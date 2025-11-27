class CurrencyHelper {
  static String formatLocalCurrency(dynamic amount, String currency) {
    final symbols = {
      'JPY': '¥',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'CNY': '¥',
      'THB': '฿',
      'SGD': 'S\$',
      'IDR': 'Rp',
      'KRW': '₩',
      'AUD': 'A\$',
      'NZD': 'NZ\$',
      'VND': '₫',
      'PHP': '₱',
      'TWD': 'NT\$',
      'HKD': 'HK\$',
      'MYR': 'RM',
    };

    final symbol = symbols[currency] ?? '$currency ';
    final numAmount = amount is num ? amount.toDouble() : 0.0;

    if (['JPY', 'KRW', 'IDR', 'VND'].contains(currency)) {
      return '$symbol${numAmount.toStringAsFixed(0)}';
    }

    return '$symbol${numAmount.toStringAsFixed(2)}';
  }

  static String getFeatureLabel(String feature) {
    final labels = {
      'weather-smart': '🌤️ Weather-Smart',
      'real-restaurants': '🍽️ Real Restaurants',
      'openstreetmap': '🗺️ OpenStreetMap',
      'free-api': '🆓 Free API',
      'currency': '💱 Multi-Currency',
      'no-duplicates': '✅ No Duplicates',
      'halal-filter': '☪️ Halal Filter',
      'route': '🗺️ Optimized Route',
    };
    return labels[feature] ?? feature;
  }
}