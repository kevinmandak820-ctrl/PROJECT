const digipayService = require('../../../services/digipay.service');
const { Payment, Order, Invoice, Notification, AgriculturalProduct, User } = require('../../../infrastructure/database/sequelize');

// In-memory fallback cache for payments when MySQL server is disconnected or in test environments
const inMemoryPayments = new Map();
const inMemoryOrders = new Map();

class PaymentController {
    /**
     * Initiate a Mobile Money payment via DigiPay SDK
     * 
     * Route: POST /api/payments/initiate
     * Accepts: { amount, mobileNumber, customerPhone, customerEmail, bookingIds, orderId, cropId, metadata }
     */
    static async initiatePayment(req, res) {
        try {
            const body = req.body || {};
            const rawPhone = body.mobileNumber || body.customerPhone || body.phone;
            let rawAmount = body.amount;
            const bookingIds = body.bookingIds;
            const orderId = body.orderId;
            const cropId = body.cropId;
            const customerEmail = body.customerEmail || body.email || (req.user && req.user.email) || null;
            const customerId = req.user ? req.user.id : null;

            if (!rawPhone || typeof rawPhone !== 'string' || rawPhone.trim() === '') {
                return res.status(400).json({
                    status: 'error',
                    message: 'A valid customer mobile phone number is required (e.g. "+237678808831" or "678808831").'
                });
            }

            // Normalize phone number to DigiPay format ("237678808831")
            let normalizedPhone;
            try {
                normalizedPhone = digipayService.constructor.normalizePhoneNumber(rawPhone);
            } catch (phoneErr) {
                return res.status(400).json({
                    status: 'error',
                    message: phoneErr.message
                });
            }

            // Detect provider for client info (MTN or Orange)
            const provider = digipayService.constructor.detectMobileMoneyProvider(normalizedPhone);

            // If amount is not explicitly provided, try to calculate from crop or order
            let cropItem = null;
            if (!rawAmount && cropId) {
                try {
                    cropItem = await AgriculturalProduct.findByPk(cropId);
                    if (cropItem) {
                        // Base price might be USD or FCFA. If USD, convert to FCFA (~605 FCFA)
                        const unitPrice = Number(cropItem.price);
                        const quantity = body.quantity ? Number(body.quantity) : 1;
                        rawAmount = unitPrice > 500 ? unitPrice * quantity : Math.round(unitPrice * 605 * quantity);
                    }
                } catch (_) {}
            }

            if (!rawAmount || isNaN(Number(rawAmount)) || Number(rawAmount) < 50) {
                return res.status(400).json({
                    status: 'error',
                    message: 'A valid positive payment amount of at least 50 XAF (minimum 100 XAF recommended) is required.'
                });
            }

            const integerAmount = Math.round(Number(rawAmount));

            // Metadata payload to preserve for callback / verification
            const metadata = {
                ...(body.metadata && typeof body.metadata === 'object' ? body.metadata : {}),
                ...(bookingIds ? { bookingIds } : {}),
                ...(orderId ? { orderId } : {}),
                ...(cropId ? { cropId } : {}),
                ...(customerId ? { customerId } : {}),
                selectedProvider: provider,
                appName: 'AgriMed Link'
            };

            // Optional webhook URL if public host is configured
            let webhookUrl = undefined;
            const host = req.get('host');
            if (host && !host.includes('localhost') && !host.includes('127.0.0.1')) {
                webhookUrl = `${req.protocol}://${host}/api/payments/webhook`;
            }

            // 1. Call DigiPay SDK to initiate payment
            const digiResponse = await digipayService.initiatePayment({
                amount: integerAmount,
                customerPhone: normalizedPhone,
                customerEmail: customerEmail || undefined,
                metadata,
                webhookUrl
            });

            const transactionId = digiResponse.transactionId;
            const status = digiResponse.status || 'pending';
            const instructions = digiResponse.instructions || digipayService.constructor.getApprovalInstructions(normalizedPhone, integerAmount);

            // Operator-specific user instruction message
            const initiateMessage = provider === 'orange'
                ? 'DigiPay payment initiated. Please dial #150# (or #150*50#) on your Orange phone to validate the transaction.'
                : 'DigiPay payment initiated. Please approve the prompt on your phone (or dial *126# if prompt does not appear).';

            // 2. Persist Payment in Database (or memory store)
            let savedPayment = null;
            try {
                savedPayment = await Payment.create({
                    transactionId,
                    amount: integerAmount,
                    currency: 'XAF',
                    customerPhone: normalizedPhone,
                    customerEmail: customerEmail,
                    provider,
                    status,
                    freemopayReference: digiResponse.freemopayReference || null,
                    metadata: {
                        ...metadata,
                        instructions
                    },
                    customerId,
                    orderId: orderId || null
                });
            } catch (dbErr) {
                console.warn('[PaymentController] Database save fallback to memory:', dbErr.message);
                savedPayment = {
                    id: `pay-${Date.now()}`,
                    transactionId,
                    amount: integerAmount,
                    currency: 'XAF',
                    customerPhone: normalizedPhone,
                    customerEmail,
                    provider,
                    status,
                    metadata: {
                        ...metadata,
                        instructions
                    },
                    customerId,
                    orderId: orderId || null,
                    createdAt: new Date().toISOString()
                };
                inMemoryPayments.set(transactionId, savedPayment);
            }

            return res.status(200).json({
                status: 'success',
                message: initiateMessage,
                data: {
                    transactionId,
                    status,
                    amount: integerAmount,
                    baseAmount: digiResponse.baseAmount || integerAmount,
                    commissionAmount: digiResponse.commissionAmount || 0,
                    currency: 'XAF',
                    customerPhone: normalizedPhone,
                    provider,
                    freemopayReference: digiResponse.freemopayReference || null,
                    instructions,
                    metadata,
                    payment: savedPayment
                }
            });
        } catch (error) {
            console.error('[PaymentController] Error initiating payment:', error);
            return res.status(500).json({
                status: 'error',
                message: error.message || 'Internal server error while initiating payment.'
            });
        }
    }

