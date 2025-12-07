import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/favorite_controller.dart';

/// Shows filled heart when favorited, outline when not
class FavoriteButton extends StatefulWidget {
  final Map<String, dynamic> place;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showBackground;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final VoidCallback? onToggle;
  final bool mini; // For smaller version on cards

  const FavoriteButton({
    super.key,
    required this.place,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
    this.showBackground = true,
    this.backgroundColor,
    this.padding,
    this.onToggle,
    this.mini = false,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool _isToggling = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _toggleFavorite(bool currentStatus) async {
    if (_isToggling) return; // Prevent double-tap

    if (!FavoriteController.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    setState(() => _isToggling = true);

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Play animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    try {
      final newStatus = await FavoriteController.toggleFavorite(widget.place);

      if (mounted) {
        // Show feedback
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  newStatus
                      ? 'Added to favorites'
                      : 'Removed from favorites',
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: !newStatus
                ? SnackBarAction(
              label: 'Undo',
              textColor: Colors.yellow,
              onPressed: () => _toggleFavorite(false),
            )
                : null,
          ),
        );

        widget.onToggle?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.login, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Please log in to save favorites'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Log In',
          textColor: Colors.yellow,
          onPressed: () {
            Navigator.pushNamed(context, '/login');
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSize = widget.mini ? 18.0 : widget.size;
    final activeColor = widget.activeColor ?? Colors.red;
    final inactiveColor = widget.inactiveColor ?? Colors.grey[600]!;

    // Use StreamBuilder for real-time updates
    return StreamBuilder<bool>(
      stream: FavoriteController.streamIsFavorite(widget.place),
      builder: (context, snapshot) {
        // Show loading indicator only briefly on first load
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return SizedBox(
            width: effectiveSize,
            height: effectiveSize,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
            ),
          );
        }

        final isFavorite = snapshot.data ?? false;

        Widget heartIcon = ScaleTransition(
          scale: _scaleAnimation,
          child: _isToggling
              ? SizedBox(
            width: effectiveSize,
            height: effectiveSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          )
              : Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            size: effectiveSize,
            color: isFavorite ? activeColor : inactiveColor,
          ),
        );

        if (widget.showBackground) {
          return GestureDetector(
            onTap: _isToggling ? null : () => _toggleFavorite(isFavorite),
            child: Container(
              padding: widget.padding ?? EdgeInsets.all(widget.mini ? 4 : 6),
              decoration: BoxDecoration(
                color: widget.backgroundColor ??
                    Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: heartIcon,
            ),
          );
        }

        return GestureDetector(
          onTap: _isToggling ? null : () => _toggleFavorite(isFavorite),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(4),
            child: heartIcon,
          ),
        );
      },
    );
  }
}

/// A favorite button specifically designed for list items
class FavoriteListTileButton extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback? onToggle;

  const FavoriteListTileButton({
    super.key,
    required this.place,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FavoriteButton(
      place: place,
      size: 24,
      showBackground: false,
      onToggle: onToggle,
    );
  }
}

/// A favorite button for cards (smaller, positioned in corner)
class FavoriteCardButton extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback? onToggle;

  const FavoriteCardButton({
    super.key,
    required this.place,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FavoriteButton(
      place: place,
      mini: true,
      size: 16,
      showBackground: true,
      backgroundColor: Colors.white.withOpacity(0.9),
      padding: const EdgeInsets.all(5),
      onToggle: onToggle,
    );
  }
}