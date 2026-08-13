const mongoose = require('mongoose');


// No _id per line: an item is identified by its product, and a cart never has
// the same product twice.
const cartItemSchema = mongoose.Schema({
    product: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Product",
        required: true,
    },

    quantity: {
        type: Number,
        required: true,
        min: [1, "Quantity must be at least 1"],
        default: 1,
    },
}, { _id: false });

// A separate collection rather than a field on User, so cart writes never touch
// the document used for authentication.
const cartSchema = mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        required: true,
        unique: true,
    },

    items: {
        type: [cartItemSchema],
        default: [],
    },
}, { timestamps: true });

const Cart = mongoose.model("Cart", cartSchema);
module.exports = Cart;
