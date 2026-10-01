require('dotenv').config();
const path = require('path');
const geminiService = require('../src/services/gemini.service');
const fs = require('fs');

async function verifyScan() {
    console.log('--- Testing Gemini Plant Scanner & Disease Detection ---');
    console.log('API Key configured:', geminiService.apiKey ? 'YES (Length: ' + geminiService.apiKey.length + ')' : 'NO');

    const testImagePath = path.resolve(__dirname, '../../Frontend/agrimed_link/assets/images/crop_moringa.jpg');
    if (!fs.existsSync(testImagePath)) {
        console.error('Test image not found at:', testImagePath);
        process.exit(1);
    }

    const imageBase64 = fs.readFileSync(testImagePath).toString('base64');
    console.log('Sending crop image to Gemini AI (multimodal vision)...');

    try {
        const result = await geminiService.analyzePlant({
            imageBase64,
            mimeType: 'image/jpeg'
        });

        console.log('✅ Gemini Scan Result:');
        console.log('Plant Name:        ', result.name);
        console.log('Botanical:         ', result.botanical);
        console.log('Family:            ', result.family);
        console.log('Confidence:        ', result.confidence);
        console.log('Health Status:     ', result.healthStatus);
        console.log('Is Healthy:        ', result.isHealthy);
        console.log('Pathogen:          ', result.pathogen);
        console.log('Active Compounds:  ', result.compounds);
        console.log('Base USD Price:    ', result.basePriceUSD, '/', result.unit);
        console.log('Proposed Treatment:', result.treatment);
        console.log('AI Model Used:     ', result.aiModel);
        console.log('\n--- SUCCESS: Gemini Plant Scanner is fully operational! ---');
    } catch (err) {
        console.error('❌ Verification failed:', err.message);
        process.exit(1);
    }
}

verifyScan();
