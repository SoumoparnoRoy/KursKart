# KursKart

Full-Stack Multi-Store E-Commerce Application built using Flutter, Node.js, Express, and MongoDB.

---

## Overview

KursKart is a scalable multi-store e-commerce platform where multiple vendors can manage their stores, products, and orders within a unified system.

The project follows a full-stack architecture and is organised using a monorepo structure.

---

## Project Structure

```text
kurskart/
├── frontend/
│   └── lib/
│       ├── models/        # Data models
│       ├── providers/     # Riverpod state
│       ├── services/      # HTTP + secure token storage
│       └── views/
│           ├── screens/   # Auth screens, main nav shell
│           └── widgets/   # Auth gate, shared widgets
└── backend/
    ├── middlewares/       # JWT verification
    ├── models/            # Mongoose schemas
    └── routes/            # API routes
```

frontend/  - Flutter mobile application
backend/   - Node.js + Express + MongoDB API

---

## Tech Stack

### Frontend
- Flutter
- Dart
- Riverpod (state management)
- flutter_secure_storage (JWT storage)
- REST API Integration

### Backend
- Node.js
- Express.js
- MongoDB
- Mongoose
- JWT Authentication
- bcryptjs (password hashing)

---

## Running the Project

### Backend

Create a `backend/.env` file with:

```text
MONGO_URI = <your MongoDB connection string>
PORT = 3000
JWT_SECRET = <a long random string>
CLOUDINARY_CLOUD_NAME = <from the Cloudinary dashboard>
CLOUDINARY_API_KEY = <from the Cloudinary dashboard>
CLOUDINARY_API_SECRET = <from the Cloudinary dashboard>
```

See `backend/.env.example` for the full list, including the seeder-only
variables covered below. The server exits immediately with a clear message if
`MONGO_URI` or `JWT_SECRET` is missing. The three Cloudinary keys are only
warned about: without them everything works except image uploads, and that route
says so with a 503.

```bash
cd backend
npm install
npm start
```

Use `npm run dev` for auto-restart on file changes.

### Demo data

```bash
npm run seed
```

Re-runnable. It upserts two vendors with their stores and products, five demo
shoppers, a delivered order for each shopper and store, and the reviews those
orders entitle — so every star in the catalogue is backed by a real row rather
than a hardcoded number. The script prints the logins when it finishes.

`VENDOR_PASSWORD` and `SHOPPER_PASSWORD` must be set; there is no fallback and
the passwords are never printed. These are real credentials despite the made-up
catalogue behind them — a vendor login can read every customer name, address and
phone number on that store's orders — so they do not belong in the repository or
in terminal scrollback.

The seeder refuses to run under `NODE_ENV=production`, and for any `MONGO_URI`
that is not localhost it requires an explicit opt-in, because it overwrites
products, resets stock and rebuilds the demo order history:

```bash
SEED_ALLOW=yes npm run seed
```

To remove the demo accounts from a database that has already been seeded — for
instance to retire a password that has been shared or committed:

```bash
npm run seed:purge
```

It lists what it found and, against a non-local database, stops there unless
`SEED_ALLOW=yes` is set. It removes the accounts and their orders; stores,
products and reviews stay, so the catalogue keeps working and ratings keep the
reviews behind them. The seeded stores are simply left with no owner who can
sign in, and `npm run seed` re-owns them on the next run.

Seeded stores are matched on their **name**, not on `owner`. Owner looks like
the natural key but breaks as soon as an account is deleted and recreated: the
new user has a new id, no store matches it, and the seeder builds a duplicate
catalogue beside the original. If a database is already in that state:

```bash
npm run seed:repair
```

It drops duplicate seeded stores — keeping the copy that still has an owner and
carries the reviews — along with their products, and removes orders whose buyer
no longer exists. Same opt-in rule, and a no-op on a healthy database.

Products are matched on (store, name) and updated in place, so their ids survive
a reseed and open carts keep working. Reviews are matched on (product, user) for
the same reason, and because a review written by hand while signed in as a demo
shopper would otherwise collide with the seeded one. Seeding resets stock to the
seed values, and rebuilds the demo shoppers' order history from scratch.

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

The API base URL defaults to `http://10.0.2.2:3000`, which is the Android emulator's
alias for the host machine. To run against a backend on your LAN — for example on a
physical device — override it at launch (no code change needed):

