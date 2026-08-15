const mongoose = require('mongoose');


const storeSchema = mongoose.Schema({
    name: {
        type: String,
        required: true,
        trim: true,
    },

    // One store per vendor for now. Products hang off the store rather than the
    // user so a store can later change hands without touching every product.
    owner: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        required: true,
        unique: true,
    },

    description: {
        type: String,
        default: "",
        trim: true,
    },

    logoUrl: {
        type: String,
        default: "",
    },

    isActive: {
        type: Boolean,
        default: true,
    },

    // Same purpose as the flag on Product: marks rows the seeder owns, so it can
    // find its own store again by name after the owning account has been
    // deleted and recreated with a new id.
    seeded: {
        type: Boolean,
        default: false,
    },
}, { timestamps: true });

const Store = mongoose.model("Store", storeSchema);
module.exports = Store;
