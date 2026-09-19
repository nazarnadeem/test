import 'package:equatable/equatable.dart';
import '../data/models/user_model.dart';
import '../data/models/auth_session.dart';

enum AuthStatus {
  initial,
  checkingSession,
  loading,
  authenticated,
  unauthenticated,
  passwordResetSuccess,
  error,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final AuthSession? session;
  final UserModel? user;
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.user,
    this.errorMessage,
    this.successMessage,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && session != null && !session!.isExpired;
  bool get isLoading =>
      status == AuthStatus.loading || status == AuthStatus.checkingSession;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    UserModel? user,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        session,
        user,
        errorMessage,
        successMessage,
      ];
}
