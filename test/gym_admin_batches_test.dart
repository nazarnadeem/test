import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/models/gym_batch_model.dart';
import 'package:gcrm_one/features/auth/data/models/gym_member_model.dart';
import 'package:gcrm_one/features/auth/data/models/user_model.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/gym_admin_dashboard_screen.dart';

void main() {
  group('GymBatchModel Unit Tests', () {
    test('GymBatchModel serializes to and from JSON correctly', () {
      final batch = GymBatchModel(
        id: 'btch_101',
        tenantId: 'tenant_001',
        name: 'Morning Fitness Batch',
        time: '06:00 AM - 07:30 AM',
        limit: 15,
        memberIds: ['mem_01', 'mem_02'],
        memberNames: ['Jordan Hayes', 'Alex Morgan'],
        isActive: true,
        accentColor: const Color(0xFF00E676),
      );

      final json = batch.toJson();
      expect(json['id'], 'btch_101');
      expect(json['name'], 'Morning Fitness Batch');
      expect(json['time'], '06:00 AM - 07:30 AM');
      expect(json['limit'], 15);
      expect(json['memberIds'], ['mem_01', 'mem_02']);

      final restored = GymBatchModel.fromJson(json, 'btch_101');
      expect(restored.id, 'btch_101');
      expect(restored.name, 'Morning Fitness Batch');
      expect(restored.enrolledCount, 2);
      expect(restored.availableSlots, 13);
      expect(restored.isFull, false);
    });

    test('GymBatchModel capacity helpers work as expected', () {
      final fullBatch = GymBatchModel(
        id: 'btch_full',
        name: 'HIIT Express',
        time: '05:00 PM - 06:00 PM',
        limit: 2,
        memberIds: ['m1', 'm2'],
      );

      expect(fullBatch.enrolledCount, 2);
      expect(fullBatch.isFull, true);
      expect(fullBatch.availableSlots, 0);
      expect(fullBatch.occupancyRatio, 1.0);
    });

    test('GymMemberModel serializes batchId and batchName correctly', () {
      final member = GymMemberModel(
        id: 'mem_101',
        firstName: 'Elena',
        lastName: 'Rostova',
        phone: '+91 9112233445',
        membershipPlan: 'Pro Pass',
        batchId: 'btch_morn',
        batchName: 'Morning Elite (06:00 AM - 07:30 AM)',
        startDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );

      final json = member.toJson();
      expect(json['batchId'], 'btch_morn');
      expect(json['batchName'], 'Morning Elite (06:00 AM - 07:30 AM)');

      final restored = GymMemberModel.fromJson(json, 'mem_101');
      expect(restored.batchId, 'btch_morn');
      expect(restored.batchName, 'Morning Elite (06:00 AM - 07:30 AM)');
    });

    test('GymMemberModel.copyWith clears batchId and batchName properly when set to null or clearBatch: true', () {
      final member = GymMemberModel(
        id: 'mem_102',
        firstName: 'Elena',
        lastName: 'Rostova',
        phone: '+91 9112233445',
        membershipPlan: 'Pro Pass',
        batchId: 'btch_morn',
        batchName: 'Morning Elite (06:00 AM - 07:30 AM)',
        startDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );

      // Clearing via batchId: null and batchName: null
      final cleared1 = member.copyWith(batchId: null, batchName: null);
      expect(cleared1.batchId, isNull);
      expect(cleared1.batchName, isNull);

      // Clearing via clearBatch: true
      final cleared2 = member.copyWith(clearBatch: true);
      expect(cleared2.batchId, isNull);
      expect(cleared2.batchName, isNull);

      // Preserving batch when other fields change
      final updatedPhone = member.copyWith(phone: '+91 9999999999');
      expect(updatedPhone.batchId, 'btch_morn');
      expect(updatedPhone.batchName, 'Morning Elite (06:00 AM - 07:30 AM)');
      expect(updatedPhone.phone, '+91 9999999999');
    });
  });

  group('Gym Admin Batches Controller & Repository Tests', () {
    late MockAuthService mockAuthService;
    late AuthController authController;

    setUp(() async {
      mockAuthService = MockAuthService();
      mockAuthService.resetForTesting();
      authController = AuthController(authRepository: mockAuthService);

      await authController.login(
        email: 'owner@metrofitness.com',
        password: 'Owner@Metro2026',
      );
    });

    test('AuthController can add, update, toggle, and delete batches', () async {
      final newBatch = GymBatchModel(
        id: 'btch_test_1',
        tenantId: 'tenant_metro_01',
        name: 'Evening Powerlifting',
        time: '07:00 PM - 08:30 PM',
        limit: 10,
        memberIds: ['mem_001'],
        memberNames: ['Jordan Hayes'],
      );

      // 1. Add Batch
      final addSuccess = await authController.addGymBatch(newBatch);
      expect(addSuccess, true);
      expect(authController.batches.any((b) => b.name == 'Evening Powerlifting'), true);

      // 2. Update Batch
      final createdBatch = authController.batches.firstWhere((b) => b.name == 'Evening Powerlifting');
      final updatedBatch = createdBatch.copyWith(
        name: 'Evening Powerlifting Elite',
        limit: 25,
      );
      final updateSuccess = await authController.updateGymBatch(updatedBatch);
      expect(updateSuccess, true);
      expect(authController.batches.firstWhere((b) => b.id == createdBatch.id).limit, 25);

      // 3. Toggle Status
      final toggleSuccess = await authController.toggleGymBatchStatus(createdBatch.id, false);
      expect(toggleSuccess, true);
      expect(authController.batches.firstWhere((b) => b.id == createdBatch.id).isActive, false);

      // 4. Delete Batch
      final deleteSuccess = await authController.deleteGymBatch(createdBatch.id);
      expect(deleteSuccess, true);
      expect(authController.batches.any((b) => b.id == createdBatch.id), false);
    });
  });

  group('Gym Admin Dashboard Screen Batches Tab Widget Tests', () {
    late MockAuthService mockAuthService;
    late AuthController authController;

    setUp(() async {
      mockAuthService = MockAuthService();
      mockAuthService.resetForTesting();
      authController = AuthController(authRepository: mockAuthService);

      await authController.login(
        email: 'owner@metrofitness.com',
        password: 'Owner@Metro2026',
      );

      // Seed a test member
      await authController.addGymMember(
        GymMemberModel(
          id: 'mem_widget_01',
          tenantId: 'tenant_metro_01',
          firstName: 'Marcus',
          lastName: 'Vance',
          phone: '+91 9988776655',
          email: 'marcus@example.com',
          membershipPlan: 'Pro Tier',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(const Duration(days: 30)),
        ),
      );
    });

    testWidgets('Displays Batches tab and creates a new facility batch', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Batches tab exists in TabBar
      expect(find.text('Batches'), findsOneWidget);

      // Switch to Batches tab
      await tester.tap(find.text('Batches'));
      await tester.pumpAndSettle();

      // Verify Batches tab header KPI card or empty state view
      expect(find.text('Total Batches'), findsOneWidget);

      // Tap "Add Batch" button
      await tester.tap(find.text('Add Batch').first);
      await tester.pumpAndSettle();

      // Verify create batch modal sheet opens with 4 required details
      expect(find.text('Create New Facility Batch'), findsOneWidget);
      expect(find.text('1. Batch Name *'), findsOneWidget);
      expect(find.text('2. Batch Time *'), findsOneWidget);
      expect(find.text('3. Batch Limit / Max Capacity *'), findsOneWidget);
      expect(find.text('4. Add Members to Batch'), findsOneWidget);

      // Enter details
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Early Bird Cardio');

      // Select preset time or enter time
      await tester.tap(find.text('06:00 AM - 07:30 AM').first);
      await tester.pumpAndSettle();

      // Enter capacity limit
      await tester.enterText(textFields.at(2), '30');

      // Check member in multi-select list
      expect(find.text('Marcus Vance'), findsOneWidget);
      await tester.tap(find.text('Marcus Vance'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Submit Create Batch form
      await tester.tap(find.text('Create Batch'));
      await tester.pumpAndSettle();

      // Verify new batch is listed on dashboard screen
      expect(find.text('Early Bird Cardio'), findsOneWidget);
      expect(find.text('06:00 AM - 07:30 AM'), findsOneWidget);
      expect(find.text('Marcus Vance'), findsOneWidget);
    });

    testWidgets('Edits existing batch details and assigned members', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      // Pre-add a batch
      await authController.addGymBatch(
        GymBatchModel(
          id: 'btch_edit_me',
          name: 'Zumba Beats',
          time: '05:30 PM - 07:00 PM',
          limit: 15,
          memberIds: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Batches tab
      await tester.tap(find.text('Batches'));
      await tester.pumpAndSettle();

      expect(find.text('Zumba Beats'), findsOneWidget);

      // Tap "Edit Batch" button
      await tester.tap(find.text('Edit Batch').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch Details'), findsOneWidget);

      // Update name
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Zumba Beats Masterclass');
      await tester.pumpAndSettle();

      // Submit Edit Batch form
      await tester.tap(find.text('Update Batch'));
      await tester.pumpAndSettle();

      expect(find.text('Zumba Beats Masterclass'), findsOneWidget);
    });

    testWidgets('Prevents creating a batch when member count exceeds capacity limit', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batches'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Batch').first);
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Strict Limit Batch');
      await tester.tap(find.text('06:00 AM - 07:30 AM').first);
      await tester.enterText(textFields.at(2), '1');
      await tester.pumpAndSettle();

      expect(find.text('Marcus Vance'), findsOneWidget);
      await tester.tap(find.text('Marcus Vance'), warnIfMissed: false);
      expect(find.byType(CheckboxListTile), findsWidgets);
    });

    testWidgets('Prevents deleting a batch when members are linked and shows error', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      // Add a batch with 1 member linked
      await authController.addGymBatch(
        GymBatchModel(
          id: 'btch_with_members',
          name: 'Pilates Power',
          time: '08:00 AM - 09:30 AM',
          limit: 10,
          memberIds: ['mem_widget_01'],
          memberNames: ['Marcus Vance'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batches'));
      await tester.pumpAndSettle();

      expect(find.text('Pilates Power'), findsOneWidget);

      // Try to delete batch with member
      final deleteButtons = find.widgetWithText(OutlinedButton, 'Delete');
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Verify error message is shown and batch is NOT deleted
      expect(
        find.text('1 members are linked with this batch firstly remove these members from batch by editing the batch'),
        findsOneWidget,
      );
      expect(find.text('Pilates Power'), findsOneWidget);
    });

    testWidgets('Allows deleting a batch when no members are linked', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      // Add a batch with 0 members linked
      await authController.addGymBatch(
        const GymBatchModel(
          id: 'btch_empty',
          name: 'Empty Batch Demo',
          time: '11:00 AM - 12:00 PM',
          limit: 10,
          memberIds: [],
          memberNames: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batches'));
      await tester.pumpAndSettle();

      expect(find.text('Empty Batch Demo'), findsOneWidget);

      // Tap Delete on the empty batch
      final deleteButtons = find.widgetWithText(OutlinedButton, 'Delete');
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Verify confirmation dialog opens
      expect(find.text('Delete Batch'), findsOneWidget);
      expect(find.text('Are you sure you want to delete "Empty Batch Demo"?'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Verify batch was removed
      expect(find.text('Empty Batch Demo'), findsNothing);
    });

    testWidgets('Removing a member from batch in edit dialog clears the member batchId and updates state', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      // 1. Create a batch with Marcus Vance linked
      final batch = GymBatchModel(
        id: 'btch_marcus_sync',
        name: 'Iron Club',
        time: '06:00 AM - 07:30 AM',
        limit: 10,
        memberIds: ['mem_widget_01'],
        memberNames: ['Marcus Vance'],
      );
      await authController.addGymBatch(batch);

      // Set member's batchId to this batch
      final existingMem = authController.members.firstWhere((m) => m.id == 'mem_widget_01');
      await authController.updateGymMember(
        existingMem.copyWith(batchId: 'btch_marcus_sync', batchName: 'Iron Club (06:00 AM - 07:30 AM)'),
      );
      expect(authController.members.firstWhere((m) => m.id == 'mem_widget_01').batchId, 'btch_marcus_sync');

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Batches tab
      await tester.tap(find.text('Batches'));
      await tester.pumpAndSettle();

      // Open Edit Batch modal
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Batch').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch Details'), findsOneWidget);

      // Deselect Marcus Vance
      expect(find.byType(CheckboxListTile), findsWidgets);
      await tester.ensureVisible(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      // Submit update batch
      await tester.ensureVisible(find.text('Update Batch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Batch'));
      await tester.pumpAndSettle();

      // Verify batch no longer has Marcus Vance
      final updatedBatch = authController.batches.firstWhere((b) => b.id == 'btch_marcus_sync');
      expect(updatedBatch.memberIds.contains('mem_widget_01'), false);

      // CRITICAL: Verify member is updated and no longer has batchId
      final updatedMember = authController.members.firstWhere((m) => m.id == 'mem_widget_01');
      expect(updatedMember.batchId, isNull);
      expect(updatedMember.batchName, isNull);

      // Check Members tab to ensure it shows 'Batch: Unassigned'
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      expect(find.text('Batch: Unassigned'), findsOneWidget);
    });
  });
}
