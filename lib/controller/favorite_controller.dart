import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Controller for managing user's favorite places
/// Similar to Google Maps "Saved" feature
class FavoriteController {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection name for favorites
  static const String _collectionName = 'favorites';

  /// Get current user's Firebase UID
  static String? get _currentUserUid => _auth.currentUser?.uid;

  /// Check if user is logged in
  static bool get isLoggedIn => _currentUserUid != null;

  // ==========================================
  // ADD TO FAVORITES
  // ==========================================
  /// Add a place to user's favorites
  /// Returns the document ID if successful, null if failed
  static Future<String?> addToFavorites(Map<String, dynamic> place) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to save favorites');
    }

    try {
      final userUid = _currentUserUid!;

      // Create a unique place ID based on coordinates or OSM ID
      final placeId = _generatePlaceId(place);

      // Check if already favorited
      final existing = await _firestore
          .collection(_collectionName)
          .where('firebaseUid', isEqualTo: userUid)
          .where('placeId', isEqualTo: placeId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        print('⚠️ Place already in favorites');
        return existing.docs.first.id;
      }

      // Extract place data
      final favoriteData = {
        'firebaseUid': userUid,
        'placeId': placeId,
        'name': place['name'] ?? 'Unknown Place',
        'nameLocal': place['name_local'],
        'type': place['type'] ?? place['category'] ?? 'place',
        'category': place['category'] ?? _inferCategory(place),
        'latitude': place['latitude'] ?? place['lat'],
        'longitude': place['longitude'] ?? place['lon'],
        'distance': place['distance'],
        'address': _extractAddress(place),
        'tags': place['tags'],
        'osmId': place['id']?.toString() ?? place['osm_id']?.toString(),
        'osmType': place['osmType'],
        'savedAt': FieldValue.serverTimestamp(),
      };

      // Add to Firestore
      final docRef = await _firestore.collection(_collectionName).add(favoriteData);

      print('✅ Added to favorites: ${place['name']}');
      return docRef.id;

    } catch (e) {
      print('❌ Error adding to favorites: $e');
      rethrow;
    }
  }

  // ==========================================
  // REMOVE FROM FAVORITES
  // ==========================================
  /// Remove a place from user's favorites
  static Future<bool> removeFromFavorites(Map<String, dynamic> place) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to manage favorites');
    }

    try {
      final userUid = _currentUserUid!;
      final placeId = _generatePlaceId(place);

      // Find and delete the favorite
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('firebaseUid', isEqualTo: userUid)
          .where('placeId', isEqualTo: placeId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('⚠️ Place not found in favorites');
        return false;
      }

      // Delete all matching documents (should be just one)
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      print('✅ Removed from favorites: ${place['name']}');
      return true;

    } catch (e) {
      print('❌ Error removing from favorites: $e');
      rethrow;
    }
  }

  // ==========================================
  // REMOVE BY DOCUMENT ID
  // ==========================================
  /// Remove a favorite by its Firestore document ID
  static Future<bool> removeByDocId(String docId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to manage favorites');
    }

    try {
      await _firestore.collection(_collectionName).doc(docId).delete();
      print('✅ Removed favorite by doc ID: $docId');
      return true;
    } catch (e) {
      print('❌ Error removing favorite: $e');
      rethrow;
    }
  }

  // ==========================================
  // CHECK IF FAVORITED
  // ==========================================
  /// Check if a place is in user's favorites
  static Future<bool> isFavorite(Map<String, dynamic> place) async {
    if (!isLoggedIn) return false;

    try {
      final userUid = _currentUserUid!;
      final placeId = _generatePlaceId(place);

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('firebaseUid', isEqualTo: userUid)
          .where('placeId', isEqualTo: placeId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;

    } catch (e) {
      print('❌ Error checking favorite status: $e');
      return false;
    }
  }

  // ==========================================
  // TOGGLE FAVORITE
  // ==========================================
  /// Toggle favorite status - returns true if now favorited, false if removed
  static Future<bool> toggleFavorite(Map<String, dynamic> place) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to manage favorites');
    }

    final isFav = await isFavorite(place);

    if (isFav) {
      await removeFromFavorites(place);
      return false;
    } else {
      await addToFavorites(place);
      return true;
    }
  }

  // ==========================================
  // GET ALL FAVORITES
  // ==========================================
  /// Get all user's favorites
  static Future<List<Map<String, dynamic>>> getAllFavorites() async {
    if (!isLoggedIn) return [];

    try {
      final userUid = _currentUserUid!;

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('firebaseUid', isEqualTo: userUid)
          .orderBy('savedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id; // Include document ID for deletion
        return data;
      }).toList();

    } catch (e) {
      print('❌ Error getting favorites: $e');
      return [];
    }
  }

  // ==========================================
  // GET FAVORITES BY CATEGORY
  // ==========================================
  /// Get favorites filtered by category (attraction, food, accommodation)
  static Future<List<Map<String, dynamic>>> getFavoritesByCategory(String category) async {
    if (!isLoggedIn) return [];

    try {
      final userUid = _currentUserUid!;

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('firebaseUid', isEqualTo: userUid)
          .where('category', isEqualTo: category)
          .orderBy('savedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

    } catch (e) {
      print('❌ Error getting favorites by category: $e');
      return [];
    }
  }

  // ==========================================
  // GET FAVORITES COUNT
  // ==========================================
  /// Get total count of user's favorites
  static Future<int> getFavoritesCount() async {
    if (!isLoggedIn) return 0;

    try {
      final userUid = _currentUserUid!;

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('firebaseUid', isEqualTo: userUid)
          .count()
          .get();

      return querySnapshot.count ?? 0;

    } catch (e) {
      print('❌ Error getting favorites count: $e');
      return 0;
    }
  }

  // ==========================================
  // STREAM FAVORITES (Real-time updates)
  // ==========================================
  /// Stream of user's favorites for real-time updates
  static Stream<List<Map<String, dynamic>>> streamFavorites() {
    if (!isLoggedIn) return Stream.value([]);

    final userUid = _currentUserUid!;

    return _firestore
        .collection(_collectionName)
        .where('firebaseUid', isEqualTo: userUid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
    });
  }

  // ==========================================
  // STREAM FAVORITE STATUS
  // ==========================================
  /// Stream to check if a specific place is favorited (real-time)
  static Stream<bool> streamIsFavorite(Map<String, dynamic> place) {
    if (!isLoggedIn) return Stream.value(false);

    final userUid = _currentUserUid!;
    final placeId = _generatePlaceId(place);

    return _firestore
        .collection(_collectionName)
        .where('firebaseUid', isEqualTo: userUid)
        .where('placeId', isEqualTo: placeId)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  /// Generate a unique place ID based on coordinates or OSM ID
  static String _generatePlaceId(Map<String, dynamic> place) {
    // Prefer OSM ID if available
    final osmId = place['id']?.toString() ?? place['osm_id']?.toString();
    if (osmId != null && osmId.isNotEmpty) {
      return 'osm_$osmId';
    }

    // Fallback to coordinates-based ID
    final lat = place['latitude'] ?? place['lat'];
    final lon = place['longitude'] ?? place['lon'];
    if (lat != null && lon != null) {
      // Round to 5 decimal places for consistency
      final latRounded = (lat as double).toStringAsFixed(5);
      final lonRounded = (lon as double).toStringAsFixed(5);
      return 'coord_${latRounded}_$lonRounded';
    }

    // Last resort: use name hash
    final name = place['name']?.toString() ?? 'unknown';
    return 'name_${name.hashCode}';
  }

  /// Infer category from place type
  static String _inferCategory(Map<String, dynamic> place) {
    final type = (place['type'] ?? '').toString().toLowerCase();
    final tags = place['tags'] as Map<String, dynamic>?;
    final amenity = tags?['amenity']?.toString().toLowerCase() ?? '';
    final tourism = tags?['tourism']?.toString().toLowerCase() ?? '';

    // Food places
    if (['restaurant', 'cafe', 'fast_food', 'bar', 'pub', 'food_court', 'bakery']
        .contains(amenity) || ['restaurant', 'cafe'].contains(type)) {
      return 'food';
    }

    // Accommodation
    if (['hotel', 'hostel', 'motel', 'guest_house', 'apartment']
        .contains(tourism) || ['hotel', 'hostel'].contains(type)) {
      return 'accommodation';
    }

    // Default to attraction
    return 'attraction';
  }

  /// Extract address from place tags
  static String? _extractAddress(Map<String, dynamic> place) {
    final tags = place['tags'] as Map<String, dynamic>?;
    if (tags == null) return null;

    final parts = <String>[];

    if (tags['addr:street'] != null) {
      if (tags['addr:housenumber'] != null) {
        parts.add('${tags['addr:housenumber']} ${tags['addr:street']}');
      } else {
        parts.add(tags['addr:street'].toString());
      }
    }
    if (tags['addr:city'] != null) parts.add(tags['addr:city'].toString());
    if (tags['addr:state'] != null) parts.add(tags['addr:state'].toString());
    if (tags['addr:country'] != null) parts.add(tags['addr:country'].toString());

    return parts.isNotEmpty ? parts.join(', ') : null;
  }
}