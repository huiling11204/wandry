import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Handles user authentication: login, register, profile management
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current logged in user
  User? get currentUser => _auth.currentUser;

  // Stream that notifies when auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==========================================
  // Generate User ID with Counter (C20251027XXXX)
  // ==========================================
  Future<String> _getNextUserId(String role) async {
    try {
      // C for Customer, A for Admin
      String prefix = role == 'Customer' ? 'C' : 'A';
      String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());

      print('🔧 Generating UserID: $prefix$dateStr');

      // Reference to counter document for today
      DocumentReference counterRef = _firestore
          .collection('counters')
          .doc('userCounter_$dateStr'); // One counter per day

      // Use transaction to safely increment counter
      return await _firestore.runTransaction<String>((transaction) async {
        DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

        // Get current count or start at 0
        int currentCount = 0;
        if (counterSnapshot.exists) {
          Map<String, dynamic>? data = counterSnapshot.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey(prefix)) {
            currentCount = data[prefix] as int;
          }
        }

        // Increment and format as 4-digit number
        int newCount = currentCount + 1;
        String sequenceStr = newCount.toString().padLeft(4, '0');
        String newID = '$prefix$dateStr$sequenceStr';

        print('📊 Counter: $prefix $currentCount → $newCount');
        print('✅ Generated UserID: $newID');

        // Update counter for this prefix
        transaction.set(counterRef, {
          prefix: newCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return newID;
      });

    } catch (e) {
      print('❌ CRITICAL ERROR generating UserID: $e');
      print('❌ Error details: ${e.toString()}');
      rethrow;
    }
  }

  // ==========================================
  // Generate Profile ID with Counter (CP20251027XXXX)
  // ==========================================
  Future<String> _getNextProfileId(String role) async {
    try {
      // CP for Customer Profile, AP for Admin Profile
      String prefix = role == 'Customer' ? 'CP' : 'AP';
      String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());

      print('🔧 Generating ProfileID: $prefix$dateStr');

      DocumentReference counterRef = _firestore
          .collection('counters')
          .doc('profileCounter_$dateStr'); // One counter per day

      // Use transaction to safely increment counter
      return await _firestore.runTransaction<String>((transaction) async {
        DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

        int currentCount = 0;
        if (counterSnapshot.exists) {
          Map<String, dynamic>? data = counterSnapshot.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey(prefix)) {
            currentCount = data[prefix] as int;
          }
        }

        int newCount = currentCount + 1;
        String sequenceStr = newCount.toString().padLeft(4, '0');
        String newID = '$prefix$dateStr$sequenceStr';

        print('📊 Profile Counter: $prefix $currentCount → $newCount');
        print('✅ Generated ProfileID: $newID');

        // Update counter for this prefix
        transaction.set(counterRef, {
          prefix: newCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return newID;
      });

    } catch (e) {
      print('❌ CRITICAL ERROR generating ProfileID: $e');
      print('❌ Error details: ${e.toString()}');
      rethrow; // Don't use fallback - let registration fail properly
    }
  }

  // ==========================================
  // Sign In (Works for both Customer and Admin)
  // ==========================================
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('🔐 Attempting sign in for: $email');

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('✅ Firebase Auth successful for UID: ${result.user?.uid}');

      if (result.user != null) {
        print('🔍 Looking for user profile with firebaseUid: ${result.user!.uid}');

        // Check if user has a profile in Firestore
        QuerySnapshot userQuery = await _firestore
            .collection('user')
            .where('firebaseUid', isEqualTo: result.user!.uid)
            .limit(1)
            .get();

        print('📊 Query returned ${userQuery.docs.length} documents');

        // No profile = invalid user
        if (userQuery.docs.isEmpty) {
          print('❌ No user profile found in Firestore');
          await _auth.signOut();
          throw 'User profile not found. Please register first.';
        }

        print('✅ User profile found: ${userQuery.docs.first.id}');

        // CRITICAL FIX: Check if email was verified and needs syncing
        await _syncEmailIfVerified(result.user!.uid);

        // Update last login timestamp
        await _firestore
            .collection('user')
            .doc(userQuery.docs.first.id)
            .update({'lastLoginDate': FieldValue.serverTimestamp()});

        print('✅ Updated last login date');
      }

      print('🎉 Sign in completed successfully');
      return result;

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Exception: ${e.code}');
      print('❌ Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Unexpected error during sign in: $e');

      if (e is String) rethrow;
      throw 'An unexpected error occurred. Please try again.';
    }
  }

