import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../backend/interaction_tracker.dart';
import '../../widget/trip_rating_dialog.dart';

class TripDetailPage extends StatefulWidget {
  final String tripId;

  const TripDetailPage({super.key, required this.tripId});

  @override
  _TripDetailPageState createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Trip'),
        content: Text('Are you sure you want to delete this trip? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete trip document
        await _firestore.collection('trip').doc(widget.tripId).delete();

        // Delete associated itinerary items
        final items = await _firestore
            .collection('itineraryItem')
            .where('tripID', isEqualTo: widget.tripId)
            .get();

        final batch = _firestore.batch();
        for (var doc in items.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trip deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete trip'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Add this method to _TripDetailPageState in TripDetailPage
  Future<void> _markTripAsCompleted() async {
    try {
      final tripDoc = await _firestore.collection('trip').doc(widget.tripId).get();
      final tripData = tripDoc.data() as Map<String, dynamic>;

      // Get visited places from itinerary
      final itinerarySnapshot = await _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: widget.tripId)
          .get();

      List<String> visitedPlaces = itinerarySnapshot.docs
          .map((doc) => doc.data()['locationID'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      // Update trip status
      await _firestore.collection('trip').doc(widget.tripId).update({
        'status': 'completed',
        'completedDate': FieldValue.serverTimestamp(),
      });

      // 🆕 Track trip completion
      await InteractionTracker().trackTripCompletion(
        tripId: widget.tripId,
        tripName: tripData['tripName'] ?? 'Trip',
        destination: tripData['destination'] ?? '',
        startDate: (tripData['startDate'] as Timestamp).toDate(),
        endDate: (tripData['endDate'] as Timestamp).toDate(),
        daysCount: visitedPlaces.length,
      );

      // Show rating dialog
      if (mounted) {
        await TripRatingDialog.show(
          context,
          tripId: widget.tripId,
          tripName: tripData['tripName'] ?? 'Trip',
          destination: tripData['destination'] ?? '',
          startDate: (tripData['startDate'] as Timestamp).toDate(),
          endDate: (tripData['endDate'] as Timestamp).toDate(),
          visitedPlaces: visitedPlaces,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('trip').doc(widget.tripId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Trip not found'));
          }

          final trip = snapshot.data!.data() as Map<String, dynamic>;
          final startDate = (trip['startDate'] as Timestamp).toDate();
          final endDate = (trip['endDate'] as Timestamp).toDate();

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: Color(0xFF2196F3),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      trip['tripName'] ?? 'Trip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2196F3),
                            Color(0xFF1976D2),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.place,
                          size: 80,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    if (trip['status'] != 'completed')
                      IconButton(
                        icon: Icon(Icons.check_circle_outline),
                        tooltip: 'Mark as Completed',
                        onPressed: _markTripAsCompleted,
                      ),
                    IconButton(
                      icon: Icon(Icons.share),
                      onPressed: () {
                        // TODO: Implement share
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Share feature coming soon')),
                        );
                      },
                    ),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'export',
                          child: ListTile(
                            leading: Icon(Icons.picture_as_pdf),
                            title: Text('Export to PDF'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Edit Trip'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete', style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteTrip();
                        } else if (value == 'export') {
                          // TODO: Implement PDF export (Phase 7)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('PDF export coming in Phase 7')),
                          );
                        } else if (value == 'edit') {
                          // TODO: Implement edit
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Edit feature coming soon')),
                          );
                        }
                      },
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: Size.fromHeight(50),
                    child: Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Color(0xFF2196F3),
                        unselectedLabelColor: Colors.grey[600],
                        indicatorColor: Color(0xFF2196F3),
                        tabs: [
                          Tab(text: 'Itinerary'),
                          Tab(text: 'Accommodation'),
                          Tab(text: 'Resources'),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: Column(
              children: [
                // Trip info card
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Color(0xFF2196F3), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${trip['destinationCity']}, ${trip['destinationCountry']}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                          SizedBox(width: 8),
                          Text(
                            '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                          SizedBox(width: 8),
                          Text(
                            '${endDate.difference(startDate).inDays + 1} days',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      if (trip['tripDescription']?.isNotEmpty ?? false) ...[
                        SizedBox(height: 12),
                        Text(
                          trip['tripDescription'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildItineraryTab(),
                      _buildAccommodationTab(),
                      _buildResourcesTab(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildItineraryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: widget.tripId)
          .orderBy('dayNumber')
          .orderBy('orderInDay')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No itinerary items yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'ML recommendations will appear here in Phase 3',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final items = snapshot.data!.docs;
        final groupedByDay = <int, List<DocumentSnapshot>>{};

        for (var item in items) {
          final data = item.data() as Map<String, dynamic>;
          final day = data['dayNumber'] as int;
          groupedByDay.putIfAbsent(day, () => []).add(item);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: groupedByDay.length,
          itemBuilder: (context, index) {
            final day = groupedByDay.keys.elementAt(index);
            final dayItems = groupedByDay[day]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Day $day',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...dayItems.map((item) {
                  final data = item.data() as Map<String, dynamic>;
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      title: Text(
                        '${data['startTime']} - ${data['endTime']}',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        data['notes'] ?? 'No description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.more_vert),
                        onPressed: () {
                          // TODO: Implement edit/delete
                        },
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAccommodationTab() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Accommodation Recommendations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Hotel suggestions will be integrated in Phase 7 using Amadeus API',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.flight, color: Color(0xFF2196F3)),
            title: Text('Flights'),
            subtitle: Text('Search for flights to your destination'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Open flight search
            },
          ),
        ),
        SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.hotel, color: Color(0xFF2196F3)),
            title: Text('Accommodation'),
            subtitle: Text('Find hotels and places to stay'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Open hotel search
            },
          ),
        ),
        SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.directions_car, color: Color(0xFF2196F3)),
            title: Text('Transportation'),
            subtitle: Text('Explore local transport options'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Open transport info
            },
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Coming in Phase 7',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}