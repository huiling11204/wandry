import 'package:flutter/material.dart';
import '../model/destination_type_model.dart';

/// A widget that allows users to select 1-3 destination type preferences
class DestinationTypeSelectorWidget extends StatelessWidget {
  final List<String> selectedTypeIds;
  final Function(List<String>) onSelectionChanged;
  final int maxSelection;
  final int minSelection;

  const DestinationTypeSelectorWidget({
    super.key,
    required this.selectedTypeIds,
    required this.onSelectionChanged,
    this.maxSelection = 3,
    this.minSelection = 1,
  });

  void _toggleSelection(String typeId) {
    final List<String> newSelection = List.from(selectedTypeIds);

    if (newSelection.contains(typeId)) {
      // Don't allow deselecting if at minimum
      if (newSelection.length > minSelection) {
        newSelection.remove(typeId);
      }
    } else {
      // Don't allow selecting more than max
      if (newSelection.length < maxSelection) {
        newSelection.add(typeId);
      } else {
        // Replace the first selected item
        newSelection.removeAt(0);
        newSelection.add(typeId);
      }
    }

    onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selection hint
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Select $minSelection-$maxSelection types that match your travel style',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Selection counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: selectedTypeIds.length >= minSelection
                ? const Color(0xFF4A90E2).withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selectedTypeIds.length >= minSelection
                  ? const Color(0xFF4A90E2).withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selectedTypeIds.length >= minSelection
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 14,
                color: selectedTypeIds.length >= minSelection
                    ? const Color(0xFF4A90E2)
                    : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                '${selectedTypeIds.length}/$maxSelection selected',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selectedTypeIds.length >= minSelection
                      ? const Color(0xFF4A90E2)
                      : Colors.orange[700],
                ),
              ),
            ],
          ),
        ),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15, // FIXED: Was 1.4, now gives more height
          ),
          itemCount: DestinationType.allTypes.length,
          itemBuilder: (context, index) {
            final type = DestinationType.allTypes[index];
            final isSelected = selectedTypeIds.contains(type.id);

            return _DestinationTypeCard(
              type: type,
              isSelected: isSelected,
              onTap: () => _toggleSelection(type.id),
              selectionOrder: isSelected
                  ? selectedTypeIds.indexOf(type.id) + 1
                  : null,
            );
          },
        ),
      ],
    );
  }
}

class _DestinationTypeCard extends StatelessWidget {
  final DestinationType type;
  final bool isSelected;
  final VoidCallback onTap;
  final int? selectionOrder;

