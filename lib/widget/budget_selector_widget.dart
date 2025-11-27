import 'package:flutter/material.dart';

class BudgetSelectorWidget extends StatelessWidget {
  final String selectedBudget;
  final Function(String) onBudgetSelected;

  const BudgetSelectorWidget({
    super.key,
    required this.selectedBudget,
    required this.onBudgetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BudgetChip(
          label: 'Low',
          icon: Icons.attach_money,
          isSelected: selectedBudget == 'Low',
          onTap: () => onBudgetSelected('Low'),
        ),
        const SizedBox(width: 12),
        _BudgetChip(
          label: 'Medium',
          icon: Icons.monetization_on,
          isSelected: selectedBudget == 'Medium',
          onTap: () => onBudgetSelected('Medium'),
        ),
        const SizedBox(width: 12),
        _BudgetChip(
          label: 'High',
          icon: Icons.diamond,
          isSelected: selectedBudget == 'High',
          onTap: () => onBudgetSelected('High'),
        ),
      ],
    );
  }
}

class _BudgetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _BudgetChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4A90E2).withOpacity(0.1)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}