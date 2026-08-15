require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/user');
const Store = require('./models/store');
const Product = require('./models/product');
const Order = require('./models/order');
const Review = require('./models/review');


// Re-runnable: it only ever removes the stores and products belonging to the
// seeded vendors below, so real accounts and their data are left alone.
//
// Both passwords come from the environment with no fallback. A default here
// would be a working credential published in the repository, and these accounts
// are not toys: a vendor login can read every customer name, address and phone
// number on its store's orders.
const VENDOR_PASSWORD = process.env.VENDOR_PASSWORD;
const SHOPPER_PASSWORD = process.env.SHOPPER_PASSWORD;

// Reviews need a delivered order behind them, exactly as the API demands, so
// these accounts exist to have bought the things they review. Their addresses
// are real-shaped because an order copies one at purchase time.
const shoppers = [
    {
        fullName: "Ananya Bose", email: "shopper.ananya@kurskart.dev",
        addressLine: "14 Southern Avenue", locality: "Lake Market",
        city: "Kolkata", state: "West Bengal", pincode: "700029", phone: "9830012345",
    },
    {
        fullName: "Rohan Mehta", email: "shopper.rohan@kurskart.dev",
        addressLine: "27 Koregaon Park Road", locality: "Mundhwa",
        city: "Pune", state: "Maharashtra", pincode: "411001", phone: "9822045678",
    },
    {
        fullName: "I. Fernandes", email: "shopper.isabel@kurskart.dev",
        addressLine: "9 Hill Road", locality: "Bandra West",
        city: "Mumbai", state: "Maharashtra", pincode: "400050", phone: "9867098765",
    },
    {
        fullName: "Karthik Iyer", email: "shopper.karthik@kurskart.dev",
        addressLine: "52 Sarjapur Road", locality: "Koramangala",
        city: "Bengaluru", state: "Karnataka", pincode: "560034", phone: "9845023456",
    },
    {
        fullName: "Meera Saxena", email: "shopper.meera@kurskart.dev",
        addressLine: "3 Rajpur Road", locality: "Civil Lines",
        city: "Dehradun", state: "Uttarakhand", pincode: "248001", phone: "9411034567",
    },
];

const vendors = [
    {
        key: "aurora",
        fullName: "Aurora Supply Co",
        email: "vendor.aurora@kurskart.dev",
        store: {
            name: "Aurora Electronics",
            description: "Audio, wearables and everyday carry tech.",
            logoUrl: "https://picsum.photos/seed/aurora-logo/200/200",
        },
    },
    {
        key: "vellum",
        fullName: "Vellum and Thread",
        email: "vendor.vellum@kurskart.dev",
        store: {
            name: "Vellum & Thread",
            description: "Small-batch homeware and wardrobe staples.",
            logoUrl: "https://picsum.photos/seed/vellum-logo/200/200",
        },
    },
];

// Each `photo` is a hand-picked Unsplash id, checked by eye against the product
// it belongs to. Unsplash's CDN resizes and crops from the query string, so the
// app receives a square 600px image rather than a multi-megabyte original.
const IMAGE_PARAMS = "w=600&h=600&fit=crop&q=70";

