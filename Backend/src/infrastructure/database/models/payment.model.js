const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const Payment = sequelize.define('Payment', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        transactionId: {
            type: DataTypes.STRING,
            allowNull: true,
            unique: true
        },
        amount: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false
        },
        currency: {
            type: DataTypes.STRING(10),
            defaultValue: 'XAF',
            allowNull: false
        },
        customerPhone: {
            type: DataTypes.STRING,
            allowNull: true
        },
        customerEmail: {
            type: DataTypes.STRING,
            allowNull: true
        },
        provider: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        status: {
            type: DataTypes.ENUM('pending', 'success', 'failed', 'refunded'),
            defaultValue: 'pending',
            allowNull: false
        },
        freemopayReference: {
            type: DataTypes.STRING,
            allowNull: true
        },
        metadata: {
            type: DataTypes.JSON,
            allowNull: true
        }
    }, {
        tableName: 'payments',
        indexes: [
            {
                unique: true,
                fields: ['transactionId']
            },
            {
                fields: ['status']
            }
        ]
    });

    return Payment;
};
