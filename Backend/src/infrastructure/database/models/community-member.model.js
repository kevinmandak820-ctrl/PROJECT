const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const CommunityMember = sequelize.define('CommunityMember', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        communityId: {
            type: DataTypes.UUID,
            allowNull: false
        },
        userId: {
            type: DataTypes.UUID,
            allowNull: false
        },
        role: {
            type: DataTypes.ENUM('creator', 'admin', 'member'),
            defaultValue: 'member'
        }
    }, {
        tableName: 'community_members',
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ['communityId', 'userId']
            }
        ]
    });

    return CommunityMember;
};
