class StringHelper {
  // Extract English place name
  static String extractEnglishPlaceName(Map<String, dynamic> place) {
    String placeName = '';

    final tags = place['tags'] as Map<String, dynamic>?;
    if (tags != null) {
      placeName = tags['name:en']?.toString() ??
          tags['int_name']?.toString() ??
          tags['official_name:en']?.toString() ??
          tags['alt_name:en']?.toString() ??
          '';
    }

    if (placeName.isEmpty) {
      String fullName = place['name']?.toString() ??
          place['display_name']?.toString() ??
          '';

      if (fullName.isNotEmpty) {
        List<String> parts = fullName.split(',').map((e) => e.trim()).toList();

        for (var part in parts) {
          if (containsLatinCharacters(part) && part.length > 2) {
            placeName = part;
            break;
          }
        }

        if (placeName.isEmpty) {
          placeName = parts[0];
        }
      }
    }

    return placeName;
  }

  // Check if text contains Latin characters
  static bool containsLatinCharacters(String text) {
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  // Get English country name from country code
  static String getEnglishCountryName(Map<String, dynamic>? address) {
    if (address == null) return '';

    String country = address['country']?.toString() ?? '';
    String countryCode = address['country_code']?.toString().toUpperCase() ?? '';

    Map<String, String> countryMap = {
      'JP': 'Japan',
      'CN': 'China',
      'KR': 'South Korea',
      'TH': 'Thailand',
      'MY': 'Malaysia',
      'SG': 'Singapore',
      'ID': 'Indonesia',
      'VN': 'Vietnam',
      'PH': 'Philippines',
      'IN': 'India',
      'FR': 'France',
      'DE': 'Germany',
      'IT': 'Italy',
      'ES': 'Spain',
      'GB': 'United Kingdom',
      'US': 'United States',
    };

    if (countryCode.isNotEmpty && countryMap.containsKey(countryCode)) {
      return countryMap[countryCode]!;
    }

    return country;
  }

  // Format opening hours
  static String formatOpeningHours(String hours) {
    if (hours == 'Not available' || hours.isEmpty) return hours;

    return hours
        .replaceAll('Mo', 'Mon')
        .replaceAll('Tu', 'Tue')
        .replaceAll('We', 'Wed')
        .replaceAll('Th', 'Thu')
        .replaceAll('Fr', 'Fri')
        .replaceAll('Sa', 'Sat')
        .replaceAll('Su', 'Sun');
  }

  // Get smart fallback description based on place type
  static String getSmartFallbackDescription(Map<String, dynamic>? tags) {
    if (tags == null) return 'Discover this amazing destination.';

    String tourism = tags['tourism']?.toString() ?? '';
    String amenity = tags['amenity']?.toString() ?? '';

    if (tourism == 'hotel' || amenity == 'hotel') {
      return 'A comfortable accommodation option offering quality service and amenities for travelers.';
    } else if (tourism == 'attraction' || tourism == 'viewpoint') {
      return 'A popular destination known for its unique features and visitor experiences.';
    } else if (amenity == 'restaurant' || amenity == 'cafe') {
      return 'A dining establishment serving food and beverages to guests.';
    } else if (tourism == 'museum') {
      return 'A cultural institution preserving and exhibiting artifacts and history.';
    } else if (amenity == 'bar' || amenity == 'pub') {
      return 'An establishment serving drinks and providing social atmosphere.';
    } else if (tourism == 'gallery') {
      return 'An art gallery showcasing various artworks and exhibitions.';
    } else if (tourism == 'theme_park' || tourism == 'zoo') {
      return 'An entertainment venue offering attractions and activities for visitors of all ages.';
    } else if (tags['shop'] != null) {
      return 'A retail establishment offering products and services.';
    }

    return 'Discover this amazing destination worth visiting.';
  }

  // Parse address from tags
  static String getAddressString(Map<String, dynamic>? tags) {
    if (tags == null) return '';

    List<String> addressParts = [];

    String street = '';
    if (tags['addr:housenumber'] != null) {
      street = tags['addr:housenumber'].toString();
    }
    if (tags['addr:street'] != null) {
      if (street.isNotEmpty) {
        street += ' ${tags['addr:street']}';
      } else {
        street = tags['addr:street'].toString();
      }
    }
    if (street.isNotEmpty) addressParts.add(street);

    if (tags['addr:city'] != null) {
      addressParts.add(tags['addr:city'].toString());
    }

    if (tags['addr:state'] != null) {
      addressParts.add(tags['addr:state'].toString());
    } else if (tags['addr:province'] != null) {
      addressParts.add(tags['addr:province'].toString());
    }

    if (tags['addr:postcode'] != null) {
      addressParts.add(tags['addr:postcode'].toString());
    }

    if (tags['addr:country'] != null) {
      addressParts.add(tags['addr:country'].toString());
    }

    return addressParts.join(', ');
  }
}