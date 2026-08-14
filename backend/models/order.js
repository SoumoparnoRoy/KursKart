const mongoose = require('mongoose');


// Name, price, image and store name are COPIED at purchase time rather than
// referenced. An order is a record of what was actually bought for what price,
// so editing or deleting a product later must not rewrite history.
const orderItemSchema = mongoose.Schema({
    product: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Product",
        required: true,
    },

    name: { type: String, required: true },
    price: { type: Number, required: true, min: 0 },
    image: { type: String, default: "" },

    quantity: {
        type: Number,
        required: true,
        min: [1, "Quantity must be at least 1"],
    },

    store: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Store",
        required: true,
    },

    storeName: { type: String, default: "" },
}, { _id: false });

const ORDER_STATUSES = ["placed", "shipped", "delivered", "cancelled"];

const orderSchema = mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        required: true,
    },

    items: {
        type: [orderItemSchema],
        required: true,
        validate: {
            validator: (items) => items.length > 0,
            message: "An order must contain at least one item",
        },
    },

    // Copied from the user at purchase time, like the item prices above. If
    // they move house, past orders must still show where they were sent.
    shippingAddress: {
        addressLine: { type: String, default: "" },
        locality: { type: String, default: "" },
        city: { type: String, default: "" },
        state: { type: String, default: "" },
        pincode: { type: String, default: "" },
        phone: { type: String, default: "" },
    },

    subtotal: { type: Number, required: true, min: 0 },
    total: { type: Number, required: true, min: 0 },

    status: {
        type: String,
        enum: ORDER_STATUSES,
        default: "placed",
    },
}, { timestamps: true });

orderSchema.index({ user: 1, createdAt: -1 });

const Order = mongoose.model("Order", orderSchema);
module.exports = Order;
module.exports.ORDER_STATUSES = ORDER_STATUSES;
