import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/main.dart';
import 'package:agrimed_link/services/localization_service.dart';
import 'package:agrimed_link/services/app_localizations.dart';

import 'package:agrimed_link/widgets/language_selector_dialog.dart';

void main() {
  setUp(() async {
    // Reset to English before each test
    await LocalizationService.instance.setLanguage('en');
  });

  group('LocalizationService & AppLocalizations Unit Tests', () {
    test('Service supports exactly 4 languages with valid configurations', () {
      final supported = LocalizationService.supportedLanguages;
      expect(supported.length, 4, reason: 'Must support up to 4 languages maximum');

      final codes = supported.map((l) => l.code).toList();
      expect(codes, containsAll(['en', 'fr', 'es', 'ar']));

      final arLang = supported.firstWhere((l) => l.code == 'ar');
      expect(arLang.isRtl, isTrue, reason: 'Arabic must be configured as RTL');

      final enLang = supported.firstWhere((l) => l.code == 'en');
      expect(enLang.isRtl, isFalse);

      expect(LocalizationService.isSupported('en'), isTrue);
      expect(LocalizationService.isSupported('fr'), isTrue);
      expect(LocalizationService.isSupported('es'), isTrue);
      expect(LocalizationService.isSupported('ar'), isTrue);
      expect(LocalizationService.isSupported('de'), isFalse);
    });

    test('Translations resolve accurately for English, French, Spanish, and Arabic', () {
      final en = AppLocalizations(const Locale('en'));
      final fr = AppLocalizations(const Locale('fr'));
      final es = AppLocalizations(const Locale('es'));
      final ar = AppLocalizations(const Locale('ar'));

      // Welcome Back
      expect(en.translate('welcome_back'), 'Welcome Back');
      expect(fr.translate('welcome_back'), 'Bon retour');
      expect(es.translate('welcome_back'), 'Bienvenido de nuevo');
      expect(ar.translate('welcome_back'), 'أهلاً بك من جديد');

      // Navigation items
      expect(en.translate('nav_products'), 'Products');
      expect(fr.translate('nav_products'), 'Produits');
      expect(es.translate('nav_products'), 'Productos');
      expect(ar.translate('nav_products'), 'المنتجات');

      expect(en.translate('nav_crops'), 'Crops');
      expect(fr.translate('nav_crops'), 'Cultures');
      expect(es.translate('nav_crops'), 'Cultivos');
      expect(ar.translate('nav_crops'), 'المحاصيل');

      // Farmer actions
      expect(en.translate('add_crop'), 'Add Crop');
      expect(fr.translate('add_crop'), 'Ajouter culture');
      expect(es.translate('add_crop'), 'Añadir cultivo');
      expect(ar.translate('add_crop'), 'إضافة محصول');

      // Parameter replacement
      expect(
        en.translate('register_as', {'role': 'Farmer'}),
        'Register as Farmer',
      );
      expect(
        fr.translate('register_as', {'role': 'Agriculteur'}),
        "S'inscrire en tant que Agriculteur",
      );
    });

    test('Fallback mechanism returns English or key itself when missing', () {
      final custom = AppLocalizations(const Locale('fr'));
      // A key not in French falls back to English if present
      expect(custom.translate('app_name'), 'AgriMed Link');
      // A completely non-existent key returns the key itself
      expect(custom.translate('non_existent_key'), 'non_existent_key');
    });

    test('LocalizationService reactive updates notify listeners', () async {
      Locale? updatedLocale;
      void listener() {
        updatedLocale = LocalizationService.instance.currentLocale.value;
      }

      LocalizationService.instance.currentLocale.addListener(listener);

      await LocalizationService.instance.setLanguage('fr');
      expect(updatedLocale?.languageCode, 'fr');
      expect(LocalizationService.instance.currentLanguage.nativeName, 'Français');

      await LocalizationService.instance.setLanguage('es');
      expect(updatedLocale?.languageCode, 'es');
      expect(LocalizationService.instance.currentLanguage.nativeName, 'Español');

      await LocalizationService.instance.setLanguage('ar');
      expect(updatedLocale?.languageCode, 'ar');
      expect(LocalizationService.instance.isRtl, isTrue);

      LocalizationService.instance.currentLocale.removeListener(listener);
    });
  });

  group('In-App Language Switcher Widget Tests', () {
    testWidgets('User can open language modal and reactively switch UI language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp(initialUser: null));
      await tester.pumpAndSettle();

      // 1. Initially in English
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // 2. Tap language picker button on Login screen
      final pickerButton = find.byType(LanguagePickerButton);
      expect(pickerButton, findsOneWidget);
      await tester.tap(pickerButton);
      await tester.pumpAndSettle();

      // 3. Language selection modal displays all 4 languages
      expect(find.text('Select Language'), findsOneWidget);
      expect(find.text('English'), findsWidgets);
      expect(find.text('Français'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);

      // 4. Tap French
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();

      // 5. Verify UI instantly updates to French
      expect(find.text('Bon retour'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);

      // 6. Tap language picker again and select Spanish
      await tester.tap(find.byType(LanguagePickerButton));
      await tester.pumpAndSettle();

      expect(find.text('Español'), findsOneWidget);
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();

      // 7. Verify UI instantly updates to Spanish
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Bon retour'), findsNothing);

      // 8. Tap language picker again and select Arabic
      await tester.tap(find.byType(LanguagePickerButton));
      await tester.pumpAndSettle();

      expect(find.text('العربية'), findsOneWidget);
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      // 9. Verify UI instantly updates to Arabic
      expect(find.text('أهلاً بك من جديد'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('Bienvenido de nuevo'), findsNothing);

      // 10. Switch back to English
      await tester.tap(find.byType(LanguagePickerButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English').first);
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}
