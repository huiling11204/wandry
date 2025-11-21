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
  List<Map<String, dynamic>> _attractions = [];
  List<Map<String, dynamic>> _food = [];
  List<Map<String, dynamic>> _accommodation = [];
  bool _isLoading = false;
  String? _error;
  String _loadingMessage = 'Searching...';

  @override
  void initState() {
    super.initState();
    _searchNearbyAttractions();
  }

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
      final radius = (widget.searchRadius * 1000).toInt();

      print('Starting search for nearby places...');
      print('Location: $lat, $lon');
      print('Radius: $radius meters');

      setState(() => _loadingMessage = 'Finding attractions...');
      print('Fetching attractions...');
      final attractions = await OverpassController.fetchAttractions(lat, lon, radius);

      // Calculate distances and sort
      for (var place in attractions) {
        place['distance'] = DistanceCalculator.calculateDistance(
          lat,
          lon,
          place['latitude'],
          place['longitude'],
        );
      }
      attractions.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() => _attractions = attractions);

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _loadingMessage = 'Finding food places...');
      print('Fetching food places...');
      final food = await OverpassController.fetchFood(lat, lon, radius);

      for (var place in food) {
        place['distance'] = DistanceCalculator.calculateDistance(
          lat,
          lon,
          place['latitude'],
          place['longitude'],
        );
      }
      food.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() => _food = food);

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _loadingMessage = 'Finding accommodations...');
      print('Fetching accommodations...');
      final accommodation = await OverpassController.fetchAccommodation(lat, lon, radius);

      for (var place in accommodation) {
        place['distance'] = DistanceCalculator.calculateDistance(
          lat,
          lon,
          place['latitude'],
          place['longitude'],
        );
      }
      accommodation.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() => _accommodation = accommodation);

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
      itemCount: places.length > 6 ? 6 : places.length,
      itemBuilder: (context, index) {
        return PlaceCard(
          place: places[index],
          onTap: () => _navigateToAttractionDetail(places[index]),
        );
      },
    );
  }
}