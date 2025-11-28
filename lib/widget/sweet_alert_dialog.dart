// lib/widget/sweet_alert_dialog.dart
// Beautiful SweetAlert-style dialogs for the app

import 'package:flutter/material.dart';

enum SweetAlertType {
  success,
  error,
  warning,
  info,
  confirm,
}

class SweetAlertDialog {
  static Future<bool?> show({
    required BuildContext context,
    required SweetAlertType type,
    required String title,
    String? subtitle,
    Widget? content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
    bool showCancelButton = false,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: _SweetAlertContent(
              type: type,
              title: title,
              subtitle: subtitle,
              content: content,
              confirmText: confirmText,
              cancelText: cancelText,
              onConfirm: onConfirm,
              onCancel: onCancel,
              showCancelButton: showCancelButton,
            ),
          ),
        );
      },
    );
  }

  // Convenience methods
  static Future<void> success({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) {
    return show(
      context: context,
      type: SweetAlertType.success,
      title: title,
      subtitle: subtitle,
      confirmText: confirmText,
      onConfirm: onConfirm,
    );
  }

  static Future<void> error({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) {
    return show(
      context: context,
      type: SweetAlertType.error,
      title: title,
      subtitle: subtitle,
      confirmText: confirmText,
      onConfirm: onConfirm,
    );
  }

  static Future<void> warning({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) {
    return show(
      context: context,
      type: SweetAlertType.warning,
      title: title,
      subtitle: subtitle,
      confirmText: confirmText,
      onConfirm: onConfirm,
    );
  }

  static Future<void> info({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) {
    return show(
      context: context,
      type: SweetAlertType.info,
      title: title,
      subtitle: subtitle,
      confirmText: confirmText,
      onConfirm: onConfirm,
    );
  }

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return show(
      context: context,
      type: SweetAlertType.confirm,
      title: title,
      subtitle: subtitle,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: onConfirm,
      onCancel: onCancel,
      showCancelButton: true,
    );
  }
}

class _SweetAlertContent extends StatefulWidget {
  final SweetAlertType type;
  final String title;
  final String? subtitle;
  final Widget? content;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool showCancelButton;

  const _SweetAlertContent({
    required this.type,
    required this.title,
    this.subtitle,
    this.content,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.showCancelButton = false,
  });

  @override
  State<_SweetAlertContent> createState() => _SweetAlertContentState();
}

class _SweetAlertContentState extends State<_SweetAlertContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _iconAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _iconAnimationController.forward();
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Icon
                ScaleTransition(
                  scale: _iconAnimation,
                  child: _buildIcon(),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Subtitle
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Custom content
                if (widget.content != null) ...[
                  const SizedBox(height: 16),
                  widget.content!,
                ],

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    if (widget.showCancelButton) ...[
                      Expanded(
                        child: _buildButton(
                          text: widget.cancelText ?? 'Cancel',
                          isOutlined: true,
                          onPressed: () {
                            Navigator.pop(context, false);
                            widget.onCancel?.call();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _buildButton(
                        text: widget.confirmText ?? 'OK',
                        isOutlined: false,
                        onPressed: () {
                          Navigator.pop(context, true);
                          widget.onConfirm?.call();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    Color backgroundColor;
    Color iconColor;
    IconData icon;

    switch (widget.type) {
      case SweetAlertType.success:
        backgroundColor = Colors.green[50]!;
        iconColor = Colors.green[600]!;
        icon = Icons.check_circle;
        break;
      case SweetAlertType.error:
        backgroundColor = Colors.red[50]!;
        iconColor = Colors.red[600]!;
        icon = Icons.error;
        break;
      case SweetAlertType.warning:
        backgroundColor = Colors.orange[50]!;
        iconColor = Colors.orange[600]!;
        icon = Icons.warning_rounded;
        break;
      case SweetAlertType.info:
        backgroundColor = Colors.blue[50]!;
        iconColor = Colors.blue[600]!;
        icon = Icons.info;
        break;
      case SweetAlertType.confirm:
        backgroundColor = Colors.purple[50]!;
        iconColor = Colors.purple[600]!;
        icon = Icons.help_outline;
        break;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 48,
        color: iconColor,
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isOutlined,
    required VoidCallback onPressed,
  }) {
    Color buttonColor;
    switch (widget.type) {
      case SweetAlertType.success:
        buttonColor = Colors.green[600]!;
        break;
      case SweetAlertType.error:
        buttonColor = Colors.red[600]!;
        break;
      case SweetAlertType.warning:
        buttonColor = Colors.orange[600]!;
        break;
      case SweetAlertType.info:
        buttonColor = Colors.blue[600]!;
        break;
      case SweetAlertType.confirm:
        buttonColor = Colors.purple[600]!;
        break;
    }

    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          side: BorderSide(color: Colors.grey[300]!),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 2,
        shadowColor: buttonColor.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Route Warning Dialog - Special dialog for reorder warnings
class RouteWarningDialog extends StatelessWidget {
  final String itemName;
  final double addedDistance;
  final int addedTime;
  final double oldDistance;
  final double newDistance;

  const RouteWarningDialog({
    super.key,
    required this.itemName,
    required this.addedDistance,
    required this.addedTime,
    required this.oldDistance,
    required this.newDistance,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String itemName,
    required double addedDistance,
    required int addedTime,
    required double oldDistance,
    required double newDistance,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: RouteWarningDialog(
              itemName: itemName,
              addedDistance: addedDistance,
              addedTime: addedTime,
              oldDistance: oldDistance,
              newDistance: newDistance,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignificant = addedDistance.abs() > 5 || addedTime.abs() > 20;
    final isImprovement = addedDistance < 0;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isImprovement
                        ? Colors.green[50]
                        : isSignificant
                        ? Colors.orange[50]
                        : Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isImprovement
                        ? Icons.thumb_up
                        : isSignificant
                        ? Icons.warning_rounded
                        : Icons.swap_vert,
                    size: 48,
                    color: isImprovement
                        ? Colors.green[600]
                        : isSignificant
                        ? Colors.orange[600]
                        : Colors.blue[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  isImprovement ? 'Great Choice!' : 'Route Change',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Moving "$itemName"',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Stats Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isImprovement
                        ? Colors.green[50]
                        : isSignificant
                        ? Colors.orange[50]
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isImprovement
                          ? Colors.green[200]!
                          : isSignificant
                          ? Colors.orange[200]!
                          : Colors.blue[200]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Distance change
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.route,
                              size: 24,
                              color: isImprovement
                                  ? Colors.green[600]
                                  : isSignificant
                                  ? Colors.orange[600]
                                  : Colors.blue[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Distance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      isImprovement
                                          ? '${addedDistance.abs().toStringAsFixed(1)} km shorter'
                                          : '+${addedDistance.toStringAsFixed(1)} km',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isImprovement
                                            ? Colors.green[700]
                                            : isSignificant
                                            ? Colors.orange[700]
                                            : Colors.blue[700],
                                      ),
                                    ),
                                    if (!isImprovement) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: isSignificant
                                            ? Colors.orange[600]
                                            : Colors.blue[600],
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Time change
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.schedule,
                              size: 24,
                              color: isImprovement
                                  ? Colors.green[600]
                                  : isSignificant
                                  ? Colors.orange[600]
                                  : Colors.blue[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Travel Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  isImprovement
                                      ? '~${addedTime.abs()} min saved'
                                      : '+~$addedTime min',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isImprovement
                                        ? Colors.green[700]
                                        : isSignificant
                                        ? Colors.orange[700]
                                        : Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Warning message for significant changes
                if (isSignificant && !isImprovement) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is a significant route change. Make sure this is what you want.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isImprovement
                              ? Colors.green[600]
                              : isSignificant
                              ? Colors.orange[600]
                              : Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isImprovement ? 'Apply' : 'Reorder Anyway',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}