// ============================================
// VIEW PROFILE PAGE (REFACTORED - UI Only)
// Location: lib/screen/view_profile_page.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:wandry/controller/profile_controller.dart';
import 'package:wandry/widget/profile_field_widget.dart';
import 'package:wandry/widget/sweet_alert_dialog.dart';
import 'edit_profile_page.dart';

class ViewProfilePage extends StatefulWidget {
  const ViewProfilePage({super.key});

  @override
  _ViewProfilePageState createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final ProfileController _profileController = ProfileController();

  Map<String, dynamic>? profileData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ---------------------------------------------------
  // LOAD PROFILE (Calls Controller)
  // ---------------------------------------------------
  Future<void> _loadProfile() async {
    setState(() => isLoading = true);

    try {
      final data = await _profileController.loadProfile();
      setState(() {
        profileData = data;
      });
    } catch (e) {
      print('❌ Error loading profile: $e');
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Load Failed',
          subtitle: 'Error loading profile: $e',
        );
      }

      // Set fallback data
      setState(() {
        profileData = {
          'fullName': _profileController.currentUser?.displayName ?? 'User',
          'firstName': _profileController.currentUser?.displayName ?? 'User',
          'lastName': '',
          'email': _profileController.currentUser?.email ?? 'Not set',
          'phoneNumber': 'Not set',
        };
      });
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ---------------------------------------------------
  // DELETE ACCOUNT (Calls Controller)
  // ---------------------------------------------------
  Future<void> _deleteAccount() async {
    final confirm = await SweetAlertDialog.show(
      context: context,
      type: SweetAlertType.warning,
      title: 'Delete Account',
      subtitle: 'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      showCancelButton: true,
    );

    if (confirm != true) return;

    try {
      await _profileController.deleteAccount();

      // Show success message
      if (mounted) {
        await SweetAlertDialog.success(
          context: context,
          title: 'Account Deleted',
          subtitle: 'Your account has been deleted successfully.',
        );

        // Navigate to login
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      print('❌ Error deleting account: $e');
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Delete Failed',
          subtitle: 'Error deleting account: $e',
        );
      }
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