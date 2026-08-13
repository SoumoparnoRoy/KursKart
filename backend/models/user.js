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
        validate: {
            validator: (value) => {
                return value.length >= 8;
            },
            message: "Password must be atleast 8 characters",
        }
    },
});

const User = mongoose.model("User", userSchema);
module.exports = User;