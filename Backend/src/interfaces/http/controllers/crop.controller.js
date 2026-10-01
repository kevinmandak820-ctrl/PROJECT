const { Op } = require('sequelize');
const path = require('path');
const fs = require('fs');
const { AgriculturalProduct, User } = require('../../../infrastructure/database/sequelize');

class CropController {
    /**
     * Create a new crop listing (Farmer or Admin)
     */
    static async createCrop(req, res) {
        try {
            const {
                name,
                price,
                category,
                quantity,
                unit,
                description,
                status,
                harvestDate
            } = req.body;

            if (!name || name.trim() === '') {
                return res.status(400).json({
                    status: 'error',
                    message: 'Crop name is required.'
                });
            }

            if (price === undefined || price === null || isNaN(Number(price)) || Number(price) < 0) {
                return res.status(400).json({
                    status: 'error',
                    message: 'A valid non-negative crop price is required.'
                });
            }

            // Image resolution: multer file takes priority, then body imageUrl
            let imageUrl = null;
            if (req.file) {
                imageUrl = `/uploads/crops/${req.file.filename}`;
            } else if (req.body.imageUrl && req.body.imageUrl.trim() !== '') {
                imageUrl = req.body.imageUrl.trim();
            }

            const crop = await AgriculturalProduct.create({
                farmerId: req.user.id,
                name: name.trim(),
                price: parseFloat(price),
                category: category && category.trim() !== '' ? category.trim() : 'General',
                quantity: quantity !== undefined && !isNaN(Number(quantity)) ? parseFloat(quantity) : 0,
                unit: unit && unit.trim() !== '' ? unit.trim() : 'kg',
                description: description ? description.trim() : null,
                imageUrl,
                status: status || 'available',
                harvestDate: harvestDate || null
            });

            return res.status(201).json({
                status: 'success',
                message: 'Crop created successfully',
                data: { crop }
            });
        } catch (error) {
            console.error('Error creating crop:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Internal server error while creating crop: ' + error.message
            });
        }
    }

    /**
     * Get all active marketplace crops with optional filtering
     */
    static async getAllCrops(req, res) {
        try {
            const { q, category, status, farmerId } = req.query;
            const whereClause = {};

            if (q && q.trim() !== '') {
                whereClause[Op.or] = [
                    { name: { [Op.like]: `%${q.trim()}%` } },
                    { description: { [Op.like]: `%${q.trim()}%` } }
                ];
            }

            if (category && category.trim() !== '' && category.toLowerCase() !== 'all') {
                whereClause.category = category.trim();
            }

            if (status && status.trim() !== '' && status.toLowerCase() !== 'all') {
                whereClause.status = status.trim();
            }

            if (farmerId && farmerId.trim() !== '') {
                whereClause.farmerId = farmerId.trim();
            }

            const crops = await AgriculturalProduct.findAll({
                where: whereClause,
                include: [{
                    model: User,
                    as: 'farmer',
                    attributes: ['id', 'name', 'email', 'phone_number', 'rating']
                }],
                order: [['createdAt', 'DESC']]
            });

            return res.status(200).json({
                status: 'success',
                data: {
                    crops,
                    total: crops.length
                }
            });
        } catch (error) {
            console.error('Error retrieving crops:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Internal server error while retrieving crops: ' + error.message
            });
        }
    }

    /**
     * Get crops owned by the currently authenticated farmer
     */
    static async getMyCrops(req, res) {
        try {
            const crops = await AgriculturalProduct.findAll({
                where: { farmerId: req.user.id },
                include: [{
                    model: User,
                    as: 'farmer',
                    attributes: ['id', 'name', 'email', 'phone_number', 'rating']
                }],
                order: [['createdAt', 'DESC']]
            });

            return res.status(200).json({
                status: 'success',
                data: {
                    crops,
                    total: crops.length
                }
            });
        } catch (error) {
            console.error('Error retrieving farmer crops:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Internal server error while retrieving your crops: ' + error.message
            });
        }
    }

    /**
     * Get single crop by UUID
     */
    static async getCropById(req, res) {
        try {
            const { id } = req.params;
            const crop = await AgriculturalProduct.findByPk(id, {
                include: [{
                    model: User,
                    as: 'farmer',
                    attributes: ['id', 'name', 'email', 'phone_number', 'rating']
                }]
            });

            if (!crop) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Crop not found with provided identifier.'
                });
            }

            return res.status(200).json({
                status: 'success',
                data: { crop }
            });
        } catch (error) {
            console.error('Error retrieving crop by ID:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Internal server error while retrieving crop: ' + error.message
            });
        }
    }

    /**
     * Modify an existing crop (Owner or Admin only)
     */
    static async updateCrop(req, res) {
        try {
            const { id } = req.params;
            const crop = await AgriculturalProduct.findByPk(id);

            if (!crop) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Crop not found.'
                });
            }

            // Verify ownership: must be the creator farmer or system admin
            if (crop.farmerId !== req.user.id && req.user.role !== 'admin') {
                return res.status(403).json({
                    status: 'error',
                    message: 'Forbidden: You are not authorized to modify this crop listing.'
                });
            }

            const {
                name,
                price,
                category,
                quantity,
                unit,
                description,
                status,
                harvestDate,
                imageUrl: bodyImageUrl
            } = req.body;

            if (name !== undefined) {
                if (name.trim() === '') {
                    return res.status(400).json({
                        status: 'error',
                        message: 'Crop name cannot be empty.'
                    });
                }
                crop.name = name.trim();
            }

            if (price !== undefined) {
                if (isNaN(Number(price)) || Number(price) < 0) {
                    return res.status(400).json({
                        status: 'error',
                        message: 'Price must be a valid non-negative number.'
                    });
                }
                crop.price = parseFloat(price);
            }

            if (category !== undefined) crop.category = category.trim();
            if (quantity !== undefined && !isNaN(Number(quantity))) crop.quantity = parseFloat(quantity);
            if (unit !== undefined) crop.unit = unit.trim();
            if (description !== undefined) crop.description = description ? description.trim() : null;
            if (status !== undefined) crop.status = status;
            if (harvestDate !== undefined) crop.harvestDate = harvestDate || null;

            // Handle image update
            if (req.file) {
                crop.imageUrl = `/uploads/crops/${req.file.filename}`;
            } else if (bodyImageUrl !== undefined) {
                crop.imageUrl = bodyImageUrl ? bodyImageUrl.trim() : null;
            }

            await crop.save();

            // Fetch with farmer included for complete response
            const updatedCrop = await AgriculturalProduct.findByPk(crop.id, {
                include: [{
                    model: User,
                    as: 'farmer',
                    attributes: ['id', 'name', 'email', 'phone_number', 'rating']
                }]
            });

            return res.status(200).json({
                status: 'success',
                message: 'Crop updated successfully',
                data: { crop: updatedCrop }
            });
        } catch (error) {
            console.error('Error updating crop:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Internal server error while modifying crop: ' + error.message
            });
        }
    }

    /**
     * Delete an existing crop (Owner or Admin only)
     */
    static async deleteCrop(req, res) {
        try {
            const { id } = req.params;
            const crop = await AgriculturalProduct.findByPk(id);

            if (!crop) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Crop not found.'
                });
            }

            // Verify ownership
            if (crop.farmerId !== req.user.id && req.user.role !== 'admin') {
                return res.status(403).json({
                    status: 'error',
                    message: 'Forbidden: You are not authorized to delete this crop listing.'
                });
            }

            // Attempt to remove local image file if present in uploads
            if (crop.imageUrl && crop.imageUrl.startsWith('/uploads/crops/')) {
                const localFilePath = path.join(__dirname, '../../../../', crop.imageUrl);
                if (fs.existsSync(localFilePath)) {
                    try {
                        fs.unlinkSync(localFilePath);
                    } catch (fsErr) {
                        console.warn('Could not delete crop image file:', fsErr.message);
                    }
                }
            }

            await crop.destroy();

            return res.status(200).json({
                status: 'success',
                message: 'Crop deleted successfully from inventory.'
            });
        } catch (error) {
            console.error('Error deleting crop:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Internal server error while deleting crop: ' + error.message
            });
        }
    }

    /**
     * Upload an image independently and receive its public URL
     */
    static async uploadCropImage(req, res) {
        try {
            if (!req.file) {
                return res.status(400).json({
                    status: 'error',
                    message: 'No image file uploaded.'
                });
            }

            const imageUrl = `/uploads/crops/${req.file.filename}`;
            return res.status(200).json({
                status: 'success',
                message: 'Crop image uploaded successfully.',
                data: {
                    imageUrl,
                    filename: req.file.filename,
                    size: req.file.size
                }
            });
        } catch (error) {
            console.error('Error uploading crop image:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Internal server error while uploading crop image: ' + error.message
            });
        }
    }

    /**
     * Bulk upload/import crops for rapid farmer inventory creation
     */
    static async bulkUploadCrops(req, res) {
        try {
            const { crops } = req.body;

            if (!crops || !Array.isArray(crops) || crops.length === 0) {
                return res.status(400).json({
                    status: 'error',
                    message: 'An array of crops is required for bulk upload.'
                });
            }

            const preparedCrops = [];
            for (let i = 0; i < crops.length; i++) {
                const item = crops[i];
                if (!item.name || item.name.trim() === '') {
                    return res.status(400).json({
                        status: 'error',
                        message: `Item at index ${i} is missing a required name.`
                    });
                }
                if (item.price === undefined || isNaN(Number(item.price)) || Number(item.price) < 0) {
                    return res.status(400).json({
                        status: 'error',
                        message: `Item "${item.name}" has an invalid price.`
                    });
                }

                preparedCrops.push({
                    farmerId: req.user.id,
                    name: item.name.trim(),
                    price: parseFloat(item.price),
                    category: item.category ? item.category.trim() : 'General',
                    quantity: item.quantity !== undefined && !isNaN(Number(item.quantity)) ? parseFloat(item.quantity) : 0,
                    unit: item.unit ? item.unit.trim() : 'kg',
                    description: item.description ? item.description.trim() : null,
                    imageUrl: item.imageUrl ? item.imageUrl.trim() : null,
                    status: item.status || 'available',
                    harvestDate: item.harvestDate || null
                });
            }

            const createdCrops = await AgriculturalProduct.bulkCreate(preparedCrops);

            return res.status(201).json({
                status: 'success',
                message: `Successfully imported ${createdCrops.length} crops.`,
                data: {
                    crops: createdCrops,
                    count: createdCrops.length
                }
            });
        } catch (error) {
            console.error('Error in bulk crop upload:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Internal server error during bulk crop upload: ' + error.message
            });
        }
    }
}

module.exports = CropController;
