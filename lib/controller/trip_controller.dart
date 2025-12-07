import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripController {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's trips
  static Future<List<QueryDocumentSnapshot>> getUserTrips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please login first');
    }

    final snapshot = await _firestore
        .collection('trip')
        .where('userID', isEqualTo: user.uid)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('Create a trip first!');
    }

    return snapshot.docs;
  }

  // Add place to trip
  static Future<void> addPlaceToTrip({
    required String tripId,
    required String placeName,
    required String description,
    required double latitude,
    required double longitude,
    String openingHours = '',
    String contactNo = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please login first');
    }

    // Create location document
    final locationRef = _firestore.collection('location').doc();
    await locationRef.set({
      'locationID': locationRef.id,
      'locationName': placeName,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'openingHours': openingHours,
      'contactNo': contactNo,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create itinerary item
    final itineraryRef = _firestore.collection('itineraryItem').doc();
    await itineraryRef.set({
      'itineraryItemID': itineraryRef.id,
      'tripID': tripId,
      'locationID': locationRef.id,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }
}