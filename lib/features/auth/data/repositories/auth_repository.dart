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
import '../models/gym_gallery_item_model.dart';
import '../models/push_notification_model.dart';

/// Abstract contract for Authentication & Tenant Onboarding in GCRM One.
/// Can be implemented by MockAuthService, FirebaseAuthService, SupabaseAuthService,
/// or custom REST/GraphQL Backend.
abstract class AuthRepository {
  /// Sign in with email and password, validating role & tenant status
  Future<AuthSession> login({
    required String email,
    required String password,
    UserRole? requestedRole,
    bool rememberMe = true,
  });

  /// Sign in specifically to the platform Super Admin portal
  Future<AuthSession> loginSuperAdmin({
    required String email,
    required String password,
    String? securityCode,
    bool rememberMe = true,
  });

  /// Register / Create a platform Super Administrator account
  Future<AuthSession> registerSuperAdmin({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    String? securityPin,
    String? organization,
  });

  /// Register a new Gym Vendor (Tenant onboarding)
  Future<AuthSession> registerGymVendor({
    required String gymName,
    required String tradeLicense,
    required String address,
    required String ownerFullName,
    required String email,
    required String password,
    required String phone,
    SubscriptionTier tier = SubscriptionTier.growth,
  });

  /// Register / Onboard a new Gym facility along with its Admin login account (Super Admin level)
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
  });

  /// Uploads optimized gym logo image to Firebase Storage and returns the public download URL
  Future<String?> uploadGymLogo({
    required String gymId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  });

  /// Uploads optimized team member avatar photo to Firebase Storage and returns the public download URL
  Future<String?> uploadTeamMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  });

  /// Register a new gym member with invite / gym branch code
  Future<AuthSession> registerMember({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String gymCode,
  });

  /// Request password recovery code
  Future<bool> requestPasswordReset({required String email});

  /// Verify 6-digit OTP code
  Future<bool> verifyOtp({required String email, required String otpCode});

  /// Complete password reset
  Future<bool> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  });

  /// Check persisted session on app launch
  Future<AuthSession?> getCurrentSession();

  /// Terminate active session
  Future<void> logout();

  /// Fetch all gym tenants (Super Admin level)
  Future<List<GymTenantModel>> getGymTenants();

  /// Update an existing gym tenant facility details (Super Admin level)
  Future<GymTenantModel> updateGymTenant(GymTenantModel tenant);

  /// Toggle active / suspended status for a gym tenant
  Future<void> toggleGymStatus({
    required String tenantId,
    required bool isActive,
  });

  /// Fetch all platform subscription plans (Super Admin level)
  Future<List<PlatformPlanModel>> getPlatformPlans();

  /// Create a new platform subscription plan in Firestore / backend
  Future<PlatformPlanModel> createPlatformPlan(PlatformPlanModel plan);

  /// Update an existing platform subscription plan
  Future<PlatformPlanModel> updatePlatformPlan(PlatformPlanModel plan);

  /// Toggle active/disabled status for a platform subscription plan
  Future<void> togglePlatformPlanStatus(String planId);

  /// Fetch team members / staff belonging to a gym facility
  Future<List<GymTeamMemberRecord>> getTeamMembers({required String tenantId});

  /// Add a new team member to Firestore / Firebase Storage
  Future<GymTeamMemberRecord> addTeamMember({
    required String tenantId,
    required GymTeamMemberRecord member,
    List<int>? photoBytes,
  });

  /// Update an existing team member record in Firestore
  Future<GymTeamMemberRecord> updateTeamMember({
    required String tenantId,
    required GymTeamMemberRecord member,
    List<int>? photoBytes,
  });

  /// Delete a team member record from Firestore
  Future<void> deleteTeamMember({
    required String tenantId,
    required String memberId,
  });

  /// Toggle duty status for a team member
  Future<void> toggleTeamMemberDuty({
    required String tenantId,
    required String memberId,
    required bool isOnDuty,
  });

  /// Update attendance log for a specific date for a team member
  Future<void> updateTeamMemberAttendance({
    required String tenantId,
    required String memberId,
    required String dateKey,
    required bool isPresent,
  });

  /// Fetch membership plans created by a specific gym facility / tenant
  Future<List<GymMembershipPlanModel>> getGymMembershipPlans({
    required String tenantId,
  });

  /// Add a new gym membership plan in Firestore / backend
  Future<GymMembershipPlanModel> addGymMembershipPlan({
    required String tenantId,
    required GymMembershipPlanModel plan,
  });

  /// Update an existing gym membership plan in Firestore / backend
  Future<GymMembershipPlanModel> updateGymMembershipPlan({
    required String tenantId,
    required GymMembershipPlanModel plan,
  });

  /// Delete a gym membership plan from Firestore / backend
  Future<void> deleteGymMembershipPlan({
    required String tenantId,
    required String planId,
  });

  /// Toggle active / paused status for a gym membership plan
  Future<void> toggleGymMembershipPlanStatus({
    required String tenantId,
    required String planId,
    required bool isActive,
  });

  // ── Gym Batches Management Methods ──
  /// Fetch batches created by a specific gym facility / tenant
  Future<List<GymBatchModel>> getGymBatches({
    required String tenantId,
  });

  /// Add a new batch for a gym tenant
  Future<GymBatchModel> addGymBatch({
    required String tenantId,
    required GymBatchModel batch,
  });

  /// Update an existing batch for a gym tenant
  Future<GymBatchModel> updateGymBatch({
    required String tenantId,
    required GymBatchModel batch,
  });

  /// Delete a batch for a gym tenant
  Future<void> deleteGymBatch({
    required String tenantId,
    required String batchId,
  });

  /// Toggle active status for a batch
  Future<void> toggleGymBatchStatus({
    required String tenantId,
    required String batchId,
    required bool isActive,
  });

  // ── Gym Member Enrollment & Management Methods ──
  /// Fetch enrolled members for a specific gym tenant (with optional limit & status filter)
  Future<List<GymMemberModel>> getGymMembers({
    required String tenantId,
    int limit = 20,
    String statusFilter = 'All',
  });

  /// Fetch paginated gym members with cursor & server-side filter
  Future<PaginatedMembersResult> getPaginatedGymMembers({
    required String tenantId,
    int limit = 20,
    dynamic lastDocument,
    String statusFilter = 'All',
  });

  /// Add a new gym member under a tenant facility
  Future<GymMemberModel> addGymMember({
    required String tenantId,
    required GymMemberModel member,
    List<int>? photoBytes,
  });

  /// Update an existing gym member's details or membership
  Future<GymMemberModel> updateGymMember({
    required String tenantId,
    required GymMemberModel member,
    List<int>? photoBytes,
  });

  /// Delete a gym member from the system
  Future<void> deleteGymMember({
    required String tenantId,
    required String memberId,
  });

  /// Record a member attendance check-in
  Future<GymCheckInLog> recordMemberCheckIn({
    required String tenantId,
    required String memberId,
    required String memberName,
    required String planName,
    String method = 'QR Scan',
  });

  /// Fetch recent check-in activity logs from Firestore / backend
  Future<List<GymCheckInLog>> getGymCheckIns({
    required String tenantId,
    int limit = 50,
  });

  /// Upload and optimize member profile photo to Firebase Storage
  Future<String?> uploadGymMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  });

  /// Upload and optimize user account profile photo to Firebase Storage
  Future<String?> uploadUserProfilePhoto({
    required String userId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  });

  // ── Gym Operating Expenses & Outflow Methods ──
  /// Fetch operating expenses for a specific gym tenant with pagination / limit
  Future<List<GymExpenseRecord>> getGymExpenses({
    required String tenantId,
    int limit = 50,
  });

  /// Add / record a new operating expense transaction
  Future<GymExpenseRecord> addGymExpense({
    required String tenantId,
    required GymExpenseRecord expense,
  });

  /// Update an existing operating expense transaction
  Future<GymExpenseRecord> updateGymExpense({
    required String tenantId,
    required GymExpenseRecord expense,
  });

  /// Delete an operating expense record
  Future<void> deleteGymExpense({
    required String tenantId,
    required String expenseId,
  });

  // ── Gym Media Gallery Methods ──
  /// Fetch gallery media items for a specific gym tenant (capped at 25 total)
  Future<List<GymGalleryItemModel>> getGymGalleryItems({
    required String tenantId,
  });

  /// Upload batch of gallery items (up to 10 at once, optimized before upload)
  Future<List<GymGalleryItemModel>> uploadGymGalleryItems({
    required String tenantId,
    required List<GymGalleryUploadPayload> items,
    String uploadedBy = 'Admin',
  });

  /// Delete a media item from the gym gallery
  Future<void> deleteGymGalleryItem({
    required String tenantId,
    required String itemId,
  });

  // ── Super Admin Push Notification Methods ──
  /// Send a platform-wide, role-based, or gym-specific push notification broadcast
  Future<PushNotificationRecord> sendSuperAdminPushNotification({
    required String title,
    required String body,
    required String targetAudience,
    String? targetTenantId,
    String? targetGymName,
    String sound = 'notification.mp3',
    String? sentByName,
  });

  /// Fetch history of push notifications sent by Super Admin
  Future<List<PushNotificationRecord>> getSentNotificationsHistory({int limit = 50});
}

