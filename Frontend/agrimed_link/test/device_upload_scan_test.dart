import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agrimed_link/main.dart';
import 'package:agrimed_link/services/currency_service.dart';
import 'package:agrimed_link/services/crop_service.dart';
import 'package:agrimed_link/screens/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final validPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CropService.isTestMode = true;
    DashboardScreen.enablePriceTimer = false;
    await CurrencyService.instance.init();
    await CurrencyService.instance.setCurrency(AppCurrency.usd);
  });

  group('Device Image Upload & Scan Widget Tests', () {
    testWidgets('Dashboard Scan tab exposes device gallery, camera buttons and file loader', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      // Navigate to dashboard
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed(
        '/dashboard',
        arguments: {
          'email': 'farmer@agrimed.com',
          'role': 'farmer',
          'name': 'Organic Agronomist',
        },
      );
      await tester.pumpAndSettle();

      // Open drawer and navigate to Scan screen
      final ScaffoldState scaffoldState = tester.firstState<ScaffoldState>(
        find.byType(Scaffold),
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Scan'), findsOneWidget);
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      // Verify Scanner UI
      expect(find.text('Scan Crop/Product'), findsOneWidget);
      expect(find.text('Camera Viewfinder'), findsOneWidget);
      expect(find.text('Upload Image'), findsOneWidget);

      // Switch to Upload Image mode
      await tester.tap(find.text('Upload Image'));
      await tester.pumpAndSettle();

      // 1. Verify Device Upload Card elements
      expect(find.text('Upload Image from Your Device'), findsOneWidget);
      expect(find.text('Device Gallery'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsWidgets);

      // 2. Verify Manual File Path / URL Input
      expect(find.text('Enter local file path or image URL...'), findsOneWidget);
      expect(find.text('Load'), findsOneWidget);

      // 3. Verify Preset Specimen Thumbnails are available
      expect(find.text('Select Specimen to Upload & Scan:'), findsOneWidget);
      expect(find.text('Aloe Vera'), findsOneWidget);
      expect(find.text('Moringa Leaf'), findsOneWidget);
      expect(find.text('Diseased Leaf'), findsOneWidget);
      expect(find.text('Bio-Fertilizer'), findsOneWidget);
      expect(find.text('Tomato Seeds'), findsOneWidget);
    });

    testWidgets('Entering a local file path loads the device image and scans it with Gemini AI', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed(
        '/dashboard',
        arguments: {
          'email': 'farmer@agrimed.com',
          'role': 'farmer',
          'name': 'Organic Agronomist',
        },
      );
      await tester.pumpAndSettle();

      // Open drawer & navigate to Scan
      final ScaffoldState scaffoldState = tester.firstState<ScaffoldState>(
        find.byType(Scaffold),
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      // Switch to Upload Image mode
      await tester.tap(find.text('Upload Image'));
      await tester.pumpAndSettle();

      // Create a temporary test image on the filesystem
      final tempDir = Directory.systemTemp;
      final testImageFile = File('${tempDir.path}/test_crop_leaf.png');
      testImageFile.writeAsBytesSync(validPngBytes);

      // Type the test file path into the specific scanner input field
      final textFieldFinder = find.byKey(const Key('scanner_image_path_input'));
      await tester.ensureVisible(textFieldFinder);
      await tester.enterText(textFieldFinder, testImageFile.path);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Tap 'Load' button
      final loadBtn = find.text('Load');
      await tester.ensureVisible(loadBtn);
      await tester.tap(loadBtn);
      await tester.pumpAndSettle();

      // Verify the device image preview chip appears with filename and ready status
      expect(find.text('test_crop_leaf.png'), findsWidgets);
      expect(find.textContaining('Ready to diagnose'), findsOneWidget);

      // Verify the scan button now says "Scan Device Photo with Gemini AI"
      final scanDeviceBtn = find.text('Scan Device Photo with Gemini AI');
      expect(scanDeviceBtn, findsOneWidget);

      // Tap the scan button to trigger Gemini AI diagnosis
      await tester.ensureVisible(scanDeviceBtn);
      await tester.tap(scanDeviceBtn);
      await tester.pumpAndSettle();

      // Verify Scan Complete modal pops up with full diagnosis & valuations
      expect(find.text('Scan Complete'), findsOneWidget);
      expect(find.text('Commercial Valuation'), findsOneWidget);
      expect(find.textContaining('Proposed Treatment:'), findsOneWidget);

      // Verify all 3 currencies are displayed
      expect(find.text('🇺🇸 USD'), findsOneWidget);
      expect(find.text('🇪🇺 EUR'), findsOneWidget);
      expect(find.text('🌍 FCFA'), findsOneWidget);

      // Close modal
      final closeBtn = find.text('Close');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      expect(find.text('Scan Complete'), findsNothing);

      // Clean up test file
      if (testImageFile.existsSync()) {
        testImageFile.deleteSync();
      }
    });

    testWidgets('Tapping specimen preset clears device image selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed(
        '/dashboard',
        arguments: {
          'email': 'farmer@agrimed.com',
          'role': 'farmer',
          'name': 'Organic Agronomist',
        },
      );
      await tester.pumpAndSettle();

      // Open drawer & navigate to Scan
      final ScaffoldState scaffoldState = tester.firstState<ScaffoldState>(
        find.byType(Scaffold),
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      // Switch to Upload Image mode
      await tester.tap(find.text('Upload Image'));
      await tester.pumpAndSettle();

      // Create a temporary test image
      final tempDir = Directory.systemTemp;
      final testImageFile = File('${tempDir.path}/sample_plant.png');
      testImageFile.writeAsBytesSync(validPngBytes);

      final textFieldFinder = find.byKey(const Key('scanner_image_path_input'));
      await tester.ensureVisible(textFieldFinder);
      await tester.enterText(textFieldFinder, testImageFile.path);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final loadBtn = find.text('Load');
      await tester.ensureVisible(loadBtn);
      await tester.tap(loadBtn);
      await tester.pumpAndSettle();

      expect(find.text('sample_plant.png'), findsWidgets);
      expect(find.text('Scan Device Photo with Gemini AI'), findsOneWidget);

      // Now tap a preset specimen thumbnail (e.g. Moringa Leaf)
      final moringaPreset = find.text('Moringa Leaf');
      await tester.ensureVisible(moringaPreset);
      await tester.tap(moringaPreset);
      await tester.pumpAndSettle();

      // Device image should be cleared and default upload button text restored
      expect(find.text('Scan Device Photo with Gemini AI'), findsNothing);
      expect(find.text('Select Image to Scan'), findsOneWidget);

      // Clean up test file
      if (testImageFile.existsSync()) {
        testImageFile.deleteSync();
      }
    });
  });
}
