/// Utility class for form validation
class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Empty is handled separately
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email format';
    }

    return null; // Valid
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Empty is handled separately
    }

    bool hasMinLength = value.length >= 8;
    bool hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
    bool hasLowercase = RegExp(r'[a-z]').hasMatch(value);
    bool hasNumber = RegExp(r'[0-9]').hasMatch(value);
    bool hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);

    if (hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar) {
      return null; // Valid
    }

    return 'Invalid Password';
  }

  // Password validation with detailed message
  static String? validatePasswordDetailed(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    bool hasMinLength = value.length >= 8;
    bool hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
    bool hasLowercase = RegExp(r'[a-z]').hasMatch(value);
    bool hasNumber = RegExp(r'[0-9]').hasMatch(value);
    bool hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);

    if (hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar) {
      return null; // Valid
    }

    return 'Password must contain: 8+ characters, uppercase, lowercase, number, and special character';
  }

  // Name validation
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) {
      return '$fieldName can only contain letters';
    }

    return null; // Valid
  }

  // Contact number validation
  static String? validateContact(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    final contactRegex = RegExp(r'^[0-9]{10,15}$');

    if (!contactRegex.hasMatch(trimmed)) {
      return 'Please enter a valid contact number (10-15 digits)';
    }

    return null; // Valid
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null; // Valid
  }

  // Check if value is valid (no error)
  static bool isValid(String? errorMessage) {
    return errorMessage == null || errorMessage.isEmpty;
  }

  // Check if email format is valid
  static bool isEmailValid(String email) {
    return validateEmail(email) == null && email.isNotEmpty;
  }

  // Check if password is strong
  static bool isPasswordValid(String password) {
    return validatePassword(password) == null && password.isNotEmpty;
  }

  // Check if name is valid
  static bool isNameValid(String name) {
    return validateName(name) == null && name.trim().isNotEmpty;
  }

  // Check if contact is valid
  static bool isContactValid(String contact) {
    return validateContact(contact) == null && contact.trim().isNotEmpty;
  }

  // ---------------------------------------------------
  // PROFILE-SPECIFIC VALIDATORS (with required field checks)
  // ---------------------------------------------------

  /// Validates first name - REQUIRED field for profile
  static String? validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your first name';
    }
    if (value.trim().length < 2) {
      return 'First name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'First name can only contain letters';
    }
    return null;
  }

  /// Validates last name - OPTIONAL field for profile
  static String? validateLastName(String? value) {
    // Last name is optional, but if provided, validate it
    if (value != null && value.trim().isNotEmpty) {
      if (value.trim().length < 2) {
        return 'Last name must be at least 2 characters';
      }
      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
        return 'Last name can only contain letters';
      }
    }
    return null;
  }

  /// Validates email - REQUIRED field for profile
  static String? validateEmailRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    // Email validation regex
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates phone number - REQUIRED field for profile
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your contact number';
    }
    // Remove spaces and dashes for validation
    String cleanNumber = value.trim().replaceAll(RegExp(r'[\s-]'), '');

    // Check if it contains only digits (and optional + at start)
    if (!RegExp(r'^\+?\d+$').hasMatch(cleanNumber)) {
      return 'Contact number can only contain digits';
    }

    // Check length (8-15 digits is reasonable for most countries)
    int digitCount = cleanNumber.replaceAll('+', '').length;
    if (digitCount < 8 || digitCount > 15) {
      return 'Contact number must be 8-15 digits';
    }

    return null;
  }
}