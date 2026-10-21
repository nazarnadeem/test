import '../../../../core/config/white_label_config.dart';
import '../models/auth_session.dart';
import '../models/gym_batch_model.dart';
import '../models/gym_check_in_model.dart';
import '../models/gym_expense_model.dart';
import '../models/gym_gallery_item_model.dart';
import '../models/gym_member_model.dart';
import '../models/gym_membership_plan_model.dart';
import '../models/gym_team_member_model.dart';
import '../models/gym_tenant_model.dart';
import '../models/platform_plan_model.dart';
import '../models/push_notification_model.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// Keeps a white-label build inside the two gyms named in its env file.
///
/// The platform app passes every call through. A white-label app rejects
/// other tenant ids before they reach Firestore.
class TenantScopedAuthRepository implements AuthRepository {
  /// Repository that talks to Firebase or the in-memory fallback.
  final AuthRepository _inner;

  /// Wraps [inner] with the current [WhiteLabelConfig] rules.
  TenantScopedAuthRepository(this._inner);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    UserRole? requestedRole,
    bool rememberMe = true,
  }) {
    return _guardSession(
      _inner.login(
        email: email,
        password: password,
        requestedRole: requestedRole,
        rememberMe: rememberMe,
      ),
    );
  }

  @override
  Future<AuthSession> loginSuperAdmin({
    required String email,
    required String password,
    String? securityCode,
    bool rememberMe = true,
  }) async {
    WhiteLabelConfig.ensurePlatformAdminAllowed();
    return _guardSession(
      _inner.loginSuperAdmin(
        email: email,
        password: password,
        securityCode: securityCode,
        rememberMe: rememberMe,
      ),
    );
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
    WhiteLabelConfig.ensurePlatformAdminAllowed();
    return _guardSession(
      _inner.registerSuperAdmin(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        securityPin: securityPin,
        organization: organization,
      ),
    );
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
    WhiteLabelConfig.ensureGymCreationAllowed();
    return _guardSession(
      _inner.registerGymVendor(
        gymName: gymName,
        tradeLicense: tradeLicense,
        address: address,
        ownerFullName: ownerFullName,
        email: email,
        password: password,
        phone: phone,
        tier: tier,
      ),
    );
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
  }) {
    WhiteLabelConfig.ensureGymCreationAllowed();
    return _inner.registerGymWithAdmin(
      gymName: gymName,
      ownerFullName: ownerFullName,
      ownerEmail: ownerEmail,
      phone: phone,
      address: address,
      adminName: adminName,
      adminEmail: adminEmail,
      adminPassword: adminPassword,
      logoBytes: logoBytes,
      logoUrl: logoUrl,
      primaryColorHex: primaryColorHex,
      tier: tier,
      planId: planId,
      planName: planName,
      planPrice: planPrice,
      billingPeriod: billingPeriod,
      planStartDate: planStartDate,
      planExpiryDate: planExpiryDate,
      isLifetimeFree: isLifetimeFree,
    );
  }

  @override
  Future<String?> uploadGymLogo({
    required String gymId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) {
    WhiteLabelConfig.ensureTenant(gymId);
    return _inner.uploadGymLogo(
      gymId: gymId,
      imageBytes: imageBytes,
      fileExtension: fileExtension,
    );
  }

  @override
  Future<String?> uploadTeamMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.uploadTeamMemberPhoto(
      tenantId: tenantId,
      memberId: memberId,
      imageBytes: imageBytes,
      fileExtension: fileExtension,
    );
  }

  @override
  Future<AuthSession> registerMember({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String gymCode,
  }) {
    return _guardSession(
      _inner.registerMember(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        gymCode: gymCode,
      ),
    );
  }

  @override
  Future<bool> requestPasswordReset({required String email}) {
    return _inner.requestPasswordReset(email: email);
  }

  @override
  Future<bool> verifyOtp({required String email, required String otpCode}) {
    return _inner.verifyOtp(email: email, otpCode: otpCode);
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) {
    return _inner.resetPassword(
      email: email,
      otpCode: otpCode,
      newPassword: newPassword,
    );
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    final session = await _inner.getCurrentSession();
    if (session == null) return null;
    if (WhiteLabelConfig.allows(session.user.tenantId)) return session;
    await _inner.logout();
    return null;
  }

  @override
  Future<void> logout() => _inner.logout();

  @override
  Future<List<GymTenantModel>> getGymTenants() async {
    final tenants = await _inner.getGymTenants();
    if (!WhiteLabelConfig.isRestricted) return tenants;
    return tenants.where((tenant) => WhiteLabelConfig.allows(tenant.id)).toList();
  }

  @override
  Future<GymTenantModel> updateGymTenant(GymTenantModel tenant) {
    WhiteLabelConfig.ensureTenant(tenant.id);
    return _inner.updateGymTenant(tenant);
  }

  @override
  Future<void> toggleGymStatus({
    required String tenantId,
    required bool isActive,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.toggleGymStatus(tenantId: tenantId, isActive: isActive);
  }

  @override
  Future<List<PlatformPlanModel>> getPlatformPlans() => _inner.getPlatformPlans();

  @override
  Future<PlatformPlanModel> createPlatformPlan(PlatformPlanModel plan) {
    WhiteLabelConfig.ensurePlatformAdminAllowed();
    return _inner.createPlatformPlan(plan);
  }

  @override
  Future<PlatformPlanModel> updatePlatformPlan(PlatformPlanModel plan) {
    WhiteLabelConfig.ensurePlatformAdminAllowed();
    return _inner.updatePlatformPlan(plan);
  }

  @override
  Future<void> togglePlatformPlanStatus(String planId) {
    WhiteLabelConfig.ensurePlatformAdminAllowed();
    return _inner.togglePlatformPlanStatus(planId);
  }

  @override
  Future<List<GymTeamMemberRecord>> getTeamMembers({required String tenantId}) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.getTeamMembers(tenantId: tenantId);
  }

  @override
  Future<GymTeamMemberRecord> addTeamMember({
    required String tenantId,
    required GymTeamMemberRecord member,
    List<int>? photoBytes,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.addTeamMember(
      tenantId: tenantId,
      member: member,
      photoBytes: photoBytes,
    );
  }

  @override
  Future<GymTeamMemberRecord> updateTeamMember({
    required String tenantId,
    required GymTeamMemberRecord member,
    List<int>? photoBytes,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.updateTeamMember(
      tenantId: tenantId,
      member: member,
      photoBytes: photoBytes,
    );
  }

  @override
  Future<void> deleteTeamMember({
    required String tenantId,
    required String memberId,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.deleteTeamMember(tenantId: tenantId, memberId: memberId);
  }

  @override
  Future<void> toggleTeamMemberDuty({
    required String tenantId,
    required String memberId,
    required bool isOnDuty,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.toggleTeamMemberDuty(
      tenantId: tenantId,
      memberId: memberId,
      isOnDuty: isOnDuty,
    );
  }

  @override
  Future<void> updateTeamMemberAttendance({
    required String tenantId,
    required String memberId,
    required String dateKey,
    required bool isPresent,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.updateTeamMemberAttendance(
      tenantId: tenantId,
      memberId: memberId,
      dateKey: dateKey,
      isPresent: isPresent,
    );
  }

  @override
  Future<List<GymMembershipPlanModel>> getGymMembershipPlans({
    required String tenantId,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.getGymMembershipPlans(tenantId: tenantId);
  }

  @override
  Future<GymMembershipPlanModel> addGymMembershipPlan({
    required String tenantId,
    required GymMembershipPlanModel plan,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.addGymMembershipPlan(tenantId: tenantId, plan: plan);
  }

  @override
  Future<GymMembershipPlanModel> updateGymMembershipPlan({
    required String tenantId,
    required GymMembershipPlanModel plan,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.updateGymMembershipPlan(tenantId: tenantId, plan: plan);
  }

  @override
  Future<void> deleteGymMembershipPlan({
    required String tenantId,
    required String planId,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.deleteGymMembershipPlan(tenantId: tenantId, planId: planId);
  }

  @override
  Future<void> toggleGymMembershipPlanStatus({
    required String tenantId,
    required String planId,
    required bool isActive,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.toggleGymMembershipPlanStatus(
      tenantId: tenantId,
      planId: planId,
      isActive: isActive,
    );
  }

  @override
  Future<List<GymBatchModel>> getGymBatches({required String tenantId}) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.getGymBatches(tenantId: tenantId);
  }

  @override
  Future<GymBatchModel> addGymBatch({
    required String tenantId,
    required GymBatchModel batch,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.addGymBatch(tenantId: tenantId, batch: batch);
  }

  @override
  Future<GymBatchModel> updateGymBatch({
    required String tenantId,
    required GymBatchModel batch,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.updateGymBatch(tenantId: tenantId, batch: batch);
  }

  @override
  Future<void> deleteGymBatch({
    required String tenantId,
    required String batchId,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.deleteGymBatch(tenantId: tenantId, batchId: batchId);
  }

  @override
  Future<void> toggleGymBatchStatus({
    required String tenantId,
    required String batchId,
    required bool isActive,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.toggleGymBatchStatus(
      tenantId: tenantId,
      batchId: batchId,
      isActive: isActive,
    );
  }

  @override
  Future<List<GymMemberModel>> getGymMembers({
    required String tenantId,
    int limit = 20,
    String statusFilter = 'All',
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.getGymMembers(
      tenantId: tenantId,
      limit: limit,
      statusFilter: statusFilter,
    );
  }

  @override
  Future<PaginatedMembersResult> getPaginatedGymMembers({
    required String tenantId,
    int limit = 20,
    dynamic lastDocument,
    String statusFilter = 'All',
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.getPaginatedGymMembers(
      tenantId: tenantId,
      limit: limit,
      lastDocument: lastDocument,
      statusFilter: statusFilter,
    );
  }

  @override
  Future<GymMemberModel> addGymMember({
    required String tenantId,
    required GymMemberModel member,
    List<int>? photoBytes,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.addGymMember(
      tenantId: tenantId,
      member: member,
      photoBytes: photoBytes,
    );
  }

  @override
  Future<GymMemberModel> updateGymMember({
    required String tenantId,
    required GymMemberModel member,
    List<int>? photoBytes,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.updateGymMember(
      tenantId: tenantId,
      member: member,
      photoBytes: photoBytes,
    );
  }

  @override
  Future<void> deleteGymMember({
    required String tenantId,
    required String memberId,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.deleteGymMember(tenantId: tenantId, memberId: memberId);
  }

  @override
  Future<GymCheckInLog> recordMemberCheckIn({
    required String tenantId,
    required String memberId,
    required String memberName,
    required String planName,
    String method = 'QR Scan',
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.recordMemberCheckIn(
      tenantId: tenantId,
      memberId: memberId,
      memberName: memberName,
      planName: planName,
      method: method,
    );
  }

  @override
  Future<List<GymCheckInLog>> getGymCheckIns({
    required String tenantId,
    int limit = 50,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.getGymCheckIns(tenantId: tenantId, limit: limit);
  }

  @override
  Future<String?> uploadGymMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.uploadGymMemberPhoto(
      tenantId: tenantId,
      memberId: memberId,
      imageBytes: imageBytes,
      fileExtension: fileExtension,
    );
  }

  @override
  Future<String?> uploadUserProfilePhoto({
    required String userId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) {
    return _inner.uploadUserProfilePhoto(
      userId: userId,
      imageBytes: imageBytes,
      fileExtension: fileExtension,
    );
  }

  @override
  Future<List<GymExpenseRecord>> getGymExpenses({
    required String tenantId,
    int limit = 50,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.getGymExpenses(tenantId: tenantId, limit: limit);
  }

  @override
  Future<GymExpenseRecord> addGymExpense({
    required String tenantId,
    required GymExpenseRecord expense,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.addGymExpense(tenantId: tenantId, expense: expense);
  }

  @override
  Future<GymExpenseRecord> updateGymExpense({
    required String tenantId,
    required GymExpenseRecord expense,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.updateGymExpense(tenantId: tenantId, expense: expense);
  }

  @override
  Future<void> deleteGymExpense({
    required String tenantId,
    required String expenseId,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.deleteGymExpense(tenantId: tenantId, expenseId: expenseId);
  }

  @override
  Future<List<GymGalleryItemModel>> getGymGalleryItems({
    required String tenantId,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.getGymGalleryItems(tenantId: tenantId);
  }

  @override
  Future<List<GymGalleryItemModel>> uploadGymGalleryItems({
    required String tenantId,
    required List<GymGalleryUploadPayload> items,
    String uploadedBy = 'Admin',
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.uploadGymGalleryItems(
      tenantId: tenantId,
      items: items,
      uploadedBy: uploadedBy,
    );
  }

  @override
  Future<void> deleteGymGalleryItem({
    required String tenantId,
    required String itemId,
  }) {
    WhiteLabelConfig.ensureTenant(tenantId);
    return _inner.deleteGymGalleryItem(tenantId: tenantId, itemId: itemId);
  }

  @override
  Future<PushNotificationRecord> sendSuperAdminPushNotification({
    required String title,
    required String body,
    required String targetAudience,
    String? targetTenantId,
    String? targetGymName,
    String sound = 'notification.mp3',
    String? sentByName,
  }) {
    WhiteLabelConfig.ensureBroadcast(
      targetAudience: targetAudience,
      targetTenantId: targetTenantId,
    );
    return _inner.sendSuperAdminPushNotification(
      title: title,
      body: body,
      targetAudience: targetAudience,
      targetTenantId: targetTenantId,
      targetGymName: targetGymName,
      sound: sound,
      sentByName: sentByName,
    );
  }

  @override
  Future<SentNotificationPage> getSentNotificationsHistory({
    int limit = SentNotificationPage.pageSize,
    bool reset = true,
  }) async {
    final page = await _inner.getSentNotificationsHistory(limit: limit, reset: reset);
    if (!WhiteLabelConfig.isRestricted) return page;
    return SentNotificationPage(
      records: page.records
          .where((record) => WhiteLabelConfig.allows(record.targetTenantId))
          .toList(),
      hasMore: page.hasMore,
    );
  }

  Future<AuthSession> _guardSession(Future<AuthSession> pending) async {
    try {
      final session = await pending;
      WhiteLabelConfig.ensureAccount(session.user.tenantId);
      return session;
    } on TenantAccessException {
      try {
        await _inner.logout();
      } catch (_) {}
      rethrow;
    }
  }
}
