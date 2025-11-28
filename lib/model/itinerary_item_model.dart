// lib/model/itinerary_item_model.dart
// COMPLETE VERSION: Added reorder tracking fields

import 'package:cloud_firestore/cloud_firestore.dart';

class ItineraryItemModel {
  final String id;
  final String tripId;
  final int dayNumber;
  final int orderInDay;
  final String title;
  final String category;
  final String startTime;
  final String endTime;
  final double? estimatedCostMYR;
  final double? estimatedCostLocal;
  final String? currencyDisplay;
  final String? localCurrency;
  final String? description;
  final Map<String, dynamic>? coordinates;
  final List<dynamic>? restaurantOptions;
  final Map<String, dynamic>? weather;
  final bool? isHalalCertified;
  final bool? isOutdoor;
  final double? rating;
  final String? website;
  final bool? hasWebsite;
  final List<dynamic>? highlights;
  final String? openingHours;
  final String? bestTimeToVisit;
  final String? accessibility;
  final String? nearbyTransit;
  final List<dynamic>? facilities;
  final List<dynamic>? tips;

  // Duration & Navigation fields
  final int? durationMinutes;
  final String? nameLocal;
  final double? distanceKm;
  final int? estimatedTravelMinutes;
  final bool? isPreferred;
  final double? preferenceScore;
  final String? mapsLink;
  final String? mapsLinkDirect;
  final String? dataAvailability;

  // Edit tracking fields
  final bool? isReplaced;
  final DateTime? replacedAt;
  final bool? isSkipped;
  final DateTime? skippedAt;
  final bool? isExtended;
  final bool? isShortened;
  final int? timeAdjustedMinutes;
  final String? extendedNote;
  final String? userNote;
  final DateTime? noteAddedAt;

  // REORDER tracking fields (NEW)
  final bool? isReordered;
  final DateTime? reorderedAt;
  final int? originalOrderInDay;
  final String? originalStartTime;
  final String? originalEndTime;

  ItineraryItemModel({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.orderInDay,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    this.estimatedCostMYR,
    this.estimatedCostLocal,
    this.currencyDisplay,
    this.localCurrency,
    this.description,
    this.coordinates,
    this.restaurantOptions,
    this.weather,
    this.isHalalCertified,
    this.isOutdoor,
    this.rating,
    this.website,
    this.hasWebsite,
    this.highlights,
    this.openingHours,
    this.bestTimeToVisit,
    this.accessibility,
    this.nearbyTransit,
    this.facilities,
    this.tips,
    this.durationMinutes,
    this.nameLocal,
    this.distanceKm,
    this.estimatedTravelMinutes,
    this.isPreferred,
    this.preferenceScore,
    this.mapsLink,
    this.mapsLinkDirect,
    this.dataAvailability,
    // Edit tracking
    this.isReplaced,
    this.replacedAt,
    this.isSkipped,
    this.skippedAt,
    this.isExtended,
    this.isShortened,
    this.timeAdjustedMinutes,
    this.extendedNote,
    this.userNote,
    this.noteAddedAt,
    // Reorder tracking (NEW)
    this.isReordered,
    this.reorderedAt,
    this.originalOrderInDay,
    this.originalStartTime,
    this.originalEndTime,
  });

