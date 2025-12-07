import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Holds all budget amounts by category
class BudgetData {
  final double totalMYR;
  final double totalLocal;
  final double mealsMYR;
  final double mealsLocal;
  final double attractionsMYR;
  final double attractionsLocal;
  final double entertainmentMYR;
  final double entertainmentLocal;
  final double accommodationMYR;
  final double accommodationLocal;
  final double otherMYR;
  final double otherLocal;
  final String? localCurrency;
  final int itemCount;
  final int accommodationCount;

  BudgetData({
    required this.totalMYR,
    required this.totalLocal,
    required this.mealsMYR,
    required this.mealsLocal,
    required this.attractionsMYR,
    required this.attractionsLocal,
    required this.entertainmentMYR,
    required this.entertainmentLocal,
    required this.accommodationMYR,
    required this.accommodationLocal,
    required this.otherMYR,
    required this.otherLocal,
    this.localCurrency,
    required this.itemCount,
    required this.accommodationCount,
  });

  /// Creates empty budget with all zeros
  factory BudgetData.empty() {
    return BudgetData(
      totalMYR: 0.0,
      totalLocal: 0.0,
      mealsMYR: 0.0,
      mealsLocal: 0.0,
      attractionsMYR: 0.0,
      attractionsLocal: 0.0,
      entertainmentMYR: 0.0,
      entertainmentLocal: 0.0,
      accommodationMYR: 0.0,
      accommodationLocal: 0.0,
      otherMYR: 0.0,
      otherLocal: 0.0,
      localCurrency: null,
      itemCount: 0,
      accommodationCount: 0,
    );
  }

  /// Returns true if budget is empty
  bool get isEmpty =>
      totalMYR == 0.0 &&
          totalLocal == 0.0 &&
          itemCount == 0 &&
          accommodationCount == 0;
}

