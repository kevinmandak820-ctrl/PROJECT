const http = require('http');
// Load environment variables for the test profile before loading app config
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '../.env') });

const app = require('../src/interfaces/http/app');
const { sequelize } = require('../src/infrastructure/database/sequelize');

const PORT = 3001;
const BASE_URL = `http://localhost:${PORT}/api`;

let server;

// Helper assertion function
function assert(condition, message) {
    if (!condition) {
        throw new Error(`Assertion failed: ${message}`);
    }
    console.log(`  ✓ Pass: ${message}`);
}

async function setup() {
    console.log('\n--- Setting up verification environment ---');
    console.log('Syncing database...');
    // Recreate database tables to ensure clean test state
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 0');
    await sequelize.sync({ force: true });
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 1');

    console.log('Starting Test HTTP Server...');
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(PORT, resolve));
    console.log(`Test HTTP Server running at http://localhost:${PORT}`);
}

async function teardown() {
    console.log('\n--- Tearing down verification environment ---');
    if (server) {
        await new Promise((resolve) => server.close(resolve));
        console.log('Closed Test HTTP Server.');
    }
    await sequelize.close();
    console.log('Closed Database connections.');
}

async function runTests() {
    let accessToken = '';
    let refreshToken = '';

    console.log('\n--- Running Authentication Endpoint Tests ---');

    // 1. REGISTRATION TEST: Success with @gmail.com
    try {
        console.log('Testing User Registration (farmer role with @gmail.com)...');
        const res = await fetch(`${BASE_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: 'farmer_john@gmail.com',
                password: 'password123',
                role: 'farmer'
            })
        });

        const data = await res.json();
        assert(res.status === 201, `Register responds with status 201 (got ${res.status})`);
        assert(data.status === 'success', `Register responds with success status`);
        assert(data.data.user.email === 'farmer_john@gmail.com', `Returned email is correct`);
        assert(data.data.user.role === 'farmer', `Returned role is correct`);
        assert(data.data.user.status === 'active', `Returned user status is active`);
        assert(!data.data.user.password, `Hashed password is not returned in user payload`);
    } catch (err) {
        console.error('Registration Test Failed:', err);
        throw err;
    }

    // 1b. REGISTRATION TEST: Success with @icloud.com
    try {
        console.log('Testing User Registration (customer role with @icloud.com)...');
        const res = await fetch(`${BASE_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: 'buyer_sarah@icloud.com',
                password: 'password123',
                role: 'customer'
            })
        });

        const data = await res.json();
        assert(res.status === 201, `Register responds with status 201 for @icloud.com`);
        assert(data.status === 'success', `Register responds with success status`);
        assert(data.data.user.email === 'buyer_sarah@icloud.com', `Returned @icloud.com email is correct`);
    } catch (err) {
        console.error('Registration with @icloud.com Test Failed:', err);
        throw err;
    }

    // 1c. REGISTRATION TEST: Non-admin email domain rejection (e.g. @yahoo.com or @example.com)
    try {
        console.log('Testing User Registration (invalid domain rejection for non-admin)...');
        const res = await fetch(`${BASE_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: 'unauthorized_domain@yahoo.com',
                password: 'password123',
                role: 'farmer'
            })
        });

        const data = await res.json();
        assert(res.status === 400, `Non-admin with @yahoo.com domain rejected with 400 (got ${res.status})`);
        assert(data.status === 'error', `Rejection returned error status`);
        assert(data.message.includes('@gmail.com') || data.message.includes('@icloud.com'), `Message specifies @gmail.com or @icloud.com requirement`);
    } catch (err) {
        console.error('Non-admin Domain Rejection Test Failed:', err);
        throw err;
    }

    // 2. REGISTRATION TEST: Double Signup Failure
    try {
        console.log('Testing User Registration (duplicate email)...');
        const res = await fetch(`${BASE_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: 'FARMER_JOHN@GMAIL.COM', // test case insensitivity/trimming
                password: 'anotherPassword',
                role: 'farmer'
            })
        });

        const data = await res.json();
        assert(res.status === 400, `Duplicate register responds with status 400 (got ${res.status})`);
        assert(data.status === 'error', `Duplicate register returns error payload`);
        assert(data.message.includes('already registered'), `Error message indicates duplication`);
    } catch (err) {
        console.error('Duplicate Registration Test Failed:', err);
        throw err;
    }

    // 2b. REGISTRATION SECURITY TEST: Admin Registration Attempt Prohibited
    try {
        console.log('Testing User Registration (prohibited admin role attempt)...');
        const res = await fetch(`${BASE_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: 'hacker_admin@gmail.com',
                password: 'password123',
                role: 'admin'
            })
        });

        const data = await res.json();
        assert(res.status === 403, `Admin registration responds with status 403 Forbidden (got ${res.status})`);
        assert(data.status === 'error', `Admin registration returns error payload`);
        assert(data.message.includes('prohibited'), `Error message clearly states admin registration is prohibited`);
    } catch (err) {
        console.error('Admin Registration Prohibited Test Failed:', err);
        throw err;
    }

    // 3. LOGIN TEST: Password Mismatch
    try {
        console.log('Testing User Login (invalid credentials)...');
        const res = await fetch(`${BASE_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: 'farmer_john@gmail.com',
                password: 'wrongpassword'
            })
        });

        const data = await res.json();
        assert(res.status === 401, `Failed login responds with status 401 (got ${res.status})`);
        assert(data.status === 'error', `Failed login returns error status`);
    } catch (err) {
        console.error('Login Failure Test Failed:', err);
        throw err;
    }

    // 4. LOGIN TEST: Success
    try {
        console.log('Testing User Login (valid credentials)...');
        const res = await fetch(`${BASE_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: 'farmer_john@gmail.com',
                password: 'password123'
            })
        });

        const data = await res.json();
        assert(res.status === 200, `Login responds with status 200 (got ${res.status})`);
        assert(data.status === 'success', `Login responds with success status`);
        assert(data.data.accessToken, `Access token was returned`);
        assert(data.data.refreshToken, `Refresh token was returned`);

        accessToken = data.data.accessToken;
        refreshToken = data.data.refreshToken;
    } catch (err) {
        console.error('Login Success Test Failed:', err);
        throw err;
    }

    // 5. PROTECTED ROUTE TEST: Auth Missing
    try {
        console.log('Testing Protected Route (no auth token)...');
        const res = await fetch(`${BASE_URL}/auth/test-role`);
        const data = await res.json();
        assert(res.status === 401, `Unauthenticated request to protected route returns 401 (got ${res.status})`);
        assert(data.status === 'error', `Unauthenticated request returns error payload`);
    } catch (err) {
        console.error('Missing Auth Verification Failed:', err);
        throw err;
    }

    // 6. PROTECTED ROUTE TEST: Farmer Authorized Access
    try {
        console.log('Testing Protected Farmer Route (with authentic farmer token)...');
        const res = await fetch(`${BASE_URL}/auth/test-role`, {
            headers: { 'Authorization': `Bearer ${accessToken}` }
        });

        const data = await res.json();
        assert(res.status === 200, `Authorized access responds with 200 (got ${res.status})`);
        assert(data.status === 'success', `Authorized access returns success status`);
        assert(data.user.role === 'farmer', `User object correctly attached to request`);
    } catch (err) {
        console.error('Famer RBAC Authentication Failed:', err);
        throw err;
    }

    // 7. PROTECTED ROUTE TEST: Forbidden Access (Farmer trying to access Admin endpoint)
    try {
        console.log('Testing Protected Admin Route (with farmer token)...');
        const res = await fetch(`${BASE_URL}/auth/test-admin-role`, {
            headers: { 'Authorization': `Bearer ${accessToken}` }
        });

        const data = await res.json();
        assert(res.status === 403, `Forbidden access responds with 403 (got ${res.status})`);
        assert(data.status === 'error', `Forbidden access returns error status`);
        assert(data.message.includes('Forbidden'), `Message indicates forbidden access`);
    } catch (err) {
        console.error('Admin RBAC Forbidden Block Verification Failed:', err);
        throw err;
    }

    // 8. TOKEN REFRESH TEST: Success
    try {
        console.log('Testing Token Refresh...');
        // Wait 1 second to ensure 'iat' (issued at) claim updates, yielding a different token signature
        await new Promise((resolve) => setTimeout(resolve, 1000));
        const res = await fetch(`${BASE_URL}/auth/refresh`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ refreshToken })
        });

        const data = await res.json();
        assert(res.status === 200, `Refresh responds with status 200 (got ${res.status})`);
        assert(data.status === 'success', `Refresh returns success status`);
        assert(data.data.accessToken, `New access token is returned`);
        assert(data.data.accessToken !== accessToken, `New access token is different from old access token`);

        // Update token for subsequent request
        accessToken = data.data.accessToken;
    } catch (err) {
        console.error('Token Refresh Test Failed:', err);
        throw err;
    }

    // 9. PASSWORD RESET REQUEST: Stub Success
    try {
        console.log('Testing Password Reset Request Stub...');
        const res = await fetch(`${BASE_URL}/auth/password-reset`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: 'farmer_john@gmail.com' })
        });

        const data = await res.json();
        assert(res.status === 200, `Password reset requests return 200`);
        assert(data.status === 'success', `Password reset request responds with success status`);
        assert(data.message.includes('simulated'), `Reverts back with mock status message`);
    } catch (err) {
        console.error('Password Reset Request Test Failed:', err);
        throw err;
    }

    // 10. PASSWORD RESET CONFIRM: Stub Success
    try {
        console.log('Testing Password Reset Confirmation Stub...');
        const res = await fetch(`${BASE_URL}/auth/password-reset/confirm`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ token: 'simulated_token', newPassword: 'newpassword123' })
        });

        const data = await res.json();
        assert(res.status === 200, `Password reset confirmation returns 200`);
        assert(data.status === 'success', `Password reset confirmation responds with success status`);
    } catch (err) {
        console.error('Password Reset Confirmation Test Failed:', err);
        throw err;
    }

    // 11. LOGOUT TEST: Success
    try {
        console.log('Testing Logout...');
        const res = await fetch(`${BASE_URL}/auth/logout`, {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${accessToken}` }
        });

        const data = await res.json();
        assert(res.status === 200, `Logout responds with status 200 (got ${res.status})`);
        assert(data.status === 'success', `Logout returns success status`);
    } catch (err) {
        console.error('Logout Test Failed:', err);
        throw err;
    }
}

async function main() {
    try {
        await setup();
        await runTests();
        console.log('\n=========================================');
        console.log('ALL API VALIDATIONS COMPLETED SUCCESSFULLY');
        console.log('=========================================');
    } catch (error) {
        console.error('\n=========================================');
        console.error('VERIFICATION RUN ENCOUNTERED FAILURES');
        console.error(error.message);
        console.error('=========================================');
        process.exitCode = 1;
    } finally {
        await teardown();
    }
}

main();
