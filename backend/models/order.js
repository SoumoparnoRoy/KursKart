const mongoose = require('mongoose');


const ORDER_STATUSES = ["placed", "shipped", "delivered", "cancelled"];

// How far along each status is. "cancelled" has no rank — it leaves the line
// entirely rather than advancing it, so it is handled separately below.
const STATUS_RANK = { placed: 0, shipped: 1, delivered: 2 };

const ALLOWED_TRANSITIONS = {
    placed: ["shipped", "cancelled"],
    shipped: ["delivered"],
    delivered: [],
    cancelled: [],
};

// Lines saved before the per-line status existed have none, and .lean() reads
// skip Mongoose's defaults, so both paths land here.
function statusOf(item) {
    return item?.status ?? "placed";
}

// The order as a whole is only as far along as its least advanced live line:
// one store shipping does not make the order shipped while another has not.
// An order counts as cancelled only once nothing is left to deliver.
function rollUpStatus(items) {
    const live = (items ?? []).filter((i) => statusOf(i) !== "cancelled");
    if (live.length === 0) return "cancelled";

    return live.reduce(
        (least, i) =>
            STATUS_RANK[statusOf(i)] < STATUS_RANK[least] ? statusOf(i) : least,
        "delivered",
    );
}

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

    // Status lives on the line, not the order, because an order can span
    // several stores and each vendor only controls their own items. The
    // order-level status below is rolled up from these.
    status: {
        type: String,
        enum: ORDER_STATUSES,
        default: "placed",
    },
}, { _id: false });

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

    // Rolled up from the item statuses on every write, never set directly.
    // Stored rather than computed on read so it can be queried and sorted on.
    status: {
        type: String,
        enum: ORDER_STATUSES,
        default: "placed",
    },
}, { timestamps: true });

orderSchema.index({ user: 1, createdAt: -1 });

// Vendors list orders by the stores on their lines, which is a multikey lookup
// into the items array.
orderSchema.index({ "items.store": 1, createdAt: -1 });

// Mongoose 9 middleware is promise-based, so this takes no next callback.
orderSchema.pre('save', function () {
    this.status = rollUpStatus(this.items);
});

const Order = mongoose.model("Order", orderSchema);
module.exports = Order;
module.exports.ORDER_STATUSES = ORDER_STATUSES;
module.exports.ALLOWED_TRANSITIONS = ALLOWED_TRANSITIONS;
module.exports.statusOf = statusOf;
module.exports.rollUpStatus = rollUpStatus;
