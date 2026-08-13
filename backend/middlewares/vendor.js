const User = require('../models/user');
const Store = require('../models/store');


// Runs after verifyToken. Confirms the caller is a vendor and loads the store
// they own, so routes never have to trust a store id from the request body.
//
// Accounts created before the role field existed have no role at all, which
// reads as undefined and correctly fails this check.
const verifyVendor = async (req, res, next) => {
    try {
        const user = await User.findById(req.user);
        if (!user) {
            return res.status(404).json({ msg: "User not found" });
        }

        if (user.role !== "vendor") {
            return res.status(403).json({ msg: "Vendor account required" });
        }

        const store = await Store.findOne({ owner: user._id });
        if (!store) {
            return res.status(404).json({ msg: "No store found for this vendor" });
        }

        req.vendor = user;
        req.store = store;
        next();
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};

module.exports = verifyVendor;
