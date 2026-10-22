import 'package:flutter/services.dart';

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

  static const String mobileHint = '9876543210';

  static final List<TextInputFormatter> mobileInputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  /// Keeps the last 10 digits so saved numbers with a country code still fit the field.
  static String tenDigits(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  /// Validates a required 10 digit mobile number.
  static String? phone(String? value) => _mobile(value, required: true);

  /// Validates an optional 10 digit mobile number.
  static String? optionalPhone(String? value) => _mobile(value, required: false);

  static String? _mobile(String? value, {required bool required}) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return required ? 'Enter a 10 digit mobile number.' : null;
    }
    if (digits.length != 10) return 'Enter a 10 digit mobile number.';
    return null;
  }
}
