const { getDbStatus, testConnection } = require('../../../infrastructure/database/sequelize');

class HealthController {
    static async getHealth(req, res) {
        // Fast in-memory status check so health check returns in <1ms without blocking on network timeout
        let dbHealth = getDbStatus();
        if (!dbHealth.lastChecked) {
            // Initial non-blocking check
            testConnection(2000).catch(() => {});
        }

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
