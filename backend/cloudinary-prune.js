require('dotenv').config();
const mongoose = require('mongoose');
const Order = require('./models/order');
const Product = require('./models/product');
const {
    PRODUCTS_FOLDER,
    isConfigured,
    publicIdFromUrl,
    destroyImage,
    listProductImages,
} = require('./cloudinary');


// Deletes product images that nothing in the database refers to any more.
//
// The routes clean up after themselves when a product is deleted or its photo
// replaced, so this is a backstop rather than the main mechanism: it catches
// uploads abandoned before a product was ever saved, anything lost to a failed
// delete, and whatever leaked out of paths nobody thought of. Run it
// occasionally, not on a schedule tied to anything.
//
// An image is "referred to" if it is on a product OR copied onto an order line.
// Order lines matter as much as products: an order records what was actually
// bought, so deleting the asset behind a past order's thumbnail would rewrite
// history, which is exactly what copying the image at purchase time prevents.
//
// Prints what it would delete and stops there. Deleting needs --delete, and on
// a non-localhost database SEED_ALLOW=yes as well, matching the seeder — this
// reads the live catalogue to decide what is unused, and being wrong here
// destroys images that real products are showing.

function targetsLocalhost(uri) {
    return /(\/\/|@)(localhost|127\.0\.0\.1|\[::1\])([:/]|$)/.test(uri);
}

function formatBytes(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

async function prune() {
    if (!process.env.MONGO_URI) {
        console.error("Missing required environment variable: MONGO_URI");
        process.exit(1);
    }

    if (!isConfigured()) {
        console.error("Missing CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY or CLOUDINARY_API_SECRET");
        process.exit(1);
    }

    const wantsDelete = process.argv.includes("--delete");

    await mongoose.connect(process.env.MONGO_URI);
    console.log(`Connected to "${mongoose.connection.name}"`);

    // Every image the database knows about, as public ids. Pasted links to
    // other sites resolve to null and drop out, which is right: they are not
    // ours to delete and never appear in the Cloudinary listing either.
    const referenced = new Set();

    for (const product of await Product.find({}, { images: 1 }).lean()) {
        for (const url of product.images ?? []) {
            const id = publicIdFromUrl(url);
            if (id) referenced.add(id);
        }
    }
    const fromProducts = referenced.size;

    for (const order of await Order.find({}, { "items.image": 1 }).lean()) {
        for (const item of order.items ?? []) {
            const id = publicIdFromUrl(item.image);
            if (id) referenced.add(id);
        }
    }

    const assets = await listProductImages();

    console.log(
        `\n${assets.length} image(s) under ${PRODUCTS_FOLDER}, ` +
        `${referenced.size} referenced (${fromProducts} by products, ` +
        `${referenced.size - fromProducts} only by past orders).`,
    );

    const orphans = assets.filter((a) => !referenced.has(a.publicId));

    if (orphans.length === 0) {
        console.log("No orphans. Nothing to do.");
        await mongoose.disconnect();
        return;
    }

    const total = orphans.reduce((sum, o) => sum + (o.bytes ?? 0), 0);
    console.log(`\n${orphans.length} orphan(s), ${formatBytes(total)}:`);
    for (const o of orphans) {
        console.log(`  ${o.publicId}  ${formatBytes(o.bytes ?? 0)}  ${o.createdAt ?? ""}`);
    }

    if (!wantsDelete) {
        console.log("\nNothing was deleted. Re-run with --delete to remove the images listed above.");
        await mongoose.disconnect();
        return;
    }

    if (!targetsLocalhost(process.env.MONGO_URI) && process.env.SEED_ALLOW !== "yes") {
        console.log(
            "\nMONGO_URI does not point at localhost, so nothing was deleted.\n" +
            "Re-run with SEED_ALLOW=yes to remove the images listed above.",
        );
        await mongoose.disconnect();
        return;
    }

    let deleted = 0;
    for (const o of orphans) {
        const result = await destroyImage(o.publicId);
        if (result === "ok") {
            deleted += 1;
        } else {
            console.error(`  could not delete ${o.publicId} (${result ?? "no response"})`);
        }
    }

    console.log(`\nDeleted ${deleted} of ${orphans.length} orphan(s).`);
    await mongoose.disconnect();
}

prune().catch(async (e) => {
    console.error("Prune failed:", e.message);
    await mongoose.disconnect();
    process.exit(1);
});
