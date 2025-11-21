// lib/controller/search_controller.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class DestinationSearchController {
  static const String _searchUrl =
      "https://us-central1-trip-planner-ec182.cloudfunctions.net/searchDestinations";

  // Search destinations
  static Future<Map<String, dynamic>> searchDestinations(
      String query, {
        int limit = 15,
      }) async {
    if (query.isEmpty) {
      return {'success': false, 'error': 'Query is empty'};
    }

    try {
      final response = await http.post(
        Uri.parse(_searchUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'limit': limit}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'results': List<Map<String, dynamic>>.from(data['results'] ?? []),
          };
        } else {
          return {
            'success': false,
            'error': data['error'] ?? 'Search failed',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Check your internet.',
      };
    }
  }
}