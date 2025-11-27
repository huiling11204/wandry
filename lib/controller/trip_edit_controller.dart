// lib/controller/trip_edit_controller.dart
// Handles trip-level editing (preferences, dates, destination)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripEditController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  StreamSubscription? _regenerationSubscription;
  bool _isDisposed = false;

  // Callbacks
  Function(bool isLoading)? onLoadingChanged;
  Function(String message)? onError;
  Function(String message)? onSuccess;
  Function(int progress, String message)? onRegenerationProgress;
  Function(String tripId)? onRegenerationComplete;

  void dispose() {
    _isDisposed = true;
    _regenerationSubscription?.cancel();
    onLoadingChanged = null;
    onError = null;
    onSuccess = null;
    onRegenerationProgress = null;
    onRegenerationComplete = null;
  }

  /// Get current trip data for editing
  Future<Map<String, dynamic>?> getTripData(String tripId) async {
    try {
      final doc = await _firestore.collection('trip').doc(tripId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      onError?.call('Failed to load trip data');
      return null;
    }
  }

  /// Update trip preferences without regenerating itinerary
  /// Use this for simple metadata changes (name, description)
  Future<bool> updateTripMetadata({
    required String tripId,
    String? tripName,
    String? tripDescription,
  }) async {
    onLoadingChanged?.call(true);

    try {
      final updates = <String, dynamic>{
        'lastUpdatedDate': FieldValue.serverTimestamp(),
      };

      if (tripName != null) updates['tripName'] = tripName;
      if (tripDescription != null) updates['tripDescription'] = tripDescription;

      await _firestore.collection('trip').doc(tripId).update(updates);

      onLoadingChanged?.call(false);
      onSuccess?.call('Trip updated successfully!');
      return true;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to update trip: ${e.toString()}');
      return false;
    }
  }

  /// Update trip preferences that require itinerary regeneration
  /// This will delete existing itinerary and generate a new one
  Future<bool> updateTripWithRegeneration({
    required String tripId,
    String? city,
    String? country,
    DateTime? startDate,
    DateTime? endDate,
    String? budgetLevel,
    List<String>? destinationTypes,
    bool? halalOnly,
  }) async {
    onLoadingChanged?.call(true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // 1. Get existing trip data
      final tripDoc = await _firestore.collection('trip').doc(tripId).get();
      if (!tripDoc.exists) {
        throw Exception('Trip not found');
      }

      final existingData = tripDoc.data()!;

      // 2. Merge with new data
      final newCity = city ?? existingData['destinationCity'];
      final newCountry = country ?? existingData['destinationCountry'];
      final newStartDate = startDate ?? _parseDate(existingData['startDate']);
      final newEndDate = endDate ?? _parseDate(existingData['endDate']);
      final newBudgetLevel = budgetLevel ?? existingData['budgetLevel'] ?? 'Medium';
      final newDestinationTypes = destinationTypes ??
          (existingData['destinationTypes'] as List?)?.cast<String>() ?? ['relaxing'];
      final newHalalOnly = halalOnly ?? existingData['halalOnly'] ?? false;

      // 3. Delete existing itinerary items
      await _deleteExistingItinerary(tripId);

      // 4. Update trip status and metadata
      await _firestore.collection('trip').doc(tripId).update({
        'destinationCity': newCity,
        'destinationCountry': newCountry,
        'city': newCity,
        'country': newCountry,
        'startDate': Timestamp.fromDate(newStartDate),
        'endDate': Timestamp.fromDate(newEndDate),
        'budgetLevel': newBudgetLevel,
        'destinationTypes': newDestinationTypes,
        'halalOnly': newHalalOnly,
        'generationStatus': 'pending',
        'generationProgress': 0,
        'progressMessage': 'Starting regeneration...',
        'isRegenerated': true,
        'regeneratedAt': FieldValue.serverTimestamp(),
        'lastUpdatedDate': FieldValue.serverTimestamp(),
      });

      // 5. Start listening for regeneration progress
      _listenToRegeneration(tripId);

      // 6. Call cloud function to regenerate
      await _functions.httpsCallable('py-generateCompleteTrip').call({
        'tripID': tripId,
        'userID': user.uid,
        'city': newCity,
        'country': newCountry,
        'startDate': newStartDate.toIso8601String(),
        'endDate': newEndDate.toIso8601String(),
        'budgetLevel': newBudgetLevel,
        'destinationTypes': newDestinationTypes,
        'halalOnly': newHalalOnly,
      });

      return true;
    } catch (e) {
      onLoadingChanged?.call(false);
      onError?.call('Failed to regenerate trip: ${e.toString()}');
      return false;
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Future<void> _deleteExistingItinerary(String tripId) async {
    // Delete itinerary items
    final items = await _firestore
        .collection('itineraryItem')
        .where('tripID', isEqualTo: tripId)
        .get();

    final batch = _firestore.batch();
    for (var doc in items.docs) {
      batch.delete(doc.reference);
    }

    // Delete accommodation
    try {
      await _firestore.collection('accommodation').doc(tripId).delete();
    } catch (e) {
      // Ignore if doesn't exist
    }

    await batch.commit();
  }

  void _listenToRegeneration(String tripId) {
    if (_isDisposed) return;

    _regenerationSubscription?.cancel();
    _regenerationSubscription = _firestore
        .collection('trip')
        .doc(tripId)
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed) return;
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = data['generationStatus'] as String?;
      final progress = data['generationProgress'] as int? ?? 0;
      final message = data['progressMessage'] as String? ?? 'Processing...';

      switch (status) {
        case 'processing':
          onRegenerationProgress?.call(progress, message);
          break;
        case 'completed':
          _regenerationSubscription?.cancel();
          onLoadingChanged?.call(false);
          onRegenerationComplete?.call(tripId);
          break;
        case 'failed':
          _regenerationSubscription?.cancel();
          onLoadingChanged?.call(false);
          final errorMessage = data['errorMessage'] as String? ?? 'Regeneration failed';
          onError?.call(errorMessage);
          break;
      }
    });
  }

  /// Check if changes require regeneration
  static bool requiresRegeneration({
    Map<String, dynamic>? originalData,
    String? newCity,
    String? newCountry,
    DateTime? newStartDate,
    DateTime? newEndDate,
    String? newBudgetLevel,
    List<String>? newDestinationTypes,
  }) {
    if (originalData == null) return true;

    // City or country change = regeneration needed
    if (newCity != null && newCity != originalData['destinationCity']) return true;
    if (newCountry != null && newCountry != originalData['destinationCountry']) return true;

    // Date change = regeneration needed
    if (newStartDate != null) {
      final originalStart = _parseStaticDate(originalData['startDate']);
      if (!_isSameDay(newStartDate, originalStart)) return true;
    }

    if (newEndDate != null) {
      final originalEnd = _parseStaticDate(originalData['endDate']);
      if (!_isSameDay(newEndDate, originalEnd)) return true;
    }

    // Budget level change = regeneration needed (affects pricing)
    if (newBudgetLevel != null && newBudgetLevel != originalData['budgetLevel']) return true;

    // Destination types change = regeneration needed
    if (newDestinationTypes != null) {
      final originalTypes = (originalData['destinationTypes'] as List?)?.cast<String>() ?? [];
      if (!_listsEqual(newDestinationTypes, originalTypes)) return true;
    }

    return false;
  }

  static DateTime _parseStaticDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = List<String>.from(a)..sort();
    final sortedB = List<String>.from(b)..sort();
    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  /// Get edit summary for confirmation dialog
  static Map<String, String> getEditSummary({
    required Map<String, dynamic> originalData,
    String? newCity,
    String? newCountry,
    DateTime? newStartDate,
    DateTime? newEndDate,
    String? newBudgetLevel,
    List<String>? newDestinationTypes,
  }) {
    final changes = <String, String>{};

    if (newCity != null && newCity != originalData['destinationCity']) {
      changes['City'] = '${originalData['destinationCity']} → $newCity';
    }

    if (newCountry != null && newCountry != originalData['destinationCountry']) {
      changes['Country'] = '${originalData['destinationCountry']} → $newCountry';
    }

    if (newStartDate != null) {
      final originalStart = _parseStaticDate(originalData['startDate']);
      if (!_isSameDay(newStartDate, originalStart)) {
        changes['Start Date'] = '${_formatDate(originalStart)} → ${_formatDate(newStartDate)}';
      }
    }

    if (newEndDate != null) {
      final originalEnd = _parseStaticDate(originalData['endDate']);
      if (!_isSameDay(newEndDate, originalEnd)) {
        changes['End Date'] = '${_formatDate(originalEnd)} → ${_formatDate(newEndDate)}';
      }
    }

    if (newBudgetLevel != null && newBudgetLevel != originalData['budgetLevel']) {
      changes['Budget'] = '${originalData['budgetLevel'] ?? 'Medium'} → $newBudgetLevel';
    }

    if (newDestinationTypes != null) {
      final originalTypes = (originalData['destinationTypes'] as List?)?.cast<String>() ?? [];
      if (!_listsEqual(newDestinationTypes, originalTypes)) {
        changes['Trip Style'] = 'Updated preferences';
      }
    }

    return changes;
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}