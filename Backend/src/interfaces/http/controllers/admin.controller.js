const { Op } = require('sequelize');
const {
    User,
    AgriculturalProduct,
    IndustrialProduct,
    AppSetting
} = require('../../../infrastructure/database/sequelize');

class AdminController {
    /**
     * View System Statistics
     */
    static async getStats(req, res, next) {
        try {
            // User counts
            const totalUsers = await User.count();
            const activeUsers = await User.count({ where: { status: 'active' } });
            const suspendedUsers = await User.count({ where: { status: 'suspended' } });
            const pendingRequests = await User.count({ where: { status: 'pending_approval' } });

            // Role distribution
            const roles = ['farmer', 'customer', 'supplier', 'advisor', 'investor', 'admin'];
            const usersByRole = {};
            for (const r of roles) {
                usersByRole[r] = await User.count({ where: { role: r } });
            }

            // Product & Crop statistics
            const totalCrops = await AgriculturalProduct.count();
            const totalSupplies = await IndustrialProduct.count();

            // Recent 5 registered users
            const recentUsers = await User.findAll({
                attributes: ['id', 'name', 'email', 'role', 'status', 'createdAt'],
                order: [['createdAt', 'DESC']],
                limit: 5
            });

            // App settings
            let appSettings = await AppSetting.findOne();
            if (!appSettings) {
                appSettings = await AppSetting.create({});
            }

            const uptimeSeconds = Math.floor(process.uptime());
            const memoryMB = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);

            return res.status(200).json({
                status: 'success',
                data: {
                    overview: {
                        totalUsers,
                        activeUsers,
                        suspendedUsers,
                        pendingRequests,
                        totalCrops,
                        totalSupplies
                    },
                    usersByRole,
                    systemHealth: {
                        serverStatus: 'healthy',
                        uptimeSeconds,
                        uptimeFormatted: `${Math.floor(uptimeSeconds / 3600)}h ${Math.floor((uptimeSeconds % 3600) / 60)}m ${uptimeSeconds % 60}s`,
                        memoryUsageMB: memoryMB,
                        nodeVersion: process.version,
                        platform: process.platform,
                        database: 'connected',
                        maintenanceMode: appSettings.maintenanceMode,
                        timestamp: new Date().toISOString()
                    },
                    recentUsers
                }
            });
        } catch (error) {
            console.error('Admin getStats error:', error);
            next(error);
        }
    }

    /**
     * List all users with filtering and pagination
     */
    static async getUsers(req, res, next) {
        try {
            const { role, status, search, page = 1, limit = 50 } = req.query;
            const whereClause = {};

            if (role && role !== 'all') {
                whereClause.role = role;
            }

            if (status && status !== 'all') {
                whereClause.status = status;
            }

            if (search && search.trim()) {
                const query = `%${search.trim()}%`;
                whereClause[Op.or] = [
                    { name: { [Op.like]: query } },
                    { email: { [Op.like]: query } },
                    { phone_number: { [Op.like]: query } }
                ];
            }

            const offset = (parseInt(page, 10) - 1) * parseInt(limit, 10);
            const { rows: users, count: total } = await User.findAndCountAll({
                where: whereClause,
                attributes: ['id', 'name', 'email', 'phone_number', 'role', 'status', 'createdAt', 'updatedAt'],
                order: [['createdAt', 'DESC']],
                limit: parseInt(limit, 10),
                offset
            });

            return res.status(200).json({
                status: 'success',
                data: {
                    users,
                    total,
                    page: parseInt(page, 10),
                    totalPages: Math.ceil(total / parseInt(limit, 10))
                }
            });
        } catch (error) {
            console.error('Admin getUsers error:', error);
            next(error);
        }
    }

    /**
     * Admin directly creates a new user
     */
    static async createUser(req, res, next) {
        try {
            const { email, password, name, phone_number, role, status } = req.body;

            if (!email || !password) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Email and password are required'
                });
            }

            if (password.length < 6) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Password must be at least 6 characters long'
                });
            }

            // Check duplicate email
            const existing = await User.findOne({ where: { email: email.toLowerCase().trim() } });
            if (existing) {
                return res.status(400).json({
                    status: 'error',
                    message: 'A user with this email already exists'
                });
            }

            // Enforce single-admin invariant: Only one admin is allowed across the entire app
            if (role && (role.toString().toLowerCase() === 'admin' || role.toString().toLowerCase() === 'administrator')) {
                return res.status(403).json({
                    status: 'error',
                    message: 'Forbidden: The platform only permits a single system administrator (system.admin@agrimedlink.com). Creation of secondary admin accounts is prohibited.'
                });
            }

            // Enforce email domain: all users except admin must use @gmail.com or @icloud.com
            const emailLower = email.toLowerCase().trim();
            const isTargetAdmin = (role && (role.toString().toLowerCase() === 'admin' || role.toString().toLowerCase() === 'administrator')) || emailLower === 'system.admin@agrimedlink.com';
            if (!isTargetAdmin && !emailLower.endsWith('@gmail.com') && !emailLower.endsWith('@icloud.com')) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Email must end with @gmail.com or @icloud.com (except for administrator accounts)'
                });
            }

            const allowedRoles = ['customer', 'farmer', 'supplier', 'delivery_guy', 'advisor', 'investor'];
            const assignedRole = role && allowedRoles.includes(role.toLowerCase()) ? role.toLowerCase() : 'customer';

            const allowedStatuses = ['active', 'suspended', 'pending_approval', 'rejected'];
            const assignedStatus = status && allowedStatuses.includes(status) ? status : 'active';

            const newUser = await User.create({
                email: email.toLowerCase().trim(),
                password,
                name: name || null,
                phone_number: phone_number || null,
                role: assignedRole,
                status: assignedStatus
            });

            return res.status(201).json({
                status: 'success',
                message: `User created successfully with role ${assignedRole}`,
                data: {
                    user: {
                        id: newUser.id,
                        email: newUser.email,
                        name: newUser.name,
                        phone_number: newUser.phone_number,
                        role: newUser.role,
                        status: newUser.status,
                        createdAt: newUser.createdAt
                    }
                }
            });
        } catch (error) {
            console.error('Admin createUser error:', error);
            next(error);
        }
    }

    /**
     * Suspend a user account
     */
    static async suspendUser(req, res, next) {
        try {
            const { id } = req.params;

            // Prevent self-lockout
            if (req.user && req.user.id === id) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Administrators cannot suspend their own active account'
                });
            }

            const user = await User.findByPk(id);
            if (!user) {
                return res.status(404).json({
                    status: 'error',
                    message: 'User not found'
                });
            }

            user.status = 'suspended';
            await user.save();

            return res.status(200).json({
                status: 'success',
                message: `User ${user.email} has been suspended`,
                data: {
                    user: {
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        role: user.role,
                        status: user.status
                    }
                }
            });
        } catch (error) {
            console.error('Admin suspendUser error:', error);
            next(error);
        }
    }

    /**
     * Un-suspend a user account
     */
    static async unsuspendUser(req, res, next) {
        try {
            const { id } = req.params;
            const user = await User.findByPk(id);
            if (!user) {
                return res.status(404).json({
                    status: 'error',
                    message: 'User not found'
                });
            }

            user.status = 'active';
            await user.save();

            return res.status(200).json({
                status: 'success',
                message: `User ${user.email} has been un-suspended and activated`,
                data: {
                    user: {
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        role: user.role,
                        status: user.status
                    }
                }
            });
        } catch (error) {
            console.error('Admin unsuspendUser error:', error);
            next(error);
        }
    }

    /**
     * View pending professional account requests (Advisors & Investors)
     */
    static async getPendingRequests(req, res, next) {
        try {
            const requests = await User.findAll({
                where: {
                    status: 'pending_approval'
                },
                attributes: ['id', 'name', 'email', 'phone_number', 'role', 'status', 'createdAt'],
                order: [['createdAt', 'DESC']]
            });

            return res.status(200).json({
                status: 'success',
                data: {
                    requests,
                    count: requests.length
                }
            });
        } catch (error) {
            console.error('Admin getPendingRequests error:', error);
            next(error);
        }
    }

    /**
     * Accept a professional registration request
     */
    static async acceptRequest(req, res, next) {
        try {
            const { id } = req.params;
            const user = await User.findByPk(id);
            if (!user) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Request not found'
                });
            }

            user.status = 'active';
            await user.save();

            return res.status(200).json({
                status: 'success',
                message: `Account creation request for ${user.role} (${user.email}) has been accepted. User is now active.`,
                data: {
                    user: {
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        role: user.role,
                        status: user.status
                    }
                }
            });
        } catch (error) {
            console.error('Admin acceptRequest error:', error);
            next(error);
        }
    }

    /**
     * Reject a professional registration request
     */
    static async rejectRequest(req, res, next) {
        try {
            const { id } = req.params;
            const user = await User.findByPk(id);
            if (!user) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Request not found'
                });
            }

            user.status = 'rejected';
            await user.save();

            return res.status(200).json({
                status: 'success',
                message: `Account creation request for ${user.role} (${user.email}) has been rejected.`,
                data: {
                    user: {
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        role: user.role,
                        status: user.status
                    }
                }
            });
        } catch (error) {
            console.error('Admin rejectRequest error:', error);
            next(error);
        }
    }

    /**
     * Get application settings
     */
    static async getAppSettings(req, res, next) {
        try {
            let settings = await AppSetting.findOne();
            if (!settings) {
                settings = await AppSetting.create({});
            }

            return res.status(200).json({
                status: 'success',
                data: {
                    settings
                }
            });
        } catch (error) {
            console.error('Admin getAppSettings error:', error);
            next(error);
        }
    }

    /**
     * Update application settings
     */
    static async updateAppSettings(req, res, next) {
        try {
            const {
                appName,
                appVersion,
                buildNumber,
                maintenanceMode,
                announcement,
                commissionRate,
                allowRegistrations,
                supportEmail
            } = req.body;

            let settings = await AppSetting.findOne();
            if (!settings) {
                settings = await AppSetting.create({});
            }

            if (appName !== undefined) settings.appName = appName;
            if (appVersion !== undefined) settings.appVersion = appVersion;
            if (buildNumber !== undefined) settings.buildNumber = buildNumber;
            if (maintenanceMode !== undefined) settings.maintenanceMode = Boolean(maintenanceMode);
            if (announcement !== undefined) settings.announcement = announcement;
            if (commissionRate !== undefined) settings.commissionRate = commissionRate;
            if (allowRegistrations !== undefined) settings.allowRegistrations = Boolean(allowRegistrations);
            if (supportEmail !== undefined) settings.supportEmail = supportEmail;

            await settings.save();

            return res.status(200).json({
                status: 'success',
                message: 'Application settings updated successfully',
                data: {
                    settings
                }
            });
        } catch (error) {
            console.error('Admin updateAppSettings error:', error);
            next(error);
        }
    }
}

module.exports = AdminController;
