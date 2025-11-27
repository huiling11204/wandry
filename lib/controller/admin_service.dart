import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AdminService - Direct Firestore queries (No Cloud Functions needed)
/// Place this in lib/controller/admin_service.dart
///
/// Admin verification uses TWO checks:
/// 1. User collection: role == 'Admin' (for app logic)
/// 2. Admins collection: document exists with firebaseUid (for Firestore security rules)
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==========================================
  // ADMIN VERIFICATION
  // ==========================================

  /// Check if current user is an admin
  /// Checks both user collection role AND admins collection
  Future<bool> isCurrentUserAdmin() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return false;

      // Check 1: User collection role
      QuerySnapshot userQuery = await _firestore
          .collection('user')
          .where('firebaseUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return false;

      Map<String, dynamic> userData =
      userQuery.docs.first.data() as Map<String, dynamic>;

      if (userData['role'] != 'Admin') return false;

      // Check 2: Admins collection (for security rules compatibility)
      DocumentSnapshot adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      return adminDoc.exists;
    } catch (e) {
      print('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// Verify admin before operations (throws if not admin)
  Future<void> _verifyAdmin() async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated');
    }

    bool isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) {
      throw Exception('User is not an admin');
    }
  }

  // ==========================================
  // USER MANAGEMENT
  // ==========================================

  /// Get all users with their profiles
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      print('🔄 AdminService: Fetching all users...');

      await _verifyAdmin();

      // Get all users
      QuerySnapshot usersSnapshot = await _firestore.collection('user').get();
      List<Map<String, dynamic>> users = [];

      for (var doc in usersSnapshot.docs) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        String firebaseUid = userData['firebaseUid'] ?? '';
        String role = userData['role'] ?? '';

        // Get profile based on role
        Map<String, dynamic>? profile;

        if (role == 'Customer' && firebaseUid.isNotEmpty) {
          QuerySnapshot profileSnapshot = await _firestore
              .collection('customerProfile')
              .where('firebaseUid', isEqualTo: firebaseUid)
              .limit(1)
              .get();

          if (profileSnapshot.docs.isNotEmpty) {
            profile =
            profileSnapshot.docs.first.data() as Map<String, dynamic>;
          }
        } else if (role == 'Admin' && firebaseUid.isNotEmpty) {
          QuerySnapshot profileSnapshot = await _firestore
              .collection('adminProfile')
              .where('firebaseUid', isEqualTo: firebaseUid)
              .limit(1)
              .get();

          if (profileSnapshot.docs.isNotEmpty) {
            profile =
            profileSnapshot.docs.first.data() as Map<String, dynamic>;
          }
        }

        users.add({
          ...userData,
          'profile': profile,
          'docId': doc.id,
        });
      }

      print('✅ AdminService: Fetched ${users.length} users');
      return users;
    } catch (e) {
      print('❌ AdminService: Error getting all users: $e');
      rethrow;
    }
  }

  /// Delete a user and their profile
  Future<void> deleteUser(String userId, String firebaseUid) async {
    try {
      print('🔄 AdminService: Deleting user $userId...');

      await _verifyAdmin();

      // Prevent deleting yourself
      User? currentUser = _auth.currentUser;
      if (currentUser?.uid == firebaseUid) {
        throw Exception('Cannot delete your own account');
      }

      // Get user document to find role
      DocumentSnapshot userDoc =
      await _firestore.collection('user').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String role = userData['role'] ?? '';

      // Delete profile based on role
      if (role == 'Customer') {
        QuerySnapshot profileSnapshot = await _firestore
            .collection('customerProfile')
            .where('firebaseUid', isEqualTo: firebaseUid)
            .limit(1)
            .get();

        if (profileSnapshot.docs.isNotEmpty) {
          await profileSnapshot.docs.first.reference.delete();
          print('✅ Deleted customer profile');
        }
      } else if (role == 'Admin') {
        // Delete admin profile
        QuerySnapshot profileSnapshot = await _firestore
            .collection('adminProfile')
            .where('firebaseUid', isEqualTo: firebaseUid)
            .limit(1)
            .get();

        if (profileSnapshot.docs.isNotEmpty) {
          await profileSnapshot.docs.first.reference.delete();
          print('✅ Deleted admin profile');
        }

        // Also delete from admins collection
        await _firestore.collection('admins').doc(firebaseUid).delete();
        print('✅ Deleted from admins collection');
      }

      // Delete user document
      await _firestore.collection('user').doc(userId).delete();
      print('✅ Deleted user document');

      print('✅ AdminService: User deleted successfully');
    } catch (e) {
      print('❌ AdminService: Error deleting user: $e');
      rethrow;
    }
  }

  // ==========================================
  // FEEDBACK MANAGEMENT
  // ==========================================

  /// Get all feedback submissions
  /// Customer feedback model uses: rating, comment, createdAt, updatedAt, userEmail
  Future<List<Map<String, dynamic>>> getAllFeedback() async {
    try {
      print('🔄 AdminService: Fetching all feedback...');

      await _verifyAdmin();

      QuerySnapshot feedbackSnapshot;

      try {
        // Try with ordering by createdAt first (customer model field)
        feedbackSnapshot = await _firestore
            .collection('feedback')
            .orderBy('createdAt', descending: true)
            .get();
        print('✅ Fetched feedback with createdAt ordering');
      } catch (e) {
        // If ordering fails (no index), get without order
        print('⚠️ Ordering by createdAt failed, trying without order: $e');
        feedbackSnapshot = await _firestore.collection('feedback').get();
      }

      List<Map<String, dynamic>> feedbackList = [];

      for (var doc in feedbackSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        feedbackList.add({
          'id': doc.id,
          ...data,
        });
      }

      // Sort manually by createdAt if ordering wasn't applied
      feedbackList.sort((a, b) {
        // Try createdAt first (customer model)
        var aTime = a['createdAt'] ?? a['timestamp'];
        var bTime = b['createdAt'] ?? b['timestamp'];

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return (bTime as Timestamp).compareTo(aTime as Timestamp);
      });

      print('✅ AdminService: Fetched ${feedbackList.length} feedback entries');

      // Debug: print first feedback structure
      if (feedbackList.isNotEmpty) {
        print('📊 Sample feedback structure: ${feedbackList.first.keys.toList()}');
      }

      return feedbackList;
    } catch (e) {
      print('❌ AdminService: Error getting all feedback: $e');
      print('❌ Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Delete a feedback entry
  Future<void> deleteFeedback(String feedbackId) async {
    try {
      print('🔄 AdminService: Deleting feedback $feedbackId...');

      await _verifyAdmin();

      await _firestore.collection('feedback').doc(feedbackId).delete();

      print('✅ AdminService: Feedback deleted successfully');
    } catch (e) {
      print('❌ AdminService: Error deleting feedback: $e');
      rethrow;
    }
  }

  // ==========================================
  // STATISTICS
  // ==========================================

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      print('🔄 AdminService: Fetching user statistics...');

      await _verifyAdmin();

      QuerySnapshot usersSnapshot = await _firestore.collection('user').get();

      int totalUsers = 0;
      int totalCustomers = 0;
      int totalAdmins = 0;
      int newUsersThisMonth = 0;

      DateTime now = DateTime.now();
      DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);

      for (var doc in usersSnapshot.docs) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        totalUsers++;

        if (userData['role'] == 'Customer') {
          totalCustomers++;
        } else if (userData['role'] == 'Admin') {
          totalAdmins++;
        }

        // Count new users this month
        if (userData['registrationDate'] != null) {
          try {
            Timestamp regTimestamp = userData['registrationDate'] as Timestamp;
            DateTime regDate = regTimestamp.toDate();
            if (regDate.isAfter(firstDayOfMonth)) {
              newUsersThisMonth++;
            }
          } catch (e) {
            print('⚠️ Error parsing registration date: $e');
          }
        }
      }

      Map<String, dynamic> stats = {
        'totalUsers': totalUsers,
        'totalCustomers': totalCustomers,
        'totalAdmins': totalAdmins,
        'newUsersThisMonth': newUsersThisMonth,
      };

      print('✅ AdminService: Statistics calculated');
      print('   Total Users: $totalUsers');
      print('   Customers: $totalCustomers');
      print('   Admins: $totalAdmins');
      print('   New This Month: $newUsersThisMonth');

      return stats;
    } catch (e) {
      print('❌ AdminService: Error getting user statistics: $e');
      rethrow;
    }
  }

  // ==========================================
  // ROLE MANAGEMENT
  // ==========================================

  /// Update a user's role (USE WITH CAUTION!)
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      print('🔄 AdminService: Updating user $userId role to $newRole...');

      await _verifyAdmin();

      if (newRole != 'Customer' && newRole != 'Admin') {
        throw Exception(
            'Invalid role: $newRole. Must be "Customer" or "Admin".');
      }

      // Get current user to prevent self-role-change
      User? currentUser = _auth.currentUser;
      DocumentSnapshot userDoc =
      await _firestore.collection('user').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      if (userData['firebaseUid'] == currentUser?.uid) {
        throw Exception('Cannot change your own role');
      }

      String oldRole = userData['role'] ?? '';
      String firebaseUid = userData['firebaseUid'] ?? '';

      // Update role in user document
      await _firestore.collection('user').doc(userId).update({
        'role': newRole,
      });

      // Handle admins collection based on role change
      if (newRole == 'Admin' && oldRole != 'Admin') {
        // Promoting to admin - add to admins collection
        await _firestore.collection('admins').doc(firebaseUid).set({
          'email': userData['email'],
          'addedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Added to admins collection');
      } else if (newRole != 'Admin' && oldRole == 'Admin') {
        // Demoting from admin - remove from admins collection
        await _firestore.collection('admins').doc(firebaseUid).delete();
        print('✅ Removed from admins collection');
      }

      print('✅ AdminService: User role updated successfully');
    } catch (e) {
      print('❌ AdminService: Error updating user role: $e');
      rethrow;
    }
  }

  // ==========================================
  // ERROR HANDLING HELPERS
  // ==========================================

  /// Get user-friendly error message
  String getErrorMessage(dynamic error) {
    String errorStr = error.toString();

    if (errorStr.contains('User must be authenticated')) {
      return 'You must be logged in to perform this action.';
    } else if (errorStr.contains('User is not an admin')) {
      return 'You do not have permission to perform this action. Admin access required.';
    } else if (errorStr.contains('Cannot delete your own')) {
      return 'You cannot delete your own account.';
    } else if (errorStr.contains('Cannot change your own')) {
      return 'You cannot change your own role.';
    } else if (errorStr.contains('not found') ||
        errorStr.contains('NOT_FOUND')) {
      return 'The requested item was not found.';
    } else if (errorStr.contains('PERMISSION_DENIED')) {
      return 'Permission denied. Please check Firestore security rules.';
    } else if (errorStr.contains('requires an index')) {
      return 'Database index required. Please create the index in Firebase Console.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}