const productsByVendor = {
    aurora: [
        { name: "Halo Wireless Headphones", price: 7499, category: "Electronics", stock: 42, rating: 4.6, photo: "photo-1505740420928-5e560c06d30e", description: "Over-ear headphones with active noise cancelling and 30-hour battery life." },
        { name: "Pulse Fitness Band", price: 2999, category: "Electronics", stock: 130, rating: 4.1, photo: "photo-1508685096489-7aacd43bd3b1", description: "Heart-rate and sleep tracking with a seven-day charge." },
        { name: "Nimbus Bluetooth Speaker", price: 3499, category: "Electronics", stock: 68, rating: 4.4, photo: "photo-1608043152269-423dbba4e7e1", description: "Pocket-sized speaker, IPX7 water resistant, 12-hour playback." },
        { name: "Vertex 65W GaN Charger", price: 1899, category: "Electronics", stock: 210, rating: 4.8, photo: "photo-1572721546624-05bf65ad7679", description: "Three-port fast charger that runs a laptop and two phones at once." },
        { name: "Slate Mechanical Keyboard", price: 5999, category: "Electronics", stock: 27, rating: 4.5, photo: "photo-1618384887929-16ec33fab9ef", description: "Hot-swappable switches, aluminium frame, white backlight." },
        { name: "Orbit Wireless Mouse", price: 1599, category: "Electronics", stock: 95, rating: 4.0, photo: "photo-1615663245857-ac93bb7c39e7", description: "Silent-click mouse with adjustable DPI and USB-C charging." },
    ],
    vellum: [
        { name: "Stonewashed Linen Shirt", price: 2499, category: "Fashion", stock: 54, rating: 4.3, photo: "photo-1740711152088-88a009e877bb", description: "Breathable European linen with a relaxed cut." },
        { name: "Everyday Canvas Tote", price: 1299, category: "Fashion", stock: 120, rating: 4.7, photo: "photo-1574365569389-a10d488ca3fb", description: "Heavyweight cotton canvas with a reinforced base and inner pocket." },
        { name: "Merino Crew Socks (3 pack)", price: 899, category: "Fashion", stock: 300, rating: 4.2, photo: "photo-1615486364462-ef6363adbc18", description: "Temperature-regulating merino blend that resists odour." },
        { name: "Terracotta Stoneware Mug", price: 649, category: "Home", stock: 180, rating: 4.5, photo: "photo-1495100497150-fe209c585f50", description: "Hand-glazed 350ml mug, dishwasher and microwave safe." },
        { name: "Cedar & Sage Candle", price: 1099, category: "Home", stock: 76, rating: 4.6, photo: "photo-1612198526331-66fcc90d67da", description: "Soy wax candle with a 45-hour burn time." },
        { name: "Waffle Cotton Throw", price: 3299, category: "Home", stock: 33, rating: 4.4, photo: "photo-1734553529922-bc020a21643b", description: "Lightweight waffle-weave throw that softens with every wash." },
    ],
};

// Picked by star rating, so a five-star row never reads like a grudging three.
// Deterministic selection keeps the text stable across reseeds.
const COMMENTS = {
    5: [
        "Exactly what I wanted. Would buy again without thinking about it.",
        "Better than I expected for the price. No complaints at all.",
        "Arrived quickly and has held up to daily use so far.",
        "Genuinely well made. The details are where the money went.",
        "Second one I've bought. That should say enough.",
    ],
    4: [
        "Very good overall, only small things keep it off full marks.",
        "Does the job well. Packaging could have been better.",
        "Happy with it. Slightly different in person than in the photos.",
        "Solid quality, though it took a few days to get used to.",
        "Good value. I'd recommend it with minor reservations.",
    ],
    3: [
        "Does what it says, nothing more. Fine for the price.",
        "Average. Works, but I doubt it will last years.",
        "Mixed feelings — good in some ways, disappointing in others.",
        "Acceptable, but I'd look around before buying again.",
    ],
    2: [
        "Not really what I expected from the description.",
        "Works, but the build quality is disappointing.",
        "Had problems within the first couple of weeks.",
    ],
    1: [
        "Stopped working almost immediately. Would not buy again.",
        "Nothing like the photos. Sending it back.",
    ],
};

/// Splits a target average into `count` whole-star ratings that land as close
/// to it as five or so reviews can — the mean of n integers moves in steps of
/// 1/n, so the derived rating rarely matches the target exactly. That is the
/// point: after this runs, the number on screen is whatever the reviews say.
function ratingsFor(target, count) {
    const total = Math.round(target * count);
    const base = Math.floor(total / count);
    const generous = total % count;

    // Spread evenly rather than filling greedily: a 4.6 becomes 5,5,5,4,4 and
    // not 5,5,5,5,3, which would leave one baffling low review on every page.
    return Array.from({ length: count }, (_, i) =>
        Math.min(5, Math.max(1, i < generous ? base + 1 : base)),
    );
}

/// True only for a database on this machine. Used to decide whether seeding
/// needs an explicit go-ahead, so the check has to fail closed: anything it
/// cannot recognise counts as remote.
function targetsLocalhost(uri) {
    return /(\/\/|@)(localhost|127\.0\.0\.1|\[::1\])([:/]|$)/.test(uri);
}

/// The seeder rewrites products, wipes the demo shoppers' order history, resets
/// stock and creates accounts whose password whoever ran it knows. Pointing it
/// at a shared database should take a deliberate act rather than being what
/// happens when MONGO_URI is left as it was.
function assertSafeTarget() {
    if (process.env.NODE_ENV === "production") {
        throw new Error("Refusing to run with NODE_ENV=production.");
    }

    if (!targetsLocalhost(process.env.MONGO_URI ?? "") && process.env.SEED_ALLOW !== "yes") {
        throw new Error(
            "MONGO_URI does not point at localhost. Seeding a shared database " +
            "overwrites products, resets stock and rebuilds the demo order " +
            "history. Re-run with SEED_ALLOW=yes if that is the intention.",
        );
    }
}

