import 'package:cloud_firestore/cloud_firestore.dart';

class ItineraryItemModel {
  final String id;
  final String tripId;
  final int dayNumber;
  final int orderInDay;
  final String title;
  final String category;
  final String startTime;
  final String endTime;
  final double? estimatedCostMYR;
  final double? estimatedCostLocal;
  final String? currencyDisplay;
  final String? localCurrency;
  final String? description;
  final Map<String, dynamic>? coordinates;
  final List<dynamic>? restaurantOptions;
  final Map<String, dynamic>? weather;
  final bool? isHalalCertified;
  final bool? isOutdoor;
  final double? rating;
  final String? website;
  final bool? hasWebsite;
  final List<dynamic>? highlights;
  final String? openingHours;
  final String? bestTimeToVisit;
  final String? accessibility;
  final String? nearbyTransit;
  final List<dynamic>? facilities;
  final List<dynamic>? tips;

  ItineraryItemModel({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.orderInDay,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    this.estimatedCostMYR,
    this.estimatedCostLocal,
    this.currencyDisplay,
    this.localCurrency,
    this.description,
    this.coordinates,
    this.restaurantOptions,
    this.weather,
    this.isHalalCertified,
    this.isOutdoor,
    this.rating,
    this.website,
    this.hasWebsite,
    this.highlights,
    this.openingHours,
    this.bestTimeToVisit,
    this.accessibility,
    this.nearbyTransit,
    this.facilities,
    this.tips,
  });

  factory ItineraryItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItineraryItemModel(
      id: doc.id,
      tripId: data['tripID'] ?? '',
      dayNumber: data['dayNumber'] ?? 0,
      orderInDay: data['orderInDay'] ?? 0,
      title: data['title'] ?? 'Activity',
      category: data['category'] ?? 'attraction',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      estimatedCostMYR: data['estimatedCostMYR']?.toDouble(),
      estimatedCostLocal: data['estimatedCostLocal']?.toDouble(),
      currencyDisplay: data['currencyDisplay'],
      localCurrency: data['localCurrency'],
      description: data['description'],
      coordinates: data['coordinates'],
      restaurantOptions: data['restaurantOptions'],
      weather: data['weather'],
      isHalalCertified: data['isHalalCertified'],
      isOutdoor: data['isOutdoor'],
      rating: data['rating']?.toDouble(),
      website: data['website'],
      hasWebsite: data['has_website'],
      highlights: data['highlights'],
      openingHours: data['openingHours'],
      bestTimeToVisit: data['bestTimeToVisit'],
      accessibility: data['accessibility'],
      nearbyTransit: data['nearbyTransit'],
      facilities: data['facilities'],
      tips: data['tips'],
    );
  }

  bool get isMeal => ['breakfast', 'lunch', 'dinner', 'meal'].contains(category.toLowerCase());

  bool get hasRestaurants => restaurantOptions != null && restaurantOptions!.isNotEmpty;
}