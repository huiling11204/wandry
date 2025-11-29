// lib/controller/place_image_controller.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to fetch place images from multiple free sources
/// Enhanced with name translation/normalization for better matching
class PlaceImageController {
  // Cache to avoid repeated API calls
  static final Map<String, String?> _imageCache = {};

  // Cache for translated names
  static final Map<String, String> _translationCache = {};

  /// Get image URL for a place, trying multiple sources
  static Future<String?> getPlaceImage({
    required String placeName,
    String? placeType,
    double? latitude,
    double? longitude,
    String? country,
  }) async {
    // Check cache first
    final cacheKey = '${placeName}_${latitude}_$longitude';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey];
    }

    String? imageUrl;

    // Get English name for better search results
    final englishName = await _getEnglishName(placeName, latitude, longitude);
    final searchName = englishName ?? placeName;

    print('🔍 Searching image for: $searchName (original: $placeName)');

    // 1. Try Wikipedia with English name
    imageUrl = await _tryWikipedia(searchName, country);
    if (imageUrl != null) {
      _imageCache[cacheKey] = imageUrl;
      return imageUrl;
    }

    // 2. Try with original name if different
    if (englishName != null && englishName != placeName) {
      imageUrl = await _tryWikipedia(placeName, country);
      if (imageUrl != null) {
        _imageCache[cacheKey] = imageUrl;
        return imageUrl;
      }
    }

    // 3. Try Wikimedia Commons search
    imageUrl = await _tryWikimediaCommons(searchName, placeType);
    if (imageUrl != null) {
      _imageCache[cacheKey] = imageUrl;
      return imageUrl;
    }

    // 4. Try with place type context
    if (placeType != null) {
      final searchWithType = '$searchName ${_getTypeKeyword(placeType)}';
      imageUrl = await _tryWikimediaCommons(searchWithType, null);
      if (imageUrl != null) {
        _imageCache[cacheKey] = imageUrl;
        return imageUrl;
      }
    }

    // 5. Use static map image as fallback (always works)
    if (latitude != null && longitude != null) {
      imageUrl = getStaticMapUrl(latitude, longitude);
      _imageCache[cacheKey] = imageUrl;
      return imageUrl;
    }

    // 6. Final fallback: themed placeholder based on place type
    imageUrl = _getThemedPlaceholder(placeName, placeType);
    _imageCache[cacheKey] = imageUrl;
    return imageUrl;
  }

  /// Get English name using multiple strategies
  static Future<String?> _getEnglishName(String placeName, double? lat, double? lon) async {
    // Check translation cache
    if (_translationCache.containsKey(placeName)) {
      return _translationCache[placeName];
    }

    // If already contains mostly Latin characters, just clean it
    if (_isMostlyLatin(placeName)) {
      final cleaned = _cleanPlaceName(placeName);
      _translationCache[placeName] = cleaned;
      return cleaned;
    }

    String? englishName;

    // Strategy 1: Try reverse geocoding to get English name
    if (lat != null && lon != null) {
      englishName = await _getEnglishNameFromCoordinates(lat, lon);
      if (englishName != null && englishName.isNotEmpty) {
        _translationCache[placeName] = englishName;
        return englishName;
      }
    }

    // Strategy 2: Try Wikipedia search to find English article
    englishName = await _getEnglishNameFromWikipediaSearch(placeName);
    if (englishName != null && englishName.isNotEmpty) {
      _translationCache[placeName] = englishName;
      return englishName;
    }

    // Strategy 3: Try to extract Latin characters from the name
    englishName = _extractLatinPart(placeName);
    if (englishName != null && englishName.isNotEmpty) {
      _translationCache[placeName] = englishName;
      return englishName;
    }

    return null;
  }

  /// Get English place name from coordinates using Nominatim reverse geocoding
  static Future<String?> _getEnglishNameFromCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
            'lat=$lat&lon=$lon&format=json&accept-language=en&zoom=18',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'TripPlannerApp/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Try to get name in English
        final name = data['name'];
        final displayName = data['display_name'];
        final address = data['address'] as Map<String, dynamic>?;

        // Priority: name > tourism > amenity > road
        if (name != null && _containsLatinCharacters(name)) {
          return name;
        }

        if (address != null) {
          // Try specific address fields that might have English names
          final tourism = address['tourism'];
          final amenity = address['amenity'];
          final shop = address['shop'];
          final building = address['building'];

          for (var field in [tourism, amenity, shop, building]) {
            if (field != null && _containsLatinCharacters(field.toString())) {
              return field.toString();
            }
          }
        }

        // Extract first Latin part from display_name
        if (displayName != null) {
          final parts = displayName.toString().split(',');
          for (var part in parts) {
            final trimmed = part.trim();
            if (_containsLatinCharacters(trimmed) && trimmed.length > 2) {
              return trimmed;
            }
          }
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }
    return null;
  }

  /// Search Wikipedia to find English article title
  static Future<String?> _getEnglishNameFromWikipediaSearch(String query) async {
    try {
      // First try on English Wikipedia with search
      final searchUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?'
            'action=query&'
            'format=json&'
            'list=search&'
            'srlimit=1&'
            'srsearch=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(searchUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final search = data['query']?['search'] as List?;

        if (search != null && search.isNotEmpty) {
          final title = search[0]['title'];
          if (title != null && _containsLatinCharacters(title)) {
            return title;
          }
        }
      }
    } catch (e) {
      print('Wikipedia search error: $e');
    }
    return null;
  }

  /// Extract Latin characters part from a mixed-script name
  static String? _extractLatinPart(String text) {
    // Match sequences of Latin characters and spaces
    final latinRegex = RegExp('[a-zA-Z][a-zA-Z\\s\\-\\.]+[a-zA-Z]');
    final matches = latinRegex.allMatches(text);

    if (matches.isNotEmpty) {
      // Get the longest Latin match
      String longest = '';
      for (var match in matches) {
        final matched = match.group(0) ?? '';
        if (matched.length > longest.length) {
          longest = matched;
        }
      }
      if (longest.length >= 3) {
        return longest.trim();
      }
    }
    return null;
  }

  /// Check if text is mostly Latin characters
  static bool _isMostlyLatin(String text) {
    if (text.isEmpty) return false;

    int latinCount = 0;
    int totalLetters = 0;

    for (var char in text.runes) {
      if ((char >= 65 && char <= 90) || (char >= 97 && char <= 122)) {
        latinCount++;
        totalLetters++;
      } else if (char > 127 && !_isPunctuation(char)) {
        totalLetters++;
      }
    }

    if (totalLetters == 0) return true;
    return latinCount / totalLetters > 0.5;
  }

  static bool _isPunctuation(int charCode) {
    return charCode == 32 || // space
        charCode == 44 || // comma
        charCode == 46 || // period
        charCode == 45 || // hyphen
        charCode == 39;   // apostrophe
  }

  /// Try to get image from Wikipedia
  static Future<String?> _tryWikipedia(String placeName, String? country) async {
    if (placeName.isEmpty) return null;

    try {
      String searchName = _cleanPlaceName(placeName);

      // Try direct title match first
      final wikiUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?'
            'action=query&'
            'format=json&'
            'prop=pageimages&'
            'piprop=thumbnail&'
            'pithumbsize=400&'
            'redirects=1&'
            'titles=${Uri.encodeComponent(searchName)}',
      );

      final response = await http.get(wikiUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;
          if (firstPage['missing'] != true && firstPage['thumbnail'] != null) {
            print('✅ Found Wikipedia image for: $searchName');
            return firstPage['thumbnail']['source'];
          }
        }
      }

      // Try search API if direct match failed
      final searchUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?'
            'action=query&'
            'format=json&'
            'prop=pageimages&'
            'piprop=thumbnail&'
            'pithumbsize=400&'
            'generator=search&'
            'gsrlimit=1&'
            'gsrsearch=${Uri.encodeComponent(country != null ? '$searchName $country' : searchName)}',
      );

      final searchResponse = await http.get(searchUrl).timeout(const Duration(seconds: 5));

      if (searchResponse.statusCode == 200) {
        final data = jsonDecode(searchResponse.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;
          if (firstPage['thumbnail'] != null) {
            print('✅ Found Wikipedia image via search for: $searchName');
            return firstPage['thumbnail']['source'];
          }
        }
      }
    } catch (e) {
      print('Wikipedia image fetch error: $e');
    }

    return null;
  }

  /// Try Wikimedia Commons for images
  static Future<String?> _tryWikimediaCommons(String placeName, String? placeType) async {
    try {
      String searchTerm = _cleanPlaceName(placeName);

      final commonsUrl = Uri.parse(
        'https://commons.wikimedia.org/w/api.php?'
            'action=query&'
            'format=json&'
            'generator=search&'
            'gsrnamespace=6&'
            'gsrlimit=1&'
            'prop=imageinfo&'
            'iiprop=url&'
            'iiurlwidth=400&'
            'gsrsearch=${Uri.encodeComponent(searchTerm)}',
      );

      final response = await http.get(commonsUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;
          final imageInfo = firstPage['imageinfo'] as List?;
          if (imageInfo != null && imageInfo.isNotEmpty) {
            print('✅ Found Wikimedia Commons image for: $searchTerm');
            return imageInfo[0]['thumburl'] ?? imageInfo[0]['url'];
          }
        }
      }
    } catch (e) {
      print('Wikimedia Commons fetch error: $e');
    }

    return null;
  }

  /// Get a static map image URL
  static String getStaticMapUrl(double lat, double lng, {int zoom = 15, int width = 400, int height = 300}) {
    // Using OpenStreetMap static tiles
    // Alternative free options: Stamen, CartoDB
    return 'https://static-maps.yandex.ru/1.x/?'
        'lang=en_US&'
        'll=$lng,$lat&'
        'z=$zoom&'
        'l=map&'
        'size=$width,$height&'
        'pt=$lng,$lat,pm2rdm';
  }

  /// Get themed placeholder based on place type
  static String _getThemedPlaceholder(String placeName, String? placeType) {
    final seed = placeName.hashCode.abs() % 10000;
    return 'https://picsum.photos/seed/$seed/400/300';
  }

  /// Clean place name for better search results
  static String _cleanPlaceName(String name) {
    String cleaned = name
        .replaceAll(RegExp('\\s*\\([^)]*\\)'), '') // Remove parenthetical content
        .replaceAll(RegExp('\\s*-\\s*.*\$'), '') // Remove content after dash
        .replaceAll(RegExp('[^\\w\\s\u0080-\uFFFF]'), ' ') // Keep letters and unicode
        .replaceAll(RegExp('\\s+'), ' ') // Normalize spaces
        .trim();

    return cleaned;
  }

  /// Get keyword for place type to improve search
  static String _getTypeKeyword(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
      case 'cafe':
      case 'fast_food':
        return 'restaurant';
      case 'hotel':
      case 'hostel':
        return 'hotel';
      case 'museum':
        return 'museum';
      case 'park':
      case 'theme_park':
        return 'park';
      case 'beach':
        return 'beach';
      case 'temple':
        return 'temple';
      case 'viewpoint':
        return 'landmark';
      default:
        return '';
    }
  }

  static bool _containsLatinCharacters(String text) {
    return RegExp('[a-zA-Z]').hasMatch(text);
  }

  /// Clear caches
  static void clearCache() {
    _imageCache.clear();
    _translationCache.clear();
  }
}