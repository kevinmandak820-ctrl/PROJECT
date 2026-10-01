const { User } = require('../../../infrastructure/database/sequelize');
const {
    generateAccessToken,
    generateRefreshToken,
    verifyRefreshToken
} = require('../../../infrastructure/utils/auth.utils');

class AuthController {
    /**
     * Register a new user
     */
    static async register(req, res, next) {
        try {
            const { email, password, role, name, phone_number } = req.body;

            // Simple validation
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

            // Check if email already exists
            const existingUser = await User.findOne({ where: { email } });
            if (existingUser) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Email is already registered'
                });
            }

            // Prohibit registration as an admin or using the designated system administrator email
            if (
                (role && (role.toString().toLowerCase() === 'admin' || role.toString().toLowerCase() === 'administrator')) ||
                (email && email.toString().toLowerCase().trim() === 'system.admin@agrimedlink.com')
            ) {
                return res.status(403).json({
                    status: 'error',
                    message: 'Registration as an administrator is prohibited. The platform maintains a single designated administrator (system.admin@agrimedlink.com).'
                });
            }

            // Enforce email domain: all users except admin must use @gmail.com or @icloud.com
            const emailLower = email.toString().toLowerCase().trim();
            const isTargetAdmin = (role && (role.toString().toLowerCase() === 'admin' || role.toString().toLowerCase() === 'administrator')) || emailLower === 'system.admin@agrimedlink.com';
            if (!isTargetAdmin && !emailLower.endsWith('@gmail.com') && !emailLower.endsWith('@icloud.com')) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Email must end with @gmail.com or @icloud.com (except for administrator accounts)'
                });
            }

            // Allowed public registration roles check (admin is strictly excluded)
            const allowedRoles = ['customer', 'farmer', 'supplier', 'delivery_guy', 'advisor', 'investor'];
            const userRole = role && allowedRoles.includes(role.toString().toLowerCase()) ? role.toString().toLowerCase() : 'customer';

            // If user registers as advisor or investor, their account requires administrative approval
            const isProfessionalRole = ['advisor', 'investor'].includes(userRole);
            const initialStatus = isProfessionalRole ? 'pending_approval' : 'active';

            // Create user (Sequelize hooks will automatically hash the password)
            const user = await User.create({
                email,
                password,
                role: userRole,
                name: name || null,
                phone_number: phone_number || null,
                status: initialStatus
            });

            const successMsg = isProfessionalRole
                ? 'Your registration request has been submitted and is pending administrator approval.'
                : 'User registered successfully';

            return res.status(201).json({
                status: 'success',
                message: successMsg,
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
            console.error('Registration controller error:', error);
            next(error);
        }
    }

    /**
     * User Login
     */
    static async login(req, res, next) {
        try {
            const { email, password } = req.body;

            if (!email || !password) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Email and password are required'
                });
            }

            const normalizedEmail = email.toString().toLowerCase().trim();

            // Find user in DB
            let user = await User.findOne({ where: { email: normalizedEmail } });
            
            // Ensure unique system admin account is always present if attempting login
            if (!user && normalizedEmail === 'system.admin@agrimedlink.com') {
                user = await User.create({
                    email: 'system.admin@agrimedlink.com',
                    password: 'admin2026key$',
                    name: 'System Administrator',
                    phone_number: '+1-800-AGRI-ADM',
                    role: 'admin',
                    status: 'active'
                });
            }

            if (!user) {
                return res.status(401).json({
                    status: 'error',
                    message: 'Invalid email or password'
                });
            }

            // Enforce single-admin invariant: only system.admin@agrimedlink.com can possess admin role
            if (user.role === 'admin' && user.email !== 'system.admin@agrimedlink.com') {
                user.role = 'customer';
                await user.save();
            }

            if (user.status !== 'active') {
                let statusMessage = 'Your account is suspended';
                if (user.status === 'pending_approval') {
                    statusMessage = 'Your account is pending administrator approval. Please wait for an administrator to review your request.';
                } else if (user.status === 'rejected') {
                    statusMessage = 'Your account application was rejected. Please contact support.';
                }
                return res.status(403).json({
                    status: 'error',
                    message: statusMessage,
                    accountStatus: user.status
                });
            }

            // Verify password using model instance method
            const isPasswordValid = await user.validatePassword(password);
            if (!isPasswordValid) {
                return res.status(401).json({
                    status: 'error',
                    message: 'Invalid email or password'
                });
            }

            // Generate token credentials
            const accessToken = generateAccessToken(user);
            const refreshToken = generateRefreshToken(user);

            return res.status(200).json({
                status: 'success',
                message: 'Logged in successfully',
                data: {
                    accessToken,
                    refreshToken,
                    user: {
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        phone_number: user.phone_number,
                        role: user.role
                    }
                }
            });
        } catch (error) {
            console.error('Login controller error:', error);
            next(error);
        }
    }

    /**
     * Refresh access tokens
     */
    static async refresh(req, res, next) {
        try {
            const { refreshToken } = req.body;
            if (!refreshToken) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Refresh token is required'
                });
            }

            const decoded = verifyRefreshToken(refreshToken);
            if (!decoded) {
                return res.status(401).json({
                    status: 'error',
                    message: 'Invalid or expired refresh token'
                });
            }

            // Fetch active user
            const user = await User.findByPk(decoded.id);
            if (!user) {
                return res.status(401).json({
                    status: 'error',
                    message: 'User associated with token does not exist'
                });
            }

            if (user.status !== 'active') {
                return res.status(403).json({
                    status: 'error',
                    message: user.status === 'pending_approval'
                        ? 'Your account is pending administrator approval'
                        : 'Your account is suspended'
                });
            }

            // Generate a fresh access token
            const accessToken = generateAccessToken(user);

            return res.status(200).json({
                status: 'success',
                data: {
                    accessToken
                }
            });
        } catch (error) {
            console.error('Token refresh error:', error);
            next(error);
        }
    }

    /**
     * User Logout
     */
    static async logout(req, res, next) {
        try {
            // For stateless JWT, we request client discards the tokens.
            // A success response verifies endpoints connect cleanly.
            return res.status(200).json({
                status: 'success',
                message: 'Logged out successfully'
            });
        } catch (error) {
            console.error('Logout error:', error);
            next(error);
        }
    }

    /**
     * Request Password Reset (Stub)
     */
    static async requestPasswordReset(req, res, next) {
        try {
            const { email } = req.body;
            if (!email) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Email is required'
                });
            }

            // Stub message indicating reset flow triggered
            return res.status(200).json({
                status: 'success',
                message: `Password reset link sent to ${email} (simulated)`
            });
        } catch (error) {
            console.error('Password reset request error:', error);
            next(error);
        }
    }

    /**
     * Confirm Password Reset (Stub)
     */
    static async confirmPasswordReset(req, res, next) {
        try {
            const { token, newPassword } = req.body;
            if (!token || !newPassword) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Reset token and new password are required'
                });
            }

            if (newPassword.length < 6) {
                return res.status(400).json({
                    status: 'error',
                    message: 'New password must be at least 6 characters long'
                });
            }

            // Stub success message
            return res.status(200).json({
                status: 'success',
                message: 'Password has been reset successfully (simulated)'
            });
        } catch (error) {
            console.error('Password reset confirmation error:', error);
            next(error);
        }
    }
}

module.exports = AuthController;
