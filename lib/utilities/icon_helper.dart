import 'package:flutter/material.dart';

class IconHelper {

  /// Get color for itinerary categories
  static Color getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'breakfast':
      case 'lunch':
      case 'dinner':
      case 'meal':
        return Colors.orange;
      case 'museum':
        return Colors.brown;
      case 'park':
      case 'nature':
        return Colors.green;
      case 'shopping':
        return Colors.pink;
      case 'entertainment':
        return Colors.deepPurple;
      case 'temple':
      case 'cultural':
        return Colors.indigo;
      case 'beach':
        return Colors.cyan;
      default:
        return const Color(0xFF2196F3);
    }
  }

  /// Get icon for itinerary categories
  static IconData getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
      case 'dinner':
      case 'restaurant':
      case 'meal':
        return Icons.restaurant;
      case 'hotel':
      case 'accommodation':
        return Icons.hotel;
      case 'shopping':
        return Icons.shopping_bag;
      case 'beach':
      case 'nature':
        return Icons.beach_access;
      case 'museum':
      case 'cultural':
        return Icons.museum;
      case 'entertainment':
        return Icons.movie;
      case 'park':
        return Icons.park;
      case 'temple':
        return Icons.temple_buddhist;
      default:
        return Icons.place;
    }
  }

  /// Get weather icon from description
  static IconData getWeatherIcon(String description) {
    description = description.toLowerCase();
    if (description.contains('rain')) return Icons.umbrella;
    if (description.contains('cloud')) return Icons.cloud;
    if (description.contains('sun') || description.contains('clear')) {
      return Icons.wb_sunny;
    }
    if (description.contains('snow')) return Icons.ac_unit;
    return Icons.wb_cloudy;
  }

  /// Get icon for OpenStreetMap place types (for attraction/search results)
  static IconData getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'attraction':
      case 'viewpoint':
        return Icons.location_on;
      case 'museum':
      case 'gallery':
        return Icons.museum;
      case 'artwork':
        return Icons.palette;
      case 'theme_park':
      case 'zoo':
        return Icons.park;
      case 'restaurant':
        return Icons.restaurant_menu;
      case 'cafe':
        return Icons.local_cafe;
      case 'fast_food':
        return Icons.fastfood;
      case 'bar':
      case 'pub':
        return Icons.local_bar;
      case 'hotel':
      case 'hostel':
      case 'motel':
        return Icons.hotel;
      case 'guest_house':
      case 'apartment':
        return Icons.home;
      default:
        return Icons.place;
    }
  }

  /// Get icon for search categories (used in PlaceDetailPage nearby search)
  static IconData getSearchCategoryIcon(String category) {
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
}