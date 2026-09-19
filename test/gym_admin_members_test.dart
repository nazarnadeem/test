import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/utils/image_optimizer.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/gym_admin_dashboard_screen.dart';

void main() {
  group('GymMemberModel Unit Tests', () {
    test('serializes and deserializes accurately with all member fields, physical metrics and goal', () {
      final dob = DateTime(1996, 6, 15);
      final start = DateTime(2026, 1, 1);
      final expiry = DateTime(2027, 1, 1);

      final member = GymMemberModel(
        id: 'mem_test_100',
        tenantId: 'tenant_metro_01',
        firstName: 'Marcus',
        lastName: 'Sterling',
        photoUrl: 'https://firebasestorage.googleapis.com/sample.jpg',
        gender: 'Male',
        dateOfBirth: dob,
        phone: '+91 98765 43210',
        email: 'marcus.s@gmail.com',
        address: '742 Evergreen Terrace, Springfield',
        weight: 80.0,
        height: 180.0,
        goal: 'Muscle Building',
        emergencyContactName: 'Elena Sterling',
        emergencyPhone: '+91 91234 56789',
        emergencyContactRelation: 'Spouse',
        membershipPlanId: 'gplan_gold',
        membershipPlan: 'Gold Annual Pass',
        isLifetimeFree: false,
        startDate: start,
        expiryDate: expiry,
        isActive: true,
        totalCheckIns: 12,
      );

      expect(member.fullName, 'Marcus Sterling');
      expect(member.age, isNotNull);
      expect(member.formattedDob, '15/06/1996');
      expect(member.hasEmergencyContact, isTrue);
      expect(member.weight, 80.0);
      expect(member.height, 180.0);
      expect(member.formattedWeight, '80 kg');
      expect(member.formattedHeight, '180 cm');
      expect(member.goal, 'Muscle Building');
      expect(member.formattedGoal, 'Muscle Building');
      expect(member.bmi, closeTo(24.69, 0.05));
      expect(member.formattedBmi, '24.7');

      final json = member.toJson();
      expect(json['firstName'], 'Marcus');
      expect(json['lastName'], 'Sterling');
      expect(json['gender'], 'Male');
      expect(json['weight'], 80.0);
      expect(json['height'], 180.0);
      expect(json['goal'], 'Muscle Building');
      expect(json['isLifetimeFree'], isFalse);
      expect(json['photoUrl'], 'https://firebasestorage.googleapis.com/sample.jpg');
      expect(json['emergencyContactName'], 'Elena Sterling');

      final restored = GymMemberModel.fromJson(json, 'mem_test_100');
      expect(restored.fullName, 'Marcus Sterling');
      expect(restored.gender, 'Male');
      expect(restored.formattedDob, '15/06/1996');
      expect(restored.weight, 80.0);
      expect(restored.height, 180.0);
      expect(restored.goal, 'Muscle Building');
      expect(restored.isLifetimeFree, isFalse);
    });

    test('serializes and deserializes discountType and discountValue with helpers', () {
      final memberFixed = GymMemberModel(
        id: 'mem_disc_1',
        firstName: 'Diana',
        lastName: 'Prince',
        phone: '+91 91111 22222',
        membershipPlan: 'Gold Annual',
        discountType: 'Fixed',
        discountValue: 500.0,
        startDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );

      expect(memberFixed.hasDiscount, isTrue);
      expect(memberFixed.formattedDiscount, '₹500 OFF');
      expect(memberFixed.calculateDiscountAmount(2500), 500.0);
      expect(memberFixed.calculateFinalPrice(2500), 2000.0);

      final jsonFixed = memberFixed.toJson();
      expect(jsonFixed['discountType'], 'Fixed');
      expect(jsonFixed['discountValue'], 500.0);

      final restoredFixed = GymMemberModel.fromJson(jsonFixed);
      expect(restoredFixed.discountType, 'Fixed');
      expect(restoredFixed.discountValue, 500.0);
      expect(restoredFixed.formattedDiscount, '₹500 OFF');

      final memberPercent = GymMemberModel(
        id: 'mem_disc_2',
        firstName: 'Arthur',
        lastName: 'Curry',
        phone: '+91 93333 44444',
        membershipPlan: 'Silver Monthly',
        discountType: 'Percentage',
        discountValue: 10.0,
        startDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );

      expect(memberPercent.hasDiscount, isTrue);
      expect(memberPercent.formattedDiscount, '10% OFF');
      expect(memberPercent.calculateDiscountAmount(1500), 150.0);
      expect(memberPercent.calculateFinalPrice(1500), 1350.0);

      final memberNoDisc = GymMemberModel(
        id: 'mem_disc_3',
        firstName: 'Clark',
        lastName: 'Kent',
        phone: '+91 95555 66666',
        membershipPlan: 'Bronze Daily',
        startDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );

      expect(memberNoDisc.hasDiscount, isFalse);
      expect(memberNoDisc.formattedDiscount, 'No Discount');
      expect(memberNoDisc.calculateDiscountAmount(1000), 0.0);
      expect(memberNoDisc.calculateFinalPrice(1000), 1000.0);
    });

    test('isLifetimeFree member never expires and has lifetime helpers', () {
      final member = GymMemberModel(
        id: 'mem_lifetime_01',
        firstName: 'Bruce',
        lastName: 'Wayne',
        phone: '+91 99999 88888',
        membershipPlan: 'Lifetime Free',
        isLifetimeFree: true,
        startDate: DateTime.now(),
        expiryDate: DateTime(2099, 12, 31),
      );

      expect(member.isLifetimeFree, isTrue);
      expect(member.isExpired, isFalse);
      expect(member.isExpiringSoon, isFalse);
      expect(member.daysRemaining, 99999);
      expect(member.formattedExpiry, 'Never (Lifetime Free)');
    });

    test('uploadGymMemberPhoto optimizes image before storing', () async {
      final mockAuth = MockAuthService();
      final sampleBytes = ImageOptimizer.createSampleAvatarBytes();
      final opt = await ImageOptimizer.optimizeImage(sampleBytes, maxDimension: 512, quality: 80);

      expect(opt.width, lessThanOrEqualTo(512));
      expect(opt.format, 'jpg');

      final url = await mockAuth.uploadGymMemberPhoto(
        tenantId: 'tenant_metro_01',
        memberId: 'mem_opt_1',
        imageBytes: opt.bytes,
      );

      expect(url, isNotNull);
      expect(url!.isNotEmpty, isTrue);
    });
  });

  group('Gym Admin Member Enrollment Widget Tests', () {
    late AuthController authController;

    setUp(() async {
      authController = AuthController(authRepository: MockAuthService());
      await authController.login(
        email: 'owner@metrofitness.com',
        password: 'Owner@Metro2026',
      );

      // Pre-seed an active membership plan
      await authController.addGymMembershipPlan(
        const GymMembershipPlanModel(
          id: 'gplan_titan',
          name: 'Titan Pro Annual',
          price: 18000,
          durationDays: 365,
          category: 'VIP All-Access',
          accessType: '24/7 Full Access',
          features: ['All Gym Access', 'Sauna', 'Personal Locker'],
        ),
      );
    });

    testWidgets('Enroll regular member with photo, DD/MM/YYYY DOB, emergency contact and package',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Members Tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      expect(find.text('No Members Enrolled Yet'), findsOneWidget);

      // Open Member Enrollment Modal
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Enroll New Member'), findsOneWidget);
      expect(find.text('Demo Photo'), findsOneWidget);
      expect(find.text('Is Lifetime Free Member'), findsOneWidget);
      expect(find.text('DD/MM/YYYY'), findsOneWidget);

      // 1. Click Demo Photo to optimize profile picture
      await tester.tap(find.text('Demo Photo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Optimized:'), findsOneWidget);

      // 2. Fill First Name & Last Name
      final firstNameField = find.widgetWithText(TextFormField, 'e.g. Jordan');
      await tester.enterText(firstNameField, 'Dominic');

      final lastNameField = find.widgetWithText(TextFormField, 'e.g. Hayes');
      await tester.enterText(lastNameField, 'Toretto');

      // 3. Fill Phone Number, Email, Address
      final phoneField = find.widgetWithText(TextFormField, '+91 98765 43210');
      await tester.enterText(phoneField, '+91 98765 43210');

      final addressField = find.widgetWithText(TextFormField, 'Street, Apt/Suite, City, State, ZIP');
      await tester.enterText(addressField, '1327 Ocean Ave, Los Angeles, CA');

      // 4. Fill Physical Metrics & Fitness Goal
      final weightField = find.widgetWithText(TextFormField, 'e.g. 75');
      await tester.ensureVisible(weightField);
      await tester.enterText(weightField, '92.5');

      final heightField = find.widgetWithText(TextFormField, 'e.g. 178');
      await tester.ensureVisible(heightField);
      await tester.enterText(heightField, '182');

      // 5. Fill Emergency Contact details
      final emgNameField = find.widgetWithText(TextFormField, 'e.g. Sarah Hayes');
      await tester.ensureVisible(emgNameField);
      await tester.enterText(emgNameField, 'Letty Ortiz');

      final emgPhoneField = find.widgetWithText(TextFormField, '+91 91234 56789');
      await tester.ensureVisible(emgPhoneField);
      await tester.enterText(emgPhoneField, '+91 91234 56789');

      // 6. Submit Enrollment
      final enrollBtn = find.text('Enroll & Issue Member Pass');
      await tester.ensureVisible(enrollBtn);
      await tester.tap(enrollBtn);
      await tester.pumpAndSettle();

      // Verify Member Card appears on dashboard with Goal, Weight, Height and BMI
      expect(find.text('Dominic Toretto'), findsOneWidget);
      expect(find.textContaining('1327 Ocean Ave'), findsOneWidget);
      expect(find.textContaining('92.5 kg'), findsOneWidget);
      expect(find.textContaining('182 cm'), findsOneWidget);
      expect(find.textContaining('Letty Ortiz'), findsOneWidget);
      expect(find.textContaining('Titan Pro Annual'), findsWidgets);

      // Verify Check In button on Member Card works
      final checkInBtn = find.text('Check In');
      expect(checkInBtn, findsOneWidget);
      await tester.tap(checkInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Total Check-Ins: 1'), findsOneWidget);
    });

    testWidgets('Enroll Lifetime Free Member hides package selection and never expires',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Members Tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Open Member Enrollment Modal
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Toggle 'Is Lifetime Free Member'
      final lifetimeCheckbox = find.byType(Checkbox);
      await tester.tap(lifetimeCheckbox);
      await tester.pumpAndSettle();

      // Verify package selector is replaced by lifetime banner
      expect(find.textContaining('Lifetime Free Member active'), findsOneWidget);

      // Fill Name and Phone
      final firstNameField = find.widgetWithText(TextFormField, 'e.g. Jordan');
      await tester.enterText(firstNameField, 'Bruce');

      final lastNameField = find.widgetWithText(TextFormField, 'e.g. Hayes');
      await tester.enterText(lastNameField, 'Wayne');

      final phoneField = find.widgetWithText(TextFormField, '+91 98765 43210');
      await tester.enterText(phoneField, '+91 99999 88888');

      // Submit Enrollment
      final enrollBtn = find.text('Enroll & Issue Member Pass');
      await tester.ensureVisible(enrollBtn);
      await tester.tap(enrollBtn);
      await tester.pumpAndSettle();

      // Verify Member Card displays Lifetime Free badge and VIP Lifetime Pass
      expect(find.text('Bruce Wayne'), findsOneWidget);
      expect(find.text('♾️ Lifetime Free'), findsOneWidget);
      expect(find.text('Plan: VIP Lifetime Free'), findsOneWidget);
    });

    testWidgets('Edit member modal opens pre-filled and updates member profile successfully',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Members Tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Enroll an initial member
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final firstNameField = find.widgetWithText(TextFormField, 'e.g. Jordan');
      await tester.enterText(firstNameField, 'Clark');

      final lastNameField = find.widgetWithText(TextFormField, 'e.g. Hayes');
      await tester.enterText(lastNameField, 'Kent');

      final phoneField = find.widgetWithText(TextFormField, '+91 98765 43210');
      await tester.enterText(phoneField, '+91 88888 77777');

      final weightField = find.widgetWithText(TextFormField, 'e.g. 75');
      await tester.ensureVisible(weightField);
      await tester.enterText(weightField, '100');

      final heightField = find.widgetWithText(TextFormField, 'e.g. 178');
      await tester.ensureVisible(heightField);
      await tester.enterText(heightField, '190');

      final enrollBtn = find.text('Enroll & Issue Member Pass');
      await tester.ensureVisible(enrollBtn);
      await tester.tap(enrollBtn);
      await tester.pumpAndSettle();

      // Search for Clark Kent to focus directly on Clark's card
      final searchField = find.widgetWithText(TextFormField, 'Search members by name, phone, or plan...');
      await tester.enterText(searchField, 'Clark');
      await tester.pumpAndSettle();

      // Tap Edit button on member card
      final editBtn = find.text('Edit');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify edit modal opened with pre-filled details
      expect(find.text('Edit Member Profile'), findsOneWidget);

      final editFirstNameField = find.widgetWithText(TextFormField, 'e.g. Jordan').last;
      expect((tester.widget(editFirstNameField) as TextFormField).controller?.text, 'Clark');

      final editLastNameField = find.widgetWithText(TextFormField, 'e.g. Hayes').last;
      expect((tester.widget(editLastNameField) as TextFormField).controller?.text, 'Kent');

      final editPhoneField = find.widgetWithText(TextFormField, '+91 98765 43210').last;
      expect((tester.widget(editPhoneField) as TextFormField).controller?.text, '+91 88888 77777');

      final editWeightField = find.widgetWithText(TextFormField, 'e.g. 75').last;
      expect((tester.widget(editWeightField) as TextFormField).controller?.text, '100');

      final editHeightField = find.widgetWithText(TextFormField, 'e.g. 178').last;
      expect((tester.widget(editHeightField) as TextFormField).controller?.text, '190');

      // Modify last name, address, and weight
      await tester.enterText(editLastNameField, 'Kal-El');

      final editAddressField = find.widgetWithText(TextFormField, 'Street, Apt/Suite, City, State, ZIP').last;
      await tester.enterText(editAddressField, '344 Clinton St, Metropolis');

      await tester.enterText(editWeightField, '105');

      // Save changes
      final saveBtn = find.text('Save Member Changes');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify dashboard shows updated details
      expect(find.text('Clark Kal-El'), findsOneWidget);
      expect(find.textContaining('344 Clinton St'), findsOneWidget);
      expect(find.textContaining('105 kg'), findsOneWidget);
    });

    testWidgets('Photo upload works seamlessly for both Member Creation and Member Edit', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Go to Members Tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // 2. Open Add Member Dialog
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Tap 'Demo Photo' button in Add Member modal
      final demoPhotoBtn = find.text('Demo Photo');
      expect(demoPhotoBtn, findsOneWidget);
      await tester.tap(demoPhotoBtn);
      await tester.pumpAndSettle();

      // Verify optimization indicator appeared
      expect(find.textContaining('Optimized'), findsOneWidget);

      final firstNameField = find.widgetWithText(TextFormField, 'e.g. Jordan');
      await tester.enterText(firstNameField, 'Diana');

      final lastNameField = find.widgetWithText(TextFormField, 'e.g. Hayes');
      await tester.enterText(lastNameField, 'Prince');

      final phoneField = find.widgetWithText(TextFormField, '+91 98765 43210');
      await tester.enterText(phoneField, '+91 91111 22222');

      final enrollBtn = find.text('Enroll & Issue Member Pass');
      await tester.ensureVisible(enrollBtn);
      await tester.tap(enrollBtn);
      await tester.pumpAndSettle();

      // Verify created member has photoUrl
      final createdMember = authController.members.firstWhere((m) => m.firstName == 'Diana');
      expect(createdMember.photoUrl, isNotNull);
      expect(createdMember.photoUrl!.isNotEmpty, isTrue);

      // 3. Edit Diana Prince and update her photo
      final searchField = find.widgetWithText(TextFormField, 'Search members by name, phone, or plan...');
      await tester.enterText(searchField, 'Diana');
      await tester.pumpAndSettle();

      final editBtn = find.text('Edit');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Member Profile'), findsOneWidget);

      // Tap 'Demo Photo' button in Edit Member modal
      final editDemoPhotoBtn = find.text('Demo Photo');
      expect(editDemoPhotoBtn, findsOneWidget);
      await tester.tap(editDemoPhotoBtn);
      await tester.pumpAndSettle();

      // Save edited member changes
      final saveBtn = find.text('Save Member Changes');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify member profile was updated with valid photoUrl
      final updatedMember = authController.members.firstWhere((m) => m.firstName == 'Diana');
      expect(updatedMember.photoUrl, isNotNull);
      expect(updatedMember.photoUrl!.isNotEmpty, isTrue);
    });
  });
}
