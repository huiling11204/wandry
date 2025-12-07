import 'package:flutter/material.dart';
import 'package:wandry/controller/profile_controller.dart';
import 'package:wandry/controller/userAuth.dart'; // ADD THIS IMPORT
import 'package:wandry/utilities/validators.dart';
import 'package:wandry/widget/profile_field_widget.dart';
import 'package:wandry/widget/sweet_alert_dialog.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfilePage({super.key, required this.profileData});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ProfileController _profileController = ProfileController();
  final AuthService _authService = AuthService(); // ADD THIS

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
  // SAVE CHANGES (With Auto-Logout After Email Change)
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
        originalEmail: widget.profileData['email'] ?? '',
      );

      if (!mounted) return;

      // Handle different email update scenarios
      String emailMessage = result['emailMessage'] ?? '';

      if (emailMessage == 'verification_sent') {
        // Email verification sent - FORCE LOGOUT
        await SweetAlertDialog.show(
          context: context,
          type: SweetAlertType.success,
          title: 'Verification Email Sent!',
          subtitle: '✅ A verification link has been sent to:\n${result['newEmail']}\n\n'
              '📧 Please check your email and click the verification link.\n\n'
              '🔑 After verification, log in again with your NEW email address to complete the process.\n\n'
              'You will now be logged out.',
          confirmText: 'OK, Log Me Out',
        );

        // Force logout and redirect to login page
        await _authService.signOut(); // FIXED: Use _authService instead

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
                (route) => false,
            arguments: {
              'message': 'Email verification sent. Please verify your email and log in again.',
              'newEmail': result['newEmail'],
            },
          );
        }

      } else if (emailMessage == 'email_in_use') {
        // Email already in use by another account
        await SweetAlertDialog.error(
          context: context,
          title: 'Email Already in Use',
          subtitle: 'This email address is already registered to another account. Please use a different email.',
        );

      } else if (emailMessage == 'requires_reauth') {
        // Requires re-authentication for security
        final shouldLogout = await SweetAlertDialog.show(
          context: context,
          type: SweetAlertType.warning,
          title: 'Re-authentication Required',
          subtitle: 'For security reasons, please log out and log in again to change your email.\n\nYour other profile changes have been saved.',
          confirmText: 'Log Out Now',
          cancelText: 'Later',
          showCancelButton: true,
        );

        if (shouldLogout == true) {
          await _authService.signOut(); // FIXED: Use _authService instead
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          }
        } else {
          Navigator.pop(context, true);
        }

      } else if (emailMessage == 'invalid_email') {
        // Invalid email format
        await SweetAlertDialog.error(
          context: context,
          title: 'Invalid Email',
          subtitle: 'The email address format is not valid. Please check and try again.',
        );

      } else if (emailMessage == 'error') {
        // General error
        await SweetAlertDialog.error(
          context: context,
          title: 'Update Failed',
          subtitle: 'Failed to update email. Please try again later.',
        );

      } else {
        // Success - no email change or profile updated without email change
        await SweetAlertDialog.success(
          context: context,
          title: 'Success!',
          subtitle: 'Profile updated successfully.',
        );

        Navigator.pop(context, true);
      }

    } catch (e) {
      print('❌ Error updating profile: $e');
      if (mounted) {
        await SweetAlertDialog.error(
          context: context,
          title: 'Update Failed',
          subtitle: 'Error updating profile: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
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
              // Important notice banner
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Important: If you change your email, you will be logged out automatically. '
                            'After verifying your new email, log in again using the NEW email address.',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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