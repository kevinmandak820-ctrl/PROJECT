const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const CommunityMessage = sequelize.define('CommunityMessage', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        communityId: {
            type: DataTypes.UUID,
            allowNull: false
        },
        senderId: {
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
        }
    }, {
        tableName: 'community_messages',
        timestamps: true
    });

    return CommunityMessage;
};
