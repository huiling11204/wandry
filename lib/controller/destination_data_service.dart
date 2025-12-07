import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches real operating hours and entrance fees from OpenStreetMap/Wikidata
class DestinationDataService {
  // Cache to avoid repeated API calls
  static final Map<String, Map<String, dynamic>> _cache = {};

  // Rate limiting - minimum 300ms between calls
  static DateTime? _lastApiCall;
  static const _minDelayMs = 300;

  /// Fetches enriched data for a destination using coordinates
  static Future<Map<String, dynamic>> fetchDestinationData({
    required String placeName,
    required double latitude,
    required double longitude,
    String? country,
    String? category,
  }) async {
    // Check cache first
    final cacheKey =
        '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Initialize result with default values
    final result = <String, dynamic>{
      'operating_hours': null,
      'entrance_fee': null,
      'website': null,
      'phone': null,
      'description': null,
      'image_url': null,
      'data_source': 'estimated',
      'hours_verified': false,
      'fee_verified': false,
    };

    // Step 1: Try OpenStreetMap (best for hours & fees)
    try {
      final osmData = await _fetchFromOSM(latitude, longitude, placeName);
      if (osmData != null) {
        if (osmData['opening_hours'] != null) {
          result['operating_hours'] = _formatOpeningHours(
            osmData['opening_hours'],
          );
          result['hours_verified'] = true;
          result['data_source'] = 'osm';
        }
        if (osmData['fee'] != null || osmData['charge'] != null) {
          result['entrance_fee'] = _parseFee(
            osmData['fee'] ?? osmData['charge'],
            country,
          );
          result['fee_verified'] = true;
        }
        if (osmData['website'] != null) {
          result['website'] = osmData['website'];
        }
        if (osmData['phone'] != null) {
          result['phone'] = osmData['phone'];
        }
        // Check for free admission
        if (osmData['fee'] == 'no' || osmData['access'] == 'yes') {
          result['entrance_fee'] = {
            'amount': 0,
            'currency': 'FREE',
            'display': 'Free admission',
          };
          result['fee_verified'] = true;
        }
      }
    } catch (e) {
      print('OSM fetch error: $e');
    }

    // Step 2: If still missing data, try Wikidata
    if (result['operating_hours'] == null || result['entrance_fee'] == null) {
      try {
        final wikidataResult = await _fetchFromWikidata(placeName, country);
        if (wikidataResult != null) {
          if (result['operating_hours'] == null &&
              wikidataResult['opening_hours'] != null) {
            result['operating_hours'] = wikidataResult['opening_hours'];
            result['hours_verified'] = true;
            if (result['data_source'] == 'estimated')
              result['data_source'] = 'wikidata';
          }
          if (result['entrance_fee'] == null &&
              wikidataResult['entrance_fee'] != null) {
            result['entrance_fee'] = wikidataResult['entrance_fee'];
            result['fee_verified'] = true;
          }
          if (result['website'] == null && wikidataResult['website'] != null) {
            result['website'] = wikidataResult['website'];
          }
          if (result['phone'] == null && wikidataResult['phone'] != null) {
            result['phone'] = wikidataResult['phone'];
          }
        }
      } catch (e) {
        print('Wikidata fetch error: $e');
      }
    }

    // Step 3: Generate smart estimates for missing data
    if (result['operating_hours'] == null) {
      result['operating_hours'] = _getSmartHours(category, country);
    }
    if (result['entrance_fee'] == null) {
      result['entrance_fee'] = _getSmartFee(category, country);
    }

    // Cache the result
    _cache[cacheKey] = result;

    return result;
  }

