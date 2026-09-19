import 'dart:async';
import 'dart:typed_data';
import '../../../../core/utils/image_optimizer.dart';
import '../models/user_model.dart';
import '../models/gym_tenant_model.dart';
import '../models/auth_session.dart';
import '../models/platform_plan_model.dart';
import '../models/gym_team_member_model.dart';
import '../models/gym_membership_plan_model.dart';
import '../models/gym_member_model.dart';
import '../models/gym_expense_model.dart';
import '../models/gym_check_in_model.dart';
import '../models/gym_batch_model.dart';
import 'auth_repository.dart';

/// In-memory mock authentication implementation for GCRM One.
/// Fully equipped with pre-seeded accounts, multi-tenant records, and realistic async delay.
class MockAuthService implements AuthRepository {
  // Singleton pattern for centralized state across the app
  static final MockAuthService _instance = MockAuthService._internal();
  factory MockAuthService() => _instance;
  MockAuthService._internal() {
    _seedInitialData();
  }

  void resetForTesting() {
    _usersByEmail.clear();
    _tenantsById.clear();
    _pendingOtpsByEmail.clear();
    _membershipPlansByTenant.clear();
    _membersByTenant.clear();
    _expensesByTenant.clear();
    _checkInsByTenant.clear();
    _batchesByTenant.clear();
    _currentSession = null;
    _seedInitialData();
  }

  // State caches
  final Map<String, _UserCredential> _usersByEmail = {};
  final Map<String, GymTenantModel> _tenantsById = {};
  final Map<String, String> _pendingOtpsByEmail = {};
  final Map<String, List<GymMembershipPlanModel>> _membershipPlansByTenant = {};
  final Map<String, List<GymMemberModel>> _membersByTenant = {};
  final Map<String, List<GymExpenseRecord>> _expensesByTenant = {};
  final Map<String, List<GymCheckInLog>> _checkInsByTenant = {};
  final Map<String, List<GymBatchModel>> _batchesByTenant = {};
  AuthSession? _currentSession;

