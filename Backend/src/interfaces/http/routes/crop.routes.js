const express = require('express');
const CropController = require('../controllers/crop.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');
const upload = require('../middlewares/upload.middleware');

const router = express.Router();

// Public / Marketplace crop browsing
router.get('/', CropController.getAllCrops);

// Farmer personal crop inventory (must precede /:id to prevent route shadowing)
router.get('/my-crops', authenticate, authorize(['farmer', 'admin']), CropController.getMyCrops);

// Dedicated image upload endpoint
router.post(
    '/upload-image',
    authenticate,
    authorize(['farmer', 'admin']),
    upload.single('image'),
    CropController.uploadCropImage
);

// Bulk upload / import crops
router.post(
    '/bulk',
    authenticate,
    authorize(['farmer', 'admin']),
    CropController.bulkUploadCrops
);

// Single crop retrieval
router.get('/:id', CropController.getCropById);

// Create new crop (Farmer or Admin)
router.post(
    '/',
    authenticate,
    authorize(['farmer', 'admin']),
    upload.single('image'),
    CropController.createCrop
);

// Update/modify crop (Owner Farmer or Admin)
router.put(
    '/:id',
    authenticate,
    authorize(['farmer', 'admin']),
    upload.single('image'),
    CropController.updateCrop
);

// Delete crop (Owner Farmer or Admin)
router.delete(
    '/:id',
    authenticate,
    authorize(['farmer', 'admin']),
    CropController.deleteCrop
);

module.exports = router;
