import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/services/mapbox_service.dart';
import 'package:agrimed_link/services/app_localizations.dart';
import 'package:agrimed_link/services/localization_service.dart';
import 'package:agrimed_link/services/currency_service.dart';
import 'package:agrimed_link/screens/maps/farm_map_screen.dart';
import 'package:agrimed_link/screens/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await LocalizationService.instance.init();
    await CurrencyService.instance.init();
    DashboardScreen.enablePriceTimer = false;
  });

  group('Mapbox Service Unit Tests', () {
    final mapbox = MapboxService.instance;

    test('Mapbox Public Token is configured and formatted correctly', () {
      expect(MapboxService.mapboxAccessToken, startsWith('pk.'));
      expect(MapboxService.mapboxAccessToken, contains('bXJrZXZpbjgyMC'));
    });

    test('Generates valid Static Map URLs with markers and styles', () {
      final url = mapbox.getStaticMapUrl(
        lat: 5.5083,
        lng: 10.6311,
        zoom: 12,
        style: 'outdoors-v12',
        markerLabel: 'farm',
        markerColor: '2E7D32',
      );

      expect(url, startsWith('https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/static/'));
      expect(url, contains('pin-s-farm+2E7D32(10.6311,5.5083)'));
      expect(url, contains('10.6311,5.5083,12,0'));
      expect(url, contains('access_token=${MapboxService.mapboxAccessToken}'));
    });

    test('Generates valid Static Route Map URLs connecting origin and destination', () {
      final routeUrl = mapbox.getRouteStaticMapUrl(
        originLat: 5.5083,
        originLng: 10.6311,
        destLat: 4.0511,
        destLng: 9.7042,
        style: 'streets-v12',
      );

      expect(routeUrl, startsWith('https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/'));
      expect(routeUrl, contains('pin-s-farm+2E7D32(10.6311,5.5083)'));
      expect(routeUrl, contains('pin-s-car+E65100(9.7042,4.0511)'));
      expect(routeUrl, contains('/auto/'));
      expect(routeUrl, contains('access_token=${MapboxService.mapboxAccessToken}'));
    });

    test('Calculates delivery fee in XAF based on route distance', () {
      expect(mapbox.calculateDeliveryFee(0), 500);
      expect(mapbox.calculateDeliveryFee(5), 1250);   // 500 + 5*150 = 1250
      expect(mapbox.calculateDeliveryFee(10), 2000);  // 500 + 10*150 = 2000
      expect(mapbox.calculateDeliveryFee(25.4), 4300); // 500 + 3810 = 4310 -> 4300
    });

    test('Default Cameroon Agricultural Hubs are populated with coordinates & crops', () async {
      final farms = await mapbox.fetchFarms();
      expect(farms.isNotEmpty, isTrue);
      expect(farms.length, greaterThanOrEqualTo(5));

      final foumbot = farms.firstWhere((f) => f.name.contains('Foumbot'));
      expect(foumbot.latitude, closeTo(5.5083, 0.01));
      expect(foumbot.longitude, closeTo(10.6311, 0.01));
      expect(foumbot.crops, contains('Tomatoes'));
      expect(foumbot.farmerName, isNotEmpty);
      expect(foumbot.rating, greaterThan(4.0));
    });

    test('MapPlace and DeliveryRoute parse JSON correctly', () {
      final place = MapPlace.fromJson({
        'id': 'place.123',
        'place_name': 'Yaounde, Cameroon',
        'text': 'Yaounde',
        'center': [11.52, 3.84],
      });
      expect(place.text, 'Yaounde');
      expect(place.longitude, 11.52);
      expect(place.latitude, 3.84);

      final route = DeliveryRoute.fromJson({
        'distanceKm': 244.5,
        'durationMinutes': 360,
        'deliveryFeeXAF': 37200,
        'staticRouteMapUrl': 'https://example.com/route.png',
        'steps': [
          {'instruction': 'Head south'},
          {'instruction': 'Take N3 highway'}
        ],
      });
      expect(route.distanceKm, 244.5);
      expect(route.durationMinutes, 360);
      expect(route.deliveryFeeXAF, 37200);
      expect(route.steps.length, 2);
      expect(route.steps.first, 'Head south');
    });
  });

  group('FarmMapScreen UI & Widget Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1080, 1920);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    Widget buildTestScreen(Widget child) {
      return MaterialApp(
        locale: const Locale('en'),
        supportedLocales: LocalizationService.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
        ],
        home: child,
      );
    }

    testWidgets('FarmMapScreen renders header, search bar, map action buttons, and farm carousel', (tester) async {
      await tester.pumpWidget(buildTestScreen(const FarmMapScreen()));
      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('Farm & Delivery Map Explorer'), findsOneWidget);

      // Verify Search TextField
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search city, farm, or market in Cameroon...'), findsOneWidget);

      // Verify Map Control Buttons
      expect(find.byTooltip('Change Map Style'), findsOneWidget);
      expect(find.byTooltip('Zoom In'), findsOneWidget);
      expect(find.byTooltip('Zoom Out'), findsOneWidget);
      expect(find.byTooltip('Reset to Cameroon'), findsOneWidget);

      // Verify Farm Carousel Content
      expect(find.text('Verified Farms & Hubs'), findsOneWidget);
      expect(find.text('Calculate Route'), findsOneWidget);
      expect(find.text('Foumbot High-Yield Tomato & Pepper Farm'), findsOneWidget);
      expect(find.text('Tomatoes'), findsWidgets);
    });

    testWidgets('Map Style Picker opens and shows all 4 map styles', (tester) async {
      await tester.pumpWidget(buildTestScreen(const FarmMapScreen()));
      await tester.pumpAndSettle();

      // Tap layers icon
      await tester.tap(find.byTooltip('Change Map Style'));
      await tester.pumpAndSettle();

      // Verify Sheet Header and Options
      expect(find.text('Select Map Layer Style'), findsOneWidget);
      expect(find.text('Outdoors & Agricultural Terrain'), findsOneWidget);
      expect(find.text('High-Resolution Satellite'), findsOneWidget);
      expect(find.text('Streets & Navigation'), findsOneWidget);
      expect(find.text('Dark High-Contrast'), findsOneWidget);

      // Tap Satellite
      await tester.tap(find.text('High-Resolution Satellite'));
      await tester.pumpAndSettle();

      // Sheet should close
      expect(find.text('Select Map Layer Style'), findsNothing);
    });

    testWidgets('Calculate Route button opens Delivery Route & Fare Calculator modal', (tester) async {
      await tester.pumpWidget(buildTestScreen(const FarmMapScreen()));
      await tester.pumpAndSettle();

      // Tap "Calculate Route"
      await tester.tap(find.text('Calculate Route'));
      await tester.pumpAndSettle();

      // Verify Calculator Sheet Content
      expect(find.text('Delivery Route & Fare Calculator'), findsOneWidget);
      expect(find.text('Powered by Mapbox Directions Engine'), findsOneWidget);
      expect(find.text('PICKUP ORIGIN (FARM)'), findsOneWidget);
      expect(find.text('Destination (Drop-off Address / City):'), findsOneWidget);

      // Verify quick presets
      expect(find.text('Douala (Akwa)'), findsOneWidget);
      expect(find.text('Yaoundé (Bastos)'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Delivery Route & Fare Calculator'), findsNothing);
    });

    testWidgets('Dashboard displays Map button in AppBar and Sidebar Navigation', (tester) async {
      await tester.pumpWidget(buildTestScreen(const DashboardScreen()));
      await tester.pumpAndSettle();

      // Verify AppBar Map button
      expect(find.byTooltip('Farm & Delivery Map'), findsOneWidget);

      // Open Sidebar Drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Verify Sidebar Map ListTile
      expect(find.text('Farm & Delivery Map'), findsWidgets);
    });
  });
}
