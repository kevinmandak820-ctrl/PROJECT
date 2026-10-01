import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/main.dart';
import 'package:agrimed_link/screens/admin/admin_portal_screen.dart';
import 'package:agrimed_link/services/admin_service.dart';
import 'package:agrimed_link/services/app_localizations.dart';
import 'package:agrimed_link/services/auth_service.dart';
import 'package:agrimed_link/services/localization_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AdminService.isTestMode = true;
    AuthService.isTestMode = true;
    await LocalizationService.instance.setLanguage('en');
  });

  group('Admin Security & Registration Prohibition Tests', () {
    testWidgets('Signup screen strictly forbids Admin registration and does not offer Admin role', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      // 1. Navigate to Sign Up screen
      final signUpLink = find.text('Sign Up');
      expect(signUpLink, findsOneWidget);
      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      // 2. Verify "Register as Admin" button is strictly absent
      expect(find.text('Register as Admin'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Register as Admin'), findsNothing);

      // 3. Verify Admin role card is not in the self-registration role selection options
      expect(find.text('Admin'), findsNothing);

      // 4. Verify informative Administrator accounts banner directing to Login
      expect(find.text('Administrator Accounts'), findsOneWidget);
      expect(find.textContaining('cannot be self-registered'), findsOneWidget);

      // 5. Verify AuthService client-side guard throws if admin registration is attempted
      expect(
        () => AuthService.register(
          name: 'Unauthorized Admin',
          email: 'admin_test@agrimed.com',
          phone: '+1-555-0199',
          password: 'Password123!',
          role: 'admin',
        ),
        throwsA(predicate((e) => e.toString().contains('prohibited'))),
      );
    });

    testWidgets('Login screen does not show demo role selector or Fill Admin Credentials button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      expect(find.text('Fill Admin Credentials'), findsNothing);
      expect(find.text('Quick Demo Login by Role'), findsNothing);
      expect(find.text('Farmer'), findsNothing);
      expect(find.text('Admin'), findsNothing);
    });

    testWidgets(r'Entering system.admin@agrimedlink.com and admin2026key$ authenticates and grants admin privileges', (
      WidgetTester tester,
    ) async {
      final user = await AuthService.login(
        'system.admin@agrimedlink.com',
        r'admin2026key$',
      );

      expect(user.email, equals('system.admin@agrimedlink.com'));
      expect(user.role, equals('admin'));
    });

    testWidgets('AdminPortalScreen blocks non-admin users with Access Denied shield', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: LocalizationService.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: const RouteSettings(
                arguments: {
                  'email': 'unauthorized.user@example.com',
                  'role': 'farmer',
                },
              ),
              builder: (context) => const AdminPortalScreen(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Unauthorized Administrator Access'), findsOneWidget);
      expect(find.textContaining('system.admin@agrimedlink.com'), findsOneWidget);
    });
  });
}