/// Products are matched on (store, name), so two entries sharing a name inside
/// one vendor would silently overwrite each other and one product would just be
/// missing. Caught here, before anything is written.
function assertNamesAreUnique() {
    for (const [key, products] of Object.entries(productsByVendor)) {
        const seen = new Set();
        for (const { name } of products) {
            if (seen.has(name)) {
                throw new Error(
                    `Duplicate product name "${name}" for vendor "${key}". ` +
                    `Names must be unique within a store.`,
                );
            }
            seen.add(name);
        }
    }
}

/// Gives every seeded product the reviews its target rating implies, along with
/// the delivered orders that entitle them — the API refuses a review without
/// one, and the seeder has no business going around its own rules.
///
/// Unlike products, seeded orders and reviews are torn down and rebuilt on each
/// run rather than matched in place, so their ids are not stable. Nothing holds
/// them but each other, and they belong to demo accounts only.
async function seedReviews(reviewable) {
    const salt = await bcrypt.genSalt(10);
    const shopperPassword = await bcrypt.hash(SHOPPER_PASSWORD, salt);

    const accounts = [];
    for (const shopper of shoppers) {
        accounts.push(await User.findOneAndUpdate(
            { email: shopper.email },
            { $set: { ...shopper, password: shopperPassword, role: "customer" } },
            { upsert: true, returnDocument: "after", setDefaultsOnInsert: true },
        ));
    }

    const shopperIds = accounts.map((a) => a._id);

    // Only the demo shoppers' own orders are rebuilt. A real customer's orders
    // and reviews are never in range.
    //
    // Reviews are upserted on (product, user) further down rather than deleted
    // and recreated: if someone signs in as a demo shopper and writes a review
    // by hand, deleting only seeded:true rows would leave theirs in place and
    // the unique index would then reject the seeded one, taking the whole run
    // down. Upserting absorbs it instead.
    await Order.deleteMany({ user: { $in: shopperIds } });

    // Which products each shopper reviewed, grouped so one delivered order can
    // cover everything they bought from a single store.
    const basket = new Map();

    const pending = [];
    reviewable.forEach((entry, productIndex) => {
        // Three to five reviews, varied so the catalogue does not look stamped
        // out, and derived from the index so a reseed produces the same page.
        const count = 3 + (productIndex % 3);
        const ratings = ratingsFor(entry.target, count);

        ratings.forEach((rating, i) => {
            const reviewer = accounts[(productIndex + i) % accounts.length];
            const pool = COMMENTS[rating];

            pending.push({
                entry,
                reviewer,
                rating,
                comment: pool[(productIndex + i) % pool.length],
            });

            const key = `${reviewer._id}:${entry.store._id}`;
            if (!basket.has(key)) {
                basket.set(key, { reviewer, store: entry.store, products: [] });
            }
            basket.get(key).products.push(entry.product);
        });
    });

    // One delivered order per shopper per store, holding everything of theirs.
    const orderFor = new Map();
    for (const [key, { reviewer, store, products }] of basket) {
        const items = products.map((p) => ({
            product: p._id,
            name: p.name,
            price: p.price,
            image: p.images?.[0] ?? "",
            quantity: 1,
            store: store._id,
            storeName: store.name,
            status: "delivered",
        }));

        const subtotal = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

        const order = await Order.create({
            user: reviewer._id,
            items,
            shippingAddress: {
                addressLine: reviewer.addressLine, locality: reviewer.locality,
                city: reviewer.city, state: reviewer.state,
                pincode: reviewer.pincode, phone: reviewer.phone,
            },
            subtotal,
            total: subtotal,
        });

        orderFor.set(key, order);
    }

    const kept = [];
    for (const { entry, reviewer, rating, comment } of pending) {
        const review = await Review.findOneAndUpdate(
            { product: entry.product._id, user: reviewer._id },
            {
                $set: {
                    userName: reviewer.fullName,
                    // Repointed at the order just rebuilt, so the proof-of-
                    // purchase reference never dangles.
                    order: orderFor.get(`${reviewer._id}:${entry.store._id}`)._id,
                    rating,
                    comment,
                    seeded: true,
                },
            },
            { upsert: true, returnDocument: "after", setDefaultsOnInsert: true },
        );

        kept.push(review._id);
    }

    // Drops seeded rows the plan no longer covers — a product removed from the
    // catalogue, or a lower review count than a previous run produced.
    await Review.deleteMany({ seeded: true, _id: { $nin: kept } });

    // The averages on the products come from the rows just written, through the
    // same path the API uses.
    for (const { product } of reviewable) {
        await Review.refreshProductRating(product._id);
    }

    return { reviewCount: pending.length, orderCount: orderFor.size };
}