  void _seedInitialData() {
    // 1. Seed Super Admin (Platform Owner)
    final superAdminUser = UserModel(
      id: 'usr_superadmin_001',
      email: 'superadmin@gcrmone.com',
      fullName: 'Chief Administrator (GCRM ONE)',
      phoneNumber: '+1 (800) 555-0199',
      role: UserRole.superAdmin,
      tenantId: null,
      gymName: 'GCRM ONE Global Platform',
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
      permissions: [
        'manage_all_tenants',
        'approve_gym_vendors',
        'view_global_revenue',
        'manage_system_settings',
      ],
    );
    _usersByEmail['superadmin@gcrmone.com'] = _UserCredential(
      user: superAdminUser,
      password: 'SuperAdmin@GCRM2026',
    );

    // 2. Seed Gym Tenants (Vendors)
    final tenant1 = GymTenantModel(
      id: 'tenant_metro_01',
      gymName: 'MetroFitness Central Club',
      tradeLicense: 'TR-NYC-2024-8831',
      ownerId: 'usr_owner_001',
      ownerName: 'Marcus Vance',
      ownerEmail: 'owner@metrofitness.com',
      address: '452 5th Avenue, New York, NY 10018',
      phone: '+1 (212) 555-4321',
      gymCode: 'METRO-NY',
      tier: SubscriptionTier.enterprise,
      status: TenantStatus.active,
      activeMembersCount: 420,
      activeTrainersCount: 14,
      monthlyRevenue: 284000.0,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    );

    final tenant2 = GymTenantModel(
      id: 'tenant_iron_02',
      gymName: 'IronPulse Powerhouse Gym',
      tradeLicense: 'TR-MIA-2024-7712',
      ownerId: 'usr_owner_002',
      ownerName: 'Elena Rostova',
      ownerEmail: 'elena@ironpulse.com',
      address: '880 Ocean Drive, Miami Beach, FL 33139',
      phone: '+1 (305) 555-8900',
      gymCode: 'IRON-MIA',
      tier: SubscriptionTier.growth,
      status: TenantStatus.active,
      activeMembersCount: 280,
      activeTrainersCount: 9,
      monthlyRevenue: 192000.0,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    );

    final tenant3 = GymTenantModel(
      id: 'tenant_apex_03',
      gymName: 'Apex Athletic Sanctuary',
      tradeLicense: 'TR-ATX-2025-1102',
      ownerId: 'usr_owner_003',
      ownerName: 'Liam O\'Connor',
      ownerEmail: 'liam@apexath.com',
      address: '220 Congress Ave, Austin, TX 78701',
      phone: '+1 (512) 555-3344',
      gymCode: 'APEX-ATX',
      tier: SubscriptionTier.starter,
      status: TenantStatus.pendingApproval,
      activeMembersCount: 0,
      activeTrainersCount: 0,
      monthlyRevenue: 0.0,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );

    _tenantsById[tenant1.id] = tenant1;
    _tenantsById[tenant2.id] = tenant2;
    _tenantsById[tenant3.id] = tenant3;

    // 3. Seed Gym Owner
    final ownerUser = UserModel(
      id: 'usr_owner_001',
      email: 'owner@metrofitness.com',
      fullName: 'Marcus Vance',
      phoneNumber: '+1 (212) 555-4321',
      role: UserRole.gymOwner,
      tenantId: tenant1.id,
      gymName: tenant1.gymName,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      permissions: [
        'manage_gym_members',
        'manage_trainers',
        'view_gym_analytics',
        'process_memberships',
      ],
    );
    _usersByEmail['owner@metrofitness.com'] = _UserCredential(
      user: ownerUser,
      password: 'Owner@Metro2026',
    );

    // 4. Seed Trainer
    final trainerUser = UserModel(
      id: 'usr_trainer_001',
      email: 'trainer@metrofitness.com',
      fullName: 'David Sterling',
      phoneNumber: '+1 (212) 555-9876',
      role: UserRole.trainer,
      tenantId: tenant1.id,
      gymName: tenant1.gymName,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      permissions: [
        'view_assigned_clients',
        'log_workout_plans',
        'record_attendance',
      ],
    );
    _usersByEmail['trainer@metrofitness.com'] = _UserCredential(
      user: trainerUser,
      password: 'Trainer@Metro2026',
    );

    // 5. Seed Member
    final memberUser = UserModel(
      id: 'usr_member_001',
      email: 'member@metrofitness.com',
      fullName: 'Sarah Jenkins',
      phoneNumber: '+1 (212) 555-1122',
      role: UserRole.member,
      tenantId: tenant1.id,
      gymName: tenant1.gymName,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      permissions: [
        'qr_check_in',
        'view_workout_schedule',
        'book_group_classes',
      ],
    );
    _usersByEmail['member@metrofitness.com'] = _UserCredential(
      user: memberUser,
      password: 'Member@Metro2026',
    );
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    UserRole? requestedRole,
    bool rememberMe = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final normalizedEmail = email.trim().toLowerCase();

    final cred = _usersByEmail[normalizedEmail];
    if (cred == null || cred.password != password) {
      throw Exception('Invalid email or password. Please verify your credentials.');
    }

    if (requestedRole != null && cred.user.role != requestedRole) {
      throw Exception(
        'Account is registered as ${cred.user.role.displayName}. Please switch role to proceed.',
      );
    }

    _currentSession = AuthSession(
      user: cred.user,
      token: 'jwt_token_${cred.user.id}_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'refresh_${cred.user.id}',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      rememberMe: rememberMe,
    );

    return _currentSession!;
  }

