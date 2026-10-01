const express = require('express');
const AuthController = require('../controllers/auth.controller');
const { authenticate } = require('../middlewares/auth.middleware');

const router = express.Router();

// Public Authentication endpoints
router.post('/register', AuthController.register);
router.post('/login', AuthController.login);
router.post('/refresh', AuthController.refresh);
router.post('/password-reset', AuthController.requestPasswordReset);
router.post('/password-reset/confirm', AuthController.confirmPasswordReset);

// Authenticated Logout
router.post('/logout', authenticate, AuthController.logout);

module.exports = router;
