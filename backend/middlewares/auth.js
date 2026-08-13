const jwt = require('jsonwebtoken');


// Verifies the JWT sent in the x-auth-token header and attaches the user id to
// the request. Routes that need a signed-in user should sit behind this.
const verifyToken = (req, res, next) => {
    try {
        const token = req.header('x-auth-token');
        if (!token) {
            return res.status(401).json({ msg: "No authentication token, access denied" });
        }

        const verified = jwt.verify(token, process.env.JWT_SECRET);
        req.user = verified.id;
        req.token = token;
        next();
    } catch (e) {
        // Covers expired, malformed and wrongly-signed tokens alike.
        return res.status(401).json({ msg: "Token verification failed, authorisation denied" });
    }
};

module.exports = verifyToken;
