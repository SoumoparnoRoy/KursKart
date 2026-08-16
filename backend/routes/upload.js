const crypto = require('crypto');
const express = require('express');
const verifyToken = require('../middlewares/auth');
const verifyVendor = require('../middlewares/vendor');


const uploadRouter = express.Router();

// Signatures are only good for an hour on Cloudinary's side. Nothing enforces
// this here; it is the window a leaked signature would stay usable.
const SIGNATURE_TTL_SECONDS = 3600;

// Cloudinary signs the upload parameters, not the file: sort them by key, join
// them as a query string, append the API secret, and hash. The client must then
// send back exactly these parameters and no others, or Cloudinary rejects it.
function signParams(params, secret) {
    const payload = Object.keys(params)
        .sort()
        .map((key) => `${key}=${params[key]}`)
        .join("&");

    return crypto.createHash("sha1").update(payload + secret).digest("hex");
}

// Hands a vendor a short-lived permit to upload one image straight to
// Cloudinary. The bytes never pass through this server, which matters on
// Vercel: a serverless request body is capped at 4.5 MB, well under what a
// tablet camera produces.
//
// The API secret stays here and is never sent to the client.
uploadRouter.post('/api/uploads/signature', verifyToken, verifyVendor, async (req, res) => {
    try {
        const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
        const apiKey = process.env.CLOUDINARY_API_KEY;
        const apiSecret = process.env.CLOUDINARY_API_SECRET;

        if (!cloudName || !apiKey || !apiSecret) {
            return res.status(503).json({ msg: "Image uploads are not configured on this server" });
        }

        // Scoped to the caller's own store, so a signature handed to one vendor
        // cannot be used to write into another's folder.
        const folder = `kurskart/products/${req.store._id}`;
        const timestamp = Math.floor(Date.now() / 1000);

        const signature = signParams({ folder, timestamp }, apiSecret);

        res.json({
            cloudName,
            apiKey,
            timestamp,
            folder,
            signature,
            expiresIn: SIGNATURE_TTL_SECONDS,
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = uploadRouter;
