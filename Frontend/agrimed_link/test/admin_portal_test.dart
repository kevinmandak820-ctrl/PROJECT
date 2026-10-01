import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/main.dart';
import 'package:agrimed_link/screens/admin/admin_portal_screen.dart';
import 'package:agrimed_link/services/admin_service.dart';
import 'package:agrimed_link/services/app_localizations.dart';
import 'package:agrimed_link/services/localization_service.dart';

void main() {
  setUp(() async {
    AdminService.isTestMode = true;
    await LocalizationService.instance.setLanguage('en');
  });

  group('Admin Portal & Governance Widget Tests', () {
    testWidgets('AdminPortalScreen renders all 4 tabs and interactions', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
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

      // 1. Verify Header & Title
      expect(find.text('Admin Management Console'), findsOneWidget);
      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('App Settings'), findsOneWidget);

      // 2. Tab 1: System Statistics
      expect(find.text('Total Users'), findsOneWidget);
      expect(find.text('Active Crops'), findsOneWidget);
      expect(find.text('Pending Approvals'), findsOneWidget);
      expect(find.text('System Health & Metrics'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Role Distribution'), findsOneWidget);

      // 3. Tab 2: User Management
      await tester.tap(find.text('Users'));
      await tester.pumpAndSettle();

      expect(find.text('Create User'), findsOneWidget);
      expect(find.text('John Farmer'), findsOneWidget);
      expect(find.text('ACTIVE'), findsWidgets);
      expect(find.text('SUSPENDED'), findsWidgets);

      // Test opening Create User dialog
      final createUserBtn = find.widgetWithText(ElevatedButton, 'Create User');
      expect(createUserBtn, findsOneWidget);
      await tester.tap(createUserBtn);
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Select Your Role'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Test Suspend and Unsuspend action button presence
      expect(find.text('Suspend'), findsWidgets);
      expect(find.text('Un-suspend'), findsWidgets);

      // 4. Tab 3: Professional Approvals (Advisors & Investors)
      await tester.tap(find.text('Approvals'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Sarah Botanical'), findsOneWidget);
      expect(find.text('Professional Agricultural Advisor Request'), findsOneWidget);
      expect(find.text('Accept Request'), findsWidgets);
      expect(find.text('Reject Request'), findsWidgets);

      // Tap Accept on applicant
      await tester.tap(find.widgetWithText(ElevatedButton, 'Accept Request').first);
      await tester.pumpAndSettle();

      // 5. Tab 4: Application Settings & Updates
      await tester.tap(find.text('App Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Platform Configuration'), findsOneWidget);
      expect(find.text('Maintenance Mode'), findsOneWidget);
      expect(find.text('Commission Rate (%)'), findsOneWidget);
      expect(find.text('Platform Announcement'), findsOneWidget);

      final saveBtn = find.widgetWithText(ElevatedButton, 'Save Application Settings');
      expect(saveBtn, findsOneWidget);
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      expect(find.text('Application settings updated successfully!'), findsOneWidget);
    });

    testWidgets('Dashboard displays Admin Console shortcut and sidebar link for Admin role', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      // Navigate to Dashboard with Admin role
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed(
        '/dashboard',
        arguments: {
          'email': 'system.admin@agrimedlink.com',
          'role': 'admin',
          'name': 'System Administrator',
        },
      );
      await tester.pumpAndSettle();

      // 1. Top bar contains Admin Portal icon
      final adminTopIcon = find.byTooltip('Admin Portal');
      expect(adminTopIcon, findsOneWidget);

      // 2. Open sidebar drawer
      final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // 3. Drawer contains ADMIN badge and Admin Portal item
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Admin Portal'), findsOneWidget);
      expect(find.text('CONSOLE'), findsOneWidget);

      // 4. Tap Admin Portal in drawer to open console
      await tester.tap(find.text('Admin Portal'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Management Console'), findsOneWidget);
    });
  });
}

