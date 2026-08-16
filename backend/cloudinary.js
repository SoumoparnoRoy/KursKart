const crypto = require('crypto');


// Everything the app does with Cloudinary, kept in one place: signing an upload
// permit, working out which asset a stored URL refers to, and deleting one.
//
// There is no `cloudinary` npm package here on purpose. Signing is a sorted
// query string hashed with the API secret, which is a few lines, and the two
// REST calls we make are plain fetches.

const API_BASE = 'https://api.cloudinary.com/v1_1';

// Where every product image lives. Also the prefix the prune script sweeps, so
// nothing outside it is ever considered for deletion.
const PRODUCTS_FOLDER = 'kurskart/products';

function config() {
    return {
        cloudName: process.env.CLOUDINARY_CLOUD_NAME,
        apiKey: process.env.CLOUDINARY_API_KEY,
        apiSecret: process.env.CLOUDINARY_API_SECRET,
    };
}

function isConfigured() {
    const { cloudName, apiKey, apiSecret } = config();
    return Boolean(cloudName && apiKey && apiSecret);
}

// Cloudinary signs the parameters, not the file: sort them by key, join them as
// a query string, append the API secret, and hash. Callers must then send back
// exactly these parameters, or the request is rejected.
function signParams(params, secret) {
    const payload = Object.keys(params)
        .sort()
        .map((key) => `${key}=${params[key]}`)
        .join("&");

    return crypto.createHash("sha1").update(payload + secret).digest("hex");
}

// A permit for one upload into the given store's own folder.
function signUpload(storeId) {
    const { cloudName, apiKey, apiSecret } = config();
    const folder = `${PRODUCTS_FOLDER}/${storeId}`;
    const timestamp = Math.floor(Date.now() / 1000);

    return {
        cloudName,
        apiKey,
        timestamp,
        folder,
        signature: signParams({ folder, timestamp }, apiSecret),
    };
}

/// Turns a stored image URL back into the Cloudinary public id, or null if the
/// URL is not one of ours — pasted links to other sites are common in this app
/// and must never be treated as deletable assets.
function publicIdFromUrl(url) {
    const { cloudName } = config();
    if (!cloudName || typeof url !== "string") return null;

    let parsed;
    try {
        parsed = new URL(url);
    } catch {
        return null;
    }

    if (parsed.hostname !== "res.cloudinary.com") return null;

    // /<cloud>/image/upload/[transformations/]v123/<public id>.<ext>
    const segments = parsed.pathname.split('/').filter(Boolean);
    if (segments[0] !== cloudName) return null;

    const uploadAt = segments.indexOf("upload");
    if (uploadAt === -1) return null;

    let rest = segments.slice(uploadAt + 1);

    // Drop the version, and with it any transformation segments in front of it.
    // Our own URLs carry no transformations, but one added later must not shift
    // the public id and silently turn every delete into a no-op.
    const versionAt = rest.findIndex((s) => /^v\d+$/.test(s));
    if (versionAt !== -1) rest = rest.slice(versionAt + 1);

    if (rest.length === 0) return null;

    const publicId = rest.join('/').replace(/\.[^./]+$/, '');

    // Refuse anything outside the products folder even if it is on our cloud.
    return publicId.startsWith(`${PRODUCTS_FOLDER}/`) ? publicId : null;
}

/// Deletes one asset. Returns Cloudinary's own result string ("ok",
/// "not found") or null when the call itself failed.
///
/// Never throws: callers delete images as a side effect of deleting a product,
/// and a Cloudinary outage must not stop a vendor managing their catalogue.
async function destroyImage(publicId) {
    if (!isConfigured() || !publicId) return null;

    const { cloudName, apiKey, apiSecret } = config();
    const timestamp = Math.floor(Date.now() / 1000);

    const body = new URLSearchParams({
        public_id: publicId,
        timestamp: String(timestamp),
        api_key: apiKey,
        signature: signParams({ public_id: publicId, timestamp }, apiSecret),
    });

    try {
        const res = await fetch(`${API_BASE}/${cloudName}/image/destroy`, {
            method: 'POST',
            body,
            // Deletes happen while a vendor waits on their own request, so this
            // gives up rather than holding the response open. Whatever is
            // missed here is picked up by `npm run cloudinary:prune`.
            signal: AbortSignal.timeout(8000),
        });
        const json = await res.json();
        return json.result ?? null;
    } catch (e) {
        console.error(`Could not delete image ${publicId}:`, e.message);
        return null;
    }
}

/// Every product image in the account, following pagination. Uses the admin
/// API, which is rate limited, so this is for the prune script rather than
/// anything on a request path.
async function listProductImages() {
    if (!isConfigured()) return [];

    const { cloudName, apiKey, apiSecret } = config();
    const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');

    const found = [];
    let cursor;

    do {
        const query = new URLSearchParams({
            type: 'upload',
            prefix: PRODUCTS_FOLDER,
            max_results: '500',
        });
        if (cursor) query.set('next_cursor', cursor);

        const res = await fetch(`${API_BASE}/${cloudName}/resources/image?${query}`, {
            headers: { Authorization: `Basic ${auth}` },
        });

        if (!res.ok) {
            throw new Error(`Cloudinary list failed (${res.status}): ${await res.text()}`);
        }

        const json = await res.json();
        for (const r of json.resources ?? []) {
            found.push({ publicId: r.public_id, bytes: r.bytes, createdAt: r.created_at });
        }
        cursor = json.next_cursor;
    } while (cursor);

    return found;
}

module.exports = {
    PRODUCTS_FOLDER,
    isConfigured,
    signUpload,
    publicIdFromUrl,
    destroyImage,
    listProductImages,
};
