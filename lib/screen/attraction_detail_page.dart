import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/wikipedia_controller.dart';
import '../controller/place_image_controller.dart';
import '../utilities/string_helper.dart';
import '../widget/detail_row.dart';
import '../widget/favorite_button.dart';

class AttractionDetailPage extends StatefulWidget {
  final Map<String, dynamic> place;

  const AttractionDetailPage({super.key, required this.place});

  @override
  State<AttractionDetailPage> createState() => _AttractionDetailPageState();
}

class _AttractionDetailPageState extends State<AttractionDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _details;
  String? _imageUrl;
  String? _wikipediaDescription;

  @override
  void initState() {
    super.initState();
    _initializeData();
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

  Future<void> _fetchWikipediaData() async {
    String placeName = StringHelper.extractEnglishPlaceName(widget.place);

    // Try Wikipedia first
    final wikiData = await WikipediaController.fetchWikipediaData(placeName, null);

    setState(() {
      _imageUrl = wikiData['imageUrl'];
      _wikipediaDescription = wikiData['description'];
    });

    // If no Wikipedia image, try our enhanced image controller
    if (_imageUrl == null) {
      final enhancedImageUrl = await PlaceImageController.getPlaceImage(
        placeName: placeName,
        placeType: widget.place['type'],
        latitude: widget.place['latitude'] ?? widget.place['lat'],
        longitude: widget.place['longitude'] ?? widget.place['lon'],
      );

      setState(() {
        _imageUrl = enhancedImageUrl;
      });
    }
  }

  Future<void> _fetchDetails() async {
    final tags = widget.place['tags'] as Map<String, dynamic>?;

    String name = StringHelper.extractEnglishPlaceName(widget.place);
    if (name.isEmpty) {
      name = widget.place['name']?.toString() ?? 'Unknown';
    }

    String description = _wikipediaDescription ??
        StringHelper.getSmartFallbackDescription(tags);
    String openingHours = tags?['opening_hours']?.toString() ?? 'Not available';
    String phone = tags?['phone']?.toString() ??
        tags?['contact:phone']?.toString() ?? 'Not available';
    String website = tags?['website']?.toString() ??
        tags?['contact:website']?.toString() ?? '';

    setState(() {
      _details = {
        'name': name,
        'description': description,
        'openingHours': openingHours,
        'phone': phone,
        'website': website,
      };
    });
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

    // Google Maps directions URL (will use current location as origin)
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );

    // Alternative: Open in Google Maps app with navigation
    final googleMapsAppUrl = Uri.parse(
      'google.navigation:q=$lat,$lon&mode=d',
    );

    try {
      // Try Google Maps app first (for Android)
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        // Fallback to web URL
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        // Final fallback: simple coordinates URL
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

  @override
  Widget build(BuildContext context) {
    final placeName = _details?['name']?.toString() ??
        StringHelper.extractEnglishPlaceName(widget.place) ??
        widget.place['name']?.toString() ??
        'Unknown Place';

    final tags = widget.place['tags'] as Map<String, dynamic>?;
    String location = '';
    if (tags != null) {
      final city = tags['addr:city']?.toString() ?? '';
      final state = tags['addr:state']?.toString() ?? '';
      final country = tags['addr:country']?.toString() ?? '';

      if (city.isNotEmpty) location = city;
      if (state.isNotEmpty) {
        location += location.isEmpty ? state : ', $state';
      }
      if (country.isNotEmpty && location.isEmpty) location = country;
    }

    String fullAddress = StringHelper.getAddressString(tags);

    final distance = widget.place['distance'] as double?;
    String distanceText = '';
    if (distance != null) {
      distanceText = '${distance.toStringAsFixed(1)} km away';
    }

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
              // SINGLE FAVORITE BUTTON - in app bar only
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: FavoriteButton(
                  place: widget.place,
                  size: 22,
                  showBackground: true,
                  backgroundColor: Colors.white.withOpacity(0.9),
                  padding: const EdgeInsets.all(8),
                ),
              ),
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
                    child: const Icon(Icons.directions, color: Colors.white, size: 20),
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
                  if (distanceText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.route,
                          size: 18,
                          color: Color(0xFF4A90E2),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Action buttons row - ONLY Directions and Map (no duplicate favorite)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openDirections,
                          icon: const Icon(Icons.directions, size: 20),
                          label: const Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openOnMap,
                          icon: const Icon(Icons.map, size: 20),
                          label: const Text('View Map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[600],
                            side: BorderSide(color: Colors.blue[600]!),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                    'About This Place',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _details?['description']?.toString() ??
                        StringHelper.getSmartFallbackDescription(tags),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (fullAddress.isNotEmpty)
                    DetailRow(
                      icon: Icons.location_city,
                      label: 'Address',
                      value: fullAddress,
                    ),
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