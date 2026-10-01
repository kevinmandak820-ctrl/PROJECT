const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const Notification = sequelize.define('Notification', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: false
        },
        date: {
            type: DataTypes.DATEONLY,
            defaultValue: DataTypes.NOW
        },
        time: {
            type: DataTypes.TIME,
            defaultValue: DataTypes.NOW
        }
    }, {
        tableName: 'notifications'
    });

    return Notification;
};
