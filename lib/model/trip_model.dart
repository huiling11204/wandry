import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String id;
  final String tripName;
  final String destinationCity;
  final String destinationCountry;
  final DateTime startDate;
  final DateTime endDate;
  final double? totalEstimatedBudgetMYR;
  final double? totalEstimatedBudgetLocal;
  final String? destinationCurrency;
  final List<String>? features;
  final Map<String, dynamic>? mlMetrics;

  // NEW: Data quality fields
  final String? dataQuality;           // 'good' or 'limited'
  final bool? isSparseDataArea;        // true if limited restaurant data
  final int? totalRestaurantsFound;    // Total restaurants found
  final String? destinationWarning;    // Warning message if any
  final String? destinationType;       // 'normal', 'large', 'remote', 'recommended'
  final List<String>? destinationTypes; // User selected trip styles

  TripModel({
    required this.id,
    required this.tripName,
    required this.destinationCity,
    required this.destinationCountry,
    required this.startDate,
    required this.endDate,
    this.totalEstimatedBudgetMYR,
    this.totalEstimatedBudgetLocal,
    this.destinationCurrency,
    this.features,
    this.mlMetrics,
    this.dataQuality,
    this.isSparseDataArea,
    this.totalRestaurantsFound,
    this.destinationWarning,
    this.destinationType,
    this.destinationTypes,
  });

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripModel(
      id: doc.id,
      tripName: data['tripName'] ?? 'Trip',
      destinationCity: data['destinationCity'] ?? '',
      destinationCountry: data['destinationCountry'] ?? '',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      totalEstimatedBudgetMYR: data['totalEstimatedBudgetMYR']?.toDouble(),
      totalEstimatedBudgetLocal: data['totalEstimatedBudgetLocal']?.toDouble(),
      destinationCurrency: data['destinationCurrency'],
      features: data['features'] != null
          ? List<String>.from(data['features'])
          : null,
      mlMetrics: data['mlMetrics'],
      // NEW fields
      dataQuality: data['dataQuality'],
      isSparseDataArea: data['isSparseDataArea'],
      totalRestaurantsFound: data['totalRestaurantsFound'],
      destinationWarning: data['destinationWarning'],
      destinationType: data['destinationType'],
      destinationTypes: data['destinationTypes'] != null
          ? List<String>.from(data['destinationTypes'])
          : null,
    );
  }

  static DateTime _parseDate(dynamic value) {
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

  int get durationInDays => endDate.difference(startDate).inDays + 1;

  // NEW: Helper methods
  bool get hasLimitedData => dataQuality == 'limited' || isSparseDataArea == true;

  bool get isRemoteArea => destinationType == 'remote';

  bool get isLargeCity => destinationType == 'large';

  String? get dataQualityMessage {
    if (hasLimitedData) {
      return 'This area has limited data. Some meal options may be fewer than usual.';
    }
    return null;
  }
}