import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // IMPROVED: Extract English place name with better logic
  String _extractEnglishPlaceName() {
    String placeName = '';

    final tags = widget.place['tags'] as Map<String, dynamic>?;
    if (tags != null) {
      placeName = tags['name:en']?.toString() ??
          tags['int_name']?.toString() ??
          tags['official_name:en']?.toString() ??
          tags['alt_name:en']?.toString() ??
          '';
    }

    if (placeName.isEmpty) {
      String fullName = widget.place['name']?.toString() ?? '';

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

  bool _containsLatinCharacters(String text) {
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  // IMPROVED: Fetch Wikipedia data with alternative search
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
              print('⚠️ No thumbnail, using fallback');
              _setFallbackImage(placeName);
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
            _setFallbackImage(placeName);
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

  void _setFallbackImage(String placeName) {
    final random = placeName.hashCode.abs() % 1000;
    setState(() {
      _imageUrl = 'https://picsum.photos/seed/$random/800/600';
    });
    print('📸 Using fallback image');
  }

  // IMPROVED: Smart fallback descriptions based on place type
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
    } else if (tourism == 'gallery') {
      return 'An art gallery showcasing various artworks and exhibitions.';
    } else if (tourism == 'theme_park' || tourism == 'zoo') {
      return 'An entertainment venue offering attractions and activities for visitors of all ages.';
    } else if (tags['shop'] != null) {
      return 'A retail establishment offering products and services.';
    }

    return 'Discover this amazing destination worth visiting.';
  }

  Future<void> _fetchDetails() async {
    final tags = widget.place['tags'] as Map<String, dynamic>?;

    // Build details from available data
    String name = _extractEnglishPlaceName();
    if (name.isEmpty) {
      name = widget.place['name']?.toString() ?? 'Unknown';
    }

    String description = _wikipediaDescription ?? _getSmartFallbackDescription();
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

      final locationRef =
      FirebaseFirestore.instance.collection('location').doc();
      await locationRef.set({
        'locationID': locationRef.id,
        'locationName': _details?['name']?.toString() ??
            widget.place['name']?.toString() ??
            'Unknown',
        'description': _details?['description']?.toString() ?? '',
        'latitude': widget.place['latitude'] ?? widget.place['lat'] ?? 0.0,
        'longitude': widget.place['longitude'] ?? widget.place['lon'] ?? 0.0,
        'openingHours': _details?['openingHours']?.toString() ?? '',
        'contactNo': _details?['phone']?.toString() ?? '',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final itineraryRef =
      FirebaseFirestore.instance.collection('itineraryItem').doc();
      await itineraryRef.set({
        'itineraryItemID': itineraryRef.id,
        'tripID': tripId,
        'locationID': locationRef.id,
        'addedAt': FieldValue.serverTimestamp(),
      });

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

  // NEW: Parse address from tags
  String _getAddressString() {
    final tags = widget.place['tags'] as Map<String, dynamic>?;
    if (tags == null) return '';

    List<String> addressParts = [];

    // Street number and name
    String street = '';
    if (tags['addr:housenumber'] != null) {
      street = tags['addr:housenumber'].toString();
    }
    if (tags['addr:street'] != null) {
      if (street.isNotEmpty) {
        street += ' ${tags['addr:street']}';
      } else {
        street = tags['addr:street'].toString();
      }
    }
    if (street.isNotEmpty) addressParts.add(street);

    // City
    if (tags['addr:city'] != null) {
      addressParts.add(tags['addr:city'].toString());
    }

    // State/Province
    if (tags['addr:state'] != null) {
      addressParts.add(tags['addr:state'].toString());
    } else if (tags['addr:province'] != null) {
      addressParts.add(tags['addr:province'].toString());
    }

    // Postal code
    if (tags['addr:postcode'] != null) {
      addressParts.add(tags['addr:postcode'].toString());
    }

    // Country
    if (tags['addr:country'] != null) {
      addressParts.add(tags['addr:country'].toString());
    }

    return addressParts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final placeName = _details?['name']?.toString() ??
        _extractEnglishPlaceName() ??
        widget.place['name']?.toString() ??
        'Unknown Place';

    // Get location from tags
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

    // Get full address
    String fullAddress = _getAddressString();

    // Get distance if available
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
                  // Place Name
                  Text(
                    placeName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location
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

                  // Distance
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

                  // About This Place
                  const Text(
                    'About This Place',
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

                  // Details Section
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Full Address
                  if (fullAddress.isNotEmpty)
                    _buildDetailRow(
                      Icons.location_city,
                      'Address',
                      fullAddress,
                    ),

                  // Opening Hours
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

                  // Phone
                  if (_details?['phone']?.toString() != 'Not available' &&
                      _details?['phone']?.toString().isNotEmpty == true)
                    _buildDetailRow(
                      Icons.phone,
                      'Contact',
                      _details!['phone'].toString(),
                    ),

                  // Website
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

                  // Add to Trip Button
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
                    fontWeight: FontWeight.w500,
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