require('dotenv').config();
const digipayService = require('../src/services/digipay.service');

async function verifyDigiPay() {
    console.log('====================================================');
    console.log('--- Testing DigiPay SDK Integration & Payin Flow ---');
    console.log('====================================================');

    // 1. Verify Configuration
    console.log('\n[1] Checking DigiPay Configuration:');
    const hasKey = Boolean(digipayService.apiKey);
    const keyPrefix = digipayService.apiKey ? digipayService.apiKey.substring(0, 8) + '...' : 'NONE';
    console.log(`    API Key Present: ${hasKey} (${keyPrefix})`);
    console.log(`    Environment:     ${digipayService.environment}`);

    if (!hasKey) {
        throw new Error('DIGIPAY_API_KEY is not defined in environment!');
    }

    // 2. Phone Number Normalization Tests
    console.log('\n[2] Testing Phone Number Normalization:');
    const testCases = [
        { input: '+237678808831', expected: '237678808831', provider: 'mtn' },
        { input: '678808831', expected: '237678808831', provider: 'mtn' },
        { input: '00237678808831', expected: '237678808831', provider: 'mtn' },
        { input: '+237 6 78 80 88 31', expected: '237678808831', provider: 'mtn' },
        { input: '+237699001122', expected: '237699001122', provider: 'orange' },
        { input: '699001122', expected: '237699001122', provider: 'orange' }
    ];

    for (const tc of testCases) {
        const normalized = digipayService.constructor.normalizePhoneNumber(tc.input);
        const provider = digipayService.constructor.detectMobileMoneyProvider(tc.input);
        const pass = normalized === tc.expected && provider === tc.provider;
        const instr = digipayService.constructor.getApprovalInstructions(tc.input, 5000);
        console.log(`    ${pass ? '✅' : '❌'} "${tc.input}" -> "${normalized}" [${provider.toUpperCase()}] (Dial: ${instr.dialCode})`);
        if (!pass) throw new Error(`Normalization mismatch for ${tc.input}: got ${normalized}, expected ${tc.expected}`);
    }

    // 2b. Instructions and Failure Reason Verification
    console.log('\n[2b] Testing Approval Instructions & Failure Reason Formatting:');
    const orangeInstr = digipayService.constructor.getApprovalInstructions('+237699001122', 15000);
    const mtnInstr = digipayService.constructor.getApprovalInstructions('+237678808831', 15000);
    console.log(`    ✅ Orange Dial Code: ${orangeInstr.dialCode}, Requires Manual Dial: ${orangeInstr.requiresManualDial}`);
    console.log(`    ✅ MTN Dial Code:    ${mtnInstr.dialCode}, Fallback: ${mtnInstr.warning.substring(0, 40)}...`);

    const insufficientMsg = digipayService.constructor.formatFailureReason('BALANCE_INSUFFICIENT', 'orange');
    const timeoutMsg = digipayService.constructor.formatFailureReason('TIMEOUT', 'orange');
    const mtnTimeoutMsg = digipayService.constructor.formatFailureReason('TIMEOUT', 'mtn');
    console.log(`    ✅ Insufficient balance message: "${insufficientMsg.substring(0, 50)}..."`);
    console.log(`    ✅ Orange Timeout message:       "${timeoutMsg.substring(0, 50)}..."`);
    console.log(`    ✅ MTN Timeout message:          "${mtnTimeoutMsg.substring(0, 50)}..."`);

    // 3. Live Balance Check
    console.log('\n[3] Testing DigiPay SDK Live Balance (client.settlements.getBalance):');
    try {
        const balance = await digipayService.getBalance();
        console.log('    ✅ Live Balance Check Succeeded:');
        console.log(`       Available Balance:        ${balance.balance} XAF`);
        console.log(`       Total Revenue Collected:  ${balance.totalRevenue} XAF`);
        console.log(`       Total Commission Paid:    ${balance.totalCommissionPaid} XAF`);
    } catch (balErr) {
        console.error('    ❌ Live balance check error:', balErr.message);
        throw balErr;
    }

    // 4. Test Payment Initiation
    console.log('\n[4] Testing Payment Initiation (client.payments.initiate):');
    const testPayload = {
        amount: 50, // Minimum testing amount in XAF
        customerPhone: '+237678808831',
        customerEmail: 'customer@example.com',
        metadata: {
            bookingIds: ['booking-test-999'],
            cropName: 'Organic Moringa Oleifera',
            notes: 'Test initiated via AgriMed verification script'
        }
    };

    console.log('    Sending initiate payload:', JSON.stringify(testPayload, null, 2));
    let paymentResponse;
    try {
        paymentResponse = await digipayService.initiatePayment(testPayload);
        console.log('    ✅ Payment Initiate Succeeded!');
        console.log('       Transaction ID:      ', paymentResponse.transactionId);
        console.log('       Status:              ', paymentResponse.status);
        console.log('       Amount Charged:      ', paymentResponse.amount, 'XAF');
        console.log('       Base Amount:         ', paymentResponse.baseAmount, 'XAF');
        console.log('       Commission:          ', paymentResponse.commissionAmount, 'XAF');
        console.log('       Freemopay Reference: ', paymentResponse.freemopayReference || 'N/A');
        console.log('       Message:             ', paymentResponse.message || 'Prompt sent to customer');
    } catch (initErr) {
        console.error('    ❌ Payment initiate error:', initErr.message);
        throw initErr;
    }

    // 5. Test Live Payment Status Check
    console.log('\n[5] Testing Live Status Check (client.payments.getStatus):');
    try {
        const statusResponse = await digipayService.getStatus(paymentResponse.transactionId);
        console.log('    ✅ Live Status Query Succeeded!');
        console.log('       Transaction ID: ', statusResponse.transactionId);
        console.log('       Current Status: ', statusResponse.status);
        console.log('       Total Amount:   ', statusResponse.totalAmount, statusResponse.currency || 'XAF');
        console.log('       Customer Phone: ', statusResponse.customerPhone);
        console.log('       Metadata:       ', statusResponse.metadata);
    } catch (statErr) {
        console.error('    ❌ Status query error:', statErr.message);
        throw statErr;
    }

    console.log('\n====================================================');
    console.log('🎉 SUCCESS: DigiPay SDK integration fully verified!');
    console.log('====================================================\n');
}

verifyDigiPay().catch((err) => {
    console.error('\n❌ Verification Failed:', err);
    process.exit(1);
});
