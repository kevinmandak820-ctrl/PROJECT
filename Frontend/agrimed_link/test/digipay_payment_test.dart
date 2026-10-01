import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/services/payment_service.dart';
import 'package:agrimed_link/services/crop_service.dart';
import 'package:agrimed_link/widgets/digipay_checkout_sheet.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CropService.isTestMode = true;
    DigiPayCheckoutSheet.enableAnimations = false;
  });

  group('DigiPay PaymentService Unit Tests', () {
    test('Phone normalization handles various Cameroon formats', () {
      expect(PaymentService.normalizePhone('+237678808831'), '237678808831');
      expect(PaymentService.normalizePhone('678808831'), '237678808831');
      expect(PaymentService.normalizePhone('00237678808831'), '237678808831');
      expect(PaymentService.normalizePhone('+237 6 78 80 88 31'), '237678808831');
    });

    test('Operator detection identifies MTN and Orange Cameroon numbers', () {
      expect(PaymentService.detectOperator('+237678808831'), 'MTN');
      expect(PaymentService.detectOperator('678808831'), 'MTN');
      expect(PaymentService.detectOperator('+237699001122'), 'Orange');
      expect(PaymentService.detectOperator('699001122'), 'Orange');
    });

    test('Initiate payment in test mode returns mock transaction', () async {
      final res = await PaymentService.instance.initiatePayment(
        amount: 5000,
        mobileNumber: '+237678808831',
        email: 'customer@example.com',
        bookingIds: ['booking-test-1'],
        metadata: {'test': true},
      );

      expect(res['status'], 'success');
      final data = res['data'] as Map<String, dynamic>;
      expect(data['transactionId'], startsWith('TXN_MOCK_'));
      expect(data['amount'], 5000);
      expect(data['currency'], 'XAF');
      expect(data['customerPhone'], '237678808831');
      expect(data['provider'], 'mtn');
    });

    test('Check status returns valid resolved status for mock transactions', () async {
      final statusRes = await PaymentService.instance.checkStatus('TXN_MOCK_12345');
      expect(statusRes['status'], 'success');
      final data = statusRes['data'] as Map<String, dynamic>;
      expect(data['isSuccess'], isTrue);
    });
  });

  group('DigiPayCheckoutSheet Widget Tests', () {
    testWidgets('Renders product info, operator selection, and pay button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      DigiPayCheckoutSheet.show(
                        context,
                        itemName: 'Organic Aloe Vera',
                        unitPriceUSD: 8.50,
                      );
                    },
                    child: const Text('Open Checkout'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Tap to open checkout sheet
      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      // Check header and Cameroon currency badge
      expect(find.text('DigiPay Mobile Money'), findsOneWidget);
      expect(find.text('🇨🇲 XAF'), findsOneWidget);

      // Check item name and operator choices
      expect(find.text('Organic Aloe Vera'), findsOneWidget);
      expect(find.text('MTN'), findsOneWidget);
      expect(find.text('Orange'), findsOneWidget);

      // Check payment button presence
      expect(find.textContaining('Pay'), findsWidgets);
    });

    testWidgets('Tapping Orange switches provider and typing Orange phone auto-detects', (
      WidgetTester tester,
    ) async {
      DigiPayCheckoutSheet.mockPendingInTest = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      DigiPayCheckoutSheet.show(
                        context,
                        itemName: 'Organic Aloe Vera',
                        unitPriceUSD: 8.50,
                      );
                    },
                    child: const Text('Open Checkout'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      // Enter Orange Cameroon number
      await tester.enterText(find.byType(TextField).first, '699001122');
      await tester.pumpAndSettle();

      // Should auto-detect Orange
      expect(find.text('Orange Detected'), findsOneWidget);
      expect(find.textContaining('Orange'), findsWidgets);

      // Tap Pay with Orange
      await tester.tap(find.textContaining('Pay 5143 FCFA with Orange'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Waiting screen should display Orange manual dial code #150#
      expect(find.text('#150#'), findsOneWidget);
      expect(find.textContaining('Orange Money'), findsWidgets);
      expect(find.textContaining('Check Status Now'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);

      // Tap Copy button
      await tester.tap(find.text('Copy'));
      await tester.pump();

      // Clean up and close sheet
      DigiPayCheckoutSheet.mockPendingInTest = false;
      Navigator.of(tester.element(find.byType(DigiPayCheckoutSheet))).pop();
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
