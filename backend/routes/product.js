const express = require('express');
const mongoose = require('mongoose');
const Product = require('../models/product');
const verifyToken = require('../middlewares/auth');
const verifyVendor = require('../middlewares/vendor');


const productRouter = express.Router();

const MAX_LIMIT = 50;
const DEFAULT_LIMIT = 20;

/// User input goes straight into a RegExp, so characters like ( or * must be
/// neutralised or a stray bracket becomes a 500 (or a very expensive scan).
function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Only the fields the feed needs, so a listing does not drag every store field
// across the wire.
const STORE_FIELDS = "name logoUrl";

// The feed. Supports ?page, ?limit, ?category, ?store and ?search.
productRouter.get('/api/products', async (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);
        const limit = Math.min(
            MAX_LIMIT,
            Math.max(1, parseInt(req.query.limit, 10) || DEFAULT_LIMIT),
        );

        const filter = {};

        if (req.query.category) {
            filter.category = req.query.category;
        }

        if (req.query.store) {
            if (!mongoose.isValidObjectId(req.query.store)) {
                return res.status(400).json({ msg: "Invalid store id" });
            }
            filter.store = req.query.store;
        }

        // Substring match rather than $text, because search runs as the user
        // types: a text index only matches whole words, so "lin" would find
        // nothing until "linen" was fully typed. This does not use an index, so
        // it is worth revisiting (Atlas Search) if the catalogue grows large.
        const search = (req.query.search ?? "").trim();
        if (search) {
            const pattern = new RegExp(escapeRegExp(search), "i");
            filter.$or = [{ name: pattern }, { description: pattern }];
        }

        const [products, total] = await Promise.all([
            Product.find(filter)
                .populate("store", STORE_FIELDS)
                .sort({ createdAt: -1 })
                .skip((page - 1) * limit)
                .limit(limit)
                .lean(),
            Product.countDocuments(filter),
        ]);

        res.json({
            products,
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit) || 1,
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// The distinct categories that actually have products, for the feed's filter
// strip. Declared before /:id so "categories" is not read as an id.
productRouter.get('/api/products/categories', async (req, res) => {
    try {
        const categories = await Product.distinct("category");
        res.json({ categories: categories.sort() });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// The vendor's own catalogue, including anything out of stock that the public
// feed would bury. Declared before /:id so "mine" is not read as an id.
productRouter.get('/api/products/mine', verifyToken, verifyVendor, async (req, res) => {
    try {
        const products = await Product.find({ store: req.store._id })
            .sort({ createdAt: -1 })
            .lean();
        res.json({ products });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

productRouter.get('/api/products/:id', async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const product = await Product.findById(req.params.id)
            .populate("store", STORE_FIELDS)
            .lean();

        if (!product) {
            return res.status(404).json({ msg: "Product not found" });
        }

        res.json(product);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// The store is taken from the authenticated vendor, never from the request, so
// a vendor cannot add products to somebody else's store.
productRouter.post('/api/products', verifyToken, verifyVendor, async (req, res) => {
    try {
        const { name, description, price, category, images, stock } = req.body;

        if (!name || price === undefined || !category) {
            return res.status(400).json({ msg: "Name, price and category are required" });
        }

        if (typeof price !== "number" || Number.isNaN(price) || price < 0) {
            return res.status(400).json({ msg: "Price must be a number of 0 or more" });
        }

        const product = await Product.create({
            name,
            description,
            price,
            category,
            images: Array.isArray(images) ? images : [],
            stock: typeof stock === "number" ? stock : 0,
            store: req.store._id,
        });

        res.status(201).json(product);
    } catch (e) {
        if (e.name === "ValidationError") {
            const [first] = Object.values(e.errors);
            return res.status(400).json({ msg: first.message });
        }
        res.status(500).json({ error: e.message });
    }
});

/// Both of these scope the lookup to the vendor's own store, so a vendor can
/// never edit or delete another store's product even with a valid id.
productRouter.patch('/api/products/:id', verifyToken, verifyVendor, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const updates = {};
        const { name, description, price, category, images, stock } = req.body;

        if (name !== undefined) {
            if (!name.trim()) {
                return res.status(400).json({ msg: "Name cannot be empty" });
            }
            updates.name = name.trim();
        }
        if (description !== undefined) updates.description = description.trim();
        if (category !== undefined) {
            if (!category.trim()) {
                return res.status(400).json({ msg: "Category cannot be empty" });
            }
            updates.category = category.trim();
        }
        if (price !== undefined) {
            if (typeof price !== "number" || Number.isNaN(price) || price < 0) {
                return res.status(400).json({ msg: "Price must be a number of 0 or more" });
            }
            updates.price = price;
        }
        if (stock !== undefined) {
            if (!Number.isInteger(stock) || stock < 0) {
                return res.status(400).json({ msg: "Stock must be a whole number of 0 or more" });
            }
            updates.stock = stock;
        }
        if (images !== undefined) {
            updates.images = Array.isArray(images) ? images : [];
        }

        const product = await Product.findOneAndUpdate(
            { _id: req.params.id, store: req.store._id },
            { $set: updates },
            { returnDocument: "after", runValidators: true },
        );

        if (!product) {
            return res.status(404).json({ msg: "Product not found in your store" });
        }

        res.json(product);
    } catch (e) {
        if (e.name === "ValidationError") {
            const [first] = Object.values(e.errors);
            return res.status(400).json({ msg: first.message });
        }
        res.status(500).json({ error: e.message });
    }
});

productRouter.delete('/api/products/:id', verifyToken, verifyVendor, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const product = await Product.findOneAndDelete({
            _id: req.params.id,
            store: req.store._id,
        });

        if (!product) {
            return res.status(404).json({ msg: "Product not found in your store" });
        }

        // Past orders keep their snapshot, and carts holding this product have
        // the dangling line stripped on their next read.
        res.json({ msg: "Product deleted", id: product._id });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = productRouter;
