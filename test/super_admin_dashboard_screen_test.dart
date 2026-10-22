import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/constants/app_strings.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/models/platform_plan_model.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/super_admin_dashboard_screen.dart';

void main() {
  group('SuperAdminDashboardScreen Tests', () {
    late AuthController authController;

    setUp(() async {
      authController = AuthController(authRepository: MockAuthService());
      await authController.login(
        email: AppStrings.demoSuperAdminEmail,
        password: AppStrings.demoSuperAdminPass,
      );
      await authController.loadGymTenants();
      await authController.loadPlatformPlans();
    });

    testWidgets('SuperAdminDashboardScreen renders profile, metrics, and gyms',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminDashboardScreen(authController: authController),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Console Header
      expect(find.text('GCRM ONE'), findsOneWidget);
      expect(find.text('Super Admin Platform Console'), findsOneWidget);

      // Verify KPIs
      expect(find.text('Active Gyms'), findsOneWidget);
      expect(find.text('Platform Members'), findsOneWidget);
      expect(find.text('Monthly Volume'), findsOneWidget);
      expect(find.text('System Health'), findsOneWidget);

      // Verify Add Gym FAB
      expect(find.text('Add Gym'), findsOneWidget);
    });

    testWidgets('SuperAdminDashboardScreen switches to Plans tab and renders dynamic plans from backend',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminDashboardScreen(authController: authController),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Plans & Pricing tab
      final plansTab = find.textContaining('Plans & Pricing');
      expect(plansTab, findsOneWidget);
      await tester.tap(plansTab);
      await tester.pumpAndSettle();

      // Verify Empty State when no plans exist
      expect(find.text('No Subscription Plans in Firebase'), findsOneWidget);
      expect(find.text('Add Plan'), findsWidgets);

      // Now dynamically add a custom plan (as if received from Firestore)
      await authController.addPlatformPlan(
        const PlatformPlanModel(
          id: 'plan_dynamic_01',
          name: 'Dynamic Gold Tier',
          tagline: 'Dynamically created tier in Firestore',
          price: 79999.0,
          billingPeriod: 'year',
          features: ['All Features Included'],
        ),
      );

      await tester.pumpAndSettle();

      // Verify the dynamic plan is displayed
      expect(find.text('Dynamic Gold Tier'), findsOneWidget);
      expect(find.text('Dynamically created tier in Firestore'), findsOneWidget);
    });

    testWidgets('SuperAdminDashboardScreen opens Register Gym modal and registers gym with plan, validity dates, and admin account',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Add Gym FAB
      final addGymButton = find.text('Add Gym');
      expect(addGymButton, findsOneWidget);
      await tester.tap(addGymButton);
      await tester.pumpAndSettle();

      // Verify modal headers, branding, plan selection & date pickers
      expect(find.text('Register New Gym'), findsOneWidget);
      expect(find.text('1. GYM BRANDING & IDENTITY'), findsOneWidget);
      expect(find.text('Gym Logo Asset'), findsOneWidget);
      expect(find.text('Gym Primary Brand Color'), findsOneWidget);
      expect(find.text('2. SUBSCRIPTION PLAN & DURATION'), findsOneWidget);
      expect(find.text('Lifetime Free Gym'), findsOneWidget);
      expect(find.text('Plan Start Date'), findsOneWidget);
      expect(find.text('Plan Expiry Date'), findsOneWidget);
      expect(find.text('Presets:'), findsOneWidget);
      expect(find.text('3. GYM & OWNER DETAILS'), findsOneWidget);
      expect(find.text('4. GYM ADMIN ACCOUNT'), findsOneWidget);

      final submitBtn = find.text('Register Gym & Admin Account');
      expect(submitBtn, findsOneWidget);

      // Fill in all fields in the modal (index 0 is search bar in dashboard, index 1 is hex color)
      final formFields = find.byType(TextFormField);
      expect(formFields, findsNWidgets(10));

      await tester.enterText(formFields.at(2), 'Titan Gym Chicago');
      await tester.enterText(formFields.at(3), 'Alex Rodriguez');
      await tester.enterText(formFields.at(4), 'alex@titangym.com');
      await tester.enterText(formFields.at(5), '+1 (312) 555-0188');
      await tester.enterText(formFields.at(6), '100 Michigan Ave, Chicago, IL');
      await tester.enterText(formFields.at(7), 'Manager Bob');
      await tester.enterText(formFields.at(8), 'bob.admin@titangym.com');
      await tester.enterText(formFields.at(9), 'AdminTitan2026!');

      await tester.pump();

      // Scroll to submit button and click
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify new gym appears in dashboard list with plan details
      expect(find.text('Titan Gym Chicago'), findsOneWidget);
      expect(find.text('Owner: Alex Rodriguez'), findsOneWidget);
      expect(find.text('Admin: Manager Bob'), findsOneWidget);

      // Verify that the newly created Admin account can log in
      bool? loginSuccess;
      authController.login(
        email: 'bob.admin@titangym.com',
        password: 'AdminTitan2026!',
      ).then((res) => loginSuccess = res);
      await tester.pump(const Duration(milliseconds: 500));

      expect(loginSuccess, isTrue);
      expect(authController.currentUser?.fullName, 'Manager Bob');
      expect(authController.currentUser?.gymName, 'Titan Gym Chicago');
    });

    testWidgets('SuperAdminDashboardScreen registers a Lifetime Free Gym when checkbox is selected',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Add Gym FAB
      await tester.tap(find.text('Add Gym'));
      await tester.pumpAndSettle();

      // Tap on Lifetime Free Gym checkbox
      final lifetimeCheckboxFinder = find.text('Lifetime Free Gym');
      expect(lifetimeCheckboxFinder, findsOneWidget);
      await tester.tap(lifetimeCheckboxFinder);
      await tester.pumpAndSettle();

      // Verify lifetime active banner appears
      expect(find.textContaining('Lifetime Free Active'), findsOneWidget);

      final formFields = find.byType(TextFormField);
      await tester.enterText(formFields.at(2), 'Zenith Lifetime Gym');
      await tester.enterText(formFields.at(3), 'Sarah Connor');
      await tester.enterText(formFields.at(4), 'sarah@zenith.com');
      await tester.enterText(formFields.at(5), '+1 (555) 999-8888');
      await tester.enterText(formFields.at(6), '44 Sunset Blvd, Los Angeles, CA');
      await tester.enterText(formFields.at(7), 'Sarah Connor');
      await tester.enterText(formFields.at(8), 'sarah.admin@zenith.com');
      await tester.enterText(formFields.at(9), 'Zenith2026Secure!');
      await tester.pump();

      final submitBtn = find.text('Register Gym & Admin Account');
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify new lifetime gym is listed with lifetime badge
      expect(find.text('Zenith Lifetime Gym'), findsOneWidget);
      expect(find.textContaining('Lifetime Free Gym • Permanent Active Access'), findsOneWidget);

      // Verify tenant model in controller has isLifetimeFree = true
      final registeredGym = authController.gymTenants.firstWhere((g) => g.gymName == 'Zenith Lifetime Gym');
      expect(registeredGym.isLifetimeFree, isTrue);
      expect(registeredGym.isPlanActive, isTrue);
    });

    testWidgets('SuperAdmin can toggle Gym active/inactive status and edit gym details',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Verify MetroFitness Central Club is active by default
      expect(find.text('MetroFitness Central Club'), findsOneWidget);
      expect(find.text('Facility Active'), findsWidgets);

      // Tap on Edit Gym button
      final editBtn = find.text('Edit').first;
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify Edit Gym Sheet opened
      expect(find.text('Edit Gym Facility'), findsOneWidget);
      expect(find.text('Modify branding, validity, and active status'), findsOneWidget);
      expect(find.text('Gym Status: Active'), findsOneWidget);

      // Toggle Gym Status to Inactive in the modal
      final modalSwitch = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Switch),
      );
      expect(modalSwitch, findsOneWidget);
      await tester.tap(modalSwitch);
      await tester.pumpAndSettle();

      expect(find.text('Gym Status: Inactive / Suspended'), findsOneWidget);

      // Save changes
      final saveBtn = find.text('Save Gym Changes');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify Gym is now marked as Inactive
      final updatedGym = authController.gymTenants.firstWhere((g) => g.gymName == 'MetroFitness Central Club');
      expect(updatedGym.isActive, isFalse);
      expect(updatedGym.isSuspended, isTrue);
    });
  });
}
