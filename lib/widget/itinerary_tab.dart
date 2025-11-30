// lib/widget/itinerary_tab.dart
// FIXED VERSION: Resolved RenderFlex overflow issues during reordering
// Enhanced UI with better spacing and responsive layouts
// Added SweetAlert confirmation before external links

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../model/itinerary_item_model.dart';
import '../utilities/icon_helper.dart';
import '../controller/itinerary_edit_controller.dart';
import 'edit_attraction_bottom_sheet.dart';
import 'destination_type_selector_widget.dart';
import 'sweet_alert_dialog.dart';

class ItineraryTab extends StatefulWidget {
  final String tripId;

  const ItineraryTab({super.key, required this.tripId});

  @override
  State<ItineraryTab> createState() => _ItineraryTabState();
}

class _ItineraryTabState extends State<ItineraryTab> {
  final ItineraryEditController _editController = ItineraryEditController();

  // Track which day is in edit/reorder mode
  int? _reorderingDay;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    _editController.onLoadingChanged = (isLoading) {
      if (mounted) setState(() => _isProcessing = isLoading);
    };

    _editController.onError = (message) {
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Oops!',
          subtitle: message,
        );
      }
    };

    _editController.onSuccess = (message) {
      if (mounted) {
        SweetAlertDialog.success(
          context: context,
          title: 'Success!',
          subtitle: message,
        );
      }
    };
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('trip').doc(widget.tripId).snapshots(),
      builder: (context, tripSnapshot) {
        if (!tripSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        final tripData = tripSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        DateTime? startDate;
        if (tripData['startDate'] is Timestamp) {
          startDate = (tripData['startDate'] as Timestamp).toDate();
        }

        final destinationTypes = (tripData['destinationTypesApplied'] as List?)?.cast<String>() ??
            (tripData['destinationTypes'] as List?)?.cast<String>() ??
            [];

        final city = tripData['city'] ?? tripData['destinationCity'] ?? '';
        final country = tripData['country'] ?? tripData['destinationCountry'] ?? '';

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('accommodation').doc(widget.tripId).snapshots(),
          builder: (context, accommodationSnapshot) {
            Map<String, dynamic>? accommodationData;
            if (accommodationSnapshot.hasData && accommodationSnapshot.data!.exists) {
              final accDoc = accommodationSnapshot.data!.data() as Map<String, dynamic>;
              if (accDoc['recommendedAccommodation'] != null) {
                accommodationData = accDoc['recommendedAccommodation'];
              } else if ((accDoc['accommodations'] as List?)?.isNotEmpty ?? false) {
                accommodationData = accDoc['accommodations'][0];
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itineraryItem')
                  .where('tripID', isEqualTo: widget.tripId)
                  .orderBy('dayNumber')
                  .orderBy('orderInDay')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No itinerary items yet'));
                }

                final items = snapshot.data!.docs;
                final groupedByDay = <int, List<DocumentSnapshot>>{};
                final skippedItems = <DocumentSnapshot>[];

                for (var item in items) {
                  final data = item.data() as Map<String, dynamic>;
                  if (data['isSkipped'] == true) {
                    skippedItems.add(item);
                    continue;
                  }
                  final day = data['dayNumber'] as int;
                  groupedByDay.putIfAbsent(day, () => []).add(item);
                }

                final hasSkippedItems = skippedItems.isNotEmpty;
                final totalItems = groupedByDay.length + 1 + (hasSkippedItems ? 1 : 0);

                return Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: totalItems,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildTripStyleHeader(context, destinationTypes, tripData);
                        }

                        if (hasSkippedItems && index == totalItems - 1) {
                          return _buildSkippedSection(context, skippedItems, widget.tripId);
                        }

                        final dayIndex = index - 1;
                        final day = groupedByDay.keys.elementAt(dayIndex);
                        final dayItems = groupedByDay[day]!;

                        String dateString = '';
                        if (startDate != null) {
                          final date = startDate.add(Duration(days: day - 1));
                          dateString = DateFormat('EEEE, d MMM').format(date);
                        }

                        Map<String, dynamic>? dayWeather;
                        for (var item in dayItems) {
                          final data = item.data() as Map<String, dynamic>;
                          if (data['weather'] != null) {
                            dayWeather = data['weather'];
                            break;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDayHeader(
                              context,
                              day,
                              dateString,
                              dayItems.length,
                              dayWeather,
                              accommodationData,
                            ),
                            if (day == 1 && accommodationData != null)
                              _buildAccommodationEntry(context, accommodationData),
                            _buildDayItemsList(
                              context,
                              day,
                              dayItems,
                              city,
                              country,
                              accommodationData,
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                    if (_isProcessing)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Updating itinerary...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDayItemsList(
      BuildContext context,
      int day,
      List<DocumentSnapshot> dayItems,
      String city,
      String country,
      Map<String, dynamic>? accommodationData,
      ) {
    final isReordering = _reorderingDay == day;

    if (isReordering) {
      return _buildReorderableList(context, day, dayItems, city, country, accommodationData);
    } else {
      return Column(
        children: dayItems.map((item) {
          final data = item.data() as Map<String, dynamic>;
          return _buildItineraryCard(context, data, item.id, city, country);
        }).toList(),
      );
    }
  }

  /// FIXED: Enhanced reorderable list with better UI and no overflow
  Widget _buildReorderableList(
      BuildContext context,
      int day,
      List<DocumentSnapshot> dayItems,
      String city,
      String country,
      Map<String, dynamic>? accommodationData,
      ) {
    return Column(
      children: [
        // Enhanced instructions banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple[50]!, Colors.purple[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple[300]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.drag_indicator, color: Colors.purple[700], size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reorder Mode Active',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[900],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hold and drag attractions to reorder',
                          style: TextStyle(fontSize: 12, color: Colors.purple[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _reorderingDay = null),
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('Done Reordering'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Reorderable list with fixed layout
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dayItems.length,
          onReorder: (oldIndex, newIndex) {
            _handleReorder(context, day, dayItems, oldIndex, newIndex, accommodationData);
          },
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final double elevation = Tween<double>(begin: 0, end: 12).evaluate(animation);
                final double scale = Tween<double>(begin: 1.0, end: 1.02).evaluate(animation);
                return Transform.scale(
                  scale: scale,
                  child: Material(
                    elevation: elevation,
                    borderRadius: BorderRadius.circular(16),
                    shadowColor: Colors.purple.withOpacity(0.4),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final item = dayItems[index];
            final data = item.data() as Map<String, dynamic>;
            final category = data['category'] as String? ?? 'attraction';
            final isMeal = ['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack']
                .contains(category.toLowerCase());

            return _buildReorderableItem(
              key: ValueKey(item.id),
              data: data,
              itemId: item.id,
              city: city,
              country: country,
              isMeal: isMeal,
              index: index,
            );
          },
        ),
      ],
    );
  }

  /// FIXED: Completely redesigned reorderable item to prevent overflow
  Widget _buildReorderableItem({
    required Key key,
    required Map<String, dynamic> data,
    required String itemId,
    required String city,
    required String country,
    required bool isMeal,
    required int index,
  }) {
    final category = data['category'] as String? ?? 'attraction';
    final categoryColor = IconHelper.getCategoryColor(category);
    final title = data['title'] ?? 'Activity';
    final startTime = data['startTime'] ?? '';
    final endTime = data['endTime'] ?? '';
    final distanceKm = data['distanceKm'];

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMeal ? Colors.grey[300]! : Colors.purple.withOpacity(0.3),
              width: isMeal ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isMeal ? Colors.grey : Colors.purple).withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: Drag handle or lock indicator
                  if (!isMeal)
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple[50]!, Colors.purple[100]!],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.drag_indicator,
                              color: Colors.purple[400],
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'DRAG',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[400],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: Colors.grey[400],
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'FIXED',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Main content area - FIXED: Using Expanded properly
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title row with category icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  IconHelper.getCategoryIcon(category),
                                  color: categoryColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isMeal ? Colors.grey[600] : Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Time and distance - FIXED: Wrap instead of Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              // Time chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$startTime - $endTime',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                              // Distance chip (if available)
                              if (distanceKm != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.directions_car, size: 12, color: Colors.blue[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$distanceKm km',
                                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                                      ),
                                    ],
                                  ),
                                ),
                              // Meal locked indicator
                              if (isMeal)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.restaurant, size: 12, color: Colors.orange[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Meal time locked',
                                        style: TextStyle(fontSize: 11, color: Colors.orange[700]),
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

                  // Right side: Reorder indicator
                  if (!isMeal)
                    Container(
                      width: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple[50]!, Colors.purple[100]!],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swap_vert, size: 20, color: Colors.purple[400]),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handle reorder action with distance validation
  Future<void> _handleReorder(
      BuildContext context,
      int day,
      List<DocumentSnapshot> dayItems,
      int oldIndex,
      int newIndex,
      Map<String, dynamic>? accommodationData,
      ) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    if (oldIndex == newIndex) return;

    final movedItem = dayItems[oldIndex];
    final movedData = movedItem.data() as Map<String, dynamic>;
    final movedCategory = movedData['category'] as String? ?? 'attraction';

    if (['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack'].contains(movedCategory.toLowerCase())) {
      await SweetAlertDialog.warning(
        context: context,
        title: 'Cannot Move Meals',
        subtitle: 'Meal times are fixed to maintain your schedule. Only attractions can be reordered.',
      );
      return;
    }

    final distanceInfo = _calculateDistanceImpact(
      dayItems,
      oldIndex,
      newIndex,
      accommodationData,
    );

    final confirmed = await RouteWarningDialog.show(
      context: context,
      itemName: movedData['title'] ?? 'Activity',
      addedDistance: distanceInfo['addedDistance'],
      addedTime: distanceInfo['addedTime'],
      oldDistance: distanceInfo['oldDistance'],
      newDistance: distanceInfo['newDistance'],
    );

    if (confirmed != true) return;

    await _performReorder(day, dayItems, oldIndex, newIndex);
  }

  Map<String, dynamic> _calculateDistanceImpact(
      List<DocumentSnapshot> dayItems,
      int oldIndex,
      int newIndex,
      Map<String, dynamic>? accommodationData,
      ) {
    double oldTotalDistance = 0;
    double newTotalDistance = 0;

    List<Map<String, double>> coords = [];

    if (accommodationData != null) {
      final hotelCoords = accommodationData['coordinates'] as Map<String, dynamic>?;
      if (hotelCoords != null) {
        final lat = (hotelCoords['lat'] ?? hotelCoords['latitude']);
        final lng = (hotelCoords['lng'] ?? hotelCoords['longitude']);
        if (lat != null && lng != null) {
          coords.add({
            'lat': (lat is num) ? lat.toDouble() : 0.0,
            'lng': (lng is num) ? lng.toDouble() : 0.0,
          });
        }
      }
    }

    if (coords.isEmpty) {
      for (var item in dayItems) {
        final data = item.data() as Map<String, dynamic>;
        final itemCoords = data['coordinates'] as Map<String, dynamic>?;
        if (itemCoords != null) {
          final lat = itemCoords['lat'];
          final lng = itemCoords['lng'];
          if (lat != null && lng != null) {
            coords.add({
              'lat': (lat is num) ? lat.toDouble() : 0.0,
              'lng': (lng is num) ? lng.toDouble() : 0.0,
            });
            break;
          }
        }
      }
    }

    for (var item in dayItems) {
      final data = item.data() as Map<String, dynamic>;
      final itemCoords = data['coordinates'] as Map<String, dynamic>?;
      if (itemCoords != null) {
        final lat = itemCoords['lat'];
        final lng = itemCoords['lng'];
        coords.add({
          'lat': (lat is num) ? lat.toDouble() : 0.0,
          'lng': (lng is num) ? lng.toDouble() : 0.0,
        });
      } else {
        coords.add(coords.isNotEmpty ? coords.last : {'lat': 0.0, 'lng': 0.0});
      }
    }

    for (int i = 1; i < coords.length; i++) {
      if (coords[i]['lat'] != 0 && coords[i]['lng'] != 0 &&
          coords[i - 1]['lat'] != 0 && coords[i - 1]['lng'] != 0) {
        oldTotalDistance += _haversineDistance(
          coords[i - 1]['lat']!,
          coords[i - 1]['lng']!,
          coords[i]['lat']!,
          coords[i]['lng']!,
        );
      }
    }

    List<Map<String, double>> newCoords = [];
    if (coords.isNotEmpty) {
      newCoords.add(coords[0]);
    }

    int startOffset = accommodationData != null ? 1 : 0;
    if (coords.length <= startOffset) {
      return {
        'oldDistance': 0.0,
        'newDistance': 0.0,
        'addedDistance': 0.0,
        'addedTime': 0,
      };
    }

    List<Map<String, double>> itemCoords = [];
    for (int i = startOffset; i < coords.length; i++) {
      itemCoords.add(Map<String, double>.from(coords[i]));
    }

    if (oldIndex < itemCoords.length) {
      final movedCoord = itemCoords.removeAt(oldIndex);
      final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
      if (insertAt <= itemCoords.length) {
        itemCoords.insert(insertAt.clamp(0, itemCoords.length), movedCoord);
      }
    }

    if (accommodationData != null && coords.isNotEmpty) {
      newCoords = [coords[0], ...itemCoords];
    } else {
      newCoords = itemCoords;
    }

    for (int i = 1; i < newCoords.length; i++) {
      if (newCoords[i]['lat'] != 0 && newCoords[i]['lng'] != 0 &&
          newCoords[i - 1]['lat'] != 0 && newCoords[i - 1]['lng'] != 0) {
        newTotalDistance += _haversineDistance(
          newCoords[i - 1]['lat']!,
          newCoords[i - 1]['lng']!,
          newCoords[i]['lat']!,
          newCoords[i]['lng']!,
        );
      }
    }

    final addedDistance = newTotalDistance - oldTotalDistance;
    final addedTime = ((addedDistance / 25) * 60).round();

    return {
      'oldDistance': double.parse(oldTotalDistance.toStringAsFixed(2)),
      'newDistance': double.parse(newTotalDistance.toStringAsFixed(2)),
      'addedDistance': double.parse(addedDistance.toStringAsFixed(2)),
      'addedTime': addedTime,
    };
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * 3.141592653589793 / 180;
  }

  Future<void> _performReorder(
      int day,
      List<DocumentSnapshot> dayItems,
      int oldIndex,
      int newIndex,
      ) async {
    setState(() => _isProcessing = true);

    try {
      final List<DocumentSnapshot> updatedOrder = List.from(dayItems);
      final movedItem = updatedOrder.removeAt(oldIndex);
      updatedOrder.insert(newIndex, movedItem);

      await _editController.reorderItems(
        tripId: widget.tripId,
        dayNumber: day,
        itemIds: updatedOrder.map((doc) => doc.id).toList(),
      );

      setState(() {
        _isProcessing = false;
        _reorderingDay = null;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Reorder Failed',
          subtitle: e.toString(),
        );
      }
    }
  }

  Widget _buildTripStyleHeader(BuildContext context, List<String> destinationTypes, Map<String, dynamic> tripData) {
    if (destinationTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    final city = tripData['city'] ?? tripData['destinationCity'] ?? '';
    final country = tripData['country'] ?? tripData['destinationCountry'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.explore, color: Colors.green[800], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Trip Style',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                    if (city.isNotEmpty)
                      Text(
                        '$city, $country',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: destinationTypes.map((type) {
              return _buildDestinationTypeChip(type);
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Long press to edit • Tap "Reorder" to drag destinations',
            style: TextStyle(
              fontSize: 11,
              color: Colors.green[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationTypeChip(String type) {
    final typeInfo = _getDestinationTypeInfo(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: typeInfo['color'].withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: typeInfo['color'].withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            typeInfo['emoji'],
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            typeInfo['label'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: typeInfo['color'],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getDestinationTypeInfo(String type) {
    final types = {
      'relaxing': {'emoji': '🏖️', 'label': 'Relaxing', 'color': Colors.cyan},
      'historical': {'emoji': '🏛️', 'label': 'Historical & Cultural', 'color': Colors.brown},
      'adventure': {'emoji': '🎢', 'label': 'Adventure & Outdoors', 'color': Colors.orange},
      'shopping': {'emoji': '🛍️', 'label': 'Shopping & Lifestyle', 'color': Colors.pink},
      'spiritual': {'emoji': '⛩️', 'label': 'Religious & Spiritual', 'color': Colors.purple},
      'entertainment': {'emoji': '🎭', 'label': 'Entertainment & Fun', 'color': Colors.red},
    };

    return types[type.toLowerCase()] ??
        {
          'emoji': '📍',
          'label': type,
          'color': Colors.grey,
        };
  }

  Widget _buildSkippedSection(BuildContext context, List<DocumentSnapshot> skippedItems, String tripId) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.visibility_off, color: Colors.grey[600]),
        title: Text(
          'Skipped Activities (${skippedItems.length})',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        subtitle: Text(
          'Tap to view and restore',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        children: skippedItems.map((item) {
          final data = item.data() as Map<String, dynamic>;
          return _buildSkippedItemTile(context, data, item.id, tripId);
        }).toList(),
      ),
    );
  }

  Widget _buildSkippedItemTile(BuildContext context, Map<String, dynamic> data, String itemId, String tripId) {
    final category = data['category'] as String? ?? 'attraction';
    final categoryColor = IconHelper.getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            IconHelper.getCategoryIcon(category),
            color: categoryColor.withOpacity(0.5),
            size: 20,
          ),
        ),
        title: Text(
          data['title'] ?? 'Activity',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            decoration: TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          'Day ${data['dayNumber']} • ${data['startTime']} - ${data['endTime']}',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        trailing: TextButton.icon(
          onPressed: () => _restoreSkippedItem(context, tripId, itemId, data['title']),
          icon: Icon(Icons.restore, size: 16, color: Colors.green[700]),
          label: Text(
            'Restore',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor: Colors.green[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  void _restoreSkippedItem(BuildContext context, String tripId, String itemId, String? title) async {
    final confirm = await SweetAlertDialog.confirm(
      context: context,
      title: 'Restore Activity?',
      subtitle: 'Do you want to restore "${title ?? 'this activity'}" back to your itinerary?',
      confirmText: 'Restore',
      cancelText: 'Cancel',
    );

    if (confirm == true) {
      await _editController.undoSkip(tripId: tripId, itemId: itemId);
    }
  }

  Widget _buildDayHeader(
      BuildContext context,
      int day,
      String dateString,
      int itemCount,
      Map<String, dynamic>? weather,
      Map<String, dynamic>? accommodationData,
      ) {
    final isReordering = _reorderingDay == day;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Day $day',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dateString.isNotEmpty)
                      Text(
                        dateString,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    Text('$itemCount activities', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Action buttons row - separate from header to prevent overflow
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              if (!isReordering)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _reorderingDay = day),
                  icon: const Icon(Icons.swap_vert, size: 16),
                  label: const Text('Reorder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[50],
                    foregroundColor: Colors.purple[700],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.purple[200]!),
                    ),
                  ),
                ),
              if (weather != null)
                GestureDetector(
                  onTap: () => _showWeatherDetails(context, weather),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getWeatherBackgroundColor(weather),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(IconHelper.getWeatherIcon(weather['description'] ?? ''), size: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '${weather['temp']?.toStringAsFixed(0) ?? '--'}°C',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (weather['rain_probability'] != null && weather['rain_probability'] > 30) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.water_drop, size: 12, color: Colors.white.withOpacity(0.8)),
                          Text(
                            '${weather['rain_probability']}%',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getWeatherBackgroundColor(Map<String, dynamic> weather) {
    final temp = weather['temp'] ?? 25;
    final rainProb = weather['rain_probability'] ?? 0;

    if (rainProb > 60) return Colors.blueGrey[600]!;
    if (temp > 32) return Colors.orange[600]!;
    if (temp < 15) return Colors.cyan[600]!;
    return Colors.blue[500]!;
  }

  Widget _buildAccommodationEntry(BuildContext context, Map<String, dynamic> accData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[100]!),
      ),
      child: ListTile(
        leading: const Icon(Icons.hotel, color: Colors.purple, size: 24),
        title: Text('Start from ${accData['name'] ?? 'Hotel'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(accData['address'] ?? 'Your Accommodation',
            style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        dense: true,
        onTap: () => _showExternalLinkDialog(
          accData['name'] ?? 'Hotel',
          _getAccommodationMapsUrl(accData),
        ),
      ),
    );
  }

  /// Get maps URL for accommodation
  String _getAccommodationMapsUrl(Map<String, dynamic> accData) {
    if (accData['maps_link'] != null && accData['maps_link'].toString().isNotEmpty) {
      return accData['maps_link'];
    } else if (accData['coordinates'] != null) {
      final coords = accData['coordinates'];
      return 'https://www.google.com/maps?q=${coords['lat']},${coords['lng']}';
    }
    return '';
  }

  Widget _buildItineraryCard(
      BuildContext context, Map<String, dynamic> data, String itemId, String city, String country) {
    final category = data['category'] as String? ?? 'attraction';
    final isMeal = ['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack'].contains(category.toLowerCase());
    final categoryColor = IconHelper.getCategoryColor(category);
    final hasRestaurantOptions = data['restaurantOptions'] != null && (data['restaurantOptions'] as List).isNotEmpty;

    final isPreferred = data['is_preferred'] == true || data['isPreferred'] == true;

    final isReplaced = data['isReplaced'] == true;
    final isExtended = data['isExtended'] == true;
    final isShortened = data['isShortened'] == true;
    final isReordered = data['isReordered'] == true;
    final userNote = data['userNote'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReordered
              ? Colors.purple.withOpacity(0.5)
              : isReplaced
              ? Colors.orange.withOpacity(0.5)
              : isPreferred
              ? Colors.green.withOpacity(0.5)
              : categoryColor.withOpacity(0.2),
          width: isReordered || isReplaced || isPreferred ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (hasRestaurantOptions) {
            _showRestaurantSelection(context, data);
          } else {
            _showDestinationDetails(context, data);
          }
        },
        onLongPress: !isMeal
            ? () {
          EditAttractionBottomSheet.show(
            context,
            tripId: widget.tripId,
            itemId: itemId,
            itemData: data,
            city: city,
          );
        }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration:
                    BoxDecoration(color: categoryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(IconHelper.getCategoryIcon(category), color: categoryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['title'] ?? 'Activity',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isReordered)
                              _buildStatusBadge('Reordered', Icons.swap_vert, Colors.purple)
                            else if (isReplaced)
                              _buildStatusBadge('Replaced', Icons.swap_horiz, Colors.orange)
                            else if (isPreferred && !isMeal)
                                _buildStatusBadge('Match', Icons.check_circle, Colors.green),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // FIXED: Use Wrap instead of Row for time and local name
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${data['startTime']} - ${data['endTime']}${isExtended ? ' (extended)' : isShortened ? ' (shortened)' : ''}',
                                  style: TextStyle(
                                    color: isExtended
                                        ? Colors.green[700]
                                        : isShortened
                                        ? Colors.orange[700]
                                        : Colors.grey[700],
                                    fontSize: 13,
                                    fontWeight: (isExtended || isShortened) ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            if (data['name_local'] != null && data['name_local'] != data['title'])
                              Text(
                                '(${data['name_local']})',
                                style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isMeal)
                    Tooltip(
                      message: 'Long press to edit',
                      child: Icon(Icons.more_vert, size: 20, color: Colors.grey[400]),
                    ),
                ],
              ),

              if (data['estimatedTravelMinutes'] != null || data['distanceKm'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car, size: 12, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        '~${data['estimatedTravelMinutes'] ?? 0} min',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                      if (data['distanceKm'] != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${data['distanceKm']} km)',
                          style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (userNote != null && userNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.purple[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          userNote,
                          style: TextStyle(fontSize: 12, color: Colors.purple[900]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (hasRestaurantOptions) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant_menu, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text('${(data['restaurantOptions'] as List).length} options available',
                          style: TextStyle(fontSize: 12, color: Colors.orange[900], fontWeight: FontWeight.w500)),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.orange),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ========================================
  // EXTERNAL LINK DIALOG
  // ========================================

  /// Show confirmation dialog before opening external link
  Future<void> _showExternalLinkDialog(String siteName, String url) async {
    if (url.isEmpty) return;

    final result = await SweetAlertDialog.show(
      context: context,
      type: SweetAlertType.info,
      title: 'Leaving Wandry',
      subtitle: 'You are about to visit $siteName. This will open in your browser.',
      content: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.link, color: Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getShortenedUrl(url),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      confirmText: 'Open',
      cancelText: 'Cancel',
      showCancelButton: true,
    );

    if (result == true) {
      _launchUrl(url);
    }
  }

  /// Get shortened URL for display
  String _getShortenedUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host + (uri.path.length > 20 ? '${uri.path.substring(0, 20)}...' : uri.path);
    } catch (e) {
      return url.length > 40 ? '${url.substring(0, 40)}...' : url;
    }
  }

  /// Launch URL with error handling
  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          SweetAlertDialog.error(
            context: context,
            title: 'Cannot Open Link',
            subtitle: 'Unable to open the link. Please try again later.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Error',
          subtitle: 'An error occurred: $e',
        );
      }
    }
  }

  // ========================================
  // WEATHER METHODS
  // ========================================

  void _showWeatherDetails(BuildContext context, Map<String, dynamic> weather) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Weather Forecast',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildWeatherCard(weather, showFull: true),
                  const SizedBox(height: 20),
                  const Text(
                    '💡 Recommendations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...(_getWeatherAdvice(weather).map((advice) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              advice,
                              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()),
                  if (weather['is_forecast'] == false) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is based on typical ${weather['month_name'] ?? ''} climate for this region. Actual weather may vary.',
                              style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<String> _getWeatherAdvice(Map<String, dynamic> weather) {
    final List<String> advice = [];
    final temp = weather['temp'] ?? 20.0;
    final rain = weather['rain_probability'] ?? 0.0;
    final humidity = weather['humidity'] ?? 50;
    final uv = weather['uv_index'] ?? 5;

    if (temp > 30) {
      advice.add(
        'Very hot conditions expected. Stay hydrated, use sunscreen SPF 50+, and take breaks in air-conditioned areas.',
      );
      advice.add(
        'Best to schedule outdoor activities early morning (before 10am) or late afternoon (after 4pm).',
      );
    } else if (temp < 10) {
      advice.add(
        'Cold weather ahead. Dress in layers, bring a warm jacket, and consider thermal underwear.',
      );
    } else if (temp < 20) {
      advice.add('Mild weather - perfect for outdoor activities. A light jacket should suffice.');
    }

    if (rain > 70) {
      advice.add(
        'High chance of rain. Bring waterproof jacket, umbrella, and protect electronics in waterproof bags.',
      );
    } else if (rain > 40) {
      advice.add('Moderate rain possibility. Pack a compact umbrella and have backup indoor plans ready.');
    }

    if (humidity > 70) {
      advice.add('High humidity levels. Wear breathable fabrics, stay hydrated, and take frequent breaks.');
    }

    if (uv > 8) {
      advice.add('Very high UV index. Wear a hat, sunglasses, and apply sunscreen frequently.');
    }

    if (advice.isEmpty) {
      advice.add('Pleasant weather conditions! Great day for outdoor sightseeing and activities.');
    }

    return advice;
  }

  Widget _buildWeatherCard(Map<String, dynamic> weather, {bool showFull = false}) {
    final isHot = (weather['temp'] ?? 20) > 30;
    final isCold = (weather['temp'] ?? 20) < 10;
    final isRainy = (weather['rain_probability'] ?? 0) > 50;

    Color gradientStart = Colors.blue[400]!;
    Color gradientEnd = Colors.blue[600]!;

    if (isHot) {
      gradientStart = Colors.orange[400]!;
      gradientEnd = Colors.red[500]!;
    } else if (isCold) {
      gradientStart = Colors.cyan[300]!;
      gradientEnd = Colors.blue[700]!;
    } else if (isRainy) {
      gradientStart = Colors.grey[500]!;
      gradientEnd = Colors.blueGrey[700]!;
    }

    return Container(
      padding: EdgeInsets.all(showFull ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: showFull
            ? []
            : [
          BoxShadow(
            color: gradientEnd.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                IconHelper.getWeatherIcon(weather['description'] ?? ''),
                size: showFull ? 64 : 48,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weather['temp']?.toStringAsFixed(1) ?? '--'}°C',
                      style: TextStyle(
                        fontSize: showFull ? 40 : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (showFull && weather['temp_min'] != null && weather['temp_max'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'L: ${weather['temp_min']?.toStringAsFixed(0)}° H: ${weather['temp_max']?.toStringAsFixed(0)}°',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      weather['description'] ?? '',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (weather['is_forecast'] == false) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Based on ${weather['month_name'] ?? ''} climate average',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // FIXED: Use Wrap for weather stats to prevent overflow
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceAround,
            children: [
              _buildWeatherStat(
                Icons.water_drop,
                'Rain',
                '${weather['rain_probability']?.toInt() ?? 0}%',
              ),
              if (showFull)
                _buildWeatherStat(
                  Icons.water,
                  'Humidity',
                  '${weather['humidity']?.toInt() ?? 0}%',
                ),
              _buildWeatherStat(
                Icons.air,
                'Wind',
                '${weather['wind_speed']?.toStringAsFixed(1) ?? 0} m/s',
              ),
              _buildWeatherStat(
                Icons.thermostat,
                'Feels',
                '${weather['feels_like']?.toStringAsFixed(0) ?? '--'}°C',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white.withOpacity(0.9)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  // ========================================
  // RESTAURANT METHODS
  // ========================================

  String _calculateDynamicPriceRange(List options) {
    if (options.isEmpty) return '';
    List<double> prices = [];

    for (var opt in options) {
      final optMap = opt as Map<String, dynamic>;
      double? price;
      if (optMap['estimated_cost_myr'] != null) {
        price = double.tryParse(optMap['estimated_cost_myr'].toString());
      }
      if (price == null && optMap['cost_myr'] != null) {
        price = double.tryParse(optMap['cost_myr'].toString());
      }
      if (price == null && optMap['cost_display'] != null) {
        final str = optMap['cost_display'].toString();
        final regex = RegExp(r'(\d+([.,]\d+)?)');
        final match = regex.firstMatch(str);
        if (match != null) price = double.tryParse(match.group(1)!.replaceAll(',', ''));
      }
      if (price != null && price > 0) prices.add(price);
    }

    if (prices.isEmpty) return "Price based on menu";

    prices.sort();
    final min = prices.first.round();
    final max = prices.last.round();

    if ((max - min).abs() < 10) {
      final avg = (prices.reduce((a, b) => a + b) / prices.length).round();
      return "Est. RM $avg";
    }

    return "Est. RM $min - RM $max";
  }

  void _showRestaurantSelection(BuildContext context, Map<String, dynamic> item) {
    final restaurants = item['restaurantOptions'] as List? ?? [];
    if (restaurants.isEmpty) return;
    final mealType = item['category']?.toString().toUpperCase() ?? 'MEAL';
    final dayNumber = item['dayNumber'] ?? 0;

    final sortedRestaurants =
    List<Map<String, dynamic>>.from(restaurants.map((r) => Map<String, dynamic>.from(r as Map)));
    sortedRestaurants
        .sort((a, b) => ((a['distance_km'] ?? 99.0) as num).compareTo((b['distance_km'] ?? 99.0) as num));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                      color: Colors.orange, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  child: Row(children: [
                    const Icon(Icons.restaurant, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('$mealType - Day $dayNumber',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sortedRestaurants.length,
                    itemBuilder: (context, index) {
                      final r = sortedRestaurants[index];
                      String costDisplay = r['cost_display'] ?? _calculateDynamicPriceRange([r]);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          title:
                          Text(r['name'] ?? 'Restaurant', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.restaurant_menu, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(r['cuisine'] ?? 'Local'),
                                  if (r['is_halal'] == true) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    const Text(' Halal', style: TextStyle(fontSize: 12, color: Colors.green)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              // FIXED: Use Wrap for cost and distance
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.attach_money, size: 14, color: Colors.green[700]),
                                      Text(costDisplay,
                                          style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.directions_walk, size: 14, color: Colors.blue[600]),
                                      Text(' ${r['distance_km'] ?? '?'} km',
                                          style: TextStyle(color: Colors.blue[700])),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.map, color: Colors.blue),
                            onPressed: () => _openRestaurantOnMap(context, r),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openRestaurantOnMap(BuildContext context, Map<String, dynamic> restaurant) async {
    String url = '';
    String name = restaurant['name'] ?? 'Restaurant';

    final mapsLink = restaurant['maps_link'];
    if (mapsLink != null && mapsLink.toString().isNotEmpty) {
      url = mapsLink;
    } else {
      final coords = restaurant['coordinates'] as Map<String, dynamic>?;
      if (coords != null && coords['lat'] != null && coords['lng'] != null) {
        url = 'https://www.google.com/maps?q=${coords['lat']},${coords['lng']}';
      }
    }

    if (url.isNotEmpty) {
      await _showExternalLinkDialog(name, url);
    } else {
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Cannot Open Maps',
          subtitle: 'No location information available for this restaurant.',
        );
      }
    }
  }

  // ========================================
  // DESTINATION DETAILS
  // ========================================

  void _openDestinationOnMap(BuildContext context, Map<String, dynamic> item) async {
    String url = '';
    String name = item['title'] ?? 'Destination';

    final mapsLink = item['maps_link'];
    if (mapsLink != null && mapsLink.toString().isNotEmpty) {
      url = mapsLink;
    } else {
      final coords = item['coordinates'] as Map<String, dynamic>?;
      if (coords != null && coords['lat'] != null && coords['lng'] != null) {
        url = 'https://www.google.com/maps?q=${coords['lat']},${coords['lng']}';
      }
    }

    if (url.isNotEmpty) {
      await _showExternalLinkDialog(name, url);
    } else {
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Cannot Open Maps',
          subtitle: 'Could not open maps for ${item['title'] ?? 'destination'}',
        );
      }
    }
  }

  void _showDestinationDetails(BuildContext context, Map<String, dynamic> item) {
    final isPreferred = item['is_preferred'] == true || item['isPreferred'] == true;
    final weather = item['weather'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: IconHelper.getCategoryColor(item['category']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          IconHelper.getCategoryIcon(item['category']),
                          color: IconHelper.getCategoryColor(item['category']),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] ?? 'Destination',
                              style:
                              const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            if (item['name_local'] != null && item['name_local'] != item['title'])
                              Text(
                                item['name_local'],
                                style:
                                TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                              ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: IconHelper.getCategoryColor(item['category']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    item['category']?.toString().toUpperCase() ?? 'ATTRACTION',
                                    style: TextStyle(
                                      color: IconHelper.getCategoryColor(item['category']),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                if (isPreferred)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Matches Your Style',
                                          style: TextStyle(
                                              color: Colors.green[700], fontWeight: FontWeight.w600, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // FIXED: Use Wrap for rating and time
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (item['rating'] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              (item['rating'] is num)
                                  ? (item['rating'] as num).toStringAsFixed(1)
                                  : item['rating'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${item['startTime']} - ${item['endTime']}',
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (weather != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _showWeatherDetails(context, weather),
                      child: _buildWeatherCard(weather, showFull: false),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green[50]!, Colors.green[100]!]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration:
                          BoxDecoration(color: Colors.green[200], borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.attach_money, color: Colors.green[800], size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Entrance Fee',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(
                                item['currencyDisplay'] ??
                                    'RM ${item['estimatedCostMYR']?.toStringAsFixed(0) ?? item['avg_cost']?.toStringAsFixed(0) ?? '0'}',
                                style:
                                TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[900]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(item['description'],
                        style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.6)),
                  ],
                  if (item['tips'] != null && (item['tips'] as List).isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('💡 Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...(item['tips'] as List).map((tip) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb, size: 16, color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            Expanded(
                                child:
                                Text(tip.toString(), style: TextStyle(fontSize: 13, color: Colors.grey[800]))),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map, size: 20),
                      label: const Text('View on Google Maps',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _openDestinationOnMap(context, item);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCoordinateInfo(context, item),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoordinateInfo(BuildContext context, Map<String, dynamic> item) {
    final coords = item['coordinates'] as Map<String, dynamic>?;
    if (coords == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${coords['lat']?.toStringAsFixed(6)}, ${coords['lng']?.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy coordinates',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${coords['lat']},${coords['lng']}'));
              SweetAlertDialog.success(
                context: context,
                title: 'Copied!',
                subtitle: 'Coordinates copied to clipboard',
              );
            },
          ),
        ],
      ),
    );
  }
}