```bash
flutter run --dart-define=API_URL=http://<your-computer-ip>:3000
```

Find your machine's LAN address with `ipconfig` on Windows or `ifconfig` on
macOS/Linux — it usually looks like `192.168.x.x`.

The same flag works for `flutter build apk`. The device and the machine running the
backend must be on the same network.

Plain http is enabled for debug and profile builds only, so release builds remain
https-only.

---

## API

| Method | Endpoint                        | Auth           | Description                          |
| ------ | ------------------------------- | -------------- | ------------------------------------ |
| POST   | `/api/signup`                   | —              | Create an account                    |
| POST   | `/api/signin`                   | —              | Sign in, returns a JWT (7 days)      |
| GET    | `/api/user`                     | `x-auth-token` | Current user for a stored token      |
| PATCH  | `/api/user/address`             | `x-auth-token` | Save the delivery address            |
| GET    | `/api/products`                 | —              | Feed; `page`, `limit`, `category`, `store`, `search` |
| GET    | `/api/products/categories`      | —              | Categories that have products        |
| GET    | `/api/products/:id`             | —              | Product detail                       |
| POST   | `/api/products`                 | vendor         | Create a product in your own store   |
| GET    | `/api/stores`                   | —              | Active stores                        |
| GET    | `/api/stores/:id`               | —              | Store profile and its products       |
| GET    | `/api/stores/mine`              | `x-auth-token` | Your own store                       |
| POST   | `/api/stores`                   | `x-auth-token` | Open a store; promotes you to vendor |
| PATCH  | `/api/stores/mine`              | `x-auth-token` | Edit your store                      |
| GET    | `/api/products/mine`            | vendor         | Your catalogue, incl. out of stock   |
| PATCH  | `/api/products/:id`             | vendor         | Edit a product in your own store     |
| DELETE | `/api/products/:id`             | vendor         | Delete a product from your own store |
| GET    | `/api/cart`                     | `x-auth-token` | Current cart                         |
| POST   | `/api/cart/items`               | `x-auth-token` | Add, or increment if already present |
| PATCH  | `/api/cart/items/:productId`    | `x-auth-token` | Set an exact quantity                |
| DELETE | `/api/cart/items/:productId`    | `x-auth-token` | Remove a line                        |
| DELETE | `/api/cart`                     | `x-auth-token` | Empty the cart                       |
| POST   | `/api/orders`                   | `x-auth-token` | Turn the cart into an order          |
| GET    | `/api/orders`                   | `x-auth-token` | Your orders, newest first            |
| GET    | `/api/orders/:id`               | `x-auth-token` | A single order you own               |
| PATCH  | `/api/orders/:id/cancel`        | `x-auth-token` | Cancel your own order while unshipped |
| GET    | `/api/orders/vendor`            | vendor         | Orders containing your products      |
| PATCH  | `/api/orders/:id/status`        | vendor         | Move your own lines along            |
| GET    | `/api/products/:id/reviews`     | —              | Reviews and the star distribution    |
| GET    | `/api/products/:id/reviews/mine`| `x-auth-token` | May you review it, and did you       |
| POST   | `/api/products/:id/reviews`     | `x-auth-token` | Review something delivered to you    |
| PATCH  | `/api/reviews/:id`              | `x-auth-token` | Edit your own review                 |
| DELETE | `/api/reviews/:id`              | `x-auth-token` | Delete your own review               |
| POST   | `/api/uploads/signature`        | vendor         | Permit to upload one product image   |

Every cart mutation returns the full cart, so a client never needs a follow-up
read. Prices are whole rupees stored as integers.

`search` is a case-insensitive substring match across product name and
description, so it works as the user types rather than only on whole words. It
does not use an index and is worth revisiting once the catalogue is large.

Placing an order reserves stock with a conditional update per product, so
simultaneous checkouts cannot oversell; if any line fails, the stock already
taken is put back and the cart is left untouched. Order lines copy the product
name, price and image at purchase time, so editing or deleting a product later
never rewrites past orders. The delivery address is copied the same way.

Each user has one delivery address. Checkout refuses without it, returning
`code: "ADDRESS_REQUIRED"` so the client can send the user to the form rather
than showing a raw error. Pincode and phone follow Indian formats.

