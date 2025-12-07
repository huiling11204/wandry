// Real-time progress tracking with user-friendly error handling
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../model/destination_type_model.dart';

class TripGenerationController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  StreamSubscription? _tripStatusSubscription;
  bool _isDisposed = false;

  // Callbacks
  Function(int progress, String message)? onProgressUpdate;
  Function(String tripId, String? warning, String? dataQuality)? onCompleted;
  Function(String errorCode, String errorMessage)? onError;
  Function(String warning)? onWarning;

  void dispose() {
    _isDisposed = true;  // ADD THIS
    _tripStatusSubscription?.cancel();
    _tripStatusSubscription = null;

    // Clear callbacks
    onProgressUpdate = null;
    onCompleted = null;
    onError = null;
    onWarning = null;
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
    List<String> destinationTypes = const ['relaxing'],
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      onProgressUpdate?.call(0, 'Creating your trip...');

      // Create trip document
      final tripRef = _firestore.collection('trip').doc();
      String estimatedBudget = calculateBudgetRange(startDate, endDate, budgetLevel);

      // Get backend categories from selected types
      final preferredCategories = DestinationType.getBackendCategories(destinationTypes);
      final categoryWeights = DestinationType.getCategoryWeights(destinationTypes);

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
        'generationProgress': 0,
        'statusMessage': 'Initializing...',
        'destinationTypes': destinationTypes,
        'preferredCategories': preferredCategories,
        'categoryWeights': categoryWeights,
      });

      print('✓ Trip created successfully: ${tripRef.id}');
      print('  Destination Types: $destinationTypes');

      // Start listening BEFORE calling cloud function
      listenToTripStatus(tripRef.id);

      onProgressUpdate?.call(5, 'Starting trip generation...');

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
        'destinationTypes': destinationTypes,
        'preferredCategories': preferredCategories,
        'categoryWeights': categoryWeights,
      });

      print('✅ Function called: ${result.data}');

      // Check for immediate warning from function response
      final responseData = result.data as Map<String, dynamic>?;
      if (responseData != null) {
        final warning = responseData['warning'] as String?;
        final destType = responseData['destinationType'] as String?;

        if (warning != null && warning.isNotEmpty) {
          print('⚠️ Destination warning: $warning');
          onWarning?.call(warning);
        }

        if (destType == 'large') {
          print('⚠️ Large city detected');
        } else if (destType == 'remote') {
          print('⚠️ Remote area detected');
        }
      }

      return tripRef.id;
    } catch (e) {
      print('❌ Error generating trip: $e');
      onError?.call('UNKNOWN_ERROR', 'Failed to generate trip. Please try again.\n\nError: ${e.toString()}');
      _tripStatusSubscription?.cancel();
      return null;
    }
  }

  void listenToTripStatus(String tripId) {
    if (_isDisposed) return;
    print('👂 Listening to trip status for: $tripId');

    _tripStatusSubscription?.cancel();

    _tripStatusSubscription = _firestore
        .collection('trip')
        .doc(tripId)
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed) return;

      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final generationStatus = data['generationStatus'] as String?;
      final progress = data['generationProgress'] as int? ?? 0;
      final statusMessage = data['statusMessage'] as String? ?? 'Processing...';
      final errorCode = data['errorCode'] as String?;
      final errorMessage = data['errorMessage'] as String?;
      final destinationWarning = data['destinationWarning'] as String?;
      final dataQuality = data['dataQuality'] as String?;

      print('📊 Status: $generationStatus, Progress: $progress%, Message: $statusMessage');

      switch (generationStatus) {
        case 'pending':
          onProgressUpdate?.call(progress > 0 ? progress : 5, statusMessage);
          break;

        case 'processing':
          onProgressUpdate?.call(progress, statusMessage);

          // Send warning if exists (only once)
          if (destinationWarning != null && destinationWarning.isNotEmpty) {
            onWarning?.call(destinationWarning);
          }
          break;

        case 'completed':
          onProgressUpdate?.call(100, 'Trip ready!');
          _tripStatusSubscription?.cancel();

          // Pass warning and data quality to completion handler
          onCompleted?.call(tripId, destinationWarning, dataQuality);
          break;

        case 'failed':
          final code = errorCode ?? 'GENERATION_FAILED';
          final message = errorMessage ?? 'An error occurred. Please try again.';
          onError?.call(code, message);
          _tripStatusSubscription?.cancel();
          break;
      }
    }, onError: (error) {
      if (_isDisposed) return;
      print('❌ Listener error: $error');
      onError?.call('CONNECTION_ERROR', 'Connection error: ${error.toString()}');
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
      default:
        minPerDay = 70;
        maxPerDay = 140;
    }

    final minTotal = minPerDay * days;
    final maxTotal = maxPerDay * days;

    return '\$$minTotal-$maxTotal';
  }
}

// Error code descriptions for UI
class GenerationErrorCodes {
  static const Map<String, ErrorInfo> errors = {
    'CITY_TOO_LARGE': ErrorInfo(
      title: 'City Too Large',
      icon: Icons.location_city,
      color: Colors.orange,
      suggestion: 'Try searching for a specific district or area instead.',
    ),
    'REMOTE_AREA': ErrorInfo(
      title: 'Remote Area',
      icon: Icons.terrain,
      color: Colors.amber,
      suggestion: 'This area has limited data. Results may be incomplete.',
    ),
    'NO_DESTINATIONS': ErrorInfo(
      title: 'No Attractions Found',
      icon: Icons.search_off,
      color: Colors.red,
      suggestion: 'Try a different destination or nearby major city.',
    ),
    'NO_RESTAURANTS': ErrorInfo(
      title: 'No Restaurants Found',
      icon: Icons.restaurant,
      color: Colors.orange,
      suggestion: 'This might be a remote location with limited dining options.',
    ),
    'GEOCODE_FAILED': ErrorInfo(
      title: 'Location Not Found',
      icon: Icons.location_off,
      color: Colors.red,
      suggestion: 'Please check the spelling or try a nearby city.',
    ),
    'API_TIMEOUT': ErrorInfo(
      title: 'Server Busy',
      icon: Icons.cloud_off,
      color: Colors.grey,
      suggestion: 'Please try again in a few minutes.',
    ),
    'GENERATION_FAILED': ErrorInfo(
      title: 'Generation Failed',
      icon: Icons.error_outline,
      color: Colors.red,
      suggestion: 'Something went wrong. Please try again.',
    ),
  };

  static ErrorInfo getErrorInfo(String code) {
    return errors[code] ?? errors['GENERATION_FAILED']!;
  }
}

class ErrorInfo {
  final String title;
  final IconData icon;
  final Color color;
  final String suggestion;

  const ErrorInfo({
    required this.title,
    required this.icon,
    required this.color,
    required this.suggestion,
  });
}