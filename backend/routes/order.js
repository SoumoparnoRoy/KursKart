const express = require('express');
const mongoose = require('mongoose');
const Cart = require('../models/cart');
const Order = require('../models/order');
const Product = require('../models/product');
const User = require('../models/user');
const verifyToken = require('../middlewares/auth');
const verifyVendor = require('../middlewares/vendor');
const { ALLOWED_TRANSITIONS, statusOf, rollUpStatus } = require('../models/order');
const { hasAddress, addressOf } = require('../address');


const orderRouter = express.Router();

/// Decrements stock one product at a time with a conditional update, so two
/// simultaneous checkouts can never oversell: the filter only matches while
/// enough stock remains. If a later item fails, the earlier decrements are put
/// back rather than leaving stock silently consumed.
async function reserveStock(lines) {
    const reserved = [];

    for (const line of lines) {
        const updated = await Product.findOneAndUpdate(
            { _id: line.product._id, stock: { $gte: line.quantity } },
            { $inc: { stock: -line.quantity } },
        );

        if (!updated) {
            for (const done of reserved) {
                await Product.updateOne(
                    { _id: done.product._id },
                    { $inc: { stock: done.quantity } },
                );
            }
            return { ok: false, failed: line };
        }

        reserved.push(line);
    }

    return { ok: true };
}

/// Puts stock back when a line is cancelled. Products deleted since the order
/// was placed simply match nothing, which is the right outcome — there is no
/// inventory left to credit.
async function releaseStock(lines) {
    for (const line of lines) {
        await Product.updateOne(
            { _id: line.product },
            { $inc: { stock: line.quantity } },
        );
    }
}

/// Reshapes an order for the vendor who owns some of its lines: their items
/// only, and totals covering just those. A vendor has no business seeing what
/// another store sold to the same customer.
function forVendor(order, storeId, customerName) {
    const mine = order.items.filter(
        (i) => i.store?.toString() === storeId.toString(),
    );
    const subtotal = mine.reduce((sum, i) => sum + i.price * i.quantity, 0);

    return {
        _id: order._id,
        items: mine,
        shippingAddress: order.shippingAddress,
        customerName,
        subtotal,
        total: subtotal,
        // The status of this vendor's own part, not of the whole order.
        status: rollUpStatus(mine),
        createdAt: order.createdAt,
    };
}

orderRouter.post('/api/orders', verifyToken, async (req, res) => {
    try {
        // Checked before touching stock: refusing early avoids reserving units
        // for an order that cannot be shipped anywhere.
        const user = await User.findById(req.user);
        if (!user) {
            return res.status(404).json({ msg: "User not found" });
        }
        if (!hasAddress(user)) {
            return res.status(400).json({
                msg: "Add a delivery address before placing an order",
                code: "ADDRESS_REQUIRED",
            });
        }

        const cart = await Cart.findOne({ user: req.user }).populate({
            path: "items.product",
            populate: { path: "store", select: "name" },
        });

        const lines = (cart?.items ?? []).filter((i) => i.product);
        if (lines.length === 0) {
            return res.status(400).json({ msg: "Your cart is empty" });
        }

        const reservation = await reserveStock(lines);
        if (!reservation.ok) {
            const p = reservation.failed.product;
            return res.status(400).json({
                msg: p.stock === 0
                    ? `${p.name} is out of stock`
                    : `Only ${p.stock} left of ${p.name}`,
            });
        }

        const items = lines.map((line) => ({
            product: line.product._id,
            name: line.product.name,
            price: line.product.price,
            image: line.product.images?.[0] ?? "",
            quantity: line.quantity,
            store: line.product.store?._id ?? line.product.store,
            storeName: line.product.store?.name ?? "",
        }));

        const subtotal = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

        const order = await Order.create({
            user: req.user,
            items,
            shippingAddress: addressOf(user),
            subtotal,
            // No delivery charge or tax yet, so total tracks subtotal. Kept as
            // its own field so adding them later does not change the schema.
            total: subtotal,
        });

        cart.items = [];
        await cart.save();

        res.status(201).json(order);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

orderRouter.get('/api/orders', verifyToken, async (req, res) => {
    try {
        const orders = await Order.find({ user: req.user })
            .sort({ createdAt: -1 })
            .lean();
        res.json({ orders });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Declared before /api/orders/:id, which would otherwise swallow "vendor" and
// reject it as a malformed id.
orderRouter.get('/api/orders/vendor', verifyToken, verifyVendor, async (req, res) => {
    try {
        const orders = await Order.find({ "items.store": req.store._id })
            .sort({ createdAt: -1 })
            .populate({ path: "user", select: "fullName" })
            .lean();

        res.json({
            orders: orders.map((o) =>
                forVendor(o, req.store._id, o.user?.fullName ?? ""),
            ),
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Moves this vendor's own lines. Lines belonging to other stores on the same
// order are left exactly as they are.
orderRouter.patch('/api/orders/:id/status', verifyToken, verifyVendor, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid order id" });
        }

        const next = (req.body?.status ?? "").toString().trim();

        const order = await Order.findOne({
            _id: req.params.id,
            "items.store": req.store._id,
        }).populate({ path: "user", select: "fullName" });

        if (!order) {
            return res.status(404).json({ msg: "Order not found" });
        }

        const mine = order.items.filter(
            (i) => i.store?.toString() === req.store._id.toString(),
        );

        // The vendor's lines always move together, so the current status of
        // their part is the roll-up of just those lines.
        const current = rollUpStatus(mine);
        if (!ALLOWED_TRANSITIONS[current]?.includes(next)) {
            return res.status(400).json({
                msg: current === next
                    ? `This order is already ${current}`
                    : `Cannot go from ${current} to ${next || "that status"}`,
            });
        }

        if (next === "cancelled") {
            await releaseStock(mine.filter((i) => statusOf(i) !== "cancelled"));
        }

        for (const item of mine) {
            item.status = next;
        }

        // Recomputes the order-level status in a pre-save hook.
        await order.save();

        res.json(forVendor(order.toObject(), req.store._id, order.user?.fullName ?? ""));
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// The customer's own cancel. Allowed only while nothing has shipped, and it
// takes the whole order — a buyer cancels a purchase, not one store's part.
orderRouter.patch('/api/orders/:id/cancel', verifyToken, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid order id" });
        }

        const order = await Order.findOne({ _id: req.params.id, user: req.user });
        if (!order) {
            return res.status(404).json({ msg: "Order not found" });
        }

        const live = order.items.filter((i) => statusOf(i) !== "cancelled");
        if (live.length === 0) {
            return res.status(400).json({ msg: "This order is already cancelled" });
        }
        if (live.some((i) => statusOf(i) !== "placed")) {
            return res.status(400).json({
                msg: "This order has already been shipped and cannot be cancelled",
            });
        }

        await releaseStock(live);
        for (const item of live) {
            item.status = "cancelled";
        }
        await order.save();

        res.json(order);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

orderRouter.get('/api/orders/:id', verifyToken, async (req, res) => {
    try {
        if (!mongoose.isValidObjectId(req.params.id)) {
            return res.status(400).json({ msg: "Invalid order id" });
        }

        // Scoped to the caller, so one user can never read another's order by id.
        const order = await Order.findOne({
            _id: req.params.id,
            user: req.user,
        }).lean();

        if (!order) {
            return res.status(404).json({ msg: "Order not found" });
        }

        res.json(order);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = orderRouter;
