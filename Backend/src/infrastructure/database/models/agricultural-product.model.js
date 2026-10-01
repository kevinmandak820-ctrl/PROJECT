const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const AgriculturalProduct = sequelize.define('AgriculturalProduct', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        name: {
            type: DataTypes.STRING,
            allowNull: false
        },
        category: {
            type: DataTypes.STRING,
            allowNull: false,
            defaultValue: 'General'
        },
        price: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false
        },
        quantity: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        unit: {
            type: DataTypes.STRING,
            allowNull: false,
            defaultValue: 'kg'
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        imageUrl: {
            type: DataTypes.STRING,
            allowNull: true
        },
        status: {
            type: DataTypes.ENUM('available', 'reserved', 'sold_out', 'harvested'),
            allowNull: false,
            defaultValue: 'available'
        },
        harvestDate: {
            type: DataTypes.DATEONLY,
            allowNull: true
        }
    }, {
        tableName: 'agricultural_products'
    });

    return AgriculturalProduct;
};
