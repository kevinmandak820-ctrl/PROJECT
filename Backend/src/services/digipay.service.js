const { DigiPay } = require('digipay-sdk');
const config = require('../config');

/**
 * DigiPay Payment Service
 * Handles Mobile Money payments (MTN & Orange Money) via DigiPay Node.js SDK
 */
class DigiPayService {
    constructor() {
        this.apiKey = config.digipay.apiKey;
        this.environment = config.digipay.environment || 'production';
        this._initClient();
    }

    _initClient() {
        if (!this.apiKey) {
            console.warn('[DigiPayService] Warning: DIGIPAY_API_KEY is not defined in environment variables.');
        }

        const SDK = DigiPay || require('digipay-sdk');
        this.client = new SDK({
            apiKey: this.apiKey,
            environment: this.environment
        });
        console.log(`[DigiPayService] DigiPay client initialized (env: ${this.environment})`);
    }

    /**
     * Normalizes customer mobile phone number to international Cameroon format (e.g. "237678808831")
     * Handles inputs like: "+237678808831", "00237678808831", "678808831", "237 678 80 88 31"
     * 
     * @param {string} phone
     * @returns {string} normalized phone number without '+' or spaces
     */
    static normalizePhoneNumber(phone) {
        if (!phone || typeof phone !== 'string') {
            throw new Error('A valid phone number string is required.');
        }

        // Remove all non-digits
        let digits = phone.replace(/\D/g, '');

        // Remove leading international double zeros if present (00237 -> 237)
        if (digits.startsWith('00237')) {
            digits = digits.substring(2);
        }

        // Standard Cameroon 9-digit local mobile number (starts with 6)
        if (digits.length === 9 && digits.startsWith('6')) {
            digits = '237' + digits;
        }

        // Check if starts with country code 237 and has valid length (12 digits)
        if (digits.startsWith('237') && digits.length === 12) {
            return digits;
        }

        // If it's already 12 digits or more with international code
        if (digits.length >= 10) {
            return digits;
        }

        throw new Error(`Invalid phone number format: "${phone}". Expected a valid 9-digit Cameroon number (e.g. 678808831) or international format (e.g. +237678808831).`);
    }

    /**
     * Detect provider (MTN / Orange) for UI display and tracking
     * Note: DigiPay routes automatically without needing provider in API call,
     * but we provide detection for client transparency & logging.
     * 
     * @param {string} phone 
     * @returns {'mtn' | 'orange' | 'unknown'}
     */
    static detectMobileMoneyProvider(phone) {
        try {
            const normalized = DigiPayService.normalizePhoneNumber(phone);
            const localPart = normalized.substring(3); // remove '237'
            const prefix = localPart.substring(0, 2);

            // MTN Cameroon: 67x, 650-654, 680-684
            if (prefix === '67' || (prefix === '65' && parseInt(localPart[2], 10) <= 4) || (prefix === '68' && parseInt(localPart[2], 10) <= 4)) {
                return 'mtn';
            }
            // Orange Cameroon: 69x, 655-659, 685-689
            if (prefix === '69' || (prefix === '65' && parseInt(localPart[2], 10) >= 5) || (prefix === '68' && parseInt(localPart[2], 10) >= 5)) {
                return 'orange';
            }
        } catch (_) {}
        return 'unknown';
    }

