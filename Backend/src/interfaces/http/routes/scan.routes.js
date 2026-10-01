const express = require('express');
const multer = require('multer');
const path = require('path');
const ScanController = require('../controllers/scan.controller');

const router = express.Router();

// Multer storage for uploaded crop scan images
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, path.join(__dirname, '../../../../uploads'));
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, 'scan-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

// Scan & Diagnose plant or crop image with Gemini AI
router.post('/diagnose', upload.single('image'), ScanController.diagnosePlant);

// Check Scanner & Gemini API connectivity
router.get('/status', (req, res) => {
    res.status(200).json({
        status: 'success',
        service: 'AgriMed Gemini Plant Scanner',
        provider: 'Google Gemini AI',
        status: 'ONLINE',
        models: ['gemini-3.5-flash', 'gemini-3.6-flash', 'gemini-3.8-flash']
    });
});

module.exports = router;
