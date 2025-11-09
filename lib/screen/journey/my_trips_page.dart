import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trip_basic_info_page.dart';
import 'trip_detail_page.dart';

class MyTripsPage extends StatefulWidget {
  const MyTripsPage({super.key});

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'All'; // All, Upcoming, Past

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedFilter = ['All', 'Upcoming', 'Past'][_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Add debug logging to _getTripsStream
  Stream<QuerySnapshot> _getTripsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user');
      return Stream.empty();
    }

    print('✓ Querying trips for user: ${user.uid}');

    Query query = _firestore
        .collection('trip')
        .where('userID', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _filterTrips(List<QueryDocumentSnapshot> trips) {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'Upcoming':
        return trips.where((trip) {
          final data = trip.data() as Map<String, dynamic>;
          final startDate = (data['startDate'] as Timestamp?)?.toDate();
          return startDate != null && startDate.isAfter(now);
        }).toList();

      case 'Past':
        return trips.where((trip) {
          final data = trip.data() as Map<String, dynamic>;
          final endDate = (data['endDate'] as Timestamp?)?.toDate();
          return endDate != null && endDate.isBefore(now);
        }).toList();

      default: // All
        return trips;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Journeys',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4A90E2),
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getTripsStream(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
              ),
            );
          }

          // Error state - but check if user is authenticated
          if (snapshot.hasError) {
            print('Error loading trips: ${snapshot.error}');

            // Check if user is authenticated
            final user = _auth.currentUser;
            if (user == null) {
              return _buildErrorState('Please log in to view your trips');
            }

            // If authenticated but still error, might be permission issue
            // Show empty state instead of scary error message
            return _buildEmptyState();
          }

          // No data or empty - this is normal when starting
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Filter trips based on selected tab
          final allTrips = snapshot.data!.docs;
          final filteredTrips = _filterTrips(allTrips);

          // Show empty state for filtered results
          if (filteredTrips.isEmpty) {
            return _buildFilteredEmptyState();
          }

          // Show trips list
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredTrips.length,
              itemBuilder: (context, index) {
                return _buildTripCard(filteredTrips[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripBasicInfoPage(),
            ),
          ).then((_) => setState(() {})); // Refresh after creating trip
        },
        backgroundColor: const Color(0xFF4A90E2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Plan Trip',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flight_takeoff,
                size: 60,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No trips yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start planning your next adventure!\nTap the button below to create your first trip.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripBasicInfoPage(),
                  ),
                ).then((_) => setState(() {}));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create Your First Trip',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    String message = '';
    IconData icon = Icons.search_off;

    switch (_selectedFilter) {
      case 'Upcoming':
        message = 'No upcoming trips.\nStart planning your next adventure!';
        icon = Icons.event_available;
        break;
      case 'Past':
        message = 'No past trips yet.\nCreate your first journey!';
        icon = Icons.history;
        break;
      default:
        message = 'No trips found.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Unable to load trips',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tripName = data['tripName'] as String? ?? 'Unnamed Trip';
    final destination = data['destination'] as String? ?? 'Unknown';
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final budgetLevel = data['budgetLevel'] as String? ?? 'Medium';

    // Calculate trip duration
    String duration = '';
    if (startDate != null && endDate != null) {
      final days = endDate.difference(startDate).inDays + 1;
      duration = '$days ${days == 1 ? 'day' : 'days'}';
    }

    // Format dates
    String dateRange = '';
    if (startDate != null && endDate != null) {
      dateRange = '${_formatDate(startDate)} - ${_formatDate(endDate)}';
    }

    // Determine trip status
    final now = DateTime.now();
    String status = 'Upcoming';
    Color statusColor = const Color(0xFF4CAF50);

    if (endDate != null && endDate.isBefore(now)) {
      status = 'Completed';
      statusColor = Colors.grey;
    } else if (startDate != null && startDate.isBefore(now) && endDate != null && endDate.isAfter(now)) {
      status = 'In Progress';
      statusColor = const Color(0xFFFF9800);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripDetailPage(tripId: doc.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tripName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Destination
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: Color(0xFF4A90E2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destination,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date range
              if (dateRange.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Color(0xFF4A90E2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateRange,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // Footer with duration and budget
              Row(
                children: [
                  if (duration.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Color(0xFF4A90E2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4A90E2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          budgetLevel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}