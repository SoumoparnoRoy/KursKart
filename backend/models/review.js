const mongoose = require('mongoose');
const Product = require('./product');


const reviewSchema = mongoose.Schema({
    product: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Product",
        required: true,
    },

    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        required: true,
    },

    // Copied at write time, like the fields on an order line. A review has to
    // keep reading correctly even if the author later changes their name.
    userName: { type: String, default: "" },

    // The delivered order that entitles this review. Kept so the claim can be
    // audited later, and so a refunded order could withdraw its review.
    order: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Order",
        required: true,
    },

    rating: {
        type: Number,
        required: true,
        min: [1, "Rating must be between 1 and 5"],
        max: [5, "Rating must be between 1 and 5"],
        validate: {
            validator: Number.isInteger,
            message: "Rating must be a whole number of stars",
        },
    },

    comment: {
        type: String,
        default: "",
        trim: true,
        maxlength: [1000, "Review is too long"],
    },

    // Same purpose as the flag on Product: lets the seeder clean up only its
    // own rows and never a review a real account wrote.
    seeded: {
        type: Boolean,
        default: false,
    },
}, { timestamps: true });

// One review per person per product. Editing goes through PATCH rather than a
// second row, so the average cannot be stuffed by reviewing repeatedly.
reviewSchema.index({ product: 1, user: 1 }, { unique: true });
reviewSchema.index({ product: 1, createdAt: -1 });

/// Recomputes the denormalised rating on the product. The product carries the
/// average so the feed can sort and display without joining reviews on every
/// read; this is the only thing that writes it.
reviewSchema.statics.refreshProductRating = async function (productId) {
    const [summary] = await this.aggregate([
        { $match: { product: new mongoose.Types.ObjectId(String(productId)) } },
        {
            $group: {
                _id: "$product",
                average: { $avg: "$rating" },
                count: { $sum: 1 },
            },
        },
    ]);

    // Rounded to one decimal because that is all the UI shows, and storing the
    // full float would make two products with identical stars sort apart for
    // reasons nobody can see.
    const average = summary ? Math.round(summary.average * 10) / 10 : 0;
    const count = summary?.count ?? 0;

    await Product.updateOne(
        { _id: productId },
        { $set: { rating: average, ratingCount: count } },
    );

    return { rating: average, ratingCount: count };
};

const Review = mongoose.model("Review", reviewSchema);
module.exports = Review;
