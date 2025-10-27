// ============================================
// EDIT PROFILE PAGE (FIXED - Matches Firebase Structure)
// ============================================
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfilePage({required this.profileData});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;

    // Initialize controllers with existing data
    _firstNameController = TextEditingController(
      text: widget.profileData['firstName'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.profileData['lastName'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.profileData['email'] ?? currentUser?.email ?? '',
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
  // SAVE CHANGES (Fixed to update correct collections)
  // ---------------------------------------------------
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (currentUser == null) return;

    setState(() => isSaving = true);

    try {
      print('💾 Starting profile update...');

      String firstName = _firstNameController.text.trim();
      String lastName = _lastNameController.text.trim();
      String email = _emailController.text.trim();
      String phoneNumber = _contactController.text.trim();

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

      // Step 2: Update email in user collection if changed
      if (email != widget.profileData['email']) {
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

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification email sent to $email. Please verify to complete the change.'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          print('⚠️ Email update requires re-authentication: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Email change requires re-login. Profile updated, but please sign in again to change email.'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // Step 3: Update Firebase Auth display name
      String fullName = '$firstName $lastName'.trim();
      await currentUser!.updateDisplayName(fullName);
      print('✅ Display name updated to: $fullName');

      print('🎉 Profile update complete!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your first name';
                  }
                  if (value.trim().length < 2) {
                    return 'First name must be at least 2 characters';
                  }
                  if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                    return 'First name can only contain letters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Last Name Field
              EditProfileField(
                label: 'Last Name',
                controller: _lastNameController,
                validator: (value) {
                  // Last name is optional, but if provided, validate it
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.trim().length < 2) {
                      return 'Last name must be at least 2 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                      return 'Last name can only contain letters';
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Email Field
              EditProfileField(
                label: 'Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  // Email validation regex
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Contact Number Field
              EditProfileField(
                label: 'Contact Number',
                controller: _contactController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your contact number';
                  }
                  // Remove spaces and dashes for validation
                  String cleanNumber = value.trim().replaceAll(RegExp(r'[\s-]'), '');

                  // Check if it contains only digits (and optional + at start)
                  if (!RegExp(r'^\+?\d+$').hasMatch(cleanNumber)) {
                    return 'Contact number can only contain digits';
                  }

                  // Check length (8-15 digits is reasonable for most countries)
                  int digitCount = cleanNumber.replaceAll('+', '').length;
                  if (digitCount < 8 || digitCount > 15) {
                    return 'Contact number must be 8-15 digits';
                  }

                  return null;
                },
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

// ---------------------------------------------------
// REUSABLE EDIT PROFILE FIELD WIDGET
// ---------------------------------------------------
class EditProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const EditProfileField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}