// ============================================
// VIEW PROFILE PAGE (Firebase Connected Properly)
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
  // LOAD PROFILE FROM "customer" COLLECTION (Fixed)
  // ---------------------------------------------------
  Future<void> _loadProfile() async {
    if (currentUser == null) return;

    setState(() => isLoading = true);

    try {
      final doc = await _firestore
          .collection('customer') // ✅ corrected collection name
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        profileData = doc.data();
      } else {
        // fallback: if doc not found, use currentUser info
        profileData = {
          'custName': currentUser!.displayName ?? 'Traveler',
          'custEmail': currentUser!.email ?? 'Not set',
          'custContact': 'Not set',
        };
      }
    } catch (e) {
      print('Error loading profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile data.')),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ---------------------------------------------------
  // DELETE ACCOUNT (with trips + Auth + Firestore)
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
      // Delete all trips belonging to user
      final trips = await _firestore
          .collection('trips')
          .where('custProfileID', isEqualTo: currentUser?.uid)
          .get();

      for (var doc in trips.docs) {
        await doc.reference.delete();
      }

      // Delete profile document
      await _firestore.collection('customer').doc(currentUser!.uid).delete();

      // Delete Firebase Auth user
      await currentUser!.delete();

      // Navigate to login
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting account: $e');
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
                value: profileData?['custName'] ?? 'Not set',
              ),
              SizedBox(height: 16),
              ProfileField(
                label: 'Email Address',
                value: profileData?['custEmail'] ??
                    currentUser?.email ??
                    'Not set',
              ),
              SizedBox(height: 16),
              ProfileField(
                label: 'Contact Number',
                value: profileData?['custContact'] ?? 'Not set',
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
