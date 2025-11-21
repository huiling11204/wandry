// ============================================
// EDIT PROFILE PAGE (REFACTORED - UI Only)
// Location: lib/screen/edit_profile_page.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:wandry/controller/profile_controller.dart';
import 'package:wandry/utilities/validators.dart';
import 'package:wandry/widget/profile_field_widget.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfilePage({super.key, required this.profileData});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ProfileController _profileController = ProfileController();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data
    _firstNameController = TextEditingController(
      text: widget.profileData['firstName'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.profileData['lastName'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.profileData['email'] ?? _profileController.currentUser?.email ?? '',
    );
    _contactController = TextEditingController(
      text: widget.profileData['phoneNumber'] ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------
  // SAVE CHANGES (Calls Controller)
  // ---------------------------------------------------
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileController.currentUser == null) return;

    setState(() => isSaving = true);

    try {
      final result = await _profileController.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _contactController.text.trim(),
        originalEmail: widget.profileData['email'],
      );

      if (mounted) {
        // Show appropriate message based on email update status
        if (result['emailMessage'] == 'verification_sent') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verification email sent to ${result['newEmail']}. Please verify to complete the change.',
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (result['emailMessage'] == 'requires_reauth') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Email change requires re-login. Profile updated, but please sign in again to change email.',
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => isSaving = false);
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
        title: Text('Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // First Name Field
              EditProfileField(
                label: 'First Name',
                controller: _firstNameController,
                validator: Validators.validateFirstName,
              ),
              SizedBox(height: 16),

              // Last Name Field
              EditProfileField(
                label: 'Last Name',
                controller: _lastNameController,
                validator: Validators.validateLastName,
              ),
              SizedBox(height: 16),

              // Email Field
              EditProfileField(
                label: 'Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.validateEmailRequired,
              ),
              SizedBox(height: 16),

              // Contact Number Field
              EditProfileField(
                label: 'Contact Number',
                controller: _contactController,
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhoneNumber,
              ),
              SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text('Save Changes', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}