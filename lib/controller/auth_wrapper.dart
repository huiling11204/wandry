import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controller/userAuth.dart';

/// Handles routing users to correct screen based on login status and role
class AuthWrapper {
  final AuthService _authService = AuthService();

  /// Checks if user is logged in and returns the correct route
  Future<String> determineInitialRoute() async {
    User? currentUser = _authService.currentUser;

    // Not logged in - go to welcome screen
    if (currentUser == null) {
      return '/welcome';
    }

    try {
      // Get user profile from database
      Map<String, dynamic>? userProfile = await _authService.getUserProfile(currentUser.uid);
      // No profile found - sign out and go to welcome
      if (userProfile == null) {
        await _authService.signOut();
        return '/welcome';
      }

      String? role = userProfile['role'];

      // Route based on role
      if (role == 'Admin') {
        return '/admin-dashboard';
      } else if (role == 'Customer') {
        return '/home';
      }

      // Unknown role - sign out for safety
      await _authService.signOut();
      return '/welcome';

    } catch (e) {
      print('Error determining route: $e');
      await _authService.signOut();
      return '/welcome';
    }
  }

  /// Returns the current user's role (Admin/Customer)
  Future<String?> getUserRole() async {
    User? currentUser = _authService.currentUser;
    if (currentUser == null) return null;

    try {
      Map<String, dynamic>? userProfile = await _authService.getUserProfile(currentUser.uid);
      return userProfile?['role'];
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  /// Returns true if current user is an admin
  Future<bool> isAdmin() async {
    String? role = await getUserRole();
    return role == 'Admin';
  }

  /// Returns true if current user is a customer
  Future<bool> isCustomer() async {
    String? role = await getUserRole();
    return role == 'Customer';
  }
}