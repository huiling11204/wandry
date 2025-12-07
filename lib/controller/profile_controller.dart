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
    try {
      // Force reload to get latest data from Firebase Auth
      await _auth.currentUser?.reload();
      User? refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        print('❌ No authenticated user found');
        throw 'User not authenticated';
      }

      print('🔍 Loading profile for UID: ${refreshedUser.uid}');

      // Step 1: Get user document to find email
      QuerySnapshot userQuery = await _firestore
          .collection('user')
          .where('firebaseUid', isEqualTo: refreshedUser.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('❌ No user document found');
        throw 'User profile not found';
      }

      Map<String, dynamic> userData = userQuery.docs.first.data() as Map<String, dynamic>;

      // Use Firebase Auth email as source of truth (in case it was updated)
      String authEmail = refreshedUser.email ?? '';
      String firestoreEmail = userData['email'] ?? '';

      // Sync if different (email was verified but Firestore not updated)
      if (authEmail.isNotEmpty && authEmail != firestoreEmail) {
        print('🔄 Syncing email: Firestore ($firestoreEmail) → Auth ($authEmail)');
        try {
          await userQuery.docs.first.reference.update({'email': authEmail});
          userData['email'] = authEmail; // Update local data
          print('✅ Email synced successfully');
        } catch (syncError) {
          print('⚠️ Email sync failed (non-critical): $syncError');
          // Continue even if sync fails
        }
      }

      String email = authEmail.isNotEmpty ? authEmail : firestoreEmail;
      String role = userData['role'] ?? 'Customer';

      print('✅ User found - Role: $role, Email: $email');

      // Step 2: Get customer profile using firebaseUid
      QuerySnapshot profileQuery = await _firestore
          .collection('customerProfile')
          .where('firebaseUid', isEqualTo: refreshedUser.uid)
          .limit(1)
          .get();

      if (profileQuery.docs.isEmpty) {
        print('❌ No customer profile found');
        return {
          'firstName': refreshedUser.displayName ?? 'User',
          'lastName': '',
          'email': email,
          'phoneNumber': 'Not set',
        };
      }

      Map<String, dynamic> customerData = profileQuery.docs.first.data() as Map<String, dynamic>;

      print('✅ Customer profile found');
      print('📋 Data: $customerData');

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
    } catch (e) {
      print('❌ Error in loadProfile: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------
  // CHECK IF EMAIL IS VERIFIED AND SYNC TO FIRESTORE
  // Returns: true if email was synced, false otherwise
  // ---------------------------------------------------
  Future<bool> checkAndSyncEmailVerification() async {
    try {
      // Reload to get latest email from Firebase Auth
      await _auth.currentUser?.reload();
      User? refreshedUser = _auth.currentUser;

      if (refreshedUser == null || refreshedUser.email == null) {
        print('⚠️ No user or email found');
        return false;
      }

      String authEmail = refreshedUser.email!;
      print('📧 Checking email sync - Auth email: $authEmail');

      // Get current Firestore email
      QuerySnapshot userQuery = await _firestore
          .collection('user')
          .where('firebaseUid', isEqualTo: refreshedUser.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('⚠️ No user document found for sync');
        return false;
      }

      Map<String, dynamic> userData = userQuery.docs.first.data() as Map<String, dynamic>;
      String firestoreEmail = userData['email'] ?? '';

      // If emails are different, auth email was verified - sync it!
      if (firestoreEmail != authEmail) {
        print('✅ Email verified! Syncing to Firestore: $firestoreEmail → $authEmail');

        await userQuery.docs.first.reference.update({
          'email': authEmail,
        });

        print('✅ Firestore email synced successfully');
        return true; // Email was updated
      }

      print('ℹ️ Email already in sync');
      return false;
    } catch (e) {
      print('⚠️ Error checking email sync: $e');
      return false;
    }
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

    // Step 1: Update customerProfile collection (name and phone only)
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

    // Step 2: Update Firebase Auth display name
    String fullName = '$firstName $lastName'.trim();
    await currentUser!.updateDisplayName(fullName);
    print('✅ Display name updated to: $fullName');

    String emailMessage = '';

    // Step 3: Handle email update if changed
    if (email != originalEmail && email.isNotEmpty) {
      print('📧 Email change requested: $originalEmail → $email');

      try {
        // CRITICAL: Check if email already exists first
        print('🔍 Checking if email already exists...');

        QuerySnapshot existingEmailCheck = await _firestore
            .collection('user')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();

        if (existingEmailCheck.docs.isNotEmpty) {
          // Check if it's not the current user's document
          Map<String, dynamic> existingUserData =
          existingEmailCheck.docs.first.data() as Map<String, dynamic>;

          if (existingUserData['firebaseUid'] != currentUser!.uid) {
            print('❌ Email already in use by another account');
            emailMessage = 'email_in_use';

            return {
              'status': 'success',
              'emailMessage': emailMessage,
              'newEmail': email,
            };
          }
        }

        // Email is available, proceed with verification
        print('✅ Email available, sending verification...');
        await currentUser!.verifyBeforeUpdateEmail(email);
        print('✅ Verification email sent to: $email');

        // IMPORTANT: Email will be updated AFTER user verifies
        // User MUST log in again after verification

        emailMessage = 'verification_sent';

        print('⏳ Email update pending verification');
        print('📧 User must click verification link in email sent to: $email');
        print('🔑 User must LOG IN AGAIN after verification');

      } on FirebaseAuthException catch (e) {
        print('⚠️ Firebase Auth error during email update: ${e.code}');

        if (e.code == 'requires-recent-login') {
          emailMessage = 'requires_reauth';
          print('🔐 User needs to re-authenticate before changing email');
        } else if (e.code == 'email-already-in-use') {
          emailMessage = 'email_in_use';
          print('❌ Email already in use by another account');
        } else if (e.code == 'invalid-email') {
          emailMessage = 'invalid_email';
          print('❌ Invalid email format');
        } else {
          emailMessage = 'error';
          print('❌ Unknown error: ${e.message}');
          throw 'Failed to send verification email: ${e.message}';
        }
      } catch (e) {
        print('❌ Unexpected error during email update: $e');
        emailMessage = 'error';
        throw 'Failed to update email: $e';
      }
    }

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

    try {
      // Delete trips
      final trips = await _firestore
          .collection('trip')
          .where('firebaseUid', isEqualTo: currentUser!.uid)
          .get();

      for (var doc in trips.docs) {
        await doc.reference.delete();
      }
      print('✅ Deleted ${trips.docs.length} trips');
    } catch (e) {
      print('⚠️ Could not delete trips: $e');
    }

    try {
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
    } catch (e) {
      print('⚠️ Could not delete customer profile: $e');
    }

    try {
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
    } catch (e) {
      print('⚠️ Could not delete user document: $e');
    }

    // Delete Firebase Auth user (this is the final step)
    try {
      await currentUser!.delete();
      print('✅ Deleted Firebase Auth user');
    } catch (e) {
      print('❌ Failed to delete Firebase Auth user: $e');
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw 'Please log in again before deleting your account';
      }
      throw 'Failed to delete account: $e';
    }
  }
}