    /**
     * Check live payment status from DigiPay and update records
     * 
     * Route: GET /api/payments/status/:transactionId
     */
    static async getPaymentStatus(req, res) {
        try {
            const { transactionId } = req.params;
            if (!transactionId || transactionId.trim() === '') {
                return res.status(400).json({
                    status: 'error',
                    message: 'Transaction ID is required.'
                });
            }

            // 1. Fetch live status from DigiPay
            let liveStatus;
            try {
                liveStatus = await digipayService.getStatus(transactionId.trim());
            } catch (sdkErr) {
                console.error('[PaymentController] DigiPay getStatus error:', sdkErr.message);
                return res.status(502).json({
                    status: 'error',
                    message: `DigiPay status check failed: ${sdkErr.message}`
                });
            }

            const currentStatus = liveStatus.status; // 'pending' | 'success' | 'failed' | 'refunded'
            const phone = liveStatus.customerPhone || '';
            const detectedProvider = phone ? digipayService.constructor.detectMobileMoneyProvider(phone) : 'unknown';
            const rawFailureReason = liveStatus.metadata?.failureReason || liveStatus.failureReason || null;
            const failureMessage = rawFailureReason
                ? digipayService.constructor.formatFailureReason(rawFailureReason, detectedProvider)
                : null;
            const instructions = phone
                ? digipayService.constructor.getApprovalInstructions(phone, liveStatus.totalAmount || liveStatus.baseAmount)
                : null;

            // 2. Synchronize DB records
            let paymentRecord = null;
            try {
                paymentRecord = await Payment.findOne({ where: { transactionId: transactionId.trim() } });
                if (paymentRecord) {
                    if (paymentRecord.status !== currentStatus) {
                        paymentRecord.status = currentStatus;
                        if (rawFailureReason) {
                            paymentRecord.metadata = {
                                ...(paymentRecord.metadata || {}),
                                failureReason: rawFailureReason,
                                failureMessage
                            };
                        }
                        await paymentRecord.save();
                        console.log(`[PaymentController] Updated payment ${transactionId} status to: ${currentStatus}`);
                    }

                    // If status is success, update corresponding order and generate invoice
                    if (currentStatus === 'success' && paymentRecord.orderId) {
                        try {
                            const order = await Order.findByPk(paymentRecord.orderId);
                            if (order && order.status !== 'completed' && order.status !== 'paid') {
                                order.status = 'paid';
                                await order.save();
                            }

                            // Generate Invoice if not yet created
                            const existingInvoice = await Invoice.findOne({ where: { paymentId: paymentRecord.id } });
                            if (!existingInvoice) {
                                await Invoice.create({
                                    paymentId: paymentRecord.id,
                                    price: paymentRecord.amount
                                });
                            }
                        } catch (assocErr) {
                            console.warn('[PaymentController] Order/Invoice update warning:', assocErr.message);
                        }
                    }
                }
            } catch (dbErr) {
                // Check memory store
                paymentRecord = inMemoryPayments.get(transactionId.trim());
                if (paymentRecord) {
                    paymentRecord.status = currentStatus;
                }
            }

            return res.status(200).json({
                status: 'success',
                data: {
                    transactionId: liveStatus.transactionId,
                    status: currentStatus,
                    baseAmount: liveStatus.baseAmount,
                    commissionAmount: liveStatus.commissionAmount,
                    totalAmount: liveStatus.totalAmount,
                    currency: liveStatus.currency || 'XAF',
                    customerPhone: liveStatus.customerPhone,
                    provider: detectedProvider,
                    instructions,
                    failureReason: rawFailureReason,
                    failureMessage,
                    metadata: liveStatus.metadata,
                    updatedAt: liveStatus.updatedAt,
                    isSuccess: currentStatus === 'success',
                    isPending: currentStatus === 'pending',
                    isFailed: currentStatus === 'failed' || currentStatus === 'refunded'
                }
            });
        } catch (error) {
            console.error('[PaymentController] Error getting status:', error);
            return res.status(500).json({
                status: 'error',
                message: error.message || 'Internal server error while checking payment status.'
            });
        }
    }

