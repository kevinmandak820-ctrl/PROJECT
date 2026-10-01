const http = require('http');
const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '../.env') });

const app = require('../src/interfaces/http/app');
const { sequelize, User, AgriculturalProduct } = require('../src/infrastructure/database/sequelize');

const PORT = 3002;
const BASE_URL = `http://localhost:${PORT}/api`;

let server;

function assert(condition, message) {
    if (!condition) {
        throw new Error(`Assertion failed: ${message}`);
    }
    console.log(`  ✓ Pass: ${message}`);
}

async function setup() {
    console.log('\n--- Setting up Crops verification environment ---');
    console.log('Syncing database models (alter: true)...');
    await sequelize.sync({ alter: true });
    console.log('Database schema synchronized.');

    server = http.createServer(app);
    await new Promise((resolve) => server.listen(PORT, resolve));
    console.log(`Test server running at http://localhost:${PORT}`);
}

async function teardown() {
    console.log('\n--- Tearing down verification environment ---');
    if (server) {
        await new Promise((resolve) => server.close(resolve));
        console.log('Closed test server.');
    }
    await sequelize.close();
    console.log('Closed database connection.');
}

async function runTests() {
    let farmerToken = '';
    let buyerToken = '';
    let testCropId = '';

    console.log('\n--- 1. Authenticating Test Users (Farmer & Buyer) ---');

    const farmerEmail = `farmer_${Date.now()}@test.com`;
    const buyerEmail = `buyer_${Date.now()}@test.com`;

    // Register Farmer
    const farmerRegRes = await fetch(`${BASE_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: 'Old MacDonald',
            email: farmerEmail,
            password: 'farmerPassword123!',
            role: 'farmer'
        })
    });
    const farmerRegData = await farmerRegRes.json();
    assert(farmerRegRes.status === 201, 'Farmer registered with 201');

    // Login Farmer to get Access Token
    const farmerLoginRes = await fetch(`${BASE_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            email: farmerEmail,
            password: 'farmerPassword123!'
        })
    });
    const farmerLoginData = await farmerLoginRes.json();
    assert(farmerLoginRes.status === 200, 'Farmer logged in with 200');
    farmerToken = farmerLoginData.data.accessToken;
    assert(!!farmerToken, 'Farmer token received');

    // Register Buyer
    const buyerRegRes = await fetch(`${BASE_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: 'City Buyer',
            email: buyerEmail,
            password: 'buyerPassword123!',
            role: 'customer' // customer role (non-farmer)
        })
    });
    assert(buyerRegRes.status === 201, 'Buyer registered with 201');

    // Login Buyer
    const buyerLoginRes = await fetch(`${BASE_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            email: buyerEmail,
            password: 'buyerPassword123!'
        })
    });
    const buyerLoginData = await buyerLoginRes.json();
    buyerToken = buyerLoginData.data.accessToken;
    assert(!!buyerToken, 'Buyer token received');

    console.log('\n--- 2. RBAC: Non-farmer blocked from creating crops ---');
    const buyerCreateRes = await fetch(`${BASE_URL}/crops`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${buyerToken}`
        },
        body: JSON.stringify({
            name: 'Unauthorized Crop',
            price: 15.00
        })
    });
    assert(buyerCreateRes.status === 403, 'Buyer receives 403 Forbidden when creating crop');

    console.log('\n--- 3. Farmer creates a crop (POST /api/crops) ---');
    const farmerCreateRes = await fetch(`${BASE_URL}/crops`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${farmerToken}`
        },
        body: JSON.stringify({
            name: 'Organic Aloe Vera',
            category: 'Medicinal',
            price: 12.50,
            quantity: 150.0,
            unit: 'kg',
            description: 'Fresh organic aloe vera leaves for cosmetic and medicinal uses.',
            imageUrl: 'assets/images/aloe_vera.png',
            status: 'available'
        })
    });
    const createData = await farmerCreateRes.json();
    assert(farmerCreateRes.status === 201, 'Farmer receives 201 Created');
    assert(createData.data.crop.name === 'Organic Aloe Vera', 'Crop name matches');
    assert(parseFloat(createData.data.crop.price) === 12.50, 'Crop price matches');
    assert(parseFloat(createData.data.crop.quantity) === 150.0, 'Crop quantity matches');
    assert(createData.data.crop.category === 'Medicinal', 'Crop category matches');
    testCropId = createData.data.crop.id;
    assert(!!testCropId, 'Crop UUID assigned');

    console.log('\n--- 4. Browse all crops (GET /api/crops) ---');
    const browseRes = await fetch(`${BASE_URL}/crops?category=Medicinal`);
    const browseData = await browseRes.json();
    assert(browseRes.status === 200, 'Browse crops returns 200');
    assert(Array.isArray(browseData.data.crops), 'Returned crops is an array');
    const found = browseData.data.crops.find((c) => c.id === testCropId);
    assert(!!found, 'Created crop is present in marketplace list');
    assert(found.farmer && found.farmer.name === 'Old MacDonald', 'Farmer information populated');

    console.log('\n--- 5. Farmer views own crops (GET /api/crops/my-crops) ---');
    const myCropsRes = await fetch(`${BASE_URL}/crops/my-crops`, {
        headers: { 'Authorization': `Bearer ${farmerToken}` }
    });
    const myCropsData = await myCropsRes.json();
    assert(myCropsRes.status === 200, 'My crops endpoint returns 200');
    assert(myCropsData.data.crops.some((c) => c.id === testCropId), 'Test crop present in farmer list');

    console.log('\n--- 6. Modify crop (PUT /api/crops/:id) ---');
    // Unauthorized user attempts modification
    const unauthorizedModRes = await fetch(`${BASE_URL}/crops/${testCropId}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${buyerToken}`
        },
        body: JSON.stringify({ price: 1.00 })
    });
    assert(unauthorizedModRes.status === 403, 'Non-owner blocked from modifying with 403 Forbidden');

    // Farmer modifies crop
    const farmerModRes = await fetch(`${BASE_URL}/crops/${testCropId}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${farmerToken}`
        },
        body: JSON.stringify({
            name: 'Organic Aloe Vera (Premium Grade)',
            price: 14.75,
            quantity: 200.0,
            description: 'Updated premium organic aloe vera harvested freshly this week.'
        })
    });
    const modData = await farmerModRes.json();
    assert(farmerModRes.status === 200, 'Farmer modifies crop with 200 OK');
    assert(modData.data.crop.name === 'Organic Aloe Vera (Premium Grade)', 'Crop name updated');
    assert(parseFloat(modData.data.crop.price) === 14.75, 'Crop price updated');
    assert(parseFloat(modData.data.crop.quantity) === 200.0, 'Crop quantity updated');

    console.log('\n--- 7. Bulk Upload crops (POST /api/crops/bulk) ---');
    const bulkRes = await fetch(`${BASE_URL}/crops/bulk`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${farmerToken}`
        },
        body: JSON.stringify({
            crops: [
                {
                    name: 'German Chamomile',
                    category: 'Medicinal',
                    price: 15.00,
                    quantity: 40,
                    unit: 'bundle',
                    description: 'Dried flower heads for herbal tea.'
                },
                {
                    name: 'Panax Ginseng Root',
                    category: 'Adaptogenic',
                    price: 42.00,
                    quantity: 25,
                    unit: 'kg',
                    description: 'Potent adaptogenic roots.'
                }
            ]
        })
    });
    const bulkData = await bulkRes.json();
    assert(bulkRes.status === 201, 'Bulk upload returns 201');
    assert(bulkData.data.count === 2, '2 crops created in bulk');

    console.log('\n--- 8. Upload Crop Image (Multipart / Form-Data) ---');
    // Create a temporary test image file
    const testImgPath = path.join(__dirname, 'test-crop.png');
    // Minimal 1x1 valid PNG binary buffer
    const pngBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
    );
    fs.writeFileSync(testImgPath, pngBuffer);

    // Build FormData
    const formData = new FormData();
    const fileBlob = new Blob([pngBuffer], { type: 'image/png' });
    formData.append('image', fileBlob, 'test-crop.png');

    const uploadRes = await fetch(`${BASE_URL}/crops/upload-image`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${farmerToken}`
        },
        body: formData
    });
    const uploadData = await uploadRes.json();
    assert(uploadRes.status === 200, 'Image upload returns 200 OK');
    assert(uploadData.data.imageUrl.startsWith('/uploads/crops/'), 'Image saved in /uploads/crops/');

    // Cleanup local test temp image
    if (fs.existsSync(testImgPath)) fs.unlinkSync(testImgPath);

    console.log('\n--- 9. Delete Crop (DELETE /api/crops/:id) ---');
    // Non-owner delete attempt
    const unauthDeleteRes = await fetch(`${BASE_URL}/crops/${testCropId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${buyerToken}` }
    });
    assert(unauthDeleteRes.status === 403, 'Non-owner receives 403 on delete');

    // Owner delete
    const ownerDeleteRes = await fetch(`${BASE_URL}/crops/${testCropId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${farmerToken}` }
    });
    assert(ownerDeleteRes.status === 200, 'Farmer receives 200 OK on delete');

    // Verify crop is deleted
    const verifyDeleteRes = await fetch(`${BASE_URL}/crops/${testCropId}`);
    assert(verifyDeleteRes.status === 404, 'Deleted crop returns 404 Not Found');

    console.log('\n=========================================');
    console.log('ALL CROPS ENDPOINT & RBAC TESTS PASSED!');
    console.log('=========================================\n');
}

async function main() {
    try {
        await setup();
        await runTests();
    } catch (err) {
        console.error('\nFAILED Crop verification tests:', err);
        process.exitCode = 1;
    } finally {
        await teardown();
    }
}

main();
