import 'package:flutter/material.dart';
import 'package:wandry/backend/userAuth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  String _email = '';
  String _password = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  String _emailError = '';
  String _passwordError = '';

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    setState(() {
      _email = _emailController.text;
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

      if (_email.isEmpty) {
        _emailError = '';
        _isEmailValid = false;
      } else if (!emailRegex.hasMatch(_email)) {
        _emailError = 'Please enter a valid email format';
        _isEmailValid = false;
      } else {
        _emailError = '';
        _isEmailValid = true;
      }
    });
  }

  void _validatePassword() {
    setState(() {
      _password = _passwordController.text;

      if (_password.isEmpty) {
        _passwordError = '';
        _isPasswordValid = false;
        return;
      }

      bool hasMinLength = _password.length >= 8;
      bool hasUppercase = RegExp(r'[A-Z]').hasMatch(_password);
      bool hasLowercase = RegExp(r'[a-z]').hasMatch(_password);
      bool hasNumber = RegExp(r'[0-9]').hasMatch(_password);
      bool hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_password);

      if (hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar) {
        _passwordError = '';
        _isPasswordValid = true;
      } else {
        _passwordError = 'Invalid Password';
        _isPasswordValid = false;
      }
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
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
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
                SizedBox(height: 20),
                Text(
                  isSuccess ? 'Login Successful' : 'Login Failed',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (!isSuccess && errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      errorMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (isSuccess) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                              (route) => false,
                        );
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

  Color _getBorderColor(bool hasError, bool isValid, String value, bool isFocused) {
    if (hasError) return Theme.of(context).colorScheme.error;
    if (isFocused) return Theme.of(context).colorScheme.primary;
    if (isValid && value.isNotEmpty) return Colors.green.shade400;
    return Theme.of(context).colorScheme.surfaceDim;
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
          icon: Icon(Icons.arrow_back_ios, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // CHANGED: Center alignment
              children: [
                SizedBox(height: 60), // CHANGED: More space at top

                // Welcome Title - CENTERED
                RichText(
                  textAlign: TextAlign.center, // ADDED
                  text: TextSpan(
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 28, // CHANGED: Adjust size to match image
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
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

                SizedBox(height: 12), // CHANGED: Adjusted spacing

                // Subtitle - CENTERED
                Text(
                  'Please sign in to continue our app',
                  textAlign: TextAlign.center, // ADDED
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),

                SizedBox(height: 48), // CHANGED: More spacing before form

                // Email Field - Keep left aligned for form
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email Address',
                      style: theme.textTheme.labelLarge,
                    ),
                    SizedBox(height: 8),
                    Focus(
                      onFocusChange: (hasFocus) {
                        setState(() {});
                      },
                      child: Builder(
                        builder: (context) {
                          final isFocused = Focus.of(context).hasFocus;
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getBorderColor(_emailError.isNotEmpty, _isEmailValid, _email, isFocused),
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: theme.textTheme.bodyMedium,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                hintText: 'joemama0ng@myComp.com',
                                hintStyle: theme.textTheme.labelMedium,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_emailError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          _emailError,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 24),

                // Password Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: theme.textTheme.labelLarge,
                    ),
                    SizedBox(height: 8),
                    Focus(
                      onFocusChange: (hasFocus) {
                        setState(() {});
                      },
                      child: Builder(
                        builder: (context) {
                          final isFocused = Focus.of(context).hasFocus;
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getBorderColor(_passwordError.isNotEmpty, _isPasswordValid, _password, isFocused),
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              style: theme.textTheme.bodyMedium,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                hintText: '••••••••••',
                                hintStyle: theme.textTheme.labelMedium,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: theme.colorScheme.onTertiary,
                                  ),
                                  onPressed: _isLoading ? null : () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_passwordError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          _passwordError,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 8),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _navigateToForgotPassword,
                    child: Text('Forgot Password?'),
                  ),
                ),

                SizedBox(height: 24),

                // Sign In Button - Full width
                SizedBox(
                  width: double.infinity, // ADDED: Full width button
                  child: FilledButton(
                    onPressed: (_isLoading || !_isEmailValid || !_isPasswordValid) ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16), // ADDED
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      'Sign In',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                SizedBox(height: 60),

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
                        minimumSize: Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Sign up'),
                    ),
                  ],
                ),

                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}