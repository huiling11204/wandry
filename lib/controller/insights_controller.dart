// Controller for Insights & Analytics tab - generates booking links with pre-filled data
import 'package:intl/intl.dart';

class InsightsController {
  /// Generate booking links for a destination
  BookingLinks generateBookingLinks({
    required String city,
    required String country,
    required DateTime startDate,
    required DateTime endDate,
    int travelers = 2,
  }) {
    final destination = Uri.encodeComponent('$city, $country');
    final cityOnly = Uri.encodeComponent(city);
    final countryOnly = Uri.encodeComponent(country);

    // Date formats
    final checkIn = DateFormat('yyyy-MM-dd').format(startDate);
    final checkOut = DateFormat('yyyy-MM-dd').format(endDate);

    return BookingLinks(
      // Tours & Activities
      viator: 'https://www.viator.com/searchResults/all?text=$destination',
      getYourGuide: 'https://www.getyourguide.com/s/?q=$destination',
      klook: 'https://www.klook.com/search/?query=$destination',

      // Flights -Skyscanner to homepage (prefill URLs are unreliable)
      googleFlights: 'https://www.google.com/travel/flights?q=flights+to+$cityOnly',
      skyscanner: 'https://www.skyscanner.com/',  // Fixed: Go to homepage
      kayak: 'https://www.kayak.com/flights?destinations=$cityOnly',

      // Car Rental : Go to homepage (prefill URLs often break)
      rentalCars: 'https://www.rentalcars.com/',
      kayakCars: 'https://www.kayak.com/cars',

      // Transportation
      rome2rio: 'https://www.rome2rio.com/map/$countryOnly/$cityOnly',
      grab: _getGrabLink(country, city),
      uber: 'https://m.uber.com/looking',

      // Maps
      googleMaps: 'https://www.google.com/maps/place/$destination',
      offlineMap: 'https://www.google.com/maps/place/$destination',
    );
  }

  /// Get Grab link (works in Southeast Asia)
  String _getGrabLink(String country, String city) {
    final grabCountries = ['Malaysia', 'Singapore', 'Thailand', 'Indonesia', 'Vietnam', 'Philippines', 'Cambodia', 'Myanmar'];
    final countryLower = country.toLowerCase();

    for (final c in grabCountries) {
      if (countryLower.contains(c.toLowerCase())) {
        return 'https://grab.onelink.me/2695613898?pid=website&c=SG_home_topnav';
      }
    }
    return 'https://grab.onelink.me/2695613898?pid=website&c=SG_home_topnav';
  }

