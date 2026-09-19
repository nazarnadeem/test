import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/widgets/gcrm_logo_widget.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/models/user_model.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/super_admin_sign_up_screen.dart';

void main() {
  group('SuperAdminSignUpScreen Widget Tests', () {
    late AuthController authController;

    setUp(() {
      authController = AuthController(authRepository: MockAuthService());
    });

    testWidgets('SuperAdminSignUpScreen renders form fields and creates Super Admin',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminSignUpScreen(authController: authController),
        ),
      );

      // Verify Logo & Header
      expect(find.byType(GcrmLogoWidget), findsOneWidget);
      expect(find.text('Create Super Admin'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Super Admin Email'), findsOneWidget);
      expect(find.text('Master Password'), findsOneWidget);
      expect(find.text('Create Super Admin Account'), findsOneWidget);

      // Fill in registration form
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));

      // 0: Full Name
      await tester.enterText(textFields.at(0), 'Alexander Wright');
      // 1: Email
      await tester.enterText(textFields.at(1), 'alex.wright@gcrmone.com');
      // 2: Phone
      await tester.enterText(textFields.at(2), '+1 (800) 555-0199');
      // 3: Password
      await tester.enterText(textFields.at(3), 'MasterPassword123');
      // 4: Confirm Password
      await tester.enterText(textFields.at(4), 'MasterPassword123');
      // 5: Security PIN
      await tester.enterText(textFields.at(5), '884920');

      await tester.pump();

      // Ensure button is visible in scroll view & Submit Form
      final submitButton = find.text('Create Super Admin Account');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Check that user is authenticated as Super Admin
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentUser?.role, equals(UserRole.superAdmin));
      expect(authController.currentUser?.email, equals('alex.wright@gcrmone.com'));
    });
  });
}
