const express = require('express');
const HealthController = require('../controllers/health.controller');
const authRoutes = require('./auth.routes');
const cropRoutes = require('./crop.routes');
const adminRoutes = require('./admin.routes');
const scanRoutes = require('./scan.routes');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const router = express.Router();

// Health Check route
router.get('/health', HealthController.getHealth);

// Mount Auth routes
router.use('/auth', authRoutes);

// Mount Crops routes
router.use('/crops', cropRoutes);

// Mount Admin routes (strictly protected by admin middleware inside adminRoutes)
router.use('/admin', adminRoutes);

// Mount Gemini Plant Scanner & Disease Detection routes
router.use('/scan', scanRoutes);

// Mount DigiPay Payments routes
const paymentRoutes = require('./payment.routes');
router.use('/payments', paymentRoutes);

// Mount Mapbox Geolocation, Mapping & Routing routes
const mapRoutes = require('./map.routes');
router.use('/maps', mapRoutes);

// Mount Chat, Communities & Private Messaging routes
const chatRoutes = require('./chat.routes');
router.use('/chat', chatRoutes);

// Protected Verification Routes (RBAC verification checks)
router.get('/auth/test-role', authenticate, authorize(['farmer']), (req, res) => {
    res.status(200).json({
        status: 'success',
        message: 'Successfully accessed protected route designated for farmers',
        user: { id: req.user.id, email: req.user.email, role: req.user.role }
    });
});

router.get('/auth/test-admin-role', authenticate, authorize(['admin']), (req, res) => {
    res.status(200).json({
        status: 'success',
        message: 'Successfully accessed admin-restricted portal',
        user: { id: req.user.id, email: req.user.email, role: req.user.role }
    });
});

module.exports = router;