  /// Fetches data from OpenStreetMap using Overpass API
  static Future<Map<String, dynamic>?> _fetchFromOSM(
    double lat,
    double lng,
    String placeName,
  ) async {
    await _rateLimit();

    // Query for places within 50m of coordinates
    final query =
        '''
[out:json][timeout:10];
(
  node(around:50,$lat,$lng)["name"];
  way(around:50,$lat,$lng)["name"];
  relation(around:50,$lat,$lng)["name"];
);
out body;
''';

    try {
      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: query,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final elements = data['elements'] as List? ?? [];

      if (elements.isEmpty) return null;

      // Find best matching element by name
      Map<String, dynamic>? bestMatch;
      int bestScore = 0;

      final placeNameLower = placeName.toLowerCase();

      for (var element in elements) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final name = (tags['name'] ?? '').toString().toLowerCase();
        final nameEn = (tags['name:en'] ?? '').toString().toLowerCase();

        int score = 0;

        // Score based on name match
        if (name == placeNameLower || nameEn == placeNameLower) {
          score = 100;
        } else if (name.contains(placeNameLower) ||
            placeNameLower.contains(name)) {
          score = 50;
        } else if (nameEn.contains(placeNameLower) ||
            placeNameLower.contains(nameEn)) {
          score = 40;
        }

        // Bonus for having opening_hours
        if (tags['opening_hours'] != null) score += 20;
        if (tags['tourism'] != null) score += 10;
        if (tags['amenity'] != null) score += 5;

        if (score > bestScore) {
          bestScore = score;
          bestMatch = tags;
        }
      }

      return bestMatch;
    } catch (e) {
      print('OSM query error: $e');
      return null;
    }
  }

  /// Fetches data from Wikidata
  static Future<Map<String, dynamic>?> _fetchFromWikidata(
    String placeName,
    String? country,
  ) async {
    await _rateLimit();

    try {
      // Search for entity
      final searchQuery = country != null ? '$placeName $country' : placeName;
      final searchUrl = Uri.parse(
        'https://www.wikidata.org/w/api.php?action=wbsearchentities'
        '&search=${Uri.encodeComponent(searchQuery)}'
        '&language=en&format=json&limit=1',
      );

      final searchResponse = await http
          .get(searchUrl)
          .timeout(const Duration(seconds: 8));
      if (searchResponse.statusCode != 200) return null;

      final searchData = json.decode(searchResponse.body);
      final results = searchData['search'] as List?;
      if (results == null || results.isEmpty) return null;

      final entityId = results[0]['id'] as String?;
      if (entityId == null) return null;

      // Fetch entity details
      final entityUrl = Uri.parse(
        'https://www.wikidata.org/w/api.php?action=wbgetentities'
        '&ids=$entityId&props=claims&format=json',
      );

      final entityResponse = await http
          .get(entityUrl)
          .timeout(const Duration(seconds: 8));
      if (entityResponse.statusCode != 200) return null;

      final entityData = json.decode(entityResponse.body);
      final entities = entityData['entities'] as Map<String, dynamic>?;
      if (entities == null || !entities.containsKey(entityId)) return null;

      final claims =
          entities[entityId]['claims'] as Map<String, dynamic>? ?? {};

      final result = <String, dynamic>{};

      // Extract website (P856)
      if (claims['P856'] != null) {
        final websiteClaims = claims['P856'] as List;
        if (websiteClaims.isNotEmpty) {
          result['website'] =
              websiteClaims[0]['mainsnak']?['datavalue']?['value'];
        }
      }

      // Extract phone (P1329)
      if (claims['P1329'] != null) {
        final phoneClaims = claims['P1329'] as List;
        if (phoneClaims.isNotEmpty) {
          result['phone'] = phoneClaims[0]['mainsnak']?['datavalue']?['value'];
        }
      }

      // Extract opening hours (P3025)
      if (claims['P3025'] != null) {
        final hoursClaims = claims['P3025'] as List;
        if (hoursClaims.isNotEmpty) {
          result['opening_hours'] =
              hoursClaims[0]['mainsnak']?['datavalue']?['value'];
        }
      }

      // Extract entrance fee (P3827 or P2555)
      for (final prop in ['P3827', 'P2555']) {
        if (claims[prop] != null) {
          final feeClaims = claims[prop] as List;
          if (feeClaims.isNotEmpty) {
            final datavalue = feeClaims[0]['mainsnak']?['datavalue'];
            if (datavalue?['type'] == 'quantity') {
              final amount = double.tryParse(
                datavalue['value']['amount'].toString().replaceAll('+', ''),
              );
              if (amount != null) {
                result['entrance_fee'] = {
                  'amount': amount,
                  'currency': 'USD',
                  'display': 'USD ${amount.toStringAsFixed(0)}',
                };
              }
            }
          }
          break;
        }
      }

      return result.isNotEmpty ? result : null;
    } catch (e) {
      print('Wikidata fetch error: $e');
      return null;
    }
  }

  /// Formats OSM opening hours to readable format
  static String _formatOpeningHours(String osmHours) {
    String formatted = osmHours
        .replaceAll('Mo', 'Mon')
        .replaceAll('Tu', 'Tue')
        .replaceAll('We', 'Wed')
        .replaceAll('Th', 'Thu')
        .replaceAll('Fr', 'Fri')
        .replaceAll('Sa', 'Sat')
        .replaceAll('Su', 'Sun')
        .replaceAll('PH', 'Public Holidays')
        .replaceAll('off', 'Closed')
        .replaceAll(';', '\n');

    if (osmHours == '24/7') {
      return 'Open 24 hours';
    }

    if (osmHours.contains('sunrise') || osmHours.contains('sunset')) {
      return 'Sunrise to Sunset';
    }

    return formatted;
  }

  /// Parses fee string to structured data
  static Map<String, dynamic>? _parseFee(String? feeStr, String? country) {
    if (feeStr == null) return null;

    if (feeStr.toLowerCase() == 'no' || feeStr.toLowerCase() == 'free') {
      return {'amount': 0, 'currency': 'FREE', 'display': 'Free admission'};
    }

    if (feeStr.toLowerCase() == 'yes') {
      return null; // Unknown fee
    }

    // Try to parse amount
    final regex = RegExp(r'(\d+(?:[.,]\d+)?)\s*([A-Z]{3})?');
    final match = regex.firstMatch(feeStr);

    if (match != null) {
      final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      String currency = match.group(2) ?? _getDefaultCurrency(country);

      if (amount != null) {
        return {
          'amount': amount,
          'currency': currency,
          'display': '$currency ${amount.toStringAsFixed(0)}',
        };
      }
    }

    return null;
  }

  /// Returns default currency for country
  static String _getDefaultCurrency(String? country) {
    if (country == null) return 'USD';

    final countryLower = country.toLowerCase();

    if (countryLower.contains('malaysia')) return 'MYR';
    if (countryLower.contains('thailand')) return 'THB';
    if (countryLower.contains('indonesia') || countryLower.contains('bali'))
      return 'IDR';
    if (countryLower.contains('singapore')) return 'SGD';
    if (countryLower.contains('japan')) return 'JPY';
    if (countryLower.contains('korea')) return 'KRW';
    if (countryLower.contains('vietnam')) return 'VND';
    if (countryLower.contains('philippines')) return 'PHP';
    if (countryLower.contains('cambodia')) return 'USD';
    if (countryLower.contains('india')) return 'INR';
    if (countryLower.contains('china')) return 'CNY';
    if (countryLower.contains('taiwan')) return 'TWD';
    if (countryLower.contains('hong kong')) return 'HKD';
    if (countryLower.contains('australia')) return 'AUD';
    if (countryLower.contains('uk') || countryLower.contains('united kingdom'))
      return 'GBP';
    if (countryLower.contains('europe') ||
        countryLower.contains('france') ||
        countryLower.contains('germany') ||
        countryLower.contains('italy') ||
        countryLower.contains('spain'))
      return 'EUR';
    if (countryLower.contains('us') || countryLower.contains('united states'))
      return 'USD';

    return 'USD';
  }

  /// Returns estimated hours based on category
  static String _getSmartHours(String? category, String? country) {
    final cat = (category ?? '').toLowerCase();
    final countryLower = (country ?? '').toLowerCase();

    bool isSEAsia =
        countryLower.contains('thailand') ||
        countryLower.contains('malaysia') ||
        countryLower.contains('indonesia') ||
        countryLower.contains('vietnam') ||
        countryLower.contains('philippines');

    switch (cat) {
      case 'temple':
        if (countryLower.contains('thailand')) {
          return '06:00 - 18:00 (typical for Thai temples)';
        } else if (countryLower.contains('bali') ||
            countryLower.contains('indonesia')) {
          return '08:00 - 18:00 (typical)';
        } else if (countryLower.contains('japan')) {
          return '09:00 - 16:30 (typical, may close earlier in winter)';
        }
        return '06:00 - 18:00 (typical)';

      case 'museum':
        if (countryLower.contains('malaysia')) {
          return '09:00 - 18:00 (closed most Mondays)';
        }
        return '09:00 - 17:00 (typically closed Mondays)';

      case 'park':
      case 'nature':
        if (isSEAsia) {
          return '06:00 - 19:00 (tropical hours)';
        }
        return '06:00 - 18:00 (daylight hours)';

      case 'viewpoint':
        return '24 hours (outdoor) - Best at sunrise/sunset';

      case 'shopping':
        if (isSEAsia) {
          return '10:00 - 22:00 (typical mall hours)';
        }
        return '10:00 - 21:00 (typical)';

      case 'entertainment':
        return '10:00 - 22:00 (check for show times)';

      case 'cultural':
        return '09:00 - 17:00 (typical)';

      default:
        return '09:00 - 17:00 (typical)';
    }
  }

  /// Returns estimated fee based on category and country
  static Map<String, dynamic> _getSmartFee(String? category, String? country) {
    final cat = (category ?? '').toLowerCase();
    final countryLower = (country ?? '').toLowerCase();
    final currency = _getDefaultCurrency(country);

    double amount = 0;

    switch (cat) {
      case 'temple':
        if (countryLower.contains('thailand')) {
          amount = 100; // THB
        } else if (countryLower.contains('bali') ||
            countryLower.contains('indonesia')) {
          amount = 30000; // IDR
        } else if (countryLower.contains('japan')) {
          amount = 500; // JPY
        } else if (countryLower.contains('malaysia')) {
          return {
            'amount': 0,
            'currency': 'FREE',
            'display': 'Free (donations welcome)',
          };
        } else {
          amount = 5;
        }
        break;

      case 'museum':
        if (countryLower.contains('malaysia')) {
          amount = 10;
        } else if (countryLower.contains('thailand')) {
          amount = 200;
        } else if (countryLower.contains('singapore')) {
          amount = 15;
        } else if (countryLower.contains('japan')) {
          amount = 1000;
        } else {
          amount = 15;
        }
        break;

      case 'park':
      case 'nature':
        if (countryLower.contains('malaysia')) {
          amount = 5;
        } else if (countryLower.contains('thailand')) {
          amount = 300;
        } else if (countryLower.contains('indonesia')) {
          amount = 25000;
        } else {
          return {
            'amount': 0,
            'currency': 'FREE',
            'display': 'Free / Small fee',
          };
        }
        break;

      case 'viewpoint':
        return {'amount': 0, 'currency': 'FREE', 'display': 'Usually free'};

      case 'shopping':
        return {'amount': 0, 'currency': 'FREE', 'display': 'Free entry'};

      case 'entertainment':
        if (countryLower.contains('malaysia')) {
          amount = 50;
        } else if (countryLower.contains('thailand')) {
          amount = 500;
        } else if (countryLower.contains('singapore')) {
          amount = 40;
        } else {
          amount = 30;
        }
        break;

      default:
        if (countryLower.contains('malaysia')) {
          amount = 15;
        } else if (countryLower.contains('thailand')) {
          amount = 200;
        } else {
          amount = 10;
        }
    }

    // Format display string
    String display;
    if (currency == 'IDR') {
      display =
          'IDR ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    } else if (currency == 'JPY' || currency == 'KRW' || currency == 'VND') {
      display = '$currency ${amount.toStringAsFixed(0)}';
    } else {
      display = '$currency ${amount.toStringAsFixed(0)}';
    }

    return {'amount': amount, 'currency': currency, 'display': display};
  }

  /// Enforces rate limiting between API calls
  static Future<void> _rateLimit() async {
    if (_lastApiCall != null) {
      final elapsed = DateTime.now().difference(_lastApiCall!).inMilliseconds;
      if (elapsed < _minDelayMs) {
        await Future.delayed(Duration(milliseconds: _minDelayMs - elapsed));
      }
    }
    _lastApiCall = DateTime.now();
  }

  /// Clears cached data
  static void clearCache() {
    _cache.clear();
  }
}
