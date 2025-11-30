// lib/utilities/currency_converter.dart
// FREE currency conversion using exchangerate-api.com (1500 free requests/month)
// Falls back to static rates if API fails

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyConverter {
  // FREE API - No key needed for basic usage
  // Alternative: Use static rates if you exceed limits
  static const String _baseUrl = 'https://api.exchangerate-api.com/v4/latest/';

  // Cache duration: 6 hours (to minimize API calls)
  static const Duration _cacheDuration = Duration(hours: 6);

  // Static fallback rates (updated periodically)
  // These are approximate rates as of 2024
  static const Map<String, double> _fallbackRatesFromMYR = {
    'MYR': 1.0,
    'USD': 0.21,
    'EUR': 0.20,
    'GBP': 0.17,
    'JPY': 33.0,
    'SGD': 0.29,
    'THB': 7.8,
    'IDR': 3400.0,
    'VND': 5300.0,
    'PHP': 12.3,
    'KRW': 290.0,
    'CNY': 1.55,
    'HKD': 1.68,
    'TWD': 6.9,
    'AUD': 0.33,
    'NZD': 0.36,
    'INR': 18.0,
  };

  /// Convert amount from MYR to target currency
  static Future<CurrencyResult> convertFromMYR(
      double amountMYR,
      String targetCurrency,
      ) async {
    try {
      final rate = await getExchangeRate('MYR', targetCurrency);
      final converted = amountMYR * rate.rate;

      return CurrencyResult(
        originalAmount: amountMYR,
        originalCurrency: 'MYR',
        convertedAmount: converted,
        targetCurrency: targetCurrency,
        exchangeRate: rate.rate,
        isLive: rate.isLive,
        lastUpdated: rate.lastUpdated,
      );
    } catch (e) {
      // Use fallback
      final fallbackRate = _fallbackRatesFromMYR[targetCurrency] ?? 1.0;
      return CurrencyResult(
        originalAmount: amountMYR,
        originalCurrency: 'MYR',
        convertedAmount: amountMYR * fallbackRate,
        targetCurrency: targetCurrency,
        exchangeRate: fallbackRate,
        isLive: false,
        lastUpdated: null,
      );
    }
  }

  /// Convert amount to MYR from source currency
  static Future<CurrencyResult> convertToMYR(
      double amount,
      String sourceCurrency,
      ) async {
    try {
      final rate = await getExchangeRate(sourceCurrency, 'MYR');
      final converted = amount * rate.rate;

      return CurrencyResult(
        originalAmount: amount,
        originalCurrency: sourceCurrency,
        convertedAmount: converted,
        targetCurrency: 'MYR',
        exchangeRate: rate.rate,
        isLive: rate.isLive,
        lastUpdated: rate.lastUpdated,
      );
    } catch (e) {
      // Use fallback (inverse of MYR rate)
      final myrRate = _fallbackRatesFromMYR[sourceCurrency] ?? 1.0;
      final fallbackRate = myrRate > 0 ? 1 / myrRate : 1.0;
      return CurrencyResult(
        originalAmount: amount,
        originalCurrency: sourceCurrency,
        convertedAmount: amount * fallbackRate,
        targetCurrency: 'MYR',
        exchangeRate: fallbackRate,
        isLive: false,
        lastUpdated: null,
      );
    }
  }

  /// Get exchange rate between two currencies
  static Future<ExchangeRate> getExchangeRate(
      String from,
      String to,
      ) async {
    // Check cache first
    final cached = await _getCachedRate(from, to);
    if (cached != null) {
      return cached;
    }

    // Fetch from API
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$from'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;
        final rate = (rates[to] as num?)?.toDouble();

        if (rate != null) {
          final result = ExchangeRate(
            from: from,
            to: to,
            rate: rate,
            isLive: true,
            lastUpdated: DateTime.now(),
          );

          // Cache the result
          await _cacheRate(result);

          return result;
        }
      }
    } catch (e) {
      // Fall through to fallback
    }

    // Use fallback rates
    return _getFallbackRate(from, to);
  }

  /// Get fallback rate (static, offline)
  static ExchangeRate _getFallbackRate(String from, String to) {
    double rate;

    if (from == 'MYR') {
      rate = _fallbackRatesFromMYR[to] ?? 1.0;
    } else if (to == 'MYR') {
      final fromRate = _fallbackRatesFromMYR[from] ?? 1.0;
      rate = fromRate > 0 ? 1 / fromRate : 1.0;
    } else {
      // Cross rate through MYR
      final fromToMYR = _fallbackRatesFromMYR[from] ?? 1.0;
      final toFromMYR = _fallbackRatesFromMYR[to] ?? 1.0;
      rate = fromToMYR > 0 ? toFromMYR / fromToMYR : 1.0;
    }

    return ExchangeRate(
      from: from,
      to: to,
      rate: rate,
      isLive: false,
      lastUpdated: null,
    );
  }

  /// Cache rate to SharedPreferences
  static Future<void> _cacheRate(ExchangeRate rate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'exchange_rate_${rate.from}_${rate.to}';
      final data = {
        'rate': rate.rate,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(key, json.encode(data));
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Get cached rate if still valid
  static Future<ExchangeRate?> _getCachedRate(String from, String to) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'exchange_rate_${from}_$to';
      final cached = prefs.getString(key);

      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          return ExchangeRate(
            from: from,
            to: to,
            rate: data['rate'],
            isLive: true,
            lastUpdated: timestamp,
          );
        }
      }
    } catch (e) {
      // Ignore cache errors
    }
    return null;
  }

  /// Get currency symbol
  static String getCurrencySymbol(String currencyCode) {
    const symbols = {
      'MYR': 'RM',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'SGD': 'S\$',
      'THB': '฿',
      'IDR': 'Rp',
      'VND': '₫',
      'PHP': '₱',
      'KRW': '₩',
      'CNY': '¥',
      'HKD': 'HK\$',
      'TWD': 'NT\$',
      'AUD': 'A\$',
      'NZD': 'NZ\$',
      'INR': '₹',
    };
    return symbols[currencyCode] ?? currencyCode;
  }

  /// Format amount with currency symbol
  static String formatCurrency(double amount, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);

    // No decimals for these currencies
    if (['JPY', 'KRW', 'IDR', 'VND'].contains(currencyCode)) {
      return '$symbol${amount.toStringAsFixed(0)}';
    }

    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Get list of supported currencies
  static List<String> getSupportedCurrencies() {
    return _fallbackRatesFromMYR.keys.toList()..sort();
  }
}

// ============================================
// DATA CLASSES
// ============================================

class ExchangeRate {
  final String from;
  final String to;
  final double rate;
  final bool isLive;
  final DateTime? lastUpdated;

  const ExchangeRate({
    required this.from,
    required this.to,
    required this.rate,
    required this.isLive,
    this.lastUpdated,
  });
}

class CurrencyResult {
  final double originalAmount;
  final String originalCurrency;
  final double convertedAmount;
  final String targetCurrency;
  final double exchangeRate;
  final bool isLive;
  final DateTime? lastUpdated;

  const CurrencyResult({
    required this.originalAmount,
    required this.originalCurrency,
    required this.convertedAmount,
    required this.targetCurrency,
    required this.exchangeRate,
    required this.isLive,
    this.lastUpdated,
  });

  String get formattedOriginal {
    return CurrencyConverter.formatCurrency(originalAmount, originalCurrency);
  }

  String get formattedConverted {
    return CurrencyConverter.formatCurrency(convertedAmount, targetCurrency);
  }

  String get rateDisplay {
    return '1 $originalCurrency = ${exchangeRate.toStringAsFixed(4)} $targetCurrency';
  }
}