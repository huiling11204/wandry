// ============================================
// HOME PAGE with 5-Button Bottom Navigation
// (Firebase connection made robust)
// ============================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wandry/screen/setting_page.dart';
import 'package:wandry/screen/search_page.dart';
import 'package:wandry/screen/explore_page.dart';
import 'package:wandry/screen/journey/my_trips_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Pages for bottom navigation
  late final List<Widget> _pages;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeContentPage(onNavigate: _navigateToTab),
      ExplorePage(), // UPDATED: Now uses the full-featured explore page
      SearchPage(), // OpenStreetMap search
      MyTripsPage(), // Journey
      SettingsPage(), // Setting
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Color(0xFF2196F3),
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 12,
          unselectedFontSize: 11,
          backgroundColor: Colors.white,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 26),
              activeIcon: Icon(Icons.home, size: 26),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined, size: 26),
              activeIcon: Icon(Icons.explore, size: 26),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _currentIndex == 2 ? Color(0xFF2196F3) : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search,
                  color: _currentIndex == 2 ? Colors.white : Colors.grey[600],
                  size: 24,
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.luggage_outlined, size: 26),
              activeIcon: Icon(Icons.luggage, size: 26),
              label: 'Journey',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined, size: 26),
              activeIcon: Icon(Icons.settings, size: 26),
              label: 'Setting',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// HOME CONTENT PAGE - Connected to Firestore (robust)
// ============================================
class HomeContentPage extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeContentPage({super.key, required this.onNavigate});

  @override
  _HomeContentPageState createState() => _HomeContentPageState();
}

class _HomeContentPageState extends State<HomeContentPage> {
  // We'll listen to auth changes to ensure current user is available
  User? _currentUser;
  late StreamSubscription<User?> _authSub;

  String userName = '';
  List<Map<String, dynamic>> userTrips = [];
  bool isLoading = true;
  bool hasTrips = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Popular destinations - static data for inspiration
  final List<Map<String, String>> popularDestinations = [
    {
      'name': 'Paris',
      'country': 'France',
      'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800',
      'description': 'City of Light'
    },
    {
      'name': 'Tokyo',
      'country': 'Japan',
      'image': 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800',
      'description': 'Modern meets Traditional'
    },
    {
      'name': 'Bali',
      'country': 'Indonesia',
      'image': 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800',
      'description': 'Island Paradise'
    },
    {
      'name': 'New York',
      'country': 'USA',
      'image': 'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=800',
      'description': 'The Big Apple'
    },
  ];

  // Travel tips - static content
  final List<Map<String, String>> travelTips = [
    {
      'title': 'Plan Your Budget',
      'description': 'Set a realistic budget for accommodation, food, and activities',
      'icon': '💰'
    },
    {
      'title': 'Best Time to Visit',
      'description': 'Research weather and peak seasons before booking',
      'icon': '🌤️'
    },
    {
      'title': 'Local Transportation',
      'description': 'Check public transport options and download local apps',
      'icon': '🚇'
    },
  ];

