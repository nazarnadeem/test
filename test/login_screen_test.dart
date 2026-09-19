import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/constants/app_strings.dart';
import 'package:gcrm_one/core/widgets/custom_button.dart';
import 'package:gcrm_one/core/widgets/gcrm_logo_widget.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/gym_admin_dashboard_screen.dart';
import 'package:gcrm_one/features/auth/presentation/screens/login_screen.dart';
import 'package:gcrm_one/features/auth/presentation/screens/splash_screen.dart';
import 'package:gcrm_one/features/auth/presentation/screens/super_admin_dashboard_screen.dart';

void main() {
  group('LoginScreen & Flow Tests', () {
    late AuthController authController;

    setUp(() {
      authController = AuthController(authRepository: MockAuthService());
    });

    testWidgets('SplashScreen navigates directly to LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(authController: authController),
        ),
      );

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(GcrmLogoWidget), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('LoginScreen contains Logo, Email, Password, and Forgot Password',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authController: authController),
        ),
      );

      // Verify Brand Logo
      expect(find.byType(GcrmLogoWidget), findsOneWidget);

      // Verify Form fields & controls
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('Logging in as Super Admin navigates to SuperAdminDashboardScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authController: authController),
        ),
      );

      final formFields = find.byType(TextFormField);
      expect(formFields, findsNWidgets(2));

      await tester.enterText(formFields.at(0), AppStrings.demoSuperAdminEmail);
      await tester.enterText(formFields.at(1), AppStrings.demoSuperAdminPass);

      final signInBtn = find.byType(CustomButton);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SuperAdminDashboardScreen), findsOneWidget);
      expect(find.byType(GymAdminDashboardScreen), findsNothing);
      expect(find.text('Super Admin Platform Console'), findsOneWidget);
    });

    testWidgets('Logging in as Gym Admin navigates to GymAdminDashboardScreen instead of SuperAdminDashboardScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authController: authController),
        ),
      );

      final formFields = find.byType(TextFormField);
      expect(formFields, findsNWidgets(2));

      // Enter seeded Gym Admin / Owner credentials
      await tester.enterText(formFields.at(0), 'owner@metrofitness.com');
      await tester.enterText(formFields.at(1), 'Owner@Metro2026');

      final signInBtn = find.byType(CustomButton);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Verify GymAdminDashboardScreen is shown and NOT SuperAdminDashboardScreen
      expect(find.byType(GymAdminDashboardScreen), findsOneWidget);
      expect(find.byType(SuperAdminDashboardScreen), findsNothing);

      // Verify Gym Admin Header & Badges
      expect(find.text('GYM ADMIN'), findsOneWidget);
      expect(find.text('Manager: Marcus Vance'), findsOneWidget);

      // Verify Gym Admin Operational Tabs
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Facility'), findsOneWidget);

      // Verify Fast Check-In & Enroll Member Quick Operations
      expect(find.text('Fast Check-In'), findsOneWidget);
      expect(find.text('Enroll Member'), findsOneWidget);
    });

    testWidgets('When Gym is marked Inactive/Suspended, Gym Admin login navigates to GymInactiveScreen',
        (WidgetTester tester) async {
      // First, mark the gym as inactive
      await authController.loadGymTenants();
      await authController.toggleGymStatus(
        tenantId: 'tenant_metro_01',
        isActive: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authController: authController),
        ),
      );

      final formFields = find.byType(TextFormField);
      await tester.enterText(formFields.at(0), 'owner@metrofitness.com');
      await tester.enterText(formFields.at(1), 'Owner@Metro2026');

      final signInBtn = find.byType(CustomButton);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Verify GymInactiveScreen is displayed and NOT GymAdminDashboardScreen
      expect(find.text('Gym Access Suspended'), findsOneWidget);
      expect(find.text('FACILITY INACTIVE / SUSPENDED'), findsOneWidget);
      expect(find.textContaining('has been marked as inactive by the platform administrator'), findsOneWidget);
      expect(find.text('Contact Super Admin'), findsOneWidget);
      expect(find.text('Check Reactivation Status'), findsOneWidget);
      expect(find.text('Sign Out & Switch Account'), findsOneWidget);
    });
  });
}
