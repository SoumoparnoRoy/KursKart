const express = require('express');
const mongoose = require('mongoose');
const Store = require('../models/store');
const Product = require('../models/product');
const User = require('../models/user');
const verifyToken = require('../middlewares/auth');


const storeRouter = express.Router();

storeRouter.get('/api/stores', async (req, res) => {
    try {
        const stores = await Store.find({ isActive: true })
            .select("name description logoUrl")
            .sort({ name: 1 })
            .lean();
        res.json({ stores });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Turns the caller into a vendor by giving them a store. Declared before
// /api/stores/:id so "mine" is never read as an id.
storeRouter.get('/api/stores/mine', verifyToken, async (req, res) => {
    try {
        const store = await Store.findOne({ owner: req.user }).lean();
        if (!store) {
            return res.status(404).json({ msg: "You do not have a store yet" });
        }
        res.json(store);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

storeRouter.post('/api/stores', verifyToken, async (req, res) => {
    try {
        const name = (req.body?.name ?? "").trim();
        if (!name) {
            return res.status(400).json({ msg: "Store name is required" });
        }

        const existing = await Store.findOne({ owner: req.user });
        if (existing) {
            return res.status(400).json({ msg: "You already have a store" });
        }

        const store = await Store.create({
            owner: req.user,
            name,
            description: (req.body.description ?? "").trim(),
            logoUrl: (req.body.logoUrl ?? "").trim(),
        });

        // Owning a store is what makes someone a vendor, so the role follows
        // from it rather than being granted separately.
        await User.findByIdAndUpdate(req.user, { $set: { role: "vendor" } });

        res.status(201).json(store);
    } catch (e) {
        if (e.code === 11000) {
            return res.status(400).json({ msg: "You already have a store" });
        }
        res.status(500).json({ error: e.message });
    }
});

storeRouter.patch('/api/stores/mine', verifyToken, async (req, res) => {
    try {
        const updates = {};
        if (req.body?.name !== undefined) {
            const name = req.body.name.trim();
            if (!name) {
                return res.status(400).json({ msg: "Store name cannot be empty" });
            }
            updates.name = name;
        }
        if (req.body?.description !== undefined) {
            updates.description = req.body.description.trim();
        }
        if (req.body?.logoUrl !== undefined) {
            updates.logoUrl = req.body.logoUrl.trim();
        }

        const store = await Store.findOneAndUpdate(
            { owner: req.user },
            { $set: updates },
            { returnDocument: "after", runValidators: true },
        );

        if (!store) {
            return res.status(404).json({ msg: "You do not have a store yet" });
        }

        res.json(store);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// A store profile plus its products, which is everything the store page needs
// in one round trip.
storeRouter.get('/api/stores/:id', async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid store id" });
        }

        const store = await Store.findById(req.params.id)
            .select("name description logoUrl isActive")
            .lean();

        if (!store) {
            return res.status(404).json({ msg: "Store not found" });
        }

        const products = await Product.find({ store: store._id })
            .sort({ createdAt: -1 })
            .lean();

        res.json({ ...store, products });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = storeRouter;
