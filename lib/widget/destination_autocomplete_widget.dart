import 'package:flutter/material.dart';

class DestinationAutocompleteWidget extends StatelessWidget {
  final List<Map<String, dynamic>> searchResults;
  final Function(Map<String, dynamic>) onSelectDestination;
  final LayerLink layerLink;

  const DestinationAutocompleteWidget({
    super.key,
    required this.searchResults,
    required this.onSelectDestination,
    required this.layerLink,
  });

  @override
  Widget build(BuildContext context) {
    if (searchResults.isEmpty) return const SizedBox.shrink();

    return Positioned(
      width: MediaQuery.of(context).size.width - 48,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 60),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return _DestinationSuggestionItem(
                  place: searchResults[index],
                  onTap: () => onSelectDestination(searchResults[index]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationSuggestionItem extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback onTap;

  const _DestinationSuggestionItem({
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = place['name']?.toString() ?? 'Unknown';
    final address = place['address'] as Map<String, dynamic>?;
    final city = address?['city']?.toString() ?? '';
    final country = address?['country']?.toString() ?? '';

    String subtitle = '';
    if (city.isNotEmpty && country.isNotEmpty) {
      subtitle = '$city, $country';
    } else if (city.isNotEmpty) {
      subtitle = city;
    } else if (country.isNotEmpty) {
      subtitle = country;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                size: 20,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}