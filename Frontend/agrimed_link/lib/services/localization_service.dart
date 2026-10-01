import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Representation of a supported language in AgriMed Link.
class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool isRtl;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.isRtl = false,
  });
}

/// Service managing the active locale and language preferences.
class LocalizationService {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  static const String _prefKey = 'selected_language_code';

  /// The 4 supported languages across the entire application (maximum 4 languages).
  static const List<AppLanguage> supportedLanguages = [
    AppLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
      isRtl: false,
    ),
    AppLanguage(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
      isRtl: false,
    ),
    AppLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
      isRtl: false,
    ),
    AppLanguage(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
      isRtl: true,
    ),
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('es'),
    Locale('ar'),
  ];

  final ValueNotifier<Locale> currentLocale = ValueNotifier<Locale>(const Locale('en'));

  /// Returns the current active [AppLanguage] metadata.
  AppLanguage get currentLanguage {
    final code = currentLocale.value.languageCode;
    return supportedLanguages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => supportedLanguages.first,
    );
  }

  /// Whether current active language uses Right-to-Left script.
  bool get isRtl => currentLanguage.isRtl;

  /// Initializes the service and loads saved preference.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null && isSupported(savedCode)) {
        currentLocale.value = Locale(savedCode);
      }
    } catch (_) {
      // Default to English if storage is unavailable
      currentLocale.value = const Locale('en');
    }
  }

  /// Sets the application language and persists the choice.
  Future<void> setLanguage(String code) async {
    if (!isSupported(code)) return;
    currentLocale.value = Locale(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {
      // Ignore persistence errors in test / isolated environments
    }
  }

  /// Checks if a language code is one of the 4 supported languages.
  static bool isSupported(String code) {
    return supportedLanguages.any((lang) => lang.code == code);
  }
}
