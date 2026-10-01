const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const Invoice = sequelize.define('Invoice', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        date: {
            type: DataTypes.DATEONLY,
            defaultValue: DataTypes.NOW
        },
        time: {
            type: DataTypes.TIME,
            defaultValue: DataTypes.NOW
        },
        price: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false
        }
    }, {
        tableName: 'invoices'
    });

    return Invoice;
};