    /**
     * Webhook endpoint for DigiPay server callbacks
     * 
     * Route: POST /api/payments/webhook
     */
    static async handleWebhook(req, res) {
        try {
            const body = req.body || {};
            console.log('[PaymentController] Received DigiPay Webhook:', JSON.stringify(body));

            const transactionId = body.transactionId || body.id;
            const status = body.status;

            if (transactionId && status) {
                try {
                    const payment = await Payment.findOne({ where: { transactionId } });
                    if (payment) {
                        payment.status = status;
                        if (body.freemopayReference) payment.freemopayReference = body.freemopayReference;
                        await payment.save();

                        if (status === 'success' && payment.orderId) {
                            await Order.update({ status: 'paid' }, { where: { id: payment.orderId } });
                        }
                    }
                } catch (dbErr) {
                    const mem = inMemoryPayments.get(transactionId);
                    if (mem) mem.status = status;
                }
            }

            return res.status(200).json({ status: 'success', received: true });
        } catch (error) {
            console.error('[PaymentController] Webhook handling error:', error);
            return res.status(200).json({ status: 'error', message: error.message });
        }
    }

    /**
     * Get payment history for authenticated user
     * 
     * Route: GET /api/payments/history
     */
    static async getPaymentHistory(req, res) {
        try {
            const customerId = req.user ? req.user.id : null;
            let payments = [];

            try {
                const whereClause = {};
                if (customerId) whereClause.customerId = customerId;

                payments = await Payment.findAll({
                    where: whereClause,
                    order: [['createdAt', 'DESC']],
                    limit: 50
                });
            } catch (dbErr) {
                payments = Array.from(inMemoryPayments.values()).reverse();
            }

            return res.status(200).json({
                status: 'success',
                data: { payments }
            });
        } catch (error) {
            console.error('[PaymentController] Error fetching payment history:', error);
            return res.status(500).json({
                status: 'error',
                message: 'Failed to fetch payment history: ' + error.message
            });
        }
    }

    /**
     * Get merchant DigiPay balance (Admin only)
     * 
     * Route: GET /api/payments/balance
     */
    static async getBalance(req, res) {
        try {
            const balanceData = await digipayService.getBalance();
            return res.status(200).json({
                status: 'success',
                data: balanceData
            });
        } catch (error) {
            console.error('[PaymentController] Error fetching DigiPay balance:', error);
            return res.status(500).json({
                status: 'error',
                message: error.message || 'Failed to fetch DigiPay balance.'
            });
        }
    }
}

module.exports = PaymentController;
