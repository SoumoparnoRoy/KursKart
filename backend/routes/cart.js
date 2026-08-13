const express = require('express');
const mongoose = require('mongoose');
const Cart = require('../models/cart');
const Product = require('../models/product');
const verifyToken = require('../middlewares/auth');


const cartRouter = express.Router();

const PRODUCT_FIELDS = "name price images stock category";

async function loadCart(userId) {
    const existing = await Cart.findOne({ user: userId });
    return existing ?? (await Cart.create({ user: userId, items: [] }));
}

/// Populates the cart and drops any line whose product no longer exists.
/// Reseeding deletes and recreates every product, so dangling references are a
/// normal occurrence here rather than an edge case.
async function serialiseCart(cart) {
    await cart.populate({
        path: "items.product",
        select: PRODUCT_FIELDS,
        populate: { path: "store", select: "name" },
    });

    const live = cart.items.filter((item) => item.product);
    if (live.length !== cart.items.length) {
        cart.items = live.map((item) => ({
            product: item.product._id,
            quantity: item.quantity,
        }));
        await cart.save();
        await cart.populate({
            path: "items.product",
            select: PRODUCT_FIELDS,
            populate: { path: "store", select: "name" },
        });
    }

    const items = cart.items.map((item) => ({
        product: item.product,
        quantity: item.quantity,
    }));

    return {
        items,
        itemCount: items.reduce((sum, i) => sum + i.quantity, 0),
        subtotal: items.reduce((sum, i) => sum + i.product.price * i.quantity, 0),
    };
}

function parseQuantity(value, fallback) {
    const quantity = value === undefined ? fallback : value;
    if (!Number.isInteger(quantity) || quantity < 1) return null;
    return quantity;
}

cartRouter.get('/api/cart', verifyToken, async (req, res) => {
    try {
        const cart = await loadCart(req.user);
        res.json(await serialiseCart(cart));
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

cartRouter.post('/api/cart/items', verifyToken, async (req, res) => {
    try {
        const { productId } = req.body;

        if (!mongoose.isValidObjectId(productId)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const quantity = parseQuantity(req.body.quantity, 1);
        if (quantity === null) {
            return res.status(400).json({ msg: "Quantity must be a whole number of 1 or more" });
        }

        const product = await Product.findById(productId);
        if (!product) {
            return res.status(404).json({ msg: "Product not found" });
        }

        const cart = await loadCart(req.user);
        const existing = cart.items.find((i) => i.product.equals(product._id));
        const wanted = (existing?.quantity ?? 0) + quantity;

        // Stock is checked here rather than trusting whatever the client last saw.
        if (wanted > product.stock) {
            return res.status(400).json({
                msg: product.stock === 0
                    ? "This product is out of stock"
                    : `Only ${product.stock} left in stock`,
            });
        }

        if (existing) {
            existing.quantity = wanted;
        } else {
            cart.items.push({ product: product._id, quantity });
        }

        await cart.save();
        res.json(await serialiseCart(cart));
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

cartRouter.patch('/api/cart/items/:productId', verifyToken, async (req, res) => {
    try {
        const { productId } = req.params;

        if (!mongoose.isValidObjectId(productId)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const quantity = parseQuantity(req.body.quantity, undefined);
        if (quantity === null) {
            return res.status(400).json({ msg: "Quantity must be a whole number of 1 or more" });
        }

        const cart = await loadCart(req.user);
        const existing = cart.items.find((i) => i.product.equals(productId));
        if (!existing) {
            return res.status(404).json({ msg: "That product is not in your cart" });
        }

        const product = await Product.findById(productId);
        if (!product) {
            return res.status(404).json({ msg: "Product not found" });
        }

        if (quantity > product.stock) {
            return res.status(400).json({
                msg: product.stock === 0
                    ? "This product is out of stock"
                    : `Only ${product.stock} left in stock`,
            });
        }

        existing.quantity = quantity;
        await cart.save();
        res.json(await serialiseCart(cart));
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

cartRouter.delete('/api/cart/items/:productId', verifyToken, async (req, res) => {
    try {
        const { productId } = req.params;

        if (!mongoose.isValidObjectId(productId)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const cart = await loadCart(req.user);
        cart.items = cart.items.filter((i) => !i.product.equals(productId));
        await cart.save();
        res.json(await serialiseCart(cart));
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

cartRouter.delete('/api/cart', verifyToken, async (req, res) => {
    try {
        const cart = await loadCart(req.user);
        cart.items = [];
        await cart.save();
        res.json(await serialiseCart(cart));
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = cartRouter;
