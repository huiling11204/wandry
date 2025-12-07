import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

/// Handles destination search with debouncing and retry logic
class DestinationSearchController {
  // Cloud Function URL for search
  static const String _searchUrl =
      "https://us-central1-trip-planner-ec182.cloudfunctions.net/searchDestinations";

  Timer? _debounce;
  String _lastQuery = '';

  // Callbacks for UI updates
  Function(bool isSearching)? onSearchStateChanged;
  Function(List<Map<String, dynamic>> results)? onResultsChanged;
  Function(String error)? onError;

  /// Clean up timer when done
  void dispose() {
    _debounce?.cancel();
  }

  /// Searches for destinations with debouncing
  void searchDestination(String query) {
    // Cancel previous timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Empty query = clear results
    if (query.isEmpty) {
      onSearchStateChanged?.call(false);
      onResultsChanged?.call([]);
      return;
    }

    // Wait longer for non-Latin characters (like Chinese/Japanese)
    final hasNonLatin = RegExp(r'[^\x00-\x7F]').hasMatch(query);
    final debounceTime = hasNonLatin ? 600 : 400;

    // Start timer before making API call
    _debounce = Timer(Duration(milliseconds: debounceTime), () {
      _performSearch(query);
    });
  }

  /// Makes actual API call to search
  Future<void> _performSearch(String query, {int retryCount = 0}) async {
    if (query.isEmpty) return;

    _lastQuery = query;
    onSearchStateChanged?.call(true);

    try {
      final response = await http.post(
        Uri.parse(_searchUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'limit': 10}),
      ).timeout(
        const Duration(seconds: 20),
      );

      // Check if query changed while waiting
      if (_lastQuery != query) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
          onResultsChanged?.call(results);
        } else {
          onResultsChanged?.call([]);
        }
      } else if (response.statusCode == 503 || response.statusCode == 504) {
        // Server overloaded - retry once
        if (retryCount < 1) {
          await Future.delayed(const Duration(seconds: 2));
          return _performSearch(query, retryCount: retryCount + 1);
        }
        onResultsChanged?.call([]);
      } else {
        onResultsChanged?.call([]);
      }

      onSearchStateChanged?.call(false);
    } on TimeoutException {
      // Timeout - retry once
      if (retryCount < 1 && _lastQuery == query) {
        await Future.delayed(const Duration(seconds: 1));
        return _performSearch(query, retryCount: retryCount + 1);
      }

      onSearchStateChanged?.call(false);
      onResultsChanged?.call([]);
      print('Search timeout for: $query (attempt ${retryCount + 1})');
    } catch (e) {
      onSearchStateChanged?.call(false);
      onResultsChanged?.call([]);
      print('Search error: $e');
    }
  }

  /// Extracts city and country from destination data
  Map<String, String> extractCityAndCountry(
      Map<String, dynamic>? selectedDestination,
      String destinationText,
      ) {
    String city = '';
    String country = '';

    if (selectedDestination != null) {
      city = (selectedDestination['city'] ?? '').toString().trim();
      country = (selectedDestination['country'] ?? '').toString().trim();
    }

    // Fallback: parse from text
    if (city.isEmpty || country.isEmpty) {
      final parts = destinationText.split(',').map((s) => s.trim()).toList();

      if (parts.length >= 2) {
        if (city.isEmpty) city = parts[0];
        if (country.isEmpty) country = parts[parts.length - 1];
      } else if (parts.length == 1) {
        if (city.isEmpty) city = parts[0];
        if (country.isEmpty) country = parts[0];
      }
    }

    return {'city': city, 'country': country};
  }

  /// Formats destination for display
  String formatDestinationDisplay(Map<String, dynamic> place) {
    final name = place['name']?.toString() ?? 'Unknown';
    final address = place['address'] as Map<String, dynamic>?;
    final city = address?['city']?.toString() ?? '';
    final country = address?['country']?.toString() ?? '';

    String subtitle = '';
    if (city.isNotEmpty && country.isNotEmpty) {
      subtitle = '$city, $country';
    } else if (city.isNotEmpty) {
      subtitle = city;
    } else if (country.isNotEmpty) {
      subtitle = country;
    }

    String displayName = name;
    if (subtitle.isNotEmpty) {
      displayName = '$name, $subtitle';
    }

    return displayName;
  }
}