// Add this helper method to your AuthService class:
  Future<void> _syncEmailIfVerified(String firebaseUid) async {
    try {
      // Reload user to get latest data
      await _auth.currentUser?.reload();
      User? refreshedUser = _auth.currentUser;

      if (refreshedUser == null || refreshedUser.email == null) return;

      String authEmail = refreshedUser.email!;
      print('📧 Auth email: $authEmail');

      // Get Firestore email
      QuerySnapshot userQuery = await _firestore
          .collection('user')
          .where('firebaseUid', isEqualTo: firebaseUid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return;

      Map<String, dynamic> userData = userQuery.docs.first.data() as Map<String, dynamic>;
      String firestoreEmail = userData['email'] ?? '';

      // If different, sync it
      if (firestoreEmail != authEmail && authEmail.isNotEmpty) {
        print('🔄 Syncing verified email to Firestore: $firestoreEmail → $authEmail');

        await userQuery.docs.first.reference.update({
          'email': authEmail,
        });

        print('✅ Email synced on login');
      }
    } catch (e) {
      print('⚠️ Error syncing email on login: $e');
      // Don't throw - email sync failure shouldn't block login
    }
  }

  // ==========================================
  // Register User (CUSTOMER ONLY!)
  // Admins must be created manually in Firebase Console
  // ==========================================
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String contact,
  }) async {
    UserCredential? result;
    String? userID;

    try {
      print('🚀 Starting CUSTOMER registration process...');
      print('📧 Email: $email');
      print('👤 Name: $name');
      print('📱 Contact: $contact');
      print('🎭 Role: Customer (FIXED)');

      // Step 1: Create Firebase Auth user
      print('🔐 Creating Firebase Auth user...');
      result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print('✅ Firebase Auth user created with UID: ${result.user?.uid}');

      if (result.user != null) {
        try {
          // Step 2: Generate custom userID (Customer only)
          print('🔢 Generating custom UserID...');
          userID = await _getNextUserId('Customer');
          print('✅ Generated custom UserID: $userID');

          // Step 3: Create user document (Customer role only)
          print('📝 Creating user document...');
          Map<String, dynamic> userData = {
            'userID': userID,
            'firebaseUid': result.user!.uid,
            'email': email.trim(),
            'role': 'Customer', // Only customers can register
            'registrationDate': FieldValue.serverTimestamp(),
            'lastLoginDate': FieldValue.serverTimestamp(),
          };

          await _firestore.collection('user').doc(userID).set(userData);
          print('✅ User document created at: user/$userID');

          // Step 4: Create customer profile
          await _createCustomerProfile(
            userID: userID,
            firebaseUid: result.user!.uid,
            name: name,
            contact: contact,
          );

          // Step 5: Set display name in Firebase Auth
          print('🏷️ Updating display name...');
          await result.user!.updateDisplayName(name);
          print('✅ Display name updated');

          print('🎉 Customer registration completed successfully!');
          print('📋 Summary:');
          print('   User ID: $userID');
          print('   Firebase UID: ${result.user!.uid}');
          print('   Email: $email');
          print('   Role: Customer');

          return result;

        } catch (firestoreError) {
          // If Firestore fails, delete the Firebase Auth user to keep data clean
          print('❌ Firestore error: $firestoreError');
          print('🧹 Cleaning up Firebase Auth user...');

          try {
            await result.user!.delete();
            print('✅ Firebase Auth user cleaned up');
          } catch (deleteError) {
            print('❌ Failed to clean up: $deleteError');
          }

          throw 'Failed to create user profile: $firestoreError';
        }
      }

      return result;

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Exception: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Unexpected error during registration: $e');

      if (e is String) {
        rethrow;
      }

      throw 'Registration failed: ${e.toString()}';
    }
  }

  // ==========================================
  // Create Customer Profile
  // ==========================================
  Future<void> _createCustomerProfile({
    required String userID,
    required String firebaseUid,
    required String name,
    required String contact,
  }) async {
    print('👤 Creating customer profile...');

    // Split full name into first and last name
    List<String> nameParts = name.trim().split(' ');
    String firstName = nameParts.first;
    String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    print('📝 First name: $firstName');
    print('📝 Last name: $lastName');

    // Generate profile ID
    String custProfileID = await _getNextProfileId('Customer');

    // Create profile data
    Map<String, dynamic> customerData = {
      'custProfileID': custProfileID,
      'userID': userID,
      'firebaseUid': firebaseUid,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': contact.trim(),
    };

    // Save to Firestore
    print('💾 Saving customer profile to customerProfile/$custProfileID');
    await _firestore.collection('customerProfile').doc(custProfileID).set(customerData);
    print('✅ Customer profile created with ID: $custProfileID');
  }

  /// Gets user profile data including role-specific profile
  Future<Map<String, dynamic>?> getUserProfile(String firebaseUid) async {
    try {
      print('🔍 Getting user profile for firebaseUid: $firebaseUid');

      // Find user document by Firebase UID
      QuerySnapshot userQuery = await _firestore
          .collection('user')
          .where('firebaseUid', isEqualTo: firebaseUid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('❌ No user document found');
        return null;
      }

      DocumentSnapshot userDoc = userQuery.docs.first;
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String role = userData['role'];

      print('✅ User document found. Role: $role');

      if (role == 'Customer') {
        QuerySnapshot profileQuery = await _firestore
            .collection('customerProfile')
            .where('firebaseUid', isEqualTo: firebaseUid)
            .limit(1)
            .get();

        if (profileQuery.docs.isNotEmpty) {
          Map<String, dynamic> profileData = profileQuery.docs.first.data() as Map<String, dynamic>;
          print('✅ Customer profile found');
          return {
            ...userData,
            'profile': profileData,
          };
        }
      } else if (role == 'Admin') {
        QuerySnapshot profileQuery = await _firestore
            .collection('adminProfile')
            .where('firebaseUid', isEqualTo: firebaseUid)
            .limit(1)
            .get();

        if (profileQuery.docs.isNotEmpty) {
          Map<String, dynamic> profileData = profileQuery.docs.first.data() as Map<String, dynamic>;
          print('✅ Admin profile found');
          return {
            ...userData,
            'profile': profileData,
          };
        }
      }

      return userData;
    } catch (e) {
      print('❌ Error loading user profile: $e');
      throw 'Failed to load user profile: ${e.toString()}';
    }
  }

  // ==========================================
  // Get User Profile by UserID
  // ==========================================
  Future<Map<String, dynamic>?> getUserProfileByUserId(String userID) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('user').doc(userID).get();

      if (!userDoc.exists) return null;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String role = userData['role'];

      // Get role-specific profile
      if (role == 'Customer') {
        QuerySnapshot profileQuery = await _firestore
            .collection('customerProfile')
            .where('userID', isEqualTo: userID)
            .limit(1)
            .get();

        if (profileQuery.docs.isNotEmpty) {
          return {
            ...userData,
            'profile': profileQuery.docs.first.data(),
          };
        }
      } else if (role == 'Admin') {
        QuerySnapshot profileQuery = await _firestore
            .collection('adminProfile')
            .where('userID', isEqualTo: userID)
            .limit(1)
            .get();

        if (profileQuery.docs.isNotEmpty) {
          return {
            ...userData,
            'profile': profileQuery.docs.first.data(),
          };
        }
      }

      return userData;
    } catch (e) {
      throw 'Failed to load user profile.';
    }
  }

  // ==========================================
  // Update Customer Profile
  // ==========================================
  Future<void> updateCustomerProfile({
    required String firebaseUid,
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    try {
      QuerySnapshot profileQuery = await _firestore
          .collection('customerProfile')
          .where('firebaseUid', isEqualTo: firebaseUid)
          .limit(1)
          .get();

      if (profileQuery.docs.isEmpty) {
        throw 'Customer profile not found.';
      }

      // Build update data with only non-null fields
      Map<String, dynamic> updateData = {};
      if (firstName != null) updateData['firstName'] = firstName.trim();
      if (lastName != null) updateData['lastName'] = lastName.trim();
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber.trim();

      // Update Firestore
      await profileQuery.docs.first.reference.update(updateData);

      // Update Firebase Auth display name
      if (firstName != null && currentUser != null) {
        String fullName = lastName != null ? '$firstName $lastName' : firstName;
        await currentUser!.updateDisplayName(fullName);
      }
    } catch (e) {
      throw 'Failed to update customer profile.';
    }
  }

  // ==========================================
  // Update Admin Profile
  // ==========================================
  Future<void> updateAdminProfile({
    required String firebaseUid,
    String? adminName,
  }) async {
    try {
      QuerySnapshot profileQuery = await _firestore
          .collection('adminProfile')
          .where('firebaseUid', isEqualTo: firebaseUid)
          .limit(1)
          .get();

      if (profileQuery.docs.isEmpty) {
        throw 'Admin profile not found.';
      }

      Map<String, dynamic> updateData = {};
      if (adminName != null) updateData['adminName'] = adminName.trim();

      await profileQuery.docs.first.reference.update(updateData);

      if (adminName != null && currentUser != null) {
        await currentUser!.updateDisplayName(adminName);
      }
    } catch (e) {
      throw 'Failed to update admin profile.';
    }
  }

  // ==========================================
  // Sign Out
  // ==========================================
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Error signing out. Please try again.';
    }
  }

  // ==========================================
  // /// Sends password reset email
  // ==========================================
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // ==========================================
  // Delete current user account and all related data
  // ==========================================
  Future<void> deleteAccount() async {
    try {
      if (currentUser != null) {
        String firebaseUid = currentUser!.uid;

        // Find user document
        QuerySnapshot userQuery = await _firestore
            .collection('user')
            .where('firebaseUid', isEqualTo: firebaseUid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          DocumentSnapshot userDoc = userQuery.docs.first;
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          String role = userData['role'];

          // Delete role-specific profile
          if (role == 'Customer') {
            QuerySnapshot profileQuery = await _firestore
                .collection('customerProfile')
                .where('firebaseUid', isEqualTo: firebaseUid)
                .limit(1)
                .get();

            if (profileQuery.docs.isNotEmpty) {
              await profileQuery.docs.first.reference.delete();
            }
          } else if (role == 'Admin') {
            QuerySnapshot profileQuery = await _firestore
                .collection('adminProfile')
                .where('firebaseUid', isEqualTo: firebaseUid)
                .limit(1)
                .get();

            if (profileQuery.docs.isNotEmpty) {
              await profileQuery.docs.first.reference.delete();
            }
          }
          // Delete user document
          await userDoc.reference.delete();
        }
        // Delete Firebase Auth account
        await currentUser!.delete();
      }
    } catch (e) {
      throw 'Failed to delete account. Please try again.';
    }
  }

  // ==========================================
  // Handle Auth Exceptions
  // ==========================================
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Registration is currently disabled. Please try again later.';
      case 'email-already-in-use':
        return 'Email already registered. Please use a different email.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }
}