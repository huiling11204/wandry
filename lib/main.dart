import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'widget/theme.dart';
import 'screen/welcome_page.dart';
import 'screen/login_page.dart';
import 'screen/register_page.dart';
import 'screen/forget_password_page.dart';
import 'screen/home_page.dart';

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
      initialRoute: '/welcome', // Start with welcome page
      routes: {
        '/welcome': (context) => WelcomePage(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/forgot-password': (context) => ForgotPasswordPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}