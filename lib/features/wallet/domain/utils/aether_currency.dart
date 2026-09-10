import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class AetherCurrency {
  final String code;
  final String symbol;
  final String name;

  const AetherCurrency(this.code, this.symbol, this.name);

  static const List<AetherCurrency> supportedCurrencies = [
    AetherCurrency('PKR', 'Rs ', 'Pakistani Rupee (PKR)'),
    AetherCurrency('USD', '\$ ', 'US Dollar (USD)'),
    AetherCurrency('EUR', '€ ', 'Euro (EUR)'),
    AetherCurrency('GBP', '£ ', 'British Pound (GBP)'),
    AetherCurrency('AED', 'د.إ ', 'UAE Dirham (AED)'),
    AetherCurrency('SAR', 'ر.س ', 'Saudi Riyal (SAR)'),
    AetherCurrency('TRY', '₺ ', 'Turkish Lira (TRY)'),
    AetherCurrency('INR', '₹ ', 'Indian Rupee (INR)'),
    AetherCurrency('BTC', '₿ ', 'Bitcoin (BTC)'),
  ];

  static AetherCurrency get defaultCurrency => supportedCurrencies.first; // PKR Default

  static String get currentCurrencyCode {
    try {
      if (Hive.isBoxOpen('aether_settings')) {
        final box = Hive.box('aether_settings');
        return (box.get('primary_currency') as String?) ?? 'PKR';
      }
    } catch (_) {}
    return 'PKR';
  }

  static AetherCurrency get currentCurrency => fromCode(currentCurrencyCode);

  static String get currentSymbol => currentCurrency.symbol;

  static AetherCurrency fromCode(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => defaultCurrency,
    );
  }

  // Global formatting utility to ensure perfect rendering across the app
  static String format(double amount, {String? currencyCode, bool compact = false, int? decimalDigits}) {
    final currency = (currencyCode != null && currencyCode.trim().isNotEmpty)
        ? fromCode(currencyCode)
        : currentCurrency;

    int decimals = decimalDigits ?? (currency.code == 'PKR' ? 0 : 2);

    if (compact) {
      final compactNum = NumberFormat.compact().format(amount);
      return '${currency.symbol}$compactNum';
    }

    final formatter = NumberFormat.currency(
      symbol: currency.symbol,
      decimalDigits: decimals,
    );

    return formatter.format(amount);
  }
}

// Global Riverpod Provider for Primary Currency Selection
final primaryCurrencyProvider = StateNotifierProvider<PrimaryCurrencyNotifier, String>((ref) {
  return PrimaryCurrencyNotifier();
});

class PrimaryCurrencyNotifier extends StateNotifier<String> {
  PrimaryCurrencyNotifier() : super(AetherCurrency.currentCurrencyCode);

  Future<void> setCurrency(String code) async {
    state = code;
    try {
      final box = Hive.isBoxOpen('aether_settings')
          ? Hive.box('aether_settings')
          : await Hive.openBox('aether_settings');
      await box.put('primary_currency', code);
    } catch (_) {}
  }
}