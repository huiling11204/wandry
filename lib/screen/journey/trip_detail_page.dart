import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../model/trip_model.dart';
import '../../widget/accommodation_tab.dart';
import '../../widget/budget_tab.dart';
import '../../widget/itinerary_tab.dart';
import '../../widget/restaurant_tab.dart';
import '../../widget/resources_tab.dart';
import '../../widget/ml_insight_tab.dart';
import '../../utilities/currency_helper.dart';
import '../../controller/export_controller.dart';
import '../../widget/export_share_ui.dart';

class TripDetailPage extends StatefulWidget {
  final String tripId;

  const TripDetailPage({super.key, required this.tripId});

  @override
  State<TripDetailPage> createState() =>
      _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ExportController _exportController = ExportController(); // Instantiate the controller

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        title: const Text('Delete Trip'),
        content: const Text(
          'Are you sure you want to delete this trip? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Deleting trip...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        // Delete trip document
        await _firestore.collection('trip').doc(widget.tripId).delete();

        // Delete all itinerary items
        final items = await _firestore
            .collection('itineraryItem')
            .where('tripID', isEqualTo: widget.tripId)
            .get();

        final batch = _firestore.batch();
        for (var doc in items.docs) {
          batch.delete(doc.reference);
        }

        // Delete all accommodation
        final accommodations = await _firestore
            .collection('accommodation')
            .where('tripId', isEqualTo: widget.tripId)
            .get();

        for (var doc in accommodations.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete trip: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Trip not found'));
          }

          final trip = TripModel.fromFirestore(snapshot.data!);

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildAppBar(trip),
              ];
            },
            body: Column(
              children: [
                _buildTripInfoCard(trip),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ItineraryTab(tripId: widget.tripId),
                      RestaurantTab(tripId: widget.tripId),
                      BudgetTab(tripId: widget.tripId),
                      AccommodationTab(tripId: widget.tripId),
                      const ResourcesTab(),
                      MLInsightsTab(mlMetrics: trip.mlMetrics),
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

  Widget _buildAppBar(TripModel trip) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF2196F3),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          trip.tripName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black26,
              ),
            ],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
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
        // SHARE BUTTON - Shows bottom sheet
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Export & Share',
          onPressed: () {
            // Show beautiful bottom sheet with all options
            ExportShareBottomSheet.show(context, widget.tripId);
          },
        ),

        // POPUP MENU
        PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.file_download),  // Changed icon
                title: Text('Export & Share'),       // Changed text
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Trip'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
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
              // Show beautiful bottom sheet
              ExportShareBottomSheet.show(context, widget.tripId);
            } else if (value == 'edit') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit feature coming soon')),
              );
            }
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2196F3),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF2196F3),
            indicatorWeight: 3,
            isScrollable: true,
            padding: EdgeInsets.zero,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.list_alt, size: 20), text: 'Itinerary'),
              Tab(
                icon: Icon(Icons.restaurant_menu, size: 20),
                text: 'Restaurants',
              ),
              Tab(
                icon: Icon(Icons.account_balance_wallet, size: 20),
                text: 'Budget',
              ),
              Tab(icon: Icon(Icons.hotel, size: 20), text: 'Accommodation'),
              Tab(icon: Icon(Icons.map, size: 20), text: 'Resources'),
              Tab(icon: Icon(Icons.psychology, size: 20), text: 'ML Insights'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripInfoCard(TripModel trip) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xFF2196F3),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${trip.destinationCity}, ${trip.destinationCountry}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('MMM d').format(trip.startDate)} - ${DateFormat('MMM d, y').format(trip.endDate)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${trip.durationInDays} days',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          if (trip.totalEstimatedBudgetMYR != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[50]!, Colors.green[100]!],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Total Estimated Budget',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          'RM ${trip.totalEstimatedBudgetMYR!.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.green[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        if (trip.totalEstimatedBudgetLocal != null &&
                            trip.destinationCurrency != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '≈',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            CurrencyHelper.formatLocalCurrency(
                              trip.totalEstimatedBudgetLocal!,
                              trip.destinationCurrency!,
                            ),
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (trip.features != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: trip.features!.map((feature) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    CurrencyHelper.getFeatureLabel(feature),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}