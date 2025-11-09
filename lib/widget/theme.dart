import 'package:flutter/material.dart';

final ThemeData AppTheme = ThemeData(
  scaffoldBackgroundColor: Colors.white,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF1E90FF),
    primary: Color(0xFF1E90FF), // Primary Blue
    onPrimary: Colors.white,
    secondary: Color(0xFFB3D9FF), // Light blue
    onSecondary: Color(0xFF333333),
    tertiary: Color(0xFFFF5252), // Red for delete/error
    onTertiary: Color(0xFF757575), // Grey icons
    error: Color(0xFFFF5252),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF333333),
    surfaceDim: Color(0xFFE0E0E0), // Border color
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(
    // --> Main page heading "Welcome to Wandry"
    displayLarge: TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w600,
      fontSize: 28,
      color: Color(0xFF333333),
    ),
    // --> Page Title "Log In", "Settings", "My Profile"
    headlineLarge: TextStyle(
      color: Color(0xFF333333),
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w600,
      fontSize: 24,
    ),
    // --> Section heading
    headlineMedium: TextStyle(
      color: Color(0xFF333333),
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w600,
      fontSize: 20,
    ),
    // --> Subtitle text "Please sign in to continue our app"
    headlineSmall: TextStyle(
      color: Color(0xFF9E9E9E),
      fontFamily: 'Poppins',
      fontSize: 14,
    ),
    // --> Form field labels "Enter your email"
    labelLarge: TextStyle(
      color: Color(0xFF9E9E9E),
      fontFamily: 'Poppins',
      fontSize: 12,
      fontWeight: FontWeight.normal,
    ),
    // --> Placeholder text in fields
    labelMedium: TextStyle(
      color: Color(0xFFBDBDBD),
      fontSize: 14,
      fontFamily: 'Poppins',
    ),
    // --> Card/Item titles
    titleLarge: TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w600,
      fontSize: 18,
      color: Color(0xFF333333),
    ),
    // --> Menu items
    titleMedium: TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w500,
      fontSize: 16,
      color: Color(0xFF333333),
    ),
    // --> Normal body text
    bodyMedium: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: Color(0xFF616161),
    ),
    // --> Small secondary text
    bodySmall: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 12,
      color: Color(0xFF9E9E9E),
    ),
  ),
  appBarTheme: AppBarTheme(
    color: Colors.white,
    elevation: 0,
    foregroundColor: Color(0xFF333333),
    titleTextStyle: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFF333333),
    ),
    centerTitle: true,
    iconTheme: IconThemeData(color: Color(0xFF333333)),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
      overlayColor: WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStatePropertyAll(Color(0xFF1E90FF)),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.normal,
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.symmetric(vertical: 16),
      minimumSize: Size(double.infinity, 50),
      foregroundColor: Colors.white,
      backgroundColor: Color(0xFF1E90FF),
      textStyle: TextStyle(
        fontSize: 16,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.symmetric(vertical: 16),
      minimumSize: Size(double.infinity, 50),
      side: BorderSide(color: Color(0xFF1E90FF), width: 1.5),
      foregroundColor: Color(0xFF1E90FF),
      textStyle: TextStyle(
        fontSize: 16,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 2,
    shadowColor: Colors.black.withOpacity(0.1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  listTileTheme: ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    iconColor: Color(0xFF757575),
    textColor: Color(0xFF333333),
    tileColor: Colors.white,
  ),
  dividerTheme: DividerThemeData(
    color: Color(0xFFE0E0E0),
    thickness: 1,
  ),
  iconTheme: IconThemeData(
    color: Color(0xFF757575),
    size: 24,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Color(0xFF1E90FF),
    unselectedItemColor: Color(0xFF9E9E9E),
    selectedLabelStyle: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 12,
      fontWeight: FontWeight.normal,
    ),
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
);

// Additional colors for specific use cases
class AppColors {
  static const Color primaryBlue = Color(0xFF1E90FF);
  static const Color dangerRed = Color(0xFFFF5252);
  static const Color successGreen = Color(0xFF4CAF50);

  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color textPlaceholder = Color(0xFFBDBDBD);

  static const Color borderDefault = Color(0xFFE0E0E0);
  static const Color borderFocused = Color(0xFF1E90FF);

  static const Color adminSidebarBg = Color(0xFFB3E5FC);

  // Chart colors
  static const Color chartYellow = Color(0xFFFFD54F);
  static const Color chartOrange = Color(0xFFFF9800);
  static const Color chartRed = Color(0xFFEF5350);
  static const Color chartGreen = Color(0xFF66BB6A);
  static const Color chartPink = Color(0xFFEC407A);
}