// Address rules live here rather than in a route, because two places need the
// same answer: the endpoint that saves an address, and checkout, which must
// refuse to place an order without one.

const REQUIRED = ["addressLine", "city", "state", "pincode", "phone"];

// Prices are in rupees and the app targets India, so these follow Indian
// formats. Relax them here if that ever changes.
const PINCODE = /^[1-9][0-9]{5}$/;
const PHONE = /^[6-9][0-9]{9}$/;

/// Returns an error message, or null when the address is usable.
function validateAddress(input) {
    for (const field of REQUIRED) {
        const value = (input?.[field] ?? "").toString().trim();
        if (!value) return `${labelFor(field)} is required`;
    }

    const pincode = input.pincode.toString().trim();
    if (!PINCODE.test(pincode)) {
        return "Pincode must be 6 digits";
    }

    const phone = input.phone.toString().trim().replace(/[\s-]/g, "");
    if (!PHONE.test(phone)) {
        return "Enter a valid 10-digit phone number";
    }

    return null;
}

function labelFor(field) {
    return {
        addressLine: "Address",
        locality: "Locality",
        city: "City",
        state: "State",
        pincode: "Pincode",
        phone: "Phone number",
    }[field] ?? field;
}

function hasAddress(user) {
    return REQUIRED.every((f) => (user?.[f] ?? "").toString().trim() !== "");
}

/// The fields an order copies. Kept separate from the user document so the
/// snapshot never picks up unrelated profile changes.
function addressOf(user) {
    return {
        addressLine: user.addressLine ?? "",
        locality: user.locality ?? "",
        city: user.city ?? "",
        state: user.state ?? "",
        pincode: user.pincode ?? "",
        phone: user.phone ?? "",
    };
}

module.exports = { REQUIRED, validateAddress, hasAddress, addressOf };
