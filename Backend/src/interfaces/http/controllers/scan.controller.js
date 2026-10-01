const fs = require('fs');
const path = require('path');
const geminiService = require('../../../services/gemini.service');

class ScanController {
    /**
     * Diagnose a plant image via Gemini AI
     * POST /api/scan/diagnose
     */
    static async diagnosePlant(req, res) {
        try {
            let imageBase64 = null;
            let mimeType = 'image/jpeg';
            const { promptHint, imageBase64: bodyBase64, imagePath } = req.body || {};

            // 1. Check if file uploaded via multer
            if (req.file) {
                imageBase64 = fs.readFileSync(req.file.path).toString('base64');
                mimeType = req.file.mimetype || 'image/jpeg';
            }
            // 2. Check base64 string in body
            else if (bodyBase64) {
                imageBase64 = bodyBase64;
                if (bodyBase64.includes('data:image/png')) mimeType = 'image/png';
                else if (bodyBase64.includes('data:image/webp')) mimeType = 'image/webp';
            }
            // 3. Check if server local image path passed (e.g. from frontend assets/uploads)
            else if (imagePath) {
                const cleanPath = imagePath.replace(/^\/+/, '');
                const possibleLocations = [
                    path.resolve(__dirname, '../../../../uploads', path.basename(cleanPath)),
                    path.resolve(__dirname, '../../../../Frontend/agrimed_link', cleanPath),
                    path.resolve(__dirname, '../../../../Frontend/agrimed_link/assets/images', path.basename(cleanPath))
                ];

                for (const loc of possibleLocations) {
                    if (fs.existsSync(loc)) {
                        imageBase64 = fs.readFileSync(loc).toString('base64');
                        if (loc.endsWith('.png')) mimeType = 'image/png';
                        break;
                    }
                }
            }

            if (!imageBase64) {
                return res.status(400).json({
                    status: 'error',
                    message: 'No image provided. Please upload an image file or provide imageBase64/imagePath.'
                });
            }

            // Call Gemini multimodal vision AI
            const diagnosis = await geminiService.analyzePlant({
                imageBase64,
                mimeType,
                promptHint
            });

            // Calculate currency equivalents
            const baseUSD = typeof diagnosis.basePriceUSD === 'number' ? diagnosis.basePriceUSD : 12.0;
            const eurRate = 0.92;
            const fcfaRate = 605.0;

            const valuation = {
                usd: baseUSD,
                eur: parseFloat((baseUSD * eurRate).toFixed(2)),
                fcfa: Math.round(baseUSD * fcfaRate),
                formattedUSD: `$${baseUSD.toFixed(2)}`,
                formattedEUR: `€${(baseUSD * eurRate).toFixed(2)}`,
                formattedFCFA: `${Math.round(baseUSD * fcfaRate).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ')} FCFA`
            };

            res.status(200).json({
                status: 'success',
                message: 'Plant diagnosis completed successfully via Gemini AI',
                data: {
                    ...diagnosis,
                    valuation
                }
            });
        } catch (error) {
            console.error('[ScanController] Diagnosis failed:', error);
            res.status(500).json({
                status: 'error',
                message: error.message || 'Failed to complete AI plant diagnosis'
            });
        }
    }
}

module.exports = ScanController;
