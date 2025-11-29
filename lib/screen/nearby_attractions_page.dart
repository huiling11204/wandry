// lib/screen/nearby_attractions_page.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../controller/overpass_controller.dart';
import '../utilities/distance_calculator.dart';
import '../widget/place_card.dart';
import 'attraction_detail_page.dart';

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
  // Maximum items to keep in memory per category
  static const int _maxItemsPerCategory = 50;

  List<Map<String, dynamic>> _attractions = [];
  List<Map<String, dynamic>> _food = [];
  List<Map<String, dynamic>> _accommodation = [];
  bool _isLoading = false;
  String? _error;
  String _loadingMessage = 'Searching...';

  // Track how many items to show per section (for lazy rendering)
  int _attractionsToShow = 6;
  int _foodToShow = 6;
  int _accommodationToShow = 6;

  // Track total counts before limiting
  int _totalAttractions = 0;
  int _totalFood = 0;
  int _totalAccommodation = 0;

  @override
  void initState() {
    super.initState();
    _searchNearbyAttractions();
  }

  List<Map<String, dynamic>> _processAndLimitPlaces(
      List<Map<String, dynamic>> places,
      double lat,
      double lon,
      ) {
    // Calculate distances
    for (var place in places) {
      place['distance'] = DistanceCalculator.calculateDistance(
        lat,
        lon,
        place['latitude'],
        place['longitude'],
      );
    }

    // Sort by distance
    places.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    // Return limited list to prevent memory issues
    // Takes top 50 closest places
    return places.take(_maxItemsPerCategory).toList();
  }

  Future<void> _searchNearbyAttractions() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _attractions = [];
      _food = [];
      _accommodation = [];
      _attractionsToShow = 6;
      _foodToShow = 6;
      _accommodationToShow = 6;
      _loadingMessage = 'Searching for attractions...';
    });

    try {
      final lat = widget.currentPosition.latitude;
      final lon = widget.currentPosition.longitude;
      final radius = (widget.searchRadius * 1000).toInt();

      print('Starting search for nearby places...');
      print('Location: $lat, $lon');
      print('Radius: $radius meters');

      // Fetch attractions
      setState(() => _loadingMessage = 'Finding attractions...');
      print('Fetching attractions...');
      final attractionsRaw = await OverpassController.fetchAttractions(lat, lon, radius);
      _totalAttractions = attractionsRaw.length;
      final attractions = _processAndLimitPlaces(attractionsRaw, lat, lon);
      setState(() => _attractions = attractions);

      await Future.delayed(const Duration(milliseconds: 300));

      // Fetch food
      setState(() => _loadingMessage = 'Finding food places...');
      print('Fetching food places...');
      final foodRaw = await OverpassController.fetchFood(lat, lon, radius);
      _totalFood = foodRaw.length;
      final food = _processAndLimitPlaces(foodRaw, lat, lon);
      setState(() => _food = food);

      await Future.delayed(const Duration(milliseconds: 300));

      // Fetch accommodation
      setState(() => _loadingMessage = 'Finding accommodations...');
      print('Fetching accommodations...');
      final accommodationRaw = await OverpassController.fetchAccommodation(lat, lon, radius);
      _totalAccommodation = accommodationRaw.length;
      final accommodation = _processAndLimitPlaces(accommodationRaw, lat, lon);
      setState(() => _accommodation = accommodation);

      print('Search completed successfully');
      print('Found: $_totalAttractions attractions (showing ${_attractions.length}), '
          '$_totalFood food places (showing ${_food.length}), '
          '$_totalAccommodation accommodations (showing ${_accommodation.length})');

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
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
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
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
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
              // Search radius info
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing closest ${_maxItemsPerCategory} places per category within ${widget.searchRadius.toInt()} km',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_attractions.isNotEmpty) ...[
                _buildSectionHeader('Attractive Locations', _attractions.length, _totalAttractions),
                const SizedBox(height: 16),
                _buildGridSection(_attractions, _attractionsToShow),
                if (_attractionsToShow < _attractions.length) ...[
                  const SizedBox(height: 12),
                  _buildShowMoreButton(
                    'Show More Attractions',
                    _attractions.length - _attractionsToShow,
                        () {
                      setState(() {
                        _attractionsToShow = (_attractionsToShow + 6).clamp(0, _attractions.length);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 32),
              ],
              if (_food.isNotEmpty) ...[
                _buildSectionHeader('Food Recommended', _food.length, _totalFood),
                const SizedBox(height: 16),
                _buildGridSection(_food, _foodToShow),
                if (_foodToShow < _food.length) ...[
                  const SizedBox(height: 12),
                  _buildShowMoreButton(
                    'Show More Food Places',
                    _food.length - _foodToShow,
                        () {
                      setState(() {
                        _foodToShow = (_foodToShow + 6).clamp(0, _food.length);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 32),
              ],
              if (_accommodation.isNotEmpty) ...[
                _buildSectionHeader('Accommodation', _accommodation.length, _totalAccommodation),
                const SizedBox(height: 16),
                _buildGridSection(_accommodation, _accommodationToShow),
                if (_accommodationToShow < _accommodation.length) ...[
                  const SizedBox(height: 12),
                  _buildShowMoreButton(
                    'Show More Accommodations',
                    _accommodation.length - _accommodationToShow,
                        () {
                      setState(() {
                        _accommodationToShow = (_accommodationToShow + 6).clamp(0, _accommodation.length);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 32),
              ],
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

  Widget _buildSectionHeader(String title, int showingCount, int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            totalCount > showingCount
                ? '$showingCount of $totalCount'
                : '$totalCount found',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.blue[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShowMoreButton(String text, int remaining, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue[600],
          side: BorderSide(color: Colors.blue[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          '$text ($remaining more)',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildGridSection(List<Map<String, dynamic>> places, int itemsToShow) {
    final displayCount = itemsToShow.clamp(0, places.length);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        return PlaceCard(
          place: places[index],
          onTap: () => _navigateToAttractionDetail(places[index]),
        );
      },
    );
  }
}