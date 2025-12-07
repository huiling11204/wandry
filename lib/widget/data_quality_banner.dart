// Shows a warning banner when trip has limited data

import 'package:flutter/material.dart';

class DataQualityBanner extends StatelessWidget {
  final String? dataQuality;
  final bool? isSparseDataArea;
  final int? totalRestaurantsFound;
  final String? destinationType;

  const DataQualityBanner({
    super.key,
    this.dataQuality,
    this.isSparseDataArea,
    this.totalRestaurantsFound,
    this.destinationType,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show anything for good data quality
    if (dataQuality == 'good' && isSparseDataArea != true) {
      return const SizedBox.shrink();
    }

    String message;
    IconData icon;
    Color color;

    if (destinationType == 'remote') {
      message = 'Remote area - restaurant and hotel options are limited';
      icon = Icons.terrain;
      color = Colors.orange;
    } else if (isSparseDataArea == true) {
      message = 'Limited data area - some meals may have fewer options';
      icon = Icons.info_outline;
      color = Colors.amber;
    } else if (dataQuality == 'limited') {
      message = 'Some data may be limited for this destination';
      icon = Icons.info_outline;
      color = Colors.amber;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget to show in itinerary when a meal has limited options
class LimitedDataIndicator extends StatelessWidget {
  final String dataAvailability;

  const LimitedDataIndicator({
    super.key,
    required this.dataAvailability,
  });

  @override
  Widget build(BuildContext context) {
    if (dataAvailability != 'limited') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: Colors.amber[800],
          ),
          const SizedBox(width: 6),
          Text(
            'Limited options in this area',
            style: TextStyle(
              fontSize: 11,
              color: Colors.amber[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Destination recommendation widget
class DestinationRecommendationWidget extends StatelessWidget {
  const DestinationRecommendationWidget({super.key});

  static final List<Map<String, String>> recommendations = [
    {'city': 'Tokyo', 'country': 'Japan', 'emoji': '🗼', 'quality': 'Excellent'},
    {'city': 'Osaka', 'country': 'Japan', 'emoji': '🏯', 'quality': 'Excellent'},
    {'city': 'Kyoto', 'country': 'Japan', 'emoji': '⛩️', 'quality': 'Excellent'},
    {'city': 'Bangkok', 'country': 'Thailand', 'emoji': '🛕', 'quality': 'Excellent'},
    {'city': 'Chiang Mai', 'country': 'Thailand', 'emoji': '🐘', 'quality': 'Good'},
    {'city': 'Singapore', 'country': 'Singapore', 'emoji': '🏙️', 'quality': 'Excellent'},
    {'city': 'Kuala Lumpur', 'country': 'Malaysia', 'emoji': '🏢', 'quality': 'Excellent'},
    {'city': 'Penang', 'country': 'Malaysia', 'emoji': '🍜', 'quality': 'Good'},
    {'city': 'Seoul', 'country': 'South Korea', 'emoji': '🎎', 'quality': 'Excellent'},
    {'city': 'Taipei', 'country': 'Taiwan', 'emoji': '🧧', 'quality': 'Excellent'},
    {'city': 'Hong Kong', 'country': 'China', 'emoji': '🌃', 'quality': 'Excellent'},
    {'city': 'Bali', 'country': 'Indonesia', 'emoji': '🏝️', 'quality': 'Good'},
    {'city': 'Ho Chi Minh City', 'country': 'Vietnam', 'emoji': '🏍️', 'quality': 'Good'},
    {'city': 'Hanoi', 'country': 'Vietnam', 'emoji': '🍲', 'quality': 'Good'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Recommended Destinations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'These destinations have excellent data coverage:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recommendations.take(8).map((dest) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dest['emoji']!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      dest['city']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}