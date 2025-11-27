import 'package:flutter/material.dart';
import '../controller/home_data_controller.dart';
import '../utilities/home_constants.dart';
import '../widget/home_widgets.dart';
import 'setting_page.dart';
import 'search_page.dart';
import 'explore_page.dart';
import 'journey/my_trips_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
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
      ExplorePage(),
      SearchPage(),
      MyTripsPage(),
      SettingsPage(),
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
              offset: const Offset(0, -2),
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
          selectedItemColor: const Color(0xFF2196F3),
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 12,
          unselectedFontSize: 11,
          backgroundColor: Colors.white,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 26),
              activeIcon: Icon(Icons.home, size: 26),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined, size: 26),
              activeIcon: Icon(Icons.explore, size: 26),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _currentIndex == 2 ? const Color(0xFF2196F3) : Colors.grey[300],
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
            const BottomNavigationBarItem(
              icon: Icon(Icons.luggage_outlined, size: 26),
              activeIcon: Icon(Icons.luggage, size: 26),
              label: 'Journey',
            ),
            const BottomNavigationBarItem(
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
// HOME CONTENT PAGE - Refactored
// ============================================
class HomeContentPage extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeContentPage({super.key, required this.onNavigate});

  @override
  _HomeContentPageState createState() => _HomeContentPageState();
}

class _HomeContentPageState extends State<HomeContentPage> {
  late HomeDataController _controller;

  String userName = 'Traveler';
  List<Map<String, dynamic>> userTrips = [];
  bool isLoading = true;
  bool hasTrips = false;

  @override
  void initState() {
    super.initState();
    _controller = HomeDataController();
    _setupController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setupController() {
    _controller.onDataLoaded = (name, trips, hasTripData) {
      if (mounted) {
        setState(() {
          userName = name;
          userTrips = trips;
          hasTrips = hasTripData;
        });
      }
    };

    _controller.onLoadingChanged = (loading) {
      if (mounted) {
        setState(() {
          isLoading = loading;
        });
      }
    };

    _controller.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: () => _controller.loadUserData(),
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
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          children: const [
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

              const SizedBox(height: 16).toSliver(),

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
                          color: const Color(0xFF2196F3),
                          onTap: () => widget.onNavigate(3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: QuickActionCard(
                          icon: Icons.near_me,
                          title: 'Explore Nearby',
                          color: const Color(0xFF4CAF50),
                          onTap: () => widget.onNavigate(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24).toSliver(),

              // User's Trips or Empty State
              if (hasTrips) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Trips',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigate(3),
                          child: const Text('View all'),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: userTrips.length,
                      itemBuilder: (context, index) {
                        return TripCard(
                          trip: userTrips[index],
                          status: _controller.getTripStatus(
                            userTrips[index]['startDate'],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24).toSliver(),
              ] else ...[
                // Empty State
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.flight_takeoff,
                            size: 64,
                            color: Color(0xFF2196F3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Start Your Journey',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No trips planned yet. Create your first personalized itinerary based on your preferences!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => widget.onNavigate(3),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Trip'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24).toSliver(),
              ],

              // Popular Destinations
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
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
              const SizedBox(height: 12).toSliver(),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: HomeConstants.popularDestinations.length,
                    itemBuilder: (context, index) {
                      return PopularDestinationCard(
                        destination: HomeConstants.popularDestinations[index],
                        onTap: () => widget.onNavigate(2),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24).toSliver(),

              // Travel Tips
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
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
              const SizedBox(height: 12).toSliver(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return TravelTipCard(
                        tip: HomeConstants.travelTips[index],
                      );
                    },
                    childCount: HomeConstants.travelTips.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}