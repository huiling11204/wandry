import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_page.dart';
import 'package:wandry/screen/feedback/feedback_page.dart';
import 'package:wandry/widget/sweet_alert_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Settings'),
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 20),
        children: [
          SettingsItem(
            icon: Icons.person_outline,
            title: 'My Profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ViewProfilePage()),
              );
            },
          ),
          SettingsItem(
            icon: Icons.feedback_outlined,
            title: 'Feedback',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FeedbackPage()),
              );
            },
          ),
          SettingsItem(
            icon: Icons.logout,
            title: 'Log Out',
            showArrow: false,
            onTap: () async {
              final confirm = await SweetAlertDialog.confirm(
                context: context,
                title: 'Log Out',
                subtitle: 'Are you sure you want to log out?',
                confirmText: 'Log Out',
                cancelText: 'Cancel',
              );

              if (confirm == true) {
                await FirebaseAuth.instance.signOut();

                // Show success message briefly before navigating
                SweetAlertDialog.success(
                  context: context,
                  title: 'Logged Out',
                  subtitle: 'You have been logged out successfully.',
                );

                // Small delay to show the success message
                await Future.delayed(const Duration(milliseconds: 500));

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showArrow;

  const SettingsItem({super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: showArrow ? Icon(Icons.chevron_right, color: Colors.grey) : null,
        onTap: onTap,
      ),
    );
  }
}