    /**
     * Provides clear, operator-specific approval instructions for customers in Cameroon.
     * 
     * CRITICAL TELECOM BEHAVIOR IN CAMEROON:
     * - Orange Money: NEVER sends an automatic USSD prompt to the phone screen.
     *   The customer MUST dial #150# (or #150*50#) to approve.
     * - MTN MoMo: Usually sends a USSD flash prompt, but if screen is off/locked or
     *   network is congested, the customer must dial *126# -> Approvals to validate.
     * 
     * @param {string} phone
     * @param {number} amount
     * @returns {Object} Instructions object tailored to the operator
     */
    static getApprovalInstructions(phone, amount) {
        const provider = DigiPayService.detectMobileMoneyProvider(phone);
        const formattedAmount = amount ? `${Math.round(amount)} XAF` : 'the requested amount';

        if (provider === 'orange') {
            return {
                provider: 'orange',
                providerName: 'Orange Money',
                promptType: 'manual_dial',
                dialCode: '#150#',
                fastDialCode: '#150*50#',
                title: 'Orange Money Validation Required',
                headline: `Dial #150# on your Orange phone to approve ${formattedAmount}`,
                requiresManualDial: true,
                warning: 'Orange Money does not send automated screen popups. You must dial #150# to authorize.',
                steps: [
                    'Open the Phone dialer on your Orange phone',
                    'Dial #150# (or #150*50# directly)',
                    'Select option for Pending Validations / Approvals',
                    'Enter your secret Orange Money PIN to confirm'
                ],
                copyCode: '#150#'
            };
        } else if (provider === 'mtn') {
            return {
                provider: 'mtn',
                providerName: 'MTN Mobile Money',
                promptType: 'ussd_push_with_fallback',
                dialCode: '*126#',
                fastDialCode: '*126*0#',
                title: 'Authorize MTN MoMo Payment',
                headline: `Please enter your MoMo PIN on the prompt to authorize ${formattedAmount}`,
                requiresManualDial: false,
                warning: 'If the authorization prompt did not appear on your screen, dial *126# manually.',
                steps: [
                    'Look for the MoMo authorization prompt on your phone screen',
                    'Enter your MTN Mobile Money PIN to approve',
                    'If no prompt appears within 10 seconds: dial *126# on your MTN SIM',
                    'Select "Pending Approvals" and enter your PIN'
                ],
                copyCode: '*126#'
            };
        }

        return {
            provider: 'unknown',
            providerName: 'Mobile Money',
            promptType: 'hybrid',
            dialCode: '*126# or #150#',
            title: 'Authorize Payment on Your Phone',
            headline: `Authorize payment of ${formattedAmount} on your phone`,
            requiresManualDial: false,
            warning: 'For MTN dial *126#; for Orange Money dial #150# to approve.',
            steps: [
                'For MTN: enter PIN on prompt or dial *126# -> Approvals',
                'For Orange: dial #150# -> Validations to approve'
            ],
            copyCode: '*126#'
        };
    }

    /**
     * Translates telecom / aggregator failure codes into clear, actionable advice.
     * 
     * @param {string} reason - Raw failure reason from DigiPay / Freemopay
     * @param {string} provider - 'mtn' | 'orange' | 'unknown'
     * @returns {string} Human-friendly explanation
     */
    static formatFailureReason(reason, provider = 'unknown') {
        if (!reason) {
            return provider === 'orange'
                ? 'Payment was not approved. Ensure you dial #150# to validate and that your Orange Money wallet has sufficient funds.'
                : 'Payment was not approved. Ensure you approve the MoMo prompt (or dial *126#) and that your account has sufficient funds.';
        }

        const raw = String(reason).toUpperCase();

        if (raw.includes('BALANCE_INSUFFICIENT') || raw.includes('LOW_BALANCE')) {
            return 'Insufficient Mobile Money balance. Please ensure your account has enough funds to cover the payment amount plus telecom withdrawal fees.';
        }
        if (raw.includes('TIMEOUT')) {
            return provider === 'orange'
                ? 'Payment timed out: The transaction was not validated within the required time window. Please dial #150# promptly after clicking pay.'
                : 'Payment timed out: No authorization PIN was entered within the time window. If the prompt does not appear, dial *126# promptly.';
        }
        if (raw.includes('PAYEE_LIMIT') || raw.includes('NOT_ALLOWED')) {
            return 'Transaction rejected by mobile operator: Your account has reached its daily transaction limit or is not verified for electronic payments.';
        }
        if (raw.includes('CANCEL') || raw.includes('REJECT') || raw.includes('DECLINE')) {
            return 'Payment was cancelled or declined on the mobile phone.';
        }

        return `Payment failed at operator (${reason}). Please check your phone balance and try again.`;
    }

