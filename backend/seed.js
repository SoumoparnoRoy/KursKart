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

const productsByVendor = {
    aurora: [
        { name: "Halo Wireless Headphones", price: 7499, category: "Electronics", stock: 42, rating: 4.6, description: "Over-ear headphones with active noise cancelling and 30-hour battery life." },
        { name: "Pulse Fitness Band", price: 2999, category: "Electronics", stock: 130, rating: 4.1, description: "Heart-rate and sleep tracking with a seven-day charge." },
        { name: "Nimbus Bluetooth Speaker", price: 3499, category: "Electronics", stock: 68, rating: 4.4, description: "Pocket-sized speaker, IPX7 water resistant, 12-hour playback." },
        { name: "Vertex 65W GaN Charger", price: 1899, category: "Electronics", stock: 210, rating: 4.8, description: "Three-port fast charger that runs a laptop and two phones at once." },
        { name: "Slate Mechanical Keyboard", price: 5999, category: "Electronics", stock: 27, rating: 4.5, description: "Hot-swappable switches, aluminium frame, white backlight." },
        { name: "Orbit Wireless Mouse", price: 1599, category: "Electronics", stock: 95, rating: 4.0, description: "Silent-click mouse with adjustable DPI and USB-C charging." },
    ],
    vellum: [
        { name: "Stonewashed Linen Shirt", price: 2499, category: "Fashion", stock: 54, rating: 4.3, description: "Breathable European linen with a relaxed cut." },
        { name: "Everyday Canvas Tote", price: 1299, category: "Fashion", stock: 120, rating: 4.7, description: "Heavyweight cotton canvas with a reinforced base and inner pocket." },
        { name: "Merino Crew Socks (3 pack)", price: 899, category: "Fashion", stock: 300, rating: 4.2, description: "Temperature-regulating merino blend that resists odour." },
        { name: "Terracotta Stoneware Mug", price: 649, category: "Home", stock: 180, rating: 4.5, description: "Hand-glazed 350ml mug, dishwasher and microwave safe." },
        { name: "Cedar & Sage Candle", price: 1099, category: "Home", stock: 76, rating: 4.6, description: "Soy wax candle with a 45-hour burn time." },
        { name: "Waffle Cotton Throw", price: 3299, category: "Home", stock: 33, rating: 4.4, description: "Lightweight waffle-weave throw that softens with every wash." },
    ],
};

async function seed() {
    for (const key of ["MONGO_URI"]) {
        if (!process.env[key]) {
            console.error(`Missing required environment variable: ${key}`);
            process.exit(1);
        }
    }

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

        // Clear only this vendor's previous seed data.
        const existingStore = await Store.findOne({ owner: user._id });
        if (existingStore) {
            await Product.deleteMany({ store: existingStore._id });
            await Store.deleteOne({ _id: existingStore._id });
        }

        const store = await Store.create({ owner: user._id, ...vendor.store });
        storeCount += 1;

        const products = productsByVendor[vendor.key].map((p, i) => ({
            ...p,
            store: store._id,
            images: [
                `https://picsum.photos/seed/${vendor.key}-${i}-a/600/600`,
                `https://picsum.photos/seed/${vendor.key}-${i}-b/600/600`,
            ],
        }));

        await Product.insertMany(products);
        productCount += products.length;

        console.log(`  ${store.name}: ${products.length} products`);
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
