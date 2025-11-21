import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class DestinationSearchController {
  static const String _searchUrl =
      "https://us-central1-trip-planner-ec182.cloudfunctions.net/searchDestinations";

  Timer? _debounce;

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

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    onSearchStateChanged?.call(true);

    try {
      final response = await http.post(
        Uri.parse(_searchUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'limit': 10}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
          onResultsChanged?.call(results);
        }
      }
      onSearchStateChanged?.call(false);
    } catch (e) {
      onSearchStateChanged?.call(false);
      onError?.call('Search failed: ${e.toString()}');
    }
  }

  Map<String, String> extractCityAndCountry(Map<String, dynamic>? selectedDestination, String destinationText) {
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