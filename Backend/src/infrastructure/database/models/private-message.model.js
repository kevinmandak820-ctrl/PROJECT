const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const PrivateMessage = sequelize.define('PrivateMessage', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        senderId: {
            type: DataTypes.UUID,
            allowNull: false
        },
        recipientId: {
            type: DataTypes.UUID,
            allowNull: false
        },
        content: {
            type: DataTypes.TEXT,
            allowNull: false
        },
        attachmentUrl: {
            type: DataTypes.STRING,
            allowNull: true
        },
        isRead: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        }
    }, {
        tableName: 'private_messages',
        timestamps: true,
        indexes: [
            {
                fields: ['senderId', 'recipientId']
            },
            {
                fields: ['recipientId', 'isRead']
            }
        ]
    });

    return PrivateMessage;
};
