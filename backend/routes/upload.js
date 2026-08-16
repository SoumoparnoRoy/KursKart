const express = require('express');
const verifyToken = require('../middlewares/auth');
const verifyVendor = require('../middlewares/vendor');
const { isConfigured, signUpload, publicIdFromUrl, destroyImage } = require('../cloudinary');


const uploadRouter = express.Router();

// Signatures are only good for an hour on Cloudinary's side. Nothing enforces
// this here; it is the window a leaked signature would stay usable.
const SIGNATURE_TTL_SECONDS = 3600;

// Hands a vendor a short-lived permit to upload one image straight to
// Cloudinary. The bytes never pass through this server, which matters on
// Vercel: a serverless request body is capped at 4.5 MB, well under what a
// tablet camera produces.
//
// The API secret stays here and is never sent to the client.
uploadRouter.post('/api/uploads/signature', verifyToken, verifyVendor, async (req, res) => {
    try {
        if (!isConfigured()) {
            return res.status(503).json({ msg: "Image uploads are not configured on this server" });
        }

        // Scoped to the caller's own store, so a signature handed to one vendor
        // cannot be used to write into another's folder.
        res.json({ ...signUpload(req.store._id), expiresIn: SIGNATURE_TTL_SECONDS });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Deletes an image the vendor uploaded but never saved onto a product — they
// picked a photo, then picked a different one, or removed it before saving.
// Without this those uploads are orphaned the moment they are replaced, since
// nothing in the database ever referenced them.
//
// Images that *are* on a product are not deleted here: removing them is a
// product edit, and the product routes clean up as part of that.
uploadRouter.delete('/api/uploads', verifyToken, verifyVendor, async (req, res) => {
    try {
        if (!isConfigured()) {
            return res.status(503).json({ msg: "Image uploads are not configured on this server" });
        }

        const publicId = publicIdFromUrl(req.body?.url);
        if (!publicId) {
            return res.status(400).json({ msg: "Not an uploaded image URL" });
        }

        // The folder is part of the public id, so this is what stops one vendor
        // deleting another's images by passing their URL.
        if (!publicId.startsWith(`kurskart/products/${req.store._id}/`)) {
            return res.status(403).json({ msg: "That image belongs to another store" });
        }

        const result = await destroyImage(publicId);
        res.json({ deleted: result === "ok" });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = uploadRouter;