  @override
  Future<AuthSession> loginSuperAdmin({
    required String email,
    required String password,
    String? securityCode,
    bool rememberMe = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final normalizedEmail = email.trim().toLowerCase();

    final cred = _usersByEmail[normalizedEmail];
    if (cred == null || cred.password != password) {
      throw Exception('Super Admin credentials invalid. Access denied.');
    }

    if (cred.user.role != UserRole.superAdmin) {
      throw Exception('Access denied: You do not have Super Admin platform clearance.');
    }

    _currentSession = AuthSession(
      user: cred.user,
      token: 'superadmin_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'superadmin_refresh',
      expiresAt: DateTime.now().add(const Duration(days: 14)),
      rememberMe: rememberMe,
    );

    return _currentSession!;
  }

  @override
  Future<AuthSession> registerSuperAdmin({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    String? securityPin,
    String? organization,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final normalizedEmail = email.trim().toLowerCase();

    final adminId = 'usr_superadmin_${DateTime.now().millisecondsSinceEpoch}';
    final superAdminUser = UserModel(
      id: adminId,
      email: normalizedEmail,
      fullName: fullName,
      phoneNumber: phone,
      role: UserRole.superAdmin,
      tenantId: null,
      gymName: organization ?? 'GCRM ONE Global Platform',
      createdAt: DateTime.now(),
      permissions: const [
        'manage_all_tenants',
        'approve_gym_vendors',
        'view_global_revenue',
        'manage_system_settings',
        'manage_global_trainers',
        'manage_security_keys',
      ],
    );

    _usersByEmail[normalizedEmail] = _UserCredential(
      user: superAdminUser,
      password: password,
    );

    _currentSession = AuthSession(
      user: superAdminUser,
      token: 'superadmin_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'superadmin_refresh_$adminId',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      rememberMe: true,
    );

    return _currentSession!;
  }

  @override
  Future<AuthSession> registerGymVendor({
    required String gymName,
    required String tradeLicense,
    required String address,
    required String ownerFullName,
    required String email,
    required String password,
    required String phone,
    SubscriptionTier tier = SubscriptionTier.growth,
  }) async {
    await Future.delayed(const Duration(milliseconds: 450));
    final normalizedEmail = email.trim().toLowerCase();

    if (_usersByEmail.containsKey(normalizedEmail)) {
      throw Exception('An account with this email address already exists.');
    }

    final tenantId = 'tenant_${DateTime.now().millisecondsSinceEpoch}';
    final ownerId = 'usr_owner_${DateTime.now().millisecondsSinceEpoch}';
    final gymCode = gymName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final safeCode = '${gymCode.length > 5 ? gymCode.substring(0, 5) : gymCode}-01';

    final newTenant = GymTenantModel(
      id: tenantId,
      gymName: gymName,
      tradeLicense: tradeLicense,
      ownerId: ownerId,
      ownerName: ownerFullName,
      ownerEmail: normalizedEmail,
      address: address,
      phone: phone,
      gymCode: safeCode,
      tier: tier,
      status: TenantStatus.active,
      activeMembersCount: 1,
      activeTrainersCount: 0,
      monthlyRevenue: 0.0,
      createdAt: DateTime.now(),
    );

    final newOwner = UserModel(
      id: ownerId,
      email: normalizedEmail,
      fullName: ownerFullName,
      phoneNumber: phone,
      role: UserRole.gymOwner,
      tenantId: tenantId,
      gymName: gymName,
      createdAt: DateTime.now(),
      permissions: [
        'manage_gym_members',
        'manage_trainers',
        'view_gym_analytics',
        'process_memberships',
      ],
    );

    _tenantsById[tenantId] = newTenant;
    _usersByEmail[normalizedEmail] = _UserCredential(
      user: newOwner,
      password: password,
    );

    _currentSession = AuthSession(
      user: newOwner,
      token: 'jwt_owner_${ownerId}_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'refresh_$ownerId',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      rememberMe: true,
    );

    return _currentSession!;
  }

  @override
  Future<GymTenantModel> registerGymWithAdmin({
    required String gymName,
    required String ownerFullName,
    required String ownerEmail,
    required String phone,
    required String address,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    List<int>? logoBytes,
    String? logoUrl,
    String primaryColorHex = '#FF5722',
    SubscriptionTier tier = SubscriptionTier.growth,
    String? planId,
    String? planName,
    double? planPrice,
    String? billingPeriod,
    DateTime? planStartDate,
    DateTime? planExpiryDate,
    bool isLifetimeFree = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final normalizedOwnerEmail = ownerEmail.trim().toLowerCase();
    final normalizedAdminEmail = adminEmail.trim().toLowerCase();

    final tenantId = 'tenant_${DateTime.now().millisecondsSinceEpoch}';
    final adminId = 'usr_admin_${DateTime.now().millisecondsSinceEpoch}';
    final ownerId = 'usr_owner_${DateTime.now().millisecondsSinceEpoch}';
    final cleanGymCode = gymName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final safeCode = '${cleanGymCode.length > 5 ? cleanGymCode.substring(0, 5) : cleanGymCode}-01';

    String? resolvedLogoUrl = logoUrl;
    if (logoBytes != null && logoBytes.isNotEmpty && resolvedLogoUrl == null) {
      resolvedLogoUrl = 'https://gcrmone.app/storage/gym_logos/$tenantId.jpg';
    }

    final newTenant = GymTenantModel(
      id: tenantId,
      gymName: gymName,
      tradeLicense: 'TR-$safeCode',
      ownerId: ownerId,
      ownerName: ownerFullName,
      ownerEmail: normalizedOwnerEmail,
      adminName: adminName,
      adminEmail: normalizedAdminEmail,
      adminId: adminId,
      address: address,
      phone: phone,
      gymCode: safeCode,
      logoUrl: resolvedLogoUrl,
      primaryColorHex: primaryColorHex,
      tier: tier,
      planId: planId,
      planName: planName,
      planPrice: planPrice,
      billingPeriod: billingPeriod ?? 'year',
      planStartDate: planStartDate ?? DateTime.now(),
      planExpiryDate: isLifetimeFree ? null : planExpiryDate,
      isLifetimeFree: isLifetimeFree,
      status: TenantStatus.active,
      activeMembersCount: 0,
      activeTrainersCount: 0,
      monthlyRevenue: 0.0,
      createdAt: DateTime.now(),
    );

    final adminUser = UserModel(
      id: adminId,
      email: normalizedAdminEmail,
      fullName: adminName,
      phoneNumber: phone,
      role: UserRole.gymOwner,
      tenantId: tenantId,
      gymName: gymName,
      createdAt: DateTime.now(),
      permissions: const [
        'manage_gym_members',
        'manage_trainers',
        'view_gym_analytics',
        'process_memberships',
      ],
    );

    _tenantsById[tenantId] = newTenant;
    _usersByEmail[normalizedAdminEmail] = _UserCredential(
      user: adminUser,
      password: adminPassword,
    );

    return newTenant;
  }

  @override
  Future<String?> uploadGymLogo({
    required String gymId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return 'https://gcrmone.app/storage/gym_logos/$gymId.$fileExtension';
  }

  @override
  Future<AuthSession> registerMember({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String gymCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final normalizedEmail = email.trim().toLowerCase();

    if (_usersByEmail.containsKey(normalizedEmail)) {
      throw Exception('An account with this email address already exists.');
    }

    // Match gym code to tenant
    final normalizedCode = gymCode.trim().toUpperCase();
    GymTenantModel? matchedTenant;
    for (final tenant in _tenantsById.values) {
      if (tenant.gymCode.toUpperCase() == normalizedCode ||
          tenant.gymName.toUpperCase().contains(normalizedCode)) {
        matchedTenant = tenant;
        break;
      }
    }

    // Default to first tenant if code is generic demo
    matchedTenant ??= _tenantsById.values.first;

    final memberId = 'usr_mem_${DateTime.now().millisecondsSinceEpoch}';
    final newMember = UserModel(
      id: memberId,
      email: normalizedEmail,
      fullName: fullName,
      phoneNumber: phone,
      role: UserRole.member,
      tenantId: matchedTenant.id,
      gymName: matchedTenant.gymName,
      createdAt: DateTime.now(),
      permissions: [
        'qr_check_in',
        'view_workout_schedule',
        'book_group_classes',
      ],
    );

    _usersByEmail[normalizedEmail] = _UserCredential(
      user: newMember,
      password: password,
    );

    _currentSession = AuthSession(
      user: newMember,
      token: 'jwt_mem_${memberId}_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'refresh_$memberId',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      rememberMe: true,
    );

    return _currentSession!;
  }

  @override
  Future<bool> requestPasswordReset({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalizedEmail = email.trim().toLowerCase();

    if (!_usersByEmail.containsKey(normalizedEmail)) {
      throw Exception(
        'No registered account found with this email address ($email).',
      );
    }

    // Store a mock OTP for this email
    _pendingOtpsByEmail[normalizedEmail] = '123456';
    return true;
  }

  @override
  Future<bool> verifyOtp({required String email, required String otpCode}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalizedEmail = email.trim().toLowerCase();

    // Accept default test code '123456' or whatever was stored
    if (otpCode == '123456' || _pendingOtpsByEmail[normalizedEmail] == otpCode) {
      return true;
    }
    throw Exception('Invalid verification code. Please check and try again.');
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final normalizedEmail = email.trim().toLowerCase();

    final cred = _usersByEmail[normalizedEmail];
    if (cred != null) {
      _usersByEmail[normalizedEmail] = _UserCredential(
        user: cred.user,
        password: newPassword,
      );
    }
    _pendingOtpsByEmail.remove(normalizedEmail);
    return true;
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _currentSession;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _currentSession = null;
  }

  @override
  Future<List<GymTenantModel>> getGymTenants() async {
    return _tenantsById.values.toList();
  }

  @override
  Future<GymTenantModel> updateGymTenant(GymTenantModel tenant) async {
    _tenantsById[tenant.id] = tenant;
    return tenant;
  }

  @override
  Future<void> toggleGymStatus({
    required String tenantId,
    required bool isActive,
  }) async {
    final existing = _tenantsById[tenantId];
    if (existing != null) {
      _tenantsById[tenantId] = existing.copyWith(
        status: isActive ? TenantStatus.active : TenantStatus.suspended,
      );
    }
  }

  // Plans state (starts empty until created in backend/Firestore)
  final List<PlatformPlanModel> _plans = [];

  @override
  Future<List<PlatformPlanModel>> getPlatformPlans() async {
    return List.unmodifiable(_plans);
  }

  @override
  Future<PlatformPlanModel> createPlatformPlan(PlatformPlanModel plan) async {
    final planWithId = plan.id.isEmpty
        ? plan.copyWith(id: 'plan_${DateTime.now().millisecondsSinceEpoch}')
        : plan;
    _plans.add(planWithId);
    return planWithId;
  }

  @override
  Future<PlatformPlanModel> updatePlatformPlan(PlatformPlanModel plan) async {
    final idx = _plans.indexWhere((p) => p.id == plan.id);
    if (idx != -1) {
      _plans[idx] = plan;
    } else {
      _plans.add(plan);
    }
    return plan;
  }

  @override
  Future<void> togglePlatformPlanStatus(String planId) async {
    final idx = _plans.indexWhere((p) => p.id == planId);
    if (idx != -1) {
      _plans[idx] = _plans[idx].copyWith(isActive: !_plans[idx].isActive);
    }
  }

  // ── Team Members Mock State ──
  final Map<String, List<GymTeamMemberRecord>> _teamMembersByTenant = {};

  @override
  Future<String?> uploadTeamMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    return 'https://firebasestorage.googleapis.com/v0/b/gcrm-one.appspot.com/o/tenants%2F$tenantId%2Fteam_members%2F$memberId.$fileExtension?alt=media';
  }

  @override
  Future<List<GymTeamMemberRecord>> getTeamMembers({required String tenantId}) async {
    if (!_teamMembersByTenant.containsKey(tenantId)) {
      _teamMembersByTenant[tenantId] = [];
    }
    return List.unmodifiable(_teamMembersByTenant[tenantId]!);
  }

  @override
  Future<GymTeamMemberRecord> addTeamMember({
    required String tenantId,
    required GymTeamMemberRecord member,
    List<int>? photoBytes,
  }) async {
    if (!_teamMembersByTenant.containsKey(tenantId)) {
      _teamMembersByTenant[tenantId] = [];
    }
    final memberWithTenant = member.copyWith(
      tenantId: tenantId,
      createdAt: DateTime.now(),
    );
    _teamMembersByTenant[tenantId]!.insert(0, memberWithTenant);
    return memberWithTenant;
  }

  @override
  Future<GymTeamMemberRecord> updateTeamMember({
    required String tenantId,
    required GymTeamMemberRecord member,
    List<int>? photoBytes,
  }) async {
    if (!_teamMembersByTenant.containsKey(tenantId)) {
      _teamMembersByTenant[tenantId] = [];
    }
    final list = _teamMembersByTenant[tenantId]!;
    final idx = list.indexWhere((m) => m.id == member.id);
    String? imageUrl = member.imageUrl;
    if ((imageUrl == null || imageUrl.isEmpty) && photoBytes != null && photoBytes.isNotEmpty) {
      imageUrl = 'https://firebasestorage.googleapis.com/v0/b/gcrm-one.firebasestorage.app/o/tenants%2F$tenantId%2Fteam_members%2F${member.id}.jpg?alt=media';
    }
    final updated = member.copyWith(
      tenantId: tenantId,
      imageUrl: imageUrl ?? (idx != -1 ? list[idx].imageUrl : null),
    );
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    return updated;
  }

  @override
  Future<void> deleteTeamMember({
    required String tenantId,
    required String memberId,
  }) async {
    if (_teamMembersByTenant.containsKey(tenantId)) {
      _teamMembersByTenant[tenantId]!.removeWhere((m) => m.id == memberId);
    }
  }

  @override
  Future<void> toggleTeamMemberDuty({
    required String tenantId,
    required String memberId,
    required bool isOnDuty,
  }) async {
    if (_teamMembersByTenant.containsKey(tenantId)) {
      final list = _teamMembersByTenant[tenantId]!;
      final idx = list.indexWhere((m) => m.id == memberId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(isOnDuty: isOnDuty);
      }
    }
  }

  @override
  Future<void> updateTeamMemberAttendance({
    required String tenantId,
    required String memberId,
    required String dateKey,
    required bool isPresent,
  }) async {
    if (_teamMembersByTenant.containsKey(tenantId)) {
      final list = _teamMembersByTenant[tenantId]!;
      final idx = list.indexWhere((m) => m.id == memberId);
      if (idx != -1) {
        final current = Map<String, bool>.from(list[idx].attendanceLogs);
        current[dateKey] = isPresent;
        list[idx] = list[idx].copyWith(attendanceLogs: current);
      }
    }
  }

  // ── Gym Membership Plans Mock State & Methods ──
  @override
  Future<List<GymMembershipPlanModel>> getGymMembershipPlans({
    required String tenantId,
  }) async {
    if (!_membershipPlansByTenant.containsKey(tenantId)) {
      _membershipPlansByTenant[tenantId] = [];
    }
    return List.unmodifiable(_membershipPlansByTenant[tenantId]!);
  }

  @override
  Future<GymMembershipPlanModel> addGymMembershipPlan({
    required String tenantId,
    required GymMembershipPlanModel plan,
  }) async {
    if (!_membershipPlansByTenant.containsKey(tenantId)) {
      _membershipPlansByTenant[tenantId] = [];
    }
    final newPlan = plan.copyWith(
      id: plan.id.isEmpty
          ? 'gplan_${DateTime.now().millisecondsSinceEpoch}'
          : plan.id,
      tenantId: tenantId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _membershipPlansByTenant[tenantId]!.insert(0, newPlan);
    return newPlan;
  }

  @override
  Future<GymMembershipPlanModel> updateGymMembershipPlan({
    required String tenantId,
    required GymMembershipPlanModel plan,
  }) async {
    if (!_membershipPlansByTenant.containsKey(tenantId)) {
      _membershipPlansByTenant[tenantId] = [];
    }
    final list = _membershipPlansByTenant[tenantId]!;
    final idx = list.indexWhere((p) => p.id == plan.id);
    final updated = plan.copyWith(
      tenantId: tenantId,
      updatedAt: DateTime.now(),
    );
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    return updated;
  }

  @override
  Future<void> deleteGymMembershipPlan({
    required String tenantId,
    required String planId,
  }) async {
    if (_membershipPlansByTenant.containsKey(tenantId)) {
      _membershipPlansByTenant[tenantId]!.removeWhere((p) => p.id == planId);
    }
  }

  @override
  Future<void> toggleGymMembershipPlanStatus({
    required String tenantId,
    required String planId,
    required bool isActive,
  }) async {
    if (_membershipPlansByTenant.containsKey(tenantId)) {
      final list = _membershipPlansByTenant[tenantId]!;
      final idx = list.indexWhere((p) => p.id == planId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          isActive: isActive,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  // ── Gym Batches Mock Methods ──
  @override
  Future<List<GymBatchModel>> getGymBatches({
    required String tenantId,
  }) async {
    return List.from(_batchesByTenant[tenantId] ?? []);
  }

  @override
  Future<GymBatchModel> addGymBatch({
    required String tenantId,
    required GymBatchModel batch,
  }) async {
    final newBatch = batch.copyWith(
      id: batch.id.isNotEmpty ? batch.id : 'btch_${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      createdAt: batch.createdAt ?? DateTime.now(),
      updatedAt: batch.updatedAt ?? DateTime.now(),
    );

    _batchesByTenant.putIfAbsent(tenantId, () => []);
    _batchesByTenant[tenantId]!.add(newBatch);
    return newBatch;
  }

  @override
  Future<GymBatchModel> updateGymBatch({
    required String tenantId,
    required GymBatchModel batch,
  }) async {
    final updated = batch.copyWith(
      tenantId: tenantId,
      updatedAt: DateTime.now(),
    );

    if (_batchesByTenant.containsKey(tenantId)) {
      final list = _batchesByTenant[tenantId]!;
      final idx = list.indexWhere((b) => b.id == batch.id);
      if (idx != -1) {
        list[idx] = updated;
      } else {
        list.add(updated);
      }
    } else {
      _batchesByTenant[tenantId] = [updated];
    }
    return updated;
  }

  @override
  Future<void> deleteGymBatch({
    required String tenantId,
    required String batchId,
  }) async {
    if (_batchesByTenant.containsKey(tenantId)) {
      _batchesByTenant[tenantId]!.removeWhere((b) => b.id == batchId);
    }
  }

  @override
  Future<void> toggleGymBatchStatus({
    required String tenantId,
    required String batchId,
    required bool isActive,
  }) async {
    if (_batchesByTenant.containsKey(tenantId)) {
      final list = _batchesByTenant[tenantId]!;
      final idx = list.indexWhere((b) => b.id == batchId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          isActive: isActive,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  // ── Gym Members Mock State & Methods ──
  @override
  Future<List<GymMemberModel>> getGymMembers({
    required String tenantId,
    int limit = 20,
    String statusFilter = 'All',
  }) async {
    final res = await getPaginatedGymMembers(
      tenantId: tenantId,
      limit: limit,
      statusFilter: statusFilter,
    );
    return res.members;
  }

  @override
  Future<PaginatedMembersResult> getPaginatedGymMembers({
    required String tenantId,
    int limit = 20,
    dynamic lastDocument,
    String statusFilter = 'All',
  }) async {
    if (!_membersByTenant.containsKey(tenantId)) {
      _membersByTenant[tenantId] = [];
    }
    final all = _membersByTenant[tenantId]!;

    final filtered = all.where((m) {
      if (statusFilter == 'Active') {
        return m.isActive;
      } else if (statusFilter == 'Expiring') {
        final now = DateTime.now();
        final daysUntilExpiry = m.expiryDate.difference(now).inDays;
        return m.isActive && daysUntilExpiry <= 7;
      } else if (statusFilter == 'Expired') {
        return !m.isActive || m.expiryDate.isBefore(DateTime.now());
      }
      return true;
    }).toList();

    int startIdx = 0;
    if (lastDocument is int) {
      startIdx = lastDocument;
    } else if (lastDocument is String) {
      final idx = filtered.indexWhere((m) => m.id == lastDocument);
      if (idx != -1) startIdx = idx + 1;
    }

    final endIdx = (startIdx + limit).clamp(0, filtered.length);
    final pageList = startIdx < filtered.length ? filtered.sublist(startIdx, endIdx) : <GymMemberModel>[];
    final hasMore = endIdx < filtered.length;
    final nextCursor = pageList.isNotEmpty ? endIdx : null;

    return PaginatedMembersResult(
      members: pageList,
      lastDocument: nextCursor,
      hasMore: hasMore,
      totalCount: filtered.length,
    );
  }

  @override
  Future<GymMemberModel> addGymMember({
    required String tenantId,
    required GymMemberModel member,
    List<int>? photoBytes,
  }) async {
    if (!_membersByTenant.containsKey(tenantId)) {
      _membersByTenant[tenantId] = [];
    }
    final memberId = member.id.isEmpty
        ? 'mem_${DateTime.now().millisecondsSinceEpoch}'
        : member.id;
    String? photoUrl = member.photoUrl;
    if ((photoUrl == null || photoUrl.isEmpty) && photoBytes != null && photoBytes.isNotEmpty) {
      photoUrl = 'https://firebasestorage.googleapis.com/v0/b/gcrm-one.firebasestorage.app/o/tenants%2F$tenantId%2Fmembers%2F$memberId.jpg?alt=media';
    }
    final newMember = member.copyWith(
      id: memberId,
      tenantId: tenantId,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _membersByTenant[tenantId]!.insert(0, newMember);
    return newMember;
  }

  @override
  Future<GymMemberModel> updateGymMember({
    required String tenantId,
    required GymMemberModel member,
    List<int>? photoBytes,
  }) async {
    if (!_membersByTenant.containsKey(tenantId)) {
      _membersByTenant[tenantId] = [];
    }
    final list = _membersByTenant[tenantId]!;
    final idx = list.indexWhere((m) => m.id == member.id);
    String? photoUrl = member.photoUrl;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      photoUrl = 'https://firebasestorage.googleapis.com/v0/b/gcrm-one.firebasestorage.app/o/tenants%2F$tenantId%2Fmembers%2F${member.id}.jpg?alt=media';
    }
    final updated = member.copyWith(
      tenantId: tenantId,
      photoUrl: photoUrl ?? (idx != -1 ? list[idx].photoUrl : null),
      updatedAt: DateTime.now(),
    );
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    return updated;
  }

  @override
  Future<void> deleteGymMember({
    required String tenantId,
    required String memberId,
  }) async {
    if (_membersByTenant.containsKey(tenantId)) {
      _membersByTenant[tenantId]!.removeWhere((m) => m.id == memberId);
    }
  }

  @override
  Future<GymCheckInLog> recordMemberCheckIn({
    required String tenantId,
    required String memberId,
    required String memberName,
    required String planName,
    String method = 'QR Scan',
  }) async {
    final now = DateTime.now();
    final log = GymCheckInLog(
      id: 'chk_${now.millisecondsSinceEpoch}',
      tenantId: tenantId,
      memberId: memberId,
      memberName: memberName,
      planName: planName,
      timestamp: now,
      method: method,
    );

    if (!_checkInsByTenant.containsKey(tenantId)) {
      _checkInsByTenant[tenantId] = [];
    }
    _checkInsByTenant[tenantId]!.insert(0, log);

    if (_membersByTenant.containsKey(tenantId)) {
      final list = _membersByTenant[tenantId]!;
      final idx = list.indexWhere((m) => m.id == memberId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          totalCheckIns: list[idx].totalCheckIns + 1,
          lastCheckIn: now,
          updatedAt: now,
        );
      }
    }

    return log;
  }

  @override
  Future<List<GymCheckInLog>> getGymCheckIns({
    required String tenantId,
    int limit = 50,
  }) async {
    if (!_checkInsByTenant.containsKey(tenantId)) {
      _checkInsByTenant[tenantId] = [];
    }
    final logs = _checkInsByTenant[tenantId]!;
    return List.unmodifiable(logs.take(limit));
  }

  @override
  Future<String?> uploadGymMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    final rawUint8 = imageBytes is Uint8List
        ? imageBytes
        : Uint8List.fromList(imageBytes);
    final opt = await ImageOptimizer.optimizeImage(
      rawUint8,
      maxDimension: 512,
      quality: 80,
    );
    return opt.base64DataUri;
  }

  @override
  Future<String?> uploadUserProfilePhoto({
    required String userId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    final rawUint8 = imageBytes is Uint8List
        ? imageBytes
        : Uint8List.fromList(imageBytes);
    final opt = await ImageOptimizer.optimizeImage(
      rawUint8,
      maxDimension: 512,
      quality: 85,
    );
    return opt.base64DataUri;
  }

  // ── Gym Operating Expenses Mock Methods ──
  @override
  Future<List<GymExpenseRecord>> getGymExpenses({
    required String tenantId,
    int limit = 50,
  }) async {
    if (!_expensesByTenant.containsKey(tenantId)) {
      _expensesByTenant[tenantId] = [];
    }
    final all = _expensesByTenant[tenantId]!;
    if (all.length > limit) {
      return List.unmodifiable(all.take(limit));
    }
    return List.unmodifiable(all);
  }

  @override
  Future<GymExpenseRecord> addGymExpense({
    required String tenantId,
    required GymExpenseRecord expense,
  }) async {
    if (!_expensesByTenant.containsKey(tenantId)) {
      _expensesByTenant[tenantId] = [];
    }
    final expId = expense.id.isEmpty
        ? 'exp_${DateTime.now().millisecondsSinceEpoch}'
        : expense.id;
    final newExp = expense.copyWith(
      id: expId,
      tenantId: tenantId,
    );
    _expensesByTenant[tenantId]!.insert(0, newExp);
    return newExp;
  }

  @override
  Future<GymExpenseRecord> updateGymExpense({
    required String tenantId,
    required GymExpenseRecord expense,
  }) async {
    if (!_expensesByTenant.containsKey(tenantId)) {
      _expensesByTenant[tenantId] = [];
    }
    final list = _expensesByTenant[tenantId]!;
    final idx = list.indexWhere((e) => e.id == expense.id);
    final updated = expense.copyWith(tenantId: tenantId);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    return updated;
  }

  @override
  Future<void> deleteGymExpense({
    required String tenantId,
    required String expenseId,
  }) async {
    if (_expensesByTenant.containsKey(tenantId)) {
      _expensesByTenant[tenantId]!.removeWhere((e) => e.id == expenseId);
    }
  }
}

class _UserCredential {
  final UserModel user;
  final String password;

  _UserCredential({required this.user, required this.password});
}
