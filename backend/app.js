require('dotenv').config();
const express = require('express');
const connectToDatabase = require('./db');
const authRouter = require('./routes/auth');
const productRouter = require('./routes/product');
const storeRouter = require('./routes/store');
const cartRouter = require('./routes/cart');
const orderRouter = require('./routes/order');


// Checked here rather than in index.js because serverless never runs index.js.
// Logged rather than exited: killing the process is right for a local server
// but useless in a function, where the platform just restarts it.
for (const key of ["MONGO_URI", "JWT_SECRET"]) {
    if (!process.env[key]) {
        console.error(`Missing required environment variable: ${key}`);
    }
}

const app = express();

app.use(express.json());

// Declared before the database middleware so it answers instantly: its job is
// to wake a sleeping function before a demo, not to check Mongo.
app.get('/api/health', (req, res) => {
    res.json({ ok: true, time: new Date().toISOString() });
});

// Every other request waits for a live connection first. On a warm instance
// this resolves immediately from the cache; on a cold one it opens the
// connection once and every later request reuses it.
app.use(async (req, res, next) => {
    try {
        await connectToDatabase();
        next();
    } catch (e) {
        console.error("MongoDB connection error:", e.message);
        res.status(503).json({ msg: "Database unavailable, please try again" });
    }
});

app.use(authRouter);
app.use(productRouter);
app.use(storeRouter);
app.use(cartRouter);
app.use(orderRouter);

module.exports = app;
