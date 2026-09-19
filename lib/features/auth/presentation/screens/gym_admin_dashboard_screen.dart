import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/image_optimizer.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/gym_tenant_model.dart';
import '../../data/models/gym_team_member_model.dart';
import '../../data/models/gym_membership_plan_model.dart';
import '../../data/models/gym_member_model.dart';
import '../../data/models/gym_expense_model.dart';
import '../../data/models/gym_check_in_model.dart';
import '../../data/models/gym_batch_model.dart';
import 'login_screen.dart';

export '../../data/models/gym_team_member_model.dart';
export '../../data/models/gym_membership_plan_model.dart';
export '../../data/models/gym_member_model.dart';
export '../../data/models/gym_expense_model.dart';
export '../../data/models/gym_check_in_model.dart';
export '../../data/models/gym_batch_model.dart';

/// Backward-compatible alias
typedef GymMemberRecord = GymMemberModel;
typedef GymTrainerRecord = GymTeamMemberRecord;

/// State-of-the-art Gym Admin / Facility Manager Dashboard Screen.
class GymAdminDashboardScreen extends StatefulWidget {
  final AuthController authController;

  const GymAdminDashboardScreen({
    super.key,
    required this.authController,
  });

  @override
  State<GymAdminDashboardScreen> createState() =>
      _GymAdminDashboardScreenState();
}

