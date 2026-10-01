import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/main.dart';
import 'package:agrimed_link/models/crop_model.dart';
import 'package:agrimed_link/services/crop_service.dart';

void main() {
  group('CropModel and CropService Unit Tests', () {
    test('CropModel correctly parses JSON and resolves display image', () {
      final json = {
        'id': 'crop-uuid-1',
        'farmerId': 'farmer-uuid-1',
        'name': 'Organic Echinacea',
        'category': 'Medicinal',
        'price': 19.99,
        'quantity': 75.0,
        'unit': 'bundle',
        'description': 'Immune boosting organic echinacea flower heads.',
        'imageUrl': '/uploads/crops/crop-12345.png',
        'status': 'available',
        'farmer': {
          'name': 'Farmer Giles',
          'rating': 4.9,
        }
      };

      final crop = CropModel.fromJson(json);

      expect(crop.id, 'crop-uuid-1');
      expect(crop.name, 'Organic Echinacea');
      expect(crop.price, 19.99);
      expect(crop.quantity, 75.0);
      expect(crop.unit, 'bundle');
      expect(crop.farmerName, 'Farmer Giles');
      expect(crop.isNetworkImage, isTrue);
      expect(crop.displayImageUrl, 'http://localhost:3000/uploads/crops/crop-12345.png');
    });

    test('CropModel fallback image works for asset paths', () {
      const crop = CropModel(
        id: '1',
        name: 'Aloe',
        price: 8.5,
        imageUrl: 'assets/images/aloe_vera.png',
      );
      expect(crop.isNetworkImage, isFalse);
      expect(crop.displayImageUrl, 'assets/images/aloe_vera.png');
    });

    test('CropService defaultInitialCrops contains valid crops', () {
      final defaults = CropService.defaultInitialCrops;
      expect(defaults.isNotEmpty, isTrue);
      expect(defaults.any((c) => c.name.contains('Aloe Vera')), isTrue);
      expect(defaults.any((c) => c.name.contains('Ginseng')), isTrue);
    });
  });

  group('Farmer Crop Management Widget Tests', () {
    testWidgets('Farmer can view crop management hub, FAB, and Add Crop dialog', (
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
          'name': 'Farmer Green',
          'id': 'farmer-green-id',
        },
      );
      await tester.pumpAndSettle();

      // Open drawer and switch to Crops view
      final ScaffoldState scaffoldState = tester.firstState<ScaffoldState>(
        find.byType(Scaffold),
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crops'));
      await tester.pumpAndSettle();

      // Verify Crops view elements for Farmer
      expect(find.text('Medicinal Crops'), findsOneWidget);
      expect(find.text('Add / Upload'), findsOneWidget); // FAB
      expect(find.text('Add Crop'), findsWidgets);
      expect(find.text('Bulk Upload'), findsOneWidget);
      expect(find.text('Marketplace (4)'), findsOneWidget);
      expect(find.text('My Farm (0)'), findsOneWidget);

      // Tap "Add Crop" button
      final addCropBtn = find.widgetWithText(ElevatedButton, 'Add Crop');
      expect(addCropBtn, findsOneWidget);
      await tester.tap(addCropBtn);
      await tester.pumpAndSettle();

      // Verify Add Crop Dialog opens with form fields
      expect(find.text('Add New Crop'), findsOneWidget);
      expect(find.text('Crop Name *'), findsOneWidget);
      expect(find.text('Price (\$) *'), findsOneWidget);
      expect(find.text('Quantity in Stock'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add New Crop'), findsNothing);
    });

    testWidgets('Customer/Buyer does not see Farmer management actions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed(
        '/dashboard',
        arguments: {
          'email': 'buyer@agrimed.com',
          'role': 'buyer',
          'name': 'City Buyer',
        },
      );
      await tester.pumpAndSettle();

      // Open drawer and navigate to Crops
      final ScaffoldState scaffoldState = tester.firstState<ScaffoldState>(
        find.byType(Scaffold),
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crops'));
      await tester.pumpAndSettle();

      // Buyer should NOT see farmer management controls or FAB
      expect(find.text('Add / Upload'), findsNothing);
      expect(find.text('My Farm'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

      // Buyer should see order buttons
      expect(find.byIcon(Icons.add_shopping_cart_rounded), findsWidgets);
    });
  });
}
