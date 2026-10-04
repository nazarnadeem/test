import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/firebase_auth_service.dart';
import '../../../core/services/notification_service.dart';

/// Streamlined BLoC for Authentication and Firebase Login.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({AuthRepository? authRepository})
      : _authRepository = authRepository ?? FirebaseAuthService(),
        super(const AuthState()) {
    on<CheckInitialSessionEvent>(_onCheckInitialSession);
    on<LoginSubmittedEvent>(_onLoginSubmitted);
    on<CreateSuperAdminSubmittedEvent>(_onCreateSuperAdminSubmitted);
    on<RequestPasswordResetEvent>(_onRequestPasswordReset);
    on<LogoutEvent>(_onLogout);
    on<ClearAuthMessageEvent>(_onClearAuthMessage);
  }

  Future<void> _onCheckInitialSession(
    CheckInitialSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.checkingSession));
    try {
      final session = await _authRepository.getCurrentSession();
      if (session != null && !session.isExpired) {
        // Initialize Push Notifications for authenticated user
        NotificationService.initializeAndSaveToken(session.user.id);

        emit(state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          user: session.user,
        ));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (_) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final session = await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      
      // Initialize Push Notifications for authenticated user
      NotificationService.initializeAndSaveToken(session.user.id);

      emit(state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        user: session.user,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: _cleanErrorMessage(e.toString()),
      ));
    }
  }

  Future<void> _onCreateSuperAdminSubmitted(
    CreateSuperAdminSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final session = await _authRepository.registerSuperAdmin(
        fullName: event.fullName,
        email: event.email,
        password: event.password,
        phone: event.phone,
        securityPin: event.securityPin,
        organization: event.organization,
      );
      // Initialize Push Notifications for authenticated user
      NotificationService.initializeAndSaveToken(session.user.id);

      emit(state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        user: session.user,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: _cleanErrorMessage(e.toString()),
      ));
    }
  }

  Future<void> _onRequestPasswordReset(
    RequestPasswordResetEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final success =
          await _authRepository.requestPasswordReset(email: event.email);
      if (success) {
        emit(state.copyWith(
          status: AuthStatus.passwordResetSuccess,
          successMessage: 'Password reset link sent to ${event.email}',
        ));
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Failed to send reset link.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: _cleanErrorMessage(e.toString()),
      ));
    }
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final currentUserId = state.user?.id;
      if (currentUserId != null) {
        await NotificationService.clearTokenOnLogout(currentUserId);
      }
      await _authRepository.logout();
    } finally {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  void _onClearAuthMessage(
    ClearAuthMessageEvent event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  String _cleanErrorMessage(String error) {
    if (error.startsWith('Exception: ')) {
      return error.substring(11);
    }
    return error;
  }
}
