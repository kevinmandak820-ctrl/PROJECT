const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const IndustrialProduct = sequelize.define('IndustrialProduct', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        name: {
            type: DataTypes.STRING,
            allowNull: false
        },
        price: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false
        }
    }, {
        tableName: 'industrial_products'
    });

    return IndustrialProduct;
};
