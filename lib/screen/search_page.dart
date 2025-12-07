import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/search_controller.dart';
import '../controller/interaction_tracker.dart';
import '../controller/place_image_controller.dart';
import '../utilities/icon_helper.dart';
import 'place_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _results = [];
  String? _errorMessage;
  Timer? _debounce;

  final List<Map<String, String>> _popularDestinations = [
    {'name': 'Tokyo Tower', 'icon': '🗼'},
    {'name': 'Eiffel Tower Paris', 'icon': '🗼'},
    {'name': 'Petronas Towers', 'icon': '🏢'},
    {'name': 'Penang Hill', 'icon': '⛰️'},
    {'name': 'Batu Caves', 'icon': '⛰️'},
    {'name': 'Big Ben London', 'icon': '🏰'},
  ];

  // Types to filter out (administrative/less useful for travelers)
  static const List<String> _excludedTypes = [
    'suburb',
    'neighbourhood',
    'neighborhood',
    'quarter',
    'district',
    'county',
    'state',
    'province',
    'region',
    'country',
    'continent',
    'city',
    'town',
    'village',
    'hamlet',
    'municipality',
    'administrative',
    'boundary',
    'postcode',
    'postal_code',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _results.clear();
        _errorMessage = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchDestination(query);
    });
  }

  /// Filter and sort results to prioritize tourism-relevant places
  List<dynamic> _filterAndSortResults(List<dynamic> results) {
    // First, filter out administrative/boundary types
    List<dynamic> filtered = results.where((place) {
      final type = (place['type']?.toString() ?? '').toLowerCase();
      final category = (place['category']?.toString() ?? '').toLowerCase();

      // Check if it's an excluded type
      for (var excluded in _excludedTypes) {
        if (type.contains(excluded) || category.contains(excluded)) {
          return false;
        }
      }
      return true;
    }).toList();

    // If all results were filtered out, keep the original but sort them
    if (filtered.isEmpty && results.isNotEmpty) {
      filtered = List.from(results);
    }

    // Sort: tourism types first, then others
    filtered.sort((a, b) {
      final typeA = (a['type']?.toString() ?? '').toLowerCase();
      final typeB = (b['type']?.toString() ?? '').toLowerCase();

      final scoreA = _getTourismScore(typeA);
      final scoreB = _getTourismScore(typeB);

      return scoreB.compareTo(scoreA); // Higher score first
    });

    // Remove duplicates based on name similarity
    filtered = _removeDuplicates(filtered);

    return filtered;
  }

  /// Get tourism relevance score (higher = more relevant for travelers)
  int _getTourismScore(String type) {
    type = type.toLowerCase();

    // High priority tourism types
    if (type.contains('peak') || type.contains('mountain')) return 100;
    if (type.contains('tower')) return 95;
    if (type.contains('attraction')) return 90;
    if (type.contains('museum')) return 85;
    if (type.contains('temple') || type.contains('shrine')) return 85;
    if (type.contains('beach')) return 85;
    if (type.contains('park')) return 80;
    if (type.contains('monument') || type.contains('memorial')) return 80;
    if (type.contains('castle') || type.contains('palace')) return 80;
    if (type.contains('viewpoint')) return 75;
    if (type.contains('waterfall') || type.contains('lake')) return 75;
    if (type.contains('cave')) return 70;
    if (type.contains('bridge')) return 65;
    if (type.contains('building')) return 60;
    if (type.contains('hotel')) return 55;
    if (type.contains('restaurant')) return 50;

    // Low priority (administrative)
    if (type.contains('suburb') || type.contains('neighbourhood')) return 5;
    if (type.contains('district') || type.contains('county')) return 5;
    if (type.contains('city') || type.contains('town')) return 10;

    return 30; // Default score
  }

  /// Remove duplicate places with similar names
  List<dynamic> _removeDuplicates(List<dynamic> results) {
    final seen = <String>{};
    final unique = <dynamic>[];

    for (var place in results) {
      final name = (place['name']?.toString() ?? '').toLowerCase();
      // Extract base name (before comma or parenthesis)
      final baseName = name.split(',')[0].split('(')[0].trim();

      if (!seen.contains(baseName)) {
        seen.add(baseName);
        unique.add(place);
      }
    }

    return unique;
  }

  Future<void> _searchDestination(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await DestinationSearchController.searchDestinations(query);

      if (result['success'] == true) {
        final rawResults = result['results'] ?? [];
        final filteredResults = _filterAndSortResults(rawResults);

        setState(() {
          _results = filteredResults;
        });

        // Track search
        await InteractionTracker().trackSearch(
          searchQuery: query,
          resultsCount: _results.length,
        );

        if (_results.isEmpty) {
          setState(() {
            _errorMessage = 'No results found for "${_searchController.text}"';
          });
        }
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Search failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Check your internet.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onDestinationTap(String destination) {
    _searchController.text = destination;
    _searchDestination(destination);
  }

  void _openDirections(Map<String, dynamic> place) async {
    final lat = place['latitude'] ?? place['lat'];
    final lon = place['longitude'] ?? place['lon'];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Travel Search',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search destination',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  prefixIcon:
                  Icon(Icons.search, color: Colors.grey[400], size: 24),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400]),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _results.clear();
                        _errorMessage = null;
                      });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: _searchDestination,
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
              ),
            )
                : _errorMessage != null
                ? _buildEmptyState()
                : _results.isEmpty
                ? _buildSuggestionsState()
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Illustration container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.travel_explore,
              size: 56,
              color: Colors.grey[400],
            ),
          ),

          const SizedBox(height: 24),

          // Error message
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'Try searching for a specific landmark or attraction',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Suggested searches
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Try these popular searches:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSuggestionChip('Tokyo Tower'),
                    _buildSuggestionChip('Eiffel Tower'),
                    _buildSuggestionChip('Penang Hill'),
                    _buildSuggestionChip('Batu Caves'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Clear search button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _results.clear();
                _errorMessage = null;
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Clear Search'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return InkWell(
      onTap: () => _onDestinationTap(label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.blue[700],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Destinations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _popularDestinations.length,
            itemBuilder: (context, index) {
              final destination = _popularDestinations[index];
              return InkWell(
                onTap: () => _onDestinationTap(destination['name']!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(
                        destination['icon']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          destination['name']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Search for specific places like "Tokyo Tower" instead of just "Tokyo"',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final place = _results[index] as Map<String, dynamic>;
        return _SearchResultCard(
          place: place,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaceDetailPage(place: place),
              ),
            );
          },
          onDirections: () => _openDirections(place),
        );
      },
    );
  }
}