class _GymAdminDashboardScreenState extends State<GymAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  String _memberSearchQuery = '';
  String _selectedMemberFilter = 'All';

  // In-memory demo data for Gym Admin workspace
  late List<GymMemberRecord> _members;
  late List<GymTeamMemberRecord> _teamMembers;
  late List<GymMembershipPlanModel> _membershipPlans;
  late List<GymCheckInLog> _recentCheckIns;
  late List<GymExpenseRecord> _expenses;
  late List<GymBatchModel> _batches;
  String _teamSearchQuery = '';
  String _selectedTeamFilter = 'All';
  String _planSearchQuery = '';
  String _selectedPlanFilter = 'All';
  String _batchSearchQuery = '';
  String _selectedBatchFilter = 'All';
  String _expenseSearchQuery = '';
  String _selectedExpenseCategoryFilter = 'All';
  String _selectedExpenseTimeframeFilter = 'All Time';
  String _salesTimeframe = 'Week'; // 'Week', 'Month', 'Year'
  int? _selectedSalesPointIndex;
  final Map<String, Map<String, bool>> _staffAttendanceOverrides = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });

    _members = List.from(widget.authController.members);
    _teamMembers = List.from(widget.authController.teamMembers);
    _membershipPlans = List.from(widget.authController.membershipPlans);
    _recentCheckIns = List.from(widget.authController.checkIns);
    _expenses = List.from(widget.authController.expenses);
    _batches = List.from(widget.authController.batches);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshOverviewData(forceRefresh: false);
    });
  }

  Future<void> _refreshOverviewData({bool forceRefresh = false}) async {
    await widget.authController.loadDashboardOverview(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _members = List.from(widget.authController.members);
        _teamMembers = List.from(widget.authController.teamMembers);
        _membershipPlans = List.from(widget.authController.membershipPlans);
        _expenses = List.from(widget.authController.expenses);
        _recentCheckIns = List.from(widget.authController.checkIns);
        _batches = List.from(widget.authController.batches);
      });
    }
  }

  Future<void> _fetchMembersWithServerFilter(String filterStatus) async {
    setState(() => _selectedMemberFilter = filterStatus);
    await widget.authController.loadGymMembers(
      forceRefresh: true,
      filterStatus: filterStatus,
      limit: 20,
    );
    if (mounted) {
      setState(() {
        _members = List.from(widget.authController.members);
      });
    }
  }

  Future<void> _fetchNextMembersPage() async {
    await widget.authController.loadNextMembersPage();
    if (mounted) {
      setState(() {
        _members = List.from(widget.authController.members);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  GymTenantModel? _resolveCurrentTenant() {
    final user = widget.authController.currentUser;
    if (user == null) return null;
    final tid = user.tenantId;
    if (tid != null) {
      final match = widget.authController.gymTenants.where((g) => g.id == tid);
      if (match.isNotEmpty) return match.first;
    }
    // Fallback: match by gym name
    if (user.gymName != null && user.gymName!.isNotEmpty) {
      final match = widget.authController.gymTenants
          .where((g) => g.gymName.toLowerCase() == user.gymName!.toLowerCase());
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF19202E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of your gym management console?',
          style: GoogleFonts.inter(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await widget.authController.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(authController: widget.authController),
          ),
        );
      }
    }
  }

  void _showAddMemberDialog(Color primaryColor) {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final emergencyNameCtrl = TextEditingController();
    final emergencyPhoneCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final discountValueCtrl = TextEditingController();
    final picker = ImagePicker();

    String selectedGender = 'Male';
    DateTime? selectedDob;
    DateTime selectedStartDate = DateTime.now();
    String selectedEmergencyRelation = 'Parent';
    String selectedGoal = 'General Fitness';
    String selectedDiscountType = 'Fixed'; // 'Fixed' or 'Percentage'
    const fitnessGoals = [
      'Weight Loss',
      'Muscle Building',
      'General Fitness',
      'Strength Training',
      'Endurance & Cardio',
      'Body Recomposition',
      'Flexibility & Mobility',
      'Athletic Performance',
    ];
    Uint8List? selectedPhotoBytes;
    OptimizedImageResult? optimizedPhotoResult;
    bool isOptimizingPhoto = false;
    bool isLifetimeFree = false;
    bool isSubmitting = false;
    String selectedPlan = _membershipPlans.isNotEmpty ? _membershipPlans.first.name : 'Standard Pass';
    String? selectedBatchId;
    String? selectedBatchName;
    final formKey = GlobalKey<FormState>();

    Future<void> pickAndOptimizeImage(ImageSource source, StateSetter setModalState) async {
      try {
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (picked == null) return;

        setModalState(() => isOptimizingPhoto = true);
        final rawBytes = await picked.readAsBytes();
        final result = await ImageOptimizer.optimizeImageBytes(
          rawBytes,
          maxWidth: 512,
          maxHeight: 512,
          quality: 80,
        );

        if (result != null) {
          setModalState(() {
            selectedPhotoBytes = result.bytes;
            optimizedPhotoResult = result;
            isOptimizingPhoto = false;
          });
        } else {
          setModalState(() => isOptimizingPhoto = false);
        }
      } catch (e) {
        debugPrint('Error optimizing photo: $e');
        setModalState(() => isOptimizingPhoto = false);
      }
    }

    void useSamplePhoto(StateSetter setModalState) async {
      setModalState(() => isOptimizingPhoto = true);
      final sampleBytes = ImageOptimizer.createSampleAvatarBytes();
      final result = await ImageOptimizer.optimizeImageBytes(sampleBytes);
      if (result != null) {
        setModalState(() {
          selectedPhotoBytes = result.bytes;
          optimizedPhotoResult = result;
          isOptimizingPhoto = false;
        });
      } else {
        setModalState(() => isOptimizingPhoto = false);
      }
    }

    Future<void> pickDob(BuildContext context, StateSetter setModalState) async {
      final now = DateTime.now();
      final initialDate = selectedDob ?? DateTime(now.year - 24, now.month, now.day);
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1920),
        lastDate: now,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: primaryColor,
                onPrimary: Colors.black,
                surface: const Color(0xFF161F2E),
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF131A26),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setModalState(() {
          selectedDob = picked;
        });
      }
    }

    Future<void> pickStartDate(BuildContext context, StateSetter setModalState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedStartDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: primaryColor,
                onPrimary: Colors.black,
                surface: const Color(0xFF161F2E),
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF131A26),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setModalState(() {
          selectedStartDate = picked;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.90,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Enroll New Member',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Profile Picture & Optimization
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 86,
                                      height: 86,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF192231),
                                        border: Border.all(
                                          color: primaryColor.withValues(alpha: 0.8),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withValues(alpha: 0.2),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: isOptimizingPhoto
                                            ? const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            : (selectedPhotoBytes != null
                                                ? Image.memory(
                                                    selectedPhotoBytes!,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Icon(
                                                    Icons.person_outline_rounded,
                                                    size: 44,
                                                    color: primaryColor,
                                                  )),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                                      label: Text(
                                        'Gallery',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                      onPressed: () => pickAndOptimizeImage(ImageSource.gallery, setModalState),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                      label: Text(
                                        'Camera',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                      onPressed: () => pickAndOptimizeImage(ImageSource.camera, setModalState),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      icon: const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.accentCyan),
                                      label: Text(
                                        'Demo Photo',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                      onPressed: () => useSamplePhoto(setModalState),
                                    ),
                                  ],
                                ),
                                if (optimizedPhotoResult != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Optimized: ${optimizedPhotoResult!.savingsLabel}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2. Basic Details Section
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF233045)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.badge_outlined, color: primaryColor, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Basic Details',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // First Name & Last Name
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: firstNameCtrl,
                                        label: 'First Name *',
                                        hint: 'e.g. Jordan',
                                        prefixIcon: Icons.person_rounded,
                                        validator: (v) => v == null || v.trim().isEmpty
                                            ? 'Enter first name'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: lastNameCtrl,
                                        label: 'Last Name *',
                                        hint: 'e.g. Hayes',
                                        prefixIcon: Icons.badge_outlined,
                                        validator: (v) => v == null || v.trim().isEmpty
                                            ? 'Enter last name'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Gender Dropdown & Date of Birth
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Gender *',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF19202E),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFF283448)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: selectedGender,
                                                dropdownColor: const Color(0xFF19202E),
                                                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                                isExpanded: true,
                                                items: ['Male', 'Female', 'Other'].map((g) {
                                                  return DropdownMenuItem<String>(
                                                    value: g,
                                                    child: Text(
                                                      g,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setModalState(() => selectedGender = val);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Date of Birth *',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => pickDob(context, setModalState),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF19202E),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFF283448)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.calendar_today_rounded, size: 16, color: primaryColor),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      selectedDob != null
                                                          ? '${DateFormat('dd/MM/yyyy').format(selectedDob!)} (${DateTime.now().year - selectedDob!.year}y)'
                                                          : 'DD/MM/YYYY',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12.5,
                                                        color: selectedDob != null ? Colors.white : AppColors.textSecondaryDark,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Contact Details: Phone & Email
                                CustomTextField(
                                  controller: phoneCtrl,
                                  label: 'Phone Number *',
                                  hint: '+91 98765 43210',
                                  prefixIcon: Icons.phone_rounded,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Enter phone number'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                CustomTextField(
                                  controller: emailCtrl,
                                  label: 'Email Address',
                                  hint: 'member@example.com',
                                  prefixIcon: Icons.email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),
                                // Residential Address
                                CustomTextField(
                                  controller: addressCtrl,
                                  label: 'Residential Address',
                                  hint: 'Street, Apt/Suite, City, State, ZIP',
                                  prefixIcon: Icons.home_rounded,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Physical Metrics & Fitness Goal
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF233045)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.fitness_center_rounded, color: primaryColor, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Physical Metrics & Fitness Goal',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: weightCtrl,
                                        label: 'Weight (kg)',
                                        hint: 'e.g. 75',
                                        prefixIcon: Icons.monitor_weight_outlined,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: heightCtrl,
                                        label: 'Height (cm)',
                                        hint: 'e.g. 178',
                                        prefixIcon: Icons.height_rounded,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fitness Goal *',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF19202E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF283448)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedGoal,
                                          dropdownColor: const Color(0xFF19202E),
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                          isExpanded: true,
                                          items: fitnessGoals.map((goal) {
                                            return DropdownMenuItem<String>(
                                              value: goal,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.track_changes_rounded,
                                                    size: 15,
                                                    color: primaryColor,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    goal,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setModalState(() => selectedGoal = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. Optional Emergency Contact Section
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF233045)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.emergency_rounded, color: AppColors.accentAmber, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Emergency Contact (Optional)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: emergencyNameCtrl,
                                  label: 'Contact Person Name',
                                  hint: 'e.g. Sarah Hayes',
                                  prefixIcon: Icons.person_pin_circle_rounded,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: CustomTextField(
                                        controller: emergencyPhoneCtrl,
                                        label: 'Emergency Phone',
                                        hint: '+91 91234 56789',
                                        prefixIcon: Icons.phone_callback_rounded,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Relation',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF19202E),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFF283448)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: selectedEmergencyRelation,
                                                dropdownColor: const Color(0xFF19202E),
                                                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                                isExpanded: true,
                                                items: ['Parent', 'Spouse', 'Sibling', 'Friend', 'Guardian', 'Other'].map((r) {
                                                  return DropdownMenuItem<String>(
                                                    value: r,
                                                    child: Text(
                                                      r,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setModalState(() => selectedEmergencyRelation = val);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 5. Membership Details Section
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF233045)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.card_membership_rounded,
                                      color: isLifetimeFree ? AppColors.accentViolet : primaryColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Membership Details',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Assigned Batch Selector Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Assigned Batch (Optional)',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF19202E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF283448)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String?>(
                                          value: selectedBatchId,
                                          dropdownColor: const Color(0xFF19202E),
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                          isExpanded: true,
                                          items: [
                                            DropdownMenuItem<String?>(
                                              value: null,
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.schedule_rounded, size: 16, color: Colors.white38),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'No Batch Assigned',
                                                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ..._batches.map((b) {
                                              return DropdownMenuItem<String?>(
                                                value: b.id,
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.schedule_rounded, size: 16, color: AppColors.accentCyan),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '${b.name} (${b.time})',
                                                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                          onChanged: (val) {
                                            setModalState(() {
                                              selectedBatchId = val;
                                              if (val != null) {
                                                final match = _batches.where((b) => b.id == val);
                                                selectedBatchName = match.isNotEmpty ? '${match.first.name} (${match.first.time})' : null;
                                              } else {
                                                selectedBatchName = null;
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Lifetime Free Member Checkbox
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isLifetimeFree
                                        ? const Color(0xFF1E283A)
                                        : const Color(0xFF19202E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isLifetimeFree
                                          ? AppColors.accentViolet.withValues(alpha: 0.8)
                                          : const Color(0xFF283448),
                                      width: isLifetimeFree ? 1.4 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isLifetimeFree,
                                        activeColor: AppColors.accentViolet,
                                        checkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        onChanged: (val) {
                                          setModalState(() {
                                            isLifetimeFree = val ?? false;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              isLifetimeFree = !isLifetimeFree;
                                            });
                                          },
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Is Lifetime Free Member',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: isLifetimeFree ? AppColors.accentViolet : Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.accentViolet.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '♾️ No Expiry',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.accentViolet,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Grants perpetual full facility access without requiring a package.',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondaryDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Membership Package Selection (Hidden if Lifetime Free)
                                if (isLifetimeFree) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentViolet.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.all_inclusive_rounded, color: AppColors.accentViolet, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Lifetime Free Member active • No package selection needed • Access will never expire.',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.accentViolet,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Select Membership Package *',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      final availablePlans = _membershipPlans
                                          .where((p) => p.isActive)
                                          .map((p) => p.name)
                                          .toList();
                                      if (availablePlans.isEmpty && _membershipPlans.isNotEmpty) {
                                        availablePlans.addAll(_membershipPlans.map((p) => p.name));
                                      }
                                      if (availablePlans.isEmpty) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF19202E),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFF283448)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline_rounded,
                                                  color: AppColors.accentAmber, size: 18),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'No membership plans created yet. Please create a plan in the "Plans" tab first.',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondaryDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      if (!availablePlans.contains(selectedPlan) && availablePlans.isNotEmpty) {
                                        selectedPlan = availablePlans.first;
                                      }
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: availablePlans.map((planName) {
                                          final isSelected = selectedPlan == planName;
                                          final planModel = _membershipPlans.where((p) => p.name == planName).firstOrNull;
                                          final priceTag = planModel != null ? ' (${planModel.formattedPrice})' : '';
                                          return ChoiceChip(
                                            label: Text(
                                              '$planName$priceTag',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.black
                                                    : Colors.white70,
                                              ),
                                            ),
                                            selected: isSelected,
                                            selectedColor: planModel?.accentColor ?? primaryColor,
                                            backgroundColor: const Color(0xFF19202E),
                                            onSelected: (_) {
                                              setModalState(() => selectedPlan = planName);
                                            },
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Plan Validity & Date Schedule Section (Starting Date & Auto-calculated Ending Date)
                                  Builder(
                                    builder: (context) {
                                      final planModel = _membershipPlans.where((p) => p.name == selectedPlan).firstOrNull;
                                      final durationDays = planModel?.durationDays ?? (selectedPlan.contains('Annual') ? 365 : 30);
                                      final calculatedEndDate = selectedStartDate.add(Duration(days: durationDays));
                                      final isExpiredDate = calculatedEndDate.isBefore(DateTime.now());

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF19202E),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isExpiredDate
                                                ? AppColors.error.withValues(alpha: 0.5)
                                                : const Color(0xFF283448),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.date_range_rounded, color: AppColors.accentCyan, size: 16),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Plan Validity Schedule',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isExpiredDate
                                                        ? AppColors.error.withValues(alpha: 0.2)
                                                        : AppColors.accentCyan.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isExpiredDate
                                                        ? '⚠️ Expired Plan'
                                                        : '${planModel?.durationLabel ?? '$durationDays Days'} Term',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: isExpiredDate ? AppColors.error : AppColors.accentCyan,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                // Starting Date (Clickable DatePicker)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Plan Starting Date *',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppColors.textSecondaryDark,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      InkWell(
                                                        onTap: () => pickStartDate(context, setModalState),
                                                        borderRadius: BorderRadius.circular(10),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF131A26),
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(color: const Color(0xFF2E3D56)),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accentCyan),
                                                              const SizedBox(width: 8),
                                                              Expanded(
                                                                child: Text(
                                                                  DateFormat('dd/MM/yyyy').format(selectedStartDate),
                                                                  style: GoogleFonts.inter(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                              ),
                                                              const Icon(Icons.edit_calendar_rounded, size: 14, color: Colors.white38),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                // Ending Date (Auto-calculated from Plan Details)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Plan Ending Date (Auto)',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppColors.textSecondaryDark,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF131A26),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(
                                                            color: isExpiredDate ? AppColors.error.withValues(alpha: 0.5) : const Color(0xFF2E3D56),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              isExpiredDate ? Icons.error_outline_rounded : Icons.event_available_rounded,
                                                              size: 14,
                                                              color: isExpiredDate ? AppColors.error : AppColors.success,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                DateFormat('dd/MM/yyyy').format(calculatedEndDate),
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: isExpiredDate ? AppColors.error : AppColors.success,
                                                                ),
                                                              ),
                                                            ),
                                                            Text(
                                                              DateFormat('dd MMM').format(calculatedEndDate),
                                                              style: GoogleFonts.inter(
                                                                fontSize: 10,
                                                                color: isExpiredDate ? AppColors.error : AppColors.textSecondaryDark,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Discount Configuration: Discount Type & Discount Value
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Discount Type',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondaryDark,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF19202E),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFF283448)),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedDiscountType,
                                                  dropdownColor: const Color(0xFF19202E),
                                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                                  isExpanded: true,
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: 'Fixed',
                                                      child: Text(
                                                        'Fixed (₹)',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'Percentage',
                                                      child: Text(
                                                        'Percentage (%)',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setModalState(() => selectedDiscountType = val);
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 5,
                                        child: CustomTextField(
                                          controller: discountValueCtrl,
                                          label: selectedDiscountType == 'Percentage'
                                              ? 'Discount Value (%)'
                                              : 'Discount Value (₹)',
                                          hint: selectedDiscountType == 'Percentage' ? 'e.g. 10' : 'e.g. 500',
                                          prefixIcon: selectedDiscountType == 'Percentage'
                                              ? Icons.percent_rounded
                                              : Icons.currency_rupee_rounded,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (_) => setModalState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Live Pricing Breakdown Preview
                                  Builder(
                                    builder: (context) {
                                      final planModel = _membershipPlans.where((p) => p.name == selectedPlan).firstOrNull;
                                      final parsedDisc = double.tryParse(discountValueCtrl.text.trim()) ?? 0.0;
                                      if (parsedDisc <= 0 || planModel == null) return const SizedBox.shrink();

                                      final basePrice = planModel.price;
                                      final discAmt = selectedDiscountType == 'Percentage'
                                          ? (basePrice * (parsedDisc / 100.0)).clamp(0.0, basePrice)
                                          : parsedDisc.clamp(0.0, basePrice);
                                      final finalPrice = (basePrice - discAmt).clamp(0.0, double.infinity);

                                      return Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentEmerald.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.local_offer_rounded, color: AppColors.accentEmerald, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Price: ₹${basePrice.toInt()} • Save ₹${discAmt.toStringAsFixed(discAmt % 1 == 0 ? 0 : 2)}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.accentEmerald.withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Payable: ₹${finalPrice.toStringAsFixed(finalPrice % 1 == 0 ? 0 : 2)}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.accentEmerald,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 8. Submit Button
                          CustomButton(
                            text: isSubmitting ? 'Enrolling Member...' : 'Enroll & Issue Member Pass',
                            icon: Icons.qr_code_rounded,
                            customColor: primaryColor,
                            isLoading: isSubmitting,
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSubmitting = true);

                              final planModel = _membershipPlans.where((p) => p.name == selectedPlan).firstOrNull;
                              final duration = isLifetimeFree
                                  ? const Duration(days: 36500)
                                  : (planModel != null
                                      ? Duration(days: planModel.durationDays)
                                      : (selectedPlan.contains('Annual')
                                          ? const Duration(days: 365)
                                          : const Duration(days: 30)));

                              final emgName = emergencyNameCtrl.text.trim();
                              final emgPhone = emergencyPhoneCtrl.text.trim();
                              final discVal = double.tryParse(discountValueCtrl.text.trim());

                              final newMember = GymMemberModel(
                                id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
                                tenantId: widget.authController.currentGymTenant?.id ?? 'tenant_metro_01',
                                firstName: firstNameCtrl.text.trim(),
                                lastName: lastNameCtrl.text.trim(),
                                gender: selectedGender,
                                dateOfBirth: selectedDob,
                                phone: phoneCtrl.text.trim(),
                                email: emailCtrl.text.trim().isNotEmpty
                                    ? emailCtrl.text.trim()
                                    : 'member@facility.com',
                                address: addressCtrl.text.trim(),
                                weight: double.tryParse(weightCtrl.text.trim()),
                                height: double.tryParse(heightCtrl.text.trim()),
                                goal: selectedGoal,
                                emergencyContactName: emgName.isNotEmpty ? emgName : null,
                                emergencyPhone: emgPhone.isNotEmpty ? emgPhone : null,
                                emergencyContactRelation: emgName.isNotEmpty ? selectedEmergencyRelation : null,
                                membershipPlanId: isLifetimeFree ? null : planModel?.id,
                                membershipPlan: isLifetimeFree ? 'Lifetime Free' : selectedPlan,
                                batchId: selectedBatchId,
                                batchName: selectedBatchName,
                                isLifetimeFree: isLifetimeFree,
                                discountType: (!isLifetimeFree && discVal != null && discVal > 0) ? selectedDiscountType : null,
                                discountValue: (!isLifetimeFree && discVal != null && discVal > 0) ? discVal : null,
                                startDate: selectedStartDate,
                                expiryDate: isLifetimeFree ? DateTime(2099, 12, 31) : selectedStartDate.add(duration),
                              );

                              final navigator = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              final success = await widget.authController.addGymMember(
                                newMember,
                                photoBytes: selectedPhotoBytes,
                              );

                              if (success && selectedBatchId != null) {
                                final matchIdx = _batches.indexWhere((b) => b.id == selectedBatchId);
                                if (matchIdx != -1) {
                                  final batch = _batches[matchIdx];
                                  if (!batch.memberIds.contains(newMember.id)) {
                                    final updatedIds = List<String>.from(batch.memberIds)..add(newMember.id);
                                    final updatedNames = List<String>.from(batch.memberNames)..add(newMember.fullName);
                                    final updatedBatch = batch.copyWith(memberIds: updatedIds, memberNames: updatedNames);
                                    await widget.authController.updateGymBatch(updatedBatch);
                                  }
                                }
                              }

                              if (mounted) {
                                setState(() {
                                  _members = List.from(widget.authController.members);
                                  _batches = List.from(widget.authController.batches);
                                });
                              }

                              if (!success) {
                                setModalState(() => isSubmitting = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.authController.errorMessage ?? 'Failed to enroll member.',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Enrolled ${newMember.fullName} successfully!',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditMemberDialog(GymMemberRecord member, Color primaryColor) {
    final firstNameCtrl = TextEditingController(text: member.firstName);
    final lastNameCtrl = TextEditingController(text: member.lastName);
    final phoneCtrl = TextEditingController(text: member.phone);
    final emailCtrl = TextEditingController(text: member.email);
    final addressCtrl = TextEditingController(text: member.address);
    final emergencyNameCtrl = TextEditingController(text: member.emergencyContactName ?? '');
    final emergencyPhoneCtrl = TextEditingController(text: member.emergencyPhone ?? '');
    final weightCtrl = TextEditingController(
      text: member.weight != null ? (member.weight! % 1 == 0 ? member.weight!.toInt().toString() : member.weight!.toString()) : '',
    );
    final heightCtrl = TextEditingController(
      text: member.height != null ? (member.height! % 1 == 0 ? member.height!.toInt().toString() : member.height!.toString()) : '',
    );
    final discountValueCtrl = TextEditingController(
      text: member.discountValue != null
          ? (member.discountValue! % 1 == 0 ? member.discountValue!.toInt().toString() : member.discountValue!.toString())
          : '',
    );

    final ImagePicker picker = ImagePicker();
    String selectedGender = member.gender;
    DateTime? selectedDob = member.dateOfBirth;
    DateTime selectedStartDate = member.startDate;
    String selectedEmergencyRelation = member.emergencyContactRelation ?? 'Parent';
    String selectedDiscountType = member.discountType ?? 'Fixed';
    const fitnessGoals = [
      'Weight Loss',
      'Muscle Building',
      'General Fitness',
      'Strength Training',
      'Endurance & Cardio',
      'Body Recomposition',
      'Flexibility & Mobility',
      'Athletic Performance',
    ];
    String selectedGoal = (member.goal != null && fitnessGoals.contains(member.goal))
        ? member.goal!
        : 'General Fitness';
    Uint8List? selectedPhotoBytes;
    String? selectedPhotoUrl = member.photoUrl;
    OptimizedImageResult? optimizedPhotoResult;
    bool isOptimizingPhoto = false;
    bool isLifetimeFree = member.isLifetimeFree;
    bool isActive = member.isActive;
    bool isSubmitting = false;
    String selectedPlan = member.membershipPlan;
    String? selectedBatchId = member.batchId;
    String? selectedBatchName = member.batchName;
    final formKey = GlobalKey<FormState>();

    Future<void> pickAndOptimizeImage(ImageSource source, StateSetter setModalState) async {
      try {
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (picked == null) return;

        setModalState(() => isOptimizingPhoto = true);
        final rawBytes = await picked.readAsBytes();
        final result = await ImageOptimizer.optimizeImageBytes(
          rawBytes,
          maxWidth: 512,
          maxHeight: 512,
          quality: 80,
        );

        if (result != null) {
          setModalState(() {
            selectedPhotoBytes = result.bytes;
            optimizedPhotoResult = result;
            isOptimizingPhoto = false;
          });
        } else {
          setModalState(() => isOptimizingPhoto = false);
        }
      } catch (e) {
        debugPrint('Error optimizing photo: $e');
        setModalState(() => isOptimizingPhoto = false);
      }
    }

    void useSamplePhoto(StateSetter setModalState) async {
      setModalState(() => isOptimizingPhoto = true);
      final sampleBytes = ImageOptimizer.createSampleAvatarBytes();
      final result = await ImageOptimizer.optimizeImageBytes(sampleBytes);
      if (result != null) {
        setModalState(() {
          selectedPhotoBytes = result.bytes;
          optimizedPhotoResult = result;
          isOptimizingPhoto = false;
        });
      } else {
        setModalState(() => isOptimizingPhoto = false);
      }
    }

    Future<void> pickDob(BuildContext context, StateSetter setModalState) async {
      final now = DateTime.now();
      final initialDate = selectedDob ?? DateTime(now.year - 24, now.month, now.day);
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1920),
        lastDate: now,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: primaryColor,
                onPrimary: Colors.black,
                surface: const Color(0xFF161F2E),
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF131A26),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setModalState(() {
          selectedDob = picked;
        });
      }
    }

    Future<void> pickStartDate(BuildContext context, StateSetter setModalState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedStartDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: primaryColor,
                onPrimary: Colors.black,
                surface: const Color(0xFF161F2E),
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF131A26),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setModalState(() {
          selectedStartDate = picked;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.90,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  // Modal drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Modal Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.edit_note_rounded, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Member Profile',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Update profile, emergency contact, or package terms',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF1F2937), height: 1),

                  // Scrollable form body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Profile Picture & Live Image Optimizer
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF192231),
                                        border: Border.all(
                                          color: primaryColor,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withValues(alpha: 0.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: isOptimizingPhoto
                                            ? const Center(
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : (selectedPhotoBytes != null
                                                ? Image.memory(
                                                    selectedPhotoBytes!,
                                                    fit: BoxFit.cover,
                                                  )
                                                : ImageOptimizer.buildImageWidget(
                                                    selectedPhotoUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder: Center(
                                                      child: Text(
                                                        member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'M',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 28,
                                                          fontWeight: FontWeight.w800,
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                  )),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(color: Color(0xFF283448)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => pickAndOptimizeImage(ImageSource.gallery, setModalState),
                                      icon: const Icon(Icons.photo_library_rounded, size: 14),
                                      label: const Text('Gallery', style: TextStyle(fontSize: 11.5)),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(color: Color(0xFF283448)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => pickAndOptimizeImage(ImageSource.camera, setModalState),
                                      icon: const Icon(Icons.camera_alt_rounded, size: 14),
                                      label: const Text('Camera', style: TextStyle(fontSize: 11.5)),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => useSamplePhoto(setModalState),
                                      icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                                      label: const Text('Demo Photo', style: TextStyle(fontSize: 11.5)),
                                    ),
                                  ],
                                ),
                                if (optimizedPhotoResult != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '✓ Optimized: ${optimizedPhotoResult!.summaryString}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.successLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 2. Basic Details Section
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF233045)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.badge_outlined, color: primaryColor, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Basic Details',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // First Name & Last Name
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: firstNameCtrl,
                                        label: 'First Name *',
                                        hint: 'e.g. Jordan',
                                        prefixIcon: Icons.person_outline_rounded,
                                        validator: (v) => v == null || v.trim().isEmpty
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: lastNameCtrl,
                                        label: 'Last Name *',
                                        hint: 'e.g. Hayes',
                                        prefixIcon: Icons.person_outline_rounded,
                                        validator: (v) => v == null || v.trim().isEmpty
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Gender Dropdown & Date of Birth Picker
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Gender *',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF19202E),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFF283448)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: selectedGender,
                                                dropdownColor: const Color(0xFF19202E),
                                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                                isExpanded: true,
                                                items: const [
                                                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                                                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                                                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setModalState(() => selectedGender = val);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Date of Birth *',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => pickDob(context, setModalState),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF19202E),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFF283448)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.calendar_today_rounded, size: 16, color: primaryColor),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      selectedDob != null
                                                          ? '${DateFormat('dd/MM/yyyy').format(selectedDob!)} (${DateTime.now().year - selectedDob!.year}y)'
                                                          : 'DD/MM/YYYY',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12.5,
                                                        color: selectedDob != null ? Colors.white : AppColors.textSecondaryDark,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Contact Details: Phone & Email
                                CustomTextField(
                                  controller: phoneCtrl,
                                  label: 'Phone Number *',
                                  hint: '+91 98765 43210',
                                  prefixIcon: Icons.phone_rounded,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Enter phone number'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                CustomTextField(
                                  controller: emailCtrl,
                                  label: 'Email Address',
                                  hint: 'member@example.com',
                                  prefixIcon: Icons.email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),
                                // Residential Address
                                CustomTextField(
                                  controller: addressCtrl,
                                  label: 'Residential Address',
                                  hint: 'Street, Apt/Suite, City, State, ZIP',
                                  prefixIcon: Icons.home_rounded,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Physical Metrics & Fitness Goal
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF233045)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.fitness_center_rounded, color: primaryColor, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Physical Metrics & Fitness Goal',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: weightCtrl,
                                        label: 'Weight (kg)',
                                        hint: 'e.g. 75',
                                        prefixIcon: Icons.monitor_weight_outlined,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: heightCtrl,
                                        label: 'Height (cm)',
                                        hint: 'e.g. 178',
                                        prefixIcon: Icons.height_rounded,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fitness Goal *',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF19202E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF283448)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedGoal,
                                          dropdownColor: const Color(0xFF19202E),
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                          isExpanded: true,
                                          items: fitnessGoals.map((goal) {
                                            return DropdownMenuItem<String>(
                                              value: goal,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.track_changes_rounded,
                                                    size: 15,
                                                    color: primaryColor,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    goal,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setModalState(() => selectedGoal = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. Optional Emergency Contact Section
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF233045)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.emergency_rounded, color: AppColors.accentAmber, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Emergency Contact (Optional)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: emergencyNameCtrl,
                                  label: 'Contact Person Name',
                                  hint: 'e.g. Sarah Hayes',
                                  prefixIcon: Icons.person_pin_circle_rounded,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: CustomTextField(
                                        controller: emergencyPhoneCtrl,
                                        label: 'Emergency Phone',
                                        hint: '+91 91234 56789',
                                        prefixIcon: Icons.phone_callback_rounded,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Relation',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF19202E),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFF283448)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: selectedEmergencyRelation,
                                                dropdownColor: const Color(0xFF19202E),
                                                style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                                                isExpanded: true,
                                                items: const [
                                                  DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                                                  DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                                                  DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
                                                  DropdownMenuItem(value: 'Friend', child: Text('Friend')),
                                                  DropdownMenuItem(value: 'Guardian', child: Text('Guardian')),
                                                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setModalState(() => selectedEmergencyRelation = val);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 5. Membership Details Section
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF233045)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.card_membership_rounded,
                                      color: isLifetimeFree ? AppColors.accentViolet : primaryColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Membership Details',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Active Membership Status Switch
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF19202E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF2B3648)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                                            color: isActive ? AppColors.success : AppColors.textMutedDark,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Active Status',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Switch(
                                        value: isActive,
                                        activeThumbColor: AppColors.success,
                                        onChanged: (val) {
                                          setModalState(() => isActive = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Assigned Batch Selector Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Assigned Batch',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF19202E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF283448)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String?>(
                                          value: selectedBatchId,
                                          dropdownColor: const Color(0xFF19202E),
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                          isExpanded: true,
                                          items: [
                                            DropdownMenuItem<String?>(
                                              value: null,
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.schedule_rounded, size: 16, color: Colors.white38),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'No Batch Assigned',
                                                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ..._batches.map((b) {
                                              return DropdownMenuItem<String?>(
                                                value: b.id,
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.schedule_rounded, size: 16, color: AppColors.accentCyan),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '${b.name} (${b.time})',
                                                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                          onChanged: (val) {
                                            setModalState(() {
                                              selectedBatchId = val;
                                              if (val != null) {
                                                final match = _batches.where((b) => b.id == val);
                                                selectedBatchName = match.isNotEmpty ? '${match.first.name} (${match.first.time})' : null;
                                              } else {
                                                selectedBatchName = null;
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Lifetime Free Member Checkbox
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isLifetimeFree
                                        ? const Color(0xFF1E283A)
                                        : const Color(0xFF19202E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isLifetimeFree
                                          ? AppColors.accentViolet.withValues(alpha: 0.8)
                                          : const Color(0xFF283448),
                                      width: isLifetimeFree ? 1.4 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isLifetimeFree,
                                        activeColor: AppColors.accentViolet,
                                        checkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        onChanged: (val) {
                                          setModalState(() {
                                            isLifetimeFree = val ?? false;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              isLifetimeFree = !isLifetimeFree;
                                            });
                                          },
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Is Lifetime Free Member',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: isLifetimeFree ? AppColors.accentViolet : Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.accentViolet.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '♾️ No Expiry',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.accentViolet,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Grants perpetual full facility access without requiring a package.',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondaryDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Membership Package Selection (Hidden if Lifetime Free)
                                if (isLifetimeFree) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentViolet.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.all_inclusive_rounded, color: AppColors.accentViolet, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Lifetime Free Member active • No package selection needed • Access will never expire.',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.accentViolet,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Select Membership Package *',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      final availablePlans = _membershipPlans
                                          .where((p) => p.isActive)
                                          .map((p) => p.name)
                                          .toList();
                                      if (availablePlans.isEmpty && _membershipPlans.isNotEmpty) {
                                        availablePlans.addAll(_membershipPlans.map((p) => p.name));
                                      }
                                      if (availablePlans.isEmpty) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF19202E),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFF283448)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline_rounded,
                                                  color: AppColors.accentAmber, size: 18),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'No membership plans created yet. Please create a plan in the "Plans" tab first.',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondaryDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      if (!availablePlans.contains(selectedPlan) && availablePlans.isNotEmpty) {
                                        selectedPlan = availablePlans.first;
                                      }
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: availablePlans.map((planName) {
                                          final isSelected = selectedPlan == planName;
                                          final planModel = _membershipPlans.where((p) => p.name == planName).firstOrNull;
                                          final priceTag = planModel != null ? ' (${planModel.formattedPrice})' : '';
                                          return ChoiceChip(
                                            label: Text(
                                              '$planName$priceTag',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.black
                                                    : Colors.white70,
                                              ),
                                            ),
                                            selected: isSelected,
                                            selectedColor: planModel?.accentColor ?? primaryColor,
                                            backgroundColor: const Color(0xFF19202E),
                                            onSelected: (_) {
                                              setModalState(() => selectedPlan = planName);
                                            },
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Plan Validity & Date Schedule Section (Starting Date & Auto-calculated Ending Date)
                                  Builder(
                                    builder: (context) {
                                      final planModel = _membershipPlans.where((p) => p.name == selectedPlan).firstOrNull;
                                      final durationDays = planModel?.durationDays ?? (selectedPlan.contains('Annual') ? 365 : 30);
                                      final calculatedEndDate = selectedStartDate.add(Duration(days: durationDays));
                                      final isExpiredDate = calculatedEndDate.isBefore(DateTime.now());

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF19202E),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isExpiredDate
                                                ? AppColors.error.withValues(alpha: 0.5)
                                                : const Color(0xFF283448),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.date_range_rounded, color: AppColors.accentCyan, size: 16),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Plan Validity Schedule',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isExpiredDate
                                                        ? AppColors.error.withValues(alpha: 0.2)
                                                        : AppColors.accentCyan.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isExpiredDate
                                                        ? '⚠️ Expired Plan'
                                                        : '${planModel?.durationLabel ?? '$durationDays Days'} Term',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: isExpiredDate ? AppColors.error : AppColors.accentCyan,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                // Starting Date (Clickable DatePicker)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Plan Starting Date *',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppColors.textSecondaryDark,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      InkWell(
                                                        onTap: () => pickStartDate(context, setModalState),
                                                        borderRadius: BorderRadius.circular(10),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF131A26),
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(color: const Color(0xFF2E3D56)),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accentCyan),
                                                              const SizedBox(width: 8),
                                                              Expanded(
                                                                child: Text(
                                                                  DateFormat('dd/MM/yyyy').format(selectedStartDate),
                                                                  style: GoogleFonts.inter(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                              ),
                                                              const Icon(Icons.edit_calendar_rounded, size: 14, color: Colors.white38),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                // Ending Date (Auto-calculated from Plan Details)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Plan Ending Date (Auto)',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppColors.textSecondaryDark,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF131A26),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(
                                                            color: isExpiredDate ? AppColors.error.withValues(alpha: 0.5) : const Color(0xFF2E3D56),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              isExpiredDate ? Icons.error_outline_rounded : Icons.event_available_rounded,
                                                              size: 14,
                                                              color: isExpiredDate ? AppColors.error : AppColors.success,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                DateFormat('dd/MM/yyyy').format(calculatedEndDate),
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: isExpiredDate ? AppColors.error : AppColors.success,
                                                                ),
                                                              ),
                                                            ),
                                                            Text(
                                                              DateFormat('dd MMM').format(calculatedEndDate),
                                                              style: GoogleFonts.inter(
                                                                fontSize: 10,
                                                                color: isExpiredDate ? AppColors.error : AppColors.textSecondaryDark,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Discount Configuration: Discount Type & Discount Value
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Discount Type',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondaryDark,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF19202E),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFF283448)),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedDiscountType,
                                                  dropdownColor: const Color(0xFF19202E),
                                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                                  isExpanded: true,
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: 'Fixed',
                                                      child: Text(
                                                        'Fixed (₹)',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'Percentage',
                                                      child: Text(
                                                        'Percentage (%)',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setModalState(() => selectedDiscountType = val);
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 5,
                                        child: CustomTextField(
                                          controller: discountValueCtrl,
                                          label: selectedDiscountType == 'Percentage'
                                              ? 'Discount Value (%)'
                                              : 'Discount Value (₹)',
                                          hint: selectedDiscountType == 'Percentage' ? 'e.g. 10' : 'e.g. 500',
                                          prefixIcon: selectedDiscountType == 'Percentage'
                                              ? Icons.percent_rounded
                                              : Icons.currency_rupee_rounded,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (_) => setModalState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Live Pricing Breakdown Preview
                                  Builder(
                                    builder: (context) {
                                      final planModel = _membershipPlans.where((p) => p.name == selectedPlan).firstOrNull;
                                      final parsedDisc = double.tryParse(discountValueCtrl.text.trim()) ?? 0.0;
                                      if (parsedDisc <= 0 || planModel == null) return const SizedBox.shrink();

                                      final basePrice = planModel.price;
                                      final discAmt = selectedDiscountType == 'Percentage'
                                          ? (basePrice * (parsedDisc / 100.0)).clamp(0.0, basePrice)
                                          : parsedDisc.clamp(0.0, basePrice);
                                      final finalPrice = (basePrice - discAmt).clamp(0.0, double.infinity);

                                      return Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentEmerald.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.local_offer_rounded, color: AppColors.accentEmerald, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Price: ₹${basePrice.toInt()} • Save ₹${discAmt.toStringAsFixed(discAmt % 1 == 0 ? 0 : 2)}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.accentEmerald.withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Payable: ₹${finalPrice.toStringAsFixed(finalPrice % 1 == 0 ? 0 : 2)}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.accentEmerald,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 10. Save Changes Button
                          CustomButton(
                            text: isSubmitting ? 'Saving Changes...' : 'Save Member Changes',
                            icon: Icons.save_rounded,
                            customColor: primaryColor,
                            isLoading: isSubmitting,
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSubmitting = true);

                              final planModel = _membershipPlans.where((p) => p.name == selectedPlan).firstOrNull;
                              final duration = isLifetimeFree
                                  ? const Duration(days: 36500)
                                  : (planModel != null
                                      ? Duration(days: planModel.durationDays)
                                      : (selectedPlan.contains('Annual')
                                          ? const Duration(days: 365)
                                          : const Duration(days: 30)));

                              final emgName = emergencyNameCtrl.text.trim();
                              final emgPhone = emergencyPhoneCtrl.text.trim();
                              final discVal = double.tryParse(discountValueCtrl.text.trim());

                              final updated = member.copyWith(
                                firstName: firstNameCtrl.text.trim(),
                                lastName: lastNameCtrl.text.trim(),
                                photoUrl: selectedPhotoUrl,
                                gender: selectedGender,
                                dateOfBirth: selectedDob,
                                phone: phoneCtrl.text.trim(),
                                email: emailCtrl.text.trim().isNotEmpty
                                    ? emailCtrl.text.trim()
                                    : 'member@facility.com',
                                address: addressCtrl.text.trim(),
                                weight: double.tryParse(weightCtrl.text.trim()),
                                height: double.tryParse(heightCtrl.text.trim()),
                                goal: selectedGoal,
                                emergencyContactName: emgName.isNotEmpty ? emgName : null,
                                emergencyPhone: emgPhone.isNotEmpty ? emgPhone : null,
                                emergencyContactRelation: emgName.isNotEmpty ? selectedEmergencyRelation : null,
                                membershipPlanId: isLifetimeFree ? null : planModel?.id,
                                membershipPlan: isLifetimeFree ? 'Lifetime Free' : selectedPlan,
                                batchId: selectedBatchId,
                                batchName: selectedBatchName,
                                isLifetimeFree: isLifetimeFree,
                                isActive: isActive,
                                discountType: (!isLifetimeFree && discVal != null && discVal > 0) ? selectedDiscountType : null,
                                discountValue: (!isLifetimeFree && discVal != null && discVal > 0) ? discVal : null,
                                startDate: selectedStartDate,
                                expiryDate: isLifetimeFree ? DateTime(2099, 12, 31) : selectedStartDate.add(duration),
                              );

                              final navigator = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              final success = await widget.authController.updateGymMember(
                                updated,
                                photoBytes: selectedPhotoBytes,
                              );

                              if (success && member.batchId != selectedBatchId) {
                                // 1. Remove from old batch if assigned
                                if (member.batchId != null) {
                                  final oldIdx = _batches.indexWhere((b) => b.id == member.batchId);
                                  if (oldIdx != -1) {
                                    final oldBatch = _batches[oldIdx];
                                    final updatedIds = List<String>.from(oldBatch.memberIds)..remove(updated.id);
                                    final updatedNames = List<String>.from(oldBatch.memberNames)..removeWhere((n) => n == updated.fullName || n == member.fullName);
                                    final updatedOldBatch = oldBatch.copyWith(memberIds: updatedIds, memberNames: updatedNames);
                                    await widget.authController.updateGymBatch(updatedOldBatch);
                                  }
                                }
                                // 2. Add to new batch if selected
                                if (selectedBatchId != null) {
                                  final newIdx = _batches.indexWhere((b) => b.id == selectedBatchId);
                                  if (newIdx != -1) {
                                    final newBatch = _batches[newIdx];
                                    if (!newBatch.memberIds.contains(updated.id)) {
                                      final updatedIds = List<String>.from(newBatch.memberIds)..add(updated.id);
                                      final updatedNames = List<String>.from(newBatch.memberNames)..add(updated.fullName);
                                      final updatedNewBatch = newBatch.copyWith(memberIds: updatedIds, memberNames: updatedNames);
                                      await widget.authController.updateGymBatch(updatedNewBatch);
                                    }
                                  }
                                }
                              }

                              if (mounted) {
                                setState(() {
                                  _members = List.from(widget.authController.members);
                                  _batches = List.from(widget.authController.batches);
                                });
                              }

                              if (!success) {
                                setModalState(() => isSubmitting = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.authController.errorMessage ?? 'Failed to update member.',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Updated ${updated.fullName} successfully!',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickCheckInDialog(Color primaryColor) {
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = _members.where((m) {
            return m.fullName.toLowerCase().contains(query) ||
                m.phone.contains(query);
          }).toList();

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.80,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppColors.accentCyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Member Fast Check-In',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: searchCtrl,
                    label: 'Search Member',
                    hint: 'Type member name or phone to check-in...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No matching members found',
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final mem = filtered[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF19202E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF283448),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          primaryColor.withValues(alpha: 0.2),
                                      child: Text(
                                        mem.fullName.isNotEmpty
                                            ? mem.fullName[0]
                                            : 'M',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mem.fullName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            '${mem.membershipPlan} • ${mem.daysRemaining}d valid',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(
                                        Icons.how_to_reg_rounded,
                                        size: 14,
                                      ),
                                      label: Text(
                                        'Pass',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        final tenantId = mem.tenantId ??
                                            widget.authController.currentGymTenant?.id ??
                                            widget.authController.currentUser?.tenantId ??
                                            'default_tenant';
                                        await widget.authController.recordMemberCheckIn(
                                          tenantId: tenantId,
                                          memberId: mem.id,
                                          memberName: mem.fullName,
                                          planName: mem.membershipPlan,
                                          method: 'QR Scan',
                                        );
                                        if (mounted) {
                                          setState(() {
                                            _recentCheckIns = List.from(widget.authController.checkIns);
                                            _members = List.from(widget.authController.members);
                                          });
                                        }
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                        }
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '✨ Check-in verified for ${mem.fullName}!',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            backgroundColor: AppColors.success,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.currentUser;
    final tenant = _resolveCurrentTenant();

    final primaryColor = tenant?.primaryColor ?? const Color(0xFFFF5722);
    final gymTitle = tenant?.gymName ?? (user?.gymName ?? 'IronPulse Fitness Club');
    final adminName = user?.fullName ?? (tenant?.effectiveAdminName ?? 'Gym Admin');
    final gymCode = tenant?.gymCode ?? 'GYM-01';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0E17),
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.6),
            radius: 1.3,
            colors: [
              Color(0xFF141C2E),
              Color(0xFF0A0E17),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ──────── HEADER CONSOLE ────────
              _buildGymHeader(
                gymName: gymTitle,
                adminName: adminName,
                gymCode: gymCode,
                tenant: tenant,
                primaryColor: primaryColor,
              ),

              // ──────── MODERN ATHLETIC TABS ────────
              _buildTabBar(primaryColor),

              // ──────── TAB VIEWS ────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Overview & Live Check-in Stream
                    _buildOverviewTab(primaryColor, tenant),

                    // Tab 2: Members Directory
                    _buildMembersTab(primaryColor),

                    // Tab 3: Batches & Schedules
                    _buildBatchesTab(primaryColor),

                    // Tab 4: Membership Plans & Planners
                    _buildPlansTab(primaryColor),

                    // Tab 5: Expenses & Outflow Ledger
                    _buildExpensesTab(primaryColor),

                    // Tab 6: Team & Staff
                    _buildTeamTab(primaryColor),

                    // Tab 7: Facility & Subscription Plan Details
                    _buildFacilityTab(primaryColor, tenant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedTabIndex == 1
          ? FloatingActionButton(
              backgroundColor: primaryColor,
              foregroundColor: Colors.black,
              elevation: 4,
              child: const Icon(Icons.person_add_rounded),
              onPressed: () => _showAddMemberDialog(primaryColor),
            )
          : (_selectedTabIndex == 2
              ? FloatingActionButton(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  child: const Icon(Icons.add_alarm_rounded),
                  onPressed: () => _showAddEditBatchDialog(primaryColor: primaryColor),
                )
              : (_selectedTabIndex == 3
                  ? FloatingActionButton(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      child: const Icon(Icons.add_card_rounded),
                      onPressed: () => _showAddOrEditPlanDialog(primaryColor: primaryColor),
                    )
                  : (_selectedTabIndex == 4
                      ? FloatingActionButton(
                          backgroundColor: AppColors.accentViolet,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          child: const Icon(Icons.receipt_long_rounded),
                          onPressed: () => _showAddOrEditExpenseDialog(primaryColor: primaryColor),
                        )
                      : (_selectedTabIndex == 5
                          ? FloatingActionButton(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.black,
                              elevation: 4,
                              child: const Icon(Icons.person_add_alt_1_rounded),
                              onPressed: () => _showAddTeamMemberDialog(primaryColor),
                            )
                          : null)))),
    );
  }

  Widget _buildGymHeader({
    required String gymName,
    required String adminName,
    required String gymCode,
    required GymTenantModel? tenant,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101725).withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1E2B3E)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Gym Logo / Initials Badge with glowing ring
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: ImageOptimizer.buildImageWidget(
                    tenant?.logoUrl,
                    fit: BoxFit.cover,
                    placeholder: Center(
                      child: Text(
                        gymName.isNotEmpty ? gymName[0].toUpperCase() : 'G',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            gymName,
                            style: GoogleFonts.poppins(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            'GYM ADMIN',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Manager: $adminName',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondaryDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            gymCode,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2333),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF28364D)),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFFF6B6B),
                    size: 19,
                  ),
                  tooltip: 'Sign Out',
                  onPressed: _handleLogout,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subscription Validity Status Strip
          if (tenant != null)
            _buildSubscriptionStrip(tenant, primaryColor),
        ],
      ),
    );
  }

  Widget _buildSubscriptionStrip(GymTenantModel tenant, Color primaryColor) {
    if (tenant.isLifetimeFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7C3AED).withValues(alpha: 0.22),
              const Color(0xFF4C1D95).withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.all_inclusive_rounded,
              size: 14,
              color: Color(0xFFC4B5FD),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lifetime Free Access • All Management Features Active',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE9D5FF),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final isActive = tenant.isPlanActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [
                  AppColors.success.withValues(alpha: 0.18),
                  const Color(0xFF064E3B).withValues(alpha: 0.10),
                ]
              : [
                  AppColors.error.withValues(alpha: 0.18),
                  const Color(0xFF4C0519).withValues(alpha: 0.10),
                ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.verified_rounded : Icons.warning_amber_rounded,
            size: 14,
            color: isActive ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tenant.effectivePlanName} • ${isActive ? "${tenant.remainingDays}d remaining" : "Expired"} (${tenant.formattedPlanPeriod})',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.success : const Color(0xFFFCA5A5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2B3E)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor,
              primaryColor.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textMutedDark,
        labelStyle: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Overview', icon: Icon(Icons.dashboard_rounded, size: 17)),
          Tab(text: 'Members', icon: Icon(Icons.people_alt_rounded, size: 17)),
          Tab(text: 'Batches', icon: Icon(Icons.schedule_rounded, size: 17)),
          Tab(text: 'Plans', icon: Icon(Icons.card_membership_rounded, size: 17)),
          Tab(text: 'Expenses', icon: Icon(Icons.receipt_long_rounded, size: 17)),
          Tab(text: 'Team', icon: Icon(Icons.groups_2_rounded, size: 17)),
          Tab(text: 'Facility', icon: Icon(Icons.store_rounded, size: 17)),
        ],
      ),
    );
  }

  // ──────── TAB 1: OVERVIEW ────────
  Widget _buildOverviewTab(Color primaryColor, GymTenantModel? tenant) {
    final activeMembers = _members.where((m) => m.isActive).length;
    final onDutyTeam = _teamMembers.where((t) => t.isOnDuty).length;

    // Dynamically calculate revenue / monthly volume from paying active members
    final payingActiveMembers = _members.where((m) => m.isActive && !m.isLifetimeFree).toList();
    double monthlyVolume = 0;
    for (final member in payingActiveMembers) {
      final plan = _membershipPlans.where((p) => p.name == member.membershipPlan || p.id == member.membershipPlanId).firstOrNull;
      if (plan != null) {
        monthlyVolume += member.calculateFinalPrice(plan.price);
      }
    }

    final String formattedVolume;
    if (monthlyVolume >= 100000) {
      formattedVolume = '₹${(monthlyVolume / 100000).toStringAsFixed(2)}L';
    } else if (monthlyVolume >= 1000) {
      formattedVolume = '₹${monthlyVolume.toStringAsFixed(0)}';
    } else {
      formattedVolume = '₹${monthlyVolume.toInt()}';
    }

    final String volumeSub;
    if (payingActiveMembers.isNotEmpty) {
      volumeSub = '${payingActiveMembers.length} paying active';
    } else if (_membershipPlans.isNotEmpty) {
      volumeSub = '${_membershipPlans.length} plans created';
    } else {
      volumeSub = 'No revenue yet';
    }

    return RefreshIndicator(
      color: primaryColor,
      backgroundColor: const Color(0xFF19202E),
      onRefresh: () => _refreshOverviewData(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Sales & Revenue Analytics Chart Section (Top of Tab)
            _buildSalesAnalyticsCard(primaryColor, monthlyVolume, payingActiveMembers),
            const SizedBox(height: 16),

            // 2. Expenses & Outflow Analytics Chart Section
            _buildExpensesAnalyticsCard(primaryColor),
            const SizedBox(height: 18),

            // 3. 4 Metric KPI Cards
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Active Members',
                    value: '$activeMembers',
                    sub: activeMembers > 0 ? '$activeMembers active' : 'No members yet',
                    icon: Icons.groups_rounded,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Today Check-ins',
                    value: '${_recentCheckIns.length}',
                    sub: _recentCheckIns.isNotEmpty ? '${_recentCheckIns.length} recorded' : 'No entries yet',
                    icon: Icons.qr_code_scanner_rounded,
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Team on Duty',
                    value: '$onDutyTeam / ${_teamMembers.length}',
                    sub: _teamMembers.isNotEmpty ? '$onDutyTeam staff present' : 'No staff added',
                    icon: Icons.groups_2_rounded,
                    color: AppColors.accentAmber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Monthly Volume',
                    value: formattedVolume,
                    sub: volumeSub,
                    icon: Icons.currency_rupee_rounded,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4. Fast Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'QUICK OPERATIONS',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryDark,
                    letterSpacing: 0.8,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Shortcuts',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    label: 'Fast Check-In',
                    icon: Icons.qr_code_scanner_rounded,
                    color: AppColors.accentCyan,
                    onTap: () => _showQuickCheckInDialog(primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    label: 'Enroll Member',
                    icon: Icons.person_add_alt_1_rounded,
                    color: primaryColor,
                    onTap: () => _showAddMemberDialog(primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Live Activity Check-In Stream
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'LIVE CHECK-IN ACTIVITY',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondaryDark,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'Real-time',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_recentCheckIns.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A26),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF202C3E)),
                ),
                child: Center(
                  child: Text(
                    'No check-ins recorded today. Use Fast Check-In to record entries.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._recentCheckIns.map((log) => _buildCheckInLogRow(log, primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151E2E),
            Color(0xFF0E1420),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223047), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.25),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInLogRow(GymCheckInLog log, Color primaryColor) {
    final timeStr = DateFormat('hh:mm a').format(log.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131A26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF202C3E)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.3),
                  primaryColor.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: primaryColor.withValues(alpha: 0.6)),
            ),
            child: Center(
              child: Text(
                log.memberName.isNotEmpty ? log.memberName[0] : 'M',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.memberName,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.planName} • $timeStr',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
            ),
            child: Text(
              log.method,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.accentCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────── SALES & EXPENSES ANALYTICS CHARTS ────────

  Widget _buildSalesAnalyticsCard(
    Color primaryColor,
    double totalRevenue,
    List<GymMemberRecord> payingMembers,
  ) {
    final now = DateTime.now();
    final List<String> xLabels;
    final List<double> chartPoints;
    final double periodTotal;
    final String timeframeMetricLabel;
    final String timeframeSubLabel;

    // Helper map of member paid amounts
    final Map<String, double> memberPaidAmounts = {};
    for (final member in payingMembers) {
      final plan = _membershipPlans.where(
        (p) => p.name == member.membershipPlan || p.id == member.membershipPlanId,
      ).firstOrNull;
      if (plan != null) {
        memberPaidAmounts[member.id] = member.calculateFinalPrice(plan.price);
      }
    }

    if (_salesTimeframe == 'Year') {
      // 6 Bi-Monthly Buckets spanning the full year (Jan-Feb, Mar-Apr, May-Jun, Jul-Aug, Sep-Oct, Nov-Dec)
      xLabels = const ['Jan-Feb', 'Mar-Apr', 'May-Jun', 'Jul-Aug', 'Sep-Oct', 'Nov-Dec'];
      final List<double> biMonthlyBuckets = List.filled(6, 0.0);
      int yearEnrollmentCount = 0;

      for (final member in payingMembers) {
        final amount = memberPaidAmounts[member.id] ?? 0.0;
        if (amount <= 0) continue;

        final enrollmentDate = member.startDate;
        if (enrollmentDate.year == now.year && enrollmentDate.month >= 1 && enrollmentDate.month <= 12) {
          final bucketIdx = ((enrollmentDate.month - 1) ~/ 2).clamp(0, 5);
          biMonthlyBuckets[bucketIdx] += amount;
          yearEnrollmentCount++;
        } else if (member.isActive) {
          // If member is active in current year, credit into current active period
          final currentBucketIdx = ((now.month - 1) ~/ 2).clamp(0, 5);
          biMonthlyBuckets[currentBucketIdx] += amount;
          yearEnrollmentCount++;
        }
      }

      final totalYearSales = biMonthlyBuckets.fold<double>(0.0, (sum, val) => sum + val);
      chartPoints = biMonthlyBuckets;
      periodTotal = totalYearSales;
      timeframeMetricLabel = '${now.year} Annual Inflow';
      timeframeSubLabel = totalYearSales > 0
          ? '$yearEnrollmentCount memberships recorded in ${now.year}'
          : 'No member enrollments in ${now.year} yet';
    } else if (_salesTimeframe == 'Month') {
      // 4 Weeks of Current Month
      xLabels = const ['W1', 'W2', 'W3', 'W4'];
      final List<double> weekBuckets = List.filled(4, 0.0);
      int monthEnrollmentCount = 0;

      for (final member in payingMembers) {
        final amount = memberPaidAmounts[member.id] ?? 0.0;
        if (amount <= 0) continue;

        final enrollmentDate = member.startDate;
        if (enrollmentDate.year == now.year && enrollmentDate.month == now.month) {
          final day = enrollmentDate.day;
          if (day <= 7) {
            weekBuckets[0] += amount;
          } else if (day <= 14) {
            weekBuckets[1] += amount;
          } else if (day <= 21) {
            weekBuckets[2] += amount;
          } else {
            weekBuckets[3] += amount;
          }
          monthEnrollmentCount++;
        } else if (member.isActive) {
          final currentWeekIdx = ((now.day - 1) ~/ 7).clamp(0, 3);
          weekBuckets[currentWeekIdx] += amount;
          monthEnrollmentCount++;
        }
      }

      final totalMonthSales = weekBuckets.fold<double>(0.0, (sum, val) => sum + val);
      chartPoints = weekBuckets;
      periodTotal = totalMonthSales;
      timeframeMetricLabel = 'This Month (${DateFormat('MMMM').format(now)})';
      timeframeSubLabel = totalMonthSales > 0
          ? '$monthEnrollmentCount active memberships this month'
          : 'No member enrollments this month yet';
    } else {
      // Default: 'Week' (Monday to Sunday of the current week)
      xLabels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final List<double> dayBuckets = List.filled(7, 0.0);
      final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
      final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: currentWeekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      int weekEnrollmentCount = 0;

      for (final member in payingMembers) {
        final amount = memberPaidAmounts[member.id] ?? 0.0;
        if (amount <= 0) continue;

        final enrollmentDate = member.startDate;
        if (enrollmentDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            enrollmentDate.isBefore(endOfWeek)) {
          final dayIdx = (enrollmentDate.weekday - 1).clamp(0, 6);
          dayBuckets[dayIdx] += amount;
          weekEnrollmentCount++;
        } else if (member.isActive) {
          final todayIdx = (now.weekday - 1).clamp(0, 6);
          dayBuckets[todayIdx] += amount;
          weekEnrollmentCount++;
        }
      }

      final totalWeekSales = dayBuckets.fold<double>(0.0, (sum, val) => sum + val);
      chartPoints = dayBuckets;
      periodTotal = totalWeekSales;
      timeframeMetricLabel = 'Current Week Inflow';
      timeframeSubLabel = totalWeekSales > 0
          ? '$weekEnrollmentCount memberships this week'
          : 'No member enrollments this week yet';
    }

    final formattedPeriodRevenue = periodTotal >= 100000
        ? '₹${(periodTotal / 100000).toStringAsFixed(2)}L'
        : '₹${periodTotal.toStringAsFixed(periodTotal % 1 == 0 ? 0 : 2)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151E2E),
            Color(0xFF0E1420),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223047), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.25),
                          primaryColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                    ),
                    child: Icon(Icons.auto_graph_rounded, color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SALES & REVENUE',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        timeframeMetricLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Timeframe Toggle Pills
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1019),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1D283A)),
                ),
                child: Row(
                  children: ['Week', 'Month', 'Year'].map((tf) {
                    final isSel = _salesTimeframe == tf;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _salesTimeframe = tf;
                          _selectedSalesPointIndex = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tf,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? Colors.black : AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Sales Metric Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedPeriodRevenue,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        totalRevenue > 0 ? Icons.trending_up_rounded : Icons.info_outline_rounded,
                        color: totalRevenue > 0 ? AppColors.success : AppColors.textSecondaryDark,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeframeSubLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: periodTotal > 0 ? AppColors.success : AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_selectedSalesPointIndex != null &&
                  _selectedSalesPointIndex! < chartPoints.length &&
                  _selectedSalesPointIndex! < xLabels.length)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${xLabels[_selectedSalesPointIndex!]}: ₹${chartPoints[_selectedSalesPointIndex!].toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Painted Spline Area Chart
          GestureDetector(
            onTapDown: (details) {
              final width = MediaQuery.of(context).size.width - 64;
              final step = width / (chartPoints.length - 1);
              final touchedIdx = (details.localPosition.dx / step).round().clamp(0, chartPoints.length - 1);
              setState(() {
                _selectedSalesPointIndex = touchedIdx;
              });
            },
            child: Container(
              height: 140,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CustomPaint(
                painter: _SalesChartPainter(
                  values: chartPoints,
                  labels: xLabels,
                  lineColor: primaryColor,
                  selectedIndex: _selectedSalesPointIndex,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // X-Axis Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: xLabels.map((lbl) {
              final idx = xLabels.indexOf(lbl);
              final isSel = _selectedSalesPointIndex == idx;
              return Text(
                lbl,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? primaryColor : AppColors.textSecondaryDark,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 3 Bottom Metric Stat Chips
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1622),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1D283A)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSalesStatItem(
                    label: 'Paying Members',
                    value: '${payingMembers.length}',
                    color: primaryColor,
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0xFF223047)),
                Expanded(
                  child: _buildSalesStatItem(
                    label: 'Discounted',
                    value: '${_members.where((m) => m.hasDiscount).length}',
                    color: AppColors.accentEmerald,
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0xFF223047)),
                Expanded(
                  child: _buildSalesStatItem(
                    label: 'Avg Ticket',
                    value: '₹${payingMembers.isNotEmpty ? (totalRevenue / payingMembers.length).round() : 0}',
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.textSecondaryDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildExpensesAnalyticsCard(Color primaryColor) {
    final totalExpenses = _expenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    // Group active expenses dynamically by category
    final Map<String, double> categorySums = {};
    for (final exp in _expenses) {
      categorySums[exp.category] = (categorySums[exp.category] ?? 0.0) + exp.amount;
    }

    // Build active category list sorted by spend amount descending
    final activeCategories = categorySums.entries.map((entry) {
      final cat = GymExpenseCategory.fromString(entry.key);
      final pct = totalExpenses > 0 ? entry.value / totalExpenses : 0.0;
      return {
        'name': cat.label,
        'amount': entry.value,
        'pct': pct,
        'color': cat.color,
        'icon': cat.icon,
      };
    }).toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    final String formattedTotal;
    if (totalExpenses >= 100000) {
      formattedTotal = '₹${(totalExpenses / 100000).toStringAsFixed(2)}L';
    } else if (totalExpenses >= 1000) {
      formattedTotal = '₹${totalExpenses.toStringAsFixed(totalExpenses % 1 == 0 ? 0 : 2)}';
    } else {
      formattedTotal = '₹${totalExpenses.toInt()}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151E2E),
            Color(0xFF0E1420),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223047), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentViolet.withValues(alpha: 0.25),
                          AppColors.accentViolet.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.pie_chart_rounded, color: AppColors.accentViolet, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPENSES & CASH OUTFLOW',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        _expenses.isEmpty ? 'No expenses recorded yet' : '${_expenses.length} entries recorded',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentViolet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _expenses.isEmpty ? '₹0 Logged' : formattedTotal,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentViolet,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Donut Chart & Category Legend Row
          if (_expenses.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF101724),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1F2B3E)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(70, 70),
                          painter: _ExpensesDonutPainter(
                            percentages: const [],
                            colors: const [],
                          ),
                        ),
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 24,
                          color: AppColors.textMutedDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Outflows Logged',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Track facility rent, equipment maintenance, electricity, and payroll to view live breakdown.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondaryDark,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                // Left Donut Canvas
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: _ExpensesDonutPainter(
                          percentages: activeCategories.map((c) => c['pct'] as double).toList(),
                          colors: activeCategories.map((c) => c['color'] as Color).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Colors.white70),
                          const SizedBox(height: 2),
                          Text(
                            formattedTotal,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Total Outflow',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Right Category Breakdown Items
                Expanded(
                  child: Column(
                    children: activeCategories.take(5).map((cat) {
                      final color = cat['color'] as Color;
                      final pct = ((cat['pct'] as double) * 100).round();
                      final name = cat['name'] as String;
                      final icon = cat['icon'] as IconData;
                      final amt = cat['amount'] as double;
                      final amtStr = amt >= 1000 ? '₹${amt.toInt()}' : '₹${amt.toStringAsFixed(0)}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(icon, size: 13, color: color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              amtStr,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$pct%',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Bottom Action: Record Expense Entry Button
          InkWell(
            onTap: () => _showAddOrEditExpenseDialog(primaryColor: primaryColor),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF101724),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F2B3E)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.accentViolet, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Record Operational Expense',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentViolet.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+ Add Expense',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentViolet,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────── TAB 2: MEMBERS DIRECTORY ────────
  Widget _buildMembersTab(Color primaryColor) {
    final query = _memberSearchQuery.trim().toLowerCase();
    final filtered = _members.where((m) {
      final matchesQuery = m.fullName.toLowerCase().contains(query) ||
          m.phone.contains(query) ||
          m.membershipPlan.toLowerCase().contains(query);
      if (_selectedMemberFilter == 'Expiring') {
        return matchesQuery && m.isExpiringSoon;
      } else if (_selectedMemberFilter == 'Active') {
        return matchesQuery && m.isActive;
      }
      return matchesQuery;
    }).toList();

    final hasMore = widget.authController.hasMoreMembers;
    final isLoadingMore = widget.authController.isLoadingMembers && _members.isNotEmpty;

    return Column(
      children: [
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CustomTextField(
                label: 'Search Directory',
                hint: 'Search members by name, phone, or plan...',
                prefixIcon: Icons.search_rounded,
                onChanged: (val) => setState(() => _memberSearchQuery = val),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Active', 'Expiring'].map((filter) {
                    final isSelected = _selectedMemberFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          filter,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: primaryColor,
                        backgroundColor: const Color(0xFF19202E),
                        onSelected: (_) => _fetchMembersWithServerFilter(filter),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Member list with Firestore Pagination
        Expanded(
          child: _members.isEmpty && widget.authController.isLoadingMembers
              ? Center(
                  child: CircularProgressIndicator(color: primaryColor),
                )
              : (_members.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 48,
                                color: primaryColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No Members Enrolled Yet',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enroll gym members to manage their membership validities, packages, and attendance.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondaryDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: Text(
                                'Enroll First Member',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                              onPressed: () => _showAddMemberDialog(primaryColor),
                            ),
                          ],
                        ),
                      ),
                    )
                  : (filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No matching members found',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondaryDark),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length + (hasMore ? 1 : 0),
                          itemBuilder: (context, idx) {
                            if (idx == filtered.length) {
                              return Container(
                                margin: const EdgeInsets.only(top: 8, bottom: 24),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131A26),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF202C3E)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Page ${widget.authController.currentMembersPage} (20 per page)',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: isLoadingMore ? null : _fetchNextMembersPage,
                                      icon: isLoadingMore
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            )
                                          : const Icon(Icons.arrow_forward_rounded, size: 16),
                                      label: Text(
                                        isLoadingMore ? 'Loading...' : 'Load Next 20',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final member = filtered[idx];
                            return _buildMemberCard(member, primaryColor);
                          },
                        ))),
        ),
      ],
    );
  }

  Widget _buildMemberCard(GymMemberRecord member, Color primaryColor) {
    final isExp = member.isExpiringSoon;
    final isExpired = member.isExpired;
    final statusColor = isExpired
        ? AppColors.error
        : (isExp ? AppColors.accentAmber : AppColors.success);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141D2B),
            Color(0xFF0F1522),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? AppColors.error.withValues(alpha: 0.6)
              : (isExp
                  ? AppColors.accentAmber.withValues(alpha: 0.6)
                  : const Color(0xFF223047)),
          width: (isExp || isExpired) ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? AppColors.error : (isExp ? AppColors.accentAmber : Colors.black))
                .withValues(alpha: (isExp || isExpired) ? 0.15 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Member Profile Photo or Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF192231),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: ImageOptimizer.buildImageWidget(
                    member.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: Center(
                      child: Text(
                        member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'M',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.fullName,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Gender & Age Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            member.age != null ? '${member.gender} • ${member.age}y' : member.gender,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.email.isNotEmpty ? member.email : member.phone,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Expiry / Active Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: member.isLifetimeFree
                      ? AppColors.accentViolet.withValues(alpha: 0.2)
                      : statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: member.isLifetimeFree
                        ? AppColors.accentViolet.withValues(alpha: 0.5)
                        : statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  member.isLifetimeFree
                      ? '♾️ Lifetime Free'
                      : (isExpired
                          ? 'Expired'
                          : (isExp
                              ? 'Expiring (${member.daysRemaining}d)'
                              : 'Active (${member.daysRemaining}d)')),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: member.isLifetimeFree ? AppColors.accentViolet : statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Plan & Phone Information Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF101724),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1D283A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      member.isLifetimeFree ? Icons.all_inclusive_rounded : Icons.workspace_premium_rounded,
                      size: 14,
                      color: member.isLifetimeFree ? AppColors.accentViolet : primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      member.isLifetimeFree ? 'Plan: VIP Lifetime Free' : 'Plan: ${member.membershipPlan}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (member.hasDiscount) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.accentEmerald.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '🏷️ ${member.formattedDiscount}',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentEmerald,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 13, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 4),
                    Text(
                      member.phone,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Plan Validity Schedule Display
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isExpired
                  ? AppColors.error.withValues(alpha: 0.1)
                  : const Color(0xFF101724),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isExpired
                    ? AppColors.error.withValues(alpha: 0.3)
                    : const Color(0xFF1D283A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  member.isLifetimeFree
                      ? Icons.all_inclusive_rounded
                      : (isExpired ? Icons.event_busy_rounded : Icons.date_range_rounded),
                  size: 13,
                  color: member.isLifetimeFree
                      ? AppColors.accentViolet
                      : (isExpired ? AppColors.error : AppColors.accentCyan),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    member.isLifetimeFree
                        ? 'Validity: Lifetime Access (Never Expires)'
                        : (isExpired
                            ? 'Expired on ${DateFormat('dd MMM yyyy').format(member.expiryDate)} (Started: ${DateFormat('dd MMM yyyy').format(member.startDate)})'
                            : 'Plan Schedule: ${DateFormat('dd MMM yyyy').format(member.startDate)} → ${DateFormat('dd MMM yyyy').format(member.expiryDate)}'),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: member.isLifetimeFree
                          ? AppColors.accentViolet
                          : (isExpired ? AppColors.error : AppColors.textSecondaryDark),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Assigned Batch Display Tag
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: member.batchName != null && member.batchName!.isNotEmpty
                  ? AppColors.accentCyan.withValues(alpha: 0.12)
                  : const Color(0xFF101724),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: member.batchName != null && member.batchName!.isNotEmpty
                    ? AppColors.accentCyan.withValues(alpha: 0.35)
                    : const Color(0xFF1D283A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: member.batchName != null && member.batchName!.isNotEmpty
                      ? AppColors.accentCyan
                      : Colors.white38,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    member.batchName != null && member.batchName!.isNotEmpty
                        ? 'Batch: ${member.batchName}'
                        : 'Batch: Unassigned',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: member.batchName != null && member.batchName!.isNotEmpty
                          ? AppColors.accentCyan
                          : Colors.white38,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Fitness Goal & Physical Metrics (Weight, Height, BMI)
          if (member.goal != null || member.weight != null || member.height != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.track_changes_rounded, size: 14, color: primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Goal: ${member.formattedGoal}  •  ${member.formattedWeight}  •  ${member.formattedHeight}${member.bmi != null ? '  •  BMI: ${member.formattedBmi}' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Optional Emergency Contact Section
          if (member.hasEmergencyContact) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emergency_outlined, size: 14, color: AppColors.accentAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Emergency: ${member.emergencyContactName ?? 'Contact'} (${member.emergencyContactRelation ?? 'Relation'}) • ${member.emergencyPhone ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFDE68A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Optional Address Display
          if (member.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondaryDark),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    member.address,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppColors.textSecondaryDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          // Action Buttons: Quick Check-In & Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Check-Ins: ${member.totalCheckIns}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      final tenantId = member.tenantId ??
                          widget.authController.currentGymTenant?.id ??
                          widget.authController.currentUser?.tenantId ??
                          'default_tenant';
                      await widget.authController.recordMemberCheckIn(
                        tenantId: tenantId,
                        memberId: member.id,
                        memberName: member.fullName,
                        planName: member.membershipPlan,
                        method: 'Manual Pass',
                      );
                      if (mounted) {
                        setState(() {
                          _members = List.from(widget.authController.members);
                          _recentCheckIns = List.from(widget.authController.checkIns);
                        });
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Checked in ${member.fullName} successfully!',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 13, color: AppColors.accentCyan),
                          const SizedBox(width: 5),
                          Text(
                            'Check In',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showEditMemberDialog(member, primaryColor),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_outlined, size: 13, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white38),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: const Color(0xFF141923),
                          title: Text(
                            'Remove Member?',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          content: Text(
                            'Are you sure you want to remove ${member.fullName} from the gym registry?',
                            style: GoogleFonts.inter(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Remove', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await widget.authController.deleteGymMember(
                          widget.authController.currentGymTenant?.id ?? 'tenant_metro_01',
                          member.id,
                        );
                        setState(() {
                          _members = List.from(widget.authController.members);
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTeamMemberDialog(Color primaryColor) {
    final nameCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    GymTeamRole selectedRole = GymTeamRole.trainer;
    String selectedGender = 'Male';
    bool isOnDuty = true;
    Uint8List? selectedAvatarBytes;
    bool isOptimizingAvatar = false;
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          Future<void> pickAvatar(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: source);
              if (picked == null) return;

              setModalState(() => isOptimizingAvatar = true);
              final rawBytes = await picked.readAsBytes();
              final result = await ImageOptimizer.optimizeImage(
                rawBytes,
                maxDimension: 512,
                quality: 85,
              );
              setModalState(() {
                selectedAvatarBytes = result.bytes;
                isOptimizingAvatar = false;
              });
            } catch (e) {
              setModalState(() => isOptimizingAvatar = false);
              debugPrint('Error picking avatar: $e');
            }
          }

          void showImageSourcePicker() {
            showModalBottomSheet(
              context: ctx,
              backgroundColor: const Color(0xFF19202E),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (pickerCtx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Select Profile Photo',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF222B3C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.camera_alt_rounded, color: AppColors.accentCyan),
                              label: const Text('Camera'),
                              onPressed: () {
                                Navigator.pop(pickerCtx);
                                pickAvatar(ImageSource.camera);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF222B3C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.photo_library_rounded, color: AppColors.accentAmber),
                              label: const Text('Gallery'),
                              onPressed: () {
                                Navigator.pop(pickerCtx);
                                pickAvatar(ImageSource.gallery);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.88,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 14,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedRole.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.group_add_rounded,
                                color: selectedRole.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Add Team Member',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── AVATAR / IMAGE PICKER ──
                            Center(
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: showImageSourcePicker,
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: selectedRole.color.withValues(alpha: 0.15),
                                            border: Border.all(
                                              color: selectedRole.color,
                                              width: 2.5,
                                            ),
                                          ),
                                          child: isOptimizingAvatar
                                              ? Center(
                                                  child: SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: selectedRole.color,
                                                    ),
                                                  ),
                                                )
                                              : (selectedAvatarBytes != null
                                                  ? ClipOval(
                                                      child: Image.memory(
                                                        selectedAvatarBytes!,
                                                        width: 80,
                                                        height: 80,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  : Icon(
                                                      selectedRole.icon,
                                                      color: selectedRole.color,
                                                      size: 38,
                                                    )),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: selectedRole.color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF141923),
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton(
                                    onPressed: showImageSourcePicker,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      selectedAvatarBytes != null ? 'Change Photo' : 'Upload Profile Photo',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: selectedRole.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── FULL NAME ──
                            CustomTextField(
                              controller: nameCtrl,
                              label: 'Full Name',
                              hint: 'e.g. David Sterling',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter member name'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // ── ROLE SELECTION ──
                            Text(
                              'SELECT ROLE',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryDark,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: GymTeamRole.values.map((role) {
                                final isSelected = selectedRole == role;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: role != GymTeamRole.trainer ? 8 : 0,
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setModalState(() => selectedRole = role);
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? role.color.withValues(alpha: 0.2)
                                              : const Color(0xFF19202E),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? role.color
                                                : const Color(0xFF2B3648),
                                            width: isSelected ? 1.8 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              role.icon,
                                              size: 20,
                                              color: isSelected
                                                  ? role.color
                                                  : AppColors.textMutedDark,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              role.displayName,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppColors.textMutedDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // ── CONDITIONAL EXPERIENCE & GENDER (FOR TRAINER) ──
                            if (selectedRole == GymTeamRole.trainer) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.accentAmber.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.accentAmber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.work_history_rounded,
                                          color: AppColors.accentAmber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Trainer Experience',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    CustomTextField(
                                      controller: expCtrl,
                                      label: 'Experience (Years / Background)',
                                      hint: 'e.g. 5 Years Exp',
                                      prefixIcon: Icons.workspace_premium_rounded,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        '1-2 Years Exp',
                                        '3-5 Years Exp',
                                        '5-8 Years Exp',
                                        '8+ Years Exp',
                                      ].map((preset) {
                                        final isChosen = expCtrl.text == preset;
                                        return InkWell(
                                          onTap: () {
                                            setModalState(() => expCtrl.text = preset);
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isChosen
                                                  ? AppColors.accentAmber
                                                  : const Color(0xFF19202E),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isChosen
                                                    ? AppColors.accentAmber
                                                    : const Color(0xFF2B3648),
                                              ),
                                            ),
                                            child: Text(
                                              preset,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isChosen
                                                    ? Colors.black
                                                    : Colors.white70,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 14),

                                    // ── GENDER DROPDOWN ──
                                    Text(
                                      'Trainer Gender',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF19202E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF2B3648)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedGender,
                                          dropdownColor: const Color(0xFF19202E),
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppColors.accentAmber,
                                          ),
                                          isExpanded: true,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Male',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.male_rounded, color: AppColors.accentCyan, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Male'),
                                                ],
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Female',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.female_rounded, color: Color(0xFFF472B6), size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Female'),
                                                ],
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Other',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.transgender_rounded, color: AppColors.accentAmber, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Other'),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setModalState(() => selectedGender = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── SPECIALTY / DEPARTMENT (FOR TRAINER & MANAGER) ──
                            if (selectedRole != GymTeamRole.owner) ...[
                              CustomTextField(
                                controller: specialtyCtrl,
                                label: selectedRole == GymTeamRole.trainer
                                    ? 'Specialty / Training Focus'
                                    : 'Department / Operations Focus',
                                hint: selectedRole == GymTeamRole.trainer
                                    ? 'e.g. Hypertrophy, CrossFit & HIIT'
                                    : 'e.g. Operations & Member Relations',
                                prefixIcon: Icons.stars_rounded,
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ── PHONE & EMAIL ──
                            CustomTextField(
                              controller: phoneCtrl,
                              label: 'Phone Number',
                              hint: '+91 98765 43210',
                              prefixIcon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              controller: emailCtrl,
                              label: 'Email Address',
                              hint: 'member@gym.com',
                              prefixIcon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),

                            // ── ON DUTY STATUS TOGGLE ──
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF19202E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF2B3648)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isOnDuty ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                                        color: isOnDuty ? AppColors.success : AppColors.textMutedDark,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'On Duty / Active Today',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: isOnDuty,
                                    activeThumbColor: selectedRole.color,
                                    onChanged: (val) {
                                      setModalState(() => isOnDuty = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // ── SUBMIT BUTTON ──
                            CustomButton(
                              text: 'Create Team Member',
                              icon: Icons.person_add_alt_1_rounded,
                              customColor: selectedRole.color,
                              isLoading: isSubmitting,
                              onPressed: isSubmitting
                                  ? () {}
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      setModalState(() => isSubmitting = true);

                                      final tenantId = widget.authController.currentGymTenant?.id ??
                                          widget.authController.currentUser?.tenantId ??
                                          'default_tenant';

                                      final newMember = GymTeamMemberRecord(
                                        id: 'team_${DateTime.now().millisecondsSinceEpoch}',
                                        tenantId: tenantId,
                                        fullName: nameCtrl.text.trim(),
                                        role: selectedRole,
                                        gender: selectedRole == GymTeamRole.trainer ? selectedGender : null,
                                        experience: selectedRole == GymTeamRole.trainer
                                            ? (expCtrl.text.trim().isNotEmpty
                                                ? expCtrl.text.trim()
                                                : '3+ Years Exp')
                                            : null,
                                        specialty: selectedRole == GymTeamRole.owner
                                            ? 'Gym Owner'
                                            : (specialtyCtrl.text.trim().isNotEmpty
                                                ? specialtyCtrl.text.trim()
                                                : (selectedRole == GymTeamRole.trainer
                                                    ? 'Strength & Conditioning'
                                                    : 'Operations & Management')),
                                        phone: phoneCtrl.text.trim().isNotEmpty
                                            ? phoneCtrl.text.trim()
                                            : '+91 98765 43210',
                                        email: emailCtrl.text.trim().isNotEmpty
                                            ? emailCtrl.text.trim()
                                            : '${nameCtrl.text.trim().toLowerCase().replaceAll(' ', '.')}@facility.com',
                                        isOnDuty: isOnDuty,
                                        imageBytes: selectedAvatarBytes,
                                        activeClientsCount: selectedRole == GymTeamRole.trainer ? 10 : 0,
                                        rating: 4.95,
                                        createdAt: DateTime.now(),
                                      );

                                      await widget.authController.addTeamMember(
                                        newMember,
                                        photoBytes: selectedAvatarBytes,
                                      );

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }

                                      if (mounted) {
                                        setState(() {
                                          _teamMembers = List.from(widget.authController.teamMembers);
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Added ${newMember.fullName} (${newMember.role.displayName}) to Firebase & Team!',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            backgroundColor: newMember.role.color,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────── TAB 3: MEMBERSHIP PLANS & PRICING MANAGEMENT ────────
  void _showAddOrEditPlanDialog({
    required Color primaryColor,
    GymMembershipPlanModel? existingPlan,
  }) {
    final isEditing = existingPlan != null;
    final nameCtrl = TextEditingController(text: existingPlan?.name ?? '');
    final descriptionCtrl = TextEditingController(
        text: existingPlan != null ? existingPlan.description : '');
    final priceCtrl = TextEditingController(
        text: existingPlan != null ? existingPlan.price.toStringAsFixed(0) : '');
    final admissionCtrl = TextEditingController(
        text: existingPlan != null ? existingPlan.admissionFee.toStringAsFixed(0) : '0');
    final customDaysCtrl = TextEditingController(
        text: existingPlan != null ? existingPlan.durationDays.toString() : '');
    final customCheckInsCtrl = TextEditingController(
        text: (existingPlan != null && existingPlan.maxCheckInsPerDay > 0)
            ? '${existingPlan.maxCheckInsPerDay}'
            : '0');

    String selectedCategory = existingPlan?.category ?? 'Strength & Cardio';
    String selectedPlanType = existingPlan?.planType ?? 'Yearly';
    String selectedAccessType = existingPlan?.accessType ?? '24/7 Full Access';
    int selectedMaxCheckIns = existingPlan?.maxCheckInsPerDay ?? 0;
    int selectedDurationDays = existingPlan?.durationDays ?? 365;
    bool isCustomDuration = existingPlan != null
        ? (![30, 90, 180, 365].contains(existingPlan.durationDays) || existingPlan.planType == 'Custom')
        : false;
    bool isCustomCheckIns = existingPlan != null
        ? (![0, 1, 2, 3].contains(existingPlan.maxCheckInsPerDay))
        : false;
    bool isPopular = existingPlan?.isPopular ?? false;
    bool isActive = existingPlan?.isActive ?? true;
    Color selectedAccentColor = existingPlan?.accentColor ?? primaryColor;

    List<String> features = existingPlan != null
        ? List<String>.from(existingPlan.features)
        : [];

    final customPerkCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Available presets for quick perk toggle
    final quickPerkOptions = [
      '24/7 Gym Floor Access',
      'Full Cardio & Strength Zones',
      'Personal Locker & Shower',
      'Steam & Sauna Access',
      '1x Free Trainer Consultation',
      'Custom Diet & Nutrition Chart',
      'Unlimited Group Yoga & HIIT',
      'VIP Lounge & Towel Service',
      'CrossFit & Functional Rig',
      'Complimentary Guest Passes',
    ];

    // Color options
    final colorOptions = [
      const Color(0xFFFF5722), // Flame Orange
      const Color(0xFF00E599), // Emerald
      const Color(0xFFA855F7), // Neon Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF59E0B), // Amber Gold
      const Color(0xFFF43F5E), // Rose Pink
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.92,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selectedAccentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.card_membership_rounded,
                              color: selectedAccentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEditing ? 'Edit Membership Plan' : 'Create Membership Plan',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick Presets Bar (only if not editing)
                          if (!isEditing) ...[
                            Text(
                              'QUICK TEMPLATES',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondaryDark,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildTemplateChip(
                                    label: 'Gold Yearly (₹18K)',
                                    color: const Color(0xFFFF5722),
                                    onTap: () {
                                      setModalState(() {
                                        nameCtrl.text = 'Gold Annual Pass';
                                        descriptionCtrl.text = 'Full gym access + personal locker & steam bath';
                                        priceCtrl.text = '18000';
                                        admissionCtrl.text = '0';
                                        selectedPlanType = 'Yearly';
                                        selectedAccessType = '24/7 Full Access';
                                        selectedMaxCheckIns = 0;
                                        isCustomCheckIns = false;
                                        selectedCategory = 'Strength & Cardio';
                                        selectedDurationDays = 365;
                                        isCustomDuration = false;
                                        selectedAccentColor = const Color(0xFFFF5722);
                                        isPopular = true;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTemplateChip(
                                    label: 'Monthly HIIT (₹2.5K)',
                                    color: const Color(0xFF00E599),
                                    onTap: () {
                                      setModalState(() {
                                        nameCtrl.text = 'Monthly HIIT & Strength';
                                        descriptionCtrl.text = 'Month-to-month fat burn & functional training';
                                        priceCtrl.text = '2499';
                                        admissionCtrl.text = '500';
                                        selectedPlanType = 'Monthly';
                                        selectedAccessType = 'Peak & Group Hours';
                                        selectedMaxCheckIns = 1;
                                        isCustomCheckIns = false;
                                        selectedCategory = 'HIIT & Group';
                                        selectedDurationDays = 30;
                                        isCustomDuration = false;
                                        selectedAccentColor = const Color(0xFF00E599);
                                        isPopular = false;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTemplateChip(
                                    label: 'Platinum VIP (₹28K)',
                                    color: const Color(0xFFA855F7),
                                    onTap: () {
                                      setModalState(() {
                                        nameCtrl.text = 'Platinum All-Access VIP';
                                        descriptionCtrl.text = 'VIP access with 4x monthly 1-on-1 PT sessions';
                                        priceCtrl.text = '28000';
                                        admissionCtrl.text = '0';
                                        selectedPlanType = 'Yearly';
                                        selectedAccessType = '24/7 Full Access';
                                        selectedMaxCheckIns = 0;
                                        isCustomCheckIns = false;
                                        selectedCategory = 'VIP All-Access';
                                        selectedDurationDays = 365;
                                        isCustomDuration = false;
                                        selectedAccentColor = const Color(0xFFA855F7);
                                        isPopular = false;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTemplateChip(
                                    label: 'Quarterly Cardio (₹6.5K)',
                                    color: const Color(0xFF06B6D4),
                                    onTap: () {
                                      setModalState(() {
                                        nameCtrl.text = 'Quarterly Cardio Plus';
                                        descriptionCtrl.text = '3-Month endurance & treadmill coaching';
                                        priceCtrl.text = '6500';
                                        admissionCtrl.text = '0';
                                        selectedPlanType = 'Quarterly';
                                        selectedAccessType = 'Standard (Gym Hours)';
                                        selectedMaxCheckIns = 1;
                                        isCustomCheckIns = false;
                                        selectedCategory = 'Strength & Cardio';
                                        selectedDurationDays = 90;
                                        isCustomDuration = false;
                                        selectedAccentColor = const Color(0xFF06B6D4);
                                        isPopular = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 1. Plan Name
                          CustomTextField(
                            controller: nameCtrl,
                            label: 'Plan Name',
                            hint: 'e.g. Gold Annual Pass',
                            prefixIcon: Icons.card_membership_rounded,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter a plan name'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // 2. Plan Description / Tagline
                          CustomTextField(
                            controller: descriptionCtrl,
                            label: 'Plan Description',
                            hint: 'e.g. Full facility access with personal locker & steam bath',
                            prefixIcon: Icons.description_rounded,
                          ),
                          const SizedBox(height: 14),

                          // 3. Plan Type (Monthly, Quarterly, Yearly, etc.)
                          Text(
                            'Plan Type',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              {'type': 'Monthly', 'days': 30},
                              {'type': 'Quarterly', 'days': 90},
                              {'type': 'Half-Yearly', 'days': 180},
                              {'type': 'Yearly', 'days': 365},
                              {'type': 'Custom', 'days': -1},
                            ].map((item) {
                              final type = item['type'] as String;
                              final days = item['days'] as int;
                              final isSelected = selectedPlanType == type;
                              return ChoiceChip(
                                label: Text(
                                  type,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.black : Colors.white70,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: selectedAccentColor,
                                backgroundColor: const Color(0xFF19202E),
                                onSelected: (_) {
                                  setModalState(() {
                                    selectedPlanType = type;
                                    if (days != -1) {
                                      isCustomDuration = false;
                                      selectedDurationDays = days;
                                      customDaysCtrl.text = '$days';
                                    } else {
                                      isCustomDuration = true;
                                      final parsed = int.tryParse(customDaysCtrl.text.trim()) ?? 45;
                                      selectedDurationDays = parsed;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // 4. Duration Period
                          Text(
                            'Duration Period (Days)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              {'days': 30, 'label': '1 Month (30d)'},
                              {'days': 90, 'label': '3 Months (90d)'},
                              {'days': 180, 'label': '6 Months (180d)'},
                              {'days': 365, 'label': '1 Year (365d)'},
                              {'days': -1, 'label': 'Custom Days'},
                            ].map((dur) {
                              final d = dur['days'] as int;
                              final label = dur['label'] as String;
                              final isSelected = d == -1
                                  ? isCustomDuration
                                  : (!isCustomDuration && selectedDurationDays == d);
                              return ChoiceChip(
                                label: Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.black : Colors.white70,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: selectedAccentColor,
                                backgroundColor: const Color(0xFF19202E),
                                onSelected: (_) {
                                  setModalState(() {
                                    if (d != -1) {
                                      isCustomDuration = false;
                                      selectedDurationDays = d;
                                      customDaysCtrl.text = '$d';
                                      if (d == 30) selectedPlanType = 'Monthly';
                                      if (d == 90) selectedPlanType = 'Quarterly';
                                      if (d == 180) selectedPlanType = 'Half-Yearly';
                                      if (d == 365) selectedPlanType = 'Yearly';
                                    } else {
                                      isCustomDuration = true;
                                      selectedPlanType = 'Custom';
                                      final parsed = int.tryParse(customDaysCtrl.text.trim()) ?? 45;
                                      selectedDurationDays = parsed;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          if (isCustomDuration) ...[
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: customDaysCtrl,
                              label: 'Custom Duration (Days) *',
                              hint: 'e.g. 45 or 60',
                              prefixIcon: Icons.calendar_month_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                if (isCustomDuration) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter duration in days';
                                  }
                                  final parsed = int.tryParse(v.trim());
                                  if (parsed == null || parsed <= 0) {
                                    return 'Please enter a valid positive number';
                                  }
                                }
                                return null;
                              },
                              onChanged: (v) {
                                final parsed = int.tryParse(v.trim());
                                if (parsed != null && parsed > 0) {
                                  selectedDurationDays = parsed;
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 16),

                          // 5. Pricing Row (Package Price + Admission Fee)
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: priceCtrl,
                                  label: 'Package Price (₹)',
                                  hint: '18000',
                                  prefixIcon: Icons.currency_rupee_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Enter price';
                                    if (double.tryParse(v.trim()) == null) return 'Valid number';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomTextField(
                                  controller: admissionCtrl,
                                  label: 'Admission Fee (₹)',
                                  hint: '0',
                                  prefixIcon: Icons.receipt_long_rounded,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 6. Access Type Selector
                          Text(
                            'Access Type',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              '24/7 Full Access',
                              'Standard (Gym Hours)',
                              'Peak Hours Only',
                              'Off-Peak (Daytime)',
                              'Weekend Only',
                              'Classes & Floor',
                            ].map((acc) {
                              final isSelected = selectedAccessType == acc;
                              return ChoiceChip(
                                label: Text(
                                  acc,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.black : Colors.white70,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: selectedAccentColor,
                                backgroundColor: const Color(0xFF19202E),
                                onSelected: (_) {
                                  setModalState(() => selectedAccessType = acc);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // 7. Max Check-Ins Per Day
                          Text(
                            'Daily Check-In Limit',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              {'val': 0, 'label': 'Unlimited (No Limit)'},
                              {'val': 1, 'label': '1 / Day'},
                              {'val': 2, 'label': '2 / Day'},
                              {'val': 3, 'label': '3 / Day'},
                              {'val': -1, 'label': 'Custom'},
                            ].map((item) {
                              final val = item['val'] as int;
                              final label = item['label'] as String;
                              final isSelected = val == -1
                                  ? isCustomCheckIns
                                  : (!isCustomCheckIns && selectedMaxCheckIns == val);
                              return ChoiceChip(
                                label: Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.black : Colors.white70,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: selectedAccentColor,
                                backgroundColor: const Color(0xFF19202E),
                                onSelected: (_) {
                                  setModalState(() {
                                    if (val != -1) {
                                      isCustomCheckIns = false;
                                      selectedMaxCheckIns = val;
                                      customCheckInsCtrl.text = '$val';
                                    } else {
                                      isCustomCheckIns = true;
                                      final parsed =
                                          int.tryParse(customCheckInsCtrl.text.trim()) ?? 4;
                                      selectedMaxCheckIns = parsed;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          if (isCustomCheckIns) ...[
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: customCheckInsCtrl,
                              label: 'Custom Max Check-Ins Per Day *',
                              hint: 'e.g. 4',
                              prefixIcon: Icons.how_to_reg_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                if (isCustomCheckIns) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter check-in limit';
                                  }
                                  final parsed = int.tryParse(v.trim());
                                  if (parsed == null || parsed < 0) {
                                    return 'Please enter a valid number';
                                  }
                                }
                                return null;
                              },
                              onChanged: (v) {
                                final parsed = int.tryParse(v.trim());
                                if (parsed != null && parsed >= 0) {
                                  selectedMaxCheckIns = parsed;
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 16),

                          // 8. Package Category
                          Text(
                            'Package Category',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              'Strength & Cardio',
                              'HIIT & Group',
                              'VIP All-Access',
                              'Personal Training',
                              'Student / Standard',
                            ].map((cat) {
                              final isSelected = selectedCategory == cat;
                              return ChoiceChip(
                                label: Text(
                                  cat,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.black : Colors.white70,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: selectedAccentColor,
                                backgroundColor: const Color(0xFF19202E),
                                onSelected: (_) {
                                  setModalState(() => selectedCategory = cat);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // 9. Included Features & Perks
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Included Features & Perks (${features.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                              Text(
                                'Tap to toggle',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: selectedAccentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: quickPerkOptions.map((perk) {
                              final hasPerk = features.contains(perk);
                              return FilterChip(
                                label: Text(
                                  perk,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: hasPerk ? FontWeight.w700 : FontWeight.w500,
                                    color: hasPerk ? Colors.white : Colors.white60,
                                  ),
                                ),
                                selected: hasPerk,
                                selectedColor: selectedAccentColor.withValues(alpha: 0.35),
                                checkmarkColor: selectedAccentColor,
                                backgroundColor: const Color(0xFF19202E),
                                side: BorderSide(
                                  color: hasPerk
                                      ? selectedAccentColor.withValues(alpha: 0.6)
                                      : const Color(0xFF2B3648),
                                ),
                                onSelected: (sel) {
                                  setModalState(() {
                                    if (sel) {
                                      features.add(perk);
                                    } else {
                                      features.remove(perk);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          // Custom Perk Adder
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: customPerkCtrl,
                                  label: 'Add Custom Feature',
                                  hint: 'e.g. Free Protein Smoothie on Friday',
                                  prefixIcon: Icons.star_outline_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedAccentColor,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  final text = customPerkCtrl.text.trim();
                                  if (text.isNotEmpty && !features.contains(text)) {
                                    setModalState(() {
                                      features.add(text);
                                      customPerkCtrl.clear();
                                    });
                                  }
                                },
                                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 10. Accent Color Picker
                          Text(
                            'Plan Badge & Glow Accent Color',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: colorOptions.map((c) {
                              final isSelected = selectedAccentColor.toARGB32() == c.toARGB32();
                              return GestureDetector(
                                onTap: () => setModalState(() => selectedAccentColor = c),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: c.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.black, size: 20)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // 11. Toggles: isPopular, isActive
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF19202E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF283448)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.local_fire_department_rounded,
                                            color: Color(0xFFF59E0B), size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Mark as "Most Popular" Tier',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Switch.adaptive(
                                      value: isPopular,
                                      activeTrackColor: const Color(0xFFF59E0B),
                                      onChanged: (val) => setModalState(() => isPopular = val),
                                    ),
                                  ],
                                ),
                                const Divider(color: Color(0xFF283448), height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded,
                                            color: AppColors.success, size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Active for Member Enrollments',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Switch.adaptive(
                                      value: isActive,
                                      activeTrackColor: AppColors.success,
                                      onChanged: (val) => setModalState(() => isActive = val),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Action Button
                          CustomButton(
                            text: isEditing ? 'Update Membership Plan' : 'Save & Publish Plan',
                            icon: isEditing ? Icons.check_circle_rounded : Icons.add_circle_rounded,
                            customColor: selectedAccentColor,
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final parsedPrice = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                              final parsedAdmission = double.tryParse(admissionCtrl.text.trim()) ?? 0.0;
                              final finalDurationDays = isCustomDuration
                                  ? (int.tryParse(customDaysCtrl.text.trim()) ?? selectedDurationDays)
                                  : selectedDurationDays;
                              final finalMaxCheckIns = isCustomCheckIns
                                  ? (int.tryParse(customCheckInsCtrl.text.trim()) ?? selectedMaxCheckIns)
                                  : selectedMaxCheckIns;

                              final planToSave = GymMembershipPlanModel(
                                id: isEditing
                                    ? existingPlan.id
                                    : 'gplan_${DateTime.now().millisecondsSinceEpoch}',
                                tenantId: widget.authController.activeTenantId,
                                name: nameCtrl.text.trim(),
                                tagline: descriptionCtrl.text.trim(),
                                price: parsedPrice,
                                admissionFee: parsedAdmission,
                                durationDays: finalDurationDays > 0 ? finalDurationDays : 30,
                                billingCycle: isCustomDuration ? 'Custom' : selectedPlanType,
                                accessType: selectedAccessType,
                                maxCheckInsPerDay: finalMaxCheckIns >= 0 ? finalMaxCheckIns : 0,
                                category: selectedCategory,
                                features: features.isNotEmpty
                                    ? features
                                    : ['Gym Floor Access', 'Locker & Shower Facility'],
                                isPopular: isPopular,
                                isActive: isActive,
                                enrolledMembersCount: existingPlan?.enrolledMembersCount ?? 0,
                                accentColor: selectedAccentColor,
                              );

                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              Navigator.pop(ctx);

                              if (isEditing) {
                                await widget.authController.updateGymMembershipPlan(planToSave);
                                setState(() {
                                  final idx = _membershipPlans.indexWhere((p) => p.id == planToSave.id);
                                  if (idx != -1) {
                                    _membershipPlans[idx] = planToSave;
                                  }
                                });
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Updated plan "${planToSave.name}" successfully!',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                await widget.authController.addGymMembershipPlan(planToSave);
                                setState(() {
                                  _membershipPlans.insert(0, planToSave);
                                });
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Created membership plan "${planToSave.name}"!',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────── TAB 3: BATCHES & SCHEDULES ────────
  Widget _buildBatchesTab(Color primaryColor) {
    final query = _batchSearchQuery.trim().toLowerCase();
    final filteredBatches = _batches.where((batch) {
      if (_selectedBatchFilter == 'Active' && !batch.isActive) return false;
      if (_selectedBatchFilter == 'Full' && !batch.isFull) return false;
      if (_selectedBatchFilter == 'Available' && batch.isFull) return false;

      if (query.isEmpty) return true;
      final nameMatch = batch.name.toLowerCase().contains(query);
      final timeMatch = batch.time.toLowerCase().contains(query);
      final memberMatch = batch.memberNames.any((m) => m.toLowerCase().contains(query));
      return nameMatch || timeMatch || memberMatch;
    }).toList();

    final activeBatches = _batches.where((b) => b.isActive).length;
    final totalCapacity = _batches.where((b) => b.isActive).fold(0, (sum, b) => sum + b.limit);
    final totalEnrolledInBatches = _batches.fold(0, (sum, b) => sum + b.enrolledCount);

    return RefreshIndicator(
      onRefresh: () => _refreshOverviewData(forceRefresh: true),
      color: primaryColor,
      backgroundColor: const Color(0xFF131A26),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / KPI Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Batches',
                    value: '${_batches.length}',
                    sub: '$activeBatches Active',
                    icon: Icons.schedule_rounded,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Capacity',
                    value: '$totalCapacity',
                    sub: '$totalEnrolledInBatches Enrolled',
                    icon: Icons.groups_rounded,
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar & Filter Chips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131A26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF233045)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _batchSearchQuery = v),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Search batch name, time, or members...',
                            hintStyle: GoogleFonts.inter(color: AppColors.textSecondaryDark, fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            filled: true,
                            fillColor: const Color(0xFF182232),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditBatchDialog(primaryColor: primaryColor),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Add Batch',
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Active', 'Available', 'Full'].map((filter) {
                        final isSelected = _selectedBatchFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedBatchFilter = filter),
                            selectedColor: primaryColor.withValues(alpha: 0.25),
                            backgroundColor: const Color(0xFF182232),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? primaryColor : Colors.white70,
                            ),
                            side: BorderSide(
                              color: isSelected ? primaryColor : Colors.white12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Batch List View or Empty State
            if (filteredBatches.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A26),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF233045)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      _batches.isEmpty ? 'No Facility Batches Created Yet' : 'No Batches Found',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _batches.isEmpty
                          ? 'Create your first workout batch with batch name, scheduled time, member limit, and assigned members.'
                          : 'Try adjusting your search or filter options.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondaryDark),
                    ),
                    if (_batches.isEmpty) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditBatchDialog(primaryColor: primaryColor),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Create First Batch', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredBatches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final batch = filteredBatches[index];
                  return _buildBatchCard(batch, primaryColor);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(GymBatchModel batch, Color primaryColor) {
    final occupancy = batch.occupancyRatio;
    final isFull = batch.isFull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: batch.isActive ? const Color(0xFF233045) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Badges + Popup Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.alarm_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            batch.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: batch.isActive
                                ? AppColors.success.withValues(alpha: 0.15)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: batch.isActive
                                  ? AppColors.success.withValues(alpha: 0.4)
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            batch.isActive ? 'Active' : 'Paused',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: batch.isActive ? AppColors.success : Colors.white60,
                            ),
                          ),
                        ),
                        if (isFull) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'FULL',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 14, color: AppColors.accentCyan),
                        const SizedBox(width: 4),
                        Text(
                          batch.time,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                color: const Color(0xFF19202E),
                onSelected: (val) {
                  if (val == 'edit') {
                    _showAddEditBatchDialog(primaryColor: primaryColor, batchToEdit: batch);
                  } else if (val == 'toggle') {
                    _handleToggleBatchStatus(batch);
                  } else if (val == 'delete') {
                    _showDeleteBatchDialog(batch);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 8),
                        Text('Edit Batch', style: GoogleFonts.inter(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          batch.isActive ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                          size: 18,
                          color: batch.isActive ? Colors.orangeAccent : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          batch.isActive ? 'Pause Batch' : 'Activate Batch',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('Delete Batch', style: GoogleFonts.inter(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Capacity / Limit Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Capacity Limit',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondaryDark, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${batch.enrolledCount} / ${batch.limit} Members (${(occupancy * 100).toInt()}%)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isFull ? AppColors.error : primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: occupancy,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF192232),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFull ? AppColors.error : (occupancy > 0.8 ? Colors.orangeAccent : primaryColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Assigned Members Section
          Text(
            'Enrolled Members (${batch.memberIds.length}):',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          if (batch.memberIds.isEmpty)
            Text(
              'No members assigned to this batch yet.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondaryDark, fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: batch.memberIds.map((mId) {
                final memberMatch = _members.where((m) => m.id == mId);
                final displayName = memberMatch.isNotEmpty ? memberMatch.first.fullName : mId;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2436),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2B3A52)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: primaryColor.withValues(alpha: 0.3),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: primaryColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        displayName,
                        style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),

          // Card Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showAddEditBatchDialog(primaryColor: primaryColor, batchToEdit: batch),
                icon: const Icon(Icons.edit_rounded, size: 15),
                label: Text('Edit Batch', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showDeleteBatchDialog(batch),
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: Text('Delete', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleBatchStatus(GymBatchModel batch) async {
    final newStatus = !batch.isActive;
    final success = await widget.authController.toggleGymBatchStatus(batch.id, newStatus);
    if (success && mounted) {
      setState(() {
        _batches = List.from(widget.authController.batches);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${batch.name} is now ${newStatus ? "Active" : "Paused"}'),
          backgroundColor: newStatus ? AppColors.success : Colors.orangeAccent,
        ),
      );
    }
  }

  void _showDeleteBatchDialog(GymBatchModel batch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF19202E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Batch',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${batch.name}"? Enrolled members will not be deleted from your member directory.',
          style: GoogleFonts.inter(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await widget.authController.deleteGymBatch(batch.id);
              if (success && mounted) {
                setState(() {
                  _batches = List.from(widget.authController.batches);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Batch "${batch.name}" deleted successfully.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddEditBatchDialog({
    required Color primaryColor,
    GymBatchModel? batchToEdit,
  }) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: batchToEdit?.name ?? '');
    final timeCtrl = TextEditingController(text: batchToEdit?.time ?? '06:00 AM - 07:30 AM');
    final limitCtrl = TextEditingController(text: batchToEdit?.limit.toString() ?? '20');
    final memberSearchCtrl = TextEditingController();

    final isEditing = batchToEdit != null;
    final Set<String> selectedMemberIds = Set.from(batchToEdit?.memberIds ?? []);
    bool isSaving = false;

    const presetTimes = [
      '06:00 AM - 07:30 AM',
      '07:30 AM - 09:00 AM',
      '09:00 AM - 10:30 AM',
      '04:00 PM - 05:30 PM',
      '05:30 PM - 07:00 PM',
      '07:00 PM - 08:30 PM',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final memberQuery = memberSearchCtrl.text.trim().toLowerCase();
          final filteredMemberList = _members.where((m) {
            if (memberQuery.isEmpty) return true;
            return m.fullName.toLowerCase().contains(memberQuery) ||
                m.phone.contains(memberQuery) ||
                m.email.toLowerCase().contains(memberQuery);
          }).toList();

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.90,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 14,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isEditing ? Icons.edit_calendar_rounded : Icons.add_alarm_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isEditing ? 'Edit Batch Details' : 'Create New Facility Batch',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Batch Name Field
                            CustomTextField(
                              controller: nameCtrl,
                              label: '1. Batch Name *',
                              hint: 'e.g. Morning Fitness Elite',
                              prefixIcon: Icons.fitness_center_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Please enter batch name'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // 2. Batch Time Field & Quick Presets
                            CustomTextField(
                              controller: timeCtrl,
                              label: '2. Batch Time *',
                              hint: 'e.g. 06:00 AM - 07:30 AM',
                              prefixIcon: Icons.access_time_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Please enter batch time'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Quick Time Presets:',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: presetTimes.map((preset) {
                                final isSelected = timeCtrl.text == preset;
                                return InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      timeCtrl.text = preset;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryColor.withValues(alpha: 0.2)
                                          : const Color(0xFF182232),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? primaryColor : const Color(0xFF283448),
                                      ),
                                    ),
                                    child: Text(
                                      preset,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? primaryColor : Colors.white70,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // 3. Batch Limit Field
                            CustomTextField(
                              controller: limitCtrl,
                              label: '3. Batch Limit / Max Capacity *',
                              hint: 'e.g. 20',
                              prefixIcon: Icons.group_work_rounded,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Please enter batch limit';
                                final val = int.tryParse(v.trim());
                                if (val == null || val <= 0) return 'Enter a valid positive number';
                                if (selectedMemberIds.length > val) {
                                  return 'Capacity limit ($val) cannot be less than selected members (${selectedMemberIds.length})';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 4. Add Members to Batch Section
                            Builder(
                              builder: (context) {
                                final currentLimit = int.tryParse(limitCtrl.text.trim()) ?? 20;
                                final isOverLimit = selectedMemberIds.length > currentLimit;

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131A26),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isOverLimit ? AppColors.error : const Color(0xFF233045),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.person_add_alt_1_rounded, color: primaryColor, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                '4. Add Members to Batch',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isOverLimit
                                                  ? AppColors.error.withValues(alpha: 0.2)
                                                  : primaryColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isOverLimit
                                                    ? AppColors.error
                                                    : primaryColor.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Text(
                                              '${selectedMemberIds.length} / $currentLimit Selected',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isOverLimit ? AppColors.error : primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isOverLimit || selectedMemberIds.length >= currentLimit) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Already batch capacity limit ($currentLimit members) has been crossed/reached! Increase limit to add more.',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      // Member Search Box inside modal
                                      TextField(
                                        controller: memberSearchCtrl,
                                        onChanged: (_) => setModalState(() {}),
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5),
                                        decoration: InputDecoration(
                                          hintText: 'Search members to add...',
                                          hintStyle: GoogleFonts.inter(color: AppColors.textSecondaryDark, fontSize: 12),
                                          prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                          filled: true,
                                          fillColor: const Color(0xFF182232),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      if (filteredMemberList.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Center(
                                            child: Text(
                                              _members.isEmpty
                                                  ? 'No gym members enrolled yet. Enroll members first.'
                                                  : 'No matching members found.',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors.textSecondaryDark,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxHeight: 200),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: filteredMemberList.length,
                                            itemBuilder: (ctx, idx) {
                                              final m = filteredMemberList[idx];
                                              final isSelected = selectedMemberIds.contains(m.id);

                                              return Material(
                                                color: Colors.transparent,
                                                child: CheckboxListTile(
                                                  value: isSelected,
                                                  activeColor: primaryColor,
                                                  checkColor: Colors.black,
                                                  dense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                                  title: Text(
                                                    m.fullName,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    '${m.planName} • ${m.phone}',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: AppColors.textSecondaryDark,
                                                    ),
                                                  ),
                                                  onChanged: (val) {
                                                    setModalState(() {
                                                      if (val == true) {
                                                        if (selectedMemberIds.length >= currentLimit) {
                                                          showDialog(
                                                            context: ctx,
                                                            builder: (dialogCtx) => AlertDialog(
                                                              backgroundColor: const Color(0xFF192231),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                              title: Row(
                                                                children: [
                                                                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
                                                                  const SizedBox(width: 10),
                                                                  Text(
                                                                    'Batch Limit Reached!',
                                                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                                                  ),
                                                                ],
                                                              ),
                                                              content: Text(
                                                                'Already batch capacity limit has been crossed ($currentLimit max members).\n\nYou cannot add "${m.fullName}". Please increase the Batch Limit capacity first.',
                                                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(dialogCtx),
                                                                  child: Text('OK, I Understand', style: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.bold)),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          return;
                                                        }
                                                        selectedMemberIds.add(m.id);
                                                      } else {
                                                        selectedMemberIds.remove(m.id);
                                                      }
                                                    });
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: isEditing ? 'Update Batch' : 'Create Batch',
                      isLoading: isSaving,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final limit = int.tryParse(limitCtrl.text.trim()) ?? 0;
                        if (selectedMemberIds.length > limit) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cannot create batch: Selected member count (${selectedMemberIds.length}) exceeds the capacity limit ($limit).'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        setModalState(() => isSaving = true);

                        final name = nameCtrl.text.trim();
                        final time = timeCtrl.text.trim();
                        final memberIdList = selectedMemberIds.toList();
                        final memberNameList = memberIdList.map((id) {
                          final match = _members.where((m) => m.id == id);
                          return match.isNotEmpty ? match.first.fullName : id;
                        }).toList();

                        final batchModel = GymBatchModel(
                          id: batchToEdit?.id ?? '',
                          name: name,
                          time: time,
                          limit: limit,
                          memberIds: memberIdList,
                          memberNames: memberNameList,
                          isActive: batchToEdit?.isActive ?? true,
                        );

                        final bool success;
                        if (isEditing) {
                          success = await widget.authController.updateGymBatch(batchModel);
                        } else {
                          success = await widget.authController.addGymBatch(batchModel);
                        }

                        if (success) {
                          final savedBatchId = batchModel.id.isNotEmpty
                              ? batchModel.id
                              : widget.authController.batches.where((b) => b.name == name && b.time == time).firstOrNull?.id;
                          final savedBatchName = '$name ($time)';

                          if (savedBatchId != null && savedBatchId.isNotEmpty) {
                            for (final member in _members) {
                              if (selectedMemberIds.contains(member.id)) {
                                if (member.batchId != savedBatchId) {
                                  final updatedMem = member.copyWith(batchId: savedBatchId, batchName: savedBatchName);
                                  await widget.authController.updateGymMember(updatedMem);
                                }
                              } else if (member.batchId == savedBatchId) {
                                final updatedMem = member.copyWith(batchId: null, batchName: null);
                                await widget.authController.updateGymMember(updatedMem);
                              }
                            }
                          }
                        }

                        if (mounted) {
                          setState(() {
                            _batches = List.from(widget.authController.batches);
                            _members = List.from(widget.authController.members);
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? (isEditing
                                        ? 'Batch "$name" updated successfully.'
                                        : 'New Batch "$name" created successfully.')
                                    : 'Failed to save batch.',
                              ),
                              backgroundColor: success ? AppColors.success : AppColors.error,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlansTab(Color primaryColor) {
    final query = _planSearchQuery.trim().toLowerCase();
    final filteredPlans = _membershipPlans.where((plan) {
      // Filter by category, plan type, or status
      if (_selectedPlanFilter == 'Active' && !plan.isActive) return false;
      if (_selectedPlanFilter == 'Paused' && plan.isActive) return false;
      if (_selectedPlanFilter == 'Yearly' && (plan.durationDays != 365 && plan.planType != 'Yearly')) return false;
      if (_selectedPlanFilter == 'Monthly' && (plan.durationDays != 30 && plan.planType != 'Monthly')) return false;
      if (_selectedPlanFilter == 'Quarterly' && (plan.durationDays != 90 && plan.planType != 'Quarterly')) return false;
      if (_selectedPlanFilter == '24/7 Access' && !plan.accessType.contains('24/7')) return false;
      if (_selectedPlanFilter == 'Strength & Cardio' && plan.category != 'Strength & Cardio') return false;
      if (_selectedPlanFilter == 'HIIT & Group' && plan.category != 'HIIT & Group') return false;
      if (_selectedPlanFilter == 'VIP All-Access' && plan.category != 'VIP All-Access') return false;

      if (query.isEmpty) return true;
      return plan.name.toLowerCase().contains(query) ||
          plan.description.toLowerCase().contains(query) ||
          plan.planType.toLowerCase().contains(query) ||
          plan.accessType.toLowerCase().contains(query) ||
          plan.category.toLowerCase().contains(query) ||
          plan.features.any((f) => f.toLowerCase().contains(query));
    }).toList();

    // Compute enrolled member count per plan dynamically from _members list
    final enrolledCountByPlan = <String, int>{};
    for (final m in _members) {
      if (m.isActive) {
        final pName = m.membershipPlan.trim().toLowerCase();
        final pId = m.membershipPlanId?.trim().toLowerCase();
        for (final plan in _membershipPlans) {
          final planName = plan.name.trim().toLowerCase();
          final planId = plan.id.toLowerCase();
          if ((pId != null && pId.isNotEmpty && planId == pId) ||
              (planName == pName) ||
              (pName.isNotEmpty && pName.contains(planName)) ||
              (planName.isNotEmpty && planName.contains(pName))) {
            enrolledCountByPlan[plan.id] = (enrolledCountByPlan[plan.id] ?? 0) + 1;
            break;
          }
        }
      }
    }

    final activePlansCount = _membershipPlans.where((p) => p.isActive).length;
    final totalEnrolledFromMembers = _members.where((m) => m.isActive).length;
    final totalEnrolledFromPlans = _membershipPlans.fold<int>(0, (acc, p) => acc + p.enrolledMembersCount);
    final totalEnrolled = totalEnrolledFromMembers > 0 ? totalEnrolledFromMembers : totalEnrolledFromPlans;

    final popularPlan = _membershipPlans.where((p) => p.isPopular).firstOrNull ??
        (_membershipPlans.isNotEmpty ? _membershipPlans.first : null);
    final popularEnrolledCount = popularPlan != null
        ? (enrolledCountByPlan[popularPlan.id] ?? popularPlan.enrolledMembersCount)
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Metric KPI Cards (2 Rows for clean, spacious mobile design)
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Active Plans',
                  value: '$activePlansCount / ${_membershipPlans.length}',
                  sub: 'Tiers available',
                  icon: Icons.card_membership_rounded,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Enrolled Members',
                  value: '$totalEnrolled',
                  sub: 'Subscribed users',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.accentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildKpiCard(
            title: 'Top Tier Package',
            value: popularPlan != null ? popularPlan.name.split(' ').first : 'None',
            sub: popularPlan != null ? '$popularEnrolledCount enrolled' : 'No popular tier set',
            icon: Icons.workspace_premium_rounded,
            color: AppColors.accentAmber,
          ),
          const SizedBox(height: 18),

          // Search & Filter Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEMBERSHIP PACKAGES',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondaryDark,
                  letterSpacing: 0.8,
                ),
              ),
              InkWell(
                onTap: () => _showAddOrEditPlanDialog(primaryColor: primaryColor),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'New Plan',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Input
          CustomTextField(
            label: 'Search Plans',
            hint: 'Search by name, description, plan type, access...',
            prefixIcon: Icons.search_rounded,
            onChanged: (val) {
              setState(() {
                _planSearchQuery = val;
              });
            },
          ),
          const SizedBox(height: 12),

          // Category & Type Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPlanFilterChip('All', _membershipPlans.length, primaryColor),
                const SizedBox(width: 8),
                _buildPlanFilterChip('Active', activePlansCount, AppColors.success),
                const SizedBox(width: 8),
                _buildPlanFilterChip(
                  'Yearly',
                  _membershipPlans.where((p) => p.durationDays == 365 || p.planType == 'Yearly').length,
                  AppColors.accentAmber,
                ),
                const SizedBox(width: 8),
                _buildPlanFilterChip(
                  'Monthly',
                  _membershipPlans.where((p) => p.durationDays == 30 || p.planType == 'Monthly').length,
                  const Color(0xFF00E599),
                ),
                const SizedBox(width: 8),
                _buildPlanFilterChip(
                  'Quarterly',
                  _membershipPlans.where((p) => p.durationDays == 90 || p.planType == 'Quarterly').length,
                  AppColors.accentCyan,
                ),
                const SizedBox(width: 8),
                _buildPlanFilterChip(
                  '24/7 Access',
                  _membershipPlans.where((p) => p.accessType.contains('24/7')).length,
                  const Color(0xFFA855F7),
                ),
                const SizedBox(width: 8),
                _buildPlanFilterChip(
                  'Strength & Cardio',
                  _membershipPlans.where((p) => p.category == 'Strength & Cardio').length,
                  primaryColor,
                ),
                const SizedBox(width: 8),
                _buildPlanFilterChip(
                  'HIIT & Group',
                  _membershipPlans.where((p) => p.category == 'HIIT & Group').length,
                  AppColors.accentCyan,
                ),
                const SizedBox(width: 8),
                _buildPlanFilterChip(
                  'VIP All-Access',
                  _membershipPlans.where((p) => p.category == 'VIP All-Access').length,
                  const Color(0xFFA855F7),
                ),
                const SizedBox(width: 8),
                _buildPlanFilterChip(
                  'Paused',
                  _membershipPlans.where((p) => !p.isActive).length,
                  AppColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Plans List
          if (filteredPlans.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF141A26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222D3E)),
              ),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: primaryColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'No Membership Plans Found',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create custom packages with duration, access type, and perks for your gym.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Create First Plan',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _showAddOrEditPlanDialog(primaryColor: primaryColor),
                  ),
                ],
              ),
            )
          else
            ...filteredPlans.map((plan) {
              final count = enrolledCountByPlan[plan.id] ?? plan.enrolledMembersCount;
              return _buildPlanCard(plan, primaryColor, count);
            }),
        ],
      ),
    );
  }

  Widget _buildPlanFilterChip(String label, int count, Color color) {
    final isSelected = _selectedPlanFilter == label;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black26 : Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.black : Colors.white70,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: const Color(0xFF19202E),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.black : Colors.white70,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? color : const Color(0xFF283448),
        ),
      ),
      onSelected: (_) {
        setState(() {
          _selectedPlanFilter = label;
        });
      },
    );
  }

  Widget _buildPlanCard(GymMembershipPlanModel plan, Color primaryColor, int enrolledCount) {
    final accent = plan.accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151E2E),
            Color(0xFF0F1522),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: plan.isPopular
              ? accent.withValues(alpha: 0.7)
              : const Color(0xFF223047),
          width: plan.isPopular ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: plan.isPopular
                ? accent.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Bar with Badges
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF1E2B3E)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Plan Type Badge (Monthly, Quarterly, Yearly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_repeat_rounded, size: 10.5, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 3.5),
                            Text(
                              plan.planType.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: accent.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          plan.category.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      // Access Type Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 10, color: AppColors.accentCyan),
                            const SizedBox(width: 3),
                            Text(
                              plan.accessType,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (plan.isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, size: 10.5, color: Colors.black),
                              const SizedBox(width: 3),
                              Text(
                                'MOST POPULAR',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Card Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                  color: const Color(0xFF19202E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: accent, size: 16),
                          const SizedBox(width: 10),
                          Text('Edit Plan', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.content_copy_rounded, color: AppColors.accentCyan, size: 16),
                          SizedBox(width: 10),
                          Text('Duplicate', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            plan.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                            color: plan.isActive ? AppColors.accentAmber : AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            plan.isActive ? 'Pause Plan' : 'Activate Plan',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                          SizedBox(width: 10),
                          Text('Delete Plan', style: TextStyle(color: AppColors.error, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (action) async {
                    if (action == 'edit') {
                      _showAddOrEditPlanDialog(
                        primaryColor: primaryColor,
                        existingPlan: plan,
                      );
                    } else if (action == 'duplicate') {
                      final dup = plan.copyWith(
                        id: 'gplan_${DateTime.now().millisecondsSinceEpoch}',
                        name: '${plan.name} (Copy)',
                        enrolledMembersCount: 0,
                      );
                      await widget.authController.addGymMembershipPlan(dup);
                      setState(() {
                        _membershipPlans.insert(0, dup);
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Duplicated plan "${plan.name}"'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else if (action == 'toggle') {
                      await widget.authController.toggleGymMembershipPlanStatus(
                        widget.authController.activeTenantId,
                        plan.id,
                        !plan.isActive,
                      );
                      setState(() {
                        final idx = _membershipPlans.indexWhere((p) => p.id == plan.id);
                        if (idx != -1) {
                          _membershipPlans[idx] = plan.copyWith(isActive: !plan.isActive);
                        }
                      });
                    } else if (action == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: const Color(0xFF19202E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('Delete Membership Plan',
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                          content: Text('Are you sure you want to delete "${plan.name}"?',
                              style: GoogleFonts.inter(color: AppColors.textSecondaryDark)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await widget.authController.deleteGymMembershipPlan(
                          widget.authController.activeTenantId,
                          plan.id,
                        );
                        setState(() {
                          _membershipPlans.removeWhere((p) => p.id == plan.id);
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deleted "${plan.name}"'),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          // Plan Body: Name, Description, Price, Check-ins, Perks
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (plan.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              plan.description,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          plan.formattedPrice,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          plan.durationLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        if (plan.monthlyEquivalentLabel != null)
                          Text(
                            plan.monthlyEquivalentLabel!,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF38BDF8),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Access Type & Check-In Limit Strip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.how_to_reg_rounded, size: 12, color: AppColors.accentAmber),
                          const SizedBox(width: 5),
                          Text(
                            plan.maxCheckInsLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF1F5F9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (plan.admissionFee > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+ ₹${plan.admissionFee.toInt()} Admission',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Features Checklist
                Text(
                  'Included Perks:',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMutedDark,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                ...plan.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0xFF223047), height: 1),
                const SizedBox(height: 10),

                // Bottom strip: Enrolled stats + active switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.groups_rounded, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          '$enrolledCount Active Members',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          plan.isActive ? 'Active' : 'Paused',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: plan.isActive ? AppColors.success : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 24,
                          child: Switch.adaptive(
                            value: plan.isActive,
                            activeTrackColor: AppColors.success,
                            onChanged: (val) async {
                              await widget.authController.toggleGymMembershipPlanStatus(
                                widget.authController.activeTenantId,
                                plan.id,
                                val,
                              );
                              setState(() {
                                final idx = _membershipPlans.indexWhere((p) => p.id == plan.id);
                                if (idx != -1) {
                                  _membershipPlans[idx] = plan.copyWith(isActive: val);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────── TAB 4: EXPENSES & OUTFLOW MANAGEMENT ────────
  Widget _buildExpensesTab(Color primaryColor) {
    final query = _expenseSearchQuery.trim().toLowerCase();
    final now = DateTime.now();

    final filteredExpenses = _expenses.where((exp) {
      // 1. Category Filter
      if (_selectedExpenseCategoryFilter != 'All' && exp.category != _selectedExpenseCategoryFilter) {
        return false;
      }

      // 2. Timeframe Filter
      if (_selectedExpenseTimeframeFilter == 'This Month') {
        if (exp.date.month != now.month || exp.date.year != now.year) return false;
      } else if (_selectedExpenseTimeframeFilter == 'This Week') {
        if (exp.date.isBefore(now.subtract(const Duration(days: 7)))) return false;
      } else if (_selectedExpenseTimeframeFilter == 'This Year') {
        if (exp.date.year != now.year) return false;
      }

      // 3. Search Query
      if (query.isEmpty) return true;
      return exp.title.toLowerCase().contains(query) ||
          exp.category.toLowerCase().contains(query) ||
          exp.paymentMethod.toLowerCase().contains(query) ||
          (exp.notes != null && exp.notes!.toLowerCase().contains(query)) ||
          exp.amount.toString().contains(query);
    }).toList();

    // KPI Metrics calculation
    final totalOutflow = filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final thisMonthOutflow = _expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
    final thisYearOutflow = _expenses
        .where((e) => e.date.year == now.year)
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    // Calculate Top Category
    final Map<String, double> categorySums = {};
    for (final exp in _expenses) {
      categorySums[exp.category] = (categorySums[exp.category] ?? 0.0) + exp.amount;
    }
    String topCategoryName = 'None';
    double topCategoryAmount = 0.0;
    categorySums.forEach((cat, amt) {
      if (amt > topCategoryAmount) {
        topCategoryAmount = amt;
        topCategoryName = cat;
      }
    });

    final formattedTotal = totalOutflow >= 100000
        ? '₹${(totalOutflow / 100000).toStringAsFixed(2)}L'
        : '₹${totalOutflow.toStringAsFixed(totalOutflow % 1 == 0 ? 0 : 2)}';

    final formattedMonth = thisMonthOutflow >= 100000
        ? '₹${(thisMonthOutflow / 100000).toStringAsFixed(2)}L'
        : '₹${thisMonthOutflow.toStringAsFixed(thisMonthOutflow % 1 == 0 ? 0 : 2)}';

    final formattedYear = thisYearOutflow >= 100000
        ? '₹${(thisYearOutflow / 100000).toStringAsFixed(2)}L'
        : '₹${thisYearOutflow.toStringAsFixed(thisYearOutflow % 1 == 0 ? 0 : 2)}';

    final isYearFilter = _selectedExpenseTimeframeFilter == 'This Year';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4 Metric KPI Cards Row
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Total Outflow',
                  value: formattedTotal,
                  sub: '${filteredExpenses.length} transactions',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.accentViolet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: isYearFilter ? 'This Year' : 'This Month',
                  value: isYearFilter ? formattedYear : formattedMonth,
                  sub: isYearFilter ? 'Annual ledger' : 'Monthly ledger',
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.accentOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Top Category',
                  value: topCategoryName.split(' ').first,
                  sub: topCategoryAmount > 0 ? '₹${topCategoryAmount.toInt()}' : 'No spend',
                  icon: Icons.pie_chart_rounded,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Entries Logged',
                  value: '${_expenses.length}',
                  sub: 'Active records',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.accentEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Search Bar & Filter Controls Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OPERATIONAL EXPENSES',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondaryDark,
                  letterSpacing: 0.8,
                ),
              ),
              InkWell(
                onTap: () => _showAddOrEditExpenseDialog(primaryColor: primaryColor),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 14, color: AppColors.accentViolet),
                      const SizedBox(width: 4),
                      Text(
                        'Add Expense',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentViolet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field
          CustomTextField(
            label: 'Search Expenses',
            hint: 'Search by title, note, category or amount...',
            prefixIcon: Icons.search_rounded,
            onChanged: (val) => setState(() => _expenseSearchQuery = val),
          ),
          const SizedBox(height: 10),

          // Timeframe Filter Toggle Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['This Month', 'This Week', 'This Year', 'All Time'].map((tf) {
                final isSel = _selectedExpenseTimeframeFilter == tf;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tf),
                    selected: isSel,
                    selectedColor: AppColors.accentViolet,
                    backgroundColor: const Color(0xFF19202E),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : Colors.white70,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSel ? AppColors.accentViolet : const Color(0xFF283448),
                      ),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedExpenseTimeframeFilter = tf;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildExpenseCategoryFilterChip('All', _expenses.length, primaryColor),
                const SizedBox(width: 8),
                ...GymExpenseCategory.values.map((cat) {
                  final count = _expenses.where((e) => e.category == cat.label).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildExpenseCategoryFilterChip(cat.label, count, cat.color),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Expense List
          if (filteredExpenses.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF141A26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222D3E)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentViolet.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 44,
                      color: AppColors.accentViolet,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Expenses Logged Yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track facility rent, equipment maintenance, electricity bills, and trainer stipends seamlessly.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentViolet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Record First Expense',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _showAddOrEditExpenseDialog(primaryColor: primaryColor),
                  ),
                ],
              ),
            )
          else
            ...filteredExpenses.map((exp) => _buildExpenseCard(exp, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildExpenseCategoryFilterChip(String label, int count, Color color) {
    final isSelected = _selectedExpenseCategoryFilter == label;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black26 : Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: const Color(0xFF19202E),
      labelStyle: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : Colors.white70,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? color : const Color(0xFF283448),
        ),
      ),
      onSelected: (_) {
        setState(() {
          _selectedExpenseCategoryFilter = label;
        });
      },
    );
  }

  Widget _buildExpenseCard(GymExpenseRecord exp, Color primaryColor) {
    final catColor = exp.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151E2E),
            Color(0xFF0F1522),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223047), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Category Icon Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  catColor.withValues(alpha: 0.25),
                  catColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: catColor.withValues(alpha: 0.5)),
            ),
            child: Icon(exp.icon, color: catColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Center Expense Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exp.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        exp.category,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2B3E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        exp.paymentMethod,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 4),
                    Text(
                      '${exp.formattedDate} • ${exp.formattedTime}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
                if (exp.notes != null && exp.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exp.notes!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMutedDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right Price & Action Menu
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                exp.formattedAmount,
                style: GoogleFonts.poppins(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF87171), // Vibrant Outflow Red
                ),
              ),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white70),
                color: const Color(0xFF19202E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) async {
                  if (val == 'edit') {
                    _showAddOrEditExpenseDialog(expense: exp, primaryColor: primaryColor);
                  } else if (val == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF19202E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(
                          'Delete Expense Entry',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        content: Text(
                          'Are you sure you want to delete "${exp.title}" (${exp.formattedAmount})?',
                          style: GoogleFonts.inter(color: AppColors.textSecondaryDark),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await widget.authController.deleteGymExpense(
                        widget.authController.activeTenantId,
                        exp.id,
                      );
                      setState(() {
                        _expenses.removeWhere((e) => e.id == exp.id);
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Deleted expense "${exp.title}"',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 16, color: Colors.white70),
                        SizedBox(width: 10),
                        Text('Edit', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddOrEditExpenseDialog({
    GymExpenseRecord? expense,
    required Color primaryColor,
  }) {
    final isEditing = expense != null;
    final titleCtrl = TextEditingController(text: expense?.title ?? '');
    final amountCtrl = TextEditingController(
      text: expense != null ? (expense.amount % 1 == 0 ? expense.amount.toInt().toString() : expense.amount.toString()) : '',
    );
    final notesCtrl = TextEditingController(text: expense?.notes ?? '');

    String selectedCategory = expense?.category ?? GymExpenseCategory.equipmentUpkeep.label;
    String selectedPaymentMethod = expense?.paymentMethod ?? 'UPI / Online';
    DateTime selectedDate = expense?.date ?? DateTime.now();

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF151E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF243248), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentViolet.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.receipt_long_rounded,
                  color: AppColors.accentViolet,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing ? 'Edit Expense Entry' : 'Record Operating Expense',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Input
                  CustomTextField(
                    controller: titleCtrl,
                    label: 'Expense Title / Description *',
                    hint: 'e.g. Treadmill Motor Servicing',
                    prefixIcon: Icons.edit_note_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 12),

                  // Amount Input
                  CustomTextField(
                    controller: amountCtrl,
                    label: 'Amount (₹) *',
                    hint: 'e.g. 4500',
                    prefixIcon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter amount';
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Category Dropdown
                  Text(
                    'Expense Category *',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101724),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF223047)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        dropdownColor: const Color(0xFF151E2E),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        isExpanded: true,
                        items: GymExpenseCategory.values.map((cat) {
                          return DropdownMenuItem(
                            value: cat.label,
                            child: Row(
                              children: [
                                Icon(cat.icon, size: 16, color: cat.color),
                                const SizedBox(width: 8),
                                Text(
                                  cat.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedCategory = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Method Dropdown
                  Text(
                    'Payment Mode',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101724),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF223047)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPaymentMethod,
                        dropdownColor: const Color(0xFF151E2E),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        isExpanded: true,
                        items: ['UPI / Online', 'Cash', 'Bank Transfer', 'Credit Card', 'Cheque'].map((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(
                              mode,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedPaymentMethod = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date Picker Field
                  Text(
                    'Expense Date',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.accentViolet,
                              onPrimary: Colors.white,
                              surface: Color(0xFF151E2E),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101724),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF223047)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(selectedDate),
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.accentViolet),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Optional Notes
                  CustomTextField(
                    controller: notesCtrl,
                    label: 'Notes / Invoice Ref (Optional)',
                    hint: 'e.g. Paid to Apex Gym Equipment Techs',
                    prefixIcon: Icons.notes_rounded,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentViolet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final amt = double.parse(amountCtrl.text.trim());
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);

                if (isEditing) {
                  final updated = expense.copyWith(
                    title: titleCtrl.text.trim(),
                    amount: amt,
                    category: selectedCategory,
                    paymentMethod: selectedPaymentMethod,
                    date: selectedDate,
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                  );
                  await widget.authController.updateGymExpense(updated);
                  if (mounted) {
                    setState(() {
                      final idx = _expenses.indexWhere((e) => e.id == expense.id);
                      if (idx != -1) {
                        _expenses[idx] = updated;
                      }
                    });
                  }
                } else {
                  final newExp = GymExpenseRecord(
                    id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
                    tenantId: widget.authController.activeTenantId,
                    title: titleCtrl.text.trim(),
                    amount: amt,
                    category: selectedCategory,
                    paymentMethod: selectedPaymentMethod,
                    date: selectedDate,
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                  );
                  await widget.authController.addGymExpense(newExp);
                  if (mounted) {
                    setState(() {
                      _expenses.insert(0, newExp);
                    });
                  }
                }

                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? '✅ Updated expense "${titleCtrl.text.trim()}"'
                          : '✨ Recorded expense of ₹${amt.toStringAsFixed(0)} under $selectedCategory!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                isEditing ? 'Save Changes' : 'Record Expense',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────── TAB 5: TEAM & STAFF MANAGEMENT ────────
  Widget _buildTeamTab(Color primaryColor) {
    final query = _teamSearchQuery.trim().toLowerCase();
    final filteredTeam = _teamMembers.where((member) {
      // Role filter
      if (_selectedTeamFilter == 'Owners' && member.role != GymTeamRole.owner) {
        return false;
      }
      if (_selectedTeamFilter == 'Managers' && member.role != GymTeamRole.manager) {
        return false;
      }
      if (_selectedTeamFilter == 'Trainers' && member.role != GymTeamRole.trainer) {
        return false;
      }
      if (_selectedTeamFilter == 'On Duty' && !member.isOnDuty) {
        return false;
      }

      // Text search
      if (query.isNotEmpty) {
        final matchesName = member.fullName.toLowerCase().contains(query);
        final matchesSpecialty = member.specialty.toLowerCase().contains(query);
        final matchesPhone = member.phone.contains(query);
        final matchesRole = member.role.displayName.toLowerCase().contains(query);
        final matchesGender = member.gender?.toLowerCase().contains(query) ?? false;
        final matchesExp = member.experience?.toLowerCase().contains(query) ?? false;
        return matchesName || matchesSpecialty || matchesPhone || matchesRole || matchesGender || matchesExp;
      }

      return true;
    }).toList();

    final totalOwners = _teamMembers.where((t) => t.role == GymTeamRole.owner).length;
    final totalManagers = _teamMembers.where((t) => t.role == GymTeamRole.manager).length;
    final totalTrainers = _teamMembers.where((t) => t.role == GymTeamRole.trainer).length;
    final totalOnDuty = _teamMembers.where((t) => t.isOnDuty).length;

    return Column(
      children: [
        // ── SEARCH & FILTER HEADER ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: const BoxDecoration(
            color: Color(0xFF131822),
            border: Border(bottom: BorderSide(color: Color(0xFF222B3C))),
          ),
          child: Column(
            children: [
              // Search and quick add row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF19202E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2B3648)),
                      ),
                      child: TextField(
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by name, role, specialty...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.textMutedDark,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppColors.textMutedDark,
                          ),
                          suffixIcon: _teamSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: Colors.white70),
                                  onPressed: () => setState(() => _teamSearchQuery = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onChanged: (v) => setState(() => _teamSearchQuery = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                    label: Text(
                      'Add',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _showAddTeamMemberDialog(primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTeamFilterChip('All', _teamMembers.length, primaryColor),
                    const SizedBox(width: 8),
                    _buildTeamFilterChip('Owners', totalOwners, const Color(0xFFA855F7)),
                    const SizedBox(width: 8),
                    _buildTeamFilterChip('Managers', totalManagers, const Color(0xFF06B6D4)),
                    const SizedBox(width: 8),
                    _buildTeamFilterChip('Trainers', totalTrainers, const Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    _buildTeamFilterChip('On Duty', totalOnDuty, AppColors.success),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── TEAM MEMBER LIST ──
        Expanded(
          child: filteredTeam.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_2_outlined,
                          size: 56,
                          color: AppColors.textMutedDark.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No Team Members Found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _teamSearchQuery.isNotEmpty
                              ? 'Try adjusting your search or role filters.'
                              : 'Start building your facility team right now.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: const Text('Add Team Member'),
                          onPressed: () => _showAddTeamMemberDialog(primaryColor),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTeam.length,
                  itemBuilder: (context, idx) {
                    final member = filteredTeam[idx];
                    return _buildTeamMemberCard(member, primaryColor);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeamFilterChip(String label, int count, Color accentColor) {
    final isSelected = _selectedTeamFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedTeamFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.25),
                    accentColor.withValues(alpha: 0.10),
                  ],
                )
              : null,
          color: isSelected ? null : const Color(0xFF141C2B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFF253347),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.35)
                    : const Color(0xFF202C3E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? accentColor : AppColors.textMutedDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMemberCard(GymTeamMemberRecord member, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141D2B),
            Color(0xFF0F1522),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: member.role == GymTeamRole.owner
              ? const Color(0xFFA855F7).withValues(alpha: 0.45)
              : const Color(0xFF223047),
          width: member.role == GymTeamRole.owner ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with glowing ring
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: member.role.color.withValues(alpha: 0.18),
                      border: Border.all(
                        color: member.role.color.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: member.role.color.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: member.imageBytes != null
                          ? Image.memory(
                              member.imageBytes!,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            )
                          : ImageOptimizer.buildImageWidget(
                              member.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: Center(
                                child: Text(
                                  member.fullName.isNotEmpty
                                      ? member.fullName[0].toUpperCase()
                                      : 'T',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: member.role.color,
                                  ),
                                ),
                              ),
                              errorBuilder: (_, __, ___) => Icon(
                                member.role.icon,
                                color: member.role.color,
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: member.role.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      member.role.icon,
                      size: 10,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.fullName,
                            style: GoogleFonts.poppins(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: member.role.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: member.role.color.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            member.role.badgeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: member.role.color,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Duty Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: member.isOnDuty
                                ? AppColors.success.withValues(alpha: 0.15)
                                : const Color(0xFF222B3C),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: member.isOnDuty
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            member.isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: member.isOnDuty
                                  ? AppColors.success
                                  : AppColors.textMutedDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Specialty / Department
                    Text(
                      member.specialty,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),

                    // Trainer Badges (Gender & Experience)
                    if (member.isTrainer) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (member.gender != null && member.gender!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: (member.gender == 'Female'
                                        ? const Color(0xFFF472B6)
                                        : (member.gender == 'Male'
                                            ? AppColors.accentCyan
                                            : AppColors.accentAmber))
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (member.gender == 'Female'
                                          ? const Color(0xFFF472B6)
                                          : (member.gender == 'Male'
                                              ? AppColors.accentCyan
                                              : AppColors.accentAmber))
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    member.gender == 'Female'
                                        ? Icons.female_rounded
                                        : (member.gender == 'Male'
                                            ? Icons.male_rounded
                                            : Icons.transgender_rounded),
                                    size: 12,
                                    color: member.gender == 'Female'
                                        ? const Color(0xFFF472B6)
                                        : (member.gender == 'Male'
                                            ? AppColors.accentCyan
                                            : AppColors.accentAmber),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    member.gender!,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: member.gender == 'Female'
                                          ? const Color(0xFFF472B6)
                                          : (member.gender == 'Male'
                                              ? AppColors.accentCyan
                                              : AppColors.accentAmber),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (member.experience != null && member.experience!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentAmber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.accentAmber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.work_history_rounded,
                                    size: 12,
                                    color: AppColors.accentAmber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    member.experience!,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentAmber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 6),
                    // Metrics or Contact details
                    if (member.isTrainer)
                      Text(
                        '${member.activeClientsCount} Active Clients • ⭐ ${member.rating}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentAmber,
                        ),
                      )
                    else
                      Text(
                        '📞 ${member.phone} • ✉️ ${member.email}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMutedDark,
                        ),
                      ),
                  ],
                ),
              ),

              // Actions menu / toggle
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                color: const Color(0xFF19202E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF2B3648)),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'attendance',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: AppColors.accentCyan,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'View Attendance',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_duty',
                    child: Row(
                      children: [
                        Icon(
                          member.isOnDuty ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                          size: 18,
                          color: member.isOnDuty ? AppColors.accentAmber : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          member.isOnDuty ? 'Mark Off Duty' : 'Mark On Duty',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(
                          'Remove Member',
                          style: GoogleFonts.inter(color: AppColors.error, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (action) {
                  final tenantId = member.tenantId ??
                      widget.authController.currentGymTenant?.id ??
                      'default_tenant';
                  if (action == 'attendance') {
                    _showStaffAttendanceDialog(member, primaryColor);
                  } else if (action == 'toggle_duty') {
                    widget.authController.toggleTeamMemberDuty(tenantId, member.id, !member.isOnDuty);
                    setState(() {
                      final idx = _teamMembers.indexWhere((m) => m.id == member.id);
                      if (idx != -1) {
                        _teamMembers[idx] = member.copyWith(isOnDuty: !member.isOnDuty);
                      }
                    });
                  } else if (action == 'delete') {
                    widget.authController.deleteTeamMember(tenantId, member.id);
                    setState(() {
                      _teamMembers.removeWhere((m) => m.id == member.id);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed ${member.fullName} from Team'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStaffAttendanceDialog(
    GymTeamMemberRecord member,
    Color primaryColor,
  ) {
    DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final regDate = member.createdAt ?? DateTime(2026, 1, 15);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedReg = DateTime(regDate.year, regDate.month, regDate.day);

    String dateKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    bool isPriorToRegistration(DateTime d) {
      final normD = DateTime(d.year, d.month, d.day);
      return normD.isBefore(normalizedReg);
    }

    bool isFutureDate(DateTime d) {
      final normD = DateTime(d.year, d.month, d.day);
      return normD.isAfter(today);
    }

    bool isMemberOnDutyOnDate(DateTime d) {
      if (isPriorToRegistration(d) || isFutureDate(d)) return false;
      final key = dateKey(d);
      if (_staffAttendanceOverrides[member.id]?[key] != null) {
        return _staffAttendanceOverrides[member.id]![key]!;
      }
      return member.isPresentOnDate(d);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
          final firstDayWeekday = DateTime(selectedMonth.year, selectedMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
          final emptyStartDays = firstDayWeekday - 1;

          int onDutyDays = 0;
          int offDutyDays = 0;
          int preRegDays = 0;
          int futureDays = 0;

          for (int day = 1; day <= daysInMonth; day++) {
            final d = DateTime(selectedMonth.year, selectedMonth.month, day);
            if (isPriorToRegistration(d)) {
              preRegDays++;
            } else if (isFutureDate(d)) {
              futureDays++;
            } else if (isMemberOnDutyOnDate(d)) {
              onDutyDays++;
            } else {
              offDutyDays++;
            }
          }

          final activeWorkingDays = onDutyDays + offDutyDays;
          final attendanceRate = activeWorkingDays > 0
              ? ((onDutyDays / activeWorkingDays) * 100).toStringAsFixed(0)
              : '100';

          final canGoPrev = selectedMonth.year > normalizedReg.year ||
              (selectedMonth.year == normalizedReg.year && selectedMonth.month > normalizedReg.month);
          final canGoNext = selectedMonth.year < today.year ||
              (selectedMonth.year == today.year && selectedMonth.month < today.month);

          return Dialog(
            backgroundColor: const Color(0xFF131A26),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF243248), width: 1.2),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── MODAL HEADER ──
                    Row(
                      children: [
                        // Staff Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: member.role.color.withValues(alpha: 0.15),
                            border: Border.all(color: member.role.color, width: 1.5),
                          ),
                          child: ClipOval(
                            child: member.imageBytes != null
                                ? Image.memory(member.imageBytes!, fit: BoxFit.cover)
                                : ImageOptimizer.buildImageWidget(
                                    member.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: Center(
                                      child: Text(
                                        member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'T',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w800,
                                          color: member.role.color,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    errorBuilder: (_, __, ___) => Icon(member.role.icon, color: member.role.color, size: 20),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member.fullName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: member.role.color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      member.role.badgeLabel,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: member.role.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Registered: ${DateFormat('dd MMM yyyy').format(normalizedReg)} • ${today.difference(normalizedReg).inDays} days active',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── MONTH NAVIGATOR ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF182232),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF26354D)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              color: canGoPrev ? Colors.white : Colors.white24,
                              size: 24,
                            ),
                            onPressed: canGoPrev
                                ? () {
                                    setModalState(() {
                                      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
                                    });
                                  }
                                : null,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.accentCyan),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMMM yyyy').format(selectedMonth),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              color: canGoNext ? Colors.white : Colors.white24,
                              size: 24,
                            ),
                            onPressed: canGoNext
                                ? () {
                                    setModalState(() {
                                      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── MONTHLY ATTENDANCE KPI CARDS ──
                    Row(
                      children: [
                        Expanded(
                          child: _buildAttendanceKpiCard(
                            title: 'On Duty / Present',
                            value: '$onDutyDays Days',
                            subtitle: '$attendanceRate% Duty Rate',
                            color: AppColors.success,
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAttendanceKpiCard(
                            title: 'Off Duty / Absent',
                            value: '$offDutyDays Days',
                            subtitle: 'Leaves & Off-days',
                            color: const Color(0xFFEF4444),
                            icon: Icons.cancel_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAttendanceKpiCard(
                            title: 'Month Total',
                            value: '$daysInMonth Days',
                            subtitle: preRegDays > 0
                                ? '$preRegDays Pre-join'
                                : (futureDays > 0 ? '$futureDays Upcoming' : 'Full Month'),
                            color: AppColors.accentCyan,
                            icon: Icons.date_range_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── CUSTOM CALENDAR VIEW ──
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1522),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF223047)),
                        ),
                        child: Column(
                          children: [
                            // Day Headers: MON - SUN
                            Row(
                              children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((day) {
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMutedDark,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            const Divider(color: Color(0xFF1E2A3C), height: 1),
                            const SizedBox(height: 8),

                            // Days Grid
                            Expanded(
                              child: GridView.builder(
                                physics: const ClampingScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  childAspectRatio: 1.05,
                                  crossAxisSpacing: 5,
                                  mainAxisSpacing: 5,
                                ),
                                itemCount: emptyStartDays + daysInMonth,
                                itemBuilder: (context, index) {
                                  if (index < emptyStartDays) {
                                    return const SizedBox.shrink();
                                  }

                                  final day = index - emptyStartDays + 1;
                                  final dayDate = DateTime(selectedMonth.year, selectedMonth.month, day);
                                  final isPrior = isPriorToRegistration(dayDate);
                                  final isFuture = isFutureDate(dayDate);
                                  final isToday = isSameDay(dayDate, today);
                                  final onDuty = isMemberOnDutyOnDate(dayDate);

                                  Color bgColor;
                                  Color borderColor;
                                  Color textColor;
                                  String statusText;
                                  IconData? statusIcon;

                                  if (isPrior) {
                                    bgColor = const Color(0xFF141A26).withValues(alpha: 0.4);
                                    borderColor = const Color(0xFF1B2332);
                                    textColor = Colors.white24;
                                    statusText = '–';
                                  } else if (isFuture) {
                                    bgColor = const Color(0xFF141A26).withValues(alpha: 0.5);
                                    borderColor = const Color(0xFF1F293B);
                                    textColor = Colors.white38;
                                    statusText = '–';
                                  } else if (onDuty) {
                                    bgColor = AppColors.success.withValues(alpha: 0.18);
                                    borderColor = AppColors.success.withValues(alpha: 0.5);
                                    textColor = Colors.white;
                                    statusText = 'ON';
                                    statusIcon = Icons.check_rounded;
                                  } else {
                                    bgColor = const Color(0xFFEF4444).withValues(alpha: 0.14);
                                    borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
                                    textColor = Colors.white70;
                                    statusText = 'OFF';
                                    statusIcon = Icons.close_rounded;
                                  }

                                  if (isToday) {
                                    borderColor = AppColors.accentCyan;
                                  }

                                  return InkWell(
                                    onTap: (!isPrior && !isFuture)
                                        ? () async {
                                            final key = dateKey(dayDate);
                                            final currentDuty = isMemberOnDutyOnDate(dayDate);
                                            final newDuty = !currentDuty;
                                            _staffAttendanceOverrides.putIfAbsent(member.id, () => {})[key] = newDuty;

                                            final tenantId = member.tenantId ??
                                                widget.authController.currentGymTenant?.id ??
                                                'default_tenant';

                                            await widget.authController.updateTeamMemberAttendance(
                                              tenantId: tenantId,
                                              memberId: member.id,
                                              dateKey: key,
                                              isPresent: newDuty,
                                            );

                                            if (isToday) {
                                              await widget.authController.toggleTeamMemberDuty(tenantId, member.id, newDuty);
                                              setState(() {
                                                final idx = _teamMembers.indexWhere((m) => m.id == member.id);
                                                if (idx != -1) {
                                                  _teamMembers[idx] = _teamMembers[idx].copyWith(isOnDuty: newDuty);
                                                }
                                              });
                                            }
                                            setModalState(() {});
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: borderColor,
                                          width: isToday ? 1.8 : 1,
                                        ),
                                        boxShadow: isToday
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.accentCyan.withValues(alpha: 0.3),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$day',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                          if (!isPrior && !isFuture) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (statusIcon != null)
                                                  Icon(
                                                    statusIcon,
                                                    size: 9,
                                                    color: onDuty ? AppColors.success : const Color(0xFFEF4444),
                                                  ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  statusText,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    color: onDuty ? AppColors.success : const Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              isPrior ? 'Pre' : 'Fut',
                                              style: GoogleFonts.inter(
                                                fontSize: 7.5,
                                                color: Colors.white24,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── FOOTER & LEGEND ──
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLegendItem(AppColors.success, 'On Duty'),
                            const SizedBox(width: 10),
                            _buildLegendItem(const Color(0xFFEF4444), 'Off Duty'),
                            const SizedBox(width: 10),
                            _buildLegendItem(AppColors.accentCyan, 'Today'),
                          ],
                        ),
                        Text(
                          '💡 Tap past date to adjust record',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: AppColors.textMutedDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151D2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // ──────── TAB 4: FACILITY & SUBSCRIPTION ────────
  Widget _buildFacilityTab(Color primaryColor, GymTenantModel? tenant) {
    final gymName = tenant?.gymName ?? 'GCRM One Fitness Facility';
    final address = tenant?.address ?? '452 5th Avenue, New York, NY';
    final phone = tenant?.phone ?? '+91 98765 43210';
    final ownerName = tenant?.ownerName ?? 'Marcus Vance';
    final adminEmail = tenant?.effectiveAdminEmail ?? 'admin@gym.com';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Facility Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF141D2B),
                  Color(0xFF0F1522),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF223047)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.25),
                            primaryColor.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                      ),
                      child: Icon(Icons.store_rounded, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Facility Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF202B3C), height: 24),
                _buildFacilityInfoRow('Gym Name', gymName),
                _buildFacilityInfoRow('Address', address),
                _buildFacilityInfoRow('Contact Phone', phone),
                _buildFacilityInfoRow('Owner', ownerName),
                _buildFacilityInfoRow('Admin Login', adminEmail),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Subscription Tier Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF141D2B),
                  Color(0xFF0F1522),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: tenant?.isLifetimeFree == true
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                    : const Color(0xFF223047),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (tenant?.isLifetimeFree == true
                                        ? const Color(0xFF8B5CF6)
                                        : primaryColor)
                                    .withValues(alpha: 0.25),
                                (tenant?.isLifetimeFree == true
                                        ? const Color(0xFF8B5CF6)
                                        : primaryColor)
                                    .withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (tenant?.isLifetimeFree == true
                                      ? const Color(0xFF8B5CF6)
                                      : primaryColor)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: tenant?.isLifetimeFree == true
                                ? const Color(0xFFC4B5FD)
                                : primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'GCRM Platform Plan',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (tenant?.isLifetimeFree == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'LIFETIME FREE',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(color: Color(0xFF202B3C), height: 24),
                _buildFacilityInfoRow(
                  'Current Plan',
                  tenant?.effectivePlanName ?? 'Growth Pro Tier',
                ),
                _buildFacilityInfoRow(
                  'Billing Period',
                  tenant?.isLifetimeFree == true
                      ? 'Lifetime Free'
                      : (tenant?.billingPeriod ?? 'Annual'),
                ),
                _buildFacilityInfoRow(
                  'Validity Status',
                  tenant?.formattedPlanPeriod ?? 'Active',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Spline and Area Gradient Painter for Sales Analytics
class _SalesChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final int? selectedIndex;

  _SalesChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double maxValue = values.reduce((a, b) => a > b ? a : b);
    final double effectiveMax = maxValue <= 0 ? 1000 : maxValue * 1.25;

    // 1. Draw horizontal background dashed grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF223047)
      ..strokeWidth = 1.0;

    const gridLinesCount = 3;
    for (int i = 0; i <= gridLinesCount; i++) {
      final y = size.height * (i / gridLinesCount);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Calculate point coordinates
    final points = <Offset>[];
    final double stepX = values.length > 1 ? size.width / (values.length - 1) : size.width / 2;

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normalizedY = (values[i] / effectiveMax).clamp(0.0, 1.0);
      final y = size.height - (normalizedY * (size.height - 20)) - 10;
      points.add(Offset(x, y));
    }

    // 3. Create smooth cubic bezier path
    final linePath = Path();
    final fillPath = Path();

    linePath.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;

      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // 4. Fill gradient below curve
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.35),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // 5. Draw glowing stroke curve
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawPath(linePath, glowPaint);

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, strokePaint);

    // 6. Draw data points
    for (int i = 0; i < points.length; i++) {
      final isSelected = selectedIndex == i;
      final pt = points[i];

      if (isSelected) {
        // Vertical dashed indicator
        final vertPaint = Paint()
          ..color = lineColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(pt.dx, 0), Offset(pt.dx, size.height), vertPaint);
      }

      // Outer ring
      canvas.drawCircle(
        pt,
        isSelected ? 6.5 : 4.0,
        Paint()..color = lineColor.withValues(alpha: isSelected ? 0.95 : 0.4),
      );
      // Inner circle
      canvas.drawCircle(
        pt,
        isSelected ? 3.5 : 2.0,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

/// Custom Donut Segmented Painter for Expenses Breakdown
class _ExpensesDonutPainter extends CustomPainter {
  final List<double> percentages;
  final List<Color> colors;

  _ExpensesDonutPainter({
    required this.percentages,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 14.0;

    // Background track ring
    final bgPaint = Paint()
      ..color = const Color(0xFF192232)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -3.14159 / 2; // start from 12 o'clock
    const gapAngle = 0.06;

    for (int i = 0; i < percentages.length; i++) {
      final sweepAngle = (percentages[i] * 2 * 3.14159) - gapAngle;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gapAngle / 2),
        sweepAngle,
        false,
        paint,
      );

      startAngle += percentages[i] * 2 * 3.14159;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpensesDonutPainter oldDelegate) => true;
}
