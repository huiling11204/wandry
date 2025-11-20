// ============================================
// STAR RATING WIDGET
// ============================================
import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final int rating;
  final Function(int) onRatingChanged;
  final double size;
  final bool enabled;

  const StarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 40.0,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return GestureDetector(
          onTap: enabled ? () => onRatingChanged(starNumber) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2), // Reduced from 4 to 2
            child: Icon(
              starNumber <= rating ? Icons.star : Icons.star_border,
              color: starNumber <= rating ? Colors.amber : Colors.grey[400],
              size: size,
            ),
          ),
        );
      }),
    );
  }
}

// Display-only star rating (non-interactive)
class StarRatingDisplay extends StatelessWidget {
  final int rating;
  final double size;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return Icon(
          starNumber <= rating ? Icons.star : Icons.star_border,
          color: starNumber <= rating ? Colors.amber : Colors.grey[400],
          size: size,
        );
      }),
    );
  }
}