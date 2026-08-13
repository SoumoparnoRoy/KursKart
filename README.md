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

| Method | Endpoint       | Auth            | Description                        |
| ------ | -------------- | --------------- | ---------------------------------- |
| POST   | `/api/signup`  | —               | Create an account                  |
| POST   | `/api/signin`  | —               | Sign in, returns a JWT (7 days)    |
| GET    | `/api/user`    | `x-auth-token`  | Current user for a stored token    |

Protected routes expect the JWT in an `x-auth-token` header. Passwords must be at
least 8 characters and emails are stored lowercased and uniquely indexed.

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
- Main navigation shell in place (Home, Cart, Orders, Profile — placeholders)
- Product catalogue, cart and orders not yet implemented

---

## Author

Soumoparno Roy
