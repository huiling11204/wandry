// lib/widget/itinerary_tab.dart
//
// FINAL VERSION v4.0 - PROPER LOADING STATE
// ✅ Shows hotel every day with SAME purple theme
// ✅ Shows loading placeholders first (no flickering MYR→JPY)
// ✅ Fetches REAL data from OpenStreetMap (using coordinates)
// ✅ Falls back to Wikidata → Wikipedia → Smart estimates
// ✅ Shows "Verified" vs "Estimated" badges
// ✅ All existing functionality preserved

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../model/itinerary_item_model.dart';
import '../utilities/icon_helper.dart';
import '../controller/itinerary_edit_controller.dart';
import '../controller/wikipedia_controller.dart';
import '../controller/destination_data_service.dart';
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
                            if (accommodationData != null)
                              _buildAccommodationEntry(context, accommodationData, day),
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

  // ============================================================
  // HOTEL ENTRY - SAME PURPLE THEME FOR ALL DAYS
  // ============================================================
  Widget _buildAccommodationEntry(BuildContext context, Map<String, dynamic> accData, int dayNumber) {
    final isFirstDay = dayNumber == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[50]!, Colors.purple[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isFirstDay ? Icons.flight_land : Icons.hotel,
            color: Colors.purple[700],
            size: 24,
          ),
        ),
        title: Text(
          isFirstDay
              ? 'Start from ${accData['name'] ?? 'Hotel'}'
              : 'Day $dayNumber • ${accData['name'] ?? 'Hotel'}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.purple[900],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              accData['address'] ?? accData['city'] ?? 'Your Accommodation',
              style: TextStyle(color: Colors.purple[600], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (accData['stars'] != null)
                  ...List.generate(
                    (accData['stars'] as num?)?.toInt() ?? 3,
                        (index) => Icon(Icons.star, size: 12, color: Colors.amber[600]),
                  ),
                if (accData['stars'] != null) const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFirstDay ? 'CHECK-IN' : 'YOUR BASE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.purple[400]),
        dense: true,
        onTap: () => _showExternalLinkDialog(
          accData['name'] ?? 'Hotel',
          _getAccommodationMapsUrl(accData),
        ),
      ),
    );
  }

  String _getAccommodationMapsUrl(Map<String, dynamic> accData) {
    if (accData['maps_link'] != null && accData['maps_link'].toString().isNotEmpty) {
      return accData['maps_link'];
    } else if (accData['coordinates'] != null) {
      final coords = accData['coordinates'];
      return 'https://www.google.com/maps?q=${coords['lat']},${coords['lng']}';
    }
    return '';
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
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.purple[50]!, Colors.purple[100]!]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple[300]!, width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.purple[200], borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.drag_indicator, color: Colors.purple[700], size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reorder Mode Active', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[900], fontSize: 16)),
                        Text('Hold and drag attractions to reorder', style: TextStyle(fontSize: 12, color: Colors.purple[700])),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
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
            final isMeal = ['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack'].contains(category.toLowerCase());

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
            border: Border.all(color: isMeal ? Colors.grey[300]! : Colors.purple.withOpacity(0.3), width: isMeal ? 1 : 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isMeal)
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        width: 48,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple[50]!, Colors.purple[100]!])),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.drag_indicator, color: Colors.purple[400], size: 24),
                            const SizedBox(height: 4),
                            Text('DRAG', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.purple[400])),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, color: Colors.grey[400], size: 22),
                          const SizedBox(height: 4),
                          Text('FIXED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: categoryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Icon(IconHelper.getCategoryIcon(category), color: categoryColor, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isMeal ? Colors.grey[600] : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text('$startTime - $endTime', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                  ],
                                ),
                              ),
                              if (distanceKm != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.directions_car, size: 12, color: Colors.blue[600]),
                                      const SizedBox(width: 4),
                                      Text('$distanceKm km', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isMeal)
                    Container(
                      width: 36,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple[50]!, Colors.purple[100]!])),
                      child: Icon(Icons.swap_vert, size: 20, color: Colors.purple[400]),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReorder(BuildContext context, int day, List<DocumentSnapshot> dayItems, int oldIndex, int newIndex, Map<String, dynamic>? accommodationData) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final movedItem = dayItems[oldIndex];
    final movedData = movedItem.data() as Map<String, dynamic>;
    final movedCategory = movedData['category'] as String? ?? 'attraction';

    if (['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack'].contains(movedCategory.toLowerCase())) {
      await SweetAlertDialog.warning(context: context, title: 'Cannot Move Meals', subtitle: 'Meal times are fixed. Only attractions can be reordered.');
      return;
    }

    final distanceInfo = _calculateDistanceImpact(dayItems, oldIndex, newIndex, accommodationData);
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

  Map<String, dynamic> _calculateDistanceImpact(List<DocumentSnapshot> dayItems, int oldIndex, int newIndex, Map<String, dynamic>? accommodationData) {
    return {'oldDistance': 0.0, 'newDistance': 0.0, 'addedDistance': 0.0, 'addedTime': 0};
  }

  Future<void> _performReorder(int day, List<DocumentSnapshot> dayItems, int oldIndex, int newIndex) async {
    setState(() => _isProcessing = true);
    try {
      final List<DocumentSnapshot> updatedOrder = List.from(dayItems);
      final movedItem = updatedOrder.removeAt(oldIndex);
      updatedOrder.insert(newIndex, movedItem);
      await _editController.reorderItems(tripId: widget.tripId, dayNumber: day, itemIds: updatedOrder.map((doc) => doc.id).toList());
      setState(() { _isProcessing = false; _reorderingDay = null; });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) SweetAlertDialog.error(context: context, title: 'Reorder Failed', subtitle: e.toString());
    }
  }

  Widget _buildTripStyleHeader(BuildContext context, List<String> destinationTypes, Map<String, dynamic> tripData) {
    if (destinationTypes.isEmpty) return const SizedBox.shrink();
    final city = tripData['city'] ?? tripData['destinationCity'] ?? '';
    final country = tripData['country'] ?? tripData['destinationCountry'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green[50]!, Colors.green[100]!]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green[200], borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.explore, color: Colors.green[800], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Trip Style', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[900])),
                    if (city.isNotEmpty) Text('$city, $country', style: TextStyle(fontSize: 12, color: Colors.green[700])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: destinationTypes.map((type) => _buildDestinationTypeChip(type)).toList()),
          const SizedBox(height: 8),
          Text('Long press to edit • Tap "Reorder" to drag destinations', style: TextStyle(fontSize: 11, color: Colors.green[600], fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildDestinationTypeChip(String type) {
    final typeInfo = _getDestinationTypeInfo(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: typeInfo['color'].withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: typeInfo['color'].withOpacity(0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(typeInfo['emoji'], style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(typeInfo['label'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: typeInfo['color'])),
      ]),
    );
  }

  Map<String, dynamic> _getDestinationTypeInfo(String type) {
    final types = {
      'relaxing': {'emoji': '🏖️', 'label': 'Relaxing', 'color': Colors.cyan},
      'historical': {'emoji': '🏛️', 'label': 'Historical', 'color': Colors.brown},
      'adventure': {'emoji': '🎢', 'label': 'Adventure', 'color': Colors.orange},
      'shopping': {'emoji': '🛍️', 'label': 'Shopping', 'color': Colors.pink},
      'spiritual': {'emoji': '⛩️', 'label': 'Spiritual', 'color': Colors.purple},
      'entertainment': {'emoji': '🎭', 'label': 'Entertainment', 'color': Colors.red},
    };
    return types[type.toLowerCase()] ?? {'emoji': '📍', 'label': type, 'color': Colors.grey};
  }

  Widget _buildSkippedSection(BuildContext context, List<DocumentSnapshot> skippedItems, String tripId) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.visibility_off, color: Colors.grey[600]),
        title: Text('Skipped Activities (${skippedItems.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        subtitle: Text('Tap to view and restore', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: categoryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(IconHelper.getCategoryIcon(category), color: categoryColor.withOpacity(0.5), size: 20),
        ),
        title: Text(data['title'] ?? 'Activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600], decoration: TextDecoration.lineThrough)),
        subtitle: Text('Day ${data['dayNumber']} • ${data['startTime']} - ${data['endTime']}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: TextButton.icon(
          onPressed: () => _restoreSkippedItem(context, tripId, itemId, data['title']),
          icon: Icon(Icons.restore, size: 16, color: Colors.green[700]),
          label: Text('Restore', style: TextStyle(fontSize: 12, color: Colors.green[700])),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), backgroundColor: Colors.green[50], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
    );
  }

  void _restoreSkippedItem(BuildContext context, String tripId, String itemId, String? title) async {
    final confirm = await SweetAlertDialog.confirm(context: context, title: 'Restore Activity?', subtitle: 'Do you want to restore "${title ?? 'this activity'}" back to your itinerary?', confirmText: 'Restore', cancelText: 'Cancel');
    if (confirm == true) await _editController.undoSkip(tripId: tripId, itemId: itemId);
  }

  Widget _buildDayHeader(BuildContext context, int day, String dateString, int itemCount, Map<String, dynamic>? weather, Map<String, dynamic>? accommodationData) {
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
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text('Day $day', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dateString.isNotEmpty) Text(dateString, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text('$itemCount activities', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.purple[200]!)),
                  ),
                ),
              if (weather != null)
                GestureDetector(
                  onTap: () => _showWeatherDetails(context, weather),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _getWeatherBackgroundColor(weather), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(IconHelper.getWeatherIcon(weather['description'] ?? ''), size: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('${weather['temp']?.toStringAsFixed(0) ?? '--'}°C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _buildItineraryCard(BuildContext context, Map<String, dynamic> data, String itemId, String city, String country) {
    final category = data['category'] as String? ?? 'attraction';
    final isMeal = ['breakfast', 'lunch', 'dinner', 'meal', 'cafe', 'snack'].contains(category.toLowerCase());
    final categoryColor = IconHelper.getCategoryColor(category);
    final hasRestaurantOptions = data['restaurantOptions'] != null && (data['restaurantOptions'] as List).isNotEmpty;
    final isPreferred = data['is_preferred'] == true || data['isPreferred'] == true;
    final isReplaced = data['isReplaced'] == true;
    final isReordered = data['isReordered'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReordered ? Colors.purple.withOpacity(0.5) : isReplaced ? Colors.orange.withOpacity(0.5) : isPreferred ? Colors.green.withOpacity(0.5) : categoryColor.withOpacity(0.2),
          width: isReordered || isReplaced || isPreferred ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (hasRestaurantOptions) {
            _showRestaurantSelection(context, data);
          } else {
            _showDestinationDetails(context, data, country);
          }
        },
        onLongPress: !isMeal ? () => EditAttractionBottomSheet.show(context, tripId: widget.tripId, itemId: itemId, itemData: data, city: city) : null,
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
                    decoration: BoxDecoration(color: categoryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(IconHelper.getCategoryIcon(category), color: categoryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(data['title'] ?? 'Activity', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (isPreferred && !isMeal) _buildStatusBadge('Match', Icons.check_circle, Colors.green),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('${data['startTime']} - ${data['endTime']}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isMeal) Icon(Icons.more_vert, size: 20, color: Colors.grey[400]),
                ],
              ),
              if (hasRestaurantOptions) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant_menu, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text('${(data['restaurantOptions'] as List).length} options available', style: TextStyle(fontSize: 12, color: Colors.orange[900], fontWeight: FontWeight.w500)),
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Future<void> _showExternalLinkDialog(String siteName, String url) async {
    if (url.isEmpty) return;
    final result = await SweetAlertDialog.show(context: context, type: SweetAlertType.info, title: 'Leaving Wandry', subtitle: 'Open $siteName in browser?', confirmText: 'Open', cancelText: 'Cancel', showCancelButton: true);
    if (result == true) _launchUrl(url);
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) SweetAlertDialog.error(context: context, title: 'Error', subtitle: 'Could not open link');
    }
  }

  // ============================================================
// UPDATED _showWeatherDetails METHOD WITH WEATHER ADVICE
// Replace your existing _showWeatherDetails method with this one
// ============================================================

  void _showWeatherDetails(BuildContext context, Map<String, dynamic> weather) {
    // Generate weather advice based on conditions
    final advice = _generateWeatherAdvice(weather);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
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
                  // Handle
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

                  // Title
                  const Text(
                    'Weather Forecast',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Main Weather Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getWeatherBackgroundColor(weather),
                          _getWeatherBackgroundColor(weather).withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _getWeatherBackgroundColor(weather).withOpacity(0.3),
                          blurRadius: 10,
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
                              size: 64,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${weather['temp']?.toStringAsFixed(0) ?? '--'}°C',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    weather['description'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Temperature Range
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildWeatherStat(
                              icon: Icons.arrow_upward,
                              label: 'High',
                              value: '${weather['temp_max']?.toStringAsFixed(0) ?? '--'}°C',
                            ),
                            _buildWeatherStat(
                              icon: Icons.arrow_downward,
                              label: 'Low',
                              value: '${weather['temp_min']?.toStringAsFixed(0) ?? '--'}°C',
                            ),
                            _buildWeatherStat(
                              icon: Icons.thermostat,
                              label: 'Feels',
                              value: '${weather['feels_like']?.toStringAsFixed(0) ?? weather['temp']?.toStringAsFixed(0) ?? '--'}°C',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Weather Details Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCard(
                          icon: Icons.water_drop,
                          iconColor: Colors.blue,
                          label: 'Rain Chance',
                          value: '${weather['rain_probability'] ?? 0}%',
                          bgColor: Colors.blue[50]!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailCard(
                          icon: Icons.air,
                          iconColor: Colors.teal,
                          label: 'Wind Speed',
                          value: '${weather['wind_speed']?.toStringAsFixed(0) ?? '--'} km/h',
                          bgColor: Colors.teal[50]!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCard(
                          icon: Icons.opacity,
                          iconColor: Colors.indigo,
                          label: 'Humidity',
                          value: '${weather['humidity'] ?? 60}%',
                          bgColor: Colors.indigo[50]!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailCard(
                          icon: Icons.visibility,
                          iconColor: Colors.grey,
                          label: 'Forecast',
                          value: weather['is_forecast'] == true ? 'Live' : 'Estimate',
                          bgColor: Colors.grey[100]!,
                        ),
                      ),
                    ],
                  ),

                  // Weather Advice Section
                  if (advice.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, color: Colors.amber[700], size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Weather Advice',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...advice.map((tip) => _buildAdviceCard(tip)),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

// Helper widget for weather stats in main card
  Widget _buildWeatherStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

// Helper widget for detail cards
  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Helper widget for advice cards
  Widget _buildAdviceCard(Map<String, dynamic> tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (tip['color'] as Color).withOpacity(0.1),
            (tip['color'] as Color).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (tip['color'] as Color).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (tip['color'] as Color).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tip['emoji'] as String,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: tip['color'] as Color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip['message'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Generate weather advice based on conditions
  List<Map<String, dynamic>> _generateWeatherAdvice(Map<String, dynamic> weather) {
    final advice = <Map<String, dynamic>>[];

    final temp = (weather['temp'] as num?)?.toDouble() ?? 25;
    final tempMax = (weather['temp_max'] as num?)?.toDouble() ?? temp;
    final rainProb = (weather['rain_probability'] as num?)?.toInt() ?? 0;
    final windSpeed = (weather['wind_speed'] as num?)?.toDouble() ?? 0;
    final humidity = (weather['humidity'] as num?)?.toInt() ?? 60;
    final description = (weather['description'] as String? ?? '').toLowerCase();

    // Rain advice
    if (rainProb >= 70) {
      advice.add({
        'emoji': '☔',
        'title': 'Rain Expected',
        'message': 'High chance of rain today. Bring an umbrella and consider waterproof footwear. Plan indoor activities as backup.',
        'color': Colors.blue[700]!,
      });
    } else if (rainProb >= 40) {
      advice.add({
        'emoji': '🌂',
        'title': 'Possible Showers',
        'message': 'There\'s a chance of rain. Pack a compact umbrella just in case.',
        'color': Colors.blue[600]!,
      });
    }

    // Hot weather advice
    if (tempMax >= 35) {
      advice.add({
        'emoji': '🥵',
        'title': 'Very Hot Day',
        'message': 'Extreme heat expected. Stay hydrated, apply sunscreen frequently, and seek shade during midday (11am-3pm).',
        'color': Colors.red[700]!,
      });
    } else if (tempMax >= 30) {
      advice.add({
        'emoji': '☀️',
        'title': 'Hot & Sunny',
        'message': 'It\'s going to be warm! Drink plenty of water, wear sunscreen (SPF 30+), and bring a hat.',
        'color': Colors.orange[700]!,
      });
    }

    // Cold weather advice
    if (temp <= 10) {
      advice.add({
        'emoji': '🥶',
        'title': 'Cold Weather',
        'message': 'Bundle up! Wear layers, a warm jacket, and consider gloves and a scarf.',
        'color': Colors.cyan[700]!,
      });
    } else if (temp <= 18) {
      advice.add({
        'emoji': '🧥',
        'title': 'Cool Temperature',
        'message': 'Bring a light jacket or sweater, especially for evenings.',
        'color': Colors.teal[600]!,
      });
    }

    // Wind advice
    if (windSpeed >= 30) {
      advice.add({
        'emoji': '💨',
        'title': 'Strong Winds',
        'message': 'Very windy conditions. Secure loose items and be careful with umbrellas. Avoid outdoor viewpoints.',
        'color': Colors.blueGrey[700]!,
      });
    } else if (windSpeed >= 20) {
      advice.add({
        'emoji': '🍃',
        'title': 'Breezy Day',
        'message': 'Moderate winds expected. Great for keeping cool but secure your hat!',
        'color': Colors.teal[500]!,
      });
    }

    // Humidity advice
    if (humidity >= 85 && temp >= 28) {
      advice.add({
        'emoji': '💦',
        'title': 'High Humidity',
        'message': 'Very humid conditions. Wear breathable fabrics, take breaks in air-conditioned spaces.',
        'color': Colors.purple[600]!,
      });
    }

    // Thunderstorm advice
    if (description.contains('thunder') || description.contains('storm')) {
      advice.add({
        'emoji': '⛈️',
        'title': 'Thunderstorms',
        'message': 'Storms expected. Avoid open areas, tall structures, and water activities. Have indoor backup plans.',
        'color': Colors.deepPurple[700]!,
      });
    }

    // Fog advice
    if (description.contains('fog') || description.contains('mist')) {
      advice.add({
        'emoji': '🌫️',
        'title': 'Low Visibility',
        'message': 'Foggy conditions may affect views at scenic spots. Check conditions before visiting viewpoints.',
        'color': Colors.grey[600]!,
      });
    }

    // Good weather advice
    if (advice.isEmpty && rainProb < 30 && temp >= 20 && temp <= 28) {
      advice.add({
        'emoji': '✨',
        'title': 'Perfect Weather!',
        'message': 'Great conditions for sightseeing! Comfortable temperature with low rain chance. Enjoy your day!',
        'color': Colors.green[600]!,
      });
    }

    // UV advice for clear days
    if ((description.contains('clear') || description.contains('sunny')) && tempMax >= 25 && rainProb < 30) {
      advice.add({
        'emoji': '🧴',
        'title': 'UV Protection',
        'message': 'Clear skies mean strong UV rays. Apply sunscreen every 2 hours and wear sunglasses.',
        'color': Colors.amber[700]!,
      });
    }

    return advice;
  }

  void _showRestaurantSelection(BuildContext context, Map<String, dynamic> item) {
    final restaurants = item['restaurantOptions'] as List? ?? [];
    if (restaurants.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  child: Row(children: [
                    const Icon(Icons.restaurant, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('${item['category']?.toString().toUpperCase() ?? 'MEAL'} OPTIONS', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: restaurants.length,
                    itemBuilder: (context, index) {
                      final r = restaurants[index] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(r['name'] ?? 'Restaurant', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(r['cuisine'] ?? 'Local cuisine'),
                          trailing: IconButton(
                            icon: const Icon(Icons.map, color: Colors.blue),
                            onPressed: () {
                              final coords = r['coordinates'] as Map<String, dynamic>?;
                              if (coords != null) _showExternalLinkDialog(r['name'] ?? 'Restaurant', 'https://www.google.com/maps?q=${coords['lat']},${coords['lng']}');
                            },
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

  // ============================================================
  // ✅ DESTINATION DETAILS - FETCH DATA FIRST, THEN SHOW
  // No more flickering MYR → JPY
  // ============================================================

  void _showDestinationDetails(BuildContext context, Map<String, dynamic> item, String country) async {
    // Show loading sheet first with NO data (just placeholders)
    _showLoadingSheet(context, item);

    // Prepare enriched data
    Map<String, dynamic> enrichedItem = Map<String, dynamic>.from(item);

    // Get coordinates
    final coords = item['coordinates'] as Map<String, dynamic>?;

    try {
      // Fetch all data BEFORE showing
      if (coords != null && coords['lat'] != null && coords['lng'] != null) {
        final enrichedData = await DestinationDataService.fetchDestinationData(
          placeName: item['title'] ?? '',
          latitude: (coords['lat'] as num).toDouble(),
          longitude: (coords['lng'] as num).toDouble(),
          country: country,
          category: item['category'],
        );

        // Also fetch Wikipedia description
        final wikiData = await WikipediaController.fetchWikipediaData(item['title'] ?? '', country);

        // Update enriched item
        if (enrichedData['operating_hours'] != null) {
          enrichedItem['operating_hours'] = enrichedData['operating_hours'];
          enrichedItem['hours_verified'] = enrichedData['hours_verified'] ?? false;
        }
        if (enrichedData['entrance_fee'] != null) {
          enrichedItem['entrance_fee_data'] = enrichedData['entrance_fee'];
          enrichedItem['fee_verified'] = enrichedData['fee_verified'] ?? false;
        }
        if (enrichedData['website'] != null) {
          enrichedItem['official_website'] = enrichedData['website'];
        }
        if (enrichedData['phone'] != null) {
          enrichedItem['phone'] = enrichedData['phone'];
        }
        if (wikiData['description'] != null) {
          enrichedItem['description'] = wikiData['description'];
          enrichedItem['data_enriched'] = true;
        }
      }
    } catch (e) {
      print('Data fetch error: $e');
    }

    // Close loading sheet and show final sheet with all data
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
      _showFinalDestinationSheet(context, enrichedItem, country);
    }
  }

  // Loading sheet with placeholders (NO currency shown)
  void _showLoadingSheet(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: IconHelper.getCategoryColor(item['category']).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(IconHelper.getCategoryIcon(item['category']), color: IconHelper.getCategoryColor(item['category']), size: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'] ?? 'Destination', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            if (item['name_local'] != null) Text(item['name_local'], style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!))),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Loading placeholder for Operating Hours
                  _buildLoadingInfoCard(
                    icon: Icons.schedule,
                    iconColor: Colors.blue,
                    title: 'Operating Hours',
                    gradientColors: [Colors.blue[50]!, Colors.blue[100]!],
                    borderColor: Colors.blue[300]!,
                  ),

                  const SizedBox(height: 12),

                  // Loading placeholder for Entrance Fee
                  _buildLoadingInfoCard(
                    icon: Icons.confirmation_number,
                    iconColor: Colors.green,
                    title: 'Entrance Fee',
                    gradientColors: [Colors.green[50]!, Colors.green[100]!],
                    borderColor: Colors.green[300]!,
                  ),

                  const SizedBox(height: 20),

                  // Loading placeholder for Description
                  const Text('📖 About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildShimmerLines(),

                  const SizedBox(height: 20),

                  // Loading indicator
                  Center(
                    child: Column(
                      children: [
                        SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!))),
                        const SizedBox(height: 12),
                        Text('Fetching information...', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Color> gradientColors,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor.withOpacity(0.8), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: iconColor.withOpacity(0.8), fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  height: 20,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 8),
        Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 8),
        Container(height: 14, width: 200, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
      ],
    );
  }

  // Final sheet with all data loaded
  void _showFinalDestinationSheet(BuildContext context, Map<String, dynamic> item, String country) {
    final isPreferred = item['is_preferred'] == true || item['isPreferred'] == true;
    final dataEnriched = item['data_enriched'] == true;
    final hoursVerified = item['hours_verified'] == true;
    final feeVerified = item['fee_verified'] == true;

    final tips = _generateSmartTips(item, country);

    // Get entrance fee display - use fetched data OR smart estimate with correct currency
    String entranceFeeDisplay;
    if (item['entrance_fee_data'] != null) {
      final feeData = item['entrance_fee_data'] as Map<String, dynamic>;
      entranceFeeDisplay = feeData['display'] ?? 'Check on arrival';
    } else {
      // Use smart estimate with CORRECT currency for this country
      final smartFee = _getSmartFee(item['category'], country);
      entranceFeeDisplay = smartFee['display'];
    }

    // Get operating hours
    String operatingHours = item['operating_hours'] ?? _getSmartHours(item['category'], country);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: IconHelper.getCategoryColor(item['category']).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(IconHelper.getCategoryIcon(item['category']), color: IconHelper.getCategoryColor(item['category']), size: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'] ?? 'Destination', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            if (item['name_local'] != null) Text(item['name_local'], style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      if (dataEnriched || hoursVerified || feeVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.verified, size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text('Live Data', style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Badges
                  Wrap(
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: IconHelper.getCategoryColor(item['category']).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: Text(item['category']?.toString().toUpperCase() ?? 'ATTRACTION', style: TextStyle(color: IconHelper.getCategoryColor(item['category']), fontWeight: FontWeight.w600, fontSize: 11)),
                      ),
                      if (isPreferred)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(16)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text('Matches Your Style', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600, fontSize: 10)),
                          ]),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Time & Rating
                  Wrap(
                    spacing: 16,
                    children: [
                      if (item['rating'] != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text((item['rating'] as num).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('${item['startTime']} - ${item['endTime']}', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      ]),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Operating Hours Card
                  _buildInfoCard(
                    icon: Icons.schedule,
                    iconColor: Colors.blue,
                    title: 'Operating Hours',
                    value: operatingHours,
                    isVerified: hoursVerified,
                    gradientColors: [Colors.blue[50]!, Colors.blue[100]!],
                    borderColor: Colors.blue[300]!,
                  ),

                  const SizedBox(height: 12),

                  // Entrance Fee Card
                  _buildInfoCard(
                    icon: Icons.confirmation_number,
                    iconColor: Colors.green,
                    title: 'Entrance Fee',
                    value: entranceFeeDisplay,
                    isVerified: feeVerified,
                    gradientColors: [Colors.green[50]!, Colors.green[100]!],
                    borderColor: Colors.green[300]!,
                  ),

                  // Contact Info
                  if (item['official_website'] != null || item['phone'] != null) ...[
                    const SizedBox(height: 20),
                    const Text('📞 Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (item['official_website'] != null)
                      _buildContactRow(Icons.language, 'Website', Uri.tryParse(item['official_website'])?.host ?? item['official_website'], () => _showExternalLinkDialog('Website', item['official_website'])),
                    if (item['phone'] != null)
                      _buildContactRow(Icons.phone, 'Phone', item['phone'], () => _launchUrl('tel:${item['phone']}')),
                  ],

                  // Description
                  const SizedBox(height: 20),
                  const Text('📖 About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(item['description'] ?? _generateFallbackDescription(item), style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.6)),

                  // Tips
                  if (tips.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('💡 Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...tips.take(5).map((tip) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber[200]!)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tip, style: TextStyle(fontSize: 13, color: Colors.grey[800]))),
                        ],
                      ),
                    )),
                  ],

                  const SizedBox(height: 24),

                  // Maps Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map, size: 20),
                      label: const Text('View on Google Maps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        final coords = item['coordinates'] as Map<String, dynamic>?;
                        if (coords != null) _showExternalLinkDialog(item['title'] ?? 'Destination', 'https://www.google.com/maps?q=${coords['lat']},${coords['lng']}');
                      },
                    ),
                  ),

                  // Data source note
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hoursVerified || feeVerified ? 'Data from OpenStreetMap. Verify before visiting.' : 'Estimates based on similar attractions. Verify before visiting.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool isVerified,
    required List<Color> gradientColors,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor.withOpacity(0.8), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontSize: 12, color: iconColor.withOpacity(0.8), fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isVerified ? Colors.green[100] : Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isVerified) Icon(Icons.verified, size: 10, color: Colors.green[700]),
                          if (isVerified) const SizedBox(width: 2),
                          Text(isVerified ? 'Verified' : 'Estimated', style: TextStyle(fontSize: 9, color: isVerified ? Colors.green[700] : Colors.orange[700], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: iconColor.withOpacity(0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  Text(value, style: TextStyle(fontSize: 14, color: Colors.blue[700], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  String _getSmartHours(String? category, String? country) {
    final cat = (category ?? '').toLowerCase();
    switch (cat) {
      case 'temple': return '06:00 - 18:00 (typical)';
      case 'museum': return '09:00 - 17:00 (closed Mondays)';
      case 'park': case 'nature': return '06:00 - 19:00';
      case 'viewpoint': return '24 hours (outdoor)';
      case 'shopping': return '10:00 - 22:00';
      case 'entertainment': return '10:00 - 22:00';
      default: return '09:00 - 17:00';
    }
  }

  Map<String, dynamic> _getSmartFee(String? category, String? country) {
    final cat = (category ?? '').toLowerCase();
    final countryLower = (country ?? '').toLowerCase();

    String currency = 'MYR';
    double amount = 0;

    // Set correct currency based on country
    if (countryLower.contains('japan')) currency = 'JPY';
    else if (countryLower.contains('thailand')) currency = 'THB';
    else if (countryLower.contains('indonesia') || countryLower.contains('bali')) currency = 'IDR';
    else if (countryLower.contains('singapore')) currency = 'SGD';
    else if (countryLower.contains('korea')) currency = 'KRW';
    else if (countryLower.contains('vietnam')) currency = 'VND';
    else if (countryLower.contains('philippines')) currency = 'PHP';
    else if (countryLower.contains('china')) currency = 'CNY';
    else if (countryLower.contains('taiwan')) currency = 'TWD';
    else if (countryLower.contains('hong kong')) currency = 'HKD';
    else if (countryLower.contains('india')) currency = 'INR';
    else if (countryLower.contains('australia')) currency = 'AUD';
    else if (countryLower.contains('uk') || countryLower.contains('united kingdom')) currency = 'GBP';
    else if (countryLower.contains('europe') || countryLower.contains('france') || countryLower.contains('germany') || countryLower.contains('italy')) currency = 'EUR';
    else if (countryLower.contains('us') || countryLower.contains('united states') || countryLower.contains('america')) currency = 'USD';

    switch (cat) {
      case 'temple':
        if (currency == 'JPY') amount = 500;
        else if (currency == 'THB') amount = 100;
        else if (currency == 'IDR') amount = 30000;
        else if (currency == 'MYR') return {'display': 'Free (donations welcome)'};
        else amount = 5;
        break;
      case 'museum':
        if (currency == 'JPY') amount = 1000;
        else if (currency == 'THB') amount = 200;
        else if (currency == 'SGD') amount = 20;
        else if (currency == 'MYR') amount = 15;
        else if (currency == 'EUR') amount = 15;
        else if (currency == 'GBP') amount = 12;
        else if (currency == 'USD') amount = 20;
        else amount = 15;
        break;
      case 'park': case 'nature': case 'viewpoint':
      return {'display': 'Free / Small fee'};
      case 'shopping':
        return {'display': 'Free entry'};
      case 'entertainment':
        if (currency == 'JPY') amount = 2000;
        else if (currency == 'THB') amount = 500;
        else if (currency == 'SGD') amount = 40;
        else if (currency == 'MYR') amount = 50;
        else amount = 30;
        break;
      default:
        if (currency == 'JPY') amount = 800;
        else if (currency == 'THB') amount = 150;
        else if (currency == 'IDR') amount = 25000;
        else amount = 15;
    }

    // Format display based on currency
    String display;
    if (currency == 'IDR') {
      display = 'IDR ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    } else if (currency == 'JPY' || currency == 'KRW' || currency == 'VND') {
      display = '$currency ${amount.toStringAsFixed(0)}';
    } else {
      display = '$currency ${amount.toStringAsFixed(0)}';
    }

    return {'amount': amount, 'currency': currency, 'display': display};
  }

  List<String> _generateSmartTips(Map<String, dynamic> item, String country) {
    final tips = <String>[];
    final category = (item['category'] as String? ?? '').toLowerCase();
    final countryLower = country.toLowerCase();

    switch (category) {
      case 'temple':
        tips.addAll(['Dress modestly - cover shoulders and knees', 'Remove shoes before entering']);
        if (countryLower.contains('thai')) tips.add('Never point feet toward Buddha images');
        if (countryLower.contains('japan')) tips.add('Purify hands at the water basin before entering');
        break;
      case 'museum':
        tips.addAll(['Allow 2-3 hours for visit', 'Check photography rules', 'Often closed on Mondays']);
        break;
      case 'viewpoint':
        tips.addAll(['Visit at sunrise/sunset for best photos', 'Bring water and comfortable shoes']);
        break;
      case 'park': case 'nature':
      tips.addAll(['Bring sunscreen and insect repellent', 'Start early to avoid heat']);
      break;
      case 'shopping':
        tips.addAll(['Bargaining expected at markets', 'Keep small bills handy']);
        break;
      default:
        tips.addAll(['Arrive early to avoid crowds', 'Check opening hours before visiting']);
    }

    if (countryLower.contains('japan')) tips.add('Cash preferred - ATMs at convenience stores');
    else if (countryLower.contains('thai')) tips.add('Stay hydrated - tropical climate');

    return tips;
  }

  String _generateFallbackDescription(Map<String, dynamic> item) {
    final name = item['title'] ?? 'This place';
    final category = (item['category'] as String? ?? 'attraction').toLowerCase();

    switch (category) {
      case 'temple': return '$name is a sacred temple offering visitors a glimpse into local religious traditions and architectural heritage.';
      case 'museum': return '$name showcases cultural artifacts and historical exhibitions, a great place to learn about local history.';
      case 'viewpoint': return '$name offers stunning panoramic views, popular for photography and memorable vistas.';
      case 'park': case 'nature': return '$name is a beautiful natural space perfect for relaxation and outdoor activities.';
      case 'shopping': return '$name is a vibrant shopping destination known for local products and unique finds.';
      default: return '$name is a popular attraction worth visiting during your trip.';
    }
  }
}