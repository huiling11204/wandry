// ============================================
// PROFILE CONTROLLER - Business Logic
// Location: lib/controller/profileController.dart
// ============================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // ---------------------------------------------------
  // LOAD PROFILE DATA
  // ---------------------------------------------------
  Future<Map<String, dynamic>> loadProfile() async {
    if (currentUser == null) {
      throw 'User not authenticated';
    }

    print('🔍 Loading profile for UID: ${currentUser!.uid}');

    // Step 1: Get user document to find email
    QuerySnapshot userQuery = await _firestore
        .collection('user')
        .where('firebaseUid', isEqualTo: currentUser!.uid)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      print('❌ No user document found');
      throw 'User profile not found';
    }

    Map<String, dynamic> userData = userQuery.docs.first.data() as Map<String, dynamic>;
    String email = userData['email'] ?? currentUser!.email ?? 'Not set';
    String role = userData['role'] ?? 'Customer';

    print('✅ User found - Role: $role, Email: $email');

    // Step 2: Get customer profile using firebaseUid
    QuerySnapshot profileQuery = await _firestore
        .collection('customerProfile')
        .where('firebaseUid', isEqualTo: currentUser!.uid)
        .limit(1)
        .get();

    if (profileQuery.docs.isEmpty) {
      print('❌ No customer profile found');
      // Use fallback data
      return {
        'firstName': currentUser!.displayName ?? 'User',
        'lastName': '',
        'email': email,
        'phoneNumber': 'Not set',
      };
    }

    Map<String, dynamic> customerData = profileQuery.docs.first.data() as Map<String, dynamic>;

    print('✅ Customer profile found');
    print('📋 Data: $customerData');

    // Combine firstName and lastName for display
    String firstName = customerData['firstName'] ?? '';
    String lastName = customerData['lastName'] ?? '';
    String fullName = '$firstName $lastName'.trim();
    if (fullName.isEmpty) fullName = 'User';

    return {
      'fullName': fullName,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': customerData['phoneNumber'] ?? 'Not set',
      'custProfileID': customerData['custProfileID'],
      'userID': customerData['userID'],
    };
  }

  // ---------------------------------------------------
  // UPDATE PROFILE DATA
  // ---------------------------------------------------
  Future<Map<String, String>> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String originalEmail,
  }) async {
    if (currentUser == null) {
      throw 'User not authenticated';
    }

    print('💾 Starting profile update...');

    // Step 1: Update customerProfile collection
    print('📝 Updating customer profile...');
    QuerySnapshot profileQuery = await _firestore
        .collection('customerProfile')
        .where('firebaseUid', isEqualTo: currentUser!.uid)
        .limit(1)
        .get();

    if (profileQuery.docs.isEmpty) {
      throw 'Customer profile not found';
    }

    await profileQuery.docs.first.reference.update({
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
    });
    print('✅ Customer profile updated');

    String emailMessage = '';

    // Step 2: Update email in user collection if changed
    if (email != originalEmail) {
      print('📧 Updating email in user collection...');
      QuerySnapshot userQuery = await _firestore
          .collection('user')
          .where('firebaseUid', isEqualTo: currentUser!.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        await userQuery.docs.first.reference.update({
          'email': email,
        });
        print('✅ Email updated in user collection');
      }

      // Update Firebase Auth email (requires re-authentication for security)
      try {
        await currentUser!.verifyBeforeUpdateEmail(email);
        print('✅ Verification email sent to new address');
        emailMessage = 'verification_sent';
      } catch (e) {
        print('⚠️ Email update requires re-authentication: $e');
        emailMessage = 'requires_reauth';
      }
    }

    // Step 3: Update Firebase Auth display name
    String fullName = '$firstName $lastName'.trim();
    await currentUser!.updateDisplayName(fullName);
    print('✅ Display name updated to: $fullName');

    print('🎉 Profile update complete!');

    return {
      'status': 'success',
      'emailMessage': emailMessage,
      'newEmail': email,
    };
  }

  // ---------------------------------------------------
  // DELETE ACCOUNT
  // ---------------------------------------------------
  Future<void> deleteAccount() async {
    if (currentUser == null) {
      throw 'User not authenticated';
    }

    print('🗑️ Starting account deletion...');

    // Delete all trips belonging to user
    final trips = await _firestore
        .collection('trips')
        .where('firebaseUid', isEqualTo: currentUser!.uid)
        .get();

    for (var doc in trips.docs) {
      await doc.reference.delete();
    }
    print('✅ Deleted ${trips.docs.length} trips');

    // Delete customer profile
    final profileQuery = await _firestore
        .collection('customerProfile')
        .where('firebaseUid', isEqualTo: currentUser!.uid)
        .limit(1)
        .get();

    if (profileQuery.docs.isNotEmpty) {
      await profileQuery.docs.first.reference.delete();
      print('✅ Deleted customer profile');
    }

    // Delete user document
    final userQuery = await _firestore
        .collection('user')
        .where('firebaseUid', isEqualTo: currentUser!.uid)
        .limit(1)
        .get();

    if (userQuery.docs.isNotEmpty) {
      await userQuery.docs.first.reference.delete();
      print('✅ Deleted user document');
    }

    // Delete Firebase Auth user
    await currentUser!.delete();
    print('✅ Deleted Firebase Auth user');
  }
}