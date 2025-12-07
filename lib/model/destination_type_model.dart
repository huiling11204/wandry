import 'package:flutter/material.dart';

class DestinationType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const DestinationType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  // All available destination types
  static const List<DestinationType> allTypes = [
    DestinationType(
      id: 'relaxing',
      name: 'Relaxing',
      description: 'Parks, beaches, spas, scenic spots',
      icon: Icons.spa,
      color: Colors.cyan,
    ),
    DestinationType(
      id: 'historical',
      name: 'Historical & Cultural',
      description: 'Museums, monuments, heritage sites',
      icon: Icons.account_balance,
      color: Colors.brown,
    ),
    DestinationType(
      id: 'adventure',
      name: 'Adventure & Outdoors',
      description: 'Hiking, sports, nature activities',
      icon: Icons.terrain,
      color: Colors.orange,
    ),
    DestinationType(
      id: 'shopping',
      name: 'Shopping & Lifestyle',
      description: 'Malls, markets, boutiques',
      icon: Icons.shopping_bag,
      color: Colors.pink,
    ),
    DestinationType(
      id: 'spiritual',
      name: 'Religious & Spiritual',
      description: 'Temples, churches, mosques',
      icon: Icons.temple_buddhist,
      color: Colors.purple,
    ),
    DestinationType(
      id: 'entertainment',
      name: 'Entertainment & Fun',
      description: 'Theme parks, shows, nightlife',
      icon: Icons.attractions,
      color: Colors.red,
    ),
  ];

  /// Get a DestinationType by its ID - returns null if not found
  static DestinationType? getById(String id) {
    try {
      return allTypes.firstWhere((type) => type.id == id.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // Helper methods for edit feature & backend
  // ============================================

  /// Backend category mapping for each destination type
  static const Map<String, List<String>> _backendCategories = {
    'relaxing': ['park', 'nature', 'viewpoint', 'beach'],
    'historical': ['museum', 'cultural', 'temple', 'historic'],
    'adventure': ['nature', 'entertainment', 'viewpoint', 'outdoor'],
    'shopping': ['shopping', 'attraction', 'market'],
    'spiritual': ['temple', 'cultural', 'religious'],
    'entertainment': ['entertainment', 'attraction', 'theme_park'],
  };

  /// Get backend categories for a list of type IDs
  /// Used when sending preferences to the trip generation backend
  static List<String> getBackendCategories(List<String> typeIds) {
    final Set<String> categories = {};
    for (final id in typeIds) {
      final backendCats = _backendCategories[id.toLowerCase()];
      if (backendCats != null) {
        categories.addAll(backendCats);
      }
    }
    return categories.toList();
  }

  /// Get category weights for backend scoring
  /// Higher weight = more preferred in itinerary generation
  static Map<String, double> getCategoryWeights(List<String> typeIds) {
    final Map<String, double> weights = {};

    for (final id in typeIds) {
      final backendCats = _backendCategories[id.toLowerCase()];
      if (backendCats != null) {
        for (final category in backendCats) {
          weights[category] = (weights[category] ?? 0) + 1.0;
        }
      }
    }

    // Normalize weights to 0-1 range
    if (weights.isNotEmpty) {
      final maxWeight = weights.values.reduce((a, b) => a > b ? a : b);
      weights.forEach((key, value) {
        weights[key] = value / maxWeight;
      });
    }

    // Add default weights for unlisted categories (lower priority)
    const defaultCategories = [
      'museum', 'entertainment', 'viewpoint', 'park', 'nature',
      'cultural', 'temple', 'shopping', 'attraction', 'historic',
      'beach', 'outdoor', 'market', 'religious', 'theme_park'
    ];
    for (final cat in defaultCategories) {
      weights.putIfAbsent(cat, () => 0.3);
    }

    return weights;
  }

  /// Check if a category matches user preferences
  static bool isCategoryPreferred(String category, List<String> selectedTypeIds) {
    final preferredCategories = getBackendCategories(selectedTypeIds);
    return preferredCategories.contains(category.toLowerCase());
  }

  /// Get emoji for a type ID (for display purposes)
  static String getEmoji(String typeId) {
    const emojis = {
      'relaxing': '🏖️',
      'historical': '🏛️',
      'adventure': '🎢',
      'shopping': '🛍️',
      'spiritual': '⛩️',
      'entertainment': '🎭',
    };
    return emojis[typeId.toLowerCase()] ?? '📍';
  }

  /// Get display info for a type ID (emoji + label)
  static String getDisplayLabel(String typeId) {
    final type = getById(typeId);
    if (type == null) return typeId;
    return '${getEmoji(typeId)} ${type.name}';
  }

  /// Get color for a type ID
  static Color getColor(String typeId) {
    final type = getById(typeId);
    return type?.color ?? Colors.grey;
  }

  /// Get icon for a type ID
  static IconData getIcon(String typeId) {
    final type = getById(typeId);
    return type?.icon ?? Icons.place;
  }

  /// Validate type IDs - returns only valid ones
  static List<String> validateTypeIds(List<String> typeIds) {
    return typeIds.where((id) => getById(id) != null).toList();
  }

  /// Get default type IDs if none selected
  static List<String> getDefaults() {
    return ['relaxing'];
  }

  /// Get all type IDs
  static List<String> getAllTypeIds() {
    return allTypes.map((t) => t.id).toList();
  }

  /// Get display data for all types (for UI building)
  static List<Map<String, dynamic>> getAllTypesDisplayData() {
    return allTypes.map((type) => {
      'id': type.id,
      'name': type.name,
      'description': type.description,
      'icon': type.icon,
      'color': type.color,
      'emoji': getEmoji(type.id),
    }).toList();
  }

  /// Calculate preference score for an attraction
  /// based on its category and user's selected types
  static double calculatePreferenceScore(
      String attractionCategory,
      List<String> selectedTypeIds,
      double baseRating,
      ) {
    final weights = getCategoryWeights(selectedTypeIds);
    final categoryWeight = weights[attractionCategory.toLowerCase()] ?? 0.3;

    // Combine weight with rating (rating normalized to 0-1)
    final normalizedRating = (baseRating / 5.0).clamp(0.0, 1.0);
    return categoryWeight * 0.6 + normalizedRating * 0.4;
  }
}