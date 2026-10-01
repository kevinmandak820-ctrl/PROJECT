# Deploying AgriMed Link on Railway

This repository is pre-configured for **Railway** with:
- `Dockerfile` (Containerized Node.js 20 backend)
- `railway.json` (Automated build and health-check monitoring at `/api/health`)
- `sequelize.js` (Dynamic support for Railway's `MYSQL_URL` / `DATABASE_URL` environment variables)

---

## Method 1: Web Dashboard (Recommended - 2 Minutes)

### Step 1: Connect Your GitHub Repository
1. Go to [https://railway.com](https://railway.com) and log in.
2. Click **"New Project"** (top right).
3. Select **"Deploy from GitHub repo"**.
4. Select your repository: **`kevinmandak820-ctrl/PROJECT`**.
5. Click **"Deploy Now"**.

---

### Step 2: Add MySQL Database
The backend requires a MySQL database for Sequelize:
1. In your Railway project view, click the **"+ New"** button in the canvas.
2. Select **"Database"** -> **"Add MySQL"**.
3. Railway will provision a managed MySQL database and automatically generate:
   - `MYSQL_URL`
   - `MYSQLHOST`
   - `MYSQLPORT`
   - `MYSQLUSER`
   - `MYSQLPASSWORD`
   - `MYSQLDATABASE`
4. The backend's Sequelize connection automatically recognizes these variables.

---

### Step 3: Add Service Environment Variables
1. Click on your **Backend Service** box in Railway.
2. Navigate to the **"Variables"** tab.
3. (Optional) Add your platform secrets:
   ```env
   JWT_ACCESS_SECRET=your_jwt_access_secret_2026
   JWT_REFRESH_SECRET=your_jwt_refresh_secret_2026
   GEMINI_API_KEY=your_gemini_api_key
   DIGIPAY_API_KEY=your_digipay_api_key
   MAPBOX_ACCESS_TOKEN=your_mapbox_token
   ```

---

### Step 4: Generate Public Domain
1. In the **Backend Service** settings, go to the **"Settings"** tab.
2. Scroll to the **"Networking"** section.
3. Click **"Generate Domain"** (e.g. `https://project-production.up.railway.app`).
4. Test your live deployment:
   - Root endpoint: `https://<your-domain>.up.railway.app/`
   - Healthcheck: `https://<your-domain>.up.railway.app/api/health`

---

## Method 2: Railway CLI (Command Line)

You can also deploy and link directly using Railway CLI:

```bash
# 1. Login to your Railway account
npx @railway/cli login

# 2. Link or create a project
npx @railway/cli init

# 3. Add MySQL to your project
npx @railway/cli add -d mysql

# 4. Deploy your code
npx @railway/cli up
```