Order status lives on each **line**, not on the order, because one order can
span several stores and a vendor may only move their own items. The order-level
`status` is rolled up from the lines on every write and stored so it can be
queried: an order is only as far along as its least advanced live line, and
counts as cancelled once nothing is left to deliver. Legal moves are
`placed → shipped → delivered` and `placed → cancelled`; the last two are
terminal. `GET /api/orders/vendor` trims every order to the caller's own lines
and recomputes the total from them, so a vendor never sees what another store
sold to the same customer. Cancelling — by either side — puts the reserved stock
back. A buyer cancels the whole order and only while nothing has shipped.

A product's `rating` and `ratingCount` are **derived from its reviews**, never
set by hand. Writing, editing or deleting a review recomputes both on the
product, so the feed can sort and display stars without joining reviews on every
read. A rating of 0 means unrated rather than terrible — check `ratingCount`
before showing stars.

Reviewing requires a **delivered** line for that product in one of your own
orders, which is why order status had to come first. Buying is not enough: a
cancelled order proves nothing. There is one review per person per product,
enforced by a unique index, so editing goes through `PATCH` rather than a second
row and the average cannot be stuffed by reviewing repeatedly.

Product images are uploaded **straight from the app to Cloudinary**. The backend
only signs the request: `POST /api/uploads/signature` returns a signature over a
folder scoped to the caller's own store, so a vendor cannot write anywhere else,
and the API secret never leaves the server. The bytes never pass through the
backend at all, which matters on Vercel, where a serverless request body is
capped well below what a phone camera produces. The product itself still stores
nothing but a URL, so pasted links and the seeded catalogue keep working
unchanged. Uploaded images are not deleted from Cloudinary when a product is
deleted or its photo replaced.

Owning a store is what makes an account a vendor — `POST /api/stores` sets the
role as a side effect, and there is one store per user. Vendor routes scope
every lookup to the caller's own store, so a valid product id belonging to
another store simply does not match.

Protected routes expect the JWT in an `x-auth-token` header. Passwords must be at
least 8 characters and emails are stored lowercased and uniquely indexed.

---

## Deployment

The backend is split so it runs both as a normal server and as a serverless
function:

```text
backend/
├── app.js          # the Express app: middleware, routers, exports the app
├── index.js        # local dev only — calls app.listen()
├── db.js           # cached Mongo connection, shared across warm invocations
├── api/index.js    # serverless entry point, exports the app
└── vercel.json     # routes every path to the function
```

To deploy on Vercel:

1. Import the repository and set **Root Directory** to `backend`.
2. Add `MONGO_URI` and `JWT_SECRET` as environment variables. Do not set `PORT`
   — the platform provides it.
3. In Atlas, add `0.0.0.0/0` to Network Access. Serverless IPs rotate, so an IP
   allowlist cannot work. The database stays password-protected.

Then point the app at it:

```bash
flutter build apk --release --dart-define=API_URL=https://your-app.vercel.app
```

`GET /api/health` answers without touching the database, so it can be used to
wake a sleeping function before a demo and as an uptime check.

Note that release builds are https-only by design, so they cannot talk to a
local `http://` backend — use a debug build for that.

---

## Testing

```bash
cd frontend
flutter test
flutter analyze
```

---

## Status

- Monorepo structure implemented
- Backend API with JWT authentication complete
- Sign up, sign in, session persistence and sign out working end to end
- Product catalogue with stores, seeded via `npm run seed`
- Home feed with category filter, and product detail pages
- Server-side cart: add, change quantity, remove, clear
- Checkout that reserves stock and records an immutable order
- Delivery address, editable in Profile and required at checkout
- Product search across name and description
- Vendor side: open a store from Profile, then add, edit and delete products
- Vendor Orders tab: incoming orders, with per-store status transitions
- Order detail screen, re-read from the server so a vendor's shipment shows
  without refreshing the list
- Buyers can cancel an order until it ships; cancelling restores stock
- Verified-purchase reviews, with product ratings derived from them
- Vendors upload a product photo from the camera or gallery, signed server-side
  and stored on Cloudinary; pasting a link still works as a fallback
- Not yet implemented: payments, and notifications — neither side is told when a
  status changes

---

## Author

Soumoparno Roy