  /// Get useful apps for a country
  List<UsefulApp> getUsefulApps(String country) {
    final apps = <UsefulApp>[];
    final countryLower = country.toLowerCase();

    // Universal apps
    apps.add(UsefulApp(
      name: 'Google Maps',
      description: 'Navigation & offline maps',
      icon: '🗺️',
      androidUrl: 'https://play.google.com/store/apps/details?id=com.google.android.apps.maps',
      iosUrl: 'https://apps.apple.com/app/google-maps/id585027354',
    ));

    apps.add(UsefulApp(
      name: 'Google Translate',
      description: 'Camera & voice translation',
      icon: '🌐',
      androidUrl: 'https://play.google.com/store/apps/details?id=com.google.android.apps.translate',
      iosUrl: 'https://apps.apple.com/app/google-translate/id414706506',
    ));

    // Region-specific apps
    if (_isInGrabRegion(countryLower)) {
      apps.add(UsefulApp(
        name: 'Grab',
        description: 'Rides, food & deliveries',
        icon: '🚗',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.grabtaxi.passenger',
        iosUrl: 'https://apps.apple.com/app/grab-app/id647268330',
      ));
    }

    if (countryLower.contains('japan')) {
      apps.add(UsefulApp(
        name: 'Japan Transit',
        description: 'Train schedules & routes',
        icon: '🚃',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.navitime.inbound.walk',
        iosUrl: 'https://apps.apple.com/app/japan-travel-navitime/id1042363491',
      ));
      apps.add(UsefulApp(
        name: 'PayPay',
        description: 'Mobile payments in Japan',
        icon: '💳',
        androidUrl: 'https://play.google.com/store/apps/details?id=jp.ne.paypay.android.app',
        iosUrl: 'https://apps.apple.com/app/paypay/id1435783608',
      ));
    }

    if (countryLower.contains('korea')) {
      apps.add(UsefulApp(
        name: 'KakaoMap',
        description: 'Best navigation in Korea',
        icon: '🗺️',
        androidUrl: 'https://play.google.com/store/apps/details?id=net.daum.android.map',
        iosUrl: 'https://apps.apple.com/app/kakaomap/id304608425',
      ));
      apps.add(UsefulApp(
        name: 'Papago',
        description: 'Korean translation (better than Google)',
        icon: '🦜',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.naver.labs.translator',
        iosUrl: 'https://apps.apple.com/app/papago/id1147874819',
      ));
    }

    if (countryLower.contains('china')) {
      apps.add(UsefulApp(
        name: 'WeChat',
        description: 'Essential for China - messaging & payments',
        icon: '💬',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.tencent.mm',
        iosUrl: 'https://apps.apple.com/app/wechat/id414478124',
      ));
      apps.add(UsefulApp(
        name: 'DiDi',
        description: 'Ride-hailing (Uber of China)',
        icon: '🚕',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.sdu.didi.psnger',
        iosUrl: 'https://apps.apple.com/app/didi/id554499054',
      ));
    }

    if (countryLower.contains('indonesia')) {
      apps.add(UsefulApp(
        name: 'Gojek',
        description: 'Indonesian super-app',
        icon: '🛵',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.gojek.app',
        iosUrl: 'https://apps.apple.com/app/gojek/id944875099',
      ));
    }

    if (countryLower.contains('united states') || countryLower.contains('usa') || countryLower.contains('america')) {
      apps.add(UsefulApp(
        name: 'Uber',
        description: 'Ride-hailing',
        icon: '🚗',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.ubercab',
        iosUrl: 'https://apps.apple.com/app/uber/id368677368',
      ));
      apps.add(UsefulApp(
        name: 'Lyft',
        description: 'Alternative ride-hailing',
        icon: '🚙',
        androidUrl: 'https://play.google.com/store/apps/details?id=me.lyft.android',
        iosUrl: 'https://apps.apple.com/app/lyft/id529379082',
      ));
    }

    if (countryLower.contains('united kingdom') || countryLower.contains('uk') || countryLower.contains('england')) {
      apps.add(UsefulApp(
        name: 'Citymapper',
        description: 'Best for London transport',
        icon: '🚇',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.citymapper.app.release',
        iosUrl: 'https://apps.apple.com/app/citymapper/id469463298',
      ));
    }

    if (countryLower.contains('india')) {
      apps.add(UsefulApp(
        name: 'Ola',
        description: 'Indian ride-hailing',
        icon: '🚗',
        androidUrl: 'https://play.google.com/store/apps/details?id=com.olacabs.customer',
        iosUrl: 'https://apps.apple.com/app/ola-cabs/id539179365',
      ));
    }

    // Travel essentials
    apps.add(UsefulApp(
      name: 'XE Currency',
      description: 'Currency converter',
      icon: '💱',
      androidUrl: 'https://play.google.com/store/apps/details?id=com.xe.currency',
      iosUrl: 'https://apps.apple.com/app/xe-currency/id315241195',
    ));

    apps.add(UsefulApp(
      name: 'TripAdvisor',
      description: 'Reviews & recommendations',
      icon: '⭐',
      androidUrl: 'https://play.google.com/store/apps/details?id=com.tripadvisor.tripadvisor',
      iosUrl: 'https://apps.apple.com/app/tripadvisor/id284876795',
    ));

    return apps;
  }

  bool _isInGrabRegion(String country) {
    final grabCountries = ['malaysia', 'singapore', 'thailand', 'indonesia', 'vietnam', 'philippines', 'cambodia', 'myanmar'];
    return grabCountries.any((c) => country.contains(c));
  }
}

// ============================================
// DATA CLASSES
// ============================================

class BookingLinks {
  // Tours & Activities
  final String viator;
  final String getYourGuide;
  final String klook;

  // Flights
  final String googleFlights;
  final String skyscanner;
  final String kayak;

  // Car Rental
  final String rentalCars;
  final String kayakCars;

  // Transportation
  final String rome2rio;
  final String grab;
  final String uber;

  // Maps
  final String googleMaps;
  final String offlineMap;

  const BookingLinks({
    required this.viator,
    required this.getYourGuide,
    required this.klook,
    required this.googleFlights,
    required this.skyscanner,
    required this.kayak,
    required this.rentalCars,
    required this.kayakCars,
    required this.rome2rio,
    required this.grab,
    required this.uber,
    required this.googleMaps,
    required this.offlineMap,
  });
}

class UsefulApp {
  final String name;
  final String description;
  final String icon;
  final String androidUrl;
  final String iosUrl;

  const UsefulApp({
    required this.name,
    required this.description,
    required this.icon,
    required this.androidUrl,
    required this.iosUrl,
  });
}