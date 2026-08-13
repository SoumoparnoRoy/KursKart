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
}, { timestamps: true });

const Store = mongoose.model("Store", storeSchema);
module.exports = Store;
