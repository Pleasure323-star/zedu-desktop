import 'package:zedu/core/core.dart';

class Validators {
  static List<PasswordRequirement> passwordRequirements(String? value) {
    final password = value ?? '';

    return [
      PasswordRequirement(
        label: 'At least 8 characters',
        errorMessage: 'Password must be at least 8 characters',
        isMet: password.length >= 8,
      ),
      PasswordRequirement(
        label: 'One uppercase letter (A-Z)',
        errorMessage: 'Password must contain at least one uppercase letter',
        isMet: RegExp(r'[A-Z]').hasMatch(password),
      ),
      PasswordRequirement(
        label: 'One lowercase letter (a-z)',
        errorMessage: 'Password must contain at least one lowercase letter',
        isMet: RegExp(r'[a-z]').hasMatch(password),
      ),
      PasswordRequirement(
        label: 'One number (0-9)',
        errorMessage: 'Password must contain at least one number',
        isMet: RegExp(r'[0-9]').hasMatch(password),
      ),
    ];
  }

  static String? validatePassword(BuildContext context, String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    for (final requirement in passwordRequirements(value)) {
      if (!requirement.isMet) {
        return requirement.errorMessage;
      }
    }

    return null;
  }

  static String? validateEmail(BuildContext context, String? value) {
    final email = value?.trim();
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) return 'Please enter a valid email';
    return null;
  }

  static String? validateRequired(
    BuildContext context,
    String? value, {
    String? fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }
}

class PasswordRequirement {
  const PasswordRequirement({
    required this.label,
    required this.errorMessage,
    required this.isMet,
  });

  final String label;
  final String errorMessage;
  final bool isMet;
}
