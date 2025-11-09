import 'package:flutter/material.dart';
import 'package:wandry/backend/userAuth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _contact = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreedToTerms = false;

  // Validation states
  bool _isFirstNameValid = false;
  bool _isLastNameValid = false;
  bool _isEmailValid = false;
  bool _isContactValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  String _firstNameError = '';
  String _lastNameError = '';
  String _emailError = '';
  String _contactError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_validateFirstName);
    _lastNameController.addListener(_validateLastName);
    _emailController.addListener(_validateEmail);
    _contactController.addListener(_validateContact);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateFirstName() {
    setState(() {
      _firstName = _firstNameController.text.trim();
      if (_firstName.isEmpty) {
        _firstNameError = '';
        _isFirstNameValid = false;
      } else if (_firstName.length < 2) {
        _firstNameError = 'First name must be at least 2 characters';
        _isFirstNameValid = false;
      } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(_firstName)) {
        _firstNameError = 'First name can only contain letters';
        _isFirstNameValid = false;
      } else {
        _firstNameError = '';
        _isFirstNameValid = true;
      }
    });
  }

  void _validateLastName() {
    setState(() {
      _lastName = _lastNameController.text.trim();
      if (_lastName.isEmpty) {
        _lastNameError = '';
        _isLastNameValid = false;
      } else if (_lastName.length < 2) {
        _lastNameError = 'Last name must be at least 2 characters';
        _isLastNameValid = false;
      } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(_lastName)) {
        _lastNameError = 'Last name can only contain letters';
        _isLastNameValid = false;
      } else {
        _lastNameError = '';
        _isLastNameValid = true;
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (isSuccess) {
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
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _contactController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _firstName = '';
      _lastName = '';
      _email = '';
      _contact = '';
      _password = '';
      _confirmPassword = '';
      _agreedToTerms = false;
      _isFirstNameValid = false;
      _isLastNameValid = false;
      _isEmailValid = false;
      _isContactValid = false;
      _isPasswordValid = false;
      _isConfirmPasswordValid = false;
      _firstNameError = '';
      _lastNameError = '';
      _emailError = '';
      _contactError = '';
      _passwordError = '';
      _confirmPasswordError = '';
    });
  }

  Future<void> _handleRegister() async {
    bool allValid = _isFirstNameValid &&
        _isLastNameValid &&
        _isEmailValid &&
        _isContactValid &&
        _isPasswordValid &&
        _isConfirmPasswordValid &&
        _agreedToTerms;

    if (!allValid) {
      _showErrorDialog('Please fill all fields correctly and agree to terms');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine first name and last name for registration
      String fullName = '$_firstName $_lastName'.trim();

      await _authService.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
        name: fullName,
        contact: _contact,
      );

      _showRegistrationDialog(true);

    } catch (e) {
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
                  : theme.colorScheme.primary,
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
      backgroundColor: Colors.white,
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
                  child: Column(
                    children: [
                      Text(
                        'Sign up now',
                        style: theme.textTheme.headlineMedium,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please fill the details and create account',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40),

                // First Name Field
                _buildInputField(
                  label: 'First name',
                  hint: 'Enter your first name',
                  controller: _firstNameController,
                  prefixIcon: Icons.person_outline,
                  isValid: _isFirstNameValid,
                  errorText: _firstNameError,
                  value: _firstName,
                ),

                SizedBox(height: 20),

                // Last Name Field
                _buildInputField(
                  label: 'Last name',
                  hint: 'Enter your last name',
                  controller: _lastNameController,
                  prefixIcon: Icons.person_outline,
                  isValid: _isLastNameValid,
                  errorText: _lastNameError,
                  value: _lastName,
                ),

                SizedBox(height: 20),

                // Email Field
                _buildInputField(
                  label: 'Email',
                  hint: 'Enter your email',
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
                  label: 'Contact number',
                  hint: 'Enter your contact number',
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
                  label: 'Password',
                  hint: 'Enter your password',
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
                  label: 'Confirm password',
                  hint: 'Enter confirm password',
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

                // Terms and Conditions Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: _isLoading ? null : (bool? value) {
                          setState(() {
                            _agreedToTerms = value ?? false;
                          });
                        },
                        activeColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black,
                          ),
                          children: [
                            TextSpan(text: 'I agree to the '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: _isLoading ? null : () {
                                  // TODO: Navigate to Terms & Conditions page
                                  print('Terms & Conditions clicked');
                                },
                                child: Text(
                                  'Terms & Conditions',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(text: ' & '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: _isLoading ? null : () {
                                  // TODO: Navigate to Privacy Policy page
                                  print('Privacy Policy clicked');
                                },
                                child: Text(
                                  'Privacy Policy',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(text: ' set out by this site'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 30),

                // Sign Up Button
                OutlinedButton(
                  onPressed: (_isLoading || !_isFirstNameValid || !_isLastNameValid ||
                      !_isEmailValid || !_isContactValid || !_isPasswordValid ||
                      !_isConfirmPasswordValid || !_agreedToTerms)
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
                        'Sign in',
                        style: TextStyle(
                          color: _isLoading ? theme.colorScheme.outline : theme.colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          decoration: TextDecoration.underline,
                          decorationColor: _isLoading ? theme.colorScheme.outline : theme.colorScheme.primary,
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