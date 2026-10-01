import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimed_link/main.dart';

void main() {
  testWidgets('Auth screens smoke test', (WidgetTester tester) async {
    // Build the app starting at login (no stored session)
    await tester.pumpWidget(const MyApp(initialUser: null));
    await tester.pumpAndSettle();

    // 1. Login screen shown
    expect(find.text('Welcome Back'), findsOneWidget);

    // 2. Navigate to Sign Up
    final signUpLink = find.text('Sign Up');
    expect(signUpLink, findsOneWidget);
    await tester.ensureVisible(signUpLink);
    await tester.tap(signUpLink);
    await tester.pumpAndSettle();

    // 3. Sign Up screen is shown
    expect(find.text('Join AgriMed Link'), findsOneWidget);
    expect(find.text('Buyer'), findsOneWidget);

    // 4. Select Buyer role
    final buyerRoleCard = find.text('Buyer');
    await tester.ensureVisible(buyerRoleCard);
    await tester.tap(buyerRoleCard);
    await tester.pumpAndSettle();

    // 5. Register button reflects role selection
    expect(find.text('Register as Buyer'), findsOneWidget);

    // 6. Navigate back to Login
    final signInLink = find.text('Sign In');
    await tester.ensureVisible(signInLink);
    await tester.tap(signInLink);
    await tester.pumpAndSettle();

    // 7. Login screen is shown again
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('Dashboard shows products and sidebar navigation', (
    WidgetTester tester,
  ) async {
    // Directly build the app as if the user is already logged in
    await tester.pumpWidget(
      const MyApp(
        initialUser: null, // start at login
      ),
    );
    await tester.pumpAndSettle();

    // Push directly to dashboard with test user args (no network call)
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pushNamed(
      '/dashboard',
      arguments: {
        'email': 'test@agrimed.com',
        'role': 'farmer',
        'name': 'Test User',
      },
    );
    await tester.pumpAndSettle();

    // Dashboard Products view shown
    expect(find.text('Marketplace Products'), findsOneWidget);
    expect(find.text('Featured Supplies'), findsOneWidget);

    // Open the sidebar drawer
    final Scaffold scaffold = tester.firstWidget<Scaffold>(
      find.byType(Scaffold),
    );
    expect(scaffold.drawer, isNotNull);
    final scaffoldState = tester.firstState<ScaffoldState>(
      find.byType(Scaffold),
    );
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Sidebar contains navigation items and role badge
    expect(find.text('FARMER'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Crops'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // Navigate to Crops tab via sidebar
    await tester.tap(find.text('Crops'));
    await tester.pumpAndSettle();
    expect(find.text('Medicinal Crops'), findsOneWidget);

    // Open drawer and navigate to Scan
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan Crop/Product'), findsOneWidget);
  });
}
