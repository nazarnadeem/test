import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// App launch session check
class CheckInitialSessionEvent extends AuthEvent {
  const CheckInitialSessionEvent();
}

/// Standard Login submitted
class LoginSubmittedEvent extends AuthEvent {
  final String email;
  final String password;

  const LoginSubmittedEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Request password reset link
class RequestPasswordResetEvent extends AuthEvent {
  final String email;
  const RequestPasswordResetEvent(this.email);

  @override
  List<Object?> get props => [email];
}

/// Create / Register Super Admin
class CreateSuperAdminSubmittedEvent extends AuthEvent {
  final String fullName;
  final String email;
  final String password;
  final String phone;
  final String? securityPin;
  final String? organization;

  const CreateSuperAdminSubmittedEvent({
    required this.fullName,
    required this.email,
    required this.password,
    required this.phone,
    this.securityPin,
    this.organization,
  });

  @override
  List<Object?> get props => [
        fullName,
        email,
        password,
        phone,
        securityPin,
        organization,
      ];
}

/// Sign out
class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

/// Clear messages
class ClearAuthMessageEvent extends AuthEvent {
  const ClearAuthMessageEvent();
}
