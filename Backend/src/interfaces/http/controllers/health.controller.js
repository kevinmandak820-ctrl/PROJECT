const { testConnection } = require('../../../infrastructure/database/sequelize');

class HealthController {
    static async getHealth(req, res) {
        const dbHealth = await testConnection();

        const healthStatus = {
            status: 'UP',
            timestamp: new Date().toISOString(),
            uptime: process.uptime(),
            dbConnected: dbHealth.connected,
            dbMessage: dbHealth.message
        };

        return res.status(200).json(healthStatus);
    }
}

module.exports = HealthController;
