import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/main.dart';
import 'package:agrimed_link/screens/admin/admin_portal_screen.dart';
import 'package:agrimed_link/screens/dashboard/dashboard_screen.dart';
import 'package:agrimed_link/services/admin_service.dart';
import 'package:agrimed_link/services/crop_service.dart';
import 'package:agrimed_link/services/app_localizations.dart';
import 'package:agrimed_link/services/localization_service.dart';

void main() {
  setUp(() async {
    AdminService.isTestMode = true;
    CropService.isTestMode = true;
    DashboardScreen.enablePriceTimer = false;
    await LocalizationService.instance.setLanguage('en');
  });

  group('Real-Life Role Images Comprehensive Suite', () {
    testWidgets('Signup screen displays real-life images on role cards and bottom registration button for all available user roles and forbids admin registration', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      // 1. Navigate to Sign Up screen
      final signUpLink = find.text('Sign Up');
      expect(signUpLink, findsOneWidget);
      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      // 2. Verify Admin registration is strictly forbidden
      expect(find.text('Register as Admin'), findsNothing);
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Administrator Accounts'), findsOneWidget);

      // 3. Default selection is Farmer:
      final farmerImages = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_farmer.jpg',
      );
      expect(farmerImages, findsWidgets);
      expect(find.text('Register as Farmer'), findsOneWidget);

      // 4. Select Buyer role:
      final buyerCard = find.text('Buyer');
      expect(buyerCard, findsOneWidget);
      await tester.ensureVisible(buyerCard);
      await tester.tap(buyerCard);
      await tester.pumpAndSettle();

      expect(find.text('Register as Buyer'), findsOneWidget);
      final buyerImages = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_buyer.jpg',
      );
      expect(buyerImages, findsWidgets);

      // 5. Select Supplier role:
      final supplierCard = find.text('Supplier');
      expect(supplierCard, findsOneWidget);
      await tester.ensureVisible(supplierCard);
      await tester.tap(supplierCard);
      await tester.pumpAndSettle();

      expect(find.text('Register as Supplier'), findsOneWidget);
      final supplierImages = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_supplier.jpg',
      );
      expect(supplierImages, findsWidgets);

      // 6. Select Advisor role:
      final advisorCard = find.text('Advisor');
      expect(advisorCard, findsOneWidget);
      await tester.ensureVisible(advisorCard);
      await tester.tap(advisorCard);
      await tester.pumpAndSettle();

      expect(find.text('Register as Advisor'), findsOneWidget);
      final advisorImages = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_advisor.jpg',
      );
      expect(advisorImages, findsWidgets);

      // 7. Select Investor role:
      final investorCard = find.text('Investor');
      expect(investorCard, findsOneWidget);
      await tester.ensureVisible(investorCard);
      await tester.tap(investorCard);
      await tester.pumpAndSettle();

      expect(find.text('Register as Investor'), findsOneWidget);
      final investorImages = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_investor.jpg',
      );
      expect(investorImages, findsWidgets);
    });

    testWidgets('Login screen features real-life community images in header avatar stack and no demo selector', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      // Verify Login Screen is displayed
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Community Network'), findsOneWidget);

      // Verify the 5 community role images are present in the avatar stack
      for (final role in ['farmer', 'buyer', 'supplier', 'advisor', 'investor']) {
        final imgFinder = find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_$role.jpg',
        );
        expect(imgFinder, findsWidgets, reason: 'Expected role_$role.jpg on Login Screen');
      }

      // Verify Admin image and demo chips are NOT present
      final adminImgFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_admin.jpg',
      );
      expect(adminImgFinder, findsNothing);

      expect(find.text('Quick Demo Login by Role'), findsNothing);
      expect(find.text('Fill Admin Credentials'), findsNothing);
      expect(find.text('Farmer'), findsNothing);
    });

    testWidgets('Admin Portal statistics card displays real-life role images in Role Distribution chips', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: const AdminPortalScreen(),
          supportedLocales: LocalizationService.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(useMaterial3: true),
        ),
      );
      await tester.pumpAndSettle();

      // In Tab 1: Statistics -> Role Distribution
      expect(find.text('Role Distribution'), findsOneWidget);

      // Verify all 6 roles have their real-life image thumbnails in the distribution chips
      for (final role in ['farmer', 'buyer', 'supplier', 'advisor', 'investor', 'admin']) {
        final imgFinder = find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_$role.jpg',
        );
        expect(imgFinder, findsWidgets, reason: 'Expected role_$role.jpg in Admin statistics');
      }
    });

    testWidgets('Dashboard screen displays real-life role images in AppBar, Drawer, Crop items, and Supply items', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      // Navigate to Dashboard with advisor role
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed(
        '/dashboard',
        arguments: {
          'email': 'advisor.demo@agrimedlink.com',
          'role': 'advisor',
          'name': 'Dr. Sarah Botanical',
        },
      );
      await tester.pumpAndSettle();

      // 1. Verify Top AppBar has role profile avatar
      final appBarRoleAvatar = find.byTooltip('Profile (ADVISOR)');
      expect(appBarRoleAvatar, findsOneWidget);

      // 2. Open Sidebar Drawer
      final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Drawer displays ADVISOR badge and role_advisor.jpg
      expect(find.text('ADVISOR'), findsOneWidget);
      final advisorDrawerImages = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_advisor.jpg',
      );
      expect(advisorDrawerImages, findsWidgets);

      // Close drawer
      Navigator.pop(tester.element(find.byType(Drawer)));
      await tester.pumpAndSettle();

      // 3. Tap AppBar Profile avatar to open Role Profile modal
      await tester.tap(appBarRoleAvatar);
      await tester.pumpAndSettle();

      expect(find.text('Switch Role Preview:'), findsOneWidget);
      for (final role in ['farmer', 'buyer', 'supplier', 'advisor', 'investor']) {
        final imgFinder = find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_$role.jpg',
        );
        expect(imgFinder, findsWidgets, reason: 'Expected role_$role.jpg in Role Profile modal');
      }
      final adminModalFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_admin.jpg',
      );
      expect(adminModalFinder, findsNothing, reason: 'Non-admin users should not see Admin in Role Profile modal');

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // 4. Verify Supply cards show Verified Supplier badge with role_supplier.jpg
      final supplierBadges = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_supplier.jpg',
      );
      expect(supplierBadges, findsWidgets);

      // 5. Navigate to Crops tab
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crops'));
      await tester.pumpAndSettle();

      // Verify Crops tab displays role_farmer.jpg next to farmer name
      final farmerThumbnails = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/role_farmer.jpg',
      );
      expect(farmerThumbnails, findsWidgets);
    });
  });
}
