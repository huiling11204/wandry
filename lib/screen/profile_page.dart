// ============================================
// VIEW PROFILE PAGE (FIXED - Properly reads from Firebase)
// ============================================
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';

class ViewProfilePage extends StatefulWidget {
  @override
  _ViewProfilePageState createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? currentUser;
  Map<String, dynamic>? profileData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    _loadProfile();
  }

  // ---------------------------------------------------
  // LOAD PROFILE FROM FIREBASE (FIXED)
  // ---------------------------------------------------
  Future<void> _loadProfile() async {
    if (currentUser == null) return;

    setState(() => isLoading = true);

    try {
      print('🔍 Loading profile for UID: ${currentUser!.uid}');

      // Step 1: Get user document to find userID and email
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
        profileData = {
          'firstName': currentUser!.displayName ?? 'User',
          'lastName': '',
          'email': email,
          'phoneNumber': 'Not set',
        };
      } else {
        Map<String, dynamic> customerData = profileQuery.docs.first.data() as Map<String, dynamic>;

        print('✅ Customer profile found');
        print('📋 Data: $customerData');

        // Combine firstName and lastName for display
        String firstName = customerData['firstName'] ?? '';
        String lastName = customerData['lastName'] ?? '';
        String fullName = '$firstName $lastName'.trim();
        if (fullName.isEmpty) fullName = 'User';

        profileData = {
          'fullName': fullName,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phoneNumber': customerData['phoneNumber'] ?? 'Not set',
          'custProfileID': customerData['custProfileID'],
          'userID': customerData['userID'],
        };

        print('✅ Profile data loaded: $profileData');
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );

      // Set fallback data
      profileData = {
        'fullName': currentUser?.displayName ?? 'User',
        'firstName': currentUser?.displayName ?? 'User',
        'lastName': '',
        'email': currentUser?.email ?? 'Not set',
        'phoneNumber': 'Not set',
      };
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ---------------------------------------------------
  // DELETE ACCOUNT (Fixed to use correct collections)
  // ---------------------------------------------------
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete your account? '
              'This action cannot be undone and all your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      print('🗑️ Starting account deletion...');

      // Delete all trips belonging to user
      final trips = await _firestore
          .collection('trips')
          .where('firebaseUid', isEqualTo: currentUser?.uid)
          .get();

      for (var doc in trips.docs) {
        await doc.reference.delete();
      }
      print('✅ Deleted ${trips.docs.length} trips');

      // Delete customer profile
      final profileQuery = await _firestore
          .collection('customerProfile')
          .where('firebaseUid', isEqualTo: currentUser?.uid)
          .limit(1)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        await profileQuery.docs.first.reference.delete();
        print('✅ Deleted customer profile');
      }

      // Delete user document
      final userQuery = await _firestore
          .collection('user')
          .where('firebaseUid', isEqualTo: currentUser?.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        await userQuery.docs.first.reference.delete();
        print('✅ Deleted user document');
      }

      // Delete Firebase Auth user
      await currentUser!.delete();
      print('✅ Deleted Firebase Auth user');

      // Navigate to login
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deleted successfully')),
        );
      }
    } catch (e) {
      print('❌ Error deleting account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: $e')),
      );
    }
  }

  // ---------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              ProfileField(
                label: 'Name',
                value: profileData?['fullName'] ?? 'Not set',
              ),
              SizedBox(height: 16),
              ProfileField(
                label: 'Email Address',
                value: profileData?['email'] ?? 'Not set',
              ),
              SizedBox(height: 16),
              ProfileField(
                label: 'Contact Number',
                value: profileData?['phoneNumber'] ?? 'Not set',
              ),
              SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(
                              profileData: profileData ?? {},
                            ),
                          ),
                        );

                        if (result == true) {
                          _loadProfile();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Edit', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _deleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Delete Account',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------
// REUSABLE PROFILE FIELD WIDGET
// ---------------------------------------------------
class ProfileField extends StatelessWidget {
  final String label;
  final String value;

  const ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}