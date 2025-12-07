import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages all ADMIN-SIDE dark mode
class ThemeController extends ChangeNotifier {
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isDarkMode = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// Initialize dark mode preference from Firestore
  Future<void> initializeTheme(String? userId) async {
    if (userId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final doc = await _firestore
          .collection('userSettings')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        _isDarkMode = data?['adminDarkMode'] ?? false;
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading theme: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle dark mode and save to Firestore
  Future<void> toggleDarkMode(bool isDark) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _isDarkMode = isDark;
      notifyListeners();

      await _firestore
          .collection('userSettings')
          .doc(user.uid)
          .set({
        'adminDarkMode': isDark,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving theme: $e');
      // Revert on error
      _isDarkMode = !isDark;
      notifyListeners();
    }
  }

  // ============================================
  // ADMIN DARK MODE COLORS
  // ============================================

  /// Main background color
  Color get backgroundColor => _isDarkMode
      ? const Color(0xFF121212)
      : Colors.grey[50]!;

  /// Card/Container background
  Color get cardColor => _isDarkMode
      ? const Color(0xFF1E1E1E)
      : Colors.white;

  /// Elevated card (slightly lighter in dark mode)
  Color get elevatedCardColor => _isDarkMode
      ? const Color(0xFF2D2D2D)
      : Colors.white;

  /// AppBar background
  Color get appBarColor => _isDarkMode
      ? const Color(0xFF1E1E1E)
      : const Color(0xFFB3D9E8);

  /// AppBar text/icon color
  Color get appBarForegroundColor => _isDarkMode
      ? Colors.white
      : Colors.black87;

  /// Primary text color
  Color get textColor => _isDarkMode
      ? Colors.white
      : Colors.black87;

  /// Secondary/subtitle text color
  Color get subtitleColor => _isDarkMode
      ? Colors.grey[400]!
      : Colors.grey[600]!;

  /// Hint/placeholder text color
  Color get hintColor => _isDarkMode
      ? Colors.grey[500]!
      : Colors.grey[400]!;

  /// Divider color
  Color get dividerColor => _isDarkMode
      ? Colors.grey[800]!
      : Colors.grey[200]!;

  /// Input field fill color
  Color get inputFillColor => _isDarkMode
      ? const Color(0xFF2D2D2D)
      : Colors.grey[100]!;

  /// Input field border color
  Color get inputBorderColor => _isDarkMode
      ? Colors.grey[700]!
      : Colors.grey[300]!;

  /// Icon color (secondary)
  Color get iconColor => _isDarkMode
      ? Colors.grey[400]!
      : Colors.grey[600]!;

  /// Sidebar background (for admin dashboard)
  Color get sidebarColor => _isDarkMode
      ? const Color(0xFF1E1E1E)
      : const Color(0xFFB3D9E8);

  /// List tile color
  Color get listTileColor => _isDarkMode
      ? const Color(0xFF1E1E1E)
      : Colors.white;

  /// Selected item background
  Color get selectedItemColor => _isDarkMode
      ? Colors.blue.withOpacity(0.2)
      : Colors.blue.withOpacity(0.1);

  /// Shadow color
  Color get shadowColor => _isDarkMode
      ? Colors.black.withOpacity(0.3)
      : Colors.black.withOpacity(0.05);

  /// Border color for cards
  Color get borderColor => _isDarkMode
      ? Colors.grey[800]!
      : Colors.grey[200]!;

  /// Scaffold background for dialogs
  Color get dialogBackgroundColor => _isDarkMode
      ? const Color(0xFF2D2D2D)
      : Colors.white;

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Get BoxDecoration for cards
  BoxDecoration cardDecoration({
    double borderRadius = 12,
    bool hasBorder = false,
    Color? customBorderColor,
  }) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder
          ? Border.all(color: customBorderColor ?? borderColor)
          : null,
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Get InputDecoration for text fields
  InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: inputFillColor,
      labelStyle: TextStyle(color: subtitleColor),
      hintStyle: TextStyle(color: hintColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: inputBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: inputBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
      ),
    );
  }

  /// Get TextStyle for titles
  TextStyle titleStyle({double fontSize = 18, FontWeight fontWeight = FontWeight.bold}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: textColor,
    );
  }

  /// Get TextStyle for subtitles
  TextStyle subtitleStyle({double fontSize = 14}) {
    return TextStyle(
      fontSize: fontSize,
      color: subtitleColor,
    );
  }
}