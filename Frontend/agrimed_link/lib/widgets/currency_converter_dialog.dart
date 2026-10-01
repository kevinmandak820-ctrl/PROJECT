import 'package:flutter/material.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';

/// Shows the interactive Currency Converter dialog
void showCurrencyConverterDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext ctx) => const CurrencyConverterDialog(),
  );
}

class CurrencyConverterDialog extends StatefulWidget {
  const CurrencyConverterDialog({super.key});

  static void show(BuildContext context) => showCurrencyConverterDialog(context);

  @override
  State<CurrencyConverterDialog> createState() =>
      _CurrencyConverterDialogState();
}

class _CurrencyConverterDialogState extends State<CurrencyConverterDialog> {
  final TextEditingController _amountController =
      TextEditingController(text: '100');
  AppCurrency _sourceCurrency = CurrencyService.instance.currency;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _inputAmount {
    final text = _amountController.text.trim().replaceAll(' ', '');
    return double.tryParse(text) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: const Icon(
                      Icons.currency_exchange_rounded,
                      color: AppTheme.primaryGreen,
                      size: 26.0,
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Currency Converter',
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        Text(
                          'FCFA • EURO • DOLLAR Multi-Exchange',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: AppTheme.lightText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.lightText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),

              // Converter Input Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(
                    color: AppTheme.secondaryGreen.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount to Convert',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        // Amount input
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                                vertical: 12.0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(
                                  color: AppTheme.secondaryGreen.withOpacity(0.3),
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10.0),

                        // Source Currency Selector Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: AppTheme.secondaryGreen.withOpacity(0.3),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AppCurrency>(
                              value: _sourceCurrency,
                              items: CurrencyService.instance.supportedCurrencies
                                  .map((currency) {
                                return DropdownMenuItem<AppCurrency>(
                                  value: currency,
                                  child: Row(
                                    children: [
                                      Text(currency.flag,
                                          style: const TextStyle(fontSize: 18.0)),
                                      const SizedBox(width: 6.0),
                                      Text(
                                        currency.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.0,
                                          color: AppTheme.darkText,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (newCurrency) {
                                if (newCurrency != null) {
                                  setState(() => _sourceCurrency = newCurrency);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18.0),

              // Live Converted Cards
              const Text(
                'Live Converted Values',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 10.0),

              ...CurrencyService.instance.supportedCurrencies.map((targetCurrency) {
                final converted = CurrencyService.instance.convert(
                  _inputAmount,
                  from: _sourceCurrency,
                  to: targetCurrency,
                );
                final formatted = CurrencyService.instance.formatAmount(
                  converted,
                  targetCurrency,
                  showCode: false,
                );
                final isSource = targetCurrency == _sourceCurrency;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSource
                        ? AppTheme.primaryGreen.withOpacity(0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: isSource
                          ? AppTheme.primaryGreen.withOpacity(0.5)
                          : Colors.black.withOpacity(0.08),
                      width: isSource ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        targetCurrency.flag,
                        style: const TextStyle(fontSize: 24.0),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${targetCurrency.name} (${targetCurrency.code})',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: isSource
                                    ? AppTheme.primaryGreen
                                    : AppTheme.lightText,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              formatted,
                              style: TextStyle(
                                fontSize: 17.0,
                                fontWeight: FontWeight.bold,
                                color: isSource
                                    ? AppTheme.primaryGreen
                                    : AppTheme.darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSource)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Text(
                            'SOURCE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16.0),

              // Active Platform Currency Selection
              const Divider(),
              const SizedBox(height: 8.0),
              const Text(
                'Set Active Platform Currency:',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6.0),
              const Text(
                'Marketplace items, crops, and live tickers will display in this currency.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.lightText),
              ),
              const SizedBox(height: 12.0),

              ValueListenableBuilder<AppCurrency>(
                valueListenable: CurrencyService.instance.currentCurrency,
                builder: (context, activeCurrency, _) {
                  return Row(
                    children: CurrencyService.instance.supportedCurrencies
                        .map((currency) {
                      final isSelected = currency == activeCurrency;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: InkWell(
                            onTap: () {
                              CurrencyService.instance.setCurrency(currency);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Active currency updated to ${currency.name} (${currency.code})',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: AppTheme.primaryGreen,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                                horizontal: 6.0,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryGreen
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryGreen
                                      : Colors.black12,
                                  width: 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primaryGreen
                                              .withOpacity(0.3),
                                          blurRadius: 8.0,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    currency.flag,
                                    style: const TextStyle(fontSize: 20.0),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    currency.code,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.0,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.darkText,
                                    ),
                                  ),
                                  Text(
                                    currency.symbol,
                                    style: TextStyle(
                                      fontSize: 11.0,
                                      color: isSelected
                                          ? Colors.white70
                                          : AppTheme.lightText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 18.0),

              // Quick Agricultural Commodity Presets
              const Text(
                'Agricultural Commodity Presets',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.lightText,
                ),
              ),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children: [
                  ActionChip(
                    avatar: const Text('🌿'),
                    label: const Text('Aloe Vera \$12/kg',
                        style: TextStyle(fontSize: 11.0)),
                    onPressed: () {
                      setState(() {
                        _amountController.text = '12';
                        _sourceCurrency = AppCurrency.usd;
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Text('🌱'),
                    label: const Text('Bio-Fertilizer \$25',
                        style: TextStyle(fontSize: 11.0)),
                    onPressed: () {
                      setState(() {
                        _amountController.text = '24.99';
                        _sourceCurrency = AppCurrency.usd;
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Text('🌍'),
                    label: const Text('15 000 FCFA Seedling',
                        style: TextStyle(fontSize: 11.0)),
                    onPressed: () {
                      setState(() {
                        _amountController.text = '15000';
                        _sourceCurrency = AppCurrency.fcfa;
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Text('🇪🇺'),
                    label: const Text('50 € Herbal Batch',
                        style: TextStyle(fontSize: 11.0)),
                    onPressed: () {
                      setState(() {
                        _amountController.text = '50';
                        _sourceCurrency = AppCurrency.eur;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18.0),

              // Done button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                child: const Text(
                  'Close Converter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
