import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream to listen to auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==========================================
  // FIXED: Generate User ID with Counter (More Reliable)
  // ==========================================
  Future<String> _getNextUserId(String role) async {
    try {
      String prefix = role == 'Customer' ? 'C' : 'A';
      String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());

      print('🔧 Generating UserID with prefix: $prefix, date: $dateStr');

      // Use Firestore transaction for atomic counter increment
      DocumentReference counterRef = _firestore
          .collection('counters')
          .doc('${prefix.toLowerCase()}UserCounter');

      return await _firestore.runTransaction<String>((transaction) async {
        DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

        int currentCount = 0;
        if (counterSnapshot.exists) {
          Map<String, dynamic>? data = counterSnapshot.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey(dateStr)) {
            currentCount = data[dateStr] as int;
          }
        }

        int newCount = currentCount + 1;
        print('📊 Counter: $currentCount → $newCount');

        // Update counter
        transaction.set(counterRef, {
          dateStr: newCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Generate ID: PREFIX + YYYYMMDD + 0001
        String sequenceStr = newCount.toString().padLeft(4, '0');
        String newID = '$prefix$dateStr$sequenceStr';

        print('✅ Generated UserID: $newID');
        return newID;
      });

    } catch (e) {
      print('❌ Error generating UserID: $e');
      print('❌ Error type: ${e.runtimeType}');

      // Better fallback - still uses date format
      String prefix = role == 'Customer' ? 'C' : 'A';
      String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      String randomNum = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
      String fallbackId = '$prefix$dateStr$randomNum';

      print('⚠️ Using fallback UserID: $fallbackId');
      return fallbackId;
    }
  }

  // ==========================================
  // FIXED: Generate Profile ID with Counter (More Reliable)
  // ==========================================
  Future<String> _getNextProfileId(String role) async {
    try {
      String prefix = role == 'Customer' ? 'CP' : 'AP';
      String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());

      print('🔧 Generating ProfileID with prefix: $prefix, date: $dateStr');

      // Use Firestore transaction for atomic counter increment
      DocumentReference counterRef = _firestore
          .collection('counters')
          .doc('${prefix.toLowerCase()}Counter');

      return await _firestore.runTransaction<String>((transaction) async {
        DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

        int currentCount = 0;
        if (counterSnapshot.exists) {
          Map<String, dynamic>? data = counterSnapshot.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey(dateStr)) {
            currentCount = data[dateStr] as int;
          }
        }

        int newCount = currentCount + 1;
        print('📊 Profile Counter: $currentCount → $newCount');

        // Update counter
        transaction.set(counterRef, {
          dateStr: newCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Generate ID: PREFIX + YYYYMMDD + 0001
        String sequenceStr = newCount.toString().padLeft(4, '0');
        String newID = '$prefix$dateStr$sequenceStr';

        print('✅ Generated ProfileID: $newID');
        return newID;
      });

    } catch (e) {
      print('❌ Error generating ProfileID: $e');
      print('❌ Error type: ${e.runtimeType}');

      // Better fallback - still uses date format
      String prefix = role == 'Customer' ? 'CP' : 'AP';
      String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      String randomNum = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
      String fallbackId = '$prefix$dateStr$randomNum';

      print('⚠️ Using fallback ProfileID: $fallbackId');
      return fallbackId;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('🔐 Attempting sign in for: $email');

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('✅ Firebase Auth successful for UID: ${result.user?.uid}');

      // Check if user profile exists in new structure
      if (result.user != null) {
        print('🔍 Looking for user profile with firebaseUid: ${result.user!.uid}');

        QuerySnapshot userQuery = await _firestore
            .collection('user')
            .where('firebaseUid', isEqualTo: result.user!.uid)
            .limit(1)
            .get();

        print('📊 Query returned ${userQuery.docs.length} documents');

        if (userQuery.docs.isEmpty) {
          print('❌ No user profile found in Firestore');
          await _auth.signOut();
          throw 'User profile not found. Please register first.';
        }

        print('✅ User profile found: ${userQuery.docs.first.id}');

        // Update last login date
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
      print('❌ Error type: ${e.runtimeType}');

      if (e is String) rethrow;
      throw 'An unexpected error occurred. Please try again. Error: ${e.toString()}';
    }
  }

  // Register with email and password - creates user and profile based on role
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String contact,
    String role = 'Customer', // Default role is Customer
  }) async {
    UserCredential? result;
    String? userID;

    try {
      print('🚀 Starting registration process...');
      print('📧 Email: $email');
      print('👤 Name: $name');
      print('📱 Contact: $contact');
      print('🎭 Role: $role');

      // Step 1: Create user in Firebase Auth
      print('🔐 Creating Firebase Auth user...');
      result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print('✅ Firebase Auth user created with UID: ${result.user?.uid}');

      if (result.user != null) {
        try {
          // Step 2: Generate custom userID with role prefix and date
          print('🔢 Generating custom UserID...');
          userID = await _getNextUserId(role);
          print('✅ Generated custom UserID: $userID');

          // Step 3: Create user document in 'user' collection
          print('📝 Creating user document...');
          Map<String, dynamic> userData = {
            'userID': userID,
            'firebaseUid': result.user!.uid,
            'email': email.trim(),
            'role': role,
            'registrationDate': FieldValue.serverTimestamp(),
            'lastLoginDate': FieldValue.serverTimestamp(),
          };

          await _firestore.collection('user').doc(userID).set(userData);
          print('✅ User document created successfully at: user/$userID');

          // Step 4: Create role-specific profile
          if (role == 'Customer') {
            await _createCustomerProfile(
              userID: userID,
              firebaseUid: result.user!.uid,
              name: name,
              contact: contact,
            );
          } else if (role == 'Admin') {
            await _createAdminProfile(
              userID: userID,
              firebaseUid: result.user!.uid,
              name: name,
            );
          }

          // Step 5: Update display name
          print('🏷️ Updating display name...');
          await result.user!.updateDisplayName(name);
          print('✅ Display name updated');

          print('🎉 Registration completed successfully!');
          print('📋 Summary:');
          print('   User ID: $userID');
          print('   Firebase UID: ${result.user!.uid}');
          print('   Email: $email');
          print('   Role: $role');

          return result;

        } catch (firestoreError) {
          print('❌ Firestore error: $firestoreError');
          print('❌ Error type: ${firestoreError.runtimeType}');
          print('🧹 Cleaning up Firebase Auth user...');

          try {
            await result.user!.delete();
            print('✅ Firebase Auth user cleaned up');
          } catch (deleteError) {
            print('❌ Failed to clean up Firebase Auth user: $deleteError');
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
      print('❌ Error type: ${e.runtimeType}');

      if (e is String) {
        throw e;
      }

      throw 'Registration failed: ${e.toString()}';
    }
  }

  // Create customer profile
  Future<void> _createCustomerProfile({
    required String userID,
    required String firebaseUid,
    required String name,
    required String contact,
  }) async {
    print('👤 Creating customer profile...');

    // Split name into first and last name
    List<String> nameParts = name.trim().split(' ');
    String firstName = nameParts.first;
    String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    print('📝 First name: $firstName');
    print('📝 Last name: $lastName');

    // Generate profile ID with CP prefix and date
    String custProfileID = await _getNextProfileId('Customer');

    Map<String, dynamic> customerData = {
      'custProfileID': custProfileID,
      'userID': userID,
      'firebaseUid': firebaseUid,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': contact.trim(),
    };

    print('💾 Saving customer profile to customerProfile/$custProfileID');
    await _firestore.collection('customerProfile').doc(custProfileID).set(customerData);
    print('✅ Customer profile created with ID: $custProfileID');
  }

  // Create admin profile
  Future<void> _createAdminProfile({
    required String userID,
    required String firebaseUid,
    required String name,
  }) async {
    print('👨‍💼 Creating admin profile...');

    // Generate profile ID with AP prefix and date
    String adminProfileID = await _getNextProfileId('Admin');

    Map<String, dynamic> adminData = {
      'adminProfileID': adminProfileID,
      'userID': userID,
      'firebaseUid': firebaseUid,
      'adminName': name.trim(),
    };

    print('💾 Saving admin profile to adminProfile/$adminProfileID');
    await _firestore.collection('adminProfile').doc(adminProfileID).set(adminData);
    print('✅ Admin profile created with ID: $adminProfileID');
  }

  // Get user profile from Firestore by Firebase UID
  Future<Map<String, dynamic>?> getUserProfile(String firebaseUid) async {
    try {
      print('🔍 Getting user profile for firebaseUid: $firebaseUid');

      // Get user document
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

      // Get role-specific profile
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
      print('❌ Error type: ${e.runtimeType}');
      throw 'Failed to load user profile: ${e.toString()}';
    }
  }

  // Get user profile by userID
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

  // Update customer profile
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

      Map<String, dynamic> updateData = {};
      if (firstName != null) updateData['firstName'] = firstName.trim();
      if (lastName != null) updateData['lastName'] = lastName.trim();
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber.trim();

      await profileQuery.docs.first.reference.update(updateData);

      // Update display name if name changed
      if (firstName != null && currentUser != null) {
        String fullName = lastName != null ? '$firstName $lastName' : firstName;
        await currentUser!.updateDisplayName(fullName);
      }
    } catch (e) {
      throw 'Failed to update customer profile.';
    }
  }

  // Update admin profile
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

      // Update display name
      if (adminName != null && currentUser != null) {
        await currentUser!.updateDisplayName(adminName);
      }
    } catch (e) {
      throw 'Failed to update admin profile.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Error signing out. Please try again.';
    }
  }

  // Reset password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Delete user account and all associated profiles
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

        // Delete Firebase Auth user
        await currentUser!.delete();
      }
    } catch (e) {
      throw 'Failed to delete account. Please try again.';
    }
  }

  // Handle Firebase Auth exceptions
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