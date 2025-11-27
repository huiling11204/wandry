// lib/controller/itinerary_edit_controller.dart
// Handles editing operations for itinerary items

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class ItineraryEditController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Callbacks
  Function(bool isLoading)? onLoadingChanged;
  Function(String message)? onError;
  Function(String message)? onSuccess;
  Function(List<Map<String, dynamic>> alternatives)? onAlternativesLoaded;

  // Overpass servers for fetching nearby attractions
  static const List<String> _overpassServers = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
  ];

  /// Get nearby alternative attractions for replacing an item
  /// Returns attractions within specified radius that are NOT in the current itinerary
  Future<List<Map<String, dynamic>>> getNearbyAlternatives({
    required String tripId,
    required String currentItemId,
    required double lat,
    required double lon,
    required String category,
    int radiusMeters = 3000,
    int limit = 10,
  }) async {
    onLoadingChanged?.call(true);

    try {
      // 1. Get all existing attraction IDs in this trip to exclude them
      final existingItems = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .get();

      final Set<String> existingOsmIds = {};
      final Set<String> existingNames = {};

      for (var doc in existingItems.docs) {
        final data = doc.data();
        // Skip meal items
        if (['breakfast', 'lunch', 'dinner', 'meal'].contains(data['category']?.toString().toLowerCase())) {
          continue;
        }
        if (data['osm_id'] != null) {
          existingOsmIds.add(data['osm_id'].toString());
        }
        if (data['title'] != null) {
          existingNames.add(data['title'].toString().toLowerCase());
        }
      }

      // 2. Fetch nearby attractions from OSM
      final alternatives = await _fetchNearbyAttractions(
        lat: lat,
        lon: lon,
        radiusMeters: radiusMeters,
        category: category,
        excludeOsmIds: existingOsmIds,
        excludeNames: existingNames,
        limit: limit,
      );

      onLoadingChanged?.call(false);
      onAlternativesLoaded?.call(alternatives);
      return alternatives;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to load alternatives: ${e.toString()}');
      return [];
    }
  }

  /// Fetch nearby attractions from OpenStreetMap
  Future<List<Map<String, dynamic>>> _fetchNearbyAttractions({
    required double lat,
    required double lon,
    required int radiusMeters,
    required String category,
    required Set<String> excludeOsmIds,
    required Set<String> excludeNames,
    required int limit,
  }) async {
    // Build query based on category
    String tourismFilter = _getTourismFilter(category);

    final query = '''
[out:json][timeout:15];
(
  node$tourismFilter["name"](around:$radiusMeters,$lat,$lon);
  way$tourismFilter["name"](around:$radiusMeters,$lat,$lon);
);
out center $limit;
''';

    for (var server in _overpassServers) {
      try {
        final response = await http.post(
          Uri.parse(server),
          body: query,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final elements = data['elements'] as List? ?? [];

          List<Map<String, dynamic>> attractions = [];

          for (var el in elements) {
            final osmId = el['id']?.toString() ?? '';
            final tags = el['tags'] as Map<String, dynamic>? ?? {};
            final name = tags['name:en'] ?? tags['name'] ?? '';

            // Skip if already in itinerary
            if (excludeOsmIds.contains(osmId)) continue;
            if (excludeNames.contains(name.toString().toLowerCase())) continue;

            // Skip hotels
            final tourism = tags['tourism']?.toString().toLowerCase() ?? '';
            if (['hotel', 'hostel', 'guest_house', 'motel'].contains(tourism)) continue;

            double? itemLat, itemLon;
            if (el['type'] == 'node') {
              itemLat = el['lat']?.toDouble();
              itemLon = el['lon']?.toDouble();
            } else if (el['center'] != null) {
              itemLat = el['center']['lat']?.toDouble();
              itemLon = el['center']['lon']?.toDouble();
            }

            if (itemLat == null || itemLon == null || name.isEmpty) continue;

            final distance = _calculateDistance(lat, lon, itemLat, itemLon);

            attractions.add({
              'osm_id': osmId,
              'name': name.toString().trim(),
              'name_local': tags['name'],
              'category': _inferCategory(tags),
              'coordinates': {'lat': itemLat, 'lng': itemLon},
              'distance_km': double.parse(distance.toStringAsFixed(2)),
              'travel_time_minutes': ((distance / 25) * 60 + 10).round(),
              'rating': (3.8 + Random().nextDouble() * 1.0),
              'description': tags['description'] ?? 'A popular attraction nearby.',
              'opening_hours': tags['opening_hours'] ?? 'Check on arrival',
              'website': tags['website'] ?? '',
              'tags': tags,
            });
          }

          // Sort by distance
          attractions.sort((a, b) =>
              (a['distance_km'] as double).compareTo(b['distance_km'] as double));

          return attractions.take(limit).toList();
        }
      } catch (e) {
        continue;
      }
    }

    return [];
  }

  String _getTourismFilter(String category) {
    switch (category.toLowerCase()) {
      case 'museum':
        return '["tourism"="museum"]';
      case 'viewpoint':
        return '["tourism"="viewpoint"]';
      case 'park':
      case 'nature':
        return '["leisure"~"park|garden|nature_reserve"]';
      case 'temple':
      case 'cultural':
        return '["amenity"="place_of_worship"]';
      case 'entertainment':
        return '["tourism"~"theme_park|zoo|aquarium"]';
      case 'shopping':
        return '["shop"]';
      default:
        return '["tourism"~"attraction|museum|viewpoint|artwork|gallery"]';
    }
  }

  String _inferCategory(Map<String, dynamic> tags) {
    final tourism = tags['tourism']?.toString() ?? '';
    final leisure = tags['leisure']?.toString() ?? '';
    final amenity = tags['amenity']?.toString() ?? '';

    if (tourism == 'museum') return 'museum';
    if (tourism == 'viewpoint') return 'viewpoint';
    if (leisure.contains('park') || leisure.contains('garden')) return 'park';
    if (amenity == 'place_of_worship') return 'temple';
    if (tags['historic'] != null) return 'cultural';
    return 'attraction';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  /// Replace an attraction with an alternative
  Future<bool> replaceAttraction({
    required String tripId,
    required String itemId,
    required Map<String, dynamic> newAttraction,
    required String city,
  }) async {
    onLoadingChanged?.call(true);

    try {
      // Get the original item to preserve time slots
      final originalDoc = await _firestore
          .collection('itineraryItem')
          .doc(itemId)
          .get();

      if (!originalDoc.exists) {
        throw Exception('Original item not found');
      }

      final originalData = originalDoc.data()!;

      // Build maps link
      final encodedName = Uri.encodeComponent('${newAttraction['name']} $city');
      final mapsLink = 'https://www.google.com/maps/search/?api=1&query=$encodedName';

      // Update the item with new attraction data
      await _firestore.collection('itineraryItem').doc(itemId).update({
        'title': newAttraction['name'],
        'name_local': newAttraction['name_local'],
        'category': newAttraction['category'],
        'description': newAttraction['description'] ?? '',
        'coordinates': newAttraction['coordinates'],
        'osm_id': newAttraction['osm_id'],
        'rating': newAttraction['rating'],
        'distanceKm': newAttraction['distance_km'],
        'estimatedTravelMinutes': newAttraction['travel_time_minutes'],
        'maps_link': mapsLink,
        'maps_link_direct': 'https://www.google.com/maps?q=${newAttraction['coordinates']['lat']},${newAttraction['coordinates']['lng']}',
        'opening_hours': newAttraction['opening_hours'],
        'website': newAttraction['website'],
        'tips': ['Replaced from original itinerary', 'Check opening hours before visiting'],
        'isReplaced': true,
        'replacedAt': FieldValue.serverTimestamp(),
        // Preserve original time slots
        'startTime': originalData['startTime'],
        'endTime': originalData['endTime'],
        'dayNumber': originalData['dayNumber'],
        'orderInDay': originalData['orderInDay'],
      });

      onLoadingChanged?.call(false);
      onSuccess?.call('Attraction replaced successfully!');
      return true;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to replace attraction: ${e.toString()}');
      return false;
    }
  }

  /// Swap two attractions within the same day
  Future<bool> swapAttractions({
    required String tripId,
    required String itemId1,
    required String itemId2,
  }) async {
    onLoadingChanged?.call(true);

    try {
      final doc1 = await _firestore.collection('itineraryItem').doc(itemId1).get();
      final doc2 = await _firestore.collection('itineraryItem').doc(itemId2).get();

      if (!doc1.exists || !doc2.exists) {
        throw Exception('One or both items not found');
      }

      final data1 = doc1.data()!;
      final data2 = doc2.data()!;

      // Verify same day
      if (data1['dayNumber'] != data2['dayNumber']) {
        throw Exception('Can only swap attractions within the same day');
      }

      // Swap time slots and order
      final batch = _firestore.batch();

      batch.update(_firestore.collection('itineraryItem').doc(itemId1), {
        'startTime': data2['startTime'],
        'endTime': data2['endTime'],
        'orderInDay': data2['orderInDay'],
      });

      batch.update(_firestore.collection('itineraryItem').doc(itemId2), {
        'startTime': data1['startTime'],
        'endTime': data1['endTime'],
        'orderInDay': data1['orderInDay'],
      });

      await batch.commit();

      onLoadingChanged?.call(false);
      onSuccess?.call('Attractions swapped successfully!');
      return true;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to swap attractions: ${e.toString()}');
      return false;
    }
  }

  /// Mark an attraction as "skipped" - extends previous activity time instead of deleting
  Future<bool> skipAttraction({
    required String tripId,
    required String itemId,
  }) async {
    onLoadingChanged?.call(true);

    try {
      final doc = await _firestore.collection('itineraryItem').doc(itemId).get();

      if (!doc.exists) {
        throw Exception('Item not found');
      }

      final data = doc.data()!;
      final dayNumber = data['dayNumber'];
      final orderInDay = data['orderInDay'];
      final skippedEndTime = data['endTime'];

      // FIXED: Get all items for this day, then filter in code to avoid needing composite index
      final dayItems = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .where('dayNumber', isEqualTo: dayNumber)
          .get();

      // Find the previous activity (highest orderInDay less than current)
      DocumentSnapshot? previousItem;
      int highestPreviousOrder = -1;

      for (var item in dayItems.docs) {
        final itemData = item.data();
        final itemOrder = itemData['orderInDay'] as int? ?? 0;
        final isSkipped = itemData['isSkipped'] == true;

        // Skip if it's a skipped item or if it's the current item
        if (isSkipped || item.id == itemId) continue;

        if (itemOrder < orderInDay && itemOrder > highestPreviousOrder) {
          highestPreviousOrder = itemOrder;
          previousItem = item;
        }
      }

      final batch = _firestore.batch();

      // Extend previous activity if exists
      if (previousItem != null) {
        batch.update(previousItem.reference, {
          'endTime': skippedEndTime,
          'isExtended': true,
          'extendedNote': 'Time extended due to skipped activity',
        });
      }

      // Mark current item as skipped (soft delete)
      batch.update(_firestore.collection('itineraryItem').doc(itemId), {
        'isSkipped': true,
        'skippedAt': FieldValue.serverTimestamp(),
        'originalData': data, // Preserve for potential undo
      });

      await batch.commit();

      onLoadingChanged?.call(false);
      onSuccess?.call('Activity skipped. Previous activity time extended.');
      return true;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to skip attraction: ${e.toString()}');
      return false;
    }
  }

  /// Undo a skipped attraction
  Future<bool> undoSkip({
    required String tripId,
    required String itemId,
  }) async {
    onLoadingChanged?.call(true);

    try {
      final doc = await _firestore.collection('itineraryItem').doc(itemId).get();

      if (!doc.exists) {
        throw Exception('Item not found');
      }

      final data = doc.data()!;
      final originalData = data['originalData'] as Map<String, dynamic>?;

      if (originalData == null) {
        throw Exception('Original data not found');
      }

      // Restore original item
      await _firestore.collection('itineraryItem').doc(itemId).update({
        'isSkipped': false,
        'skippedAt': FieldValue.delete(),
        'originalData': FieldValue.delete(),
      });

      // FIXED: Get all items for this day, then filter in code to avoid composite index
      final dayItems = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .where('dayNumber', isEqualTo: data['dayNumber'])
          .get();

      // Find the previous extended activity
      DocumentSnapshot? previousExtendedItem;
      int highestPreviousOrder = -1;
      final currentOrder = data['orderInDay'] as int? ?? 0;

      for (var item in dayItems.docs) {
        final itemData = item.data();
        final itemOrder = itemData['orderInDay'] as int? ?? 0;
        final isExtended = itemData['isExtended'] == true;

        if (isExtended && itemOrder < currentOrder && itemOrder > highestPreviousOrder) {
          highestPreviousOrder = itemOrder;
          previousExtendedItem = item;
        }
      }

      if (previousExtendedItem != null) {
        // Calculate original end time (30 min before skipped item start)
        final skippedStart = originalData['startTime'] ?? data['startTime'];
        await previousExtendedItem.reference.update({
          'endTime': _subtractTime(skippedStart, 30),
          'isExtended': false,
          'extendedNote': FieldValue.delete(),
        });
      }

      onLoadingChanged?.call(false);
      onSuccess?.call('Activity restored!');
      return true;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to restore attraction: ${e.toString()}');
      return false;
    }
  }

  String _subtractTime(String time, int minutes) {
    final parts = time.split(':');
    var hours = int.parse(parts[0]);
    var mins = int.parse(parts[1]);

    mins -= minutes;
    while (mins < 0) {
      mins += 60;
      hours -= 1;
    }

    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Extend time at current attraction (take time from next activity)
  /// Adjust time for an attraction (extend or shorten)
  /// Use positive minutes to extend, negative to shorten
  Future<bool> adjustTime({
    required String tripId,
    required String itemId,
    required int minutes, // positive = extend, negative = shorten
  }) async {
    onLoadingChanged?.call(true);

    try {
      final doc = await _firestore.collection('itineraryItem').doc(itemId).get();

      if (!doc.exists) {
        throw Exception('Item not found');
      }

      final data = doc.data()!;
      final dayNumber = data['dayNumber'];
      final orderInDay = data['orderInDay'] as int? ?? 0;
      final currentEndTime = data['endTime'] as String;
      final currentStartTime = data['startTime'] as String;

      // Calculate new end time
      final newEndTime = minutes >= 0
          ? _addTime(currentEndTime, minutes)
          : _subtractTime(currentEndTime, minutes.abs());

      // Validate: end time should be after start time
      if (_timeToMinutes(newEndTime) <= _timeToMinutes(currentStartTime)) {
        onLoadingChanged?.call(false);
        onError?.call('Cannot shorten: activity would have no duration');
        return false;
      }

      // FIXED: Get all items for this day, then filter to avoid composite index
      final dayItems = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .where('dayNumber', isEqualTo: dayNumber)
          .get();

      // Find the next activity (lowest orderInDay greater than current)
      DocumentSnapshot? nextItem;
      int lowestNextOrder = 999999;

      for (var item in dayItems.docs) {
        final itemData = item.data();
        final itemOrder = itemData['orderInDay'] as int? ?? 0;
        final isSkipped = itemData['isSkipped'] == true;

        if (isSkipped || item.id == itemId) continue;

        if (itemOrder > orderInDay && itemOrder < lowestNextOrder) {
          lowestNextOrder = itemOrder;
          nextItem = item;
        }
      }

      final batch = _firestore.batch();

      // Update current item
      batch.update(_firestore.collection('itineraryItem').doc(itemId), {
        'endTime': newEndTime,
        'isExtended': minutes > 0,
        'isShortened': minutes < 0,
        'timeAdjustedMinutes': minutes,
      });

      // Adjust next item start time if exists
      if (nextItem != null) {
        batch.update(nextItem.reference, {
          'startTime': newEndTime,
        });
      }

      await batch.commit();

      onLoadingChanged?.call(false);
      final action = minutes >= 0 ? 'extended' : 'shortened';
      onSuccess?.call('Time $action by ${minutes.abs()} minutes!');
      return true;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to adjust time: ${e.toString()}');
      return false;
    }
  }

  /// Legacy method - calls adjustTime with positive minutes
  Future<bool> extendTime({
    required String tripId,
    required String itemId,
    required int additionalMinutes,
  }) async {
    return adjustTime(
      tripId: tripId,
      itemId: itemId,
      minutes: additionalMinutes,
    );
  }

  /// Shorten time - calls adjustTime with negative minutes
  Future<bool> shortenTime({
    required String tripId,
    required String itemId,
    required int minutesToShorten,
  }) async {
    return adjustTime(
      tripId: tripId,
      itemId: itemId,
      minutes: -minutesToShorten,
    );
  }

  /// Convert time string to minutes for comparison
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _addTime(String time, int minutes) {
    final parts = time.split(':');
    var hours = int.parse(parts[0]);
    var mins = int.parse(parts[1]);

    mins += minutes;
    while (mins >= 60) {
      mins -= 60;
      hours += 1;
    }

    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Add a custom note to an attraction
  Future<bool> addNote({
    required String itemId,
    required String note,
  }) async {
    try {
      await _firestore.collection('itineraryItem').doc(itemId).update({
        'userNote': note,
        'noteAddedAt': FieldValue.serverTimestamp(),
      });
      onSuccess?.call('Note saved!');
      return true;
    } catch (e) {
      onError?.call('Failed to save note');
      return false;
    }
  }

  void dispose() {
    onLoadingChanged = null;
    onError = null;
    onSuccess = null;
    onAlternativesLoaded = null;
  }
}