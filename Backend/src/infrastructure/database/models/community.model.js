const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const Community = sequelize.define('Community', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        name: {
            type: DataTypes.STRING,
            allowNull: false,
            validate: {
                notEmpty: true
            }
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        category: {
            type: DataTypes.STRING,
            allowNull: false,
            defaultValue: 'General'
        },
        icon: {
            type: DataTypes.STRING,
            allowNull: true,
            defaultValue: 'groups'
        },
        creatorId: {
            type: DataTypes.UUID,
            allowNull: false
        },
        membersCount: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 1
        }
    }, {
        tableName: 'communities',
        timestamps: true
    });

    return Community;
};
