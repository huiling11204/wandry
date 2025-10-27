import 'package:flutter/material.dart';
import 'package:wandry/backend/userAuth.dart'; // Import your auth service

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService(); // Initialize auth service

  String _name = '';
  String _email = '';
  String _contact = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Validation states
  bool _isNameValid = false;
  bool _isEmailValid = false;
  bool _isContactValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  String _nameError = '';
  String _emailError = '';
  String _contactError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateName);
    _emailController.addListener(_validateEmail);
    _contactController.addListener(_validateContact);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateName() {
    setState(() {
      _name = _nameController.text.trim();
      if (_name.isEmpty) {
        _nameError = '';
        _isNameValid = false;
      } else if (_name.length < 2) {
        _nameError = 'Name must be at least 2 characters';
        _isNameValid = false;
      } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(_name)) {
        _nameError = 'Name can only contain letters and spaces';
        _isNameValid = false;
      } else {
        _nameError = '';
        _isNameValid = true;
      }
    });
  }

  void _validateEmail() {
    setState(() {
      _email = _emailController.text.trim();
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

  void _validateContact() {
    setState(() {
      _contact = _contactController.text.trim();
      final contactRegex = RegExp(r'^[0-9]{10,15}$');

      if (_contact.isEmpty) {
        _contactError = '';
        _isContactValid = false;
      } else if (!contactRegex.hasMatch(_contact)) {
        _contactError = 'Please enter a valid contact number (10-15 digits)';
        _isContactValid = false;
      } else {
        _contactError = '';
        _isContactValid = true;
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
        _passwordError = 'Password must contain: 8+ characters, uppercase, lowercase, number, and special character';
        _isPasswordValid = false;
      }

      // Re-validate confirm password when password changes
      _validateConfirmPassword();
    });
  }

  void _validateConfirmPassword() {
    setState(() {
      _confirmPassword = _confirmPasswordController.text;

      if (_confirmPassword.isEmpty) {
        _confirmPasswordError = '';
        _isConfirmPasswordValid = false;
      } else if (_confirmPassword != _password) {
        _confirmPasswordError = 'Passwords do not match';
        _isConfirmPasswordValid = false;
      } else {
        _confirmPasswordError = '';
        _isConfirmPasswordValid = true;
      }
    });
  }

  void _showErrorDialog(String message) {
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
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 20),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                    },
                    style: Theme.of(context).outlinedButtonTheme.style,
                    child: Text('Try Again'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRegistrationDialog(bool isSuccess, [String? errorMessage]) {
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
                // Icon
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

                // Title
                Text(
                  isSuccess ? 'Registration Successful' : 'Registration Failed',
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

                // Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      if (isSuccess) {
                        // Navigate back to login
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                              (route) => false,
                        );
                      }
                    },
                    style: Theme.of(context).outlinedButtonTheme.style,
                    child: Text(isSuccess ? 'Back to Login' : 'Try Again'),
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
    _nameController.clear();
    _emailController.clear();
    _contactController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _name = '';
      _email = '';
      _contact = '';
      _password = '';
      _confirmPassword = '';
      _isNameValid = false;
      _isEmailValid = false;
      _isContactValid = false;
      _isPasswordValid = false;
      _isConfirmPasswordValid = false;
      _nameError = '';
      _emailError = '';
      _contactError = '';
      _passwordError = '';
      _confirmPasswordError = '';
    });
  }

  Future<void> _handleRegister() async {
    // Validate all fields
    bool allValid = _isNameValid &&
        _isEmailValid &&
        _isContactValid &&
        _isPasswordValid &&
        _isConfirmPasswordValid;

    if (!allValid) {
      _showErrorDialog('Please fill all fields correctly and agree to terms');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use AuthService to create user account
      await _authService.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
        name: _name,
        contact: _contact,
      );

      _showRegistrationDialog(true);

    } catch (e) {
      // Clear form and show error dialog
      _clearForm();
      _showRegistrationDialog(false, e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData prefixIcon,
    required bool isValid,
    required String errorText,
    String? value,
    bool obscureText = false,
    bool showVisibilityToggle = false,
    VoidCallback? onVisibilityToggle,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium,
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText.isNotEmpty
                  ? theme.colorScheme.error
                  : isValid && value != null && value.isNotEmpty
                  ? Colors.green.shade400
                  : theme.colorScheme.primary, // Blue outline
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: theme.textTheme.bodyMedium,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.labelSmall,
              prefixIcon: Icon(
                prefixIcon,
                color: theme.colorScheme.onTertiary,
              ),
              suffixIcon: showVisibilityToggle
                  ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: theme.colorScheme.onTertiary,
                ),
                onPressed: _isLoading ? null : onVisibilityToggle,
              )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              errorText,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
                fontFamily: theme.textTheme.bodySmall?.fontFamily,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white, // White background to match design
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 40),

                // Title
                Center(
                  child: Text(
                    'Register Account',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),

                SizedBox(height: 40),

                // Name Field
                _buildInputField(
                  label: 'Enter your name',
                  hint: 'Your Name',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                  isValid: _isNameValid,
                  errorText: _nameError,
                  value: _name,
                ),

                SizedBox(height: 20),

                // Email Field
                _buildInputField(
                  label: 'Enter your email',
                  hint: 'Email',
                  controller: _emailController,
                  prefixIcon: Icons.email_outlined,
                  isValid: _isEmailValid,
                  errorText: _emailError,
                  value: _email,
                  keyboardType: TextInputType.emailAddress,
                ),

                SizedBox(height: 20),

                // Contact Number Field
                _buildInputField(
                  label: 'Enter your contact number',
                  hint: 'Your Contact Number',
                  controller: _contactController,
                  prefixIcon: Icons.phone_outlined,
                  isValid: _isContactValid,
                  errorText: _contactError,
                  value: _contact,
                  keyboardType: TextInputType.phone,
                ),

                SizedBox(height: 20),

                // Password Field
                _buildInputField(
                  label: 'Enter your password',
                  hint: 'Password',
                  controller: _passwordController,
                  prefixIcon: Icons.lock_outline,
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
                ),

                SizedBox(height: 20),

                // Confirm Password Field
                _buildInputField(
                  label: 'Enter confirm password',
                  hint: 'Confirm Password',
                  controller: _confirmPasswordController,
                  prefixIcon: Icons.lock_outline,
                  isValid: _isConfirmPasswordValid,
                  errorText: _confirmPasswordError,
                  value: _confirmPassword,
                  obscureText: !_isConfirmPasswordVisible,
                  showVisibilityToggle: true,
                  onVisibilityToggle: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),

                SizedBox(height: 20),

                // Sign Up Button
                OutlinedButton(
                  onPressed: (_isLoading || !_isNameValid || !_isEmailValid ||
                      !_isContactValid || !_isPasswordValid ||
                      !_isConfirmPasswordValid)
                      ? null
                      : _handleRegister,
                  style: theme.outlinedButtonTheme.style,
                  child: _isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                      : Text('Sign Up'),
                ),

                SizedBox(height: 30),

                // Already have account
                Column(
                  children: [
                    Text(
                      'Already have an account?',
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: _isLoading ? null : () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: _isLoading ? theme.colorScheme.outline : theme
                              .colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          decoration: TextDecoration.underline,
                          decorationColor: _isLoading ? theme.colorScheme
                              .outline : theme.colorScheme.primary,
                        ),
                      ),
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