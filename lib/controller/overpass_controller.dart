import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utilities/api_helper.dart';

class OverpassController {
  // Fetch attractions
  static Future<List<Map<String, dynamic>>> fetchAttractions(
      double lat,
      double lon,
      int radiusMeters,
      ) async {
    final query = '''
    [out:json][timeout:25];
    (
      node["tourism"~"attraction|museum|viewpoint|artwork|gallery|theme_park|zoo"](around:$radiusMeters,$lat,$lon);
      way["tourism"~"attraction|museum|viewpoint|artwork|gallery|theme_park|zoo"](around:$radiusMeters,$lat,$lon);
    );
    out center;
    ''';

    final results = await _executeOverpassQuery(query);
    return results.map((e) => {...e, 'category': 'attraction'}).toList();
  }

  // Fetch food places
  static Future<List<Map<String, dynamic>>> fetchFood(
      double lat,
      double lon,
      int radiusMeters,
      ) async {
    final query = '''
    [out:json][timeout:25];
    (
      node["amenity"~"restaurant|cafe|fast_food|bar|pub|food_court"](around:$radiusMeters,$lat,$lon);
      way["amenity"~"restaurant|cafe|fast_food|bar|pub|food_court"](around:$radiusMeters,$lat,$lon);
    );
    out center;
    ''';

    final results = await _executeOverpassQuery(query);
    return results.map((e) => {...e, 'category': 'food'}).toList();
  }

  // Fetch accommodation
  static Future<List<Map<String, dynamic>>> fetchAccommodation(
      double lat,
      double lon,
      int radiusMeters,
      ) async {
    final query = '''
    [out:json][timeout:25];
    (
      node["tourism"~"hotel|hostel|motel|guest_house|apartment"](around:$radiusMeters,$lat,$lon);
      way["tourism"~"hotel|hostel|motel|guest_house|apartment"](around:$radiusMeters,$lat,$lon);
    );
    out center;
    ''';

    final results = await _executeOverpassQuery(query);
    return results.map((e) => {...e, 'category': 'accommodation'}).toList();
  }

  // Fetch nearby category (for place detail page)
  static Future<List<Map<String, dynamic>>> fetchNearbyCategory(
      String category,
      double lat,
      double lon,
      ) async {
    String query = _buildCategoryQuery(category, lat, lon);
    return await _executeOverpassQuery(query);
  }

  // Build query for specific category
  static String _buildCategoryQuery(String category, double lat, double lon) {
    String nodeQuery = '';
    String wayQuery = '';

    switch (category.toLowerCase()) {
      case 'food':
        nodeQuery = 'node(around:2000,$lat,$lon)[amenity~"restaurant|cafe|fast_food|bar"];';
        wayQuery = 'way(around:2000,$lat,$lon)[amenity~"restaurant|cafe|fast_food|bar"];';
        break;
      case 'hotel':
        nodeQuery = 'node(around:2000,$lat,$lon)[tourism~"hotel|hostel|guest_house"];';
        wayQuery = 'way(around:2000,$lat,$lon)[tourism~"hotel|hostel|guest_house"];';
        break;
      case 'activity':
        nodeQuery = 'node(around:2000,$lat,$lon)[tourism~"attraction|museum|zoo|theme_park"];';
        wayQuery = 'way(around:2000,$lat,$lon)[tourism~"attraction|museum|zoo|theme_park"];';
        break;
      case 'photo spots':
        nodeQuery = 'node(around:2000,$lat,$lon)[tourism~"viewpoint|attraction"];';
        wayQuery = 'way(around:2000,$lat,$lon)[tourism~"viewpoint|attraction"];';
        break;
      case 'shopping':
        nodeQuery = 'node(around:2000,$lat,$lon)[shop];';
        wayQuery = 'way(around:2000,$lat,$lon)[shop];';
        break;
      default:
        nodeQuery = 'node(around:2000,$lat,$lon)[tourism];';
        wayQuery = 'way(around:2000,$lat,$lon)[tourism];';
    }

    return '''
[out:json][timeout:25];
(
  $nodeQuery
  $wayQuery
);
out center;
''';
  }

  // Execute Overpass query with fallback servers
  static Future<List<Map<String, dynamic>>> _executeOverpassQuery(String query) async {
    String lastError = '';
    final servers = ApiHelper.overpassServers;

    for (int i = 0; i < servers.length; i++) {
      try {
        print('Trying Overpass server ${i + 1}/${servers.length}: ${servers[i]}');

        final response = await http.post(
          Uri.parse(servers[i]),
          body: query,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ).timeout(const Duration(seconds: 15));

        print('Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('Successfully fetched data from server ${i + 1}');
          return _parseOverpassResponse(data);
        } else if (response.statusCode == 504 || response.statusCode == 503) {
          lastError = 'Server ${i + 1} is overloaded (${response.statusCode})';
          print(lastError);
          continue;
        } else {
          lastError = 'Server ${i + 1} returned status ${response.statusCode}';
          print(lastError);
        }
      } catch (e) {
        lastError = e.toString();
        print('Server ${i + 1} error: $lastError');

        if (i == servers.length - 1) {
          if (lastError.contains('SocketException') || lastError.contains('NetworkException')) {
            throw Exception('Network error: Please check your internet connection.');
          } else if (lastError.contains('TimeoutException')) {
            throw Exception('Request timed out: The servers are busy. Please try again.');
          } else {
            throw Exception('Failed to fetch data. Last error: $lastError');
          }
        }
        continue;
      }
    }
    return [];
  }

  // Parse Overpass API response
  static List<Map<String, dynamic>> _parseOverpassResponse(
      Map<String, dynamic> data,
      ) {
    final elements = data['elements'] as List<dynamic>? ?? [];
    List<Map<String, dynamic>> places = [];

    for (var element in elements) {
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final name = tags['name'];

      // Skip places without a name - no point showing "Unknown" places
      if (name == null || name.toString().trim().isEmpty) {
        continue;
      }

      double? lat;
      double? lon;

      if (element['type'] == 'node') {
        lat = element['lat'];
        lon = element['lon'];
      } else if (element['type'] == 'way' && element['center'] != null) {
        lat = element['center']['lat'];
        lon = element['center']['lon'];
      }

      if (lat != null && lon != null) {
        places.add({
          'id': element['id'].toString(),
          'name': name,
          'type': tags['tourism'] ?? tags['amenity'] ?? 'place',
          'lat': lat,
          'lon': lon,
          'latitude': lat,
          'longitude': lon,
          'address': tags['addr:street'] ?? '',
          'tags': tags,
          'osmType': element['type'],
          'osmId': element['id'],
        });
      }
    }

    // Return all places with valid names - sorting by distance is done in the UI layer
    return places;
  }
}