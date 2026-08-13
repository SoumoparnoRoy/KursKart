const express = require('express');
const User = require('../models/user');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const verifyToken = require('../middlewares/auth');


const authRouter = express.Router();

authRouter.post('/api/signup', async (req, res) => {
    try {
        const { fullName, email, password } = req.body;

        if (!fullName || !email || !password) {
            return res.status(400).json({ msg: "Full name, email and password are required" });
        }

        // Must be checked here, on the raw password. The schema validator only
        // ever sees the bcrypt hash, which is always 60 characters, so it can
        // never reject a short password.
        if (password.length < 8) {
            return res.status(400).json({ msg: "Password must be at least 8 characters" });
        }

        const normalisedEmail = email.trim().toLowerCase();

        const existingEmail = await User.findOne({ email: normalisedEmail });
        if (existingEmail) {
            return res.status(400).json({ msg: "User with same email address already exists" });
        } else {
            const salt = await bcrypt.genSalt(10);
            const hashedPassword = await bcrypt.hash(password, salt);

            let user = new User({ fullName, email: normalisedEmail, password: hashedPassword });
            user = await user.save();
            const { password: _, ...userWithoutPassword } = user._doc;
            res.json(userWithoutPassword);
        }
    } catch (e) {
        // Thrown when two signups for the same email race past the findOne check.
        if (e.code === 11000) {
            return res.status(400).json({ msg: "User with same email address already exists" });
        }
        if (e.name === "ValidationError") {
            const [first] = Object.values(e.errors);
            return res.status(400).json({ msg: first.message });
        }
        res.status(500).json({ error: e.message });
    }
});


authRouter.post('/api/signin', async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ msg: "Email and password are required" });
        }

        const foundUser = await User.findOne({ email: email.trim().toLowerCase() });
        if (!foundUser) {
            return res.status(400).json({ msg: "User not found with this email" });
        } else {
            const isMatch = await bcrypt.compare(password, foundUser.password);
            if (!isMatch) {
                return res.status(400).json({ msg: "Incorrect Password" });
            } else {
                const token = jwt.sign({ id: foundUser._id }, process.env.JWT_SECRET,
                    { expiresIn: "7d" });

                const { password, ...userWithoutPassword } = foundUser._doc;

                res.json({ token, ...userWithoutPassword });
            }
        }
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Used on app start to decide whether a stored token still represents a valid
// session. Returns the current user alongside the token that was presented.
authRouter.get('/api/user', verifyToken, async (req, res) => {
    try {
        const user = await User.findById(req.user);
        if (!user) {
            return res.status(404).json({ msg: "User not found" });
        }

        const { password, ...userWithoutPassword } = user._doc;
        res.json({ token: req.token, ...userWithoutPassword });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = authRouter;