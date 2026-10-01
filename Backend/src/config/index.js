const dotenv = require('dotenv');
const path = require('path');

// Load environment variables from .env file
dotenv.config({ path: path.join(__dirname, '../../.env') });

module.exports = {
  port: process.env.PORT || 3000,
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'root',
    pass: process.env.DB_PASS || '',
    name: process.env.DB_NAME || 'digital_crop_db'
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || 'super_secret_access_key',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'super_secret_refresh_key',
    accessExpiration: process.env.JWT_ACCESS_EXPIRATION || '15m',
    refreshExpiration: process.env.JWT_REFRESH_EXPIRATION || '7d'
  },
  digipay: {
    apiKey: process.env.DIGIPAY_API_KEY || '',
    environment: process.env.DIGIPAY_ENV || 'production'
  },
  mapbox: {
    accessToken: process.env.MAPBOX_ACCESS_TOKEN || ''
  }
};
