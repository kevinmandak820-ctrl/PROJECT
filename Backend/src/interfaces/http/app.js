const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const routes = require('./routes');

const app = express();

// Security and utility middlewares
app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' }
}));
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve uploaded static files
app.use('/uploads', express.static(path.join(__dirname, '../../../uploads')));

// Root endpoint
app.get('/', (req, res) => {
    res.status(200).json({
        name: 'AgriMed Link Backend API',
        status: 'online',
        version: '1.0.0',
        healthCheck: '/api/health',
        documentation: 'https://github.com/kevinmandak820-ctrl/PROJECT'
    });
});

// Routing
app.use('/api', routes);

// Global Error Handler
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        status: 'error',
        message: err.message || 'Internal Server Error'
    });
});

module.exports = app;