  const _DestinationTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
    this.selectionOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? type.color.withOpacity(0.15)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? type.color
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: type.color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Stack(
            children: [
              // Use LayoutBuilder to adapt to available space
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6), // FIXED: Reduced from 8
                          decoration: BoxDecoration(
                            color: isSelected
                                ? type.color.withOpacity(0.2)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            type.icon,
                            size: 18, // FIXED: Reduced from 20
                            color: isSelected
                                ? type.color
                                : Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Container(
                            width: 20, // FIXED: Reduced from 24
                            height: 20,
                            decoration: BoxDecoration(
                              color: type.color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 12, // FIXED: Reduced from 16
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6), // FIXED: Reduced from 8
                    // Name
                    Text(
                      type.name,
                      style: TextStyle(
                        fontSize: 12, // FIXED: Reduced from 13
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? type.color
                            : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Description - FIXED: Use Flexible to prevent overflow
                    Flexible(
                      child: Text(
                        type.description,
                        style: TextStyle(
                          fontSize: 10, // FIXED: Reduced from 11
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection order badge
              if (selectionOrder != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 18, // FIXED: Reduced from 20
                    height: 18,
                    decoration: BoxDecoration(
                      color: type.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '$selectionOrder',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10, // FIXED: Reduced from 11
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact version for display (read-only) - used in itinerary header
class DestinationTypeChips extends StatelessWidget {
  final List<String> typeIds;

  const DestinationTypeChips({
    super.key,
    required this.typeIds,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: typeIds.map((id) {
        final type = DestinationType.getById(id);
        if (type == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: type.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: type.color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, size: 12, color: type.color),
              const SizedBox(width: 4),
              Text(
                type.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: type.color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ============================================
// widgets for edit feature
// ============================================

/// Compact chip with emoji - used in trip info card
class DestinationTypeEmojiChip extends StatelessWidget {
  final String typeId;
  final bool showLabel;

  const DestinationTypeEmojiChip({
    super.key,
    required this.typeId,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final typeInfo = _getTypeInfo(typeId);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 8 : 6,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: typeInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeInfo['color'].withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(typeInfo['emoji'], style: const TextStyle(fontSize: 12)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              typeInfo['label'],
              style: TextStyle(
                fontSize: 10,
                color: typeInfo['color'],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getTypeInfo(String type) {
    final types = {
      'relaxing': {'emoji': '🏖️', 'label': 'Relaxing', 'color': Colors.cyan},
      'historical': {'emoji': '🏛️', 'label': 'Historical', 'color': Colors.brown},
      'adventure': {'emoji': '🎢', 'label': 'Adventure', 'color': Colors.orange},
      'shopping': {'emoji': '🛍️', 'label': 'Shopping', 'color': Colors.pink},
      'spiritual': {'emoji': '⛩️', 'label': 'Spiritual', 'color': Colors.purple},
      'entertainment': {'emoji': '🎭', 'label': 'Entertainment', 'color': Colors.red},
    };

    return types[type.toLowerCase()] ?? {
      'emoji': '📍',
      'label': type,
      'color': Colors.grey,
    };
  }
}

/// Horizontal scrollable list of type chips - for compact spaces
class DestinationTypeHorizontalList extends StatelessWidget {
  final List<String> typeIds;
  final bool showEmoji;

  const DestinationTypeHorizontalList({
    super.key,
    required this.typeIds,
    this.showEmoji = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: typeIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final type = DestinationType.getById(typeIds[index]);
          if (type == null) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: type.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: type.color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showEmoji) ...[
                  Text(_getEmoji(typeIds[index]), style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                ],
                Text(
                  type.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: type.color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getEmoji(String typeId) {
    const emojis = {
      'relaxing': '🏖️',
      'historical': '🏛️',
      'adventure': '🎢',
      'shopping': '🛍️',
      'spiritual': '⛩️',
      'entertainment': '🎭',
    };
    return emojis[typeId.toLowerCase()] ?? '📍';
  }
}

/// Mini badge for showing single type - used in itinerary cards
class DestinationTypeBadge extends StatelessWidget {
  final String typeId;
  final double fontSize;
  final EdgeInsets padding;

  const DestinationTypeBadge({
    super.key,
    required this.typeId,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    final type = DestinationType.getById(typeId);
    if (type == null) return const SizedBox.shrink();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: type.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: fontSize + 2, color: type.color),
          const SizedBox(width: 3),
          Text(
            type.name,
            style: TextStyle(
              fontSize: fontSize,
              color: type.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chips for selecting types in search/filter UI
class DestinationTypeFilterChips extends StatelessWidget {
  final List<String> selectedTypeIds;
  final Function(List<String>) onSelectionChanged;
  final bool allowMultiple;

  const DestinationTypeFilterChips({
    super.key,
    required this.selectedTypeIds,
    required this.onSelectionChanged,
    this.allowMultiple = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DestinationType.allTypes.map((type) {
        final isSelected = selectedTypeIds.contains(type.id);

        return FilterChip(
          selected: isSelected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type.icon,
                size: 14,
                color: isSelected ? Colors.white : type.color,
              ),
              const SizedBox(width: 4),
              Text(type.name),
            ],
          ),
          selectedColor: type.color,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 12,
          ),
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? type.color : Colors.grey[300]!,
            ),
          ),
          onSelected: (selected) {
            final newList = List<String>.from(selectedTypeIds);
            if (selected) {
              if (allowMultiple) {
                newList.add(type.id);
              } else {
                newList.clear();
                newList.add(type.id);
              }
            } else {
              newList.remove(type.id);
            }
            onSelectionChanged(newList);
          },
        );
      }).toList(),
    );
  }
}