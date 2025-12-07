// ============================================
// LOGIN PAGE - Complete with Email Verification Support
// Location: lib/screen/login_page.dart
// ============================================
import 'package:flutter/material.dart';
import '../controller/userAuth.dart';
import '../controller/auth_wrapper.dart';
import '../utilities/validators.dart';
import '../widget/custom_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final AuthWrapper _authWrapper = AuthWrapper();

  String _email = '';
  String _password = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  String _emailError = '';
  String _passwordError = '';

  // For email verification message
  String? verificationMessage;
  String? suggestedEmail;

  // Focus nodes for border color changes
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);

    // Listen to focus changes to trigger rebuilds
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we received arguments from email verification redirect
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      setState(() {
        verificationMessage = args['message'] as String?;
        suggestedEmail = args['newEmail'] as String?;

        // Pre-fill email field if provided
        if (suggestedEmail != null && suggestedEmail!.isNotEmpty) {
          _emailController.text = suggestedEmail!;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _validateEmail() {
    setState(() {
      _email = _emailController.text;
      _emailError = Validators.validateEmail(_email) ?? '';
      _isEmailValid = Validators.isEmailValid(_email);
    });
  }

  void _validatePassword() {
    setState(() {
      _password = _passwordController.text;
      _passwordError = Validators.validatePassword(_password) ?? '';
      _isPasswordValid = Validators.isPasswordValid(_password);
    });
  }

  void _navigateToForgotPassword() {
    Navigator.pushNamed(context, '/forgot-password');
  }

  void _navigateToSignUp() {
    Navigator.pushNamed(context, '/register');
  }

  void _showLoginDialog(bool isSuccess, [String? errorMessage]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isSuccess ? 'Login Successful' : 'Login Failed',
                  style: Theme.of(dialogContext).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (!isSuccess && errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      errorMessage,
                      style: Theme.of(dialogContext).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();

                      if (isSuccess) {
                        if (mounted) {
                          String route = await _authWrapper.determineInitialRoute();
                          if (mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              route,
                                  (route) => false,
                            );
                          }
                        }
                      }
                    },
                    child: Text(isSuccess ? 'Continue' : 'Try Again'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _email = '';
      _password = '';
      _isEmailValid = false;
      _isPasswordValid = false;
      _emailError = '';
      _passwordError = '';
    });
  }

  Future<void> _handleLogin() async {
    if (!_isEmailValid || !_isPasswordValid) {
      _showLoginDialog(false, 'Please enter valid email and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithEmailAndPassword(_email.trim(), _password);
      _showLoginDialog(true);
    } catch (e) {
      _clearForm();
      _showLoginDialog(false, e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Email Verification Success Banner
                if (verificationMessage != null)
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.green[700], size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Verified! ✓',
                                style: TextStyle(
                                  color: Colors.green[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Please log in with your new email address',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Welcome Title - CENTERED
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Welcome to ',
                        style: TextStyle(color: Colors.black),
                      ),
                      TextSpan(
                        text: 'Wandry',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle - CENTERED
                Text(
                  'Please sign in to continue our app',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 48),

                // Email Field
                Focus(
                  focusNode: _emailFocusNode,
                  child: CustomTextField(
                    label: 'Email Address',
                    hint: 'joemama0ng@myComp.com',
                    controller: _emailController,
                    isValid: _isEmailValid,
                    errorText: _emailError,
                    value: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    isFocused: _emailFocusNode.hasFocus,
                  ),
                ),

                const SizedBox(height: 24),

                // Password Field
                Focus(
                  focusNode: _passwordFocusNode,
                  child: CustomTextField(
                    label: 'Password',
                    hint: '••••••••••',
                    controller: _passwordController,
                    isValid: _isPasswordValid,
                    errorText: _passwordError,
                    value: _password,
                    obscureText: !_isPasswordVisible,
                    showVisibilityToggle: true,
                    onVisibilityToggle: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    enabled: !_isLoading,
                    isFocused: _passwordFocusNode.hasFocus,
                  ),
                ),

                const SizedBox(height: 8),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _navigateToForgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign In Button - Full width
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_isLoading || !_isEmailValid || !_isPasswordValid)
                        ? null
                        : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Sign In',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Sign Up Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?  ",
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _navigateToSignUp,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}