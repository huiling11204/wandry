import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controller/userAuth.dart';

/// AuthWrapper - Business logic for routing authenticated users
/// Place this in lib/controller/auth_wrapper.dart
class AuthWrapper {
  final AuthService _authService = AuthService();

  /// Check user authentication and return appropriate route
  Future<String> determineInitialRoute() async {
    User? currentUser = _authService.currentUser;

    if (currentUser == null) {
      return '/welcome';
    }

    try {
      Map<String, dynamic>? userProfile = await _authService.getUserProfile(currentUser.uid);

      if (userProfile == null) {
        await _authService.signOut();
        return '/welcome';
      }

      String? role = userProfile['role'];

      if (role == 'Admin') {
        return '/admin-dashboard';
      } else if (role == 'Customer') {
        return '/home';
      }

      // Unknown role
      await _authService.signOut();
      return '/welcome';

    } catch (e) {
      print('Error determining route: $e');
      await _authService.signOut();
      return '/welcome';
    }
  }

  /// Get user role for conditional UI rendering
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

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    String? role = await getUserRole();
    return role == 'Admin';
  }

  /// Check if current user is customer
  Future<bool> isCustomer() async {
    String? role = await getUserRole();
    return role == 'Customer';
  }
}