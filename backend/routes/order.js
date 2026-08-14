const express = require('express');
const mongoose = require('mongoose');
const Cart = require('../models/cart');
const Order = require('../models/order');
const Product = require('../models/product');
const User = require('../models/user');
const verifyToken = require('../middlewares/auth');
const { hasAddress, addressOf } = require('../address');


const orderRouter = express.Router();

/// Decrements stock one product at a time with a conditional update, so two
/// simultaneous checkouts can never oversell: the filter only matches while
/// enough stock remains. If a later item fails, the earlier decrements are put
/// back rather than leaving stock silently consumed.
async function reserveStock(lines) {
    const reserved = [];

    for (const line of lines) {
        const updated = await Product.findOneAndUpdate(
            { _id: line.product._id, stock: { $gte: line.quantity } },
            { $inc: { stock: -line.quantity } },
        );

        if (!updated) {
            for (const done of reserved) {
                await Product.updateOne(
                    { _id: done.product._id },
                    { $inc: { stock: done.quantity } },
                );
            }
            return { ok: false, failed: line };
        }

        reserved.push(line);
    }

    return { ok: true };
}

orderRouter.post('/api/orders', verifyToken, async (req, res) => {
    try {
        // Checked before touching stock: refusing early avoids reserving units
        // for an order that cannot be shipped anywhere.
        const user = await User.findById(req.user);
        if (!user) {
            return res.status(404).json({ msg: "User not found" });
        }
        if (!hasAddress(user)) {
            return res.status(400).json({
                msg: "Add a delivery address before placing an order",
                code: "ADDRESS_REQUIRED",
            });
        }

        const cart = await Cart.findOne({ user: req.user }).populate({
            path: "items.product",
            populate: { path: "store", select: "name" },
        });

        const lines = (cart?.items ?? []).filter((i) => i.product);
        if (lines.length === 0) {
            return res.status(400).json({ msg: "Your cart is empty" });
        }

        const reservation = await reserveStock(lines);
        if (!reservation.ok) {
            const p = reservation.failed.product;
            return res.status(400).json({
                msg: p.stock === 0
                    ? `${p.name} is out of stock`
                    : `Only ${p.stock} left of ${p.name}`,
            });
        }

        const items = lines.map((line) => ({
            product: line.product._id,
            name: line.product.name,
            price: line.product.price,
            image: line.product.images?.[0] ?? "",
            quantity: line.quantity,
            store: line.product.store?._id ?? line.product.store,
            storeName: line.product.store?.name ?? "",
        }));

        const subtotal = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

        const order = await Order.create({
            user: req.user,
            items,
            shippingAddress: addressOf(user),
            subtotal,
            // No delivery charge or tax yet, so total tracks subtotal. Kept as
            // its own field so adding them later does not change the schema.
            total: subtotal,
        });

        cart.items = [];
        await cart.save();

        res.status(201).json(order);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

orderRouter.get('/api/orders', verifyToken, async (req, res) => {
    try {
        const orders = await Order.find({ user: req.user })
            .sort({ createdAt: -1 })
            .lean();
        res.json({ orders });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

orderRouter.get('/api/orders/:id', verifyToken, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid order id" });
        }

        // Scoped to the caller, so one user can never read another's order by id.
        const order = await Order.findOne({
            _id: req.params.id,
            user: req.user,
        }).lean();

        if (!order) {
            return res.status(404).json({ msg: "Order not found" });
        }

        res.json(order);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = orderRouter;
