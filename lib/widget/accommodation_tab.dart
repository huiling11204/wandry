import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'sweet_alert_dialog.dart';

/// ROBUST Accommodation Tab with Fallback Support
/// ✅ Works with OLD and NEW backend
/// ✅ Generates URLs on-the-fly if missing
/// ✅ Better error messages
/// ✅ Debug logging
/// ✅ SweetAlert confirmation before external links
class AccommodationTab extends StatefulWidget {
  final String tripId;

  const AccommodationTab({Key? key, required this.tripId}) : super(key: key);

  @override
  State<AccommodationTab> createState() => _AccommodationTabState();
}

class _AccommodationTabState extends State<AccommodationTab> {
  Map<String, dynamic>? _cachedData;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('accommodation')
          .doc(widget.tripId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final newData = snapshot.data!.data() as Map<String, dynamic>;
          if (_cachedData == null || _cachedData.toString() != newData.toString()) {
            _cachedData = newData;
            _isLoading = false;
          }
        } else if (!snapshot.hasData || !snapshot.data!.exists) {
          _isLoading = snapshot.connectionState == ConnectionState.waiting;
        }

        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_cachedData == null) {
          return _buildNoAccommodations(context);
        }

        final accommodations = _cachedData!['accommodations'] as List? ?? [];
        final recommended = _cachedData!['recommendedAccommodation'] as Map<String, dynamic>?;
        final totalCostRange = _cachedData!['totalCostRange'] as Map<String, dynamic>?;
        final numNights = _cachedData!['numNights'] ?? 1;
        final checkinDate = _cachedData!['checkinDate'] as String?;
        final checkoutDate = _cachedData!['checkoutDate'] as String?;

        if (accommodations.isEmpty) {
          return _buildNoAccommodations(context);
        }

        String dateRangeDisplay = '';
        if (checkinDate != null && checkoutDate != null) {
          try {
            final checkin = DateTime.parse(checkinDate);
            final checkout = DateTime.parse(checkoutDate);
            dateRangeDisplay = '${DateFormat('MMM d').format(checkin)} - ${DateFormat('MMM d, yyyy').format(checkout)}';
          } catch (e) {
            dateRangeDisplay = '$checkinDate - $checkoutDate';
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3 + (recommended != null ? 1 : 0) + accommodations.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildCostSummaryCard(totalCostRange, numNights, dateRangeDisplay);
            }

            if (index == 1 && recommended != null) {
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Our Top Pick',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (index == 2 && recommended != null) {
              return Column(
                children: [
                  _buildRecommendedCard(
                    context,
                    recommended,
                    numNights,
                    checkinDate,
                    checkoutDate,
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }

            final headerIndex = (recommended != null ? 3 : 1);
            if (index == headerIndex) {
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${accommodations.length} accommodations found',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            final accIndex = index - (headerIndex + 1);
            if (accIndex >= 0 && accIndex < accommodations.length) {
              return _buildAccommodationCard(
                context,
                Map<String, dynamic>.from(accommodations[accIndex] as Map),
                numNights,
                checkinDate,
                checkoutDate,
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildNoAccommodations(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hotel, size: 64, color: Colors.purple[400]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Finding Accommodations...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We\'re searching for the best places to stay based on your preferences.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSummaryCard(
      Map<String, dynamic>? costRange, int numNights, String dateRange) {
    if (costRange == null) return const SizedBox.shrink();

    final minCost = costRange['min'] ?? 0;
    final maxCost = costRange['max'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hotel, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Accommodation Budget',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$numNights ${numNights == 1 ? 'night' : 'nights'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                    if (dateRange.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        dateRange,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'RM ${minCost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'to',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Up to',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'RM ${maxCost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCard(
      BuildContext context,
      Map<String, dynamic> acc,
      int numNights,
      String? checkinDate,
      String? checkoutDate,
      ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[50]!, Colors.amber[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[300]!, width: 2),
      ),
      child: _buildAccommodationCardContent(
        context,
        acc,
        numNights,
        checkinDate,
        checkoutDate,
        isRecommended: true,
      ),
    );
  }

  Widget _buildAccommodationCard(
      BuildContext context,
      Map<String, dynamic> acc,
      int numNights,
      String? checkinDate,
      String? checkoutDate,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _buildAccommodationCardContent(
        context,
        acc,
        numNights,
        checkinDate,
        checkoutDate,
      ),
    );
  }

  Widget _buildAccommodationCardContent(
      BuildContext context,
      Map<String, dynamic> acc,
      int numNights,
      String? checkinDate,
      String? checkoutDate, {
        bool isRecommended = false,
      }) {
    final name = acc['name'] ?? 'Accommodation';
    final type = acc['type'] ?? 'Hotel';
    final stars = acc['stars'] as int?;
    final rating = acc['rating'] ?? 4.0;
    final reviewsCount = acc['reviews_count'] ?? 0;
    final pricePerNight = acc['price_per_night_myr'] ?? 0.0;
    final totalCost = acc['total_cost_myr'] ?? 0.0;
    final address = acc['address'] ?? '';
    final distanceKm = acc['distance_km'] ?? 0.0;
    final amenities = acc['amenities'] as List? ?? [];
    final bookingLinks = acc['booking_links'] as Map<String, dynamic>? ?? {};
    final mapsLink = acc['maps_link'] ?? '';
    final phone = acc['phone'] ?? '';
    final website = acc['website'] ?? '';
    final city = acc['city'] ?? '';
    final country = acc['country'] ?? '';

    // ✅ DEBUG: Log booking links
    debugPrint('📋 Hotel: $name');
    debugPrint('📋 Booking links available: ${bookingLinks.keys.toList()}');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRecommended ? Colors.amber[200] : Colors.purple[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.hotel,
                  color: isRecommended ? Colors.amber[900] : Colors.purple[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (stars != null) ...[
                          ...List.generate(
                            stars,
                                (index) => Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rating and distance
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.green[700], size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$rating',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($reviewsCount)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: Colors.blue[700], size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Address
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ],
          ),

          // Amenities
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenities.take(4).map((amenity) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getAmenityIcon(amenity.toString()),
                          size: 12, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(
                        amenity.toString(),
                        style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Price
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[50]!, Colors.green[100]!],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RM ${pricePerNight.toStringAsFixed(0)} / night',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
                Text(
                  'Total: RM ${totalCost.toStringAsFixed(0)} ($numNights nights)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),

          // ✅ ROBUST: Booking section with fallback
          const SizedBox(height: 16),
          _buildRobustBookingSection(
            name: name,
            city: city,
            country: country,
            checkinDate: checkinDate,
            checkoutDate: checkoutDate,
            bookingLinks: bookingLinks,
          ),

          // Additional actions
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('View on Map', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _showExternalLinkDialog('Google Maps', mapsLink),
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('Call', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onPressed: () => _launchURL('tel:$phone'),
                  ),
                ),
              ],
              if (website.isNotEmpty) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.language, size: 16),
                    label: const Text('Site', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onPressed: () => _showExternalLinkDialog(name, website),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// ✅ ROBUST: Generate URLs on-the-fly if backend doesn't provide them
  Widget _buildRobustBookingSection({
    required String name,
    required String city,
    required String country,
    String? checkinDate,
    String? checkoutDate,
    required Map<String, dynamic> bookingLinks,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Find & Book',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Multiple ways to find this hotel',
              child: Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Primary booking buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildRobustBookingButton(
              'Booking.com',
              bookingLinks,
              'booking_com',
              Colors.blue[700]!,
              name,
              city,
              country,
              checkinDate,
              checkoutDate,
            ),
            _buildRobustBookingButton(
              'Agoda',
              bookingLinks,
              'agoda',
              Colors.red[600]!,
              name,
              city,
              country,
              checkinDate,
              checkoutDate,
            ),
            _buildRobustBookingButton(
              'Trip.com',
              bookingLinks,
              'trip_com',
              Colors.orange[700]!,
              name,
              city,
              country,
              checkinDate,
              checkoutDate,
            ),
            _buildRobustBookingButton(
              'Hotels.com',
              bookingLinks,
              'hotels_com',
              Colors.red[800]!,
              name,
              city,
              country,
              checkinDate,
              checkoutDate,
            ),
          ],
        ),

        // Search tip
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip: Long-press any button for more search options',
                  style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ✅ ROBUST: Button that works with old and new backend
  Widget _buildRobustBookingButton(
      String label,
      Map<String, dynamic> bookingLinks,
      String platform,
      Color color,
      String hotelName,
      String city,
      String country,
      String? checkinDate,
      String? checkoutDate,
      ) {
    // Get direct URL or generate fallback
    final directUrl = bookingLinks[platform] as String? ?? _generateFallbackURL(platform, city, country, checkinDate, checkoutDate);

    // Get alternative URLs or generate them
    final googleUrl = bookingLinks['${platform}_google'] as String? ?? _generateGoogleSearchURL(platform, hotelName, city, country);
    final cityUrl = bookingLinks['${platform}_city'] as String? ?? _generateCitySearchURL(platform, city, country, checkinDate, checkoutDate);

    debugPrint('🔗 $label URLs:');
    debugPrint('   Direct: $directUrl');
    debugPrint('   Google: $googleUrl');
    debugPrint('   City: $cityUrl');

    return GestureDetector(
      onLongPress: () {
        _showRobustBookingOptions(
          context,
          label,
          hotelName,
          city,
          country,
          directUrl,
          googleUrl,
          cityUrl,
        );
      },
      child: ElevatedButton(
        onPressed: () => _showExternalLinkDialog(label, directUrl),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  /// ✅ FALLBACK: Generate URLs if backend doesn't provide them
  String _generateFallbackURL(String platform, String city, String country, String? checkinDate, String? checkoutDate) {
    final dates = (checkinDate != null && checkoutDate != null)
        ? '&checkin=$checkinDate&checkout=$checkoutDate'
        : '';

    switch (platform) {
      case 'booking_com':
        return 'https://www.booking.com/searchresults.html?ss=${Uri.encodeComponent("$city, $country")}$dates';
      case 'agoda':
        return 'https://www.agoda.com/search?city=${Uri.encodeComponent(city)}${dates.replaceAll('checkin', 'checkIn').replaceAll('checkout', 'checkOut')}';
      case 'trip_com':
        return 'https://us.trip.com/hotels/list?city=${Uri.encodeComponent(city)}${dates.replaceAll('&', '&')}';
      case 'hotels_com':
        return 'https://www.hotels.com/Hotel-Search?q-destination=${Uri.encodeComponent("$city, $country")}${dates.replaceAll('checkin', 'q-check-in').replaceAll('checkout', 'q-check-out')}';
      default:
        return 'https://www.google.com/search?q=${Uri.encodeComponent("hotels in $city $country")}';
    }
  }

  String _generateGoogleSearchURL(String platform, String hotelName, String city, String country) {
    final platformDomain = platform.replaceAll('_', '.');
    return 'https://www.google.com/search?q=${Uri.encodeComponent("$hotelName $city $country $platformDomain")}';
  }

  String _generateCitySearchURL(String platform, String city, String country, String? checkinDate, String? checkoutDate) {
    return _generateFallbackURL(platform, city, country, checkinDate, checkoutDate);
  }

  /// ✅ ROBUST: Show options with all URLs guaranteed to work
  void _showRobustBookingOptions(
      BuildContext context,
      String platform,
      String hotelName,
      String city,
      String country,
      String directUrl,
      String googleUrl,
      String cityUrl,
      ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Find on $platform',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Searching for: $hotelName',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 24),

            // Option 1: Direct search
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.link, color: Colors.blue[700], size: 20),
              ),
              title: const Text('Direct Search'),
              subtitle: const Text('Opens with search filled (fastest)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showExternalLinkDialog(platform, directUrl);
              },
            ),

            // Option 2: Google search
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.search, color: Colors.green[700], size: 20),
              ),
              title: const Text('Find via Google'),
              subtitle: const Text('Most accurate - finds exact hotel page'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                debugPrint('🔍 Launching Google search: $googleUrl');
                _showExternalLinkDialog('Google Search', googleUrl);
              },
            ),

            // Option 3: City search
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.location_city, color: Colors.orange[700], size: 20),
              ),
              title: const Text('Browse City Hotels'),
              subtitle: Text('Show all hotels in $city'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                debugPrint('🏙️ Launching city search: $cityUrl');
                _showExternalLinkDialog(platform, cityUrl);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ NEW: Show confirmation dialog before opening external link
  Future<void> _showExternalLinkDialog(String siteName, String url) async {
    if (url.isEmpty) return;

    final result = await SweetAlertDialog.show(
      context: context,
      type: SweetAlertType.info,
      title: 'Leaving Wandry',
      subtitle: 'You are about to visit $siteName. This will open in your browser.',
      content: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.link, color: Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getShortenedUrl(url),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      confirmText: 'Open',
      cancelText: 'Cancel',
      showCancelButton: true,
    );

    if (result == true) {
      _launchBookingURL(url, siteName);
    }
  }

  /// ✅ NEW: Get shortened URL for display
  String _getShortenedUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host + (uri.path.length > 20 ? '${uri.path.substring(0, 20)}...' : uri.path);
    } catch (e) {
      return url.length > 40 ? '${url.substring(0, 40)}...' : url;
    }
  }

  Future<void> _launchBookingURL(String url, String platform) async {
    try {
      debugPrint('🚀 Attempting to launch: $platform');
      debugPrint('🔗 URL: $url');

      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);

      debugPrint('✅ Can launch: $canLaunch');

      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          debugPrint('✅ Successfully launched $platform');
        } else {
          debugPrint('❌ Failed to launch $platform');
          if (mounted) {
            SweetAlertDialog.error(
              context: context,
              title: 'Cannot Open Link',
              subtitle: 'Could not open $platform. Please try again later.',
            );
          }
        }
      } else {
        debugPrint('❌ Cannot launch $platform - URL not supported');
        if (mounted) {
          SweetAlertDialog.error(
            context: context,
            title: 'Cannot Open Link',
            subtitle: 'Cannot open $platform - invalid URL.',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error launching $platform: $e');
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Error',
          subtitle: 'An error occurred: $e',
        );
      }
    }
  }

  IconData _getAmenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('parking')) return Icons.local_parking;
    if (lower.contains('air')) return Icons.ac_unit;
    if (lower.contains('wheelchair')) return Icons.accessible;
    if (lower.contains('smoking')) return Icons.smoke_free;
    return Icons.check_circle;
  }

  Future<void> _launchURL(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}