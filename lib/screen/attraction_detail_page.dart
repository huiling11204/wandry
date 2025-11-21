// lib/screen/attraction_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/wikipedia_controller.dart';
import '../controller/trip_controller.dart';
import '../utilities/string_helper.dart';
import '../widget/detail_row.dart';

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

    final wikiData = await WikipediaController.fetchWikipediaData(placeName, null);

    setState(() {
      _imageUrl = wikiData['imageUrl'];
      _wikipediaDescription = wikiData['description'];
    });

    if (_imageUrl == null) {
      setState(() {
        _imageUrl = WikipediaController.getFallbackImageUrl(placeName);
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

  Future<void> _addToTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    try {
      final trips = await TripController.getUserTrips();

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
                ...trips.map((tripDoc) {
                  final tripData = tripDoc.data() as Map<String, dynamic>;
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
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _saveToTrip(String tripId) async {
    try {
      await TripController.addPlaceToTrip(
        tripId: tripId,
        placeName: _details?['name']?.toString() ??
            widget.place['name']?.toString() ??
            'Unknown',
        description: _details?['description']?.toString() ?? '',
        latitude: widget.place['latitude'] ?? widget.place['lat'] ?? 0.0,
        longitude: widget.place['longitude'] ?? widget.place['lon'] ?? 0.0,
        openingHours: _details?['openingHours']?.toString() ?? '',
        contactNo: _details?['phone']?.toString() ?? '',
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
}