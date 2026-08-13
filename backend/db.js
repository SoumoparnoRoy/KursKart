const mongoose = require('mongoose');


// Serverless platforms run each request in a function instance that may be
// reused or may be brand new. Without caching, every cold invocation opens
// another Mongo connection and a busy moment exhausts the cluster's connection
// limit. The cache lives on globalThis so it survives module reloads within a
// warm instance.
let cached = globalThis.__kurskartMongoose;
if (!cached) {
    cached = globalThis.__kurskartMongoose = { conn: null, promise: null };
}

async function connectToDatabase() {
    if (cached.conn) return cached.conn;

    if (!cached.promise) {
        if (!process.env.MONGO_URI) {
            throw new Error("Missing required environment variable: MONGO_URI");
        }

        cached.promise = mongoose
            .connect(process.env.MONGO_URI, {
                // Fail fast rather than queueing queries against a dead
                // connection until the driver's default timeout expires.
                bufferCommands: false,
                serverSelectionTimeoutMS: 8000,
            })
            .catch((err) => {
                // Clear the cached promise so the next request retries instead
                // of awaiting a promise that will never resolve.
                cached.promise = null;
                throw err;
            });
    }

    cached.conn = await cached.promise;
    return cached.conn;
}

module.exports = connectToDatabase;
