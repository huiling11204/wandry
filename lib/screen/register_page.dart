import 'package:flutter/material.dart';
import '../controller/userAuth.dart';
import '../utilities/validators.dart';
import '../widget/custom_text_field.dart';
import 'terms_and_conditions_page.dart';
import 'privacy_policy_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
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
      _firstNameError = Validators.validateName(_firstName, fieldName: 'First name') ?? '';
      _isFirstNameValid = Validators.isNameValid(_firstName);
    });
  }

  void _validateLastName() {
    setState(() {
      _lastName = _lastNameController.text.trim();
      _lastNameError = Validators.validateName(_lastName, fieldName: 'Last name') ?? '';
      _isLastNameValid = Validators.isNameValid(_lastName);
    });
  }

  void _validateEmail() {
    setState(() {
      _email = _emailController.text.trim();
      _emailError = Validators.validateEmail(_email) ?? '';
      _isEmailValid = Validators.isEmailValid(_email);
    });
  }

  void _validateContact() {
    setState(() {
      _contact = _contactController.text.trim();
      _contactError = Validators.validateContact(_contact) ?? '';
      _isContactValid = Validators.isContactValid(_contact);
    });
  }

  void _validatePassword() {
    setState(() {
      _password = _passwordController.text;
      _passwordError = Validators.validatePasswordDetailed(_password) ?? '';
      _isPasswordValid = Validators.isPasswordValid(_password);
      _validateConfirmPassword();
    });
  }

  void _validateConfirmPassword() {
    setState(() {
      _confirmPassword = _confirmPasswordController.text;
      _confirmPasswordError = Validators.validateConfirmPassword(_confirmPassword, _password) ?? '';
      _isConfirmPasswordValid = _confirmPassword.isNotEmpty && _confirmPassword == _password;
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: Theme.of(context).outlinedButtonTheme.style,
                    child: const Text('Try Again'),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 40),

                // Title
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Sign up now',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please fill the details and create account',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // First Name Field
                CustomTextFieldWithIcon(
                  label: 'First name',
                  hint: 'Enter your first name',
                  controller: _firstNameController,
                  prefixIcon: Icons.person_outline,
                  isValid: _isFirstNameValid,
                  errorText: _firstNameError,
                  value: _firstName,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Last Name Field
                CustomTextFieldWithIcon(
                  label: 'Last name',
                  hint: 'Enter your last name',
                  controller: _lastNameController,
                  prefixIcon: Icons.person_outline,
                  isValid: _isLastNameValid,
                  errorText: _lastNameError,
                  value: _lastName,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Email Field
                CustomTextFieldWithIcon(
                  label: 'Email',
                  hint: 'Enter your email',
                  controller: _emailController,
                  prefixIcon: Icons.email_outlined,
                  isValid: _isEmailValid,
                  errorText: _emailError,
                  value: _email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Contact Number Field
                CustomTextFieldWithIcon(
                  label: 'Contact number',
                  hint: 'Enter your contact number',
                  controller: _contactController,
                  prefixIcon: Icons.phone_outlined,
                  isValid: _isContactValid,
                  errorText: _contactError,
                  value: _contact,
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Password Field
                CustomTextFieldWithIcon(
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
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Confirm Password Field
                CustomTextFieldWithIcon(
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
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Terms and Conditions Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: _isLoading
                            ? null
                            : (bool? value) {
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black,
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TermsAndConditionsPage(),
                                    ),
                                  );
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
                            const TextSpan(text: ' & '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PrivacyPolicyPage(),
                                    ),
                                  );
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
                            const TextSpan(text: ' set out by this site'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Sign Up Button
                OutlinedButton(
                  onPressed: (_isLoading ||
                      !_isFirstNameValid ||
                      !_isLastNameValid ||
                      !_isEmailValid ||
                      !_isContactValid ||
                      !_isPasswordValid ||
                      !_isConfirmPasswordValid ||
                      !_agreedToTerms)
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
                      : const Text('Sign Up'),
                ),

                const SizedBox(height: 30),

                // Already have account
                Column(
                  children: [
                    Text(
                      'Already have an account?',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Sign in',
                        style: TextStyle(
                          color: _isLoading
                              ? theme.colorScheme.outline
                              : theme.colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          decoration: TextDecoration.underline,
                          decorationColor: _isLoading
                              ? theme.colorScheme.outline
                              : theme.colorScheme.primary,
                        ),
                      ),
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