require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const authRouter = require('./routes/auth');
const productRouter = require('./routes/product');
const storeRouter = require('./routes/store');


const PORT = process.env.PORT || 3000;

for (const key of ["MONGO_URI", "JWT_SECRET"]) {
    if (!process.env[key]) {
        console.error(`Missing required environment variable: ${key}`);
        process.exit(1);
    }
}

const app = express();
app.use(express.json());
app.use(authRouter);
app.use(productRouter);
app.use(storeRouter);

mongoose.connect(process.env.MONGO_URI)
    .then(() => console.log("MongoDB Connected"))
    .catch(err => console.log("MongoDB connection error:", err));


app.listen(PORT, "0.0.0.0", function () {
    console.log(`server is running on port ${PORT}`);
});