import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported platform trade currencies
enum AppCurrency {
  usd(
    code: 'USD',
    symbol: '\$',
    name: 'US Dollar',
    flag: '🇺🇸',
    rateToUSD: 1.0,
    decimals: 2,
  ),
  eur(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    flag: '🇪🇺',
    rateToUSD: 0.92,
    decimals: 2,
  ),
  fcfa(
    code: 'FCFA',
    symbol: 'FCFA',
    name: 'Franc CFA',
    flag: '🌍',
    rateToUSD: 605.0,
    decimals: 0,
  );

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
    required this.rateToUSD,
    required this.decimals,
  });

  final String code;
  final String symbol;
  final String name;
  final String flag;
  final double rateToUSD;
  final int decimals;
}

class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  static const String _prefKey = 'selected_currency';

  final ValueNotifier<AppCurrency> currentCurrency =
      ValueNotifier<AppCurrency>(AppCurrency.usd);

  AppCurrency get currency => currentCurrency.value;

  /// Initialize and load saved preference
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null) {
        final match = AppCurrency.values.firstWhere(
          (c) => c.code.toUpperCase() == savedCode.toUpperCase(),
          orElse: () => AppCurrency.usd,
        );
        currentCurrency.value = match;
      }
    } catch (_) {}
  }

  /// Switch the active platform currency and persist
  Future<void> setCurrency(AppCurrency newCurrency) async {
    currentCurrency.value = newCurrency;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newCurrency.code);
    } catch (_) {}
  }

  /// Convert an amount from one currency to another
  double convert(
    double amount, {
    required AppCurrency from,
    required AppCurrency to,
  }) {
    if (from == to) return amount;
    final amountInUSD = amount / from.rateToUSD;
    return amountInUSD * to.rateToUSD;
  }

  /// Format an amount from USD into the target/active currency
  String format(
    double amountInUSD, {
    AppCurrency? currency,
    bool showCode = false,
  }) {
    final target = currency ?? currentCurrency.value;
    final converted = convert(amountInUSD, from: AppCurrency.usd, to: target);
    return formatAmount(converted, target, showCode: showCode);
  }

  /// Format an amount that is already in [currency]
  String formatAmount(
    double amount,
    AppCurrency currency, {
    bool showCode = false,
  }) {
    switch (currency) {
      case AppCurrency.usd:
        final formatted = amount.toStringAsFixed(2);
        return showCode ? '\$$formatted USD' : '\$$formatted';

      case AppCurrency.eur:
        final formatted = amount.toStringAsFixed(2);
        return showCode ? '€$formatted EUR' : '€$formatted';

      case AppCurrency.fcfa:
        final rounded = amount.round();
        final formatted = rounded.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]} ',
            );
        return showCode ? '$formatted FCFA' : '$formatted FCFA';
    }
  }

  /// List all supported currencies
  List<AppCurrency> get supportedCurrencies => AppCurrency.values;
}
