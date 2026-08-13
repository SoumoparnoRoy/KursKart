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

    rating: {
        type: Number,
        default: 0,
        min: 0,
        max: 5,
    },
}, { timestamps: true });

// The feed filters by store and by category, so both are indexed. The text
// index backs search on the product listing later.
productSchema.index({ store: 1 });
productSchema.index({ category: 1 });
productSchema.index({ name: "text", description: "text" });

const Product = mongoose.model("Product", productSchema);
module.exports = Product;
