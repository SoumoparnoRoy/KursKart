const mongoose = require('mongoose');


const userSchema = mongoose.Schema({
    fullName: {
        type: String,
        required: true,
        trim: true,
    },

    email: {
        type: String,
        required: true,
        trim: true,
        unique: true,
        lowercase: true,
        validate: {
            validator: (value) => {
                const result = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
                return result.test(value);
            },
            message: "Please enter a valid email address",
        }
    },

    state: {
        type: String,
        default: "",
    },

    city: {
        type: String,
        default: "",
    },

    locality: {
        type: String,
        default: "",
    },

    password: {
        type: String,
        required: true,
        // Note: this only ever sees the bcrypt hash, which is always 60
        // characters, so it cannot reject a short password. The real check is
        // on the raw password in the signup route.
        validate: {
            validator: (value) => {
                return value.length >= 8;
            },
            message: "Password must be atleast 8 characters",
        }
    },

    // Accounts created before this field existed have no role at all, so code
    // must treat a missing role as "customer" rather than assuming it is set.
    role: {
        type: String,
        enum: ["customer", "vendor"],
        default: "customer",
    },
});

const User = mongoose.model("User", userSchema);
module.exports = User;