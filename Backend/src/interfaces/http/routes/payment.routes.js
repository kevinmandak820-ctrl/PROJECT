const express = require('express');
const PaymentController = require('../controllers/payment.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');
const { verifyAccessToken } = require('../../../infrastructure/utils/auth.utils');
const { User } = require('../../../infrastructure/database/sequelize');

const router = express.Router();

/**
 * Optional authentication helper:
 * Attaches user to req.user if valid token provided, but allows unauthenticated guest checkout.
 */
async function optionalAuthenticate(req, res, next) {
    try {
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.split(' ')[1];
            const decoded = verifyAccessToken(token);
            if (decoded && decoded.id) {
                const user = await User.findByPk(decoded.id);
                if (user && user.status === 'active') {
                    req.user = user;
                }
            }
        }
    } catch (_) {}
    next();
}

/**
 * @route   POST /api/payments/initiate
 * @desc    Initiate a DigiPay Mobile Money payment (MTN / Orange Money)
 * @access  Public / Authenticated
 */
router.post('/initiate', optionalAuthenticate, PaymentController.initiatePayment);

/**
 * @route   GET /api/payments/status/:transactionId
 * @desc    Check transaction status live with DigiPay SDK
 * @access  Public
 */
router.get('/status/:transactionId', PaymentController.getPaymentStatus);

/**
 * @route   POST /api/payments/webhook
 * @desc    DigiPay asynchronous webhook notifications
 * @access  Public
 */
router.post('/webhook', PaymentController.handleWebhook);

/**
 * @route   GET /api/payments/history
 * @desc    Get user's payment history
 * @access  Authenticated
 */
router.get('/history', authenticate, PaymentController.getPaymentHistory);

/**
 * @route   GET /api/payments/balance
 * @desc    Get merchant settlement balance from DigiPay
 * @access  Admin only
 */
router.get('/balance', authenticate, authorize(['admin']), PaymentController.getBalance);

module.exports = router;