/// Search result card with image loading (no type badge)
class _SearchResultCard extends StatefulWidget {
  final Map<String, dynamic> place;
  final VoidCallback onTap;
  final VoidCallback onDirections;

  const _SearchResultCard({
    required this.place,
    required this.onTap,
    required this.onDirections,
  });

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  String? _imageUrl;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final name = widget.place['name']?.toString() ?? '';
      final lat = widget.place['latitude'] ?? widget.place['lat'];
      final lon = widget.place['longitude'] ?? widget.place['lon'];
      final type = widget.place['type']?.toString();

      final imageUrl = await PlaceImageController.getPlaceImage(
        placeName: name,
        placeType: type,
        latitude: lat is num ? lat.toDouble() : null,
        longitude: lon is num ? lon.toDouble() : null,
      );

      if (mounted) {
        setState(() {
          _imageUrl = imageUrl;
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  /// Get fallback color based on type
  Color _getFallbackColor(String type) {
    type = type.toLowerCase();

    if (type.contains('peak') || type.contains('mountain')) return Colors.green[700]!;
    if (type.contains('tower')) return Colors.blue[700]!;
    if (type.contains('attraction')) return Colors.amber[700]!;
    if (type.contains('museum')) return Colors.brown[600]!;
    if (type.contains('temple') || type.contains('shrine')) return Colors.red[700]!;
    if (type.contains('church') || type.contains('cathedral')) return Colors.indigo[600]!;
    if (type.contains('mosque')) return Colors.teal[700]!;
    if (type.contains('beach')) return Colors.cyan[600]!;
    if (type.contains('park') || type.contains('garden')) return Colors.green[600]!;
    if (type.contains('castle') || type.contains('palace')) return Colors.purple[700]!;
    if (type.contains('monument') || type.contains('memorial')) return Colors.blueGrey[600]!;
    if (type.contains('viewpoint')) return Colors.orange[700]!;
    if (type.contains('waterfall')) return Colors.blue[600]!;
    if (type.contains('lake')) return Colors.blue[500]!;
    if (type.contains('cave')) return Colors.grey[700]!;
    if (type.contains('island')) return Colors.teal[600]!;
    if (type.contains('bridge')) return Colors.blueGrey[700]!;
    if (type.contains('zoo') || type.contains('aquarium')) return Colors.orange[600]!;
    if (type.contains('theme_park') || type.contains('amusement')) return Colors.pink[600]!;
    if (type.contains('hotel') || type.contains('resort')) return Colors.purple[600]!;
    if (type.contains('restaurant') || type.contains('food')) return Colors.orange[600]!;
    if (type.contains('building') || type.contains('skyscraper')) return Colors.blueGrey[600]!;
    if (type.contains('stadium') || type.contains('arena')) return Colors.green[700]!;

    return const Color(0xFF4A90E2);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.place['name']?.toString() ?? 'Unknown Place';
    final address = widget.place['address'] as Map<String, dynamic>?;
    final city = address?['city']?.toString() ?? '';
    final country = address?['country']?.toString() ?? '';
    final type = widget.place['type']?.toString() ?? 'place';

    final fallbackColor = _getFallbackColor(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Image section
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  // Image
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: _buildImage(fallbackColor),
                  ),

                  // Directions button only
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: widget.onDirections,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatPlaceName(name),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (city.isNotEmpty || country.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$city${city.isNotEmpty && country.isNotEmpty ? ', ' : ''}$country',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format place name to be cleaner
  String _formatPlaceName(String name) {
    // Remove long suffixes after comma if name is too long
    if (name.length > 35) {
      final parts = name.split(',');
      if (parts.isNotEmpty) {
        String shortName = parts[0].trim();
        if (parts.length > 1 && shortName.length < 30) {
          shortName += ', ${parts[1].trim()}';
        }
        return shortName;
      }
    }
    return name;
  }

  Widget _buildImage(Color fallbackColor) {
    if (_isLoadingImage) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[300]!),
            ),
          ),
        ),
      );
    }

    if (_imageUrl != null) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[300]!),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackImage(fallbackColor);
        },
      );
    }

    return _buildFallbackImage(fallbackColor);
  }

  Widget _buildFallbackImage(Color color) {
    final type = widget.place['type']?.toString() ?? 'place';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          IconHelper.getIconForType(type),
          size: 48,
          color: color.withOpacity(0.7),
        ),
      ),
    );
  }
}