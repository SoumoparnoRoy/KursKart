require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/user');
const Order = require('./models/order');


// Removes the demo accounts the seeder creates, so a database that has been
// seeded with a known password can be made safe without tearing down the
// catalogue.
//
// It deletes the accounts and their orders. Stores, products and reviews stay:
// `owner` on a store is only ever used to look up a store from an authenticated
// request, never populated or displayed, so a store whose owner is gone still
// lists and sells normally, and the seeder re-owns it by name on the next run.
// Reviews keep their copied `userName`, so ratings do not collapse when their
// authors go.
//
// The orders have to go with the accounts. An order whose buyer no longer
// exists still appears in the vendor's list, with a blank customer name and a
// shipping address belonging to nobody — worse than not being there at all.
//
// Matching is on the demo domain rather than a list of addresses shared with
// seed.js, so accounts left behind by older versions of the seeder are caught
// too. Nothing real should ever be on this domain, and the script prints what
// it found and waits for an explicit go-ahead before deleting.
const DEMO_DOMAIN = /@kurskart\.dev$/;

function targetsLocalhost(uri) {
    return /(\/\/|@)(localhost|127\.0\.0\.1|\[::1\])([:/]|$)/.test(uri);
}

async function purge() {
    if (!process.env.MONGO_URI) {
        console.error("Missing required environment variable: MONGO_URI");
        process.exit(1);
    }

    await mongoose.connect(process.env.MONGO_URI);
    console.log(`Connected to "${mongoose.connection.name}"`);

    const accounts = await User.find({ email: DEMO_DOMAIN })
        .select("email role")
        .sort({ role: 1, email: 1 })
        .lean();

    if (accounts.length === 0) {
        console.log("No demo accounts found. Nothing to do.");
        await mongoose.disconnect();
        return;
    }

    console.log(`\nFound ${accounts.length} demo account(s):`);
    for (const a of accounts) {
        console.log(`  ${a.role ?? "customer"}\t${a.email}`);
    }

    // Deleting accounts off a shared database should be as deliberate as
    // seeding one, and for the same reason: the default has to be "do nothing".
    if (!targetsLocalhost(process.env.MONGO_URI) && process.env.SEED_ALLOW !== "yes") {
        console.log(
            "\nMONGO_URI does not point at localhost, so nothing was deleted.\n" +
            "Re-run with SEED_ALLOW=yes to remove the accounts listed above.",
        );
        await mongoose.disconnect();
        return;
    }

    // Collected before the accounts go, since afterwards there is nothing left
    // to match the orders against.
    const ids = accounts.map((a) => a._id);
    const orders = await Order.deleteMany({ user: { $in: ids } });
    const result = await User.deleteMany({ email: DEMO_DOMAIN });

    console.log(`\nDeleted ${result.deletedCount} demo account(s) and ${orders.deletedCount} of their order(s).`);
    console.log(
        "Stores, products and reviews were left untouched. The seeded stores " +
        "now have no owner who can sign in; re-running the seeder re-owns them.",
    );

    await mongoose.disconnect();
}

purge().catch(async (e) => {
    console.error("Purge failed:", e.message);
    await mongoose.disconnect();
    process.exit(1);
});
