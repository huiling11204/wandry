import 'package:flutter/material.dart';
import 'package:wandry/controller/interaction_tracker.dart';

class TripRatingDialog extends StatefulWidget {
  final String tripId;
  final String tripName;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final List<String>? visitedPlaces; // List of place IDs

  const TripRatingDialog({
    super.key,
    required this.tripId,
    required this.tripName,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.visitedPlaces,
  });

  @override
  State<TripRatingDialog> createState() => _TripRatingDialogState();

  /// Show the rating dialog
  static Future<void> show(
      BuildContext context, {
        required String tripId,
        required String tripName,
        required String destination,
        required DateTime startDate,
        required DateTime endDate,
        List<String>? visitedPlaces,
      }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // User must rate or skip
      builder: (context) => TripRatingDialog(
        tripId: tripId,
        tripName: tripName,
        destination: destination,
        startDate: startDate,
        endDate: endDate,
        visitedPlaces: visitedPlaces,
      ),
    );
  }
}

class _TripRatingDialogState extends State<TripRatingDialog> {
  final InteractionTracker _tracker = InteractionTracker();
  final TextEditingController _feedbackController = TextEditingController();

  double _overallRating = 3.0;
  double _accommodationRating = 3.0;
  double _transportationRating = 3.0;
  double _activitiesRating = 3.0;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);

    try {
      // Track the trip rating
      await _tracker.trackTripRating(
        tripId: widget.tripId,
        tripName: widget.tripName,
        overallRating: _overallRating,
        accommodationRating: _accommodationRating,
        transportationRating: _transportationRating,
        activitiesRating: _activitiesRating,
        feedback: _feedbackController.text.trim().isNotEmpty
            ? _feedbackController.text.trim()
            : null,
        visitedPlaces: widget.visitedPlaces,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! 🎉'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Close dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _skipRating() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysCount = widget.endDate.difference(widget.startDate).inDays + 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.celebration,
                      color: theme.primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip Completed!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'How was your experience?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Trip Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tripName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          widget.destination,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$daysCount days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Overall Rating
              _buildRatingSection(
                label: 'Overall Experience',
                rating: _overallRating,
                icon: Icons.star,
                color: Colors.amber,
                onChanged: (value) => setState(() => _overallRating = value),
              ),

              const SizedBox(height: 16),

              // Detailed Ratings
              Text(
                'Rate specific aspects:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              _buildRatingSection(
                label: 'Accommodation',
                rating: _accommodationRating,
                icon: Icons.hotel,
                color: Colors.blue,
                compact: true,
                onChanged: (value) => setState(() => _accommodationRating = value),
              ),
              const SizedBox(height: 8),

              _buildRatingSection(
                label: 'Transportation',
                rating: _transportationRating,
                icon: Icons.directions_car,
                color: Colors.green,
                compact: true,
                onChanged: (value) => setState(() => _transportationRating = value),
              ),
              const SizedBox(height: 8),

              _buildRatingSection(
                label: 'Activities',
                rating: _activitiesRating,
                icon: Icons.local_activity,
                color: Colors.orange,
                compact: true,
                onChanged: (value) => setState(() => _activitiesRating = value),
              ),

              const SizedBox(height: 20),

              // Feedback TextField
              TextField(
                controller: _feedbackController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts... (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _skipRating,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text('Submit Rating'),
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

  Widget _buildRatingSection({
    required String label,
    required double rating,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
    bool compact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: compact ? 18 : 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: compact ? FontWeight.normal : FontWeight.w600,
                fontSize: compact ? 14 : 16,
              ),
            ),
            const Spacer(),
            Text(
              '${rating.toStringAsFixed(1)} ★',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: compact ? 14 : 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: compact ? 4 : 6,
          ),
          child: Slider(
            value: rating,
            min: 1,
            max: 5,
            divisions: 8, // 0.5 increments
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}