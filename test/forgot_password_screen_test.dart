import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/widgets/gcrm_logo_widget.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/forgot_password_screen.dart';

void main() {
  group('ForgotPasswordScreen Widget Tests', () {
    late AuthController authController;

    setUp(() {
      authController = AuthController(authRepository: MockAuthService());
    });

    testWidgets('ForgotPasswordScreen renders logo, form, and sends reset email',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(authController: authController),
        ),
      );

      // Verify Logo & Header
      expect(find.byType(GcrmLogoWidget), findsOneWidget);
      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Registered Email Address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);

      // Enter email
      await tester.enterText(
        find.byType(TextField),
        'superadmin@gcrmone.com',
      );
      await tester.pump();

      // Tap Send Reset Link
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      // Verify Success State
      expect(find.text('Check Your Inbox'), findsOneWidget);
      expect(find.text('superadmin@gcrmone.com'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen displays error banner on unregistered email',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(authController: authController),
        ),
      );

      // Enter unregistered email
      await tester.enterText(
        find.byType(TextField),
        'nonexistent.user@randomgym.com',
      );
      await tester.pump();

      // Tap Send Reset Link
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      // Verify Error State
      expect(find.text('No registered account found with this email address (nonexistent.user@randomgym.com).'), findsOneWidget);
    });
  });
}
