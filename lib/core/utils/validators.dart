import '../constants/app_strings.dart';

/// Form and input validation helper methods for GCRM One.
class Validators {
  Validators._();

  /// Validates standard email address format
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.emailRequired;
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return AppStrings.invalidEmail;
    }
    return null;
  }

  /// Validates password presence & minimum length
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    if (value.length < 8) {
      return AppStrings.passwordTooShort;
    }
    return null;
  }

  /// Validates password confirmation match
  static String? confirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    if (value != originalPassword) {
      return AppStrings.passwordsDoNotMatch;
    }
    return null;
  }

  /// Validates generic required text fields
  static String? requiredField(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '$fieldName is required.' : AppStrings.fieldRequired;
    }
    return null;
  }

  /// Validates gym code / invite format
  static String? gymCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.gymCodeRequired;
    }
    if (value.trim().length < 4) {
      return 'Gym code must be at least 4 characters.';
    }
    return null;
  }

  /// Validates phone number format
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (cleanPhone.length < 7 || cleanPhone.length > 15) {
      return 'Please enter a valid phone number.';
    }
    return null;
  }
}
