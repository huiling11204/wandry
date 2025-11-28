import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controller/userAuth.dart';
import '../../controller/theme_controller.dart';
import '../../widget/sweet_alert_dialog.dart';
import 'legal_document_editor_page.dart';

/// AdminSettingsPage - Simplified settings page with SweetAlert
/// Features: Edit Profile, Dark Mode, Change Password, Legal Documents
/// Place this in lib/screen/admin/admin_settings_page.dart
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ThemeController _themeController = ThemeController();

  Map<String, dynamic>? _adminProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAdminProfile() async {
    try {
      User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        Map<String, dynamic>? profile =
        await _authService.getUserProfile(currentUser.uid);

        await _themeController.initializeTheme(currentUser.uid);

        if (mounted) {
          setState(() {
            _adminProfile = profile;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ThemeController get tc => _themeController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: tc.appBarForegroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: tc.appBarColor,
        iconTheme: IconThemeData(color: tc.appBarForegroundColor),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Colors.blue[600],
        ),
      )
          : Container(
        color: tc.backgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== PROFILE SECTION =====
              _buildSectionTitle('Profile'),
              _buildProfileCard(),
              const SizedBox(height: 24),

              // ===== APPEARANCE SECTION =====
              _buildSectionTitle('Appearance'),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode (Admin)',
                  subtitle: 'Use dark theme for admin pages',
                  value: tc.isDarkMode,
                  onChanged: (value) async {
                    await tc.toggleDarkMode(value);
                    if (mounted) {
                      SweetAlertDialog.success(
                        context: context,
                        title: 'Settings Saved',
                        subtitle: value
                            ? 'Dark mode has been enabled'
                            : 'Dark mode has been disabled',
                      );
                    }
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // ===== SECURITY SECTION =====
              _buildSectionTitle('Security'),
              _buildSettingsCard([
                _buildNavigationTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: _showChangePasswordDialog,
                ),
              ]),
              const SizedBox(height: 24),

              // ===== LEGAL DOCUMENTS SECTION =====
              _buildSectionTitle('Legal Documents'),
              _buildSettingsCard([
                _buildNavigationTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Edit terms of service',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LegalDocumentEditorPage(
                          documentType: LegalDocumentType.termsAndConditions,
                        ),
                      ),
                    );
                  },
                  trailing: _buildEditBadge(),
                ),
                _buildDivider(),
                _buildNavigationTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Edit privacy policy',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LegalDocumentEditorPage(
                          documentType: LegalDocumentType.privacyPolicy,
                        ),
                      ),
                    );
                  },
                  trailing: _buildEditBadge(),
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit, size: 12, color: Colors.blue[600]),
          const SizedBox(width: 4),
          Text(
            'Edit',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: tc.subtitleColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final email = _adminProfile?['email'] ?? 'N/A';
    final adminName = _adminProfile?['profile']?['adminName'] ?? 'Admin';
    final userId = _adminProfile?['userID'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ID: $userId',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: tc.dividerColor);
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      color: tc.cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[600], size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: tc.textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: tc.subtitleStyle(fontSize: 13),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue[600],
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      color: tc.cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[600], size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: tc.textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: tc.subtitleStyle(fontSize: 13),
        ),
        trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 16, color: tc.iconColor),
        onTap: onTap,
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(
      text: _adminProfile?['profile']?['adminName'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tc.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue[600]),
            const SizedBox(width: 12),
            Text('Edit Profile', style: tc.titleStyle(fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: tc.textColor),
          decoration: tc.inputDecoration(
            labelText: 'Admin Name',
            prefixIcon: Icon(Icons.person_outline, color: tc.iconColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: tc.subtitleColor)),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                await _updateAdminName(nameController.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAdminName(String newName) async {
    try {
      final firebaseUid = _adminProfile?['firebaseUid'];
      if (firebaseUid == null) return;

      final profileQuery = await _firestore
          .collection('adminProfile')
          .where('firebaseUid', isEqualTo: firebaseUid)
          .limit(1)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        await profileQuery.docs.first.reference.update({'adminName': newName});
        await _loadAdminProfile();
        if (mounted) {
          SweetAlertDialog.success(
            context: context,
            title: 'Profile Updated',
            subtitle: 'Your admin name has been changed successfully',
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Update Failed',
          subtitle: 'Failed to update profile. Please try again.',
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tc.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.blue[600]),
            const SizedBox(width: 12),
            Text('Change Password', style: tc.titleStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                style: TextStyle(color: tc.textColor),
                decoration: tc.inputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline, color: tc.iconColor),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: TextStyle(color: tc.textColor),
                decoration: tc.inputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline, color: tc.iconColor),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: TextStyle(color: tc.textColor),
                decoration: tc.inputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_outline, color: tc.iconColor),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: tc.subtitleColor)),
          ),
          FilledButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                Navigator.pop(context);
                SweetAlertDialog.error(
                  context: context,
                  title: 'Password Mismatch',
                  subtitle: 'New passwords do not match. Please try again.',
                );
                return;
              }
              if (newPasswordController.text.length < 6) {
                Navigator.pop(context);
                SweetAlertDialog.warning(
                  context: context,
                  title: 'Weak Password',
                  subtitle: 'Password must be at least 6 characters long.',
                );
                return;
              }
              Navigator.pop(context);
              await _changePassword(
                currentPasswordController.text,
                newPasswordController.text,
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(String currentPassword, String newPassword) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      if (mounted) {
        SweetAlertDialog.success(
          context: context,
          title: 'Password Changed',
          subtitle: 'Your password has been updated successfully.',
        );
      }
    } catch (e) {
      debugPrint('Error changing password: $e');
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Change Failed',
          subtitle: 'Failed to change password. Please check your current password.',
        );
      }
    }
  }
}