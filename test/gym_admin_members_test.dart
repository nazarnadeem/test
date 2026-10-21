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

    test('GymMemberModel.fromJson handles Firestore Timestamp, maps, and date strings correctly', () {
      final now = DateTime.now();
      final expiry = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));

      // Mock Firestore Timestamp object with .toDate()
      final mockTimestamp = _MockFirestoreTimestamp(expiry);

      final jsonWithTimestamp = {
        'id': 'mem_ts_1',
        'firstName': 'Existing',
        'lastName': 'Member',
        'startDate': mockTimestamp,
        'expiryDate': mockTimestamp,
        'isActive': true,
      };

      final member = GymMemberModel.fromJson(jsonWithTimestamp);
      expect(member.id, 'mem_ts_1');
      expect(member.expiryDate.year, expiry.year);
      expect(member.expiryDate.month, expiry.month);
      expect(member.expiryDate.day, expiry.day);
      expect(member.daysRemaining, 2);
      expect(member.isExpiringSoon, isTrue);
      expect(member.isExpired, isFalse);

      // JSON with map {_seconds: ...}
      final jsonWithMap = {
        'id': 'mem_map_1',
        'firstName': 'Map',
        'lastName': 'Member',
        'startDate': {'_seconds': (now.millisecondsSinceEpoch / 1000).toInt()},
        'expiryDate': {'_seconds': (expiry.millisecondsSinceEpoch / 1000).toInt()},
      };
      final memberMap = GymMemberModel.fromJson(jsonWithMap);
      expect(memberMap.daysRemaining, 2);
      expect(memberMap.isExpiringSoon, isTrue);
    });

    test('Calendar day-aware expiry helpers correctly classify today (0d), tomorrow (1d), and past dates', () {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 0, 0, 0); // Midnight today
      final tomorrowDate = DateTime(now.year, now.month, now.day, 0, 0, 0).add(const Duration(days: 1));
      final yesterdayDate = DateTime(now.year, now.month, now.day, 0, 0, 0).subtract(const Duration(days: 1));

      final todayMember = GymMemberModel(
        id: 'mem_today',
        firstName: 'Today',
        lastName: 'Member',
        phone: '1234567890',
        membershipPlan: 'Standard Pass',
        startDate: now.subtract(const Duration(days: 30)),
        expiryDate: todayDate,
      );

      final tomorrowMember = GymMemberModel(
        id: 'mem_tomorrow',
        firstName: 'Tomorrow',
        lastName: 'Member',
        phone: '1234567891',
        membershipPlan: 'Standard Pass',
        startDate: now.subtract(const Duration(days: 30)),
        expiryDate: tomorrowDate,
      );

      final yesterdayMember = GymMemberModel(
        id: 'mem_yesterday',
        firstName: 'Yesterday',
        lastName: 'Member',
        phone: '1234567892',
        membershipPlan: 'Standard Pass',
        startDate: now.subtract(const Duration(days: 30)),
        expiryDate: yesterdayDate,
      );

      // Expiring today (0d)
      expect(todayMember.daysRemaining, 0);
      expect(todayMember.daysUntilExpiry, 0);
      expect(todayMember.isExpiringSoon, isTrue);
      expect(todayMember.isExpired, isFalse);

      // Expiring tomorrow (1d)
      expect(tomorrowMember.daysRemaining, 1);
      expect(tomorrowMember.daysUntilExpiry, 1);
      expect(tomorrowMember.isExpiringSoon, isTrue);
      expect(tomorrowMember.isExpired, isFalse);

      // Expired yesterday (-1d)
      expect(yesterdayMember.daysRemaining, 0);
      expect(yesterdayMember.daysUntilExpiry, -1);
      expect(yesterdayMember.isExpiringSoon, isFalse);
      expect(yesterdayMember.isExpired, isTrue);
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
      await tester.tap(find.byType(FloatingActionButton).last);
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

      // Verify Member Card appears on dashboard
      expect(find.text('Dominic Toretto'), findsOneWidget);
      expect(find.textContaining('Titan Pro Annual'), findsWidgets);

      // Tap on member card to expand and reveal full details & actions
      await tester.tap(find.text('Dominic Toretto'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1327 Ocean Ave'), findsOneWidget);
      expect(find.textContaining('92.5 kg'), findsOneWidget);
      expect(find.textContaining('182 cm'), findsOneWidget);
      expect(find.textContaining('Letty Ortiz'), findsOneWidget);

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
      await tester.tap(find.byType(FloatingActionButton).last);
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
      expect(find.text('Lifetime'), findsOneWidget);
      expect(find.text('VIP Lifetime Free'), findsOneWidget);
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
      await tester.tap(find.byType(FloatingActionButton).last);
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

      // Tap to expand card
      await tester.tap(find.text('Clark Kent'));
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
      await tester.tap(find.byType(FloatingActionButton).last);
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

      // Tap to expand card
      await tester.tap(find.text('Diana Prince'));
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

    testWidgets('Members cannot be deleted; can be toggled inactive and active instead', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      final activeMember = GymMemberModel(
        id: 'mem_inact_test',
        tenantId: 'tenant_metro_01',
        firstName: 'Clark',
        lastName: 'Kent',
        phone: '+91 99000 11223',
        email: 'clark@dailyplanet.com',
        membershipPlan: 'Pro Plan',
        startDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 60)),
        isActive: true,
      );
      await authController.addGymMember(activeMember);

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Members tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Filter to Clark Kent
      final searchField = find.widgetWithText(TextFormField, 'Search members by name, phone, or plan...');
      await tester.enterText(searchField, 'Clark');
      await tester.pumpAndSettle();

      expect(find.text('Clark Kent'), findsOneWidget);

      // Tap to expand card
      await tester.tap(find.text('Clark Kent'));
      await tester.pumpAndSettle();

      // Verify there is NO delete button for members
      expect(find.widgetWithIcon(IconButton, Icons.delete_outline_rounded), findsNothing);

      // Verify 'Set Inactive' button exists
      final setInactiveBtn = find.text('Set Inactive');
      expect(setInactiveBtn, findsOneWidget);

      // Tap 'Set Inactive'
      await tester.tap(setInactiveBtn);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Set Member Inactive?'), findsOneWidget);
      expect(find.textContaining('Members cannot be deleted'), findsOneWidget);

      // Confirm Set Inactive
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Set Inactive');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify member is now inactive in AuthController
      final memberInController = authController.members.firstWhere((m) => m.id == 'mem_inact_test');
      expect(memberInController.isActive, false);

      // Verify status pill shows 'Inactive' (plus the 'Inactive' filter chip)
      expect(find.text('Inactive'), findsNWidgets(2));

      // Verify button changed to 'Set Active'
      expect(find.text('Set Active'), findsOneWidget);

      // Test Inactive filter tab
      await tester.tap(find.widgetWithText(ChoiceChip, 'Inactive'));
      await tester.pumpAndSettle();
      expect(find.text('Clark Kent'), findsOneWidget);

      // Test Active filter tab (Clark Kent should not be shown)
      await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
      await tester.pumpAndSettle();
      expect(find.text('Clark Kent'), findsNothing);

      // Go back to Inactive and reactivate
      await tester.tap(find.widgetWithText(ChoiceChip, 'Inactive'));
      await tester.pumpAndSettle();
      expect(find.text('Clark Kent'), findsOneWidget);

      // Tap to expand card
      await tester.tap(find.text('Clark Kent'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Active'));
      await tester.pumpAndSettle();

      expect(find.text('Activate Member?'), findsOneWidget);
      final activateConfirmBtn = find.widgetWithText(ElevatedButton, 'Activate');
      await tester.tap(activateConfirmBtn);
      await tester.pumpAndSettle();

      // Verify member is now active again
      expect(authController.members.firstWhere((m) => m.id == 'mem_inact_test').isActive, true);
    });

    testWidgets('While adding members, batch dropdown only displays batches that haven\'t crossed member limit',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pre-seed two batches:
      // 1. Full batch (limit: 2, enrolled: 2) -> must be hidden
      await authController.addGymBatch(
        const GymBatchModel(
          id: 'btch_full_limit',
          name: 'Full Capacity Batch',
          time: '06:00 AM - 07:00 AM',
          limit: 2,
          memberIds: ['m1', 'm2'],
          memberNames: ['Member 1', 'Member 2'],
        ),
      );

      // 2. Available batch (limit: 10, enrolled: 1) -> must be shown
      await authController.addGymBatch(
        const GymBatchModel(
          id: 'btch_available_slots',
          name: 'Available Slots Batch',
          time: '07:00 AM - 08:00 AM',
          limit: 10,
          memberIds: ['m3'],
          memberNames: ['Member 3'],
        ),
      );

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
      await tester.tap(find.byType(FloatingActionButton).last);
      await tester.pumpAndSettle();

      expect(find.text('Enroll New Member'), findsOneWidget);

      // Find the batch dropdown
      final dropdownFinder = find.byType(DropdownButton<String?>);
      expect(dropdownFinder, findsWidgets);

      // Tap the Assigned Batch dropdown
      await tester.tap(dropdownFinder.last);
      await tester.pumpAndSettle();

      // The available batch must be present
      expect(find.text('Available Slots Batch (07:00 AM - 08:00 AM)'), findsWidgets);

      // The full batch that crossed limit must NOT be present
      expect(find.text('Full Capacity Batch (06:00 AM - 07:00 AM)'), findsNothing);

      // Select 'Available Slots Batch'
      await tester.tap(find.text('Available Slots Batch (07:00 AM - 08:00 AM)').last);
      await tester.pumpAndSettle();

      // Verify selected batch is shown
      expect(find.text('Available Slots Batch (07:00 AM - 08:00 AM)'), findsOneWidget);
    });

    testWidgets('Expiring filter shows 1D, 3D, and 7D sub-filters and filters members accordingly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();

      // Member 1: Expires in ~1 day (hours: 20 -> difference.inDays == 0 or 1, daysRemaining <= 1)
      await authController.addGymMember(
        GymMemberModel(
          id: 'mem_exp_1d',
          firstName: 'Alex',
          lastName: 'OneDay',
          phone: '+91 90000 00001',
          membershipPlan: 'Standard Pass',
          startDate: now.subtract(const Duration(days: 30)),
          expiryDate: now.add(const Duration(hours: 20)),
          isActive: true,
        ),
      );

      // Member 2: Expires in ~3 days (days: 2, hours: 12 -> daysRemaining == 2, so <= 3)
      await authController.addGymMember(
        GymMemberModel(
          id: 'mem_exp_3d',
          firstName: 'Brian',
          lastName: 'ThreeDays',
          phone: '+91 90000 00002',
          membershipPlan: 'Standard Pass',
          startDate: now.subtract(const Duration(days: 30)),
          expiryDate: now.add(const Duration(days: 2, hours: 12)),
          isActive: true,
        ),
      );

      // Member 3: Expires in ~6 days (days: 5, hours: 12 -> daysRemaining == 5, so <= 7)
      await authController.addGymMember(
        GymMemberModel(
          id: 'mem_exp_7d',
          firstName: 'Chloe',
          lastName: 'SevenDays',
          phone: '+91 90000 00003',
          membershipPlan: 'Standard Pass',
          startDate: now.subtract(const Duration(days: 30)),
          expiryDate: now.add(const Duration(days: 5, hours: 12)),
          isActive: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Members Tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Initially on 'All' filter -> sub-filters (1D, 3D, 7D) must not be visible
      expect(find.text('1D'), findsNothing);
      expect(find.text('3D'), findsNothing);
      expect(find.text('7D'), findsNothing);

      // Tap 'Expiring' filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expiring'));
      await tester.pumpAndSettle();

      // Sub-filters should now be visible below the main filters
      expect(find.textContaining('Expiring in'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '1D'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '3D'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '7D'), findsOneWidget);

      // By default, '7D' is selected -> all 3 expiring members should be visible
      expect(find.text('Alex OneDay'), findsOneWidget);
      expect(find.text('Brian ThreeDays'), findsOneWidget);
      expect(find.text('Chloe SevenDays'), findsOneWidget);

      // Select '3D' sub-filter
      await tester.tap(find.widgetWithText(ChoiceChip, '3D'));
      await tester.pumpAndSettle();

      // 1D and 3D members should be visible, 7D member filtered out
      expect(find.text('Alex OneDay'), findsOneWidget);
      expect(find.text('Brian ThreeDays'), findsOneWidget);
      expect(find.text('Chloe SevenDays'), findsNothing);

      // Select '1D' sub-filter
      await tester.tap(find.widgetWithText(ChoiceChip, '1D'));
      await tester.pumpAndSettle();

      // Only 1D member should be visible
      expect(find.text('Alex OneDay'), findsOneWidget);
      expect(find.text('Brian ThreeDays'), findsNothing);
      expect(find.text('Chloe SevenDays'), findsNothing);

      // Switch back to 'All' filter
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();

      // Sub-filters should be hidden again
      expect(find.text('1D'), findsNothing);
      expect(find.text('3D'), findsNothing);
      expect(find.text('7D'), findsNothing);

      // All members should be visible
      expect(find.text('Alex OneDay'), findsOneWidget);
      expect(find.text('Brian ThreeDays'), findsOneWidget);
      expect(find.text('Chloe SevenDays'), findsOneWidget);
    });

    testWidgets('Member card renders without RenderFlex overflow on standard mobile screens',
        (WidgetTester tester) async {
      // Standard mobile phone viewport: 390x844 (iPhone 12/13/14/15)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Enroll a member so a card is displayed
      await authController.addGymMember(
        GymMemberModel(
          id: 'mem_marcus',
          firstName: 'Marcus',
          lastName: 'Aurelius',
          phone: '+91 99999 88888',
          membershipPlan: 'Titan Pro Annual',
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          expiryDate: DateTime.now().add(const Duration(days: 350)),
          isActive: true,
          totalCheckIns: 5,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(
            authController: authController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure members tab is visible
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Tap member card to expand it
      await tester.tap(find.text('Marcus Aurelius'));
      await tester.pumpAndSettle();

      // Verify buttons exist and no overflow exceptions were logged
      expect(find.text('Check In'), findsWidgets);
      expect(find.text('Edit'), findsWidgets);
      expect(find.text('Set Inactive'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Member items are collapsible by default and only one expands at a time',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed Member A and Member B
      await authController.addGymMember(
        GymMemberModel(
          id: 'mem_alpha',
          firstName: 'Alpha',
          lastName: 'User',
          phone: '+91 11111 22222',
          membershipPlan: 'Standard Pass',
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          expiryDate: DateTime.now().add(const Duration(days: 20)),
          isActive: true,
          address: 'Alpha Secret Base 42',
        ),
      );

      await authController.addGymMember(
        GymMemberModel(
          id: 'mem_beta',
          firstName: 'Beta',
          lastName: 'User',
          phone: '+91 33333 44444',
          membershipPlan: 'Standard Pass',
          startDate: DateTime.now().subtract(const Duration(days: 5)),
          expiryDate: DateTime.now().add(const Duration(days: 25)),
          isActive: true,
          address: 'Beta Secret Base 99',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // 1. By default, both members are collapsed:
      // Important summary info is visible
      expect(find.text('Alpha User'), findsOneWidget);
      expect(find.text('Beta User'), findsOneWidget);
      expect(find.text('+91 11111 22222'), findsOneWidget);
      expect(find.text('+91 33333 44444'), findsOneWidget);

      // Expanded details (like addresses and action buttons) must NOT be visible yet
      expect(find.text('Alpha Secret Base 42'), findsNothing);
      expect(find.text('Beta Secret Base 99'), findsNothing);
      expect(find.text('Check In'), findsNothing);

      // 2. Expand Member Alpha
      await tester.tap(find.text('Alpha User'));
      await tester.pumpAndSettle();

      // Member Alpha is now expanded
      expect(find.text('Alpha Secret Base 42'), findsOneWidget);
      expect(find.text('Check In'), findsOneWidget);
      // Member Beta remains collapsed
      expect(find.text('Beta Secret Base 99'), findsNothing);

      // 3. Tap Member Beta: Only ONE expands at a time (accordion)
      await tester.tap(find.text('Beta User'));
      await tester.pumpAndSettle();

      // Member Beta is now expanded
      expect(find.text('Beta Secret Base 99'), findsOneWidget);
      // Member Alpha was automatically collapsed!
      expect(find.text('Alpha Secret Base 42'), findsNothing);

      // 4. Tap Member Beta again: collapses Beta
      await tester.tap(find.text('Beta User'));
      await tester.pumpAndSettle();

      // Both are collapsed again
      expect(find.text('Beta Secret Base 99'), findsNothing);
      expect(find.text('Alpha Secret Base 42'), findsNothing);
      expect(find.text('Check In'), findsNothing);
    });

    testWidgets('Plan start date cannot be in the future when adding or editing member',
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

      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Open Member Enrollment Modal
      await tester.tap(find.byType(FloatingActionButton).last);
      await tester.pumpAndSettle();

      // Tap on starting date to open date picker
      final datePickerButton = find.byIcon(Icons.edit_calendar_rounded);
      expect(datePickerButton, findsOneWidget);
      await tester.ensureVisible(datePickerButton);
      await tester.tap(datePickerButton);
      await tester.pumpAndSettle();

      // Date picker help text should show up to today restriction
      expect(find.text('SELECT PLAN START DATE (UP TO TODAY)'), findsOneWidget);

      // Close date picker
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}

class _MockFirestoreTimestamp {
  final DateTime _date;
  _MockFirestoreTimestamp(this._date);
  DateTime toDate() => _date;
}
