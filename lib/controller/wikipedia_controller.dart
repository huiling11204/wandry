// lib/controller/wikipedia_controller.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class WikipediaController {
  static Future<Map<String, String?>> fetchWikipediaData(
      String placeName,
      String? country,
      ) async {
    if (placeName.isEmpty || !_containsLatinCharacters(placeName)) {
      print('⚠️ No valid English place name found');
      return {'imageUrl': null, 'description': null};
    }

    print('🔍 Fetching Wikipedia data for: $placeName');

    try {
      final wikiUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?'
            'action=query&'
            'format=json&'
            'prop=pageimages|extracts&'
            'pithumbsize=800&'
            'exintro=1&'
            'explaintext=1&'
            'redirects=1&'
            'titles=${Uri.encodeComponent(placeName)}',
      );

      final response = await http.get(wikiUrl).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;

          if (firstPage['missing'] != true) {
            String? imageUrl = firstPage['thumbnail']?['source'];
            String? description;

            if (imageUrl == null && country != null) {
              // Try alternative search with country
              imageUrl = await _tryAlternativeImageSearch(placeName, country);
            }

            final extract = firstPage['extract'];
            if (extract != null && extract.toString().isNotEmpty) {
              String fullText = extract.toString();
              List<String> sentences = fullText.split('. ');
              String shortDesc = sentences.take(3).join('. ');
              if (!shortDesc.endsWith('.')) shortDesc += '.';
              description = shortDesc;
            }

            return {'imageUrl': imageUrl, 'description': description};
          }
        }
      }
    } catch (e) {
      print('❌ Wikipedia fetch error: $e');
    }

    return {'imageUrl': null, 'description': null};
  }

  static Future<String?> _tryAlternativeImageSearch(
      String placeName,
      String country,
      ) async {
    if (country.isEmpty || !_containsLatinCharacters(country)) {
      return null;
    }

    String searchTerm = '$placeName $country';
    print('🔍 Trying alternative search: $searchTerm');

    try {
      final wikiUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?'
            'action=query&'
            'format=json&'
            'prop=pageimages&'
            'pithumbsize=800&'
            'redirects=1&'
            'titles=${Uri.encodeComponent(searchTerm)}',
      );

      final response = await http.get(wikiUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;
          final thumbnail = firstPage['thumbnail']?['source'];

          if (thumbnail != null && firstPage['missing'] != true) {
            print('✅ Found image via alternative search');
            return thumbnail;
          }
        }
      }
    } catch (e) {
      print('❌ Alternative search failed: $e');
    }

    return null;
  }

  static bool _containsLatinCharacters(String text) {
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  static String getFallbackImageUrl(String placeName) {
    final random = placeName.hashCode.abs() % 1000;
    return 'https://picsum.photos/seed/$random/800/600';
  }
}