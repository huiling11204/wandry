// Handles editing operations for itinerary items
// Includes: Replace, Skip, Extend/Shorten time, Add note, REORDER

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // ============================================
  // REORDER FUNCTIONALITY
  // ============================================

  /// Reorder items within a day
  /// Updates orderInDay and recalculates travel times
  Future<bool> reorderItems({
    required String tripId,
    required int dayNumber,
    required List<String> itemIds, // New order of item IDs
  }) async {
    onLoadingChanged?.call(true);

    try {
      // 1. Fetch all items for this day
      final itemDocs = await Future.wait(
        itemIds.map((id) => _firestore.collection('itineraryItem').doc(id).get()),
      );

      // 2. Validate all items exist and belong to this trip/day
      for (int i = 0; i < itemDocs.length; i++) {
        if (!itemDocs[i].exists) {
          throw Exception('Item not found: ${itemIds[i]}');
        }
        final data = itemDocs[i].data()!;
        if (data['tripID'] != tripId || data['dayNumber'] != dayNumber) {
          throw Exception('Item does not belong to this day');
        }
      }

      // 3. Build ordered list of items with their data
      final orderedItems = <Map<String, dynamic>>[];
      for (int i = 0; i < itemDocs.length; i++) {
        final doc = itemDocs[i];
        final data = doc.data()!;
        orderedItems.add({
          'id': doc.id,
          'data': data,
          'newOrder': i,
        });
      }

      // 4. Separate meals from attractions
      // Meals should maintain their original time slots
      final meals = <Map<String, dynamic>>[];
      final attractions = <Map<String, dynamic>>[];

      for (var item in orderedItems) {
        final category = (item['data']['category'] as String? ?? '').toLowerCase();
        if (['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack'].contains(category)) {
          meals.add(item);
        } else {
          attractions.add(item);
        }
      }

      // 5. Calculate new time slots for attractions
      // Find available time windows between meals
      final timeWindows = _calculateTimeWindows(meals, orderedItems);

      // 6. Assign new times to attractions based on new order
      final batch = _firestore.batch();

      int attractionIndex = 0;
      for (int i = 0; i < orderedItems.length; i++) {
        final item = orderedItems[i];
        final docRef = _firestore.collection('itineraryItem').doc(item['id']);
        final category = (item['data']['category'] as String? ?? '').toLowerCase();

        if (['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack'].contains(category)) {
          // Meals keep their original times, just update order
          batch.update(docRef, {
            'orderInDay': i,
            'lastModified': FieldValue.serverTimestamp(),
          });
        } else {
          // Attractions get new times based on position
          final newTimes = _assignAttractionTime(
            attractionIndex,
            attractions.length,
            timeWindows,
            item['data'],
          );

          batch.update(docRef, {
            'orderInDay': i,
            'startTime': newTimes['startTime'],
            'endTime': newTimes['endTime'],
            'isReordered': true,
            'reorderedAt': FieldValue.serverTimestamp(),
            'lastModified': FieldValue.serverTimestamp(),
          });

          attractionIndex++;
        }
      }

      // 7. Recalculate distances for all items
      await _recalculateTravelTimes(tripId, dayNumber, orderedItems, batch);

      // 8. Commit all changes
      await batch.commit();

      onLoadingChanged?.call(false);
      onSuccess?.call('Itinerary reordered successfully!');
      return true;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to reorder: ${e.toString()}');
      return false;
    }
  }

  /// Calculate available time windows between meals
  List<Map<String, String>> _calculateTimeWindows(
      List<Map<String, dynamic>> meals,
      List<Map<String, dynamic>> allItems,
      ) {
    // Default time windows if no meals found
    if (meals.isEmpty) {
      return [
        {'start': '09:00', 'end': '12:00'},
        {'start': '14:00', 'end': '18:00'},
      ];
    }

    final windows = <Map<String, String>>[];

    // Sort meals by their original order
    meals.sort((a, b) {
      final aTime = a['data']['startTime'] as String? ?? '00:00';
      final bTime = b['data']['startTime'] as String? ?? '00:00';
      return _timeToMinutes(aTime).compareTo(_timeToMinutes(bTime));
    });

    // Morning window: 09:00 to first meal
    final firstMealStart = meals.first['data']['startTime'] as String? ?? '12:00';
    if (_timeToMinutes(firstMealStart) > _timeToMinutes('09:00')) {
      windows.add({
        'start': '09:00',
        'end': _subtractTime(firstMealStart, 15), // 15 min buffer before meal
      });
    }

    // Windows between meals
    for (int i = 0; i < meals.length - 1; i++) {
      final currentMealEnd = meals[i]['data']['endTime'] as String? ?? '12:00';
      final nextMealStart = meals[i + 1]['data']['startTime'] as String? ?? '18:00';

      final windowStart = _addTime(currentMealEnd, 15); // 15 min after meal
      final windowEnd = _subtractTime(nextMealStart, 15); // 15 min before next meal

      if (_timeToMinutes(windowEnd) > _timeToMinutes(windowStart) + 30) {
        windows.add({'start': windowStart, 'end': windowEnd});
      }
    }

    // Evening window: after last meal to 20:00
    final lastMealEnd = meals.last['data']['endTime'] as String? ?? '14:00';
    if (_timeToMinutes('20:00') > _timeToMinutes(lastMealEnd)) {
      windows.add({
        'start': _addTime(lastMealEnd, 15),
        'end': '20:00',
      });
    }

    return windows;
  }

  /// Assign time to an attraction based on its position
  Map<String, String> _assignAttractionTime(
      int attractionIndex,
      int totalAttractions,
      List<Map<String, String>> timeWindows,
      Map<String, dynamic> itemData,
      ) {
    final duration = (itemData['durationMinutes'] as int?) ?? 60;

    if (timeWindows.isEmpty) {
      // Fallback: distribute evenly from 09:00 to 18:00
      final startMinutes = 9 * 60 + (attractionIndex * (9 * 60) ~/ totalAttractions);
      return {
        'startTime': _minutesToTime(startMinutes),
        'endTime': _minutesToTime(startMinutes + duration),
      };
    }

    // Calculate total available time
    int totalAvailableMinutes = 0;
    for (var window in timeWindows) {
      totalAvailableMinutes += _timeToMinutes(window['end']!) - _timeToMinutes(window['start']!);
    }

    // Calculate where this attraction should go
    final targetPosition = (attractionIndex * totalAvailableMinutes) ~/ totalAttractions;

    // Find which window and position within window
    int accumulatedMinutes = 0;
    for (var window in timeWindows) {
      final windowDuration = _timeToMinutes(window['end']!) - _timeToMinutes(window['start']!);

      if (accumulatedMinutes + windowDuration > targetPosition) {
        // This attraction goes in this window
        final positionInWindow = targetPosition - accumulatedMinutes;
        final startMinutes = _timeToMinutes(window['start']!) + positionInWindow;

        // Ensure we don't exceed window
        final maxStart = _timeToMinutes(window['end']!) - duration;
        final actualStart = min(startMinutes, maxStart).toInt();
        final windowStart = _timeToMinutes(window['start']!);

        return {
          'startTime': _minutesToTime(max(actualStart, windowStart).toInt()),
          'endTime': _minutesToTime(max(actualStart, windowStart).toInt() + duration),
        };
      }

      accumulatedMinutes += windowDuration;
    }

    // Fallback: use last window
    final lastWindow = timeWindows.last;
    return {
      'startTime': lastWindow['start']!,
      'endTime': _minutesToTime(_timeToMinutes(lastWindow['start']!) + duration),
    };
  }

  /// Recalculate travel times based on new order
  Future<void> _recalculateTravelTimes(
      String tripId,
      int dayNumber,
      List<Map<String, dynamic>> orderedItems,
      WriteBatch batch,
      ) async {
    // Get accommodation for starting point
    Map<String, double>? startCoords;
    try {
      final accDoc = await _firestore.collection('accommodation').doc(tripId).get();
      if (accDoc.exists) {
        final accData = accDoc.data();
        if (accData != null && accData['recommendedAccommodation'] != null) {
          final hotelCoords = accData['recommendedAccommodation']['coordinates'] as Map<String, dynamic>?;
          if (hotelCoords != null) {
            startCoords = {
              'lat': (hotelCoords['lat'] ?? hotelCoords['latitude'] ?? 0).toDouble(),
              'lng': (hotelCoords['lng'] ?? hotelCoords['longitude'] ?? 0).toDouble(),
            };
          }
        }
      }
    } catch (e) {
      // Ignore accommodation errors
    }

    double prevLat = startCoords?['lat'] ?? 0;
    double prevLng = startCoords?['lng'] ?? 0;

    for (int i = 0; i < orderedItems.length; i++) {
      final item = orderedItems[i];
      final coords = item['data']['coordinates'] as Map<String, dynamic>?;

      if (coords != null) {
        final lat = (coords['lat'] ?? 0).toDouble();
        final lng = (coords['lng'] ?? 0).toDouble();

        if (prevLat != 0 && prevLng != 0 && lat != 0 && lng != 0) {
          final distance = _calculateDistance(prevLat, prevLng, lat, lng);
          final travelMinutes = ((distance / 25) * 60 + 10).round();

          final docRef = _firestore.collection('itineraryItem').doc(item['id']);
          batch.update(docRef, {
            'distanceKm': double.parse(distance.toStringAsFixed(2)),
            'estimatedTravelMinutes': travelMinutes,
          });
        }

        prevLat = lat;
        prevLng = lng;
      }
    }
  }

  /// Get nearby alternative attractions for replacing an item
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

            if (excludeOsmIds.contains(osmId)) continue;
            if (excludeNames.contains(name.toString().toLowerCase())) continue;

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
      final originalDoc = await _firestore
          .collection('itineraryItem')
          .doc(itemId)
          .get();

      if (!originalDoc.exists) {
        throw Exception('Original item not found');
      }

      final originalData = originalDoc.data()!;

      final encodedName = Uri.encodeComponent('${newAttraction['name']} $city');
      final mapsLink = 'https://www.google.com/maps/search/?api=1&query=$encodedName';

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

      if (data1['dayNumber'] != data2['dayNumber']) {
        throw Exception('Can only swap attractions within the same day');
      }

      final batch = _firestore.batch();

      batch.update(_firestore.collection('itineraryItem').doc(itemId1), {
        'startTime': data2['startTime'],
        'endTime': data2['endTime'],
        'orderInDay': data2['orderInDay'],
        'isReordered': true,
        'reorderedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_firestore.collection('itineraryItem').doc(itemId2), {
        'startTime': data1['startTime'],
        'endTime': data1['endTime'],
        'orderInDay': data1['orderInDay'],
        'isReordered': true,
        'reorderedAt': FieldValue.serverTimestamp(),
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

  /// Mark an attraction as "skipped"
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

      final dayItems = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .where('dayNumber', isEqualTo: dayNumber)
          .get();

      DocumentSnapshot? previousItem;
      int highestPreviousOrder = -1;

      for (var item in dayItems.docs) {
        final itemData = item.data();
        final itemOrder = itemData['orderInDay'] as int? ?? 0;
        final isSkipped = itemData['isSkipped'] == true;

        if (isSkipped || item.id == itemId) continue;

        if (itemOrder < orderInDay && itemOrder > highestPreviousOrder) {
          highestPreviousOrder = itemOrder;
          previousItem = item;
        }
      }

      final batch = _firestore.batch();

      if (previousItem != null) {
        batch.update(previousItem.reference, {
          'endTime': skippedEndTime,
          'isExtended': true,
          'extendedNote': 'Time extended due to skipped activity',
        });
      }

      batch.update(_firestore.collection('itineraryItem').doc(itemId), {
        'isSkipped': true,
        'skippedAt': FieldValue.serverTimestamp(),
        'originalData': data,
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

      await _firestore.collection('itineraryItem').doc(itemId).update({
        'isSkipped': false,
        'skippedAt': FieldValue.delete(),
        'originalData': FieldValue.delete(),
      });

      final dayItems = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .where('dayNumber', isEqualTo: data['dayNumber'])
          .get();

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

  /// Adjust time for an attraction (extend or shorten)
  Future<bool> adjustTime({
    required String tripId,
    required String itemId,
    required int minutes,
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

      final newEndTime = minutes >= 0
          ? _addTime(currentEndTime, minutes)
          : _subtractTime(currentEndTime, minutes.abs());

      if (_timeToMinutes(newEndTime) <= _timeToMinutes(currentStartTime)) {
        onLoadingChanged?.call(false);
        onError?.call('Cannot shorten: activity would have no duration');
        return false;
      }

      final dayItems = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .where('dayNumber', isEqualTo: dayNumber)
          .get();

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

      batch.update(_firestore.collection('itineraryItem').doc(itemId), {
        'endTime': newEndTime,
        'isExtended': minutes > 0,
        'isShortened': minutes < 0,
        'timeAdjustedMinutes': minutes,
      });

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

  // ============================================
  // HELPER METHODS
  // ============================================

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _minutesToTime(int minutes) {
    final hours = (minutes ~/ 60) % 24;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
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

  void dispose() {
    onLoadingChanged = null;
    onError = null;
    onSuccess = null;
    onAlternativesLoaded = null;
  }
}