/// Calculates and tracks trip budget in real-time
class BudgetController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Timer to prevent too many database writes
  Timer? _syncTimer;

  /// Calculates total budget for a trip
  Future<BudgetData> calculateBudget(String tripId) async {
    try {
      // Get all itinerary items
      final itemsSnapshot = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .get();

      // Get accommodation data
      final accommodationSnapshot = await _firestore
          .collection('accommodation')
          .doc(tripId)
          .get();

      return _processBudgetData(itemsSnapshot, accommodationSnapshot);
    } catch (e) {
      print('Error calculating budget: $e');
      return BudgetData.empty();
    }
  }

  /// Watches budget changes in real-time and syncs to trip document
  Stream<BudgetData> watchBudget(String tripId) {
    // Stream itinerary items
    final itemsStream = _firestore
        .collection('itineraryItem')
        .where('tripID', isEqualTo: tripId)
        .snapshots();

    // Calculate budget whenever items change
    return itemsStream.asyncMap((itemsSnapshot) async {
      // Get latest accommodation data
      final accommodationSnapshot = await _firestore
          .collection('accommodation')
          .doc(tripId)
          .get();

      final budget = _processBudgetData(itemsSnapshot, accommodationSnapshot);

      // Sync to trip document with throttling
      if (budget.totalMYR > 0) {
        _throttledSyncBudgetToTrip(tripId, budget);
      }

      return budget;
    });
  }

  /// Syncs budget to trip document with delay to prevent infinite loops
  Future<void> _throttledSyncBudgetToTrip(String tripId, BudgetData budget) async {
    // Cancel any pending update
    _syncTimer?.cancel();

    // Wait 2 seconds before updating
    _syncTimer = Timer(const Duration(seconds: 2), () async {
      try {
        final tripDoc = await _firestore.collection('trip').doc(tripId).get();
        final existingTotalMYR = (tripDoc.data()?['totalEstimatedBudgetMYR'] as num?)?.toDouble() ?? 0.0;

        // Round to 2 decimal places for comparison
        final newTotalFixed = double.parse(budget.totalMYR.toStringAsFixed(2));
        final existingTotalFixed = double.parse(existingTotalMYR.toStringAsFixed(2));

        // Skip if value hasn't changed
        if (newTotalFixed == existingTotalFixed) {
          print('Budget check: Value is identical ($newTotalFixed). Skipping write to break the loop.');
          return;
        }

        // Update trip document
        await _firestore.collection('trip').doc(tripId).update({
          'totalEstimatedBudgetMYR': budget.totalMYR,
          'totalEstimatedBudgetLocal': budget.totalLocal,
          'lastBudgetAutoSync': FieldValue.serverTimestamp(),
        });
        print('Budget Synced: RM ${budget.totalMYR.toStringAsFixed(2)}');
      } catch (e) {
        print('Error syncing budget to trip: $e');
      }
    });
  }

  /// Processes items and accommodation to calculate budget
  BudgetData _processBudgetData(
      QuerySnapshot itemsSnapshot,
      DocumentSnapshot accommodationSnapshot,
      ) {
    double totalCostMYR = 0;
    double totalCostLocal = 0;
    double mealsCostMYR = 0;
    double mealsCostLocal = 0;
    double attractionsCostMYR = 0;
    double attractionsCostLocal = 0;
    double entertainmentCostMYR = 0;
    double entertainmentCostLocal = 0;
    double accommodationCostMYR = 0;
    double accommodationCostLocal = 0;
    double otherCostMYR = 0;
    double otherCostLocal = 0;
    String? localCurrency;

    // Process each itinerary item
    for (var item in itemsSnapshot.docs) {
      final data = item.data() as Map<String, dynamic>;
      double costMYR = _safeDouble(data['estimatedCostMYR']);
      double costLocal = _safeDouble(data['estimatedCostLocal']);
      final category = (data['category'] ?? '').toString().toLowerCase();
      final restaurantOptions = data['restaurantOptions'] as List? ?? [];

      // Get local currency from first item that has it
      if (localCurrency == null && data['localCurrency'] != null) {
        localCurrency = data['localCurrency'];
      }

      // If meal has no cost but has restaurant options, estimate from options
      if (costMYR == 0 && _isMealCategory(category) && restaurantOptions.isNotEmpty) {
        final avg = _calculateAverageFromOptions(restaurantOptions);
        if (avg > 0) {
          costMYR = avg;
          costLocal = avg;
        }
      }

      totalCostMYR += costMYR;
      totalCostLocal += costLocal;

      // Add to appropriate category
      if (_isMealCategory(category)) {
        mealsCostMYR += costMYR;
        mealsCostLocal += costLocal;
      } else if (_isAttractionCategory(category)) {
        attractionsCostMYR += costMYR;
        attractionsCostLocal += costLocal;
      } else if (_isEntertainmentCategory(category)) {
        entertainmentCostMYR += costMYR;
        entertainmentCostLocal += costLocal;
      } else {
        otherCostMYR += costMYR;
        otherCostLocal += otherCostLocal;
      }
    }

    // Process accommodation
    int accomCount = 0;
    if (accommodationSnapshot.exists) {
      final data = accommodationSnapshot.data() as Map<String, dynamic>;
      final accommodations = data['accommodations'] as List? ?? [];
      final numNights = _safeInt(data['numNights']);
      accomCount = accommodations.length;

      // Get recommended or first accommodation
      Map<String, dynamic>? targetAccom;
      if (data['recommendedAccommodation'] != null) {
        targetAccom = data['recommendedAccommodation'];
      } else if (accommodations.isNotEmpty) {
        targetAccom = accommodations[0];
      }

      if (targetAccom != null) {
        // Calculate total accommodation cost
        final price = _safeDouble(targetAccom['price_per_night_myr']);
        final totalAccom = price * numNights;

        accommodationCostMYR += totalAccom;

        final priceLocal = _safeDouble(targetAccom['price_per_night_local']);
        if (priceLocal > 0) {
          accommodationCostLocal += (priceLocal * numNights);
        } else {
          accommodationCostLocal += totalAccom;
        }

        if (localCurrency == null) localCurrency = targetAccom['currency'];
      }
    }

    // Add accommodation to total
    totalCostMYR += accommodationCostMYR;
    totalCostLocal += accommodationCostLocal;

    return BudgetData(
      totalMYR: totalCostMYR,
      totalLocal: totalCostLocal,
      mealsMYR: mealsCostMYR,
      mealsLocal: mealsCostLocal,
      attractionsMYR: attractionsCostMYR,
      attractionsLocal: attractionsCostLocal,
      entertainmentMYR: entertainmentCostMYR,
      entertainmentLocal: entertainmentCostLocal,
      accommodationMYR: accommodationCostMYR,
      accommodationLocal: accommodationCostLocal,
      otherMYR: otherCostMYR,
      otherLocal: otherCostLocal,
      localCurrency: localCurrency,
      itemCount: itemsSnapshot.docs.length,
      accommodationCount: accomCount,
    );
  }

  /// Estimates meal cost from restaurant options
  double _calculateAverageFromOptions(List options) {
    if (options.isEmpty) return 0.0;
    double total = 0;
    int count = 0;

    for (var opt in options) {
      final optMap = opt as Map<String, dynamic>;

      // Check explicit cost
      if (optMap['estimated_cost_myr'] != null) {
        total += _safeDouble(optMap['estimated_cost_myr']);
        count++;
        continue;
      }

      // Check cost string like "RM 25.00"
      if (optMap['cost_display'] != null) {
        final val = _extractPrice(optMap['cost_display']);
        if (val > 0) { total += val; count++; continue; }
      }

      // Use price level as fallback
      final level = (optMap['price_level'] ?? '').toString().toLowerCase();
      if (level.contains('expensive') || level == 'high' || level == '3') { total += 100; count++; }
      else if (level.contains('moderate') || level == 'medium' || level == '2') { total += 40; count++; }
      else if (level.contains('cheap') || level == 'low' || level == '1') { total += 15; count++; }
    }

    return count == 0 ? 0.0 : total / count;
  }

  /// Extracts number from price string like "RM 25.00"
  double _extractPrice(String? display) {
    if (display == null) return 0.0;
    try {
      final regex = RegExp(r'(\d+([.,]\d+)?)');
      final match = regex.firstMatch(display);
      if (match != null) {
        return double.parse(match.group(1)!.replaceAll(',', ''));
      }
    } catch (e) { return 0.0; }
    return 0.0;
  }

  /// Safely converts any value to double
  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Safely converts any value to int
  int _safeInt(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  // Category checkers
  bool _isMealCategory(String c) => ['breakfast', 'lunch', 'dinner', 'meal', 'food', 'dining'].contains(c);
  bool _isAttractionCategory(String c) => ['attraction', 'museum', 'park', 'temple', 'landmark', 'monument', 'cultural', 'nature', 'beach'].contains(c);
  bool _isEntertainmentCategory(String c) => ['entertainment', 'shopping', 'nightlife', 'activity', 'sports', 'recreation'].contains(c);
}