// Includes Replace, Skip, Extend/Shorten time, Add note, Reorder info

import 'package:flutter/material.dart';
import '../controller/itinerary_edit_controller.dart';
import '../utilities/icon_helper.dart';

class EditAttractionBottomSheet extends StatefulWidget {
  final String tripId;
  final String itemId;
  final Map<String, dynamic> itemData;
  final String city;

  const EditAttractionBottomSheet({
    super.key,
    required this.tripId,
    required this.itemId,
    required this.itemData,
    required this.city,
  });

  static Future<void> show(
      BuildContext context, {
        required String tripId,
        required String itemId,
        required Map<String, dynamic> itemData,
        required String city,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditAttractionBottomSheet(
        tripId: tripId,
        itemId: itemId,
        itemData: itemData,
        city: city,
      ),
    );
  }

  @override
  State<EditAttractionBottomSheet> createState() => _EditAttractionBottomSheetState();
}

class _EditAttractionBottomSheetState extends State<EditAttractionBottomSheet> {
  final ItineraryEditController _controller = ItineraryEditController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    _controller.onLoadingChanged = (isLoading) {
      if (mounted) setState(() => _isLoading = isLoading);
    };

    _controller.onError = (message) {
      if (mounted) {
        setState(() => _errorMessage = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    };

    _controller.onSuccess = (message) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.itemData['title'] ?? 'Attraction';
    final category = widget.itemData['category'] ?? 'attraction';
    final startTime = widget.itemData['startTime'] ?? '';
    final endTime = widget.itemData['endTime'] ?? '';
    final dayNumber = widget.itemData['dayNumber'] ?? 1;
    final isReordered = widget.itemData['isReordered'] == true;
    final isReplaced = widget.itemData['isReplaced'] == true;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Edit Activity',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Status badges
                              if (isReordered)
                                _buildMiniStatusBadge('Reordered', Colors.purple),
                              if (isReplaced)
                                _buildMiniStatusBadge('Replaced', Colors.orange),
                            ],
                          ),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Info bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoChip(Icons.calendar_today, 'Day $dayNumber'),
                    _buildInfoChip(Icons.access_time, '$startTime - $endTime'),
                    _buildInfoChip(Icons.category, category),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Reorder hint card (NEW)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple[50]!, Colors.purple[100]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.drag_indicator, color: Colors.purple[700], size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Want to Reorder?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[900],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Use the "Reorder" button in the day header to drag & drop attractions.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.purple[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.swap_vert, color: Colors.purple[400], size: 24),
                        ],
                      ),
                    ),

                    _buildOptionTile(
                      icon: Icons.swap_horiz,
                      title: 'Replace with Nearby Attraction',
                      subtitle: 'Find alternative places within 3km',
                      color: Colors.blue,
                      onTap: () => _showReplaceOptions(),
                    ),

                    _buildOptionTile(
                      icon: Icons.more_time,
                      title: 'Extend Time Here',
                      subtitle: 'Spend more time at this attraction',
                      color: Colors.green,
                      onTap: () => _showAdjustTimeDialog(isExtend: true),
                    ),

                    _buildOptionTile(
                      icon: Icons.timer_off_outlined,
                      title: 'Shorten Time Here',
                      subtitle: 'Reduce time at this attraction',
                      color: Colors.orange,
                      onTap: () => _showAdjustTimeDialog(isExtend: false),
                    ),

                    _buildOptionTile(
                      icon: Icons.skip_next,
                      title: 'Skip This Activity',
                      subtitle: 'Remove from itinerary (extends previous activity)',
                      color: Colors.red,
                      onTap: () => _confirmSkip(),
                    ),

                    _buildOptionTile(
                      icon: Icons.note_add,
                      title: 'Add Personal Note',
                      subtitle: 'Add reminders or tips for yourself',
                      color: Colors.purple,
                      onTap: () => _showAddNoteDialog(),
                    ),

                    const SizedBox(height: 16),

                    // Distance info
                    if (widget.itemData['distanceKm'] != null || widget.itemData['estimatedTravelMinutes'] != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.directions_car, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Travel from previous location',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (widget.itemData['distanceKm'] != null) ...[
                                        Text(
                                          '${widget.itemData['distanceKm']} km',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                      if (widget.itemData['estimatedTravelMinutes'] != null)
                                        Text(
                                          '~${widget.itemData['estimatedTravelMinutes']} min',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
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

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              if (_isLoading)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const LinearProgressIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStatusBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: _isLoading ? null : onTap,
      ),
    );
  }

  void _showReplaceOptions() {
    Navigator.pop(context);
    ReplaceAttractionSheet.show(
      context,
      tripId: widget.tripId,
      itemId: widget.itemId,
      itemData: widget.itemData,
      city: widget.city,
    );
  }

  void _showAdjustTimeDialog({required bool isExtend}) {
    final title = isExtend ? 'Extend Time' : 'Shorten Time';
    final subtitle = isExtend
        ? 'How much extra time would you like to spend here?'
        : 'How much time would you like to reduce?';
    final color = isExtend ? Colors.green : Colors.orange;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isExtend ? Icons.more_time : Icons.timer_off_outlined,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 8),
            Text(
              'Current: ${widget.itemData['startTime']} - ${widget.itemData['endTime']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimeChip(15, isExtend: isExtend, color: color),
                _buildTimeChip(30, isExtend: isExtend, color: color),
                _buildTimeChip(45, isExtend: isExtend, color: color),
                _buildTimeChip(60, isExtend: isExtend, color: color),
              ],
            ),
            if (!isExtend) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Minimum 15 minutes required for each activity.',
                        style: TextStyle(fontSize: 11, color: Colors.amber[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(int minutes, {bool isExtend = true, Color? color}) {
    final chipColor = color ?? (isExtend ? Colors.green : Colors.orange);
    final prefix = isExtend ? '+' : '-';

    return ActionChip(
      avatar: Icon(
        isExtend ? Icons.add : Icons.remove,
        size: 16,
        color: chipColor,
      ),
      label: Text(
        '$prefix$minutes min',
        style: TextStyle(color: chipColor, fontWeight: FontWeight.w500),
      ),
      backgroundColor: chipColor.withOpacity(0.1),
      side: BorderSide(color: chipColor.withOpacity(0.3)),
      onPressed: () {
        Navigator.pop(context); // Close dialog
        if (isExtend) {
          _controller.extendTime(
            tripId: widget.tripId,
            itemId: widget.itemId,
            additionalMinutes: minutes,
          );
        } else {
          _controller.shortenTime(
            tripId: widget.tripId,
            itemId: widget.itemId,
            minutesToShorten: minutes,
          );
        }
      },
    );
  }

  void _confirmSkip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Activity?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will skip "${widget.itemData['title']}" and extend the previous activity\'s time.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can restore this activity later from the "Skipped Activities" section.',
                      style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.skipAttraction(
                tripId: widget.tripId,
                itemId: widget.itemId,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Skip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog() {
    final noteController = TextEditingController(
      text: widget.itemData['userNote'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.note_add, color: Colors.purple[700]),
            const SizedBox(width: 8),
            const Text('Add Note'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noteController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Add your personal notes here...\ne.g., "Bring camera", "Book tickets online"',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _controller.addNote(
                itemId: widget.itemId,
                note: noteController.text,
              );
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// Replace Attraction Sheet
// ============================================

class ReplaceAttractionSheet extends StatefulWidget {
  final String tripId;
  final String itemId;
  final Map<String, dynamic> itemData;
  final String city;

  const ReplaceAttractionSheet({
    super.key,
    required this.tripId,
    required this.itemId,
    required this.itemData,
    required this.city,
  });

  static Future<void> show(
      BuildContext context, {
        required String tripId,
        required String itemId,
        required Map<String, dynamic> itemData,
        required String city,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReplaceAttractionSheet(
        tripId: tripId,
        itemId: itemId,
        itemData: itemData,
        city: city,
      ),
    );
  }

  @override
  State<ReplaceAttractionSheet> createState() => _ReplaceAttractionSheetState();
}

class _ReplaceAttractionSheetState extends State<ReplaceAttractionSheet> {
  final ItineraryEditController _controller = ItineraryEditController();
  List<Map<String, dynamic>> _alternatives = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupController();
    _loadAlternatives();
  }

  void _setupController() {
    _controller.onLoadingChanged = (isLoading) {
      if (mounted) setState(() => _isLoading = isLoading);
    };

    _controller.onError = (message) {
      if (mounted) {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
    };

    _controller.onSuccess = (message) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    };

    _controller.onAlternativesLoaded = (alternatives) {
      if (mounted) {
        setState(() {
          _alternatives = alternatives;
          _isLoading = false;
        });
      }
    };
  }

  void _loadAlternatives() {
    final coords = widget.itemData['coordinates'] as Map<String, dynamic>?;
    if (coords == null) {
      setState(() {
        _errorMessage = 'No coordinates available';
        _isLoading = false;
      });
      return;
    }

    _controller.getNearbyAlternatives(
      tripId: widget.tripId,
      currentItemId: widget.itemId,
      lat: coords['lat'],
      lon: coords['lng'],
      category: widget.itemData['category'] ?? 'attraction',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Replace Attraction',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Replacing: ${widget.itemData['title']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Current item info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.itemData['title'] ?? 'Current',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[900],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            '${widget.itemData['startTime']} - ${widget.itemData['endTime']}',
                            style: TextStyle(fontSize: 12, color: Colors.red[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Alternatives header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.place, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Nearby Alternatives',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const Spacer(),
                    if (!_isLoading)
                      Text(
                        '${_alternatives.length} found',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Content
              Expanded(
                child: _buildContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding nearby alternatives...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAlternatives,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_alternatives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No alternatives found nearby'),
            const SizedBox(height: 8),
            Text(
              'Try a different attraction or expand search area',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _alternatives.length,
      itemBuilder: (context, index) {
        final alt = _alternatives[index];
        return _buildAlternativeCard(alt);
      },
    );
  }

  Widget _buildAlternativeCard(Map<String, dynamic> alternative) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _confirmReplace(alternative),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCategoryColor(alternative['category']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(alternative['category']),
                  color: _getCategoryColor(alternative['category']),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alternative['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.near_me, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${alternative['distance_km']} km',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.directions_walk, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '~${alternative['travel_time_minutes']} min',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        alternative['category']?.toString().toUpperCase() ?? 'ATTRACTION',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),

              // Rating & action
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        alternative['rating']?.toStringAsFixed(1) ?? '4.0',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Icon(Icons.check, size: 20, color: Colors.green[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReplace(Map<String, dynamic> alternative) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace Attraction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Old attraction
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.remove_circle, color: Colors.red[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.itemData['title'] ?? 'Current',
                      style: TextStyle(
                        color: Colors.red[900],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Icon(Icons.arrow_downward, color: Colors.grey)),
            const SizedBox(height: 8),
            // New attraction
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.green[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alternative['name'] ?? 'Unknown',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green[900]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Time slot will remain: ${widget.itemData['startTime']} - ${widget.itemData['endTime']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _controller.replaceAttraction(
                tripId: widget.tripId,
                itemId: widget.itemId,
                newAttraction: alternative,
                city: widget.city,
              );
            },
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Replace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'museum':
        return Colors.amber;
      case 'park':
        return Colors.green;
      case 'temple':
        return Colors.purple;
      case 'viewpoint':
        return Colors.cyan;
      case 'entertainment':
        return Colors.red;
      case 'cultural':
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'museum':
        return Icons.museum;
      case 'park':
        return Icons.park;
      case 'temple':
        return Icons.temple_buddhist;
      case 'viewpoint':
        return Icons.landscape;
      case 'entertainment':
        return Icons.attractions;
      case 'cultural':
        return Icons.account_balance;
      default:
        return Icons.place;
    }
  }
}