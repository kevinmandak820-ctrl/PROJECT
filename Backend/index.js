const app = require('./src/interfaces/http/app');
const config = require('./src/config');
const { sequelize, testConnection } = require('./src/infrastructure/database/sequelize');

const host = '0.0.0.0';
const primaryPort = parseInt(process.env.PORT || config.port || 3000, 10);

// 1. Immediately bind and start HTTP server so Railway healthchecks pass in <100ms
const server = app.listen(primaryPort, host, () => {
    console.log(`Server is running in environment: ${process.env.NODE_ENV || 'production'}`);
    console.log(`Listening on http://${host}:${primaryPort}`);
    console.log(`Health endpoint: http://${host}:${primaryPort}/api/health`);
});

// Also bind secondary port 8080 if primary is different to guarantee ingress routing
if (primaryPort !== 8080) {
    try {
        const secondary = app.listen(8080, host, () => {
            console.log(`Auxiliary ingress port listening on http://${host}:8080`);
        });
        secondary.on('error', () => { /* ignore if port 8080 is unavailable */ });
    } catch (_) {}
}

// 2. Initialize database asynchronously in the background
async function bootstrapDatabase() {
    console.log('Bootstrapping backend database in background...');

    // Test database connection with 4s timeout
    const dbHealth = await testConnection(4000);
    console.log(dbHealth.message);

    if (dbHealth.connected) {
        try {
            console.log('Synchronizing database models...');
            await sequelize.sync();
            console.log('Database schema synchronized successfully.');

            // Seed and enforce unique System Admin
            const { User, AppSetting } = require('./src/infrastructure/database/sequelize');
            const { Op } = require('sequelize');

            // 1. Enforce single-admin invariant across database: revoke admin role from any unauthorized email
            await User.update(
                { role: 'customer' },
                { 
                    where: { 
                        role: 'admin',
                        email: { [Op.ne]: 'system.admin@agrimedlink.com' }
                    } 
                }
            );

            // Clean up any old placeholder admin accounts
            await User.destroy({ where: { email: 'admin.system@agrimedlink.com' } });

            // 2. Ensure unique System Admin exists with required credentials
            const existingAdmin = await User.findOne({ where: { email: 'system.admin@agrimedlink.com' } });
            if (!existingAdmin) {
                await User.create({
                    email: 'system.admin@agrimedlink.com',
                    password: 'admin2026key$',
                    name: 'System Administrator',
                    phone_number: '+1-800-AGRI-ADM',
                    role: 'admin',
                    status: 'active'
                });
                console.log('Default unique System Admin created (system.admin@agrimedlink.com)');
            } else {
                existingAdmin.password = 'admin2026key$';
                existingAdmin.role = 'admin';
                existingAdmin.status = 'active';
                await existingAdmin.save();
                console.log('Unique System Admin credentials & single-admin role verified.');
            }

            const demoUsers = [
                { email: 'farmer.demo@gmail.com', password: 'Password123!', name: 'Elena Vance', phone_number: '+1-800-FARM-01', role: 'farmer', status: 'active' },
                { email: 'buyer.demo@gmail.com', password: 'Password123!', name: 'Marcus Sterling', phone_number: '+1-800-BUY-02', role: 'customer', status: 'active' },
                { email: 'supplier.demo@gmail.com', password: 'Password123!', name: 'Claire Dupont', phone_number: '+1-800-SUPP-03', role: 'supplier', status: 'active' },
                { email: 'advisor.demo@icloud.com', password: 'Password123!', name: 'Dr. Sarah Botanical', phone_number: '+1-800-ADV-04', role: 'advisor', status: 'active' },
                { email: 'investor.demo@gmail.com', password: 'Password123!', name: 'David Greenfield', phone_number: '+1-800-INV-05', role: 'investor', status: 'active' },
            ];
            for (const d of demoUsers) {
                const exists = await User.findOne({ where: { email: d.email } });
                if (!exists) {
                    await User.create(d);
                }
            }

            const existingSettings = await AppSetting.findOne();
            if (!existingSettings) {
                await AppSetting.create({});
                console.log('Default platform app settings initialized.');
            }

            // Seed initial agricultural communities and conversations
            const { seedChatAndCommunities } = require('./src/infrastructure/database/seed_chat');
            await seedChatAndCommunities();
        } catch (syncError) {
            console.error('Failed to sync database models:', syncError.message);
        }
    } else {
        console.warn('Backend server running in API-ready standalone mode. Attach Railway MySQL to persist live data.');
    }
}

bootstrapDatabase().catch((err) => {
    console.error('Background DB bootstrap notice:', err.message);
});