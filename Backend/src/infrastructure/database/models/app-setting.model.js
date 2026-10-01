const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const AppSetting = sequelize.define('AppSetting', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        appName: {
            type: DataTypes.STRING,
            allowNull: false,
            defaultValue: 'AgriMed Link'
        },
        appVersion: {
            type: DataTypes.STRING,
            allowNull: false,
            defaultValue: '2.1.0'
        },
        buildNumber: {
            type: DataTypes.STRING,
            allowNull: false,
            defaultValue: '104'
        },
        maintenanceMode: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false
        },
        announcement: {
            type: DataTypes.TEXT,
            allowNull: true,
            defaultValue: 'Welcome to AgriMed Link Platform - Empowering Agricultural Trade'
        },
        commissionRate: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: false,
            defaultValue: 3.50
        },
        allowRegistrations: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true
        },
        supportEmail: {
            type: DataTypes.STRING,
            allowNull: false,
            defaultValue: 'support@agrimedlink.com'
        }
    }, {
        tableName: 'app_settings',
        timestamps: true
    });

    return AppSetting;
};
