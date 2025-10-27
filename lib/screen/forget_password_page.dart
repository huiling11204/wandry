import 'package:flutter/material.dart';
import 'package:wandry/backend/userAuth.dart'; // Import your auth service

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final AuthService _authService = AuthService(); // Initialize auth service

  String _email = '';
  bool _isEmailValid = false;
  String _emailError = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    setState(() {
      _email = _emailController.text.trim();
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

      if (_email.isEmpty) {
        _emailError = '';
        _isEmailValid = false;
      } else if (!emailRegex.hasMatch(_email)) {
        _emailError = 'Please enter a valid email address';
        _isEmailValid = false;
      } else {
        _emailError = '';
        _isEmailValid = true;
      }
    });
  }

  void _clearForm() {
    _emailController.clear();
    setState(() {
      _email = '';
      _isEmailValid = false;
      _emailError = '';
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

  Future<void> _handleSubmit() async {
    if (!_isEmailValid) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Send password reset email using AuthService
      await _authService.sendPasswordResetEmail(_email);

      // Show success dialog
      _showSuccessDialog();

    } catch (e) {
      // Clear form and show error
      _clearForm();
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
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
                    color: Colors.green,
                  ),
                  child: Icon(
                    Icons.mark_email_read,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Text(
                  'Email Sent!',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12),

                // Message
                Text(
                  'Password reset instructions have been sent to $_email',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 8),

                Text(
                  'Please check your email and follow the instructions to reset your password.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12),

                // Password requirements reminder
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Reminder: For security, we recommend your new password contains 8+ characters with uppercase, lowercase, number, and special character.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 20),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to login
                    },
                    style: Theme.of(context).filledButtonTheme.style,
                    child: Text('Back to Login'),
                  ),
                ),

                SizedBox(height: 12),

                // Resend option
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    // Keep the email in the field for easy resend
                  },
                  child: Text(
                    'Resend Email',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                SizedBox(height: 60),

                // Title
                Center(
                  child: Text(
                    'Forgot Password',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),

                SizedBox(height: 20),

                // Description
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Please enter your registered email address to reset your password',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                SizedBox(height: 50),

                // Email Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email Field
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _emailError.isNotEmpty
                              ? theme.colorScheme.error
                              : _isEmailValid && _email.isNotEmpty
                              ? Colors.green.shade300
                              : theme.colorScheme.primary, // Blue outline
                          width: 1.5,
                        ),
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: theme.textTheme.bodyMedium,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Email ID',
                          hintStyle: theme.textTheme.labelSmall,
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: theme.colorScheme.onTertiary,
                          ),
                          suffixIcon: _email.isNotEmpty && !_isLoading
                              ? Icon(
                            _isEmailValid ? Icons.check_circle : Icons.error,
                            color: _isEmailValid ? Colors.green : theme.colorScheme.error,
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    if (_emailError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _emailError,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12,
                            fontFamily: theme.textTheme.bodySmall?.fontFamily,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 50),

                // Submit Button
                OutlinedButton(
                  onPressed: (_isLoading || !_isEmailValid) ? null : _handleSubmit,
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
                      : Text('Reset Password'),
                ),

                SizedBox(height: 40),

                // Back to Login
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Back to Login',
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