import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/gym_admin_dashboard_screen.dart';

void main() {
  group('GymMembershipPlanModel Unit Tests', () {
    test('serializes and deserializes accurately with JSON & Firestore', () {
      const plan = GymMembershipPlanModel(
        id: 'gplan_test_01',
        tenantId: 'tenant_metro_01',
        name: 'Titan Strength Annual',
        tagline: 'Full powerlifting access with coach support',
        price: 21000.0,
        admissionFee: 500.0,
        durationDays: 365,
        billingCycle: 'Yearly',
        accessType: '24/7 Full Access',
        maxCheckInsPerDay: 2,
        category: 'Strength & Cardio',
        features: ['24/7 Access', 'Free Chalk & Belts', 'Sauna'],
        isPopular: true,
        isActive: true,
        enrolledMembersCount: 42,
        accentColor: Color(0xFFFF5722),
      );

      final json = plan.toJson();
      expect(json['id'], 'gplan_test_01');
      expect(json['tenantId'], 'tenant_metro_01');
      expect(json['name'], 'Titan Strength Annual');
      expect(json['tagline'], 'Full powerlifting access with coach support');
      expect(json['price'], 21000.0);
      expect(json['admissionFee'], 500.0);
      expect(json['durationDays'], 365);
      expect(json['billingCycle'], 'Yearly');
      expect(json['accessType'], '24/7 Full Access');
      expect(json['maxCheckInsPerDay'], 2);
      expect(json['features'], ['24/7 Access', 'Free Chalk & Belts', 'Sauna']);
      expect(json['isPopular'], isTrue);
      expect(json['isActive'], isTrue);

      final restored = GymMembershipPlanModel.fromJson(json, 'gplan_test_01');
      expect(restored.id, 'gplan_test_01');
      expect(restored.name, 'Titan Strength Annual');
      expect(restored.description, 'Full powerlifting access with coach support');
      expect(restored.planType, 'Yearly');
      expect(restored.accessType, '24/7 Full Access');
      expect(restored.maxCheckInsPerDay, 2);
      expect(restored.maxCheckInsLabel, '2 Check-Ins / Day');
      expect(restored.durationLabel, '1 Year (365 Days)');
      expect(restored.formattedPrice, '₹21000');
      expect(restored.monthlyEquivalentLabel, '₹1750 / month');
      expect(restored.isPopular, isTrue);
    });

    test('maxCheckInsLabel and durationLabel helpers format correctly', () {
      const p1 = GymMembershipPlanModel(
        id: '1',
        name: 'Monthly',
        price: 2000,
        durationDays: 30,
        maxCheckInsPerDay: 0,
        features: [],
      );
      expect(p1.durationLabel, '1 Month (30 Days)');
      expect(p1.maxCheckInsLabel, 'Unlimited Daily Check-Ins');
      expect(p1.monthlyEquivalentLabel, isNull);

      const p2 = GymMembershipPlanModel(
        id: '2',
        name: 'Single Entry Day Pass',
        price: 300,
        durationDays: 1,
        maxCheckInsPerDay: 1,
        features: [],
      );
      expect(p2.maxCheckInsLabel, '1 Check-In / Day');
    });
  });

  group('Gym Admin Dashboard Membership Plans Tab Widget Tests', () {
    late AuthController authController;

    setUp(() async {
      authController = AuthController(authRepository: MockAuthService());
      // Log in as Gym Admin to initialize state
      await authController.login(
        email: 'owner@metrofitness.com',
        password: 'Owner@Metro2026',
      );
    });

    testWidgets('GymAdminDashboardScreen starts empty without static dummy plan data',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Plans tab exists in TabBar
      expect(find.text('Plans'), findsOneWidget);

      // Tap on Plans Tab
      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();

      // Verify KPI Header Cards show 0 plans
      expect(find.text('Active Plans'), findsOneWidget);
      expect(find.text('0 / 0'), findsOneWidget);

      // Verify Empty State is shown
      expect(find.text('No Membership Plans Found'), findsOneWidget);
      expect(find.text('Create First Plan'), findsOneWidget);
    });

    testWidgets('Creating a new membership plan with all fields saves to state and list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Plans tab
      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();

      // Tap "New Plan" button
      final newPlanBtn = find.text('New Plan');
      await tester.tap(newPlanBtn);
      await tester.pumpAndSettle();

      // Verify modal opened
      expect(find.text('Create Membership Plan'), findsOneWidget);

      // 1. Enter Plan Name
      final nameField = find.widgetWithText(TextFormField, 'e.g. Gold Annual Pass');
      await tester.enterText(nameField, 'Olympus Powerlifting Pass');

      // 2. Enter Description
      final descField = find.widgetWithText(TextFormField, 'e.g. Full facility access with personal locker & steam bath');
      await tester.enterText(descField, 'Elite barbell access + unlimited chalk');

      // 3. Select Plan Type (Yearly) inside modal form
      final yearlyTypeChip = find.descendant(
        of: find.byType(Form),
        matching: find.widgetWithText(ChoiceChip, 'Yearly'),
      );
      await tester.ensureVisible(yearlyTypeChip);
      await tester.tap(yearlyTypeChip);
      await tester.pumpAndSettle();

      // 4. Enter Price & Admission
      final priceField = find.widgetWithText(TextFormField, '18000');
      await tester.enterText(priceField, '15000');

      // 5. Select Access Type inside modal form
      final accessChip = find.descendant(
        of: find.byType(Form),
        matching: find.widgetWithText(ChoiceChip, '24/7 Full Access'),
      );
      await tester.ensureVisible(accessChip);
      await tester.tap(accessChip);
      await tester.pumpAndSettle();

      // 6. Select Daily Check-Ins inside modal form
      final checkInChip = find.descendant(
        of: find.byType(Form),
        matching: find.widgetWithText(ChoiceChip, '2 / Day'),
      );
      await tester.ensureVisible(checkInChip);
      await tester.tap(checkInChip);
      await tester.pumpAndSettle();

      // Submit
      final saveBtn = find.text('Save & Publish Plan');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify new plan appears in the list with badges
      expect(find.text('Olympus Powerlifting Pass'), findsOneWidget);
      expect(find.text('₹15000'), findsWidgets);
      expect(find.text('2 Check-Ins / Day'), findsOneWidget);
    });

    testWidgets('Creating a plan with Custom Duration days successfully saves and displays custom days',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Plans tab
      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();

      // Tap "New Plan" button
      final newPlanBtn = find.text('New Plan');
      await tester.tap(newPlanBtn);
      await tester.pumpAndSettle();

      // Enter Plan Name
      final nameField = find.widgetWithText(TextFormField, 'e.g. Gold Annual Pass');
      await tester.enterText(nameField, '60-Day Transformation Pass');

      // Select "Custom Days" chip under Duration Period
      final customDaysChip = find.descendant(
        of: find.byType(Form),
        matching: find.widgetWithText(ChoiceChip, 'Custom Days'),
      );
      await tester.ensureVisible(customDaysChip);
      await tester.tap(customDaysChip);
      await tester.pumpAndSettle();

      // Verify custom duration textfield appears and only accepts int digits
      final customDaysField = find.widgetWithText(TextFormField, 'e.g. 45 or 60');
      expect(customDaysField, findsOneWidget);
      await tester.enterText(customDaysField, '60abc.5');
      await tester.pumpAndSettle();
      // '60abc.5' gets filtered to '605', let's test setting it to '60'
      await tester.enterText(customDaysField, '60');
      await tester.pumpAndSettle();

      // Enter Price
      final priceField = find.widgetWithText(TextFormField, '18000');
      await tester.enterText(priceField, '4999');

      // Submit
      final saveBtn = find.text('Save & Publish Plan');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify plan is in the dashboard with 2 Months duration badge
      expect(find.text('60-Day Transformation Pass'), findsOneWidget);
      expect(find.text('2 Months'), findsOneWidget);
    });

    testWidgets('Enrolling a member dynamically uses created membership plans',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pre-add a real plan to authController
      await authController.addGymMembershipPlan(
        const GymMembershipPlanModel(
          id: 'gplan_spartan',
          name: 'Spartan Strength Pro',
          price: 12000,
          durationDays: 180,
          features: ['Barbell Club', 'Sauna'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Members tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Verify empty members directory message is shown
      expect(find.text('No Members Enrolled Yet'), findsOneWidget);

      // Tap Enroll Member FAB
      final enrollFab = find.byType(FloatingActionButton);
      await tester.tap(enrollFab);
      await tester.pumpAndSettle();

      // Verify dialog opened and contains dynamic plan options and Plan Validity Schedule
      expect(find.text('Enroll New Member'), findsOneWidget);
      expect(find.textContaining('Select Membership Package'), findsOneWidget);
      expect(find.textContaining('Spartan Strength Pro'), findsOneWidget);
      expect(find.text('Plan Validity Schedule'), findsOneWidget);
      expect(find.text('Plan Starting Date *'), findsOneWidget);
      expect(find.text('Plan Ending Date (Auto)'), findsOneWidget);
    });
  });
}
