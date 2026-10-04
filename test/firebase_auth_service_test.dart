import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/constants/app_strings.dart';
import 'package:gcrm_one/features/auth/data/models/user_model.dart';
import 'package:gcrm_one/features/auth/data/models/gym_expense_model.dart';
import 'package:gcrm_one/features/auth/data/repositories/firebase_auth_service.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';

void main() {
  group('FirebaseAuthService Super Admin Backend Tests', () {
    late FirebaseAuthService firebaseAuthService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      firebaseAuthService = FirebaseAuthService(fallbackService: mockAuthService);
    });

    test('registerSuperAdmin initializes Master Super Admin with all platform permissions',
        () async {
      final session = await firebaseAuthService.registerSuperAdmin(
        fullName: 'Alexander Wright',
        email: 'alex.wright@gcrmone.com',
        password: 'MasterAdmin@2026',
        phone: '+1 (800) 555-0199',
        securityPin: '884920',
        organization: 'GCRM ONE Global Platform',
      );

      expect(session.user.fullName, equals('Alexander Wright'));
      expect(session.user.email, equals('alex.wright@gcrmone.com'));
      expect(session.user.role, equals(UserRole.superAdmin));
      expect(session.user.isSuperAdmin, isTrue);
      expect(session.user.gymName, equals('GCRM ONE Global Platform'));
      expect(session.user.permissions, contains('manage_all_tenants'));
      expect(session.user.permissions, contains('approve_gym_vendors'));
      expect(session.user.permissions, contains('view_global_revenue'));
      expect(session.user.permissions, contains('manage_system_settings'));
      expect(session.token.isNotEmpty, isTrue);
      expect(session.isExpired, isFalse);
    });

    test('loginSuperAdmin validates Super Admin credentials and clearance',
        () async {
      final session = await firebaseAuthService.loginSuperAdmin(
        email: AppStrings.demoSuperAdminEmail,
        password: AppStrings.demoSuperAdminPass,
      );

      expect(session.user.isSuperAdmin, isTrue);
      expect(session.user.role, equals(UserRole.superAdmin));
      expect(session.token.isNotEmpty, isTrue);
    });

    test('loginSuperAdmin throws exception on invalid credentials', () async {
      expect(
        () => firebaseAuthService.loginSuperAdmin(
          email: AppStrings.demoSuperAdminEmail,
          password: 'IncorrectPassword',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('requestPasswordReset succeeds for registered email', () async {
      final result = await firebaseAuthService.requestPasswordReset(
        email: AppStrings.demoSuperAdminEmail,
      );
      expect(result, isTrue);
    });

    test('requestPasswordReset throws exception for unregistered email', () async {
      expect(
        () => firebaseAuthService.requestPasswordReset(
          email: 'unknown.user@doesnotexist.com',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('addGymExpense, getGymExpenses, updateGymExpense and deleteGymExpense work end-to-end', () async {
      const tenantId = 'tenant_metro_01';
      final newExpense = GymExpenseRecord(
        id: 'exp_test_01',
        tenantId: tenantId,
        title: 'Air Conditioning Overhaul',
        category: 'Equipment & Upkeep',
        amount: 14500.0,
        date: DateTime(2026, 8, 31),
        paymentMethod: 'Bank Transfer',
        notes: 'Annual HVAC maintenance contract',
      );

      final added = await firebaseAuthService.addGymExpense(
        tenantId: tenantId,
        expense: newExpense,
      );

      expect(added.id, 'exp_test_01');
      expect(added.title, 'Air Conditioning Overhaul');
      expect(added.amount, 14500.0);

      // Verify fetch
      final expenses = await firebaseAuthService.getGymExpenses(tenantId: tenantId);
      expect(expenses.any((e) => e.id == 'exp_test_01'), isTrue);

      // Update
      final updated = await firebaseAuthService.updateGymExpense(
        tenantId: tenantId,
        expense: added.copyWith(amount: 16000.0, notes: 'Includes condenser replacement'),
      );
      expect(updated.amount, 16000.0);
      expect(updated.notes, 'Includes condenser replacement');

      // Delete
      await firebaseAuthService.deleteGymExpense(
        tenantId: tenantId,
        expenseId: 'exp_test_01',
      );
      final afterDelete = await firebaseAuthService.getGymExpenses(tenantId: tenantId);
      expect(afterDelete.any((e) => e.id == 'exp_test_01'), isFalse);
    });

    test('recordMemberCheckIn and getGymCheckIns persist and retrieve check-in history', () async {
      const tenantId = 'tenant_metro_01';
      final log = await firebaseAuthService.recordMemberCheckIn(
        tenantId: tenantId,
        memberId: 'mem_123',
        memberName: 'Alex Rivera',
        planName: 'Gold Annual Pass',
        method: 'QR Scan',
      );

      expect(log.memberName, 'Alex Rivera');
      expect(log.planName, 'Gold Annual Pass');
      expect(log.method, 'QR Scan');
      expect(log.tenantId, tenantId);

      final checkIns = await firebaseAuthService.getGymCheckIns(tenantId: tenantId);
      expect(checkIns.isNotEmpty, isTrue);
      expect(checkIns.first.memberName, 'Alex Rivera');
      expect(checkIns.first.method, 'QR Scan');
    });

    test('login with gym admin credentials resolves to gymOwner and isSuperAdmin is false', () async {
      final session = await firebaseAuthService.login(
        email: 'owner@metrofitness.com',
        password: 'Owner@Metro2026',
      );

      expect(session.user.role, equals(UserRole.gymOwner));
      expect(session.user.isSuperAdmin, isFalse);
      expect(session.user.isGymOwner, isTrue);
      expect(session.user.tenantId, equals('tenant_metro_01'));
    });

    test('UserModel with tenantId cannot be Super Admin even if json sets isSuperAdmin true', () {
      final model = UserModel.fromJson({
        'id': 'usr_test_gym_admin',
        'email': 'gymadmin@example.com',
        'fullName': 'Test Gym Admin',
        'role': 'superAdmin',
        'isSuperAdmin': true,
        'tenantId': 'tenant_test_123',
        'gymName': 'Test Fitness Club',
      });

      expect(model.isSuperAdmin, isFalse);
      expect(model.role, equals(UserRole.gymOwner));
      expect(model.isGymOwner, isTrue);
    });

    test('UserRoleExtension.fromString parses roles correctly', () {
      expect(UserRoleExtension.fromString('superadmin'), equals(UserRole.superAdmin));
      expect(UserRoleExtension.fromString('super_admin'), equals(UserRole.superAdmin));
      expect(UserRoleExtension.fromString('gymowner'), equals(UserRole.gymOwner));
      expect(UserRoleExtension.fromString('gym_admin'), equals(UserRole.gymOwner));
      expect(UserRoleExtension.fromString('admin'), equals(UserRole.gymOwner));
      expect(UserRoleExtension.fromString('trainer'), equals(UserRole.trainer));
      expect(UserRoleExtension.fromString('member'), equals(UserRole.member));
    });
  });
}
