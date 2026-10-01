const express = require('express');
const AdminController = require('../controllers/admin.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const router = express.Router();

// Enforce authentication and Admin role for all /admin routes
router.use(authenticate);
router.use(authorize(['admin']));

// System Statistics
router.get('/stats', AdminController.getStats);

// User Management
router.get('/users', AdminController.getUsers);
router.post('/users', AdminController.createUser);
router.patch('/users/:id/suspend', AdminController.suspendUser);
router.patch('/users/:id/unsuspend', AdminController.unsuspendUser);

// Professional Requests (Advisor & Investor approvals)
router.get('/requests', AdminController.getPendingRequests);
router.patch('/requests/:id/accept', AdminController.acceptRequest);
router.patch('/requests/:id/reject', AdminController.rejectRequest);

// Application Settings & Updates
router.get('/app-settings', AdminController.getAppSettings);
router.put('/app-settings', AdminController.updateAppSettings);

module.exports = router;
