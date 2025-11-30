// lib/pages/trip_detail_page.dart
// UPDATED: Replaced Resources tab with Trip Essentials, replaced ML Insights with Explore & Insights
// Trip Essentials and Explore tabs are customized based on destination
// UPDATED: Changed all SnackBars and AlertDialogs to SweetAlert dialogs
// UPDATED: Changed 3-dot popup menu to SweetAlert-style bottom sheet

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:wandry/model/trip_model.dart';
import 'package:wandry/widget/accommodation_tab.dart';
import 'package:wandry/widget/budget_tab.dart';
import 'package:wandry/widget/itinerary_tab.dart';
import 'package:wandry/widget/restaurant_tab.dart';
import 'package:wandry/widget/trip_essentials_tab.dart';  // NEW
import 'package:wandry/widget/insights_analytics_tab.dart'; // NEW
import 'package:wandry/widget/sweet_alert_dialog.dart';
import 'package:wandry/utilities/currency_helper.dart';
import 'package:wandry/controller/export_controller.dart';
import 'package:wandry/widget/export_share_ui.dart';
import 'edit_trip_preferences_page.dart';

class TripDetailPage extends StatefulWidget {
  final String tripId;

  const TripDetailPage({super.key, required this.tripId});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ExportController _exportController = ExportController();

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
    final confirm = await SweetAlertDialog.confirm(
      context: context,
      title: 'Delete Trip',
      subtitle: 'Are you sure you want to delete this trip? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirm == true) {
      try {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);

        // Show info dialog for deleting progress
        SweetAlertDialog.show(
          context: context,
          type: SweetAlertType.info,
          title: 'Deleting Trip',
          subtitle: 'Please wait while we delete your trip...',
          confirmText: 'OK',
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

        // Also try to delete by document ID (your structure)
        try {
          await _firestore.collection('accommodation').doc(widget.tripId).delete();
        } catch (e) {
          // Ignore if doesn't exist
        }

        await batch.commit();

        if (mounted) {
          // Dismiss any existing dialog first
          Navigator.of(context).popUntil((route) => route.isFirst);

          SweetAlertDialog.success(
            context: context,
            title: 'Deleted!',
            subtitle: 'Trip deleted successfully.',
          );
        }
      } catch (e) {
        if (mounted) {
          SweetAlertDialog.error(
            context: context,
            title: 'Delete Failed',
            subtitle: 'Failed to delete trip: $e',
          );
        }
      }
    }
  }

  // Open edit preferences page
  void _openEditPage(Map<String, dynamic> tripData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTripPreferencesPage(
          tripId: widget.tripId,
          tripData: tripData,
        ),
      ),
    );

    // If changes were made, show a success message
    if (result == true && mounted) {
      SweetAlertDialog.success(
        context: context,
        title: 'Updated!',
        subtitle: 'Trip updated successfully!',
      );
    }
  }

  // NEW: Show sweet alert style options bottom sheet
  void _showOptionsBottomSheet(Map<String, dynamic> tripData) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildOptionsSheet(tripData),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionsSheet(Map<String, dynamic> tripData) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.settings,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Trip Options',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'What would you like to do?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Option buttons
                _buildOptionTile(
                  icon: Icons.edit_outlined,
                  iconColor: Colors.blue[600]!,
                  bgColor: Colors.blue[50]!,
                  title: 'Edit Trip Preferences',
                  subtitle: 'Modify dates, destination & settings',
                  onTap: () {
                    Navigator.pop(context);
                    _openEditPage(tripData);
                  },
                ),
                const SizedBox(height: 12),

                _buildOptionTile(
                  icon: Icons.ios_share_outlined,
                  iconColor: Colors.green[600]!,
                  bgColor: Colors.green[50]!,
                  title: 'Export & Share',
                  subtitle: 'Download or share your trip plan',
                  onTap: () {
                    Navigator.pop(context);
                    ExportShareBottomSheet.show(context, widget.tripId);
                  },
                ),
                const SizedBox(height: 12),

                _buildOptionTile(
                  icon: Icons.delete_outline,
                  iconColor: Colors.red[600]!,
                  bgColor: Colors.red[50]!,
                  title: 'Delete Trip',
                  subtitle: 'Permanently remove this trip',
                  onTap: () {
                    Navigator.pop(context);
                    _deleteTrip();
                  },
                  isDanger: true,
                ),

                const SizedBox(height: 20),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDanger ? Colors.red[50]!.withOpacity(0.5) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDanger ? Colors.red[100]! : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDanger ? Colors.red[700] : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: isDanger ? Colors.red[300] : Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
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

          // Get raw tripData for edit functionality
          final tripData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final trip = TripModel.fromFirestore(snapshot.data!);

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildAppBar(trip, tripData),
              ];
            },
            body: Column(
              children: [
                _buildTripInfoCard(trip, tripData),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ItineraryTab(tripId: widget.tripId),
                      RestaurantTab(tripId: widget.tripId),
                      BudgetTab(tripId: widget.tripId),
                      AccommodationTab(tripId: widget.tripId),
                      // NEW: Trip Essentials (replaces Resources)
                      TripEssentialsTab(
                        tripId: widget.tripId,
                        destinationCity: trip.destinationCity,
                        destinationCountry: trip.destinationCountry,
                        destinationCurrency: trip.destinationCurrency,
                      ),
                      // NEW: Explore & Insights (replaces ML Insights, but includes ML at bottom)
                      InsightsAnalyticsTab(
                        tripId: widget.tripId,
                        destinationCity: trip.destinationCity,
                        destinationCountry: trip.destinationCountry,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                      ),
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

  Widget _buildAppBar(TripModel trip, Map<String, dynamic> tripData) {
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
        // Edit button - prominent in app bar
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Edit Trip',
          onPressed: () => _openEditPage(tripData),
        ),

        // SHARE BUTTON - Shows bottom sheet
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Export & Share',
          onPressed: () {
            // Show beautiful bottom sheet with all options
            ExportShareBottomSheet.show(context, widget.tripId);
          },
        ),

        // MORE OPTIONS BUTTON - Sweet Alert Style Bottom Sheet
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: 'More Options',
          onPressed: () => _showOptionsBottomSheet(tripData),
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
              // UPDATED: Changed from Resources to Essentials
              Tab(icon: Icon(Icons.emergency, size: 20), text: 'Essentials'),
              // UPDATED: Changed from ML Insights to Explore
              Tab(icon: Icon(Icons.insights, size: 20), text: 'Insights'),
            ],
          ),
        ),
      ),
    );
  }

  // Updated: Added tripData parameter and edit button
  Widget _buildTripInfoCard(TripModel trip, Map<String, dynamic> tripData) {
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
              // Quick edit button
              TextButton.icon(
                onPressed: () => _openEditPage(tripData),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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

          // Data quality indicator
          if (trip.hasLimitedData) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.dataQualityMessage ?? 'Some data may be limited for this area.',
                      style: TextStyle(fontSize: 11, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],

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

          // Display trip styles/destination types
          if (trip.destinationTypes != null && trip.destinationTypes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: trip.destinationTypes!.map((type) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getTypeDisplay(type),
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

  // Helper to get type display with emoji
  String _getTypeDisplay(String type) {
    const typeDisplay = {
      'relaxing': '🏖️ Relaxing',
      'historical': '🏛️ Historical',
      'adventure': '🎢 Adventure',
      'shopping': '🛍️ Shopping',
      'spiritual': '⛩️ Spiritual',
      'entertainment': '🎭 Entertainment',
    };
    return typeDisplay[type.toLowerCase()] ?? type;
  }
}