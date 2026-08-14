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
```

The server exits immediately with a clear message if `MONGO_URI` or `JWT_SECRET` is missing.

```bash
cd backend
npm install
npm start
```

Use `npm run dev` for auto-restart on file changes.

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
| GET    | `/api/cart`                     | `x-auth-token` | Current cart                         |
| POST   | `/api/cart/items`               | `x-auth-token` | Add, or increment if already present |
| PATCH  | `/api/cart/items/:productId`    | `x-auth-token` | Set an exact quantity                |
| DELETE | `/api/cart/items/:productId`    | `x-auth-token` | Remove a line                        |
| DELETE | `/api/cart`                     | `x-auth-token` | Empty the cart                       |
| POST   | `/api/orders`                   | `x-auth-token` | Turn the cart into an order          |
| GET    | `/api/orders`                   | `x-auth-token` | Your orders, newest first            |
| GET    | `/api/orders/:id`               | `x-auth-token` | A single order you own               |

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
- Payments, delivery addresses and a vendor UI not yet implemented

---

## Author

Soumoparno Roy
