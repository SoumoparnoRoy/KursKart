const express = require('express');
const mongoose = require('mongoose');
const Order = require('../models/order');
const Product = require('../models/product');
const Review = require('../models/review');
const User = require('../models/user');
const verifyToken = require('../middlewares/auth');


const reviewRouter = express.Router();

const MAX_LIMIT = 50;
const DEFAULT_LIMIT = 20;

/// Returns an error message, or null when the rating is usable. Checked here
/// rather than left to the schema because a non-numeric value raises a CastError
/// rather than a ValidationError, and its wording ("Cast to Number failed for
/// value...") is no use to anyone reading it in a snackbar.
function validateRating(value) {
    if (typeof value !== "number" || !Number.isInteger(value)) {
        return "Rating must be a whole number of stars, from 1 to 5";
    }
    if (value < 1 || value > 5) {
        return "Rating must be between 1 and 5";
    }
    return null;
}

/// Finds the order that entitles this user to review this product: one of
/// theirs holding a line for it that actually reached the customer. Buying is
/// not enough — a cancelled order proves nothing about the product.
async function deliveredOrderFor(userId, productId) {
    return Order.findOne({
        user: userId,
        items: {
            $elemMatch: {
                product: productId,
                status: "delivered",
            },
        },
    })
        .sort({ createdAt: -1 })
        .select("_id")
        .lean();
}

reviewRouter.get('/api/products/:id/reviews', async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const page = Math.max(1, parseInt(req.query.page, 10) || 1);
        const limit = Math.min(
            MAX_LIMIT,
            Math.max(1, parseInt(req.query.limit, 10) || DEFAULT_LIMIT),
        );

        const filter = { product: req.params.id };

        const [reviews, total, spread] = await Promise.all([
            Review.find(filter)
                .sort({ createdAt: -1 })
                .skip((page - 1) * limit)
                .limit(limit)
                .lean(),
            Review.countDocuments(filter),
            // Powers the 5-to-1 bars next to the average. Cheap enough to send
            // with the first page rather than as its own endpoint.
            Review.aggregate([
                { $match: { product: new mongoose.Types.ObjectId(req.params.id) } },
                { $group: { _id: "$rating", count: { $sum: 1 } } },
            ]),
        ]);

        const distribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
        for (const row of spread) {
            distribution[row._id] = row.count;
        }

        res.json({
            reviews,
            distribution,
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit) || 1,
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

/// Whether the caller may review this product, and whether they already have.
/// The client asks before showing a "Write a review" button, so the button
/// never appears only to be rejected on submit.
reviewRouter.get('/api/products/:id/reviews/mine', verifyToken, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const [mine, order] = await Promise.all([
            Review.findOne({ product: req.params.id, user: req.user }).lean(),
            deliveredOrderFor(req.user, req.params.id),
        ]);

        res.json({ review: mine ?? null, canReview: Boolean(order) });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

reviewRouter.post('/api/products/:id/reviews', verifyToken, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid product id" });
        }

        const invalid = validateRating(req.body?.rating);
        if (invalid) {
            return res.status(400).json({ msg: invalid });
        }

        const product = await Product.findById(req.params.id).select("_id").lean();
        if (!product) {
            return res.status(404).json({ msg: "Product not found" });
        }

        const order = await deliveredOrderFor(req.user, req.params.id);
        if (!order) {
            return res.status(403).json({
                msg: "You can review this once your order has been delivered",
                code: "NOT_DELIVERED",
            });
        }

        const user = await User.findById(req.user).select("fullName").lean();

        const review = await Review.create({
            product: req.params.id,
            user: req.user,
            userName: user?.fullName ?? "",
            order: order._id,
            rating: req.body?.rating,
            comment: req.body?.comment ?? "",
        });

        const summary = await Review.refreshProductRating(req.params.id);
        res.status(201).json({ review, ...summary });
    } catch (e) {
        if (e.code === 11000) {
            return res.status(409).json({
                msg: "You have already reviewed this product",
                code: "ALREADY_REVIEWED",
            });
        }
        if (e.name === "ValidationError") {
            const [first] = Object.values(e.errors);
            return res.status(400).json({ msg: first.message });
        }
        res.status(500).json({ error: e.message });
    }
});

/// Both of these scope the lookup to the caller, so a valid review id belonging
/// to somebody else simply does not match.
reviewRouter.patch('/api/reviews/:id', verifyToken, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid review id" });
        }

        if (req.body?.rating !== undefined) {
            const invalid = validateRating(req.body.rating);
            if (invalid) {
                return res.status(400).json({ msg: invalid });
            }
        }

        const review = await Review.findOne({ _id: req.params.id, user: req.user });
        if (!review) {
            return res.status(404).json({ msg: "Review not found" });
        }

        if (req.body?.rating !== undefined) review.rating = req.body.rating;
        if (req.body?.comment !== undefined) review.comment = req.body.comment;

        await review.save();

        const summary = await Review.refreshProductRating(review.product);
        res.json({ review, ...summary });
    } catch (e) {
        if (e.name === "ValidationError") {
            const [first] = Object.values(e.errors);
            return res.status(400).json({ msg: first.message });
        }
        res.status(500).json({ error: e.message });
    }
});

reviewRouter.delete('/api/reviews/:id', verifyToken, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid review id" });
        }

        const review = await Review.findOneAndDelete({
            _id: req.params.id,
            user: req.user,
        });

        if (!review) {
            return res.status(404).json({ msg: "Review not found" });
        }

        const summary = await Review.refreshProductRating(review.product);
        res.json({ msg: "Review deleted", id: review._id, ...summary });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = reviewRouter;
