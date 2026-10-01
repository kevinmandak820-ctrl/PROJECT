import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'crop_service.dart';

/// Service for DigiPay Mobile Money payments (Cameroon - MTN & Orange Money)
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  /// Normalize mobile phone number to 237xxxxxxxxx format
  static String normalizePhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00237')) {
      digits = digits.substring(2);
    }
    if (digits.length == 9 && digits.startsWith('6')) {
      digits = '237$digits';
    }
    return digits;
  }

  /// Detect mobile operator for visual branding
  static String detectOperator(String phone) {
    try {
      final norm = normalizePhone(phone);
      if (norm.length >= 5) {
        final local = norm.substring(3);
        final prefix = local.substring(0, 2);
        if (prefix == '67' || prefix == '68' || (prefix == '65' && int.parse(local[2]) <= 4)) {
          return 'MTN';
        }
        if (prefix == '69' || (prefix == '65' && int.parse(local[2]) >= 5) || (prefix == '68' && int.parse(local[2]) >= 5)) {
          return 'Orange';
        }
      }
    } catch (_) {}
    return 'Mobile Money';
  }

  /// Initiate a Mobile Money payment through the backend DigiPay SDK
  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    required String mobileNumber,
    String? email,
    List<String>? bookingIds,
    String? orderId,
    String? cropId,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = await AuthService.getStoredUser();
    final customerEmail = email ?? currentUser?.email;

    final payload = <String, dynamic>{
      'amount': amount.round(),
      'mobileNumber': mobileNumber.trim(),
      if (customerEmail != null && customerEmail.isNotEmpty) 'customerEmail': customerEmail,
      if (bookingIds != null && bookingIds.isNotEmpty) 'bookingIds': bookingIds,
      if (orderId != null) 'orderId': orderId,
      if (cropId != null) 'cropId': cropId,
      if (metadata != null) 'metadata': metadata,
    };

    if (CropService.isTestMode) {
      // Test mode mock response
      final normPhone = normalizePhone(mobileNumber);
      final op = detectOperator(normPhone);
      final isOrange = op == 'Orange';
      final isMockPending = metadata?['mockPending'] == true;
      final txnId = isMockPending ? 'TXN_MOCK_PENDING' : 'TXN_MOCK_${DateTime.now().millisecondsSinceEpoch}';

      return {
        'status': 'success',
        'message': isOrange
            ? 'Mock payment initiated. Dial #150# to validate.'
            : 'Mock payment initiated. Approve the MoMo prompt on screen.',
        'data': {
          'transactionId': txnId,
          'status': 'pending',
          'amount': amount.round(),
          'currency': 'XAF',
          'customerPhone': normPhone,
          'provider': op.toLowerCase(),
          'instructions': {
            'provider': op.toLowerCase(),
            'providerName': isOrange ? 'Orange Money' : 'MTN Mobile Money',
            'dialCode': isOrange ? '#150#' : '*126#',
            'requiresManualDial': isOrange,
            'title': isOrange ? 'Orange Money Validation Required' : 'Authorize MTN MoMo Payment',
            'headline': isOrange ? 'Dial #150# on your Orange phone to approve' : 'Enter your MoMo PIN on the prompt',
            'warning': isOrange
                ? 'Orange Money does not send automated screen popups. You must dial #150# to authorize.'
                : 'If no prompt appears within 10 seconds, dial *126# manually.',
            'steps': isOrange
                ? ['Open Phone dialer', 'Dial #150#', 'Select Validations / Approvals', 'Enter secret PIN']
                : ['Approve MoMo prompt on screen', 'Or dial *126# -> Approvals if no prompt appears', 'Enter MoMo PIN'],
            'copyCode': isOrange ? '#150#' : '*126#',
          }
        }
      };
    }

    try {
      final res = await ApiService.authPost('/payments/initiate', payload);
      if (res['status'] == 'success') {
        return res;
      }
      throw res['message'] as String? ?? 'Failed to initiate DigiPay payment.';
    } catch (e) {
      // Retry via public post if token refresh failed
      try {
        final res = await ApiService.post('/payments/initiate', payload);
        if (res['status'] == 'success') {
          return res;
        }
        throw res['message'] as String? ?? 'Failed to initiate DigiPay payment.';
      } catch (err) {
        debugPrint('[PaymentService] Error initiating payment: $err');
        rethrow;
      }
    }
  }

  /// Query live payment status from DigiPay
  Future<Map<String, dynamic>> checkStatus(String transactionId) async {
    if (transactionId == 'TXN_MOCK_PENDING') {
      return {
        'status': 'success',
        'data': {
          'transactionId': transactionId,
          'status': 'pending',
          'isSuccess': false,
          'isPending': true,
          'isFailed': false,
        }
      };
    }

    if (CropService.isTestMode || transactionId.startsWith('TXN_MOCK_')) {
      return {
        'status': 'success',
        'data': {
          'transactionId': transactionId,
          'status': 'success',
          'isSuccess': true,
          'isPending': false,
          'isFailed': false,
        }
      };
    }

    try {
      final res = await ApiService.authGet('/payments/status/$transactionId');
      if (res['status'] == 'success') {
        return res;
      }
      throw res['message'] as String? ?? 'Failed to check transaction status.';
    } catch (e) {
      debugPrint('[PaymentService] Error checking status: $e');
      rethrow;
    }
  }

  /// Poll transaction status until resolved (success or failed) or timeout
  Stream<Map<String, dynamic>> pollPaymentStatus(
    String transactionId, {
    Duration interval = const Duration(seconds: 3),
    int maxAttempts = 45, // ~135 seconds (allows user sufficient time to dial #150# or *126#)
  }) {
    late StreamController<Map<String, dynamic>> controller;
    Timer? timer;
    int attempts = 0;

    void tick() async {
      if (controller.isClosed) return;
      attempts++;
      try {
        final res = await checkStatus(transactionId);
        final data = res['data'] as Map<String, dynamic>? ?? {};
        if (!controller.isClosed) {
          controller.add({
            'attempt': attempts,
            'maxAttempts': maxAttempts,
            ...data,
          });
        }

        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'success' || status == 'failed' || status == 'refunded') {
          timer?.cancel();
          await controller.close();
          return;
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add({
            'attempt': attempts,
            'maxAttempts': maxAttempts,
            'error': e.toString(),
            'status': 'pending',
            'isPending': true,
          });
        }
      }

      if (attempts >= maxAttempts) {
        timer?.cancel();
        if (!controller.isClosed) {
          controller.add({
            'attempt': attempts,
            'maxAttempts': maxAttempts,
            'status': 'timeout',
            'isTimeout': true,
            'message': 'Payment verification timed out. If you approved via #150# or *126#, please check your payment history or retry.',
          });
          await controller.close();
        }
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        tick();
        timer = Timer.periodic(interval, (_) => tick());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }

  /// Fetch user payment history
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    if (CropService.isTestMode) return [];
    try {
      final res = await ApiService.authGet('/payments/history');
      if (res['status'] == 'success' && res['data']?['payments'] != null) {
        final list = res['data']['payments'] as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Admin: Get DigiPay merchant settlement balance
  Future<Map<String, dynamic>> getMerchantBalance() async {
    try {
      final res = await ApiService.authGet('/payments/balance');
      if (res['status'] == 'success') {
        return res['data'] as Map<String, dynamic>;
      }
      throw res['message'] as String? ?? 'Failed to get DigiPay balance';
    } catch (e) {
      debugPrint('[PaymentService] Error getting merchant balance: $e');
      rethrow;
    }
  }
}
