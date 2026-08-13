const express = require('express');
const mongoose = require('mongoose');
const Store = require('../models/store');
const Product = require('../models/product');


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