    /**
     * Initiate a Mobile Money payment via DigiPay SDK
     * 
     * @param {Object} params
     * @param {number} params.amount - Amount in XAF (FCFA)
     * @param {string} params.customerPhone - Customer mobile number (will be normalized)
     * @param {string} [params.customerEmail] - Customer email for receipt
     * @param {Object} [params.metadata] - Extra metadata (orderId, cropId, bookingIds, etc.)
     * @param {string} [params.webhookUrl] - Optional webhook callback URL
     * @returns {Promise<Object>} DigiPay payin response with instructions
     */
    async initiatePayment({ amount, customerPhone, customerEmail, metadata = {}, webhookUrl }) {
        if (!amount || isNaN(Number(amount)) || Number(amount) < 50) {
            throw new Error('A valid positive payment amount of at least 50 XAF (minimum 100 XAF recommended for telecom networks) is required.');
        }

        const normalizedPhone = DigiPayService.normalizePhoneNumber(customerPhone);
        const integerAmount = Math.round(Number(amount));
        const provider = DigiPayService.detectMobileMoneyProvider(normalizedPhone);
        const instructions = DigiPayService.getApprovalInstructions(normalizedPhone, integerAmount);

        const payload = {
            amount: integerAmount,
            customerPhone: normalizedPhone,
            customerEmail: customerEmail && customerEmail.trim() ? customerEmail.trim() : undefined,
            metadata: {
                ...(metadata && typeof metadata === 'object' ? metadata : {}),
                detectedProvider: provider,
            },
            webhookUrl: webhookUrl || undefined
        };

        try {
            console.log(`[DigiPayService] Initiating payment of ${integerAmount} XAF for phone ${normalizedPhone} (${provider.toUpperCase()})...`);
            const response = await this.client.payments.initiate(payload);
            console.log(`[DigiPayService] Payment initiated successfully. Transaction ID: ${response.transactionId}, Status: ${response.status}`);
            
            return {
                ...response,
                provider,
                instructions
            };
        } catch (error) {
            console.error('[DigiPayService] Payment initiation error:', error.message || error);
            throw new Error(`DigiPay payment initiation failed: ${error.message || error}`);
        }
    }

    /**
     * Query live payment transaction status from DigiPay
     * 
     * @param {string} transactionId 
     * @returns {Promise<Object>} Transaction details and status
     */
    async getStatus(transactionId) {
        if (!transactionId || typeof transactionId !== 'string') {
            throw new Error('A valid transactionId is required to query payment status.');
        }

        try {
            const statusResponse = await this.client.payments.getStatus(transactionId.trim());
            return statusResponse;
        } catch (error) {
            console.error(`[DigiPayService] Failed to get status for transaction ${transactionId}:`, error.message || error);
            throw new Error(`Failed to check DigiPay status for ${transactionId}: ${error.message || error}`);
        }
    }

    /**
     * Get merchant settlement balance from DigiPay
     * 
     * @returns {Promise<Object>} { balance, totalRevenue, totalCommissionPaid }
     */
    async getBalance() {
        try {
            return await this.client.settlements.getBalance();
        } catch (error) {
            console.error('[DigiPayService] Failed to fetch balance:', error.message || error);
            throw new Error(`Failed to fetch DigiPay balance: ${error.message || error}`);
        }
    }

    /**
     * Request a payout / withdrawal to a Mobile Money number
     * 
     * @param {Object} params
     * @param {number} params.amount
     * @param {string} params.recipientPhone
     * @returns {Promise<Object>}
     */
    async requestPayout({ amount, recipientPhone }) {
        if (!amount || Number(amount) <= 0) {
            throw new Error('A valid positive payout amount is required.');
        }
        const normalized = DigiPayService.normalizePhoneNumber(recipientPhone);
        try {
            return await this.client.settlements.requestPayout({
                amount: Math.round(Number(amount)),
                recipientPhone: normalized
            });
        } catch (error) {
            console.error('[DigiPayService] Payout request failed:', error.message || error);
            throw new Error(`DigiPay payout failed: ${error.message || error}`);
        }
    }
}

// Export singleton instance and class
const digipayServiceInstance = new DigiPayService();
module.exports = digipayServiceInstance;
module.exports.DigiPayService = DigiPayService;
