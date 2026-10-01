# Digital Crop Networking Application -- Backend Service

This service acts as the backend API for the Digital Crop Networking System. It is built using **Node.js**, **Express.js**, and **Sequelize ORM** communicating with a **MySQL** database.

The application follows a **Clean Architecture** pattern to isolate domain logic, HTTP routing interfaces, and database infrastructure concerns.

---

## Directory Structure

```text
Backend/
├── .env                  # Configuration variables (port, db credentials, etc.)
├── .env.example          # Template for required environment variables
├── index.js              # Application entry point & bootstrapping logic
├── package.json          # Node dependencies & npm commands
└── src/
    ├── config/           # Standardized configuration provider
    │   └── index.js
    ├── infrastructure/   # Interface to databases and external systems
    │   └── database/
    │       └── sequelize.js
    └── interfaces/       # Exposes endpoints, handles request routing & controllers
        └── http/
            ├── app.js
            ├── controllers/
            │   └── health.controller.js
            └── routes/
                └── index.js
```

---

## Architecture Overview

1. **Entry Point (`index.js`)**: Initializes system components by verifying database connectivity and spawning the Express listener.
2. **Configuration (`src/config`)**: Isolates environment variable reading (`dotenv`) and packages it into an accessible config object across files.
3. **Infrastructure (`src/infrastructure`)**:
   - Outlines data storage drivers, repositories, and Sequelize client operations.
   - Houses database connect/status utilities (`sequelize.js`).
4. **Interfaces (`src/interfaces`)**:
   - Handles the outside HTTP protocols.
   - **Controllers**: Evaluates incoming arguments, communicates with models/services, and formats responses (JSON).
   - **Routes**: Directs API requests (`/api/...`) to their appropriate controllers.
   - **Middlewares**: Protects operations, performs headers management (CORS, Helmet), and handles generic error reporting.

---

## Technologies Used

- **Express.js**: Fast, unopinionated, minimalist web framework for Node.js.
- **Sequelize**: Promise-based Node.js ORM for Postgres, MySQL, MariaDB, SQLite, and Microsoft SQL Server.
- **MySQL2**: Driver for mysql connection.
- **Helmet**: Secures Express apps by setting various HTTP response headers.
- **CORS**: Handles Cross-Origin Resource Sharing.
- **Dotenv**: Standard library for managing configuration settings from local Environment variables.

---

## Getting Started

### Prerequisites
- Node.js installed (v16+)
- MySQL server active

### Setup Instructions
1. Navigate to the backend directory:
   ```bash
   cd Backend
   ```

2. Duplicate `.env.example` as `.env` and configure your credentials:
   ```bash
   cp .env.example .env
   ```

3. Install dependencies:
   ```bash
   npm install
   ```

4. Start development web-server:
   ```bash
   npm run dev
   ```

5. Confirm application status by heading to:
   [http://localhost:3000/api/health](http://localhost:3000/api/health)
