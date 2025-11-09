import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/interaction_tracker.dart';

class PlaceDetailPage extends StatefulWidget {
  final Map<String, dynamic> place;

  const PlaceDetailPage({super.key, required this.place});

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _details;
  String? _imageUrl;
  String? _wikipediaDescription;

  // Multiple Overpass API servers for fallback
  final List<String> _overpassServers = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _trackPlaceView();
  }

  void _trackPlaceView() {
    try {
      final tags = widget.place['tags'] as Map<String, dynamic>?;
      final address = widget.place['address'] as Map<String, dynamic>?;

      InteractionTracker().trackPlaceView(
        placeId: widget.place['osmId']?.toString() ?? 'unknown',
        placeName: widget.place['name']?.toString() ?? 'Unknown Place',
        category: tags?['tourism']?.toString() ??
            tags?['amenity']?.toString() ??
            'general',
        state: address?['state']?.toString(),
        country: address?['country']?.toString(),
      );
    } catch (e) {
      print('Error tracking view: $e');
    }
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _fetchWikipediaData(),
      _fetchDetails(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  String _extractEnglishPlaceName() {
    String placeName = '';

    final tags = widget.place['tags'] as Map<String, dynamic>?;
    if (tags != null) {
      placeName = tags['name:en']?.toString() ??
          tags['int_name']?.toString() ??
          tags['official_name:en']?.toString() ??
          tags['alt_name:en']?.toString() ?? '';
    }

    if (placeName.isEmpty) {
      String fullName = widget.place['name']?.toString() ??
          widget.place['display_name']?.toString() ?? '';

      if (fullName.isNotEmpty) {
        List<String> parts = fullName.split(',').map((e) => e.trim()).toList();

        for (var part in parts) {
          if (_containsLatinCharacters(part) && part.length > 2) {
            placeName = part;
            break;
          }
        }

        if (placeName.isEmpty) {
          placeName = parts[0];
        }
      }
    }

    print('📝 Extracted place name: "$placeName"');
    return placeName;
  }

  String _getEnglishCountryName() {
    final address = widget.place['address'] as Map<String, dynamic>?;
    if (address == null) return '';

    String country = address['country']?.toString() ?? '';
    String countryCode = address['country_code']?.toString().toUpperCase() ?? '';

    Map<String, String> countryMap = {
      'JP': 'Japan',
      'CN': 'China',
      'KR': 'South Korea',
      'TH': 'Thailand',
      'MY': 'Malaysia',
      'SG': 'Singapore',
      'ID': 'Indonesia',
      'VN': 'Vietnam',
      'PH': 'Philippines',
      'IN': 'India',
      'FR': 'France',
      'DE': 'Germany',
      'IT': 'Italy',
      'ES': 'Spain',
      'GB': 'United Kingdom',
      'US': 'United States',
    };

    if (countryCode.isNotEmpty && countryMap.containsKey(countryCode)) {
      return countryMap[countryCode]!;
    }

    return country;
  }

  bool _containsLatinCharacters(String text) {
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  Future<void> _fetchWikipediaData() async {
    String placeName = _extractEnglishPlaceName();

    if (placeName.isEmpty || !_containsLatinCharacters(placeName)) {
      print('⚠️ No valid English place name found');
      _setFallbackImage(placeName);
      return;
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
              'titles=${Uri.encodeComponent(placeName)}');

      final response =
      await http.get(wikiUrl).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;

          if (firstPage['missing'] != true) {
            final thumbnail = firstPage['thumbnail']?['source'];
            if (thumbnail != null) {
              print('✅ Found Wikipedia image');
              setState(() {
                _imageUrl = thumbnail;
              });
            } else {
              print('⚠️ No thumbnail, trying alternative');
              await _tryAlternativeImageSearch(placeName);
            }

            final extract = firstPage['extract'];
            if (extract != null && extract.toString().isNotEmpty) {
              String fullText = extract.toString();
              List<String> sentences = fullText.split('. ');
              String shortDesc = sentences.take(3).join('. ');
              if (!shortDesc.endsWith('.')) shortDesc += '.';

              print('✅ Found Wikipedia description');
              setState(() {
                _wikipediaDescription = shortDesc;
              });
            }
          } else {
            print('❌ Wikipedia page not found');
            await _tryAlternativeImageSearch(placeName);
          }
        }
      }
    } catch (e) {
      print('❌ Wikipedia fetch error: $e');
    }

    if (_imageUrl == null) {
      _setFallbackImage(placeName);
    }
  }

  Future<void> _tryAlternativeImageSearch(String placeName) async {
    String country = _getEnglishCountryName();

    if (country.isEmpty || !_containsLatinCharacters(country)) {
      return;
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
              'titles=${Uri.encodeComponent(searchTerm)}');

      final response =
      await http.get(wikiUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;
          final thumbnail = firstPage['thumbnail']?['source'];

          if (thumbnail != null && firstPage['missing'] != true) {
            print('✅ Found image via alternative search');
            setState(() {
              _imageUrl = thumbnail;
            });
          }
        }
      }
    } catch (e) {
      print('❌ Alternative search failed: $e');
    }
  }

  void _setFallbackImage(String placeName) {
    final random = placeName.hashCode.abs() % 1000;
    setState(() {
      _imageUrl = 'https://picsum.photos/seed/$random/800/600';
    });
    print('📸 Using fallback image');
  }

  String _getSmartFallbackDescription() {
    final tags = widget.place['tags'] as Map<String, dynamic>?;
    if (tags == null) return 'Discover this amazing destination.';

    String tourism = tags['tourism']?.toString() ?? '';
    String amenity = tags['amenity']?.toString() ?? '';

    if (tourism == 'hotel' || amenity == 'hotel') {
      return 'A comfortable accommodation option offering quality service and amenities for travelers.';
    } else if (tourism == 'attraction' || tourism == 'viewpoint') {
      return 'A popular destination known for its unique features and visitor experiences.';
    } else if (amenity == 'restaurant' || amenity == 'cafe') {
      return 'A dining establishment serving food and beverages to guests.';
    } else if (tourism == 'museum') {
      return 'A cultural institution preserving and exhibiting artifacts and history.';
    } else if (amenity == 'bar' || amenity == 'pub') {
      return 'An establishment serving drinks and providing social atmosphere.';
    } else if (tags['shop'] != null) {
      return 'A retail establishment offering products and services.';
    }

    return 'Discover this amazing destination worth visiting.';
  }

  Future<void> _fetchDetails() async {
    final osmType = widget.place['osmType'];
    final osmId = widget.place['osmId'];

    if (osmType == null || osmId == null) {
      print('⚠️ No OSM data, using fallback');
      setState(() {
        _details = {
          'name': _extractEnglishPlaceName() != ''
              ? _extractEnglishPlaceName()
              : 'Unknown',
          'description': _wikipediaDescription ?? _getSmartFallbackDescription(),
          'openingHours': 'Not available',
          'phone': 'Not available',
          'website': '',
        };
      });
      return;
    }

    try {
      final url =
          "https://us-central1-trip-planner-ec182.cloudfunctions.net/getPlaceDetailsHTTP";

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'osmType': osmType,
          'osmId': osmId,
          'latitude': widget.place['latitude'] ?? 0.0,
          'longitude': widget.place['longitude'] ?? 0.0,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final details = data['details'] as Map<String, dynamic>?;

          if (details != null) {
            String? desc = details['description']?.toString();

            if (desc == null ||
                desc.isEmpty ||
                desc == 'attraction' ||
                desc == 'hotel' ||
                desc == 'restaurant' ||
                desc == 'museum' ||
                desc == 'tourism' ||
                desc == 'yes' ||
                desc == 'viewpoint') {
              if (_wikipediaDescription != null &&
                  _wikipediaDescription!.isNotEmpty) {
                details['description'] = _wikipediaDescription;
                print('✅ Using Wikipedia description');
              } else {
                details['description'] = _getSmartFallbackDescription();
                print('ℹ️ Using smart fallback description');
              }
            }

            setState(() {
              _details = details;
            });
          }
        }
      }
    } catch (e) {
      print('❌ OSM fetch error: $e');
      setState(() {
        _details = {
          'name': _extractEnglishPlaceName() != ''
              ? _extractEnglishPlaceName()
              : 'Unknown',
          'description': _wikipediaDescription ?? _getSmartFallbackDescription(),
          'openingHours': 'Not available',
          'phone': 'Not available',
          'website': '',
        };
      });
    }
  }

  String _formatOpeningHours(String hours) {
    if (hours == 'Not available' || hours.isEmpty) return hours;

    return hours
        .replaceAll('Mo', 'Mon')
        .replaceAll('Tu', 'Tue')
        .replaceAll('We', 'Wed')
        .replaceAll('Th', 'Thu')
        .replaceAll('Fr', 'Fri')
        .replaceAll('Sa', 'Sat')
        .replaceAll('Su', 'Sun');
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open website')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  // IMPROVED: Search with retry logic and multiple servers
  Future<void> _searchNearbyCategory(String category) async {
    final lat = widget.place['latitude'];
    final lon = widget.place['longitude'];

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
        ),
      ),
    );

    print('🔍 Searching for $category near location...');
    print('📍 Coordinates: $lat, $lon');

    // Try multiple servers
    for (int serverIndex = 0; serverIndex < _overpassServers.length; serverIndex++) {
      try {
        String server = _overpassServers[serverIndex];
        String overpassQuery = _buildOverpassQuery(category, lat, lon);

        print('🌐 Trying server ${serverIndex + 1}/${_overpassServers.length}: $server');

        final response = await http.post(
          Uri.parse(server),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: overpassQuery,
        ).timeout(const Duration(seconds: 30));

        print('📡 Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final elements = data['elements'] as List?;

          print('📊 Found ${elements?.length ?? 0} results');

          if (elements == null || elements.isEmpty) {
            if (serverIndex == _overpassServers.length - 1) {
              // Last server, no results
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No $category found within 2km. Try a different category.'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
            // Try next server
            continue;
          }

          // Process results
          List<Map<String, dynamic>> places = [];
          for (var element in elements) {
            double eleLat = element['lat'] ?? element['center']?['lat'] ?? 0.0;
            double eleLon = element['lon'] ?? element['center']?['lon'] ?? 0.0;

            if (eleLat == 0.0 || eleLon == 0.0) continue;

            double distance = _calculateDistance(lat, lon, eleLat, eleLon);
            String placeName = _getEnglishNameFromTags(element['tags']);

            places.add({
              'name': placeName,
              'latitude': eleLat,
              'longitude': eleLon,
              'osmType': element['type'],
              'osmId': element['id'],
              'tags': element['tags'] ?? {},
              'address': _parseAddress(element['tags']),
              'distance': distance,
            });
          }

          places.sort((a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double));
          places = places.take(20).toList();

          print('✅ Processed ${places.length} valid places');

          if (mounted) {
            Navigator.pop(context);
            _showNearbyResults(category, places);
          }
          return; // Success!
        } else if (response.statusCode == 429 || response.statusCode == 504) {
          print('⚠️ Server $server is busy (${response.statusCode}), trying next...');
          continue; // Try next server
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error with server ${serverIndex + 1}: $e');
        if (serverIndex == _overpassServers.length - 1) {
          // Last server failed
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Search temporarily unavailable. Please try again in a moment.'),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _searchNearbyCategory(category),
                ),
              ),
            );
          }
        }
        // Try next server
        continue;
      }
    }
  }

  String _getEnglishNameFromTags(Map<String, dynamic>? tags) {
    if (tags == null) return 'Unknown';

    String name = tags['name:en']?.toString() ??
        tags['int_name']?.toString() ??
        tags['official_name:en']?.toString() ??
        tags['name']?.toString() ??
        'Unknown';

    if (!_containsLatinCharacters(name)) {
      if (tags['brand:en'] != null) {
        return tags['brand:en'].toString();
      }
      if (tags['brand'] != null && _containsLatinCharacters(tags['brand'].toString())) {
        return tags['brand'].toString();
      }
      if (tags['operator'] != null && _containsLatinCharacters(tags['operator'].toString())) {
        return tags['operator'].toString();
      }
      if (tags['addr:street'] != null && _containsLatinCharacters(tags['addr:street'].toString())) {
        String type = tags['amenity'] ?? tags['tourism'] ?? 'Place';
        return '${type.toString().capitalize()} on ${tags['addr:street']}';
      }

      String type = tags['amenity']?.toString() ??
          tags['tourism']?.toString() ??
          tags['shop']?.toString() ??
          'Place';
      return type.capitalize();
    }

    return name;
  }

  String _buildOverpassQuery(String category, double lat, double lon) {
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

  Map<String, dynamic> _parseAddress(Map<String, dynamic>? tags) {
    if (tags == null) return {};

    return {
      'city': tags['addr:city'] ?? tags['city'] ?? '',
      'state': tags['addr:state'] ?? tags['state'] ?? '',
      'country': tags['addr:country'] ?? tags['country'] ?? '',
      'road': tags['addr:street'] ?? '',
    };
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.141592653589793 / 180.0;
  }

  void _showNearbyResults(String category, List<dynamic> places) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        color: const Color(0xFF4A90E2),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$category Nearby',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${places.length} places found',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: places.length,
                    itemBuilder: (context, index) {
                      final place = places[index];
                      final distance = place['distance'];
                      final distanceText = distance != null
                          ? '${(distance / 1000).toStringAsFixed(1)} km'
                          : '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCategoryIcon(category),
                              color: const Color(0xFF4A90E2),
                              size: 28,
                            ),
                          ),
                          title: Text(
                            place['name']?.toString().split(',')[0] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (distanceText.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Color(0xFF4A90E2),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      distanceText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PlaceDetailPage(place: place),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'hotel':
        return Icons.hotel;
      case 'activity':
        return Icons.local_activity;
      case 'photo spots':
        return Icons.camera_alt;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.tour;
    }
  }

  Future<void> _addToTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    try {
      final tripsSnapshot = await FirebaseFirestore.instance
          .collection('trip')
          .where('userID', isEqualTo: user.uid)
          .get();

      if (tripsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a trip first!')),
        );
        return;
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add to Trip',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ...tripsSnapshot.docs.map((tripDoc) {
                  final tripData = tripDoc.data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.luggage,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                    title: Text(
                      tripData['tripName']?.toString() ?? 'Unnamed Trip',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${tripData['startDate']?.toDate().toString().split(' ')[0] ?? ''} - ${tripData['endDate']?.toDate().toString().split(' ')[0] ?? ''}',
                    ),
                    onTap: () async {
                      await _saveToTrip(tripDoc.id);
                      if (mounted) Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveToTrip(String tripId) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;

      final locationRef = FirebaseFirestore.instance.collection('location').doc();
      final placeName = _details?['name']?.toString() ??
          widget.place['name']?.toString() ??
          'Unknown';

      await locationRef.set({
        'locationID': locationRef.id,
        'locationName': placeName,
        'description': _details?['description']?.toString() ?? '',
        'latitude': widget.place['latitude'] ?? 0.0,
        'longitude': widget.place['longitude'] ?? 0.0,
        'openingHours': _details?['openingHours']?.toString() ?? '',
        'contactNo': _details?['phone']?.toString() ?? '',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final itineraryRef = FirebaseFirestore.instance.collection('itineraryItem').doc();
      await itineraryRef.set({
        'itineraryItemID': itineraryRef.id,
        'tripID': tripId,
        'locationID': locationRef.id,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // 🆕 ADD THIS: Track place added to trip
      final tags = widget.place['tags'] as Map<String, dynamic>?;
      final address = widget.place['address'] as Map<String, dynamic>?;

      await InteractionTracker().trackPlaceAddedToTrip(
        placeId: widget.place['osmId']?.toString() ?? 'unknown',
        placeName: placeName,
        category: tags?['tourism']?.toString() ??
            tags?['amenity']?.toString() ??
            'general',
        tripId: tripId,
        state: address?['state']?.toString(),
        country: address?['country']?.toString(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to trip successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeName = _details?['name']?.toString() ??
        _extractEnglishPlaceName() ??
        widget.place['name']?.toString() ??
        'Unknown Place';
    final address = widget.place['address'] as Map<String, dynamic>?;
    final city = address?['city']?.toString() ?? '';
    final state = address?['state']?.toString() ?? '';
    final country = address?['country']?.toString() ?? '';

    String location = '';
    if (city.isNotEmpty) location = city;
    if (state.isNotEmpty) {
      location += location.isEmpty ? state : ', $state';
    }
    if (country.isNotEmpty && location.isEmpty) location = country;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
        ),
      )
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _imageUrl != null
                  ? Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes !=
                            null
                            ? loadingProgress
                            .cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor:
                        const AlwaysStoppedAnimation<Color>(
                            Color(0xFF4A90E2)),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.landscape,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                  );
                },
              )
                  : Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.image,
                  size: 80,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (location.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 18,
                          color: Color(0xFF4A90E2),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Explore Nearby',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryIcon(Icons.restaurant, 'Food'),
                        _buildCategoryIcon(Icons.hotel, 'Hotel'),
                        _buildCategoryIcon(
                            Icons.local_activity, 'Activity'),
                        _buildCategoryIcon(
                            Icons.camera_alt, 'Photo Spots'),
                        _buildCategoryIcon(
                            Icons.shopping_bag, 'Shopping'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'About Destination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_details?['description']?.toString().isNotEmpty ??
                      false)
                    Text(
                      _details!['description'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    )
                  else
                    Text(
                      _getSmartFallbackDescription(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_details?['openingHours']?.toString() !=
                      'Not available' &&
                      _details?['openingHours']?.toString().isNotEmpty ==
                          true)
                    _buildDetailRow(
                      Icons.access_time,
                      'Opening Hours',
                      _formatOpeningHours(
                          _details!['openingHours'].toString()),
                    ),
                  if (_details?['phone']?.toString() != 'Not available' &&
                      _details?['phone']?.toString().isNotEmpty == true)
                    _buildDetailRow(
                      Icons.phone,
                      'Contact',
                      _details!['phone'].toString(),
                    ),
                  if (_details?['website']?.toString().isNotEmpty ??
                      false)
                    InkWell(
                      onTap: () =>
                          _launchURL(_details!['website'].toString()),
                      child: _buildDetailRow(
                        Icons.language,
                        'Website',
                        _details!['website'].toString(),
                        isLink: true,
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addToTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Add to Trip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(IconData icon, String label) {
    return InkWell(
      onTap: () => _searchNearbyCategory(label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4A90E2),
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4A90E2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLink ? const Color(0xFF4A90E2) : Colors.black87,
                    fontWeight: FontWeight.w500,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
          if (isLink)
            Icon(
              Icons.open_in_new,
              size: 16,
              color: Colors.grey[400],
            ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}