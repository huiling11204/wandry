import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for tracking user interactions with destinations and places
/// This data is used to train the ML recommendation system
class InteractionTracker {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Track when a user views a destination/place
  Future<void> trackPlaceView({
    required String placeId,
    required String placeName,
    required String category,
    String? state,
    String? country,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('userInteractions').add({
        'userID': user.uid,
        'interactionType': 'view',
        'placeId': placeId,
        'placeName': placeName,
        'category': category,
        'state': state,
        'country': country,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'app', // Could be 'app', 'search', 'recommendation'
      });

      print('✅ Tracked place view: $placeName');
    } catch (e) {
      print('❌ Error tracking place view: $e');
    }
  }

  /// Track when a user saves/bookmarks a place
  Future<void> trackPlaceSave({
    required String placeId,
    required String placeName,
    required String category,
    String? state,
    String? country,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('userInteractions').add({
        'userID': user.uid,
        'interactionType': 'save',
        'placeId': placeId,
        'placeName': placeName,
        'category': category,
        'state': state,
        'country': country,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'app',
      });

      print('✅ Tracked place save: $placeName');
    } catch (e) {
      print('❌ Error tracking place save: $e');
    }
  }

  /// Track when a user adds a place to their trip
  Future<void> trackPlaceAddedToTrip({
    required String placeId,
    required String placeName,
    required String category,
    required String tripId,
    String? state,
    String? country,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('userInteractions').add({
        'userID': user.uid,
        'interactionType': 'add_to_trip',
        'placeId': placeId,
        'placeName': placeName,
        'category': category,
        'tripId': tripId,
        'state': state,
        'country': country,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'app',
      });

      print('✅ Tracked place added to trip: $placeName');
    } catch (e) {
      print('❌ Error tracking place add to trip: $e');
    }
  }

  /// Track when a user rates a place
  Future<void> trackPlaceRating({
    required String placeId,
    required String placeName,
    required String category,
    required double rating,
    String? review,
    String? state,
    String? country,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('userInteractions').add({
        'userID': user.uid,
        'interactionType': 'rating',
        'placeId': placeId,
        'placeName': placeName,
        'category': category,
        'rating': rating,
        'review': review,
        'state': state,
        'country': country,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'app',
      });

      print('✅ Tracked place rating: $placeName - $rating stars');
    } catch (e) {
      print('❌ Error tracking place rating: $e');
    }
  }

  /// Track when a user searches for places
  Future<void> trackSearch({
    required String searchQuery,
    String? category,
    String? location,
    int? resultsCount,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('userInteractions').add({
        'userID': user.uid,
        'interactionType': 'search',
        'searchQuery': searchQuery,
        'category': category,
        'location': location,
        'resultsCount': resultsCount,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'app',
      });

      print('✅ Tracked search: $searchQuery');
    } catch (e) {
      print('❌ Error tracking search: $e');
    }
  }

  /// Track when a user rates their completed trip
  Future<void> trackTripRating({
    required String tripId,
    required String tripName,
    required double overallRating,
    double? accommodationRating,
    double? transportationRating,
    double? activitiesRating,
    String? feedback,
    List<String>? visitedPlaces,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('userInteractions').add({
        'userID': user.uid,
        'interactionType': 'trip_rating',
        'tripId': tripId,
        'tripName': tripName,
        'overallRating': overallRating,
        'accommodationRating': accommodationRating,
        'transportationRating': transportationRating,
        'activitiesRating': activitiesRating,
        'feedback': feedback,
        'visitedPlaces': visitedPlaces,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'app',
      });

      print('✅ Tracked trip rating: $tripName - $overallRating stars');
    } catch (e) {
      print('❌ Error tracking trip rating: $e');
    }
  }

  /// Track when a user completes a trip (changes status to completed)
  Future<void> trackTripCompletion({
    required String tripId,
    required String tripName,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    int? daysCount,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('userInteractions').add({
        'userID': user.uid,
        'interactionType': 'trip_completed',
        'tripId': tripId,
        'tripName': tripName,
        'destination': destination,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'daysCount': daysCount,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'app',
      });

      print('✅ Tracked trip completion: $tripName');
    } catch (e) {
      print('❌ Error tracking trip completion: $e');
    }
  }

  /// Track when a user clicks on a recommendation
  Future<void> trackRecommendationClick({
    required String recommendationId,
    required String placeId,
    required String placeName,
    required String recommendationType, // 'similar', 'trending', 'personalized'
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('userInteractions').add({
        'userID': user.uid,
        'interactionType': 'recommendation_click',
        'recommendationId': recommendationId,
        'placeId': placeId,
        'placeName': placeName,
        'recommendationType': recommendationType,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'recommendation',
      });

      print('✅ Tracked recommendation click: $placeName');
    } catch (e) {
      print('❌ Error tracking recommendation click: $e');
    }
  }

  /// Get user's interaction history (for debugging or profile view)
  Future<List<Map<String, dynamic>>> getUserInteractions({
    int limit = 50,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('userInteractions')
          .where('userID', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('❌ Error fetching user interactions: $e');
      return [];
    }
  }

  /// Get interaction statistics for the current user
  Future<Map<String, dynamic>> getUserInteractionStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final snapshot = await _firestore
          .collection('userInteractions')
          .where('userID', isEqualTo: user.uid)
          .get();

      int viewCount = 0;
      int saveCount = 0;
      int ratingCount = 0;
      int tripCount = 0;
      Map<String, int> categoryViews = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final type = data['interactionType'] as String?;
        final category = data['category'] as String?;

        switch (type) {
          case 'view':
            viewCount++;
            if (category != null) {
              categoryViews[category] = (categoryViews[category] ?? 0) + 1;
            }
            break;
          case 'save':
            saveCount++;
            break;
          case 'rating':
            ratingCount++;
            break;
          case 'trip_completed':
            tripCount++;
            break;
        }
      }

      return {
        'totalInteractions': snapshot.docs.length,
        'viewCount': viewCount,
        'saveCount': saveCount,
        'ratingCount': ratingCount,
        'completedTrips': tripCount,
        'topCategories': categoryViews.entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      };
    } catch (e) {
      print('❌ Error fetching interaction stats: $e');
      return {};
    }
  }
}