  factory ItineraryItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItineraryItemModel(
      id: doc.id,
      tripId: data['tripID'] ?? '',
      dayNumber: data['dayNumber'] ?? 0,
      orderInDay: data['orderInDay'] ?? 0,
      title: data['title'] ?? 'Activity',
      category: data['category'] ?? 'attraction',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      estimatedCostMYR: data['estimatedCostMYR']?.toDouble(),
      estimatedCostLocal: data['estimatedCostLocal']?.toDouble(),
      currencyDisplay: data['currencyDisplay'],
      localCurrency: data['localCurrency'],
      description: data['description'],
      coordinates: data['coordinates'],
      restaurantOptions: data['restaurantOptions'],
      weather: data['weather'],
      isHalalCertified: data['isHalalCertified'],
      isOutdoor: data['isOutdoor'],
      rating: data['rating']?.toDouble(),
      website: data['website'],
      hasWebsite: data['has_website'],
      highlights: data['highlights'],
      openingHours: data['openingHours'],
      bestTimeToVisit: data['bestTimeToVisit'],
      accessibility: data['accessibility'],
      nearbyTransit: data['nearbyTransit'],
      facilities: data['facilities'],
      tips: data['tips'],
      durationMinutes: data['durationMinutes'],
      nameLocal: data['name_local'],
      distanceKm: data['distanceKm']?.toDouble(),
      estimatedTravelMinutes: data['estimatedTravelMinutes'],
      isPreferred: data['is_preferred'] ?? data['isPreferred'],
      preferenceScore: data['preferenceScore']?.toDouble(),
      mapsLink: data['maps_link'],
      mapsLinkDirect: data['maps_link_direct'],
      dataAvailability: data['dataAvailability'],
      // Edit tracking
      isReplaced: data['isReplaced'],
      replacedAt: _parseDateTime(data['replacedAt']),
      isSkipped: data['isSkipped'],
      skippedAt: _parseDateTime(data['skippedAt']),
      isExtended: data['isExtended'],
      isShortened: data['isShortened'],
      timeAdjustedMinutes: data['timeAdjustedMinutes'],
      extendedNote: data['extendedNote'],
      userNote: data['userNote'],
      noteAddedAt: _parseDateTime(data['noteAddedAt']),
      // Reorder tracking (NEW)
      isReordered: data['isReordered'],
      reorderedAt: _parseDateTime(data['reorderedAt']),
      originalOrderInDay: data['originalOrderInDay'],
      originalStartTime: data['originalStartTime'],
      originalEndTime: data['originalEndTime'],
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Check if this is a meal item
  bool get isMeal => ['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack'].contains(category.toLowerCase());

  /// Check if this item has restaurant options
  bool get hasRestaurants => restaurantOptions != null && restaurantOptions!.isNotEmpty;

  /// Check if this item has been modified (any edit)
  bool get hasBeenModified => isReplaced == true || isReordered == true || isExtended == true || isShortened == true;

  /// Check if this item can be reordered (not a meal)
  bool get canBeReordered => !isMeal;

  /// Get formatted duration string (e.g., "45 min", "1.5 hrs")
  String get durationDisplay {
    if (durationMinutes == null) {
      // Calculate from start/end time
      try {
        final startParts = startTime.split(':');
        final endParts = endTime.split(':');
        final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        final diff = endMinutes - startMinutes;

        if (diff >= 60) {
          final hours = diff / 60;
          return '${hours.toStringAsFixed(hours == hours.roundToDouble() ? 0 : 1)} hr${hours > 1 ? 's' : ''}';
        }
        return '$diff min';
      } catch (e) {
        return '';
      }
    }

    if (durationMinutes! >= 60) {
      final hours = durationMinutes! / 60;
      return '${hours.toStringAsFixed(hours == hours.roundToDouble() ? 0 : 1)} hr${hours > 1 ? 's' : ''}';
    }
    return '$durationMinutes min';
  }

  /// Check if this is a quick visit (under 45 min)
  bool get isQuickVisit => (durationMinutes ?? 60) < 45;

  /// Get category-appropriate icon suggestion
  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'temple':
        return '⛩️';
      case 'museum':
        return '🏛️';
      case 'viewpoint':
        return '🌄';
      case 'park':
        return '🌳';
      case 'nature':
        return '🏞️';
      case 'cultural':
        return '🎭';
      case 'shopping':
        return '🛍️';
      case 'entertainment':
        return '🎢';
      case 'breakfast':
        return '🍳';
      case 'lunch':
        return '🍽️';
      case 'dinner':
        return '🍲';
      case 'cafe':
      case 'snack':
        return '☕';
      default:
        return '📍';
    }
  }

  /// Get a summary of modifications made to this item
  String get modificationSummary {
    final List<String> mods = [];

    if (isReordered == true) mods.add('Reordered');
    if (isReplaced == true) mods.add('Replaced');
    if (isExtended == true) mods.add('Extended');
    if (isShortened == true) mods.add('Shortened');
    if (userNote != null && userNote!.isNotEmpty) mods.add('Has note');

    return mods.isEmpty ? 'Original' : mods.join(', ');
  }

  /// Convert to Map for Firestore updates
  Map<String, dynamic> toUpdateMap() {
    return {
      'dayNumber': dayNumber,
      'orderInDay': orderInDay,
      'title': title,
      'category': category,
      'startTime': startTime,
      'endTime': endTime,
      'estimatedCostMYR': estimatedCostMYR,
      'description': description,
      'coordinates': coordinates,
      'rating': rating,
      'tips': tips,
      'isReplaced': isReplaced,
      'isReordered': isReordered,
      'isExtended': isExtended,
      'isShortened': isShortened,
      'userNote': userNote,
    };
  }
}

/// Extension to help with list operations
extension ItineraryItemListExtension on List<ItineraryItemModel> {
  /// Get items for a specific day
  List<ItineraryItemModel> forDay(int dayNumber) {
    return where((item) => item.dayNumber == dayNumber).toList()
      ..sort((a, b) => a.orderInDay.compareTo(b.orderInDay));
  }

  /// Get only non-skipped items
  List<ItineraryItemModel> get active {
    return where((item) => item.isSkipped != true).toList();
  }

  /// Get only skipped items
  List<ItineraryItemModel> get skipped {
    return where((item) => item.isSkipped == true).toList();
  }

  /// Get only meal items
  List<ItineraryItemModel> get meals {
    return where((item) => item.isMeal).toList();
  }

  /// Get only attraction items (non-meals)
  List<ItineraryItemModel> get attractions {
    return where((item) => !item.isMeal).toList();
  }

  /// Get items that have been modified
  List<ItineraryItemModel> get modified {
    return where((item) => item.hasBeenModified).toList();
  }

  /// Get total estimated cost in MYR
  double get totalCostMYR {
    return fold(0.0, (sum, item) => sum + (item.estimatedCostMYR ?? 0));
  }

  /// Get all unique days
  List<int> get uniqueDays {
    return map((item) => item.dayNumber).toSet().toList()..sort();
  }
}