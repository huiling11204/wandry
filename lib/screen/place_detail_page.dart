// lib/screen/place_detail_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../controller/wikipedia_controller.dart';
import '../controller/place_image_controller.dart';
import '../controller/overpass_controller.dart';
import '../controller/interaction_tracker.dart';
import '../utilities/string_helper.dart';
import '../utilities/icon_helper.dart';
import '../utilities/distance_calculator.dart';
import '../widget/detail_row.dart';
import '../widget/category_icon.dart';

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
      _fetchImageAndWikipedia(),
      _fetchDetails(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchImageAndWikipedia() async {
    String placeName = StringHelper.extractEnglishPlaceName(widget.place);
    if (placeName.isEmpty) {
      placeName = widget.place['name']?.toString() ?? '';
    }

    String country = StringHelper.getEnglishCountryName(
      widget.place['address'] as Map<String, dynamic>?,
    );

    // Try Wikipedia first for description
    final wikiData = await WikipediaController.fetchWikipediaData(
      placeName,
      country,
    );

    setState(() {
      _imageUrl = wikiData['imageUrl'];
      _wikipediaDescription = wikiData['description'];
    });

    // If no Wikipedia image, use PlaceImageController for better matching
    if (_imageUrl == null) {
      final lat = widget.place['latitude'] ?? widget.place['lat'];
      final lon = widget.place['longitude'] ?? widget.place['lon'];

      final enhancedImageUrl = await PlaceImageController.getPlaceImage(
        placeName: placeName,
        placeType: widget.place['type']?.toString(),
        latitude: lat is num ? lat.toDouble() : null,
        longitude: lon is num ? lon.toDouble() : null,
        country: country,
      );

      setState(() {
        _imageUrl = enhancedImageUrl;
      });
    }
  }

  Future<void> _fetchDetails() async {
    final osmType = widget.place['osmType'];
    final osmId = widget.place['osmId'];

    if (osmType == null || osmId == null) {
      print('⚠️ No OSM data, using fallback');
      final tags = widget.place['tags'] as Map<String, dynamic>?;
      setState(() {
        _details = {
          'name': StringHelper.extractEnglishPlaceName(widget.place).isNotEmpty
              ? StringHelper.extractEnglishPlaceName(widget.place)
              : widget.place['name']?.toString() ?? 'Unknown',
          'description': _wikipediaDescription ??
              StringHelper.getSmartFallbackDescription(tags),
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
                final tags = widget.place['tags'] as Map<String, dynamic>?;
                details['description'] =
                    StringHelper.getSmartFallbackDescription(tags);
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
      final tags = widget.place['tags'] as Map<String, dynamic>?;
      setState(() {
        _details = {
          'name': StringHelper.extractEnglishPlaceName(widget.place).isNotEmpty
              ? StringHelper.extractEnglishPlaceName(widget.place)
              : widget.place['name']?.toString() ?? 'Unknown',
          'description': _wikipediaDescription ??
              StringHelper.getSmartFallbackDescription(tags),
          'openingHours': 'Not available',
          'phone': 'Not available',
          'website': '',
        };
      });
    }
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

  /// Open Google Maps with directions from current location
  Future<void> _openDirections() async {
    final lat = widget.place['latitude'] ?? widget.place['lat'];
    final lon = widget.place['longitude'] ?? widget.place['lon'];

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );

    final googleMapsAppUrl = Uri.parse(
      'google.navigation:q=$lat,$lon&mode=d',
    );

    try {
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUrl = Uri.parse('https://www.google.com/maps?q=$lat,$lon');
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps: $e')),
        );
      }
    }
  }

  /// Open location on Google Maps (view only)
  Future<void> _openOnMap() async {
    final lat = widget.place['latitude'] ?? widget.place['lat'];
    final lon = widget.place['longitude'] ?? widget.place['lon'];

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    final url = Uri.parse('https://www.google.com/maps?q=$lat,$lon');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps: $e')),
        );
      }
    }
  }

  Future<void> _searchNearbyCategory(String category) async {
    final lat = widget.place['latitude'] ?? widget.place['lat'];
    final lon = widget.place['longitude'] ?? widget.place['lon'];

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
        ),
      ),
    );

    print('🔍 Searching for $category near location...');

    try {
      final results = await OverpassController.fetchNearbyCategory(
        category,
        lat is num ? lat.toDouble() : 0.0,
        lon is num ? lon.toDouble() : 0.0,
      );

      if (results.isEmpty) {
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

      // Process results with distances
      List<Map<String, dynamic>> places = [];
      for (var element in results) {
        double eleLat = element['lat'] ?? element['latitude'] ?? 0.0;
        double eleLon = element['lon'] ?? element['longitude'] ?? 0.0;

        if (eleLat == 0.0 || eleLon == 0.0) continue;

        double distance = DistanceCalculator.calculateDistance(
          lat is num ? lat.toDouble() : 0.0,
          lon is num ? lon.toDouble() : 0.0,
          eleLat,
          eleLon,
        );

        String placeName = _getEnglishNameFromTags(element['tags']);

        places.add({
          'name': placeName,
          'latitude': eleLat,
          'longitude': eleLon,
          'osmType': element['osmType'] ?? element['type'],
          'osmId': element['osmId'] ?? element['id'],
          'tags': element['tags'] ?? {},
          'address': _parseAddress(element['tags']),
          'distance': distance,
        });
      }

      places.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));
      places = places.take(20).toList();

      if (mounted) {
        Navigator.pop(context);
        _showNearbyResults(category, places);
      }
    } catch (e) {
      print('❌ Error searching: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Search temporarily unavailable. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _searchNearbyCategory(category),
            ),
          ),
        );
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

    if (!StringHelper.containsLatinCharacters(name)) {
      if (tags['brand:en'] != null) {
        return tags['brand:en'].toString();
      }
      if (tags['brand'] != null &&
          StringHelper.containsLatinCharacters(tags['brand'].toString())) {
        return tags['brand'].toString();
      }
      String type = tags['amenity']?.toString() ??
          tags['tourism']?.toString() ??
          tags['shop']?.toString() ??
          'Place';
      return _capitalize(type);
    }

    return name;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return "${text[0].toUpperCase()}${text.substring(1)}";
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
                        IconHelper.getSearchCategoryIcon(category),
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
                          ? '${distance.toStringAsFixed(2)} km'
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              IconHelper.getSearchCategoryIcon(category),
                              color: const Color(0xFF4A90E2),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            place['name']?.toString().split(',')[0] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: distanceText.isNotEmpty
                              ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.directions_walk,
                                    size: 14, color: Colors.blue[600]),
                                const SizedBox(width: 4),
                                Text(
                                  distanceText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Directions button
                              IconButton(
                                icon: Icon(Icons.directions,
                                    color: Colors.blue[600], size: 22),
                                onPressed: () {
                                  final lat = place['latitude'];
                                  final lon = place['longitude'];
                                  if (lat != null && lon != null) {
                                    final url = Uri.parse(
                                      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
                                    );
                                    launchUrl(url, mode: LaunchMode.externalApplication);
                                  }
                                },
                                tooltip: 'Get Directions',
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlaceDetailPage(place: place),
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

  @override
  Widget build(BuildContext context) {
    final placeName = _details?['name']?.toString() ??
        StringHelper.extractEnglishPlaceName(widget.place) ??
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
            actions: [
              // Quick directions button in app bar
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions,
                        color: Colors.white, size: 20),
                  ),
                  onPressed: _openDirections,
                  tooltip: 'Get Directions',
                ),
              ),
            ],
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
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: const AlwaysStoppedAnimation<Color>(
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

                  const SizedBox(height: 20),

                  // Action buttons - Equal width
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openDirections,
                          icon: const Icon(Icons.directions, size: 27),
                          label: const Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openOnMap,
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('View Map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[600],
                            side: BorderSide(color: Colors.blue[600]!, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
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
                        CategoryIcon(
                          icon: Icons.restaurant,
                          label: 'Food',
                          onTap: () => _searchNearbyCategory('Food'),
                        ),
                        CategoryIcon(
                          icon: Icons.hotel,
                          label: 'Hotel',
                          onTap: () => _searchNearbyCategory('Hotel'),
                        ),
                        CategoryIcon(
                          icon: Icons.local_activity,
                          label: 'Activity',
                          onTap: () => _searchNearbyCategory('Activity'),
                        ),
                        CategoryIcon(
                          icon: Icons.camera_alt,
                          label: 'Photo Spots',
                          onTap: () => _searchNearbyCategory('Photo Spots'),
                        ),
                        CategoryIcon(
                          icon: Icons.shopping_bag,
                          label: 'Shopping',
                          onTap: () => _searchNearbyCategory('Shopping'),
                        ),
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
                  Text(
                    _details?['description']?.toString() ??
                        StringHelper.getSmartFallbackDescription(
                            widget.place['tags'] as Map<String, dynamic>?),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_details?['openingHours']?.toString() != 'Not available' &&
                      _details?['openingHours']?.toString().isNotEmpty == true)
                    DetailRow(
                      icon: Icons.access_time,
                      label: 'Opening Hours',
                      value: StringHelper.formatOpeningHours(
                          _details!['openingHours'].toString()),
                    ),
                  if (_details?['phone']?.toString() != 'Not available' &&
                      _details?['phone']?.toString().isNotEmpty == true)
                    DetailRow(
                      icon: Icons.phone,
                      label: 'Contact',
                      value: _details!['phone'].toString(),
                    ),
                  if (_details?['website']?.toString().isNotEmpty ?? false)
                    InkWell(
                      onTap: () => _launchURL(_details!['website'].toString()),
                      child: DetailRow(
                        icon: Icons.language,
                        label: 'Website',
                        value: _details!['website'].toString(),
                        isLink: true,
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
}