  @override
  void initState() {
    super.initState();

    // Listen for auth state so we load data when the user is ready
    _authSub = _auth.authStateChanges().listen((user) {
      _currentUser = user;
      if (user != null) {
        _loadUserData();
      } else {
        // No user: reset UI
        setState(() {
          userName = 'Traveler';
          userTrips = [];
          hasTrips = false;
          isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      if (_currentUser == null) {
        // shouldn't happen because listener triggers when user available,
        // but just in case:
        setState(() {
          userName = 'Traveler';
          userTrips = [];
          hasTrips = false;
        });
        return;
      }

      // Attempt to read user profile from either 'customer' or 'user' collection.
      // Also try several possible name field keys.
      DocumentSnapshot<Map<String, dynamic>>? profileDoc;
      try {
        profileDoc = await _firestore.collection('customer').doc(_currentUser!.uid).get();
      } catch (_) {
        profileDoc = null;
      }

      if (profileDoc == null || !profileDoc.exists) {
        // try alternate collection name
        try {
          profileDoc = await _firestore.collection('user').doc(_currentUser!.uid).get();
        } catch (_) {
          profileDoc = null;
        }
      }

      // Determine a proper display name by checking multiple possible fields
      String resolvedName = '';
      if (profileDoc != null && profileDoc.exists) {
        final data = profileDoc.data();
        if (data != null) {
          // check several possible fields for name
          final List<String> nameKeys = ['custName', 'name', 'fullName', 'displayName', 'username'];
          for (var key in nameKeys) {
            if (data.containsKey(key) && data[key] != null && data[key].toString().trim().isNotEmpty) {
              resolvedName = data[key].toString();
              break;
            }
          }
        }
      }

      // fallback to firebase user fields if profile didn't provide one
      if (resolvedName.isEmpty) {
        resolvedName = _currentUser?.displayName ??
            (_currentUser?.email != null ? _currentUser!.email!.split('@')[0] : 'Traveler');
      }

      userName = resolvedName;

      // Load user trips from Firestore (collection 'trips'), only if user id exists
      final userId = _currentUser!.uid;
      QuerySnapshot<Map<String, dynamic>>? snapshot;
      try {
        // If creationDate doesn't exist in some docs, orderBy may fail.
        // We'll attempt the ordered query first and if it fails, fall back to a non-ordered query.
        snapshot = await _firestore
            .collection('trips')
            .where('custProfileID', isEqualTo: userId)
            .orderBy('creationDate', descending: true)
            .limit(3)
            .get();
      } catch (e) {
        // fallback: query without orderBy (in case creationDate is missing or not indexed)
        snapshot = await _firestore
            .collection('trips')
            .where('custProfileID', isEqualTo: userId)
            .limit(3)
            .get();
      }

      userTrips = snapshot.docs.map((doc) {
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
          'creationDate': data['creationDate'],
          'lastUpdatedDate': data['lastUpdatedDate'],
        };
      }).toList();

      hasTrips = userTrips.isNotEmpty;
    } catch (e) {
      print('Error loading trips/profile: $e');
      hasTrips = false;
      userTrips = [];
      // keep userName fallback to displayName/email prefix
      userName = _currentUser?.displayName ?? _currentUser?.email?.split('@')[0] ?? 'Traveler';
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  String _getTripStatus(dynamic startDate) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadUserData,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $userName! 👋',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          children: [
                            TextSpan(text: 'Explore the '),
                            TextSpan(
                              text: 'Beautiful world!',
                              style: TextStyle(
                                color: Color(0xFFFF9800),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16).toSliver(),

              // Quick Action Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: QuickActionCard(
                          icon: Icons.add_location_alt,
                          title: 'Plan Trip',
                          color: Color(0xFF2196F3),
                          onTap: () {
                            // Navigate to My Trips to create new trip
                            widget.onNavigate(3);
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: QuickActionCard(
                          icon: Icons.near_me,
                          title: 'Explore Nearby',
                          color: Color(0xFF4CAF50),
                          onTap: () {
                            // Navigate to explore page
                            widget.onNavigate(1);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24).toSliver(),

              // User's Trips or Empty State
              if (hasTrips) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Trips',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onNavigate(3);
                          },
                          child: Text('View all'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      itemCount: userTrips.length,
                      itemBuilder: (context, index) {
                        return TripCard(
                          trip: userTrips[index],
                          status: _getTripStatus(userTrips[index]['startDate']),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 24).toSliver(),
              ] else ...[
                // Empty State for New Users
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.flight_takeoff,
                            size: 64,
                            color: Color(0xFF2196F3),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Start Your Journey',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No trips planned yet. Create your first personalized itinerary based on your preferences!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              widget.onNavigate(3);
                            },
                            icon: Icon(Icons.add),
                            label: Text('Create Trip'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              backgroundColor: Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24).toSliver(),
              ],

              // Popular Destinations
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Popular Destinations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12).toSliver(),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: popularDestinations.length,
                    itemBuilder: (context, index) {
                      return PopularDestinationCard(
                        destination: popularDestinations[index],
                        onTap: () {
                          // Navigate to search with pre-filled destination
                          widget.onNavigate(2);
                        },
                      );
                    },
                  ),
                ),
              ),

              SizedBox(height: 24).toSliver(),

              // Travel Tips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Travel Tips',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12).toSliver(),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return TravelTipCard(tip: travelTips[index]);
                    },
                    childCount: travelTips.length,
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// WIDGETS (unchanged visual structure)
// ============================================

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const QuickActionCard({super.key, 
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String status;

  const TripCard({super.key, required this.trip, required this.status});

  @override
  Widget build(BuildContext context) {
    final destination = '${trip['destinationCity']}, ${trip['destinationCountry']}';

    return GestureDetector(
      onTap: () {
        // Navigate to trip details
        Navigator.pushNamed(
          context,
          '/trip-details',
          arguments: trip['tripID'],
        );
      },
      child: Container(
        width: 280,
        margin: EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder with gradient
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2196F3),
                    Color(0xFF1976D2),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.place,
                      size: 48,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip['tripName'] ?? 'Untitled Trip',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          destination,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PopularDestinationCard extends StatelessWidget {
  final Map<String, String> destination;
  final VoidCallback onTap;

  const PopularDestinationCard({super.key, 
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Image.network(
                destination['image']!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.image, size: 40, color: Colors.grey[600]),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination['name']!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      destination['country']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TravelTipCard extends StatelessWidget {
  final Map<String, String> tip;

  const TravelTipCard({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tip['icon']!,
              style: TextStyle(fontSize: 24),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip['title']!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  tip['description']!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension SizedBoxSliver on SizedBox {
  SliverToBoxAdapter toSliver() {
    return SliverToBoxAdapter(child: this);
  }
}

// ============================================
// PLACEHOLDER PAGES (keep existing ones)
// ============================================

// class MyTripsPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('My Trips'),
//         automaticallyImplyLeading: false,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.add),
//             onPressed: () {
//               // Navigate to create trip page
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Create new trip')),
//               );
//             },
//           ),
//         ],
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.map, size: 64, color: Colors.grey),
//             SizedBox(height: 16),
//             Text(
//               'Your Trip Itineraries',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Padding(
//               padding: EdgeInsets.symmetric(horizontal: 40),
//               child: Text(
//                 'Create trips by setting your preferences, view generated itineraries, and modify them as needed',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.grey[600]),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF2196F3).withOpacity(0.2),
              child: Text(
                user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              user?.displayName ?? 'User',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                      (route) => false,
                );
              },
              icon: Icon(Icons.logout),
              label: Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}