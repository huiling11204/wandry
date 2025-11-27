// lib/controller/destination_search_controller.dart
// FIXED: Better timeout handling, retry logic, graceful errors

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class DestinationSearchController {
  static const String _searchUrl =
      "https://us-central1-trip-planner-ec182.cloudfunctions.net/searchDestinations";

  Timer? _debounce;
  String _lastQuery = '';

  // Callbacks
  Function(bool isSearching)? onSearchStateChanged;
  Function(List<Map<String, dynamic>> results)? onResultsChanged;
  Function(String error)? onError;

  void dispose() {
    _debounce?.cancel();
  }

  void searchDestination(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      onSearchStateChanged?.call(false);
      onResultsChanged?.call([]);
      return;
    }

    // Debounce: wait 600ms for non-Latin, 400ms for Latin
    final hasNonLatin = RegExp(r'[^\x00-\x7F]').hasMatch(query);
    final debounceTime = hasNonLatin ? 600 : 400;

    _debounce = Timer(Duration(milliseconds: debounceTime), () {
      _performSearch(query);
    });
  }

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
        const Duration(seconds: 20), // Increased from 10 to 20
      );

      // Check if query changed while waiting
      if (_lastQuery != query) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
          onResultsChanged?.call(results);
        } else {
          // API returned success: false
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
      // Timeout - retry once silently
      if (retryCount < 1 && _lastQuery == query) {
        await Future.delayed(const Duration(seconds: 1));
        return _performSearch(query, retryCount: retryCount + 1);
      }

      onSearchStateChanged?.call(false);
      onResultsChanged?.call([]);

      // Don't show error for autocomplete - just show empty results
      // User can try typing again
      print('Search timeout for: $query (attempt ${retryCount + 1})');
    } catch (e) {
      onSearchStateChanged?.call(false);

      // Don't show error snackbar for autocomplete failures
      // Just return empty results - user can try again
      onResultsChanged?.call([]);
      print('Search error: $e');
    }
  }

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

    // Fallback: parse from destination text if needed
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