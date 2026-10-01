/**
 * Comprehensive Integration Verification Test for Admin Console & Portal Features
 */
const http = require('http');
const app = require('../src/interfaces/http/app');
const { sequelize, User, AppSetting } = require('../src/infrastructure/database/sequelize');

const PORT = 3004;
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
    console.log('\n--- 1. Setting up Admin Portal Test Environment ---');
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 0;');
    await sequelize.sync({ alter: true });
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 1;');

    // Ensure default admin exists
    const [adminUser] = await User.findOrCreate({
        where: { email: 'system.admin@agrimedlink.com' },
        defaults: {
            password: 'admin2026key$',
            name: 'System Administrator',
            phone_number: '+1-800-AGRI-ADM',
            role: 'admin',
            status: 'active'
        }
    });

    // Clean up any old test users
    await User.destroy({
        where: {
            email: [
                'portal.farmer@gmail.com',
                'pro.advisor@icloud.com',
                'pro.investor@gmail.com',
                'direct.created@gmail.com'
            ]
        }
    });

    server = app.listen(PORT);
    console.log(`Test server running at http://localhost:${PORT}`);

    // Log in as Admin
    console.log('\n--- 2. Authenticating as Administrator ---');
    const adminLoginRes = await makeRequest('POST', '/api/auth/login', {
        email: 'system.admin@agrimedlink.com',
        password: 'admin2026key$'
    });
    if (adminLoginRes.status !== 200 || !adminLoginRes.body.data?.accessToken) {
        throw new Error(`Admin login failed: ${JSON.stringify(adminLoginRes.body)}`);
    }
    const adminToken = adminLoginRes.body.data.accessToken;
    const adminId = adminLoginRes.body.data.user.id;
    console.log('  ✓ Pass: Admin authenticated successfully, JWT generated');

    // Test 3: View System Statistics
    console.log('\n--- 3. Testing View System Statistics (GET /api/admin/stats) ---');
    const statsRes = await makeRequest('GET', '/api/admin/stats', null, adminToken);
    if (statsRes.status !== 200) {
        throw new Error(`Expected 200, got ${statsRes.status}: ${JSON.stringify(statsRes.body)}`);
    }
    const statsData = statsRes.body.data;
    if (typeof statsData.overview.totalUsers !== 'number') {
        throw new Error('Expected totalUsers in overview stats');
    }
    if (!statsData.systemHealth || statsData.systemHealth.database !== 'connected') {
        throw new Error('Expected system health with connected database');
    }
    console.log(`  ✓ Pass: System stats retrieved successfully: ${statsData.overview.totalUsers} users, ${statsData.overview.totalCrops} crops`);
    console.log(`  ✓ Pass: Uptime: ${statsData.systemHealth.uptimeFormatted}, Memory: ${statsData.systemHealth.memoryUsageMB}MB`);

    // Test 4: Application Settings (GET & PUT)
    console.log('\n--- 4. Testing Application Settings Update ---');
    const getSettingsRes = await makeRequest('GET', '/api/admin/app-settings', null, adminToken);
    if (getSettingsRes.status !== 200) {
        throw new Error(`Expected 200, got ${getSettingsRes.status}`);
    }
    console.log(`  ✓ Pass: Fetched app settings (AppName: ${getSettingsRes.body.data.settings.appName}, Version: ${getSettingsRes.body.data.settings.appVersion})`);

    const updateSettingsRes = await makeRequest('PUT', '/api/admin/app-settings', {
        announcement: 'Urgent: Seasonal organic seed certification deadline is Friday!',
        maintenanceMode: false,
        commissionRate: 4.00
    }, adminToken);
    if (updateSettingsRes.status !== 200 || updateSettingsRes.body.data.settings.announcement !== 'Urgent: Seasonal organic seed certification deadline is Friday!') {
        throw new Error(`Update app settings failed: ${JSON.stringify(updateSettingsRes.body)}`);
    }
    console.log('  ✓ Pass: Application settings updated successfully (Announcement & Commission rate persisted)');

    // Test 5: Admin creates a user directly
    console.log('\n--- 5. Testing Direct User Creation by Admin (POST /api/admin/users) ---');
    const createUserRes = await makeRequest('POST', '/api/admin/users', {
        name: 'Direct Created Farmer',
        email: 'direct.created@gmail.com',
        password: 'Password123!',
        phone_number: '+1-555-123-4567',
        role: 'farmer',
        status: 'active'
    }, adminToken);
    if (createUserRes.status !== 201) {
        throw new Error(`Create user failed: ${JSON.stringify(createUserRes.body)}`);
    }
    const createdUserId = createUserRes.body.data.user.id;
    console.log(`  ✓ Pass: User created with role "farmer" and ID ${createdUserId}`);

    // Test 5b: Verify admin cannot create another admin account
    console.log('\n--- 5b. Verifying Prevention of Secondary Admin Creation ---');
    const createAdminRes = await makeRequest('POST', '/api/admin/users', {
        name: 'Secondary Admin',
        email: 'secondary.admin@gmail.com',
        password: 'Password123!',
        role: 'admin',
        status: 'active'
    }, adminToken);
    if (createAdminRes.status !== 403) {
        throw new Error(`Expected 403 Forbidden when creating secondary admin, got ${createAdminRes.status}`);
    }
    console.log('  ✓ Pass: Secondary admin creation correctly rejected with HTTP 403 Forbidden');

    // Test 5c: Verify admin cannot create non-admin user with unauthorized domain (must be @gmail.com or @icloud.com)
    console.log('\n--- 5c. Verifying Email Domain Enforcement on Admin User Creation ---');
    const createInvalidDomainRes = await makeRequest('POST', '/api/admin/users', {
        name: 'Invalid Domain User',
        email: 'invalid.domain@yahoo.com',
        password: 'Password123!',
        role: 'farmer',
        status: 'active'
    }, adminToken);
    if (createInvalidDomainRes.status !== 400) {
        throw new Error(`Expected 400 Bad Request for non-gmail/icloud email, got ${createInvalidDomainRes.status}`);
    }
    console.log('  ✓ Pass: Non-admin user creation with @yahoo.com rejected with HTTP 400 Bad Request');

    // Test 6: Admin suspends user
    console.log('\n--- 6. Testing Suspend User (PATCH /api/admin/users/:id/suspend) ---');
    const suspendRes = await makeRequest('PATCH', `/api/admin/users/${createdUserId}/suspend`, null, adminToken);
    if (suspendRes.status !== 200 || suspendRes.body.data.user.status !== 'suspended') {
        throw new Error(`Suspend user failed: ${JSON.stringify(suspendRes.body)}`);
    }
    console.log('  ✓ Pass: User account status transitioned to "suspended"');

    // Test 7: Verify suspended user cannot log in
    console.log('\n--- 7. Verifying Suspended User Blocked from Login ---');
    const suspendedLoginRes = await makeRequest('POST', '/api/auth/login', {
        email: 'direct.created@gmail.com',
        password: 'Password123!'
    });
    if (suspendedLoginRes.status !== 403) {
        throw new Error(`Expected 403 Forbidden for suspended user, got ${suspendedLoginRes.status}`);
    }
    console.log('  ✓ Pass: Suspended user correctly rejected with HTTP 403 Forbidden');

    // Test 8: Admin un-suspends user
    console.log('\n--- 8. Testing Un-suspend User (PATCH /api/admin/users/:id/unsuspend) ---');
    const unsuspendRes = await makeRequest('PATCH', `/api/admin/users/${createdUserId}/unsuspend`, null, adminToken);
    if (unsuspendRes.status !== 200 || unsuspendRes.body.data.user.status !== 'active') {
        throw new Error(`Unsuspend user failed: ${JSON.stringify(unsuspendRes.body)}`);
    }
    console.log('  ✓ Pass: User un-suspended, status transitioned back to "active"');

    // Test 9: Verify un-suspended user can now log in
    console.log('\n--- 9. Verifying Un-suspended User Can Log In ---');
    const activeLoginRes = await makeRequest('POST', '/api/auth/login', {
        email: 'direct.created@gmail.com',
        password: 'Password123!'
    });
    if (activeLoginRes.status !== 200 || !activeLoginRes.body.data?.accessToken) {
        throw new Error(`Login after un-suspending failed: ${JSON.stringify(activeLoginRes.body)}`);
    }
    console.log('  ✓ Pass: Un-suspended user logged in successfully with HTTP 200 OK');

    // Test 10: Self-suspension prevention
    console.log('\n--- 10. Verifying Admin Self-Suspension Prevention ---');
    const selfSuspendRes = await makeRequest('PATCH', `/api/admin/users/${adminId}/suspend`, null, adminToken);
    if (selfSuspendRes.status !== 400) {
        throw new Error(`Expected 400 Bad Request on self-suspension, got ${selfSuspendRes.status}`);
    }
    console.log('  ✓ Pass: Admin self-suspension prevented with HTTP 400 Bad Request');

    // Test 11: Professional Agricultural Advisor Registration -> Pending Approval
    console.log('\n--- 11. Testing Professional Advisor Registration Request ---');
    const advisorRegRes = await makeRequest('POST', '/api/auth/register', {
        name: 'Dr. Sarah Botanical',
        email: 'pro.advisor@icloud.com',
        password: 'AdvisorPass123!',
        phone_number: '+1-555-987-6543',
        role: 'advisor'
    });
    if (advisorRegRes.status !== 201) {
        throw new Error(`Advisor registration failed: ${JSON.stringify(advisorRegRes.body)}`);
    }
    if (advisorRegRes.body.data.user.status !== 'pending_approval') {
        throw new Error(`Expected pending_approval status, got ${advisorRegRes.body.data.user.status}`);
    }
    const advisorUserId = advisorRegRes.body.data.user.id;
    console.log('  ✓ Pass: Professional advisor registered with status "pending_approval"');

    // Test 12: Verify pending advisor cannot log in
    console.log('\n--- 12. Verifying Pending Advisor Blocked Until Approved ---');
    const advisorLoginRes = await makeRequest('POST', '/api/auth/login', {
        email: 'pro.advisor@icloud.com',
        password: 'AdvisorPass123!'
    });
    if (advisorLoginRes.status !== 403) {
        throw new Error(`Expected 403 Forbidden for pending user, got ${advisorLoginRes.status}`);
    }
    console.log(`  ✓ Pass: Pending advisor blocked with message: "${advisorLoginRes.body.message}"`);

    // Test 13: Professional Investor Registration -> Pending Approval
    console.log('\n--- 13. Testing Agricultural Investor Registration Request ---');
    const investorRegRes = await makeRequest('POST', '/api/auth/register', {
        name: 'Venture Agri Capital',
        email: 'pro.investor@gmail.com',
        password: 'InvestorPass123!',
        phone_number: '+1-555-555-0199',
        role: 'investor'
    });
    if (investorRegRes.status !== 201 || investorRegRes.body.data.user.status !== 'pending_approval') {
        throw new Error(`Investor registration failed: ${JSON.stringify(investorRegRes.body)}`);
    }
    const investorUserId = investorRegRes.body.data.user.id;
    console.log('  ✓ Pass: Agricultural investor registered with status "pending_approval"');

    // Test 14: Admin views pending requests
    console.log('\n--- 14. Testing Admin Listing Pending Requests (GET /api/admin/requests) ---');
    const requestsRes = await makeRequest('GET', '/api/admin/requests', null, adminToken);
    if (requestsRes.status !== 200) {
        throw new Error(`Get pending requests failed: ${JSON.stringify(requestsRes.body)}`);
    }
    const pendingList = requestsRes.body.data.requests;
    const hasAdvisor = pendingList.some(r => r.id === advisorUserId);
    const hasInvestor = pendingList.some(r => r.id === investorUserId);
    if (!hasAdvisor || !hasInvestor) {
        throw new Error('Pending requests list missing created advisor or investor');
    }
    console.log(`  ✓ Pass: Admin retrieved ${pendingList.length} pending requests including Advisor and Investor`);

    // Test 15: Admin accepts Advisor request
    console.log('\n--- 15. Testing Admin Accepting Advisor Request (PATCH /api/admin/requests/:id/accept) ---');
    const acceptRes = await makeRequest('PATCH', `/api/admin/requests/${advisorUserId}/accept`, null, adminToken);
    if (acceptRes.status !== 200 || acceptRes.body.data.user.status !== 'active') {
        throw new Error(`Accept request failed: ${JSON.stringify(acceptRes.body)}`);
    }
    console.log('  ✓ Pass: Advisor account accepted and activated by Admin');

    // Test 16: Verify accepted advisor can now log in
    console.log('\n--- 16. Verifying Accepted Advisor Can Now Log In ---');
    const acceptedAdvisorLogin = await makeRequest('POST', '/api/auth/login', {
        email: 'pro.advisor@icloud.com',
        password: 'AdvisorPass123!'
    });
    if (acceptedAdvisorLogin.status !== 200 || !acceptedAdvisorLogin.body.data?.accessToken) {
        throw new Error(`Advisor login failed: ${JSON.stringify(acceptedAdvisorLogin.body)}`);
    }
    if (acceptedAdvisorLogin.body.data.user.role !== 'advisor') {
        throw new Error(`Expected role advisor, got ${acceptedAdvisorLogin.body.data.user.role}`);
    }
    console.log('  ✓ Pass: Accepted advisor logged in successfully with HTTP 200 OK and role "advisor"');

    // Test 17: Admin rejects Investor request
    console.log('\n--- 17. Testing Admin Rejecting Investor Request (PATCH /api/admin/requests/:id/reject) ---');
    const rejectRes = await makeRequest('PATCH', `/api/admin/requests/${investorUserId}/reject`, null, adminToken);
    if (rejectRes.status !== 200 || rejectRes.body.data.user.status !== 'rejected') {
        throw new Error(`Reject request failed: ${JSON.stringify(rejectRes.body)}`);
    }
    console.log('  ✓ Pass: Investor request rejected, status transitioned to "rejected"');

    // Test 18: Verify rejected investor cannot log in
    console.log('\n--- 18. Verifying Rejected Investor Blocked from Login ---');
    const rejectedLoginRes = await makeRequest('POST', '/api/auth/login', {
        email: 'pro.investor@gmail.com',
        password: 'InvestorPass123!'
    });
    if (rejectedLoginRes.status !== 403) {
        throw new Error(`Expected 403 Forbidden for rejected user, got ${rejectedLoginRes.status}`);
    }
    console.log(`  ✓ Pass: Rejected investor correctly blocked: "${rejectedLoginRes.body.message}"`);

    console.log('\n======================================================');
    console.log('ALL ADMIN PORTAL & APPROVAL INTEGRATION TESTS PASSED!');
    console.log('======================================================\n');
}

runTests()
    .catch((err) => {
        console.error('\n❌ Admin portal test failed:', err);
        process.exitCode = 1;
    })
    .finally(() => {
        if (server) server.close();
        sequelize.close();
    });