async function seed() {
    for (const key of ["MONGO_URI", "VENDOR_PASSWORD", "SHOPPER_PASSWORD"]) {
        if (!process.env[key]) {
            console.error(`Missing required environment variable: ${key}`);
            process.exit(1);
        }
    }

    assertSafeTarget();
    assertNamesAreUnique();

    await mongoose.connect(process.env.MONGO_URI);
    console.log("MongoDB Connected");

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(VENDOR_PASSWORD, salt);

    let storeCount = 0;
    let productCount = 0;

    // Filled while products are written, then used to build the delivered
    // orders and reviews that give every product its stars.
    const reviewable = [];

    for (const vendor of vendors) {
        const user = await User.findOneAndUpdate(
            { email: vendor.email },
            {
                $set: {
                    fullName: vendor.fullName,
                    email: vendor.email,
                    password: hashedPassword,
                    role: "vendor",
                },
            },
            { upsert: true, returnDocument: "after", setDefaultsOnInsert: true },
        );

        // Matched on (seeded, name) rather than on owner. Owner looks like the
        // natural key, but it breaks the moment an account is deleted and
        // recreated — the new user gets a new id, no store matches it, and the
        // seeder builds a second copy of the whole catalogue alongside the
        // original. Matching by name re-owns the existing store instead.
        const store = await Store.findOneAndUpdate(
            { seeded: true, name: vendor.store.name },
            { $set: { owner: user._id, seeded: true, ...vendor.store } },
            { upsert: true, returnDocument: "after", setDefaultsOnInsert: true },
        );
        storeCount += 1;

        // Products are matched on (store, name) and updated in place rather
        // than deleted and recreated, so their _ids survive a reseed. Anything
        // holding an id — an open app, a cart, a past order — keeps working.
        let created = 0;
        let vendorTotal = 0;
        const seededNames = [];

        // `rating` is stripped out here: it is the target the seeded reviews
        // aim at, not a value to write. Product.rating is owned entirely by
        // Review.refreshProductRating now.
        for (const { photo, rating, ...p } of productsByVendor[vendor.key]) {
            seededNames.push(p.name);

            const result = await Product.findOneAndUpdate(
                { store: store._id, name: p.name },
                {
                    $set: {
                        ...p,
                        store: store._id,
                        seeded: true,
                        images: [
                            `https://images.unsplash.com/${photo}?${IMAGE_PARAMS}`,
                        ],
                    },
                },
                {
                    upsert: true,
                    returnDocument: "after",
                    setDefaultsOnInsert: true,
                    includeResultMetadata: true,
                },
            );

            if (result.lastErrorObject?.upserted) created += 1;
            vendorTotal += 1;
            productCount += 1;

            reviewable.push({
                product: result.value,
                store,
                target: rating,
            });
        }

        // Scoped to seeded:true so this only ever removes rows the seeder owns.
        // Products a vendor created in the same store are left alone.
        const removed = await Product.deleteMany({
            store: store._id,
            seeded: true,
            name: { $nin: seededNames },
        });

        console.log(
            `  ${store.name}: ${vendorTotal - created} updated, ` +
            `${created} created, ${removed.deletedCount} removed`,
        );
    }

    const { reviewCount, orderCount } = await seedReviews(reviewable);

    console.log(`\nSeeded ${storeCount} stores and ${productCount} products.`);
    console.log(`Seeded ${orderCount} delivered orders and ${reviewCount} reviews.`);
    // The passwords themselves are never printed: this output ends up in
    // terminal scrollback and CI logs, which is the same mistake as hardcoding
    // them, one step removed.
    console.log(`Vendor logins: ${vendors.map(v => v.email).join(", ")}`);
    console.log(`Shopper logins: ${shoppers.map(s => s.email).join(", ")}`);
    console.log("Passwords are whatever VENDOR_PASSWORD and SHOPPER_PASSWORD were set to.");

    await mongoose.disconnect();
}

seed().catch(async (e) => {
    console.error("Seed failed:", e.message);
    await mongoose.disconnect();
    process.exit(1);
});
