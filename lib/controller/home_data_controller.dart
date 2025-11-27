import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeDataController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Callbacks
  Function(String userName, List<Map<String, dynamic>> trips, bool hasTrips)? onDataLoaded;
  Function(bool isLoading)? onLoadingChanged;
  Function(String error)? onError;

  StreamSubscription<User?>? _authSubscription;

  void initialize() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        loadUserData();
      } else {
        // No user logged in
        onDataLoaded?.call('Traveler', [], false);
        onLoadingChanged?.call(false);
      }
    });
  }

  void dispose() {
    _authSubscription?.cancel();
  }

  Future<void> loadUserData() async {
    onLoadingChanged?.call(true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        onDataLoaded?.call('Traveler', [], false);
        onLoadingChanged?.call(false);
        return;
      }

      // Load user profile
      final userName = await _loadUserProfile(currentUser);

      // Load user trips
      final trips = await _loadUserTrips(currentUser.uid);

      onDataLoaded?.call(userName, trips, trips.isNotEmpty);
    } catch (e) {
      print('Error loading user data: $e');
      onError?.call(e.toString());

      // Fallback to basic info
      final displayName = _auth.currentUser?.displayName ??
          _auth.currentUser?.email?.split('@')[0] ??
          'Traveler';
      onDataLoaded?.call(displayName, [], false);
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  Future<String> _loadUserProfile(User user) async {
    // Try to load from customerProfile collection
    try {
      final profileQuery = await _firestore
          .collection('customerProfile')
          .where('firebaseUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        final data = profileQuery.docs.first.data();
        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';

        if (firstName.isNotEmpty) {
          return lastName.isNotEmpty ? '$firstName $lastName' : firstName;
        }
      }
    } catch (e) {
      print('Error loading customer profile: $e');
    }

    // Try alternate collection 'user'
    try {
      final userQuery = await _firestore
          .collection('user')
          .where('firebaseUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final data = userQuery.docs.first.data();

        // Check multiple possible name fields
        final nameKeys = ['name', 'fullName', 'displayName', 'username'];
        for (var key in nameKeys) {
          if (data.containsKey(key) &&
              data[key] != null &&
              data[key].toString().trim().isNotEmpty) {
            return data[key].toString();
          }
        }
      }
    } catch (e) {
      print('Error loading user document: $e');
    }

    // Fallback to Firebase user data
    return user.displayName ??
        (user.email != null ? user.email!.split('@')[0] : 'Traveler');
  }

  Future<List<Map<String, dynamic>>> _loadUserTrips(String userId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;

      // Try ordered query first
      try {
        snapshot = await _firestore
            .collection('trip')
            .where('userID', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();
      } catch (e) {
        // Fallback: query without orderBy if index doesn't exist
        print('Ordered query failed, using unordered: $e');
        snapshot = await _firestore
            .collection('trip')
            .where('userID', isEqualTo: userId)
            .limit(3)
            .get();
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'tripID': doc.id,
          'tripName': data['tripName'] ?? 'Untitled Trip',
          'tripDescription': data['tripDescription'] ?? '',
          'destinationCity': data['destinationCity'] ?? '',
          'destinationCountry': data['destinationCountry'] ?? '',
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'estimatedBudget': data['estimatedBudget'] ?? '',
          'createdAt': data['createdAt'],
          'lastUpdatedDate': data['lastUpdatedDate'],
        };
      }).toList();
    } catch (e) {
      print('Error loading trips: $e');
      return [];
    }
  }

  String getTripStatus(dynamic startDate) {
    if (startDate == null) return 'Upcoming';

    try {
      DateTime tripDate;
      if (startDate is Timestamp) {
        tripDate = startDate.toDate();
      } else if (startDate is DateTime) {
        tripDate = startDate;
      } else {
        return 'Upcoming';
      }

      final now = DateTime.now();
      final difference = tripDate.difference(now).inDays;

      if (difference < 0) {
        return 'Past Trip';
      } else if (difference == 0) {
        return 'Today!';
      } else if (difference <= 7) {
        return 'In $difference days';
      } else if (difference <= 30) {
        return 'In ${(difference / 7).ceil()} weeks';
      } else {
        return 'In ${(difference / 30).ceil()} months';
      }
    } catch (e) {
      return 'Upcoming';
    }
  }
}