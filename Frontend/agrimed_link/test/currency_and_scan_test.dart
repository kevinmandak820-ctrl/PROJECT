import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agrimed_link/main.dart';
import 'package:agrimed_link/services/currency_service.dart';
import 'package:agrimed_link/services/crop_service.dart';
import 'package:agrimed_link/screens/dashboard/dashboard_screen.dart';
import 'package:agrimed_link/widgets/currency_converter_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CropService.isTestMode = true;
    DashboardScreen.enablePriceTimer = false;
    await CurrencyService.instance.init();
    await CurrencyService.instance.setCurrency(AppCurrency.usd);
  });

  group('CurrencyService Tests', () {
    test('Converts between USD, EUR, and FCFA accurately', () {
      final service = CurrencyService.instance;

      // 100 USD to EUR and FCFA
      final eurVal = service.convert(100.0, from: AppCurrency.usd, to: AppCurrency.eur);
      expect(eurVal, closeTo(92.0, 0.01));

      final fcfaVal = service.convert(100.0, from: AppCurrency.usd, to: AppCurrency.fcfa);
      expect(fcfaVal, closeTo(60500.0, 0.1));

      // 60500 FCFA back to USD
      final usdVal = service.convert(60500.0, from: AppCurrency.fcfa, to: AppCurrency.usd);
      expect(usdVal, closeTo(100.0, 0.01));

      // 92 EUR to FCFA
      final fcfaFromEur = service.convert(92.0, from: AppCurrency.eur, to: AppCurrency.fcfa);
      expect(fcfaFromEur, closeTo(60500.0, 1.0));
    });

    test('Formats currency strings with correct symbols and groupings', () {
      final service = CurrencyService.instance;

      final formattedUsd = service.format(125.50, currency: AppCurrency.usd);
      expect(formattedUsd, '\$125.50');

      // Converts 125.50 USD to EUR (115.46)
      final formattedEur = service.format(125.50, currency: AppCurrency.eur);
      expect(formattedEur, '€115.46');

      // Raw formatting in EUR
      expect(service.formatAmount(125.50, AppCurrency.eur), '€125.50');

      // Converts 100 USD to FCFA (60500)
      final formattedFcfa = service.format(100.0, currency: AppCurrency.fcfa);
      expect(formattedFcfa, '60 500 FCFA');

      // Raw formatting in FCFA
      expect(service.formatAmount(60500, AppCurrency.fcfa), '60 500 FCFA');
    });

    test('Switching currency notifies listeners', () async {
      final service = CurrencyService.instance;
      AppCurrency? notifiedCurrency;

      service.currentCurrency.addListener(() {
        notifiedCurrency = service.currentCurrency.value;
      });

      await service.setCurrency(AppCurrency.fcfa);
      expect(notifiedCurrency, AppCurrency.fcfa);

      await service.setCurrency(AppCurrency.eur);
      expect(notifiedCurrency, AppCurrency.eur);
    });
  });

  group('Currency Converter Dialog Tests', () {
    testWidgets('Renders inputs and preset chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CurrencyConverterDialog.show(context),
                child: const Text('Open Converter'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Converter'));
      await tester.pumpAndSettle();

      // Check title and currencies
      expect(find.text('Currency Converter'), findsOneWidget);
      expect(find.text('USD'), findsWidgets);
      expect(find.text('EUR'), findsWidgets);
      expect(find.text('FCFA'), findsWidgets);

      // Check presets exist
      expect(find.textContaining('Aloe Vera'), findsOneWidget);
      expect(find.textContaining('Bio-Fertilizer'), findsOneWidget);

      // Scroll to and tap close button
      final closeBtn = find.text('Close Converter');
      expect(closeBtn, findsOneWidget);
      await tester.ensureVisible(closeBtn);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      expect(find.text('Currency Converter'), findsNothing);
    });
  });

  group('Dashboard Currency & Scanner Tests', () {
    testWidgets('Dashboard displays currency chip and scanner modes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      // Push dashboard
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed(
        '/dashboard',
        arguments: {
          'email': 'farmer@agrimed.com',
          'role': 'farmer',
          'name': 'Green Botanist',
        },
      );
      await tester.pumpAndSettle();

      // 1. Currency button exists in AppBar with active currency code
      expect(find.text('USD'), findsWidgets);

      // 2. Open drawer and verify currency tile
      final ScaffoldState scaffoldState = tester.firstState<ScaffoldState>(
        find.byType(Scaffold),
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Currency'), findsOneWidget);
      expect(find.byIcon(Icons.currency_exchange_rounded), findsOneWidget);

      expect(find.text('Scan'), findsOneWidget);
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      // 3. Scan screen has title and mode tabs
      expect(find.text('Scan Crop/Product'), findsOneWidget);
      expect(find.text('Camera Viewfinder'), findsOneWidget);
      expect(find.text('Upload Image'), findsOneWidget);

      // 4. Switch to Upload Image mode
      await tester.tap(find.text('Upload Image'));
      await tester.pumpAndSettle();

      // Verify upload mode elements
      expect(find.text('Select Specimen to Upload & Scan:'), findsOneWidget);
      expect(find.text('Aloe Vera'), findsOneWidget);
      expect(find.text('Moringa Leaf'), findsOneWidget);
      expect(find.textContaining('Diseased Leaf'), findsOneWidget);

      // 5. Select a specimen and run diagnosis
      final diagnoseBtn = find.text('Select Image to Scan');
      expect(diagnoseBtn, findsOneWidget);
      await tester.ensureVisible(diagnoseBtn);
      await tester.tap(diagnoseBtn);
      await tester.pumpAndSettle();

      // 6. Verify AI Diagnosis Dialog pops up with 3 currencies
      expect(find.text('Scan Complete'), findsOneWidget);
      expect(find.text('Commercial Valuation'), findsOneWidget);
      expect(find.text('🇺🇸 USD'), findsOneWidget);
      expect(find.text('🇪🇺 EUR'), findsOneWidget);
      expect(find.text('🌍 FCFA'), findsOneWidget);

      // Close modal
      final closeBtn = find.text('Close');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      expect(find.text('Scan Complete'), findsNothing);
    });
  });
}
