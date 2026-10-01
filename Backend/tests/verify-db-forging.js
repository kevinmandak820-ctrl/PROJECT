const path = require('path');
const dotenv = require('dotenv');

// Load environment config
dotenv.config({ path: path.join(__dirname, '../.env') });

const {
    sequelize,
    User,
    AgriculturalProduct,
    IndustrialProduct,
    Order,
    Payment,
    Invoice,
    Notification
} = require('../src/infrastructure/database/sequelize');

// Assertion helper
function assert(condition, message) {
    if (!condition) {
        throw new Error(`Assertion failed: ${message}`);
    }
    console.log(`  ✓ Pass: ${message}`);
}

async function verifyDbForging() {
    console.log('\n--- Starting Database Forging Verification Tests ---');

    try {
        console.log('Force synchronizing all models (drops existing tables and recreates)...');
        await sequelize.sync({ force: true });
        console.log('  ✓ Pass: Database synchronized successfully.');
    } catch (syncError) {
        console.error('Sequelize sync failed:', syncError);
        throw syncError;
    }

    // 1. Verify User insertions with polymorphic attributes
    let farmer, customer, supplier, investor;
    try {
        console.log('Verifying polymorphic User role insertions...');

        farmer = await User.create({
            email: 'farmer@example.com',
            password: 'hashedpassword',
            name: 'Jane Farmer',
            dob: '1985-05-15',
            phone_number: '+123456789',
            role: 'farmer',
            rating: 4.85
        });
        assert(farmer.id !== null, 'Farmer inserted successfully');
        assert(farmer.rating == 4.85, 'Farmer rating saved correctly');

        supplier = await User.create({
            email: 'supplier@example.com',
            password: 'hashedpassword',
            name: 'Bob Supplier',
            role: 'supplier',
            rating: 4.20
        });
        assert(supplier.id !== null, 'Supplier inserted successfully');

        customer = await User.create({
            email: 'customer@example.com',
            password: 'hashedpassword',
            name: 'Alice Customer',
            role: 'customer'
        });
        assert(customer.id !== null, 'Customer inserted successfully');

        investor = await User.create({
            email: 'investor@example.com',
            password: 'hashedpassword',
            name: 'Rich Investor',
            role: 'investor',
            profession: 'Venture Capitalist'
        });
        assert(investor.id !== null, 'Investor inserted successfully');
        assert(investor.profession === 'Venture Capitalist', 'Investor profession attribute saved correctly');
    } catch (err) {
        console.error('User Role Insertions Failed:', err);
        throw err;
    }

    // 2. Verify Product models (Agricultural & Industrial) and associations
    let crop, machine;
    try {
        console.log('Verifying Product insertions and associations...');

        crop = await AgriculturalProduct.create({
            name: 'Organically Grown Tomato',
            price: 2.99,
            farmerId: farmer.id
        });
        assert(crop.id !== null, 'Agricultural crop created');

        // Fetch farmer from crop
        const cropFarmer = await crop.getFarmer();
        assert(cropFarmer.name === 'Jane Farmer', 'Association crop.getFarmer() returns proper Farmer');

        // Fetch crops from farmer
        const farmerCrops = await farmer.getCrops();
        assert(farmerCrops.length === 1, 'Association farmer.getCrops() returns correct crops array count');
        assert(farmerCrops[0].name === 'Organically Grown Tomato', 'Association retrieves tomato name');

        machine = await IndustrialProduct.create({
            name: 'Plow Tractor Model T',
            price: 15499.50,
            supplierId: supplier.id
        });
        assert(machine.id !== null, 'Industrial machine created');

        const machineSupplier = await machine.getSupplier();
        assert(machineSupplier.name === 'Bob Supplier', 'Association machine.getSupplier() returns proper Supplier');
    } catch (err) {
        console.error('Product verification failed:', err);
        throw err;
    }

    // 3. Verify Order insertions and associations
    let customerOrder, farmerOrder;
    try {
        console.log('Verifying Order insertions and associations...');

        // Customer ordering Tomato (Agricultural)
        customerOrder = await Order.create({
            buyerId: customer.id,
            agriculturalProductId: crop.id,
            quantity: 5,
            price: 14.95,
            status: 'pending'
        });
        assert(customerOrder.id !== null, 'Customer order created successfully');

        const orderCrop = await customerOrder.getAgriculturalProduct();
        assert(orderCrop.name === 'Organically Grown Tomato', 'order.getAgriculturalProduct() retrieves correct crop details');

        const buyerCustomer = await customerOrder.getBuyer();
        assert(buyerCustomer.name === 'Alice Customer', 'order.getBuyer() retrieves correct buyer profile');

        // Farmer ordering Tractor (Industrial)
        farmerOrder = await Order.create({
            buyerId: farmer.id,
            industrialProductId: machine.id,
            quantity: 1,
            price: 15499.50,
            status: 'pending'
        });
        assert(farmerOrder.id !== null, 'Farmer industrial purchase order created');

        const orderMachine = await farmerOrder.getIndustrialProduct();
        assert(orderMachine.name === 'Plow Tractor Model T', 'order.getIndustrialProduct() retrieves correct machine details');
    } catch (err) {
        console.error('Order verification failed:', err);
        throw err;
    }

    // 4. Verify Payments and Invoice creations
    try {
        console.log('Verifying Payment and Invoice associations...');

        const payment = await Payment.create({
            amount: 14.95,
            orderId: customerOrder.id,
            customerId: customer.id
        });
        assert(payment.id !== null, 'Payment record saved successfully');

        const payOrder = await payment.getOrder();
        assert(payOrder.price == 14.95, 'Payment links back to correct Order');

        const payCustomer = await payment.getCustomer();
        assert(payCustomer.name === 'Alice Customer', 'Payment links back to correct Customer');

        const invoice = await Invoice.create({
            price: 14.95,
            paymentId: payment.id
        });
        assert(invoice.id !== null, 'Invoice record created');

        const invoicePay = await invoice.getPayment();
        assert(invoicePay.amount == 14.95, 'Invoice links to correct Payment');
        assert(invoice.date !== null && invoice.time !== null, 'Invoice generated default date and time values');
    } catch (err) {
        console.error('Payment/Invoice verification failed:', err);
        throw err;
    }

    // 5. Verify Notifications
    try {
        console.log('Verifying Notification triggers...');

        const notify = await Notification.create({
            description: 'Your order has been paid and is being prepared.',
            userId: customer.id
        });
        assert(notify.id !== null, 'Notification created successfully');

        const notifRecipient = await notify.getUser();
        assert(notifRecipient.name === 'Alice Customer', 'Notification correctly references targeted recipient');
        assert(notify.date !== null && notify.time !== null, 'Notification generated default timestamp parameters');
    } catch (err) {
        console.error('Notification verification failed:', err);
        throw err;
    }

    // 6. Verify Cascade Deletion constraints
    try {
        console.log('Verifying cascade constraints (deleting customer should run deletes on association dependencies)...');

        // Capture customer id
        const customerId = customer.id;

        // Delete Customer
        await customer.destroy();

        // Check if payments are deleted cascade
        const associatedPayments = await Payment.findAll({ where: { customerId } });
        assert(associatedPayments.length === 0, 'Customer payment records deleted cascades');

        // Check if orders are deleted cascade
        const associatedOrders = await Order.findAll({ where: { buyerId: customerId } });
        assert(associatedOrders.length === 0, 'Customer purchase orders deleted cascades');

        console.log('Cascade validations succeed.');
    } catch (err) {
        console.error('Cascade constraint verification failed:', err);
        throw err;
    }
}

async function main() {
    try {
        await verifyDbForging();
        console.log('\n=========================================');
        console.log('DATABASE SCHEMA FORGING VALIDATION PASSED');
        console.log('=========================================');
    } catch (error) {
        console.error('\n=========================================');
        console.error('FORGE DB SCHEMA VERIFICATION RUN ENCOUNTERED FAILURES');
        console.error(error.stack || error.message);
        console.error('=========================================');
        process.exitCode = 1;
    } finally {
        await sequelize.close();
    }
}

main();
