import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/favorite_controller.dart';
import '../controller/place_image_controller.dart';
import '../utilities/icon_helper.dart';
import '../widget/sweet_alert_dialog.dart';
import 'attraction_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _categories = ['All', 'Attractions', 'Food', 'Accommodation'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Favorites',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue[600],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blue[600],
            indicatorWeight: 3,
            isScrollable: false, // Keep tabs fixed width
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12, // Slightly smaller font
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            tabs: _categories.map((cat) {
              // Shorten labels to fit
              String label = cat;
              if (cat == 'Attractions') label = 'Attractions';
              if (cat == 'Accommodation') label = 'Hotels';
              return Tab(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FavoritesList(category: null), // All
          _FavoritesList(category: 'attraction'),
          _FavoritesList(category: 'food'),
          _FavoritesList(category: 'accommodation'),
        ],
      ),
    );
  }
}

/// Widget to display favorites list filtered by category
class _FavoritesList extends StatefulWidget {
  final String? category;

  const _FavoritesList({this.category});

  @override
  State<_FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<_FavoritesList>
    with AutomaticKeepAliveClientMixin {
  // Cache for loaded images - persists across rebuilds
  final Map<String, String?> _imageCache = {};

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FavoriteController.streamFavorites(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading favorites',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }

        var favorites = snapshot.data ?? [];

        // Filter by category if specified
        if (widget.category != null) {
          favorites =
              favorites.where((f) => f['category'] == widget.category).toList();
        }

        if (favorites.isEmpty) {
          return _buildEmptyState(widget.category);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final favorite = favorites[index];
            final cacheKey = favorite['docId'] ?? favorite['placeId'] ?? '$index';

            return _FavoriteCard(
              key: ValueKey(cacheKey), // Stable key prevents unnecessary rebuilds
              favorite: favorite,
              imageCache: _imageCache,
              onImageLoaded: (url) {
                _imageCache[cacheKey] = url;
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String? category) {
    String message;
    IconData icon;

    switch (category) {
      case 'attraction':
        message = 'No saved attractions yet';
        icon = Icons.photo_camera;
        break;
      case 'food':
        message = 'No saved restaurants yet';
        icon = Icons.restaurant;
        break;
      case 'accommodation':
        message = 'No saved hotels yet';
        icon = Icons.hotel;
        break;
      default:
        message = 'No saved places yet';
        icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the heart icon on places to save them',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual favorite card widget
class _FavoriteCard extends StatefulWidget {
  final Map<String, dynamic> favorite;
  final Map<String, String?> imageCache;
  final Function(String?) onImageLoaded;

  const _FavoriteCard({
    super.key,
    required this.favorite,
    required this.imageCache,
    required this.onImageLoaded,
  });

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard> {
  String? _imageUrl;
  bool _isLoadingImage = true;
  bool _isRemoving = false;

  String get _cacheKey =>
      widget.favorite['docId'] ?? widget.favorite['placeId'] ?? '';

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // Check cache first
    if (widget.imageCache.containsKey(_cacheKey)) {
      setState(() {
        _imageUrl = widget.imageCache[_cacheKey];
        _isLoadingImage = false;
      });
      return;
    }

    try {
      final imageUrl = await PlaceImageController.getPlaceImage(
        placeName: widget.favorite['name'] ?? '',
        placeType: widget.favorite['type'],
        latitude: widget.favorite['latitude'],
        longitude: widget.favorite['longitude'],
      );

      if (mounted) {
        setState(() {
          _imageUrl = imageUrl;
          _isLoadingImage = false;
        });
        widget.onImageLoaded(imageUrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingImage = false);
        widget.onImageLoaded(null);
      }
    }
  }

  Future<void> _removeFavorite() async {
    final placeName = widget.favorite['name'] ?? 'this place';

    // Use SweetAlert for confirmation
    final confirmed = await SweetAlertDialog.confirm(
      context: context,
      title: 'Remove Favorite?',
      subtitle: 'Remove "$placeName" from your favorites?',
      confirmText: 'Remove',
      cancelText: 'Cancel',
    );

    if (confirmed == true && mounted) {
      setState(() => _isRemoving = true);

      try {
        await FavoriteController.removeByDocId(widget.favorite['docId']);

        if (mounted) {
          // Show success SweetAlert
          await SweetAlertDialog.success(
            context: context,
            title: 'Removed!',
            subtitle: '"$placeName" has been removed from your favorites',
            confirmText: 'OK',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isRemoving = false);
          // Show error SweetAlert
          await SweetAlertDialog.error(
            context: context,
            title: 'Error',
            subtitle: 'Failed to remove favorite: ${e.toString()}',
            confirmText: 'OK',
          );
        }
      }
    }
  }

  void _openDirections() async {
    final lat = widget.favorite['latitude'];
    final lon = widget.favorite['longitude'];

    if (lat == null || lon == null) {
      await SweetAlertDialog.warning(
        context: context,
        title: 'No Location',
        subtitle: 'Location coordinates are not available for this place',
        confirmText: 'OK',
      );
      return;
    }

    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        await SweetAlertDialog.error(
          context: context,
          title: 'Error',
          subtitle: 'Could not open maps: $e',
          confirmText: 'OK',
        );
      }
    }
  }

  void _openDetails() {
    // Convert favorite back to place format for detail page
    final place = {
      'name': widget.favorite['name'],
      'name_local': widget.favorite['nameLocal'],
      'type': widget.favorite['type'],
      'category': widget.favorite['category'],
      'latitude': widget.favorite['latitude'],
      'lat': widget.favorite['latitude'],
      'longitude': widget.favorite['longitude'],
      'lon': widget.favorite['longitude'],
      'id': widget.favorite['osmId'],
      'osm_id': widget.favorite['osmId'],
      'osmType': widget.favorite['osmType'],
      'tags': widget.favorite['tags'],
      'distance': widget.favorite['distance'],
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttractionDetailPage(place: place),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.favorite['name'] ?? 'Unknown Place';
    final type = widget.favorite['type'] ?? 'place';
    final category = widget.favorite['category'] ?? 'attraction';
    final address = widget.favorite['address'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: _openDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildImage(),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            IconHelper.getIconForType(type),
                            size: 12,
                            color: _getCategoryColor(category),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatType(type),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _getCategoryColor(category),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Address if available
                    if (address != null && address.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Directions
                  IconButton(
                    onPressed: _openDirections,
                    icon: Icon(
                      Icons.directions,
                      color: Colors.blue[600],
                      size: 22,
                    ),
                    tooltip: 'Get Directions',
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),

                  // Remove
                  _isRemoving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : IconButton(
                    onPressed: _removeFavorite,
                    icon: Icon(
                      Icons.favorite,
                      color: Colors.red[400],
                      size: 22,
                    ),
                    tooltip: 'Remove from favorites',
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_isLoadingImage) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_imageUrl != null) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final type = widget.favorite['type'] ?? 'place';
    final color =
    _getCategoryColor(widget.favorite['category'] ?? 'attraction');

    return Container(
      color: color.withOpacity(0.1),
      child: Center(
        child: Icon(
          IconHelper.getIconForType(type),
          size: 32,
          color: color.withOpacity(0.5),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'food':
        return Colors.orange;
      case 'accommodation':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _formatType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
        ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
        : '')
        .join(' ');
  }
}