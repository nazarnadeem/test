import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/constants/app_strings.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';

void main() {
  group('GCRM One Auth Module Tests', () {
    late AuthController authController;
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      authController = AuthController(authRepository: mockAuthService);
    });

    test('Initial state is not authenticated', () {
      expect(authController.isAuthenticated, false);
      expect(authController.currentUser, null);
      expect(authController.isLoading, false);
    });

    test('Login Success with Email and Password', () async {
      final success = await authController.login(
        email: AppStrings.demoSuperAdminEmail,
        password: AppStrings.demoSuperAdminPass,
      );

      expect(success, true);
      expect(authController.isAuthenticated, true);
      expect(authController.currentUser?.email, AppStrings.demoSuperAdminEmail);
    });

    test('Login Fails on Incorrect Password', () async {
      final success = await authController.login(
        email: AppStrings.demoSuperAdminEmail,
        password: 'WrongPassword123',
      );

      expect(success, false);
      expect(authController.isAuthenticated, false);
      expect(authController.errorMessage, isNotNull);
    });

    test('Password Reset Request Success for registered email', () async {
      final reqSuccess = await authController
          .requestPasswordReset(AppStrings.demoSuperAdminEmail);
      expect(reqSuccess, true);
      expect(authController.successMessage,
          contains(AppStrings.demoSuperAdminEmail));
    });

    test('Password Reset Request Fails for unregistered email', () async {
      final reqSuccess =
          await authController.requestPasswordReset('notregistered@gmail.com');
      expect(reqSuccess, false);
      expect(authController.errorMessage,
          contains('No registered account found'));
    });

    test('Logout clears session', () async {
      await authController.login(
        email: AppStrings.demoSuperAdminEmail,
        password: AppStrings.demoSuperAdminPass,
      );
      expect(authController.isAuthenticated, true);

      await authController.logout();
      expect(authController.isAuthenticated, false);
      expect(authController.currentUser, null);
    });
  });
}
