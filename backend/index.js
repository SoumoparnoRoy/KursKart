require('dotenv').config();
const app = require('./app');
const connectToDatabase = require('./db');


// Local development entry point. Vercel never runs this file — it imports the
// app through api/index.js and does its own listening.
const PORT = process.env.PORT || 3000;

for (const key of ["MONGO_URI", "JWT_SECRET"]) {
    if (!process.env[key]) {
        console.error(`Missing required environment variable: ${key}`);
        process.exit(1);
    }
}

// Connect up front so a local server reports database problems at startup
// rather than on the first request.
connectToDatabase()
    .then(() => console.log("MongoDB Connected"))
    .catch((err) => console.log("MongoDB connection error:", err.message));

app.listen(PORT, "0.0.0.0", function () {
    console.log(`server is running on port ${PORT}`);
});
