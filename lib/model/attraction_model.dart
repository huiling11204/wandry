// lib/model/attraction_model.dart

class Attraction {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double? distance;
  final String? address;
  final Map<String, dynamic> tags;
  final String? osmType;
  final dynamic osmId;
  final String category;

  Attraction({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.address,
    required this.tags,
    this.osmType,
    this.osmId,
    this.category = 'general',
  });

  factory Attraction.fromMap(Map<String, dynamic> map) {
    return Attraction(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown',
      type: map['type']?.toString() ?? '',
      latitude: (map['latitude'] ?? map['lat'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? map['lon'] ?? 0.0).toDouble(),
      distance: map['distance'] != null ? (map['distance'] as num).toDouble() : null,
      address: map['address']?.toString(),
      tags: Map<String, dynamic>.from(map['tags'] ?? {}),
      osmType: map['osmType']?.toString(),
      osmId: map['osmId'],
      category: map['category']?.toString() ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'address': address,
      'tags': tags,
      'osmType': osmType,
      'osmId': osmId,
      'category': category,
    };
  }
}

class PlaceDetails {
  final String name;
  final String description;
  final String openingHours;
  final String phone;
  final String website;

  PlaceDetails({
    required this.name,
    required this.description,
    this.openingHours = 'Not available',
    this.phone = 'Not available',
    this.website = '',
  });

  factory PlaceDetails.fromMap(Map<String, dynamic> map) {
    return PlaceDetails(
      name: map['name']?.toString() ?? 'Unknown',
      description: map['description']?.toString() ?? '',
      openingHours: map['openingHours']?.toString() ?? 'Not available',
      phone: map['phone']?.toString() ?? 'Not available',
      website: map['website']?.toString() ?? '',
    );
  }
}