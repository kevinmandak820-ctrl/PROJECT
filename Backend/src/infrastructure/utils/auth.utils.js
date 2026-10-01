const jwt = require('jsonwebtoken');
const config = require('../../config');

/**
 * Generate a short-lived access JWT token containing user details.
 */
function generateAccessToken(user) {
    return jwt.sign(
        { id: user.id, email: user.email, role: user.role },
        config.jwt.accessSecret,
        { expiresIn: config.jwt.accessExpiration }
    );
}

/**
 * Generate a long-lived refresh JWT token containing only basic identifying claims.
 */
function generateRefreshToken(user) {
    return jwt.sign(
        { id: user.id },
        config.jwt.refreshSecret,
        { expiresIn: config.jwt.refreshExpiration }
    );
}

/**
 * Synchronously verify an access token. Returns claims or null if invalid/expired.
 */
function verifyAccessToken(token) {
    try {
        return jwt.verify(token, config.jwt.accessSecret);
    } catch (error) {
        return null;
    }
}

/**
 * Synchronously verify a refresh token. Returns claims or null if invalid/expired.
 */
function verifyRefreshToken(token) {
    try {
        return jwt.verify(token, config.jwt.refreshSecret);
    } catch (error) {
        return null;
    }
}

module.exports = {
    generateAccessToken,
    generateRefreshToken,
    verifyAccessToken,
    verifyRefreshToken
};
