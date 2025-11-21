import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TripGenerationController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  StreamSubscription? _tripStatusSubscription;

  // Callbacks
  Function(int step, String message)? onStatusUpdate;
  Function(String tripId)? onCompleted;
  Function(String error)? onError;

  void dispose() {
    _tripStatusSubscription?.cancel();
  }

  Future<String?> generateTrip({
    required String tripName,
    required String tripDescription,
    required String destination,
    required String city,
    required String country,
    required DateTime startDate,
    required DateTime endDate,
    required String budgetLevel,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      onStatusUpdate?.call(0, 'Creating your trip...');

      // Create trip document
      final tripRef = _firestore.collection('trip').doc();
      String estimatedBudget = calculateBudgetRange(startDate, endDate, budgetLevel);

      await tripRef.set({
        'tripID': tripRef.id,
        'userID': user.uid,
        'tripName': tripName,
        'tripDescription': tripDescription,
        'destination': destination,
        'destinationCity': city,
        'destinationCountry': country,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'budgetLevel': budgetLevel,
        'estimatedBudget': estimatedBudget,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdatedDate': FieldValue.serverTimestamp(),
        'status': 'active',
        'generationStatus': 'pending',
      });

      print('✓ Trip created successfully: ${tripRef.id}');
      listenToTripStatus(tripRef.id);

      onStatusUpdate?.call(1, 'Starting trip generation...');

      // Call Cloud Function
      print('Calling ML Cloud Function...');
      final result = await _functions.httpsCallable('py-generateCompleteTrip').call({
        'tripID': tripRef.id,
        'userID': user.uid,
        'city': city,
        'country': country,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'budgetLevel': budgetLevel,
      });

      print('✅ Function called: ${result.data}');
      onStatusUpdate?.call(2, 'Processing in background...');

      return tripRef.id;
    } catch (e) {
      print('❌ Error generating trip: $e');
      onError?.call('Failed to generate trip. Please try again.\n\nError: ${e.toString()}');
      _tripStatusSubscription?.cancel();
      return null;
    }
  }

  void listenToTripStatus(String tripId) {
    print('👂 Listening to trip status for: $tripId');

    _tripStatusSubscription = _firestore
        .collection('trip')
        .doc(tripId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final generationStatus = data['generationStatus'] as String?;
      print('📊 Status update: $generationStatus');

      switch (generationStatus) {
        case 'pending':
          onStatusUpdate?.call(1, 'Waiting to start...');
          break;

        case 'processing':
          onStatusUpdate?.call(3, 'Generating your perfect itinerary...');
          break;

        case 'completed':
          onStatusUpdate?.call(4, 'Trip ready!');
          _tripStatusSubscription?.cancel();
          onCompleted?.call(tripId);
          break;

        case 'failed':
          final error = data['generationError'] as String? ?? 'Unknown error';
          onError?.call('Generation failed: $error');
          _tripStatusSubscription?.cancel();
          break;
      }
    }, onError: (error) {
      print('❌ Listener error: $error');
      onError?.call('Connection error: ${error.toString()}');
    });
  }

  String calculateBudgetRange(DateTime startDate, DateTime endDate, String budgetLevel) {
    final days = endDate.difference(startDate).inDays + 1;

    int minPerDay, maxPerDay;
    switch (budgetLevel) {
      case 'Low':
        minPerDay = 30;
        maxPerDay = 60;
        break;
      case 'High':
        minPerDay = 150;
        maxPerDay = 300;
        break;
      default: // Medium
        minPerDay = 70;
        maxPerDay = 140;
    }

    final minTotal = minPerDay * days;
    final maxTotal = maxPerDay * days;

    return '\$$minTotal-$maxTotal';
  }
}