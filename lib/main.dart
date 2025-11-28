import 'package:firebase_core/firebase_core.dart';
import 'package:wandry/screen/admin/admin_feedback_page.dart';
import 'package:wandry/screen/admin/admin_users_page.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'widget/theme.dart';
import 'screen/welcome_page.dart';
import 'screen/login_page.dart';
import 'screen/register_page.dart';
import 'screen/forget_password_page.dart';
import 'screen/home_page.dart';
import 'screen/admin/admin_dashboard.dart';
import 'package:wandry/screen/admin/admin_settings_page.dart';
import 'package:wandry/screen/admin/admin_reports_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wandry - Personalized Trip Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme,
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomePage(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/forgot-password': (context) => ForgotPasswordPage(),
        '/home': (context) => HomePage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/admin-users': (context) => const AdminUsersPage(),
        '/admin-feedback': (context) => const AdminFeedbackPage(),
        '/admin-reports': (context) => const AdminReportsPage(),
        '/admin-settings': (context) => const AdminSettingsPage(),
      },
    );
  }
}