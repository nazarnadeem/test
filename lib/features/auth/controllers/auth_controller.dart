import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/models/gym_tenant_model.dart';
import '../data/models/platform_plan_model.dart';
import '../data/models/auth_session.dart';
import '../data/models/gym_team_member_model.dart';
import '../data/models/gym_membership_plan_model.dart';
import '../data/models/gym_member_model.dart';
import '../data/models/gym_expense_model.dart';
import '../data/models/gym_check_in_model.dart';
import '../data/models/gym_batch_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/firebase_auth_service.dart';

/// Streamlined state manager for GCRM One Authentication and Firebase Login.
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthController({AuthRepository? authRepository})
      : _authRepository = authRepository ?? FirebaseAuthService();

  // State flags
  bool _isLoading = false;
  bool _isCheckingSession = true;
  String? _errorMessage;
  String? _successMessage;

  // Active Session Data
  AuthSession? _currentSession;
  List<GymTenantModel> _gymTenants = [];
  bool _isLoadingTenants = false;

  // Platform Subscription Plans
  List<PlatformPlanModel> _platformPlans = [];
  bool _isLoadingPlans = false;

  // Gym Team Members
  List<GymTeamMemberRecord> _teamMembers = [];
  bool _isLoadingTeam = false;

  // Gym Membership Plans
  List<GymMembershipPlanModel> _membershipPlans = [];
  bool _isLoadingMembershipPlans = false;

  // Gym Enrolled Members
  List<GymMemberModel> _members = [];
  bool _isLoadingMembers = false;

  // Gym Members Pagination & Server-side Filter state
  int _membersPageLimit = 20;
  int _currentMembersPage = 1;
  bool _hasMoreMembers = false;
  String _memberFilterStatus = 'All';
  dynamic _lastMemberDocument;
  int _totalMembersCount = 0;

  // Gym Operating Expenses
  List<GymExpenseRecord> _expenses = [];
  bool _isLoadingExpenses = false;

  // Live Gym Check-in Logs
  List<GymCheckInLog> _checkIns = [];
  bool _isLoadingCheckIns = false;

  // Gym Batches
  List<GymBatchModel> _batches = [];
  bool _isLoadingBatches = false;

  // --- In-Memory TTL Cache for Firestore Read Reduction ---
  DateTime? _lastTeamFetch;
  DateTime? _lastMembershipPlansFetch;
  DateTime? _lastMembersFetch;
  DateTime? _lastExpensesFetch;
  DateTime? _lastCheckInsFetch;
  DateTime? _lastBatchesFetch;
  DateTime? _lastTenantsFetch;
  static const Duration _cacheTtl = Duration(minutes: 5);

  // --- Getters ---
  bool get isLoading => _isLoading;
  bool get isCheckingSession => _isCheckingSession;
  bool get isAuthenticated => _currentSession != null && !_currentSession!.isExpired;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  AuthSession? get currentSession => _currentSession;
  UserModel? get currentUser => _currentSession?.user;
  List<GymTenantModel> get gymTenants => _gymTenants;
  bool get isLoadingTenants => _isLoadingTenants;
  List<PlatformPlanModel> get platformPlans => _platformPlans;
  bool get isLoadingPlans => _isLoadingPlans;
  List<GymTeamMemberRecord> get teamMembers => _teamMembers;
  bool get isLoadingTeam => _isLoadingTeam;
  List<GymMembershipPlanModel> get membershipPlans => _membershipPlans;
  bool get isLoadingMembershipPlans => _isLoadingMembershipPlans;
  List<GymBatchModel> get batches => _batches;
  bool get isLoadingBatches => _isLoadingBatches;
  List<GymMemberModel> get members => _members;
  bool get isLoadingMembers => _isLoadingMembers;
  int get membersPageLimit => _membersPageLimit;
  int get currentMembersPage => _currentMembersPage;
  bool get hasMoreMembers => _hasMoreMembers;
  String get memberFilterStatus => _memberFilterStatus;
  int get totalMembersCount => _totalMembersCount;
  List<GymExpenseRecord> get expenses => _expenses;
  bool get isLoadingExpenses => _isLoadingExpenses;
  List<GymCheckInLog> get checkIns => _checkIns;
  bool get isLoadingCheckIns => _isLoadingCheckIns;

  /// Resolves the active Gym Tenant model for the logged in user
  GymTenantModel? get currentGymTenant {
    final user = currentUser;
    if (user == null) return null;
    final tid = user.tenantId;
    if (tid != null) {
      final match = _gymTenants.where((g) => g.id == tid);
      if (match.isNotEmpty) return match.first;
    }
    if (user.gymName != null && user.gymName!.isNotEmpty) {
      final match = _gymTenants.where((g) => g.gymName.toLowerCase() == user.gymName!.toLowerCase());
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }

  /// Active Gym Tenant ID fallback helper
  String get activeTenantId {
    return currentGymTenant?.id ?? currentUser?.tenantId ?? 'default_tenant';
  }

  // --- Plan Management (Connected to Backend & Cloud Firestore) ---

  /// Load all subscription plans from backend / Firestore
  Future<void> loadPlatformPlans() async {
    _isLoadingPlans = true;
    notifyListeners();
    try {
      final plans = await _authRepository.getPlatformPlans();
      _platformPlans = plans;
    } catch (_) {
    } finally {
      _isLoadingPlans = false;
      notifyListeners();
    }
  }

  /// Create a new platform subscription plan in Firestore
  Future<bool> addPlatformPlan(PlatformPlanModel newPlan) async {
    try {
      final createdPlan = await _authRepository.createPlatformPlan(newPlan);
      _platformPlans = [..._platformPlans, createdPlan];
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Update an existing subscription plan in Firestore
  Future<bool> updatePlatformPlan(PlatformPlanModel updatedPlan) async {
    try {
      final savedPlan = await _authRepository.updatePlatformPlan(updatedPlan);
      _platformPlans = _platformPlans
          .map((p) => p.id == savedPlan.id ? savedPlan : p)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Toggle active / disabled status for a subscription plan
  Future<void> togglePlatformPlanStatus(String planId) async {
    // Optimistic local update
    _platformPlans = _platformPlans.map((p) {
      if (p.id == planId) {
        return p.copyWith(isActive: !p.isActive);
      }
      return p;
    }).toList();
    notifyListeners();

    try {
      await _authRepository.togglePlatformPlanStatus(planId);
    } catch (_) {
      // Revert on error
      await loadPlatformPlans();
    }
  }

  // --- Team Members Management (Connected to Firebase & Firestore) ---

  /// Load team members belonging to a gym facility from Firestore (with TTL caching)
  Future<void> loadTeamMembers([String? tenantId, bool forceRefresh = false]) async {
    final tid = tenantId ?? activeTenantId;
    if (!forceRefresh && _teamMembers.isNotEmpty && _lastTeamFetch != null) {
      if (DateTime.now().difference(_lastTeamFetch!) < _cacheTtl) {
        return; // Cache hit - 0 Firestore reads
      }
    }
    _isLoadingTeam = true;
    notifyListeners();
    try {
      final members = await _authRepository.getTeamMembers(tenantId: tid);
      _teamMembers = members;
      _lastTeamFetch = DateTime.now();
    } catch (e) {
      debugPrint('Error loading team members: $e');
    } finally {
      _isLoadingTeam = false;
      notifyListeners();
    }
  }

  /// Add a new team member to Firestore and upload photo to Firebase Storage
  Future<bool> addTeamMember(
    GymTeamMemberRecord newMember, {
    List<int>? photoBytes,
  }) async {
    try {
      final tenantId = newMember.tenantId ?? activeTenantId;
      final createdMember = await _authRepository.addTeamMember(
        tenantId: tenantId,
        member: newMember,
        photoBytes: photoBytes,
      );
      _teamMembers = [createdMember, ..._teamMembers];
      _lastTeamFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Update an existing team member in Firestore
  Future<bool> updateTeamMember(GymTeamMemberRecord updatedMember, {List<int>? photoBytes}) async {
    try {
      final tenantId = updatedMember.tenantId ?? activeTenantId;
      final savedMember = await _authRepository.updateTeamMember(
        tenantId: tenantId,
        member: updatedMember,
        photoBytes: photoBytes,
      );
      _teamMembers = _teamMembers
          .map((m) => m.id == savedMember.id ? savedMember : m)
          .toList();
      _lastTeamFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Delete a team member from Firestore
  Future<bool> deleteTeamMember(String tenantId, String memberId) async {
    try {
      await _authRepository.deleteTeamMember(
        tenantId: tenantId,
        memberId: memberId,
      );
      _teamMembers = _teamMembers.where((m) => m.id != memberId).toList();
      _lastTeamFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Toggle duty status in Firestore
  Future<bool> toggleTeamMemberDuty(
    String tenantId,
    String memberId,
    bool isOnDuty,
  ) async {
    try {
      await _authRepository.toggleTeamMemberDuty(
        tenantId: tenantId,
        memberId: memberId,
        isOnDuty: isOnDuty,
      );
      _teamMembers = _teamMembers.map((m) {
        if (m.id == memberId) {
          return m.copyWith(isOnDuty: isOnDuty);
        }
        return m;
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Update attendance log for a specific date in Firestore
  Future<bool> updateTeamMemberAttendance({
    required String tenantId,
    required String memberId,
    required String dateKey,
    required bool isPresent,
  }) async {
    try {
      await _authRepository.updateTeamMemberAttendance(
        tenantId: tenantId,
        memberId: memberId,
        dateKey: dateKey,
        isPresent: isPresent,
      );
      _teamMembers = _teamMembers.map((m) {
        if (m.id == memberId) {
          final updatedLogs = Map<String, bool>.from(m.attendanceLogs);
          updatedLogs[dateKey] = isPresent;
          return m.copyWith(attendanceLogs: updatedLogs);
        }
        return m;
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // --- Gym Membership Plans Management ---

  /// Load membership plans for a gym facility from Firestore (with TTL caching)
  Future<void> loadGymMembershipPlans([String? tenantId, bool forceRefresh = false]) async {
    final tid = tenantId ?? activeTenantId;
    if (!forceRefresh && _membershipPlans.isNotEmpty && _lastMembershipPlansFetch != null) {
      if (DateTime.now().difference(_lastMembershipPlansFetch!) < _cacheTtl) {
        return; // Cache hit - 0 Firestore reads
      }
    }
    _isLoadingMembershipPlans = true;
    notifyListeners();
    try {
      final plans = await _authRepository.getGymMembershipPlans(tenantId: tid);
      _membershipPlans = plans;
      _lastMembershipPlansFetch = DateTime.now();
    } catch (e) {
      debugPrint('Error loading gym membership plans: $e');
    } finally {
      _isLoadingMembershipPlans = false;
      notifyListeners();
    }
  }

  /// Add a new membership plan for the gym
  Future<bool> addGymMembershipPlan(GymMembershipPlanModel newPlan) async {
    try {
      final tenantId = newPlan.tenantId ?? activeTenantId;
      final created = await _authRepository.addGymMembershipPlan(
        tenantId: tenantId,
        plan: newPlan,
      );
      _membershipPlans = [created, ..._membershipPlans];
      _lastMembershipPlansFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Update an existing membership plan
  Future<bool> updateGymMembershipPlan(GymMembershipPlanModel updatedPlan) async {
    try {
      final tenantId = updatedPlan.tenantId ?? activeTenantId;
      final saved = await _authRepository.updateGymMembershipPlan(
        tenantId: tenantId,
        plan: updatedPlan,
      );
      _membershipPlans = _membershipPlans
          .map((p) => p.id == saved.id ? saved : p)
          .toList();
      _lastMembershipPlansFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Delete a membership plan
  Future<bool> deleteGymMembershipPlan(String tenantId, String planId) async {
    try {
      await _authRepository.deleteGymMembershipPlan(
        tenantId: tenantId,
        planId: planId,
      );
      _membershipPlans =
          _membershipPlans.where((p) => p.id != planId).toList();
      _lastMembershipPlansFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Toggle active / paused status for a membership plan
  Future<bool> toggleGymMembershipPlanStatus(
    String tenantId,
    String planId,
    bool isActive,
  ) async {
    try {
      await _authRepository.toggleGymMembershipPlanStatus(
        tenantId: tenantId,
        planId: planId,
        isActive: isActive,
      );
      _membershipPlans = _membershipPlans.map((p) {
        if (p.id == planId) {
          return p.copyWith(isActive: isActive);
        }
        return p;
      }).toList();
      _lastMembershipPlansFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // --- Gym Batches Management ---

  /// Load batches for a gym facility from Firestore / repository (with TTL caching)
  Future<void> loadGymBatches([String? tenantId, bool forceRefresh = false]) async {
    final tid = tenantId ?? activeTenantId;
    if (!forceRefresh && _batches.isNotEmpty && _lastBatchesFetch != null) {
      if (DateTime.now().difference(_lastBatchesFetch!) < _cacheTtl) {
        return; // Cache hit
      }
    }
    _isLoadingBatches = true;
    notifyListeners();
    try {
      final loadedBatches = await _authRepository.getGymBatches(tenantId: tid);
      _batches = loadedBatches;
      _lastBatchesFetch = DateTime.now();
    } catch (e) {
      debugPrint('Error loading gym batches: $e');
    } finally {
      _isLoadingBatches = false;
      notifyListeners();
    }
  }

  /// Add a new batch for the gym facility
  Future<bool> addGymBatch(GymBatchModel batch) async {
    try {
      final tenantId = batch.tenantId ?? activeTenantId;
      final created = await _authRepository.addGymBatch(
        tenantId: tenantId,
        batch: batch,
      );
      _batches = [created, ..._batches];
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding gym batch: $e');
      return false;
    }
  }

  /// Update an existing gym batch
  Future<bool> updateGymBatch(GymBatchModel batch) async {
    try {
      final tenantId = batch.tenantId ?? activeTenantId;
      final updated = await _authRepository.updateGymBatch(
        tenantId: tenantId,
        batch: batch,
      );
      _batches = _batches.map((b) => b.id == updated.id ? updated : b).toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating gym batch: $e');
      return false;
    }
  }

  /// Delete a batch
  Future<bool> deleteGymBatch(String batchId, [String? tenantId]) async {
    try {
      final tid = tenantId ?? activeTenantId;
      await _authRepository.deleteGymBatch(
        tenantId: tid,
        batchId: batchId,
      );
      _batches = _batches.where((b) => b.id != batchId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting gym batch: $e');
      return false;
    }
  }

  /// Toggle active / paused status for a batch
  Future<bool> toggleGymBatchStatus(
    String batchId,
    bool isActive, [
    String? tenantId,
  ]) async {
    try {
      final tid = tenantId ?? activeTenantId;
      await _authRepository.toggleGymBatchStatus(
        tenantId: tid,
        batchId: batchId,
        isActive: isActive,
      );
      _batches = _batches.map((b) {
        if (b.id == batchId) {
          return b.copyWith(isActive: isActive);
        }
        return b;
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error toggling gym batch status: $e');
      return false;
    }
  }

  // ── Gym Member Management Operations ──

  /// Load enrolled members for a specific gym tenant (with Firestore server-side pagination & filter)
  Future<void> loadGymMembers({
    String? tenantId,
    bool forceRefresh = false,
    String filterStatus = 'All',
    bool loadNextPage = false,
    int limit = 20,
  }) async {
    final tid = tenantId ?? currentGymTenant?.id ?? currentUser?.tenantId;
    if (tid == null) return;

    if (!forceRefresh &&
        !loadNextPage &&
        filterStatus == _memberFilterStatus &&
        _members.isNotEmpty &&
        _lastMembersFetch != null) {
      if (DateTime.now().difference(_lastMembersFetch!) < _cacheTtl) {
        return; // Cache hit - 0 Firestore reads
      }
    }

    if (!loadNextPage || filterStatus != _memberFilterStatus) {
      _lastMemberDocument = null;
      _currentMembersPage = 1;
      _members = [];
    }

    _memberFilterStatus = filterStatus;
    _membersPageLimit = limit;
    _isLoadingMembers = true;
    notifyListeners();

    try {
      final res = await _authRepository.getPaginatedGymMembers(
        tenantId: tid,
        limit: limit,
        lastDocument: _lastMemberDocument,
        statusFilter: filterStatus,
      );

      if (loadNextPage) {
        _members = [..._members, ...res.members];
        _currentMembersPage++;
      } else {
        _members = res.members;
      }

      _lastMemberDocument = res.lastDocument;
      _hasMoreMembers = res.hasMore;
      _totalMembersCount = res.totalCount;
      _lastMembersFetch = DateTime.now();
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
    } finally {
      _isLoadingMembers = false;
      notifyListeners();
    }
  }

  /// Load next page of members from Firestore (Limit 20)
  Future<void> loadNextMembersPage([String? tenantId]) async {
    if (_isLoadingMembers || !_hasMoreMembers) return;
    await loadGymMembers(
      tenantId: tenantId,
      forceRefresh: true,
      filterStatus: _memberFilterStatus,
      loadNextPage: true,
      limit: _membersPageLimit,
    );
  }

  /// Add / enroll a new gym member
  Future<bool> addGymMember(GymMemberModel member, {List<int>? photoBytes}) async {
    final tenantId = member.tenantId ?? currentGymTenant?.id ?? currentUser?.tenantId ?? 'tenant_metro_01';
    try {
      final saved = await _authRepository.addGymMember(
        tenantId: tenantId,
        member: member.copyWith(tenantId: tenantId),
        photoBytes: photoBytes,
      );
      _members = [saved, ..._members.where((m) => m.id != saved.id)];
      _lastMembersFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Update an existing gym member
  Future<bool> updateGymMember(GymMemberModel member, {List<int>? photoBytes}) async {
    final tenantId = member.tenantId ?? currentGymTenant?.id ?? currentUser?.tenantId ?? 'tenant_metro_01';
    try {
      final saved = await _authRepository.updateGymMember(
        tenantId: tenantId,
        member: member.copyWith(tenantId: tenantId),
        photoBytes: photoBytes,
      );
      _members = _members.map((m) => m.id == saved.id ? saved : m).toList();
      _lastMembersFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Delete a gym member
  Future<bool> deleteGymMember(String tenantId, String memberId) async {
    try {
      await _authRepository.deleteGymMember(
        tenantId: tenantId,
        memberId: memberId,
      );
      _members = _members.where((m) => m.id != memberId).toList();
      _lastMembersFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Record a check-in for a gym member and save to live stream
  Future<GymCheckInLog?> recordMemberCheckIn({
    String? tenantId,
    required String memberId,
    required String memberName,
    required String planName,
    String method = 'QR Scan',
  }) async {
    final tid = tenantId ?? currentGymTenant?.id ?? currentUser?.tenantId ?? 'tenant_metro_01';
    try {
      final log = await _authRepository.recordMemberCheckIn(
        tenantId: tid,
        memberId: memberId,
        memberName: memberName,
        planName: planName,
        method: method,
      );

      _checkIns = [log, ..._checkIns.where((c) => c.id != log.id)];
      _lastCheckInsFetch = DateTime.now();

      _members = _members.map((m) {
        if (m.id == memberId) {
          return m.copyWith(
            totalCheckIns: m.totalCheckIns + 1,
            lastCheckIn: DateTime.now(),
          );
        }
        return m;
      }).toList();
      _lastMembersFetch = DateTime.now();

      notifyListeners();
      return log;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return null;
    }
  }

  /// Load recent check-in logs from Firestore (with TTL caching & limit)
  Future<void> loadGymCheckIns([String? tenantId, bool forceRefresh = false, int limit = 30]) async {
    final tid = tenantId ?? currentGymTenant?.id ?? currentUser?.tenantId;
    if (tid == null) return;

    if (!forceRefresh && _checkIns.isNotEmpty && _lastCheckInsFetch != null) {
      if (DateTime.now().difference(_lastCheckInsFetch!) < const Duration(seconds: 45)) {
        return; // Cache hit - 0 Firestore reads
      }
    }

    _isLoadingCheckIns = true;
    notifyListeners();

    try {
      _checkIns = await _authRepository.getGymCheckIns(tenantId: tid, limit: limit);
      _lastCheckInsFetch = DateTime.now();
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
    } finally {
      _isLoadingCheckIns = false;
      notifyListeners();
    }
  }

  /// Load operating expenses for a specific gym tenant (with TTL caching & limit)
  Future<void> loadGymExpenses([String? tenantId, bool forceRefresh = false, int limit = 50]) async {
    final tid = tenantId ?? currentGymTenant?.id ?? currentUser?.tenantId;
    if (tid == null) return;

    if (!forceRefresh && _expenses.isNotEmpty && _lastExpensesFetch != null) {
      if (DateTime.now().difference(_lastExpensesFetch!) < _cacheTtl) {
        return; // Cache hit - 0 Firestore reads
      }
    }

    _isLoadingExpenses = true;
    notifyListeners();

    try {
      _expenses = await _authRepository.getGymExpenses(tenantId: tid, limit: limit);
      _lastExpensesFetch = DateTime.now();
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
    } finally {
      _isLoadingExpenses = false;
      notifyListeners();
    }
  }

  /// Consolidated parallel loader for Gym Admin Dashboard Overview tab with smart caching
  Future<void> loadDashboardOverview({String? tenantId, bool forceRefresh = false}) async {
    final tid = tenantId ?? activeTenantId;
    await Future.wait([
      loadGymMembers(tenantId: tid, forceRefresh: forceRefresh),
      loadTeamMembers(tid, forceRefresh),
      loadGymMembershipPlans(tid, forceRefresh),
      loadGymBatches(tid, forceRefresh),
      loadGymExpenses(tid, forceRefresh, 50),
      loadGymCheckIns(tid, forceRefresh, 30),
    ]);
  }

  /// Add / record a new operating expense
  Future<bool> addGymExpense(GymExpenseRecord expense) async {
    final tenantId = expense.tenantId ?? currentGymTenant?.id ?? currentUser?.tenantId ?? 'tenant_metro_01';
    try {
      final saved = await _authRepository.addGymExpense(
        tenantId: tenantId,
        expense: expense.copyWith(tenantId: tenantId),
      );
      _expenses = [saved, ..._expenses.where((e) => e.id != saved.id)];
      _lastExpensesFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Update an existing operating expense
  Future<bool> updateGymExpense(GymExpenseRecord expense) async {
    final tenantId = expense.tenantId ?? currentGymTenant?.id ?? currentUser?.tenantId ?? 'tenant_metro_01';
    try {
      final saved = await _authRepository.updateGymExpense(
        tenantId: tenantId,
        expense: expense.copyWith(tenantId: tenantId),
      );
      _expenses = _expenses.map((e) => e.id == saved.id ? saved : e).toList();
      _lastExpensesFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Delete an operating expense
  Future<bool> deleteGymExpense(String tenantId, String expenseId) async {
    try {
      await _authRepository.deleteGymExpense(
        tenantId: tenantId,
        expenseId: expenseId,
      );
      _expenses = _expenses.where((e) => e.id != expenseId).toList();
      _lastExpensesFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // --- Actions & Methods ---

  /// Initialize and check active session
  Future<void> checkInitialSession() async {
    _isCheckingSession = true;
    notifyListeners();

    try {
      _currentSession = await _authRepository.getCurrentSession();
      if (_currentSession != null) {
        final results = await Future.wait([
          _authRepository.getGymTenants(),
          _authRepository.getPlatformPlans(),
        ]);
        _gymTenants = results[0] as List<GymTenantModel>;
        _platformPlans = results[1] as List<PlatformPlanModel>;
        _lastTenantsFetch = DateTime.now();
      } else {
        // Preload plans even for public tier view
        _platformPlans = await _authRepository.getPlatformPlans();
      }
    } catch (_) {
      _currentSession = null;
      _platformPlans = [];
    } finally {
      _isCheckingSession = false;
      notifyListeners();
    }
  }

  /// Load all partner gym tenants (with TTL caching)
  Future<void> loadGymTenants({bool forceRefresh = false}) async {
    if (!forceRefresh && _gymTenants.isNotEmpty && _lastTenantsFetch != null) {
      if (DateTime.now().difference(_lastTenantsFetch!) < _cacheTtl) {
        return; // Cache hit - 0 Firestore reads
      }
    }
    _isLoadingTenants = true;
    notifyListeners();
    try {
      _gymTenants = await _authRepository.getGymTenants();
      _lastTenantsFetch = DateTime.now();
    } catch (_) {
    } finally {
      _isLoadingTenants = false;
      notifyListeners();
    }
  }

  /// Register / Onboard a new Gym along with its Admin account
  Future<bool> registerGymWithAdmin({
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
    _isLoadingTenants = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final newGym = await _authRepository.registerGymWithAdmin(
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

      _gymTenants = [newGym, ..._gymTenants.where((g) => g.id != newGym.id)];
      _successMessage =
          'Gym "$gymName" and Admin account ($adminEmail) created successfully!';
      _isLoadingTenants = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoadingTenants = false;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Updates an existing Gym Tenant's details
  Future<bool> updateGymTenant(GymTenantModel updatedTenant) async {
    _isLoadingTenants = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final saved = await _authRepository.updateGymTenant(updatedTenant);
      _gymTenants = _gymTenants.map((g) => g.id == saved.id ? saved : g).toList();
      _successMessage = 'Gym "${saved.gymName}" updated successfully!';
      _isLoadingTenants = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoadingTenants = false;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Toggles a gym's active or suspended status
  Future<bool> toggleGymStatus({
    required String tenantId,
    required bool isActive,
  }) async {
    // Optimistic local update
    _gymTenants = _gymTenants.map((g) {
      if (g.id == tenantId) {
        return g.copyWith(
          status: isActive ? TenantStatus.active : TenantStatus.suspended,
        );
      }
      return g;
    }).toList();
    notifyListeners();

    try {
      await _authRepository.toggleGymStatus(
        tenantId: tenantId,
        isActive: isActive,
      );
      _successMessage = isActive
          ? 'Gym activated successfully.'
          : 'Gym has been marked as Inactive.';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Uploads optimized gym logo to storage
  Future<String?> uploadGymLogo({
    required String gymId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    return await _authRepository.uploadGymLogo(
      gymId: gymId,
      imageBytes: imageBytes,
      fileExtension: fileExtension,
    );
  }

  /// Uploads optimized gym member photo to storage
  Future<String?> uploadGymMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    return await _authRepository.uploadGymMemberPhoto(
      tenantId: tenantId,
      memberId: memberId,
      imageBytes: imageBytes,
      fileExtension: fileExtension,
    );
  }

  /// Uploads optimized user profile photo to storage
  Future<String?> uploadUserProfilePhoto({
    required String userId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    return await _authRepository.uploadUserProfilePhoto(
      userId: userId,
      imageBytes: imageBytes,
      fileExtension: fileExtension,
    );
  }

  /// Clear any active error or success message
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Authenticate user via Email and Password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _authRepository.login(
        email: email,
        password: password,
      );

      _currentSession = session;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Create and register a new Master Super Admin account
  Future<bool> registerSuperAdmin({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    String? securityPin,
    String? organization,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final session = await _authRepository.registerSuperAdmin(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        securityPin: securityPin,
        organization: organization,
      );

      _currentSession = session;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Send password reset link to user's email
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final success = await _authRepository.requestPasswordReset(email: email);
      _isLoading = false;
      if (success) {
        _successMessage = 'Password reset instructions sent to $email';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Terminate active session and sign out
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.logout();
    } finally {
      _currentSession = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  String _cleanErrorMessage(String error) {
    if (error.startsWith('Exception: ')) {
      return error.substring(11);
    }
    return error;
  }
}
