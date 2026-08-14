require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/user');
const Store = require('./models/store');
const Product = require('./models/product');


// Re-runnable: it only ever removes the stores and products belonging to the
// seeded vendors below, so real accounts and their data are left alone.
const VENDOR_PASSWORD = "vendorpass123";

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

async function seed() {
    for (const key of ["MONGO_URI"]) {
        if (!process.env[key]) {
            console.error(`Missing required environment variable: ${key}`);
            process.exit(1);
        }
    }

    assertNamesAreUnique();

    await mongoose.connect(process.env.MONGO_URI);
    console.log("MongoDB Connected");

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(VENDOR_PASSWORD, salt);

    let storeCount = 0;
    let productCount = 0;

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

        const store = await Store.findOneAndUpdate(
            { owner: user._id },
            { $set: { owner: user._id, ...vendor.store } },
            { upsert: true, returnDocument: "after", setDefaultsOnInsert: true },
        );
        storeCount += 1;

        // Products are matched on (store, name) and updated in place rather
        // than deleted and recreated, so their _ids survive a reseed. Anything
        // holding an id — an open app, a cart, a past order — keeps working.
        let created = 0;
        let vendorTotal = 0;
        const seededNames = [];

        for (const { photo, ...p } of productsByVendor[vendor.key]) {
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

    console.log(`\nSeeded ${storeCount} stores and ${productCount} products.`);
    console.log(`Vendor logins: ${vendors.map(v => v.email).join(", ")}`);
    console.log(`Vendor password: ${VENDOR_PASSWORD}`);

    await mongoose.disconnect();
}

seed().catch(async (e) => {
    console.error("Seed failed:", e.message);
    await mongoose.disconnect();
    process.exit(1);
});
