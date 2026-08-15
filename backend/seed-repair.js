require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/user');
const Store = require('./models/store');
const Product = require('./models/product');
const Order = require('./models/order');
const Review = require('./models/review');


// Repairs a database left inconsistent by an older version of the seeder.
//
// The seeder used to match its stores on `owner`. Deleting a demo vendor and
// re-running it therefore produced a *second* store of the same name — the new
// account had a new id, nothing matched it, and a duplicate catalogue appeared
// alongside the original. This removes the leftovers:
//
//   - duplicate seeded stores, keeping the one that still has an owner, along
//     with the products underneath the copies
//   - orders whose buyer no longer exists, which otherwise show up in a
//     vendor's list with a blank customer name
//
// It also stamps `seeded: true` on the surviving seeded stores, which the
// current seeder matches on and which stores created by the older code lack.
//
// Idempotent: on a healthy database it finds nothing and changes nothing.

function targetsLocalhost(uri) {
    return /(\/\/|@)(localhost|127\.0\.0\.1|\[::1\])([:/]|$)/.test(uri);
}

/// A store the seeder owns. Identified by its contents rather than by a flag,
/// because the rows this script exists to clean up predate the flag.
async function isSeeded(store) {
    return (await Product.countDocuments({ store: store._id, seeded: true })) > 0;
}

async function repair() {
    if (!process.env.MONGO_URI) {
        console.error("Missing required environment variable: MONGO_URI");
        process.exit(1);
    }

    await mongoose.connect(process.env.MONGO_URI);
    console.log(`Connected to "${mongoose.connection.name}"`);

    const stores = await Store.find({}).lean();
    const seeded = [];
    for (const store of stores) {
        if (await isSeeded(store)) seeded.push(store);
    }

    // Group by name; anything with more than one row is a duplicate set.
    const byName = new Map();
    for (const store of seeded) {
        if (!byName.has(store.name)) byName.set(store.name, []);
        byName.get(store.name).push(store);
    }

    const doomed = [];
    const survivors = [];

    for (const [name, copies] of byName) {
        if (copies.length === 1) {
            survivors.push(copies[0]);
            continue;
        }

        // Keep the copy whose owner still exists; if several do, keep the one
        // carrying the reviews, since those are the rows the ratings come from.
        const scored = [];
        for (const store of copies) {
            const ids = (await Product.find({ store: store._id }).select("_id").lean())
                .map((p) => p._id);
            scored.push({
                store,
                hasOwner: Boolean(await User.exists({ _id: store.owner })),
                reviews: await Review.countDocuments({ product: { $in: ids } }),
                products: ids.length,
            });
        }

        scored.sort((a, b) =>
            Number(b.hasOwner) - Number(a.hasOwner) || b.reviews - a.reviews);

        const [keep, ...rest] = scored;
        console.log(
            `\n"${name}" has ${copies.length} copies. Keeping the one with ` +
            `owner=${keep.hasOwner}, ${keep.reviews} review(s), ` +
            `${keep.products} product(s).`,
        );
        for (const r of rest) {
            console.log(`  dropping copy ${r.store._id.toString().slice(-6)} ` +
                `(owner=${r.hasOwner}, ${r.reviews} review(s), ${r.products} product(s))`);
        }

        survivors.push(keep.store);
        doomed.push(...rest.map((r) => r.store));
    }

    const orphanOrders = [];
    for (const order of await Order.find({}).select("user").lean()) {
        if (!(await User.exists({ _id: order.user }))) orphanOrders.push(order._id);
    }

    const unstamped = survivors.filter((s) => !s.seeded);

    console.log(`\nTo remove: ${doomed.length} duplicate store(s), ` +
        `${orphanOrders.length} order(s) with a missing buyer.`);
    console.log(`To stamp as seeded: ${unstamped.length} store(s).`);

    if (doomed.length === 0 && orphanOrders.length === 0 && unstamped.length === 0) {
        console.log("Nothing to repair.");
        await mongoose.disconnect();
        return;
    }

    if (!targetsLocalhost(process.env.MONGO_URI) && process.env.SEED_ALLOW !== "yes") {
        console.log(
            "\nMONGO_URI does not point at localhost, so nothing was changed.\n" +
            "Re-run with SEED_ALLOW=yes to apply the repair above.",
        );
        await mongoose.disconnect();
        return;
    }

    const doomedIds = doomed.map((s) => s._id);
    const products = await Product.deleteMany({ store: { $in: doomedIds } });
    const removedStores = await Store.deleteMany({ _id: { $in: doomedIds } });
    const removedOrders = await Order.deleteMany({ _id: { $in: orphanOrders } });
    const stamped = await Store.updateMany(
        { _id: { $in: unstamped.map((s) => s._id) } },
        { $set: { seeded: true } },
    );

    console.log(`\nRemoved ${removedStores.deletedCount} store(s), ` +
        `${products.deletedCount} product(s), ${removedOrders.deletedCount} order(s).`);
    console.log(`Stamped ${stamped.modifiedCount} store(s) as seeded.`);

    await mongoose.disconnect();
}

repair().catch(async (e) => {
    console.error("Repair failed:", e.message);
    await mongoose.disconnect();
    process.exit(1);
});
