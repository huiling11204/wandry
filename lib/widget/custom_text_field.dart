import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final bool isValid;
  final String errorText;
  final String? value;
  final bool obscureText;
  final bool showVisibilityToggle;
  final VoidCallback? onVisibilityToggle;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool isFocused;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.prefixIcon,
    required this.isValid,
    required this.errorText,
    this.value,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.onVisibilityToggle,
    this.keyboardType,
    this.enabled = true,
    this.isFocused = false,
  });

  Color _getBorderColor(BuildContext context) {
    final theme = Theme.of(context);

    if (errorText.isNotEmpty) return theme.colorScheme.error;
    if (isFocused) return theme.colorScheme.primary;
    if (isValid && value != null && value!.isNotEmpty) return Colors.green.shade400;
    return theme.colorScheme.surfaceDim;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getBorderColor(context),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: theme.textTheme.bodyMedium,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.labelMedium,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: theme.colorScheme.onTertiary)
                  : null,
              suffixIcon: showVisibilityToggle
                  ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.colorScheme.onTertiary,
                ),
                onPressed: enabled ? onVisibilityToggle : null,
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text(
              errorText,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ),
      ],
    );
  }
}

/// Alternative version for Register page style
class CustomTextFieldWithIcon extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData prefixIcon;
  final bool isValid;
  final String errorText;
  final String? value;
  final bool obscureText;
  final bool showVisibilityToggle;
  final VoidCallback? onVisibilityToggle;
  final TextInputType? keyboardType;
  final bool enabled;

  const CustomTextFieldWithIcon({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.prefixIcon,
    required this.isValid,
    required this.errorText,
    this.value,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.onVisibilityToggle,
    this.keyboardType,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText.isNotEmpty
                  ? theme.colorScheme.error
                  : isValid && value != null && value!.isNotEmpty
                  ? Colors.green.shade400
                  : theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: theme.textTheme.bodyMedium,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.labelSmall,
              prefixIcon: Icon(
                prefixIcon,
                color: theme.colorScheme.onTertiary,
              ),
              suffixIcon: showVisibilityToggle
                  ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: theme.colorScheme.onTertiary,
                ),
                onPressed: enabled ? onVisibilityToggle : null,
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              errorText,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
                fontFamily: theme.textTheme.bodySmall?.fontFamily,
              ),
            ),
          ),
      ],
    );
  }
}