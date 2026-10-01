/**
 * Integration & Model Verification Test for Email Domain Enforcement
 * Rule: All users except the administrator must have "@gmail.com" or "@icloud.com" when inserting their email.
 */
const { sequelize, User } = require('../src/infrastructure/database/sequelize');
const http = require('http');
const app = require('../src/interfaces/http/app');

const PORT = 3008;
const BASE_URL = `http://localhost:${PORT}/api`;
let server;

function assert(condition, message) {
    if (!condition) {
        throw new Error(`Assertion failed: ${message}`);
    }
    console.log(`  ✓ Pass: ${message}`);
}

async function runTests() {
    console.log('\n======================================================');
    console.log('STARTING EMAIL DOMAIN ENFORCEMENT VERIFICATION');
    console.log('======================================================');

    // 1. MODEL-LEVEL VALIDATION TESTS
    console.log('\n--- 1. Testing Sequelize User Model Validation ---');

    // Test 1a: Valid @gmail.com non-admin user
    const validGmailUser = User.build({
        email: 'test.farmer@gmail.com',
        password: 'Password123!',
        role: 'farmer'
    });
    await validGmailUser.validate();
    assert(true, 'Sequelize accepts non-admin with @gmail.com');

    // Test 1b: Valid @icloud.com non-admin user
    const validIcloudUser = User.build({
        email: 'test.advisor@icloud.com',
        password: 'Password123!',
        role: 'advisor'
    });
    await validIcloudUser.validate();
    assert(true, 'Sequelize accepts non-admin with @icloud.com');

    // Test 1c: Case-insensitivity and trimming
    const validUpperUser = User.build({
        email: '  TEST.BUYER@GMAIL.COM  ',
        password: 'Password123!',
        role: 'customer'
    });
    await validUpperUser.validate();
    assert(validUpperUser.email === 'test.buyer@gmail.com', 'Email is normalized to lowercase and trimmed');

    // Test 1d: System administrator exemption
    const adminUser = User.build({
        email: 'system.admin@agrimedlink.com',
        password: 'admin2026key$',
        role: 'admin'
    });
    await adminUser.validate();
    assert(true, 'Sequelize exempts designated system administrator');

    // Test 1e: Rejection of non-admin @yahoo.com
    let rejectedYahoo = false;
    try {
        const yahooUser = User.build({
            email: 'farmer@yahoo.com',
            password: 'Password123!',
            role: 'farmer'
        });
        await yahooUser.validate();
    } catch (err) {
        rejectedYahoo = true;
        assert(err.message.includes('@gmail.com or @icloud.com'), 'Validation error mentions @gmail.com or @icloud.com requirement');
    }
    assert(rejectedYahoo, 'Sequelize rejects non-admin with @yahoo.com');

    // Test 1f: Rejection of non-admin @agrimedlink.com
    let rejectedCustomOrg = false;
    try {
        const customOrgUser = User.build({
            email: 'farmer@agrimedlink.com',
            password: 'Password123!',
            role: 'farmer'
        });
        await customOrgUser.validate();
    } catch (err) {
        rejectedCustomOrg = true;
    }
    assert(rejectedCustomOrg, 'Sequelize rejects non-admin with @agrimedlink.com');

    // 2. HTTP CONTROLLER ENDPOINT TESTS
    console.log('\n--- 2. Testing HTTP Endpoints ---');
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(PORT, resolve));

    // Test 2a: /api/auth/register with @gmail.com
    const regGmailRes = await fetch(`${BASE_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: 'Alice Gmail',
            email: `test_alice_${Date.now()}@gmail.com`,
            password: 'Password123!',
            role: 'farmer'
        })
    });
    const regGmailData = await regGmailRes.json();
    assert(regGmailRes.status === 201, `Public registration with @gmail.com succeeded (got ${regGmailRes.status})`);

    // Test 2b: /api/auth/register with @icloud.com
    const regIcloudRes = await fetch(`${BASE_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: 'Bob iCloud',
            email: `test_bob_${Date.now()}@icloud.com`,
            password: 'Password123!',
            role: 'customer'
        })
    });
    assert(regIcloudRes.status === 201, `Public registration with @icloud.com succeeded (got ${regIcloudRes.status})`);

    // Test 2c: /api/auth/register with @yahoo.com rejects with 400
    const regYahooRes = await fetch(`${BASE_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: 'Charlie Yahoo',
            email: 'charlie@yahoo.com',
            password: 'Password123!',
            role: 'farmer'
        })
    });
    const regYahooData = await regYahooRes.json();
    assert(regYahooRes.status === 400, `Public registration with @yahoo.com rejected with 400 (got ${regYahooRes.status})`);
    assert(regYahooData.message.includes('@gmail.com') && regYahooData.message.includes('@icloud.com'), 'Error message specifies @gmail.com or @icloud.com');

    // Test 2d: /api/auth/register as admin is 403 Forbidden
    const regAdminRes = await fetch(`${BASE_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: 'Unauthorized Admin',
            email: 'rogue.admin@gmail.com',
            password: 'Password123!',
            role: 'admin'
        })
    });
    assert(regAdminRes.status === 403, `Admin self-registration prohibited with 403 (got ${regAdminRes.status})`);

    console.log('\n======================================================');
    console.log('ALL EMAIL DOMAIN ENFORCEMENT TESTS PASSED SUCCESSFULLY');
    console.log('======================================================\n');
}

runTests()
    .catch((err) => {
        console.error('\n❌ Verification failed:', err);
        process.exitCode = 1;
    })
    .finally(async () => {
        if (server) await new Promise((r) => server.close(r));
        await sequelize.close();
    });
