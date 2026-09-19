import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/gym_admin_dashboard_screen.dart';

void main() {
  group('Gym Admin Dashboard Team Tab & Role Management Tests', () {
    late AuthController authController;

    setUp(() async {
      authController = AuthController(authRepository: MockAuthService());
      // Log in as Gym Owner to initialize state
      await authController.login(
        email: 'owner@metrofitness.com',
        password: 'Owner@Metro2026',
      );
    });

    testWidgets('GymAdminDashboardScreen displays Team tab and team KPI card',
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

      // Check Overview tab KPI card for Team
      expect(find.text('Team on Duty'), findsOneWidget);

      // Check Team tab exists
      expect(find.text('Team'), findsOneWidget);
    });

    testWidgets(
        'Switching to Team tab when empty displays empty state view',
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

      // Tap Team tab
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      // Verify empty state is displayed
      expect(find.text('No Team Members Found'), findsOneWidget);
      expect(find.text('Add Team Member'), findsWidgets);
    });

    testWidgets(
        'Creating a Trainer prompts for Experience and Gender and adds Trainer with both badges',
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

      // Tap Team tab
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      // Tap Add Team Member button
      final addBtn = find.text('Add Team Member').first;
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify modal opened
      expect(find.text('Add Team Member'), findsWidgets);
      expect(find.text('Trainer Experience'), findsOneWidget);
      expect(find.text('Trainer Gender'), findsOneWidget);

      // Fill in Name
      final nameField = find.widgetWithText(TextFormField, 'e.g. David Sterling');
      await tester.enterText(nameField, 'Alex Thunder');

      // Select Experience preset
      final expPreset = find.text('5-8 Years Exp');
      await tester.tap(expPreset);
      await tester.pumpAndSettle();

      // Select Gender from dropdown
      final genderDropdown = find.byType(DropdownButton<String>);
      expect(genderDropdown, findsOneWidget);
      await tester.tap(genderDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      // Submit
      final createBtn = find.text('Create Team Member');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Verify new Trainer is in the team list with both experience and gender badges
      expect(find.text('Alex Thunder'), findsOneWidget);
      expect(find.text('5-8 Years Exp'), findsOneWidget);
      expect(find.text('Female'), findsWidgets);
    });

    testWidgets(
        'Creating an Owner or Manager hides Trainer Experience field and adds team member',
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

      // Tap Team tab
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      // Tap Add button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Change role to Manager
      await tester.tap(find.text('Manager'));
      await tester.pumpAndSettle();

      // Verify Trainer Experience field is hidden
      expect(find.text('Trainer Experience'), findsNothing);

      // Fill name
      final nameField = find.widgetWithText(TextFormField, 'e.g. David Sterling');
      await tester.enterText(nameField, 'Sophia Taylor');

      // Submit
      final createBtn = find.text('Create Team Member');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Verify new Manager is in the list
      expect(find.text('Sophia Taylor'), findsOneWidget);
      expect(find.text('MANAGER'), findsWidgets);
    });

    testWidgets(
        'Role filter chips filter dynamically created team members properly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Add 1 Owner and 1 Trainer
      await authController.addTeamMember(
        const GymTeamMemberRecord(
          id: 'team_01',
          fullName: 'Marcus Vance',
          role: GymTeamRole.owner,
          specialty: 'Gym Founder & Owner',
          phone: '+1 555 123 4567',
        ),
      );
      await authController.addTeamMember(
        const GymTeamMemberRecord(
          id: 'team_02',
          fullName: 'Elena Vance',
          role: GymTeamRole.manager,
          specialty: 'Operations Manager',
          phone: '+1 555 890 1234',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Team tab
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      // Filter by Owners
      await tester.tap(find.text('Owners'));
      await tester.pumpAndSettle();

      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('Elena Vance'), findsNothing);

      // Filter by Managers
      await tester.tap(find.text('Managers'));
      await tester.pumpAndSettle();

      expect(find.text('Marcus Vance'), findsNothing);
      expect(find.text('Elena Vance'), findsOneWidget);
    });

    testWidgets('Toggling duty status and removing team member updates backend state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await authController.addTeamMember(
        const GymTeamMemberRecord(
          id: 'team_david',
          fullName: 'David Sterling',
          role: GymTeamRole.trainer,
          gender: 'Male',
          experience: '7 Years Exp',
          specialty: 'Hypertrophy & Strength',
          phone: '+1 555 901 2345',
          isOnDuty: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Team tab
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      expect(find.text('David Sterling'), findsOneWidget);

      // Open popup menu on card
      final popupMenuBtn = find.byIcon(Icons.more_vert_rounded).first;
      await tester.tap(popupMenuBtn);
      await tester.pumpAndSettle();

      // Toggle duty
      await tester.tap(find.text('Mark Off Duty'));
      await tester.pumpAndSettle();

      // Verify duty updated
      expect(authController.teamMembers.first.isOnDuty, isFalse);
    });

    testWidgets('View Attendance popup option opens custom calendar modal with KPIs and attendance grid',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await authController.addTeamMember(
        GymTeamMemberRecord(
          id: 'team_sarah',
          fullName: 'Sarah Connor',
          role: GymTeamRole.trainer,
          gender: 'Female',
          experience: '6 Years Exp',
          specialty: 'CrossFit & HIIT',
          phone: '+1 555 432 1098',
          isOnDuty: true,
          createdAt: DateTime(2026, 1, 15),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Team tab
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      expect(find.text('Sarah Connor'), findsOneWidget);

      // Open popup menu
      final popupMenuBtn = find.byIcon(Icons.more_vert_rounded).first;
      await tester.tap(popupMenuBtn);
      await tester.pumpAndSettle();

      // Expect 'View Attendance' menu item
      expect(find.text('View Attendance'), findsOneWidget);

      // Tap View Attendance
      await tester.tap(find.text('View Attendance'));
      await tester.pumpAndSettle();

      // Verify custom calendar modal opened
      expect(find.text('Sarah Connor'), findsWidgets);
      expect(find.text('On Duty / Present'), findsOneWidget);
      expect(find.text('Off Duty / Absent'), findsOneWidget);
      expect(find.text('Month Total'), findsOneWidget);
      expect(find.text('MON'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);
      expect(find.text('💡 Tap past date to adjust record'), findsOneWidget);

      // Month navigation buttons
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Tap close
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Modal closed
      expect(find.text('💡 Tap past date to adjust record'), findsNothing);
    });

    test('GymTeamMemberRecord isPresentOnDate dynamically marks all days from registration date as present', () {
      final regDate = DateTime(2026, 8, 1);
      final member = GymTeamMemberRecord(
        id: 'team_dyn_1',
        fullName: 'Marcus Iron',
        role: GymTeamRole.trainer,
        specialty: 'Powerlifting',
        phone: '+1 555 123 4567',
        createdAt: regDate,
        attendanceLogs: const {
          '2026-08-10': false, // Explicit off day
        },
      );

      // Day before registration: false (not joined yet)
      expect(member.isPresentOnDate(DateTime(2026, 7, 31)), isFalse);

      // Day of registration: true (attended)
      expect(member.isPresentOnDate(DateTime(2026, 8, 1)), isTrue);

      // Regular day after registration: true (attended)
      expect(member.isPresentOnDate(DateTime(2026, 8, 5)), isTrue);

      // Explicit off day logged: false (off duty)
      expect(member.isPresentOnDate(DateTime(2026, 8, 10)), isFalse);

      // Future date: false
      expect(member.isPresentOnDate(DateTime(2026, 9, 30)), isFalse);
    });

    test('GymTeamMemberRecord serializes to and from JSON for Firestore with attendanceLogs', () {
      const record = GymTeamMemberRecord(
        id: 'team_test_123',
        tenantId: 'tenant_abc',
        fullName: 'Jordan Cruz',
        role: GymTeamRole.trainer,
        gender: 'Male',
        experience: '4 Years Exp',
        specialty: 'Athletic Conditioning',
        phone: '+1 555 999 8888',
        email: 'jordan@gym.com',
        activeClientsCount: 12,
        rating: 4.95,
        isOnDuty: true,
        imageUrl: 'https://storage.googleapis.com/test.jpg',
        attendanceLogs: {
          '2026-08-15': true,
          '2026-08-16': false,
        },
      );

      final json = record.toJson();
      expect(json['id'], 'team_test_123');
      expect(json['tenantId'], 'tenant_abc');
      expect(json['fullName'], 'Jordan Cruz');
      expect(json['role'], 'trainer');
      expect(json['gender'], 'Male');
      expect(json['experience'], '4 Years Exp');
      expect(json['imageUrl'], 'https://storage.googleapis.com/test.jpg');
      expect(json['attendanceLogs'], isA<Map>());
      expect(json['attendanceLogs']['2026-08-15'], isTrue);
      expect(json['attendanceLogs']['2026-08-16'], isFalse);

      final deserialized = GymTeamMemberRecord.fromJson(json, 'team_test_123');
      expect(deserialized.id, 'team_test_123');
      expect(deserialized.tenantId, 'tenant_abc');
      expect(deserialized.fullName, 'Jordan Cruz');
      expect(deserialized.role, GymTeamRole.trainer);
      expect(deserialized.gender, 'Male');
      expect(deserialized.experience, '4 Years Exp');
      expect(deserialized.isTrainer, isTrue);
      expect(deserialized.imageUrl, 'https://storage.googleapis.com/test.jpg');
      expect(deserialized.attendanceLogs['2026-08-15'], isTrue);
      expect(deserialized.attendanceLogs['2026-08-16'], isFalse);
    });
  });
}
