import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/screens/auth/signup_screen.dart';
import 'package:agrimed_link/screens/auth/login_screen.dart';
import 'package:agrimed_link/services/auth_service.dart';
import 'package:agrimed_link/services/admin_service.dart';
import 'package:agrimed_link/services/app_localizations.dart';
import 'package:agrimed_link/services/localization_service.dart';

void main() {
  setUp(() async {
    AdminService.isTestMode = true;
    await LocalizationService.instance.setLanguage('en');
  });

  group('Email Domain Enforcement Unit & Service Tests', () {
    test('AuthService.register rejects non-admin users without @gmail.com or @icloud.com', () async {
      // 1. Rejection for @yahoo.com
      expect(
        () => AuthService.register(
          name: 'Jane Doe',
          email: 'jane.doe@yahoo.com',
          phone: '+1-555-0100',
          password: 'Password123!',
          role: 'farmer',
        ),
        throwsA(predicate((e) => e.toString().contains('@gmail.com or @icloud.com'))),
      );

      // 2. Rejection for @example.com
      expect(
        () => AuthService.register(
          name: 'Mark Buyer',
          email: 'mark@example.com',
          phone: '+1-555-0101',
          password: 'Password123!',
          role: 'customer',
        ),
        throwsA(predicate((e) => e.toString().contains('@gmail.com or @icloud.com'))),
      );

      // 3. Rejection for @agrimedlink.com for non-admin
      expect(
        () => AuthService.register(
          name: 'Bob Supplier',
          email: 'bob@agrimedlink.com',
          phone: '+1-555-0102',
          password: 'Password123!',
          role: 'supplier',
        ),
        throwsA(predicate((e) => e.toString().contains('@gmail.com or @icloud.com'))),
      );
    });

    test('AuthService.register prohibits self-registration as admin', () async {
      expect(
        () => AuthService.register(
          name: 'Hacker Admin',
          email: 'admin.hacker@gmail.com',
          phone: '+1-555-9999',
          password: 'Password123!',
          role: 'admin',
        ),
        throwsA(predicate((e) => e.toString().contains('prohibited'))),
      );
    });

    test('AdminService.createUser strictly enforces @gmail.com or @icloud.com for non-admin', () async {
      // 1. Succeeds for @gmail.com
      final gmailUser = await AdminService.createUser(
        name: 'Direct Farmer',
        email: 'direct.farmer@gmail.com',
        password: 'Password123!',
        role: 'farmer',
      );
      expect(gmailUser['email'], equals('direct.farmer@gmail.com'));

      // 2. Succeeds for @icloud.com
      final icloudUser = await AdminService.createUser(
        name: 'Direct Advisor',
        email: 'direct.advisor@icloud.com',
        password: 'Password123!',
        role: 'advisor',
      );
      expect(icloudUser['email'], equals('direct.advisor@icloud.com'));

      // 3. Rejects invalid non-admin domain
      expect(
        () => AdminService.createUser(
          name: 'Invalid Domain User',
          email: 'invalid.user@hotmail.com',
          password: 'Password123!',
          role: 'farmer',
        ),
        throwsA(predicate((e) => e.toString().contains('@gmail.com or @icloud.com'))),
      );
    });
  });

  group('SignupScreen Email Domain Validation Widget Tests', () {
    testWidgets('SignupScreen form validator rejects non-gmail/icloud emails and accepts valid ones', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: const SignupScreen(),
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

      // Find the email TextFormField (second TextFormField on screen: Name is 1st, Email is 2nd)
      final emailField = find.byType(TextFormField).at(1);
      expect(emailField, findsOneWidget);

      // 1. Enter invalid domain email
      await tester.enterText(emailField, 'testuser@yahoo.com');
      await tester.pumpAndSettle();

      // Scroll to and tap Register button to trigger form validation
      final registerBtn = find.textContaining('Register as');
      await tester.ensureVisible(registerBtn);
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      // Verify validation error message is displayed
      expect(find.text('Email must end with @gmail.com or @icloud.com'), findsOneWidget);

      // 2. Enter valid @gmail.com email
      await tester.enterText(emailField, 'testuser@gmail.com');
      await tester.pumpAndSettle();

      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      // Verify domain error disappears
      expect(find.text('Email must end with @gmail.com or @icloud.com'), findsNothing);

      // 3. Enter valid @icloud.com email
      await tester.enterText(emailField, 'testuser@icloud.com');
      await tester.pumpAndSettle();

      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      expect(find.text('Email must end with @gmail.com or @icloud.com'), findsNothing);
    });
  });

  group('LoginScreen Email Domain Validation Widget Tests', () {
    testWidgets('LoginScreen form validator allows system admin and enforces @gmail.com/@icloud.com for others', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: const LoginScreen(),
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

      // Find email field (1st TextFormField on login screen)
      final emailField = find.byType(TextFormField).first;
      expect(emailField, findsOneWidget);

      // 1. Enter unauthorized domain email
      await tester.enterText(emailField, 'farmer@customdomain.com');
      await tester.pumpAndSettle();

      final signInBtn = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Verify validation error is displayed
      expect(find.text('Email must end with @gmail.com or @icloud.com'), findsOneWidget);

      // 2. Enter system.admin@agrimedlink.com (exempt unique platform admin)
      await tester.enterText(emailField, 'system.admin@agrimedlink.com');
      await tester.pumpAndSettle();

      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Admin email should NOT trigger the domain error
      expect(find.text('Email must end with @gmail.com or @icloud.com'), findsNothing);

      // 3. Enter @gmail.com email
      await tester.enterText(emailField, 'elena.farmer@gmail.com');
      await tester.pumpAndSettle();

      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Email must end with @gmail.com or @icloud.com'), findsNothing);
    });
  });
}
