import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:wandry/screen/attraction_detail_page.dart';

class NearbyAttractionsPage extends StatefulWidget {
  final Position currentPosition;
  final double searchRadius;

  const NearbyAttractionsPage({
    super.key,
    required this.currentPosition,
    required this.searchRadius,
  });

  @override
  State<NearbyAttractionsPage> createState() => _NearbyAttractionsPageState();
}

class _NearbyAttractionsPageState extends State<NearbyAttractionsPage> {
  // Results
  List<Map<String, dynamic>> _attractions = [];
  List<Map<String, dynamic>> _food = [];
  List<Map<String, dynamic>> _accommodation = [];
  bool _isLoading = false;
  String? _error;
  String _loadingMessage = 'Searching...'; // NEW: Track what we're loading

  // Overpass API servers for fallback
  final List<String> _overpassServers = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
  ];

  @override
  void initState() {
    super.initState();
    _searchNearbyAttractions();
  }

  // Search nearby attractions using Overpass API
  Future<void> _searchNearbyAttractions() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _attractions = [];
      _food = [];
      _accommodation = [];
      _loadingMessage = 'Searching for attractions...';
    });

    try {
      final lat = widget.currentPosition.latitude;
      final lon = widget.currentPosition.longitude;
      final radius = (widget.searchRadius * 1000).toInt(); // Convert to meters

      print('Starting search for nearby places...');
      print('Location: $lat, $lon');
      print('Radius: $radius meters');

      // Fetch categories one by one with delay to avoid rate limiting
      setState(() => _loadingMessage = 'Finding attractions...');
      print('Fetching attractions...');
      await _fetchAttractions(lat, lon, radius);

      // Small delay between requests to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _loadingMessage = 'Finding food places...');
      print('Fetching food places...');
      await _fetchFood(lat, lon, radius);

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _loadingMessage = 'Finding accommodations...');
      print('Fetching accommodations...');
      await _fetchAccommodation(lat, lon, radius);

      print('Search completed successfully');
      print('Found: ${_attractions.length} attractions, ${_food.length} food places, ${_accommodation.length} accommodations');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Search failed with error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Fetch attractions (tourism spots)
  Future<void> _fetchAttractions(double lat, double lon, int radius) async {
    final query = '''
    [out:json][timeout:25];
    (
      node["tourism"~"attraction|museum|viewpoint|artwork|gallery|theme_park|zoo"](around:$radius,$lat,$lon);
      way["tourism"~"attraction|museum|viewpoint|artwork|gallery|theme_park|zoo"](around:$radius,$lat,$lon);
    );
    out center;
    ''';

    final results = await _executeOverpassQuery(query);
    setState(() {
      _attractions = results
          .map((e) => {
        ...e,
        'category': 'attraction',
      })
          .toList();
    });
  }

  // Fetch food places
  Future<void> _fetchFood(double lat, double lon, int radius) async {
    final query = '''
    [out:json][timeout:25];
    (
      node["amenity"~"restaurant|cafe|fast_food|bar|pub|food_court"](around:$radius,$lat,$lon);
      way["amenity"~"restaurant|cafe|fast_food|bar|pub|food_court"](around:$radius,$lat,$lon);
    );
    out center;
    ''';

    final results = await _executeOverpassQuery(query);
    setState(() {
      _food = results
          .map((e) => {
        ...e,
        'category': 'food',
      })
          .toList();
    });
  }

  // Fetch accommodation
  Future<void> _fetchAccommodation(double lat, double lon, int radius) async {
    final query = '''
    [out:json][timeout:25];
    (
      node["tourism"~"hotel|hostel|motel|guest_house|apartment"](around:$radius,$lat,$lon);
      way["tourism"~"hotel|hostel|motel|guest_house|apartment"](around:$radius,$lat,$lon);
    );
    out center;
    ''';

    final results = await _executeOverpassQuery(query);
    setState(() {
      _accommodation = results
          .map((e) => {
        ...e,
        'category': 'accommodation',
      })
          .toList();
    });
  }

  // Execute Overpass query with fallback servers
  Future<List<Map<String, dynamic>>> _executeOverpassQuery(String query) async {
    String lastError = '';

    for (int i = 0; i < _overpassServers.length; i++) {
      try {
        print('Trying Overpass server ${i + 1}/${_overpassServers.length}: ${_overpassServers[i]}');

        final response = await http
            .post(
          Uri.parse(_overpassServers[i]),
          body: query,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        )
            .timeout(const Duration(seconds: 15)); // Reduced from 30s to 15s

        print('Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('Successfully fetched data from server ${i + 1}');
          return _parseOverpassResponse(data);
        } else if (response.statusCode == 504 || response.statusCode == 503) {
          lastError = 'Server ${i + 1} is overloaded (${response.statusCode})';
          print(lastError);
          // Don't give up yet, try next server immediately
          continue;
        } else {
          lastError = 'Server ${i + 1} returned status ${response.statusCode}';
          print(lastError);
        }
      } catch (e) {
        lastError = e.toString();
        print('Server ${i + 1} error: $lastError');

        if (i == _overpassServers.length - 1) {
          // Last server failed, throw detailed error
          if (lastError.contains('SocketException') || lastError.contains('NetworkException')) {
            throw Exception('Network error: Please check your internet connection and ensure INTERNET permission is granted in AndroidManifest.xml');
          } else if (lastError.contains('TimeoutException')) {
            throw Exception('Request timed out: The servers are busy. Please try again in a moment.');
          } else {
            throw Exception('Failed to fetch data from all servers. Last error: $lastError');
          }
        }
        // Try next server
        continue;
      }
    }
    return [];
  }

  // Parse Overpass API response
  List<Map<String, dynamic>> _parseOverpassResponse(Map<String, dynamic> data) {
    final elements = data['elements'] as List<dynamic>? ?? [];
    List<Map<String, dynamic>> places = [];

    for (var element in elements) {
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final name = tags['name'] ?? 'Unknown';

      double? lat;
      double? lon;

      // Handle both node and way types
      if (element['type'] == 'node') {
        lat = element['lat'];
        lon = element['lon'];
      } else if (element['type'] == 'way' && element['center'] != null) {
        lat = element['center']['lat'];
        lon = element['center']['lon'];
      }

      if (lat != null && lon != null) {
        final distance = _calculateDistance(
          widget.currentPosition.latitude,
          widget.currentPosition.longitude,
          lat,
          lon,
        );

        places.add({
          'id': element['id'].toString(),
          'name': name,
          'type': tags['tourism'] ?? tags['amenity'] ?? 'place',
          'lat': lat,
          'lon': lon,
          'latitude': lat,
          'longitude': lon,
          'distance': distance,
          'address': tags['addr:street'] ?? '',
          'tags': tags,
          'osmType': element['type'],
          'osmId': element['id'],
        });
      }
    }

    // Sort by distance
    places.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));

    // Limit to top 20 results per category
    return places.take(20).toList();
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // Get appropriate icon for place type
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'attraction':
      case 'viewpoint':
        return Icons.location_on;
      case 'museum':
      case 'gallery':
        return Icons.museum;
      case 'artwork':
        return Icons.palette;
      case 'theme_park':
      case 'zoo':
        return Icons.park;
      case 'restaurant':
        return Icons.restaurant_menu;
      case 'cafe':
        return Icons.local_cafe;
      case 'fast_food':
        return Icons.fastfood;
      case 'bar':
      case 'pub':
        return Icons.local_bar;
      case 'hotel':
      case 'hostel':
      case 'motel':
        return Icons.hotel;
      case 'guest_house':
      case 'apartment':
        return Icons.home;
      default:
        return Icons.place;
    }
  }

  // Navigate to attraction detail page
  void _navigateToAttractionDetail(Map<String, dynamic> attraction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttractionDetailPage(place: attraction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nearby Attractions',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _loadingMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _searchNearbyAttractions,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      )
          : (_attractions.isEmpty && _food.isEmpty && _accommodation.isEmpty)
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No places found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try increasing your search radius',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attractive Locations Section
              if (_attractions.isNotEmpty) ...[
                const Text(
                  'Attractive Locations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildGridSection(_attractions),
                const SizedBox(height: 32),
              ],

              // Food Recommended Section
              if (_food.isNotEmpty) ...[
                const Text(
                  'Food Recommended',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildGridSection(_food),
                const SizedBox(height: 32),
              ],

              // Accommodation Section
              if (_accommodation.isNotEmpty) ...[
                const Text(
                  'Accommodation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildGridSection(_accommodation),
                const SizedBox(height: 32),
              ],

              // Back Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Build grid section for each category
  Widget _buildGridSection(List<Map<String, dynamic>> places) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: places.length > 6 ? 6 : places.length, // Show max 6 items
      itemBuilder: (context, index) {
        return _buildPlaceCard(places[index]);
      },
    );
  }

  // Build individual place card - NOW CLICKABLE
  Widget _buildPlaceCard(Map<String, dynamic> place) {
    return InkWell(
      onTap: () => _navigateToAttractionDetail(place),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForType(place['type']),
                size: 40,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                place['name'],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Distance
            if (place['distance'] != null)
              Text(
                '${(place['distance'] as double).toStringAsFixed(1)} km',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}