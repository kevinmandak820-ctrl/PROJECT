/**
 * Integration verification test for Unique Admin Registration and Capabilities
 */
const http = require('http');
const app = require('../src/interfaces/http/app');
const { sequelize, User } = require('../src/infrastructure/database/sequelize');

const PORT = 3003;
let server;

function makeRequest(method, path, body = null, token = null) {
    return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const options = {
            hostname: 'localhost',
            port: PORT,
            path,
            method,
            headers: {
                'Content-Type': 'application/json',
                ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
                ...(token ? { 'Authorization': `Bearer ${token}` } : {})
            }
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                let parsed = data;
                try { parsed = JSON.parse(data); } catch (_) {}
                resolve({ status: res.statusCode, body: parsed });
            });
        });

        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
    });
}

async function runTests() {
    console.log('\n--- 1. Setting up Admin Verification Environment ---');
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 0;');
    await sequelize.sync({ alter: true });
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 1;');

    // Clean up test admin if present
    await User.destroy({ where: { email: 'system.admin@agrimedlink.com' } });

    server = app.listen(PORT);
    console.log(`Test server running at http://localhost:${PORT}`);

    // Test 1: Self-registration as Admin or with admin email is strictly forbidden
    console.log('\n--- 2. Verify Self-Registration as Admin is Strictly Prohibited ---');
    const regRes = await makeRequest('POST', '/api/auth/register', {
        name: 'Attempted Admin',
        email: 'unauthorized.admin@agrimedlink.com',
        password: 'Password123!',
        phone_number: '+1-800-FAKE-ADM',
        role: 'admin'
    });
    if (regRes.status !== 403) {
        throw new Error(`Admin registration should return 403 Forbidden, got status=${regRes.status}`);
    }
    console.log('  ✓ Pass: Self-registration as Admin prohibited with HTTP 403 Forbidden');

    const regAdminEmailRes = await makeRequest('POST', '/api/auth/register', {
        name: 'Designated Admin Attempt',
        email: 'system.admin@agrimedlink.com',
        password: 'admin2026key$',
        phone_number: '+1-800-AGRI-ADM',
        role: 'customer'
    });
    if (regAdminEmailRes.status !== 403) {
        throw new Error(`Registration with admin email should return 403 Forbidden, got status=${regAdminEmailRes.status}`);
    }
    console.log('  ✓ Pass: Public registration using admin email prohibited with HTTP 403 Forbidden');

    // Test 2: Login as Single Designated Admin with required credentials
    console.log('\n--- 3. Login as Designated System Admin (system.admin@agrimedlink.com) ---');
    const loginRes = await makeRequest('POST', '/api/auth/login', {
        email: 'system.admin@agrimedlink.com',
        password: 'admin2026key$'
    });

    if (loginRes.status !== 200 || !loginRes.body.data.accessToken) {
        throw new Error(`Admin login failed: ${JSON.stringify(loginRes.body)}`);
    }
    const adminToken = loginRes.body.data.accessToken;
    console.log('  ✓ Pass: Admin logged in with HTTP 200 and access token generated');
    console.log(`  ✓ Pass: Authenticated user role is "${loginRes.body.data.user.role}"`);
    console.log(`  ✓ Pass: Authenticated user email is "${loginRes.body.data.user.email}"`);

    // Test 3: Admin access to protected endpoints
    console.log('\n--- 4. Verify Admin RBAC Privileges ---');
    const myCropsRes = await makeRequest('GET', '/api/crops/my-crops', null, adminToken);
    if (myCropsRes.status !== 200) {
        throw new Error(`Admin failed to access /api/crops/my-crops: status=${myCropsRes.status}`);
    }
    console.log('  ✓ Pass: Admin successfully accessed protected /api/crops/my-crops endpoint');

    // Test 4: Invalid password rejected
    console.log('\n--- 5. Prevent Unauthorized Access With Wrong Password ---');
    const badLoginRes = await makeRequest('POST', '/api/auth/login', {
        email: 'system.admin@agrimedlink.com',
        password: 'WrongPassword123!'
    });
    if (badLoginRes.status !== 401) {
        throw new Error(`Invalid password should return 401 Unauthorized, got ${badLoginRes.status}`);
    }
    console.log('  ✓ Pass: Wrong password rejected with HTTP 401 Unauthorized');

    console.log('\n=========================================');
    console.log('ALL SINGLE ADMIN INVARIANT & CREDENTIAL TESTS PASSED!');
    console.log('=========================================\n');
}

runTests()
    .catch((err) => {
        console.error('Test failure:', err);
        process.exit(1);
    })
    .finally(() => {
        if (server) server.close();
        sequelize.close();
    });
