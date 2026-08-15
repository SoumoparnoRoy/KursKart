const mongoose = require('mongoose');


const productSchema = mongoose.Schema({
    name: {
        type: String,
        required: true,
        trim: true,
    },

    description: {
        type: String,
        default: "",
        trim: true,
    },

    price: {
        type: Number,
        required: true,
        min: [0, "Price cannot be negative"],
    },

    category: {
        type: String,
        required: true,
        trim: true,
    },

    images: {
        type: [String],
        default: [],
    },

    stock: {
        type: Number,
        default: 0,
        min: [0, "Stock cannot be negative"],
    },

    store: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Store",
        required: true,
    },

    // Both are denormalised from the reviews and written only by
    // Review.refreshProductRating. Kept on the product so the feed can show and
    // sort by stars without joining every review on each read.
    rating: {
        type: Number,
        default: 0,
        min: 0,
        max: 5,
    },

    ratingCount: {
        type: Number,
        default: 0,
        min: 0,
    },

    // True only for rows created by the seed script. The seeder uses this to
    // scope its cleanup to its own data, so running it never deletes products a
    // vendor created in the same store.
    seeded: {
        type: Boolean,
        default: false,
    },
}, { timestamps: true });

// The feed filters by store and by category, so both are indexed.
//
// There is deliberately no text index: search needs substring matching for
// type-ahead, which $text cannot do, so the route uses a regex instead.
productSchema.index({ store: 1 });
productSchema.index({ category: 1 });

const Product = mongoose.model("Product", productSchema);
module.exports = Product;
