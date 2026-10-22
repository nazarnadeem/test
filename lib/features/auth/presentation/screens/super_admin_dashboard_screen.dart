import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/utils/image_optimizer.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/gcrm_logo_widget.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/gym_tenant_model.dart';
import '../../data/models/platform_plan_model.dart';
import '../../data/models/push_notification_model.dart';
import '../widgets/gym_whatsapp_settings_card.dart';
import 'login_screen.dart';

/// Flagship Super Admin Dashboard Screen for GCRM One Platform Lead.
/// Provides platform governance, KPI metrics, gym management, and subscription plans.
class SuperAdminDashboardScreen extends StatefulWidget {
  final AuthController authController;

  const SuperAdminDashboardScreen({
    super.key,
    required this.authController,
  });

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _selectedTabIndex = 0; // 0: Gyms, 1: Subscription Plans
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.authController.loadGymTenants();
      widget.authController.loadPlatformPlans();
      widget.authController.loadNotificationsHistory();
    });
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2230),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E394D)),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Are you sure you want to end your Super Admin session?',
          style: GoogleFonts.inter(
            color: AppColors.textSecondaryDark,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondaryDark),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.authController.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      authController: widget.authController,
                    ),
                  ),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendNotificationDialog({GymTenantModel? preselectedTenant}) {
    final titleCtrl = TextEditingController(
      text: preselectedTenant != null ? '📢 Update for ${preselectedTenant.gymName}' : '',
    );
    final bodyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String targetAudience = preselectedTenant != null ? 'specific_gym' : 'all';
    GymTenantModel? selectedTenant = preselectedTenant ??
        (widget.authController.gymTenants.isNotEmpty ? widget.authController.gymTenants.first : null);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return Container(
              margin: EdgeInsets.only(
                top: 40,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF131822),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Color(0xFF222B3C), width: 1.5),
                  left: BorderSide(color: Color(0xFF222B3C), width: 1.5),
                  right: BorderSide(color: Color(0xFF222B3C), width: 1.5),
                ),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E3D52),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Send Push Notification',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Instant mobile broadcast with custom alert sound',
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
                    const Divider(color: Color(0xFF222B3C), height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARGET AUDIENCE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildAudienceChip(
                                  label: 'All Users',
                                  icon: Icons.public_rounded,
                                  isSelected: targetAudience == 'all',
                                  onTap: () => setModalState(() => targetAudience = 'all'),
                                ),
                                const SizedBox(width: 8),
                                _buildAudienceChip(
                                  label: 'Gym Admins',
                                  icon: Icons.shield_rounded,
                                  isSelected: targetAudience == 'gym_owners',
                                  onTap: () => setModalState(() => targetAudience = 'gym_owners'),
                                ),
                                const SizedBox(width: 8),
                                _buildAudienceChip(
                                  label: 'Specific Gym',
                                  icon: Icons.fitness_center_rounded,
                                  isSelected: targetAudience == 'specific_gym',
                                  onTap: () => setModalState(() => targetAudience = 'specific_gym'),
                                ),
                              ],
                            ),
                            if (targetAudience == 'specific_gym') ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F141E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF222B3C)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<GymTenantModel>(
                                    value: selectedTenant,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF131822),
                                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                                    items: widget.authController.gymTenants.map((t) {
                                      return DropdownMenuItem<GymTenantModel>(
                                        value: t,
                                        child: Text(
                                          '${t.gymName} (${t.ownerEmail})',
                                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newTenant) {
                                      setModalState(() => selectedTenant = newTenant);
                                    },
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Text(
                              'QUICK TEMPLATES',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryDark,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildTemplateChip(
                                    label: '⚡ Maintenance',
                                    onTap: () {
                                      setModalState(() {
                                        titleCtrl.text = '⚡ Scheduled Maintenance';
                                        bodyCtrl.text = 'GCRM One cloud services will undergo scheduled optimization tonight. No disruptions expected.';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTemplateChip(
                                    label: '🎉 New Features',
                                    onTap: () {
                                      setModalState(() {
                                        titleCtrl.text = '🎉 New Platform Features Live';
                                        bodyCtrl.text = 'Exciting updates including mobile QR check-in and batch scheduling are now active on your gym console!';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTemplateChip(
                                    label: '📢 Platform Notice',
                                    onTap: () {
                                      setModalState(() {
                                        titleCtrl.text = '📢 Platform Security Notice';
                                        bodyCtrl.text = 'Please verify your active team credentials and update operating member batches for the new month.';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTemplateChip(
                                    label: '💳 Renewal Alert',
                                    onTap: () {
                                      setModalState(() {
                                        titleCtrl.text = '💳 Subscription Plan Renewal';
                                        bodyCtrl.text = 'Your facility plan is approaching its expiry date. Please review subscription details to maintain uninterrupted access.';
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'NOTIFICATION TITLE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: titleCtrl,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'e.g., Scheduled Maintenance Notice',
                                hintStyle: GoogleFonts.inter(color: AppColors.textSecondaryDark, fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFF0F141E),
                                prefixIcon: const Icon(Icons.title_rounded, color: AppColors.primary, size: 20),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF222B3C)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a notification title' : null,
                              onChanged: (_) => setModalState(() {}),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'MESSAGE BODY',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: bodyCtrl,
                              maxLines: 3,
                              maxLength: 250,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter your message to platform users or gym admins...',
                                hintStyle: GoogleFonts.inter(color: AppColors.textSecondaryDark, fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFF0F141E),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF222B3C)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a notification message' : null,
                              onChanged: (_) => setModalState(() {}),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161F2E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.music_note_rounded, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Custom Alert Sound Active',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'Plays notification.mp3 on Android & iOS devices',
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
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      'ONLINE',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'DEVICE PREVIEW',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryDark,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B2332),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF2B3A50)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.fitness_center_rounded, size: 12, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppStrings.appName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '• now',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          color: AppColors.textSecondaryDark,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.volume_up_rounded, size: 13, color: AppColors.primary),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Notification Title Preview',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    bodyCtrl.text.isNotEmpty ? bodyCtrl.text : 'Notification body message will appear here for recipients...',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                label: Text(
                                  isSubmitting ? 'Dispatching Push Alert...' : 'Send Push Notification Now',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) return;
                                        setModalState(() => isSubmitting = true);

                                        final record = await widget.authController.sendPushNotification(
                                          title: titleCtrl.text.trim(),
                                          body: bodyCtrl.text.trim(),
                                          targetAudience: targetAudience,
                                          targetTenantId: targetAudience == 'specific_gym' ? selectedTenant?.id : null,
                                          targetGymName: targetAudience == 'specific_gym' ? selectedTenant?.gymName : null,
                                          sound: 'notification.mp3',
                                        );

                                        if (!mounted) return;
                                        Navigator.pop(ctx);

                                        if (record != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      'Push notification dispatched! Sound: notification.mp3',
                                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: AppColors.success,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAudienceChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : const Color(0xFF0F141E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFF222B3C),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondaryDark),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF161F2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF28364B)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showAddGymDialog() {
    final nameCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    final ownerEmailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final adminNameCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    final adminPasswordCtrl = TextEditingController();
    final whatsAppControllers = GymWhatsAppSettingsControllers();
    final hexColorCtrl = TextEditingController(text: '#FF5722');
    final formKey = GlobalKey<FormState>();

    Uint8List? selectedLogoBytes;
    ImageOptimizationResult? logoOptimizationResult;
    bool isOptimizingLogo = false;
    String selectedColorHex = '#FF5722';
    Color selectedPrimaryColor = const Color(0xFFFF5722);
    bool isSubmitting = false;

    // Subscription Plan & Validity state
    bool isLifetimeFree = false;
    DateTime startDate = DateTime.now();
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));

    final fallbackPlan = const PlatformPlanModel(
      id: '',
      name: 'No Plans Available',
      tagline: 'Please create a plan first',
      price: 0.0,
      billingPeriod: 'month',
      features: [],
    );

    final availablePlans = widget.authController.platformPlans.isNotEmpty
        ? widget.authController.platformPlans
        : [fallbackPlan];

    PlatformPlanModel selectedPlan = availablePlans.first;
    SubscriptionTier selectedTier = SubscriptionTier.growth;

    const brandPalette = [
      {'name': 'Athletic Orange', 'hex': '#FF5722', 'color': Color(0xFFFF5722)},
      {'name': 'Electric Cyan', 'hex': '#00E5FF', 'color': Color(0xFF00E5FF)},
      {'name': 'Volt Lime', 'hex': '#76FF03', 'color': Color(0xFF76FF03)},
      {'name': 'Amber Gold', 'hex': '#FFB300', 'color': Color(0xFFFFB300)},
      {'name': 'Crimson Rose', 'hex': '#F43F5E', 'color': Color(0xFFF43F5E)},
      {'name': 'Royal Violet', 'hex': '#8B5CF6', 'color': Color(0xFF8B5CF6)},
      {'name': 'Emerald Green', 'hex': '#10B981', 'color': Color(0xFF10B981)},
      {'name': 'Obsidian Blue', 'hex': '#3B82F6', 'color': Color(0xFF3B82F6)},
      {'name': 'Magenta Pulse', 'hex': '#EC4899', 'color': Color(0xFFEC4899)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickAndOptimizeLogo(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: source);
              if (picked == null) return;

              setModalState(() => isOptimizingLogo = true);
              final rawBytes = await picked.readAsBytes();
              final result = await ImageOptimizer.optimizeImage(
                rawBytes,
                maxDimension: 512,
                quality: 85,
              );
              setModalState(() {
                selectedLogoBytes = result.bytes;
                logoOptimizationResult = result;
                isOptimizingLogo = false;
              });
            } catch (e) {
              setModalState(() => isOptimizingLogo = false);
              debugPrint('Logo selection note: $e');
            }
          }

          Future<void> pickStartDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: startDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2040),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: selectedPrimaryColor,
                      onPrimary: Colors.black,
                      surface: const Color(0xFF1E2638),
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setModalState(() {
                startDate = picked;
                if (expiryDate.isBefore(startDate)) {
                  expiryDate = startDate.add(const Duration(days: 365));
                }
              });
            }
          }

          Future<void> pickExpiryDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: expiryDate.isAfter(startDate) ? expiryDate : startDate.add(const Duration(days: 365)),
              firstDate: startDate,
              lastDate: DateTime(2040),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: selectedPrimaryColor,
                      onPrimary: Colors.black,
                      surface: const Color(0xFF1E2638),
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setModalState(() {
                expiryDate = picked;
              });
            }
          }

          final durationDays = expiryDate.difference(startDate).inDays;

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.90,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 12,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sleek Top Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Modal Title Header (Sticky at top of 90% sheet)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedPrimaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.add_business_rounded,
                                color: selectedPrimaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Register New Gym',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Branding, plan setup & admin account',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                              ],
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

                    // Scrollable Form Body
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ──────── SECTION 1: GYM BRANDING (LOGO & COLOR) ────────
                            Row(
                              children: [
                                Icon(
                                  Icons.palette_rounded,
                                  size: 15,
                                  color: selectedPrimaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '1. GYM BRANDING & IDENTITY',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedPrimaryColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Gym Logo Picker Box
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF19202E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF283448)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Avatar Preview
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF0F131C),
                                          border: Border.all(
                                            color: selectedPrimaryColor,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: selectedPrimaryColor.withValues(alpha: 0.25),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: isOptimizingLogo
                                            ? Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      selectedPrimaryColor,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : (selectedLogoBytes != null
                                                ? ClipOval(
                                                    child: Image.memory(
                                                      selectedLogoBytes!,
                                                      width: 72,
                                                      height: 72,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.fitness_center_rounded,
                                                    size: 30,
                                                    color: selectedPrimaryColor,
                                                  )),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Gym Logo Asset',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Optimized client-side before Firebase Storage upload',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.textSecondaryDark,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF222B3C),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  icon: const Icon(Icons.photo_library_rounded, size: 14),
                                                  label: Text(
                                                    selectedLogoBytes != null ? 'Change' : 'Choose Logo',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      pickAndOptimizeLogo(ImageSource.gallery),
                                                ),
                                                if (selectedLogoBytes != null) ...[
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline_rounded,
                                                      color: AppColors.error,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      setModalState(() {
                                                        selectedLogoBytes = null;
                                                        logoOptimizationResult = null;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Live Image Optimization Stats Banner
                                  if (logoOptimizationResult != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.success.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.auto_awesome_rounded,
                                            color: AppColors.success,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Optimized: ${logoOptimizationResult!.summaryString}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Gym Primary Color Selector
                            Text(
                              'Gym Primary Brand Color',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: brandPalette.map((item) {
                                  final color = item['color'] as Color;
                                  final hex = item['hex'] as String;
                                  final isSelected = selectedColorHex.toUpperCase() == hex.toUpperCase();

                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedColorHex = hex;
                                        selectedPrimaryColor = color;
                                        hexColorCtrl.text = hex;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.transparent,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          if (isSelected)
                                            BoxShadow(
                                              color: color.withValues(alpha: 0.6),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                        ],
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Custom Hex Color Field
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: selectedPrimaryColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: CustomTextField(
                                    controller: hexColorCtrl,
                                    label: 'Color Hex Code',
                                    hint: '#FF5722',
                                    prefixIcon: Icons.colorize_rounded,
                                    onChanged: (val) {
                                      if (val.startsWith('#') && val.length == 7) {
                                        try {
                                          final hex = val.replaceFirst('#', '');
                                          final parsed = Color(int.parse('0xFF$hex'));
                                          setModalState(() {
                                            selectedColorHex = val;
                                            selectedPrimaryColor = parsed;
                                          });
                                        } catch (_) {}
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // ──────── SECTION 2: SUBSCRIPTION PLAN & VALIDITY ────────
                            Row(
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 15,
                                  color: selectedPrimaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '2. SUBSCRIPTION PLAN & DURATION',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedPrimaryColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Plan Selector Cards
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: availablePlans.map((plan) {
                                  final isSelected = selectedPlan.id == plan.id;
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedPlan = plan;
                                        if (plan.name.toLowerCase().contains('starter')) {
                                          selectedTier = SubscriptionTier.starter;
                                        } else if (plan.name.toLowerCase().contains('enterprise') || plan.name.toLowerCase().contains('vip')) {
                                          selectedTier = SubscriptionTier.enterprise;
                                        } else {
                                          selectedTier = SubscriptionTier.growth;
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 200,
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? selectedPrimaryColor.withValues(alpha: 0.12)
                                            : const Color(0xFF19202E),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? selectedPrimaryColor
                                              : const Color(0xFF283448),
                                          width: isSelected ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  plan.name,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: isSelected ? Colors.white : Colors.white70,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isSelected)
                                                Icon(
                                                  Icons.check_circle_rounded,
                                                  color: selectedPrimaryColor,
                                                  size: 16,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₹${NumberFormat.currency(symbol: '', decimalDigits: 0).format(plan.price)} / ${plan.billingPeriod}',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: selectedPrimaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            plan.tagline.isNotEmpty ? plan.tagline : 'All management features',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ──────── LIFETIME FREE GYM CHECKBOX TILE ────────
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  isLifetimeFree = !isLifetimeFree;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isLifetimeFree
                                      ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                                      : const Color(0xFF19202E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isLifetimeFree
                                        ? const Color(0xFF8B5CF6)
                                        : const Color(0xFF283448),
                                    width: isLifetimeFree ? 1.6 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: isLifetimeFree,
                                        activeColor: const Color(0xFF8B5CF6),
                                        checkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        side: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                                        onChanged: (val) {
                                          setModalState(() {
                                            isLifetimeFree = val ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Lifetime Free Gym',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isLifetimeFree ? Colors.white : Colors.white70,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isLifetimeFree
                                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                                                      : const Color(0xFF222B3C),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'FREE FOREVER',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isLifetimeFree
                                                        ? const Color(0xFFC4B5FD)
                                                        : AppColors.textMutedDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Grant permanent lifetime access without recurring billing or plan expiration',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (isLifetimeFree) ...[
                              // Start Date Box & Lifetime Banner
                              GestureDetector(
                                onTap: pickStartDate,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF19202E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF283448)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.play_circle_outline_rounded,
                                            size: 15,
                                            color: AppColors.accentCyan,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Activation Start Date:',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(startDate),
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.all_inclusive_rounded,
                                      size: 18,
                                      color: Color(0xFFC4B5FD),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '♾️ Lifetime Free Active — Permanent access, no expiration date required.',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFE9D5FF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Dates Selection (Start Date & Expiry Date)
                              Row(
                                children: [
                                  // Start Date Box
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: pickStartDate,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF19202E),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF283448)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.play_circle_outline_rounded,
                                                  size: 13,
                                                  color: AppColors.accentCyan,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Plan Start Date',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondaryDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(startDate),
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Expiry Date Box
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: pickExpiryDate,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF19202E),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF283448)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.event_available_rounded,
                                                  size: 13,
                                                  color: AppColors.success,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Plan Expiry Date',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondaryDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(expiryDate),
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Quick Duration Presets Chips
                              Row(
                                children: [
                                  Text(
                                    'Presets:',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textMutedDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          {'label': '+1 Mo', 'days': 30},
                                          {'label': '+3 Mo', 'days': 90},
                                          {'label': '+6 Mo', 'days': 180},
                                          {'label': '+1 Yr', 'days': 365},
                                          {'label': '+2 Yr', 'days': 730},
                                        ].map((preset) {
                                          final days = preset['days'] as int;
                                          final isCurrent = durationDays == days;

                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: InkWell(
                                              onTap: () {
                                                setModalState(() {
                                                  expiryDate = startDate.add(Duration(days: days));
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isCurrent
                                                      ? selectedPrimaryColor.withValues(alpha: 0.2)
                                                      : const Color(0xFF222B3C),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isCurrent
                                                        ? selectedPrimaryColor
                                                        : Colors.transparent,
                                                  ),
                                                ),
                                                child: Text(
                                                  preset['label'] as String,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isCurrent
                                                        ? selectedPrimaryColor
                                                        : Colors.white70,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Live Calculated Validity Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161F2E),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.accentCyan.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 13,
                                      color: AppColors.accentCyan,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Valid for $durationDays days (${DateFormat('dd MMM yyyy').format(startDate)} – ${DateFormat('dd MMM yyyy').format(expiryDate)})',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accentCyan,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // ──────── SECTION 3: GYM & OWNER DETAILS ────────
                            Row(
                              children: [
                                Icon(
                                  Icons.fitness_center_rounded,
                                  size: 15,
                                  color: selectedPrimaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '3. GYM & OWNER DETAILS',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedPrimaryColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 1. Gym Name
                            CustomTextField(
                              controller: nameCtrl,
                              label: 'Gym Name',
                              hint: 'e.g. IronPulse Fitness NYC',
                              prefixIcon: Icons.fitness_center_rounded,
                              validator: (v) =>
                                  Validators.requiredField(v, 'Gym Name'),
                            ),
                            const SizedBox(height: 12),

                            // 2. Owner's Full Name
                            CustomTextField(
                              controller: ownerCtrl,
                              label: "Owner's Full Name",
                              hint: 'e.g. Marcus Vance',
                              prefixIcon: Icons.person_rounded,
                              validator: (v) =>
                                  Validators.requiredField(v, "Owner's Full Name"),
                            ),
                            const SizedBox(height: 12),

                            // 3. Email (Owner's Email)
                            CustomTextField(
                              controller: ownerEmailCtrl,
                              label: "Owner's Email Address",
                              hint: 'owner@ironpulse.com',
                              prefixIcon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 12),

                            // 4. Phone Number
                            CustomTextField(
                              controller: phoneCtrl,
                              label: 'Contact Phone Number',
                              hint: Validators.mobileHint,
                              prefixIcon: Icons.phone_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: Validators.mobileInputFormatters,
                              validator: Validators.phone,
                            ),
                            const SizedBox(height: 12),

                            // 5. Location (Facility Address)
                            CustomTextField(
                              controller: addressCtrl,
                              label: 'Facility Location / Address',
                              hint: 'e.g. 452 5th Avenue, New York, NY',
                              prefixIcon: Icons.location_on_rounded,
                              validator: (v) =>
                                  Validators.requiredField(v, 'Location'),
                            ),
                            const SizedBox(height: 20),

                            // ──────── SECTION 4: GYM ADMIN ACCOUNT ────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.admin_panel_settings_rounded,
                                      size: 15,
                                      color: AppColors.accentCyan,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '4. GYM ADMIN ACCOUNT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentCyan,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                  ),
                                  icon: const Icon(Icons.copy_rounded, size: 13),
                                  label: Text(
                                    'Same as Owner',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      if (ownerCtrl.text.isNotEmpty) {
                                        adminNameCtrl.text = ownerCtrl.text.trim();
                                      }
                                      if (ownerEmailCtrl.text.isNotEmpty) {
                                        adminEmailCtrl.text = ownerEmailCtrl.text.trim();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // 6. Admin Name
                            CustomTextField(
                              controller: adminNameCtrl,
                              label: 'Admin Full Name',
                              hint: 'e.g. Marcus Vance (or Facility Manager)',
                              prefixIcon: Icons.badge_rounded,
                              validator: (v) =>
                                  Validators.requiredField(v, 'Admin Name'),
                            ),
                            const SizedBox(height: 12),

                            // 7. Admin Email
                            CustomTextField(
                              controller: adminEmailCtrl,
                              label: 'Admin Login Email',
                              hint: 'admin@ironpulse.com',
                              prefixIcon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 12),

                            // 8. Admin Password
                            CustomTextField(
                              controller: adminPasswordCtrl,
                              label: 'Admin Initial Password',
                              hint: 'Minimum 8 characters',
                              prefixIcon: Icons.lock_rounded,
                              isPassword: true,
                              validator: Validators.password,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'WhatsApp',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GymWhatsAppSettingsFields(controllers: whatsAppControllers),
                            const SizedBox(height: 24),

                            // Submit Button
                            CustomButton(
                              text: isSubmitting
                                  ? 'Creating Gym & Admin...'
                                  : 'Register Gym & Admin Account',
                              icon: Icons.check_circle_rounded,
                              isLoading: isSubmitting,
                              customColor: selectedPrimaryColor,
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;

                                      setModalState(() => isSubmitting = true);

                                      if (whatsAppControllers.hasPhoneNumber &&
                                          whatsAppControllers.accessToken.text.trim().isEmpty) {
                                        setModalState(() => isSubmitting = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Add the WhatsApp access token for this phone number, or leave the phone number blank.',
                                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                            ),
                                            backgroundColor: AppColors.error,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }

                                      final success =
                                          await widget.authController.registerGymWithAdmin(
                                        gymName: nameCtrl.text.trim(),
                                        ownerFullName: ownerCtrl.text.trim(),
                                        ownerEmail: ownerEmailCtrl.text.trim(),
                                        phone: phoneCtrl.text.trim(),
                                        address: addressCtrl.text.trim(),
                                        adminName: adminNameCtrl.text.trim(),
                                        adminEmail: adminEmailCtrl.text.trim(),
                                        adminPassword: adminPasswordCtrl.text,
                                        logoBytes: selectedLogoBytes,
                                        primaryColorHex: selectedColorHex,
                                        tier: selectedTier,
                                        planId: isLifetimeFree ? 'lifetime_free' : selectedPlan.id,
                                        planName: isLifetimeFree ? 'Lifetime Free Plan' : selectedPlan.name,
                                        planPrice: isLifetimeFree ? 0.0 : selectedPlan.price,
                                        billingPeriod: isLifetimeFree ? 'lifetime' : selectedPlan.billingPeriod,
                                        planStartDate: startDate,
                                        planExpiryDate: isLifetimeFree ? null : expiryDate,
                                        isLifetimeFree: isLifetimeFree,
                                      );

                                      var message = success
                                          ? 'Gym "${nameCtrl.text.trim()}" & Admin account (${adminEmailCtrl.text.trim()}) registered successfully!'
                                          : (widget.authController.errorMessage ?? 'Failed to register gym.');
                                      if (success && whatsAppControllers.hasPhoneNumber) {
                                        final adminEmail = adminEmailCtrl.text.trim().toLowerCase();
                                        final tenant = widget.authController.gymTenants
                                            .where((gym) => (gym.adminEmail ?? '').toLowerCase() == adminEmail)
                                            .firstOrNull;
                                        if (tenant == null) {
                                          message = '$message WhatsApp settings were not saved.';
                                        } else {
                                          try {
                                            await WhatsAppService.saveSettings(
                                              tenantId: tenant.id,
                                              phoneNumberId: whatsAppControllers.phoneNumberId.text,
                                              accessToken: whatsAppControllers.accessToken.text,
                                              templates: whatsAppControllers.templates.text,
                                            );
                                          } catch (error) {
                                            message =
                                                '$message WhatsApp settings were not saved: ${error.toString().replaceFirst('Exception: ', '')}';
                                          }
                                        }
                                      }

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              message,
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            backgroundColor: success
                                                ? AppColors.success
                                                : AppColors.error,
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

  void _showEditGymDialog(GymTenantModel tenant) async {
    final whatsAppControllers = GymWhatsAppSettingsControllers();
    var whatsAppTokenSaved = false;
    var whatsAppReady = false;
    try {
      final settings = await WhatsAppService.loadSettings(tenantId: tenant.id);
      whatsAppControllers.apply(settings);
      whatsAppTokenSaved = settings.tokenSaved;
      whatsAppReady = true;
    } catch (_) {}
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: tenant.gymName);
    final ownerCtrl = TextEditingController(text: tenant.ownerName);
    final ownerEmailCtrl = TextEditingController(text: tenant.ownerEmail);
    final phoneCtrl = TextEditingController(text: Validators.tenDigits(tenant.phone));
    final addressCtrl = TextEditingController(text: tenant.address);
    final hexColorCtrl = TextEditingController(text: tenant.primaryColorHex);
    final formKey = GlobalKey<FormState>();

    Uint8List? selectedLogoBytes;
    ImageOptimizationResult? logoOptimizationResult;
    bool isOptimizingLogo = false;
    bool isSubmitting = false;

    String selectedColorHex = tenant.primaryColorHex;
    Color selectedPrimaryColor = tenant.primaryColor;

    bool isLifetimeFree = tenant.isLifetimeFree;
    bool isGymActive = tenant.isActive;
    DateTime startDate = tenant.planStartDate ?? tenant.createdAt;
    DateTime expiryDate = tenant.planExpiryDate ?? DateTime.now().add(const Duration(days: 365));

    final fallbackPlan = const PlatformPlanModel(
      id: '',
      name: 'No Plans Available',
      tagline: 'Please create a plan first',
      price: 0.0,
      billingPeriod: 'month',
      features: [],
    );

    final availablePlans = widget.authController.platformPlans.isNotEmpty
        ? widget.authController.platformPlans
        : [fallbackPlan];

    PlatformPlanModel selectedPlan = availablePlans.firstWhere(
      (p) => p.id == tenant.planId,
      orElse: () => availablePlans.first,
    );
    SubscriptionTier selectedTier = tenant.tier;

    const brandPalette = [
      {'name': 'Athletic Orange', 'hex': '#FF5722', 'color': Color(0xFFFF5722)},
      {'name': 'Electric Cyan', 'hex': '#00E5FF', 'color': Color(0xFF00E5FF)},
      {'name': 'Volt Lime', 'hex': '#76FF03', 'color': Color(0xFF76FF03)},
      {'name': 'Amber Gold', 'hex': '#FFB300', 'color': Color(0xFFFFB300)},
      {'name': 'Crimson Rose', 'hex': '#F43F5E', 'color': Color(0xFFF43F5E)},
      {'name': 'Royal Violet', 'hex': '#8B5CF6', 'color': Color(0xFF8B5CF6)},
      {'name': 'Emerald Green', 'hex': '#10B981', 'color': Color(0xFF10B981)},
      {'name': 'Obsidian Blue', 'hex': '#3B82F6', 'color': Color(0xFF3B82F6)},
      {'name': 'Magenta Pulse', 'hex': '#EC4899', 'color': Color(0xFFEC4899)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickAndOptimizeLogo(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: source);
              if (picked == null) return;

              setModalState(() => isOptimizingLogo = true);
              final rawBytes = await picked.readAsBytes();
              final result = await ImageOptimizer.optimizeImage(
                rawBytes,
                maxDimension: 512,
                quality: 85,
              );
              setModalState(() {
                selectedLogoBytes = result.bytes;
                logoOptimizationResult = result;
                isOptimizingLogo = false;
              });
            } catch (e) {
              setModalState(() => isOptimizingLogo = false);
            }
          }

          Future<void> pickStartDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: startDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: selectedPrimaryColor,
                    onPrimary: Colors.black,
                    surface: const Color(0xFF19202E),
                    onSurface: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setModalState(() {
                startDate = picked;
                if (expiryDate.isBefore(startDate)) {
                  expiryDate = startDate.add(const Duration(days: 365));
                }
              });
            }
          }

          Future<void> pickExpiryDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: expiryDate.isAfter(startDate)
                  ? expiryDate
                  : startDate.add(const Duration(days: 30)),
              firstDate: startDate,
              lastDate: DateTime(2035),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: selectedPrimaryColor,
                    onPrimary: Colors.black,
                    surface: const Color(0xFF19202E),
                    onSurface: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setModalState(() {
                expiryDate = picked;
              });
            }
          }

          final durationDays = isLifetimeFree
              ? 99999
              : (expiryDate.difference(startDate).inDays > 0
                  ? expiryDate.difference(startDate).inDays
                  : 0);

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.90,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 12,
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
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: selectedPrimaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  color: selectedPrimaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Edit Gym Facility',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Modify branding, validity, and active status',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
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
                    const Divider(color: Color(0xFF222B3C), height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ──────── SECTION 1: FACILITY ACCESS STATUS ────────
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isGymActive
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isGymActive
                                      ? AppColors.success.withValues(alpha: 0.35)
                                      : AppColors.error.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isGymActive
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.block_rounded,
                                    color: isGymActive ? AppColors.success : AppColors.error,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isGymActive
                                              ? 'Gym Status: Active'
                                              : 'Gym Status: Inactive / Suspended',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: isGymActive
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                        ),
                                        Text(
                                          isGymActive
                                              ? 'Gym Admins and members can log in and use operations.'
                                              : 'Login access restricted. Inactive screen will be shown.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textSecondaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: isGymActive,
                                    activeThumbColor: AppColors.success,
                                    activeTrackColor: AppColors.success.withValues(alpha: 0.3),
                                    inactiveThumbColor: AppColors.error,
                                    inactiveTrackColor: AppColors.error.withValues(alpha: 0.3),
                                    onChanged: (val) {
                                      setModalState(() => isGymActive = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // ──────── SECTION 2: BRANDING & IDENTITY ────────
                            Row(
                              children: [
                                Icon(Icons.palette_rounded, size: 15, color: selectedPrimaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  '1. GYM BRANDING & IDENTITY',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedPrimaryColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Gym Logo Upload & Optimization Box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF19202E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF283448)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Logo Preview / Default
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF131822),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selectedPrimaryColor.withValues(alpha: 0.5),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: selectedLogoBytes != null
                                              ? Image.memory(
                                                  selectedLogoBytes!,
                                                  fit: BoxFit.cover,
                                                )
                                              : ImageOptimizer.buildImageWidget(
                                                  tenant.logoUrl,
                                                  fit: BoxFit.cover,
                                                  primaryColor: selectedPrimaryColor,
                                                  placeholder: Center(
                                                    child: Icon(
                                                      Icons.fitness_center_rounded,
                                                      color: selectedPrimaryColor,
                                                      size: 24,
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
                                            Text(
                                              'Gym Logo',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Auto-optimized before upload',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.textMutedDark,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                InkWell(
                                                  onTap: isOptimizingLogo
                                                      ? null
                                                      : () => pickAndOptimizeLogo(ImageSource.gallery),
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: selectedPrimaryColor.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: selectedPrimaryColor.withValues(alpha: 0.4),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.photo_library_rounded,
                                                          size: 13,
                                                          color: selectedPrimaryColor,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          selectedLogoBytes != null || (tenant.logoUrl != null && tenant.logoUrl!.isNotEmpty)
                                                              ? 'Change'
                                                              : 'Upload',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: selectedPrimaryColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (selectedLogoBytes != null) ...[
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons.delete_outline_rounded,
                                                      color: AppColors.error,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      setModalState(() {
                                                        selectedLogoBytes = null;
                                                        logoOptimizationResult = null;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (logoOptimizationResult != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.success.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.auto_awesome_rounded,
                                            color: AppColors.success,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Optimized: ${logoOptimizationResult!.summaryString}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Gym Primary Color
                            Text(
                              'Gym Primary Brand Color',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: brandPalette.map((item) {
                                final color = item['color'] as Color;
                                final hex = item['hex'] as String;
                                final isSelected = selectedColorHex.toLowerCase() == hex.toLowerCase();

                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedColorHex = hex;
                                      selectedPrimaryColor = color;
                                      hexColorCtrl.text = hex;
                                    });
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(alpha: 0.6),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: Icon(Icons.check, size: 16, color: Colors.white),
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            // ──────── SECTION 3: SUBSCRIPTION PLAN & DURATION ────────
                            Row(
                              children: [
                                Icon(Icons.card_membership_rounded, size: 15, color: selectedPrimaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  '2. SUBSCRIPTION PLAN & DURATION',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedPrimaryColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            // Plan Selector Cards
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: availablePlans.map((plan) {
                                  final isSelected = selectedPlan.id == plan.id;
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedPlan = plan;
                                        if (plan.name.toLowerCase().contains('starter')) {
                                          selectedTier = SubscriptionTier.starter;
                                        } else if (plan.name.toLowerCase().contains('enterprise') ||
                                            plan.name.toLowerCase().contains('vip')) {
                                          selectedTier = SubscriptionTier.enterprise;
                                        } else {
                                          selectedTier = SubscriptionTier.growth;
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 190,
                                      margin: const EdgeInsets.only(right: 10),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? selectedPrimaryColor.withValues(alpha: 0.12)
                                            : const Color(0xFF19202E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? selectedPrimaryColor
                                              : const Color(0xFF283448),
                                          width: isSelected ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            plan.name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? Colors.white : Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹${plan.price.toStringAsFixed(0)} / ${plan.billingPeriod}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? selectedPrimaryColor
                                                  : AppColors.textSecondaryDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Lifetime Free Gym Checkbox Tile
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  isLifetimeFree = !isLifetimeFree;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isLifetimeFree
                                      ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                                      : const Color(0xFF19202E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isLifetimeFree
                                        ? const Color(0xFF8B5CF6)
                                        : const Color(0xFF283448),
                                    width: isLifetimeFree ? 1.6 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: isLifetimeFree,
                                        activeColor: const Color(0xFF8B5CF6),
                                        checkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        side: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                                        onChanged: (val) {
                                          setModalState(() {
                                            isLifetimeFree = val ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Lifetime Free Gym',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isLifetimeFree ? Colors.white : Colors.white70,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isLifetimeFree
                                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                                                      : const Color(0xFF222B3C),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'FREE FOREVER',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isLifetimeFree
                                                        ? const Color(0xFFC4B5FD)
                                                        : AppColors.textMutedDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Permanent lifetime free access without subscription expiration',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textSecondaryDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (isLifetimeFree) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.all_inclusive_rounded,
                                      size: 18,
                                      color: Color(0xFFC4B5FD),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '♾️ Lifetime Free Active — No subscription expiration date required.',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFE9D5FF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Dates Selection (Start Date & Expiry Date)
                              Row(
                                children: [
                                  // Start Date Box
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: pickStartDate,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF19202E),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF283448)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.play_circle_outline_rounded,
                                                  size: 13,
                                                  color: AppColors.accentCyan,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Plan Start Date',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondaryDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(startDate),
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Expiry Date Box
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: pickExpiryDate,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF19202E),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF283448)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.event_available_rounded,
                                                  size: 13,
                                                  color: AppColors.success,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Plan Expiry Date',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondaryDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(expiryDate),
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Quick Duration Presets Chips
                              Row(
                                children: [
                                  Text(
                                    'Presets:',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textMutedDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          {'label': '+1 Mo', 'days': 30},
                                          {'label': '+3 Mo', 'days': 90},
                                          {'label': '+6 Mo', 'days': 180},
                                          {'label': '+1 Yr', 'days': 365},
                                          {'label': '+2 Yr', 'days': 730},
                                        ].map((preset) {
                                          final days = preset['days'] as int;
                                          final isCurrent = durationDays == days;

                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: InkWell(
                                              onTap: () {
                                                setModalState(() {
                                                  expiryDate = startDate.add(Duration(days: days));
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isCurrent
                                                      ? selectedPrimaryColor.withValues(alpha: 0.2)
                                                      : const Color(0xFF222B3C),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isCurrent
                                                        ? selectedPrimaryColor
                                                        : Colors.transparent,
                                                  ),
                                                ),
                                                child: Text(
                                                  preset['label'] as String,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isCurrent
                                                      ? selectedPrimaryColor
                                                      : Colors.white70,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),

                            // ──────── SECTION 4: GYM & OWNER DETAILS ────────
                            Row(
                              children: [
                                Icon(Icons.fitness_center_rounded, size: 15, color: selectedPrimaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  '3. GYM & OWNER DETAILS',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedPrimaryColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 1. Gym Name
                            CustomTextField(
                              controller: nameCtrl,
                              label: 'Gym Name',
                              hint: 'e.g. IronPulse Fitness NYC',
                              prefixIcon: Icons.fitness_center_rounded,
                              validator: (v) => Validators.requiredField(v, 'Gym Name'),
                            ),
                            const SizedBox(height: 12),

                            // 2. Owner's Full Name
                            CustomTextField(
                              controller: ownerCtrl,
                              label: "Owner's Full Name",
                              hint: 'e.g. Marcus Vance',
                              prefixIcon: Icons.person_rounded,
                              validator: (v) => Validators.requiredField(v, "Owner's Full Name"),
                            ),
                            const SizedBox(height: 12),

                            // 3. Email
                            CustomTextField(
                              controller: ownerEmailCtrl,
                              label: "Owner's Email Address",
                              hint: 'owner@ironpulse.com',
                              prefixIcon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 12),

                            // 4. Phone Number
                            CustomTextField(
                              controller: phoneCtrl,
                              label: 'Contact Phone Number',
                              hint: Validators.mobileHint,
                              prefixIcon: Icons.phone_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: Validators.mobileInputFormatters,
                              validator: Validators.phone,
                            ),
                            const SizedBox(height: 12),

                            // 5. Location
                            CustomTextField(
                              controller: addressCtrl,
                              label: 'Facility Location / Address',
                              hint: 'e.g. 452 5th Avenue, New York, NY',
                              prefixIcon: Icons.location_on_rounded,
                              validator: (v) => Validators.requiredField(v, 'Location'),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'WhatsApp',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (whatsAppReady)
                              GymWhatsAppSettingsFields(
                                controllers: whatsAppControllers,
                                tokenSaved: whatsAppTokenSaved,
                              )
                            else
                              Text(
                                'WhatsApp settings could not be loaded. Gym details can still be saved.',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            const SizedBox(height: 24),

                            // Save Changes Button
                            CustomButton(
                              text: isSubmitting ? 'Saving Changes...' : 'Save Gym Changes',
                              icon: Icons.save_rounded,
                              isLoading: isSubmitting,
                              customColor: selectedPrimaryColor,
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;

                                      if (whatsAppReady &&
                                          whatsAppControllers.hasPhoneNumber &&
                                          whatsAppControllers.accessToken.text.trim().isEmpty &&
                                          !whatsAppTokenSaved) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Add the WhatsApp access token for this phone number, or leave the phone number blank.',
                                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                            ),
                                            backgroundColor: AppColors.error,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }

                                      setModalState(() => isSubmitting = true);

                                      String? uploadedLogoUrl = tenant.logoUrl;
                                      if (selectedLogoBytes != null) {
                                        try {
                                          uploadedLogoUrl = await widget.authController.uploadGymLogo(
                                            gymId: tenant.id,
                                            imageBytes: selectedLogoBytes!,
                                            fileExtension: logoOptimizationResult?.format ?? 'jpg',
                                          );
                                        } catch (_) {}
                                      }

                                      final updatedTenant = tenant.copyWith(
                                        gymName: nameCtrl.text.trim(),
                                        ownerName: ownerCtrl.text.trim(),
                                        ownerEmail: ownerEmailCtrl.text.trim(),
                                        phone: phoneCtrl.text.trim(),
                                        address: addressCtrl.text.trim(),
                                        logoUrl: uploadedLogoUrl,
                                        primaryColorHex: selectedColorHex,
                                        planId: isLifetimeFree ? 'lifetime_free' : selectedPlan.id,
                                        planName: isLifetimeFree ? 'Lifetime Free Plan' : selectedPlan.name,
                                        planPrice: isLifetimeFree ? 0.0 : selectedPlan.price,
                                        billingPeriod: isLifetimeFree ? 'lifetime' : selectedPlan.billingPeriod,
                                        tier: selectedTier,
                                        planStartDate: startDate,
                                        planExpiryDate: isLifetimeFree ? null : expiryDate,
                                        isLifetimeFree: isLifetimeFree,
                                        status: isGymActive ? TenantStatus.active : TenantStatus.suspended,
                                      );

                                      final success = await widget.authController.updateGymTenant(updatedTenant);
                                      var message = success
                                          ? 'Gym "${nameCtrl.text.trim()}" updated successfully!'
                                          : (widget.authController.errorMessage ?? 'Failed to update gym.');
                                      if (success && whatsAppReady) {
                                        try {
                                          await WhatsAppService.saveSettings(
                                            tenantId: tenant.id,
                                            phoneNumberId: whatsAppControllers.phoneNumberId.text,
                                            accessToken: whatsAppControllers.accessToken.text,
                                            templates: whatsAppControllers.templates.text,
                                          );
                                        } catch (error) {
                                          message =
                                              '$message WhatsApp settings were not saved: ${error.toString().replaceFirst('Exception: ', '')}';
                                        }
                                      }

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              message,
                                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                            ),
                                            backgroundColor: success ? AppColors.success : AppColors.error,
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

  void _showAddPlanDialog() {
    final nameCtrl = TextEditingController();
    final taglineCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final discountedPriceCtrl = TextEditingController();
    final renewalPriceCtrl = TextEditingController();
    final featuresCtrl = TextEditingController(
      text: 'QR Member Check-In\nPOS Billing & Receipts\nClass Scheduling\nMulti-Staff Access',
    );
    bool isPopular = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
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
              top: 12,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sleek Top Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Modal Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.card_membership_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Create Subscription Plan',
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

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Plan Name
                          CustomTextField(
                            controller: nameCtrl,
                            label: 'Plan Name',
                            hint: 'e.g. Platinum All-Access',
                            prefixIcon: Icons.workspace_premium_rounded,
                            validator: (v) =>
                                Validators.requiredField(v, 'Plan Name'),
                          ),
                          const SizedBox(height: 14),

                          // 2. Tagline
                          CustomTextField(
                            controller: taglineCtrl,
                            label: 'Tagline / Description',
                            hint: 'e.g. Unlimited multi-location & trainer booking',
                            prefixIcon: Icons.subtitles_rounded,
                            validator: (v) =>
                                Validators.requiredField(v, 'Tagline'),
                          ),
                          const SizedBox(height: 14),

                          // 3. Regular Price
                          CustomTextField(
                            controller: priceCtrl,
                            label: 'Monthly Price (₹)',
                            hint: 'e.g. 4999',
                            prefixIcon: Icons.currency_rupee_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                Validators.requiredField(v, 'Price'),
                          ),
                          const SizedBox(height: 14),

                          // 4. Discounted Price (Optional)
                          CustomTextField(
                            controller: discountedPriceCtrl,
                            label: 'Discounted Price (₹) - Optional',
                            hint: 'e.g. 3999 for first month promo',
                            prefixIcon: Icons.local_offer_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 14),

                          // 5. Renewal Price (Optional)
                          CustomTextField(
                            controller: renewalPriceCtrl,
                            label: 'Renewal Price (₹) - Optional',
                            hint: 'e.g. 4499 after promo period',
                            prefixIcon: Icons.autorenew_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 14),

                          // 6. Included Features
                          CustomTextField(
                            controller: featuresCtrl,
                            label: 'Features List (one per line)',
                            hint: 'Feature 1\nFeature 2\nFeature 3',
                            prefixIcon: Icons.checklist_rounded,
                            maxLines: 4,
                            validator: (v) =>
                                Validators.requiredField(v, 'Features'),
                          ),
                          const SizedBox(height: 14),

                          // 7. Popular Tier Checkbox
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF19202E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF283448)),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isPopular,
                                  activeColor: AppColors.accentCyan,
                                  onChanged: (val) {
                                    setModalState(() {
                                      isPopular = val ?? false;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Highlight as "MOST POPULAR"',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'Displays bright gradient banner on checkout',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textSecondaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Submit Button
                          CustomButton(
                            text: 'Create Subscription Plan',
                            icon: Icons.check_circle_rounded,
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;

                              final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                              final discPrice = discountedPriceCtrl.text.trim().isNotEmpty
                                  ? double.tryParse(discountedPriceCtrl.text.trim())
                                  : null;
                              final renPrice = renewalPriceCtrl.text.trim().isNotEmpty
                                  ? double.tryParse(renewalPriceCtrl.text.trim())
                                  : null;

                              final features = featuresCtrl.text
                                  .trim()
                                  .split('\n')
                                  .where((f) => f.trim().isNotEmpty)
                                  .map((f) => f.trim())
                                  .toList();

                              final newPlan = PlatformPlanModel(
                                id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
                                name: nameCtrl.text.trim(),
                                tagline: taglineCtrl.text.trim(),
                                price: price,
                                discountedPrice: discPrice,
                                renewalPrice: renPrice,
                                billingPeriod: 'month',
                                features: features.isNotEmpty
                                    ? features
                                    : const [
                                        'QR Member Check-In',
                                        'POS Billing & Receipts',
                                        'Class Scheduling',
                                      ],
                                isPopular: isPopular,
                                isActive: true,
                                accentColor: isPopular
                                    ? const Color(0xFF00D2FF)
                                    : const Color(0xFF00E599),
                              );

                              final success =
                                  await widget.authController.addPlatformPlan(newPlan);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Subscription Plan "${newPlan.name}" saved to Firebase!'
                                          : 'Plan saved locally.',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF141923),
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(10.0),
          child: GcrmLogoWidget(
            size: 32,
            showText: false,
            isDark: true,
            animateGlow: false,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.appName,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              'Super Admin Platform Console',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Broadcast Push Notification',
            icon: const Icon(Icons.campaign_rounded, color: AppColors.primary),
            onPressed: () => _showSendNotificationDialog(),
          ),
          IconButton(
            tooltip: 'Refresh Metrics',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              widget.authController.loadGymTenants();
              widget.authController.loadNotificationsHistory();
            },
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B)),
            onPressed: _handleLogout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: Icon(
          _selectedTabIndex == 0
              ? Icons.add_business_rounded
              : (_selectedTabIndex == 1
                  ? Icons.add_circle_outline_rounded
                  : Icons.campaign_rounded),
          color: Colors.white,
        ),
        label: Text(
          _selectedTabIndex == 0
              ? 'Add Gym'
              : (_selectedTabIndex == 1 ? 'Add Plan' : 'Send Alert'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        onPressed: _selectedTabIndex == 0
            ? _showAddGymDialog
            : (_selectedTabIndex == 1
                ? _showAddPlanDialog
                : () => _showSendNotificationDialog()),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.authController,
          builder: (context, _) {
            final user = widget.authController.currentUser;
            final List<GymTenantModel> tenants =
                widget.authController.gymTenants;
            final List<PlatformPlanModel> plans =
                widget.authController.platformPlans;
            final isLoading = widget.authController.isLoadingTenants;

            // Calculate KPIs
            final totalGyms = tenants.length;
            final totalMembers = tenants.fold<int>(
              0,
              (int sum, GymTenantModel t) => sum + t.activeMembersCount,
            );
            final totalRevenue = tenants.fold<double>(
              0.0,
              (double sum, GymTenantModel t) => sum + t.monthlyRevenue,
            );
            final formattedRevenue =
                NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                    .format(totalRevenue);

            // Filtered Tenants
            final List<GymTenantModel> filteredTenants = tenants.where((t) {
              final matchesQuery = _searchQuery.isEmpty ||
                  t.gymName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  t.ownerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  t.gymCode.toLowerCase().contains(_searchQuery.toLowerCase());
              if (!matchesQuery) return false;
              if (_selectedFilter == 'All') return true;
              if (_selectedFilter == 'Active') {
                return t.status == TenantStatus.active;
              }
              if (_selectedFilter == 'Growth') {
                return t.tier == SubscriptionTier.growth;
              }
              if (_selectedFilter == 'Enterprise') {
                return t.tier == SubscriptionTier.enterprise;
              }
              return true;
            }).toList();

            return RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  widget.authController.loadGymTenants(),
                  widget.authController.loadPlatformPlans(),
                ]);
              },
              color: AppColors.primary,
              backgroundColor: const Color(0xFF1B2230),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (_selectedTabIndex != 2) return false;
                  if (!widget.authController.hasMoreSentNotifications) return false;
                  if (notification.metrics.axis != Axis.vertical) return false;
                  final nearBottom = notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 200;
                  if (nearBottom) {
                    widget.authController.loadNotificationsHistory(reset: false);
                  }
                  return false;
                },
                child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Super Admin Profile Header Card
                    _buildAdminProfileCard(user?.fullName, user?.email),
                    const SizedBox(height: 16),

                    // 2. Metric KPI Cards Grid
                    _buildKpiGrid(
                      totalGyms: totalGyms,
                      totalMembers: totalMembers,
                      formattedRevenue: formattedRevenue,
                    ),
                    const SizedBox(height: 20),

                    // 3. Navigation Tab Bar (Gyms vs Plans vs Push Alerts)
                    _buildSectionTabs(
                      tenantsCount: tenants.length,
                      plansCount: plans.length,
                      notificationsCount: widget.authController.sentNotifications.length,
                    ),
                    const SizedBox(height: 16),

                    // 4. Tab Body Content
                    if (_selectedTabIndex == 0) ...[
                      // --- GYMS VIEW ---
                      _buildSearchAndFilterBar(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Partner Gyms (${filteredTenants.length})',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (filteredTenants.isEmpty) ...[
                        _buildEmptyState(),
                      ] else ...[
                        ...filteredTenants.map((t) => _buildTenantCard(t)),
                      ],
                    ] else if (_selectedTabIndex == 1) ...[
                      // --- PLANS VIEW ---
                      _buildPlansHeader(plans.length),
                      const SizedBox(height: 12),
                      if (plans.isEmpty) ...[
                        _buildPlansEmptyState(),
                      ] else ...[
                        ...plans.map((p) => _buildPlanCard(p)),
                      ],
                    ] else ...[
                      // --- PUSH ALERTS & BROADCASTS VIEW ---
                      _buildNotificationsSection(
                        widget.authController.sentNotifications,
                        widget.authController.isLoadingNotifications,
                      ),
                    ],

                    const SizedBox(height: 80), // FAB space
                  ],
                ),
              ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTabs({
    required int tenantsCount,
    required int plansCount,
    required int notificationsCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2B3E)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _selectedTabIndex == 0
                      ? const LinearGradient(
                          colors: [
                            AppColors.primary,
                            Color(0xFFFF7043),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTabIndex == 0
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 15,
                      color: _selectedTabIndex == 0
                          ? Colors.white
                          : AppColors.textSecondaryDark,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Gyms ($tenantsCount)',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedTabIndex == 0
                              ? Colors.white
                              : AppColors.textSecondaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _selectedTabIndex == 1
                      ? const LinearGradient(
                          colors: [
                            AppColors.primary,
                            Color(0xFFFF7043),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTabIndex == 1
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.card_membership_rounded,
                      size: 15,
                      color: _selectedTabIndex == 1
                          ? Colors.white
                          : AppColors.textSecondaryDark,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Plans & Pricing ($plansCount)',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedTabIndex == 1
                              ? Colors.white
                              : AppColors.textSecondaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _selectedTabIndex == 2
                      ? const LinearGradient(
                          colors: [
                            AppColors.primary,
                            Color(0xFFFF7043),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTabIndex == 2
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      size: 16,
                      color: _selectedTabIndex == 2
                          ? Colors.white
                          : AppColors.textSecondaryDark,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Push Alerts ($notificationsCount)',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedTabIndex == 2
                              ? Colors.white
                              : AppColors.textSecondaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(List<PushNotificationRecord> history, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Broadcasts (${history.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Alert Sound: notification.mp3 active',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.campaign_rounded, size: 16, color: Colors.white),
              label: Text(
                'Send Alert',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              onPressed: () => _showSendNotificationDialog(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (isLoading && history.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF131822),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF222B3C)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 40, color: AppColors.textSecondaryDark),
                  const SizedBox(height: 10),
                  Text(
                    'No Push Notifications Sent Yet',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Send instant notifications with custom sound to all gyms or specific facilities.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () => _showSendNotificationDialog(),
                    child: const Text('Compose Broadcast', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ...history.map((record) => _buildNotificationRecordCard(record)),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else if (!widget.authController.hasMoreSentNotifications)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No more data',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildNotificationRecordCard(PushNotificationRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222B3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, y • h:mm a').format(record.createdAt),
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
                  color: (record.status == 'completed' || record.status == 'sent')
                      ? AppColors.success.withValues(alpha: 0.15)
                      : const Color(0xFFFFA000).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: (record.status == 'completed' || record.status == 'sent')
                        ? AppColors.success
                        : const Color(0xFFFFA000),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            record.body,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFFCFD8DC),
              height: 1.4,
            ),
          ),
          const Divider(color: Color(0xFF222B3C), height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2837),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 12, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 4),
                    Text(
                      record.audienceDisplayLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2837),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      record.sound,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (record.recipientsCount > 0)
                Text(
                  '${record.recipientsCount} recipient(s)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlansHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription Plans ($count)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Manage pricing tiers, capacity quotas & feature access',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
          label: Text(
            'New Plan',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          onPressed: _showAddPlanDialog,
        ),
      ],
    );
  }

  Widget _buildPlansEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222B3C)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_membership_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Subscription Plans in Firebase',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No plans exist in Cloud Firestore yet. Tap "Add Plan" to create and publish your first package.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: Text(
              'Add Plan',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            onPressed: _showAddPlanDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(PlatformPlanModel plan) {
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: plan.isPopular
              ? plan.accentColor.withValues(alpha: 0.6)
              : const Color(0xFF222B3C),
          width: plan.isPopular ? 1.8 : 1.0,
        ),
        boxShadow: plan.isPopular
            ? [
                BoxShadow(
                  color: plan.accentColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan Top Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: plan.accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: plan.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: plan.accentColor.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      plan.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (plan.isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          plan.accentColor,
                          plan.accentColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'MOST POPULAR',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Price & Tagline
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currencyFormatter.format(
                            plan.discountedPrice ?? plan.price,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: plan.discountedPrice != null
                                ? AppColors.success
                                : Colors.white,
                          ),
                        ),
                        if (plan.discountedPrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            currencyFormatter.format(plan.price),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMutedDark,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        Text(
                          '/ year',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.textSecondaryDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (plan.discountedPrice != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'SPECIAL OFFER',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2230),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF283448)),
                        ),
                        child: Text(
                          '${plan.subscribedGymsCount} Gyms Active',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plan.tagline,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondaryDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Annual Renewal Banner (Overflow-Safe)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18202D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF263246)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.autorenew_rounded,
                        size: 16,
                        color: AppColors.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                            ),
                            children: [
                              const TextSpan(text: 'Annual Renewal: '),
                              TextSpan(
                                text: plan.renewalPrice != null
                                    ? '${currencyFormatter.format(plan.renewalPrice)} / yr'
                                    : '${currencyFormatter.format(plan.price)} / yr',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242E40),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${plan.subscribedGymsCount} Gyms',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Features Bullet Points
                ...plan.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: plan.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Plan Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: plan.isActive,
                            activeThumbColor: AppColors.primary,
                            onChanged: (_) {
                              widget.authController.togglePlatformPlanStatus(plan.id);
                            },
                          ),
                        ),
                        Text(
                          plan.isActive ? 'Active Tier' : 'Disabled',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: plan.isActive
                                ? AppColors.success
                                : AppColors.textMutedDark,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Editing plan "${plan.name}" settings',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text(
                        'Edit Plan',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildAdminProfileCard(String? fullName, String? email) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF162032), Color(0xFF0F1522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223047)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accentCyan],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text(
                (fullName != null && fullName.isNotEmpty)
                    ? fullName[0].toUpperCase()
                    : 'A',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fullName ?? 'Platform Super Admin',
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
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
                          colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        'MASTER',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  email ?? 'admin@domain.com',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid({
    required int totalGyms,
    required int totalMembers,
    required String formattedRevenue,
  }) {
    final memberFormatter = NumberFormat.decimalPattern();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Active Gyms',
                value: '$totalGyms',
                subtitle: '+3 this month',
                icon: Icons.fitness_center_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Platform Members',
                value: memberFormatter.format(totalMembers),
                subtitle: 'Active Global',
                icon: Icons.groups_rounded,
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Monthly Volume',
                value: formattedRevenue,
                subtitle: 'Global MRR',
                icon: Icons.monetization_on_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'System Health',
                value: '99.9%',
                subtitle: 'Cloud Active',
                icon: Icons.cloud_done_rounded,
                color: AppColors.accentCyan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
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
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Column(
      children: [
        CustomTextField(
          label: '',
          hint: 'Search by gym name, owner, or referral code...',
          prefixIcon: Icons.search_rounded,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Active', 'Growth', 'Enterprise'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    filter,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: const Color(0xFF19202E),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFF283448),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTenantCard(GymTenantModel tenant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222B3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Gym Logo Avatar or Brand Colored Initials
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tenant.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tenant.primaryColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: ImageOptimizer.buildImageWidget(
                    tenant.logoUrl,
                    fit: BoxFit.cover,
                    primaryColor: tenant.primaryColor,
                    placeholder: Center(
                      child: Text(
                        tenant.gymName.isNotEmpty
                            ? tenant.gymName[0].toUpperCase()
                            : 'G',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: tenant.primaryColor,
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
                    Text(
                      tenant.gymName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tenant.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            tenant.address.isNotEmpty
                                ? tenant.address
                                : 'Facility Location',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(tenant.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: AppColors.textMutedDark,
              ),
              const SizedBox(width: 4),
              Text(
                'Owner: ${tenant.ownerName}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              if (tenant.adminName != null &&
                  tenant.adminName != tenant.ownerName) ...[
                const SizedBox(width: 10),
                const Icon(
                  Icons.badge_outlined,
                  size: 14,
                  color: AppColors.accentCyan,
                ),
                const SizedBox(width: 4),
                Text(
                  'Admin: ${tenant.adminName}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
              const Spacer(),
              const Icon(
                Icons.tag_rounded,
                size: 14,
                color: AppColors.textMutedDark,
              ),
              const SizedBox(width: 2),
              Text(
                tenant.gymCode,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tenant.primaryColor,
                ),
              ),
            ],
          ),
          // Plan & Validity Status Tag
          if (tenant.isLifetimeFree) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.all_inclusive_rounded,
                    size: 14,
                    color: Color(0xFFC4B5FD),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lifetime Free Gym • Permanent Active Access',
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
            ),
          ] else if (tenant.planExpiryDate != null || tenant.planName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tenant.isPlanActive
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tenant.isPlanActive
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    tenant.isPlanActive
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    size: 13,
                    color: tenant.isPlanActive ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${tenant.effectivePlanName} • ${tenant.isPlanActive ? "${tenant.remainingDays}d remaining" : "Expired"} (${tenant.formattedPlanPeriod})',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tenant.isPlanActive ? AppColors.success : AppColors.error,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(color: Color(0xFF222B3C), height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                'Members',
                '${tenant.activeMembersCount}',
                Icons.groups_outlined,
              ),
              _buildInfoItem(
                'Plan',
                tenant.effectivePlanName,
                Icons.workspace_premium_outlined,
              ),
              _buildInfoItem(
                'Revenue',
                NumberFormat.currency(
                  symbol: '₹',
                  locale: 'en_IN',
                  decimalDigits: 0,
                ).format(tenant.monthlyRevenue),
                Icons.currency_rupee_rounded,
              ),
            ],
          ),
          const Divider(color: Color(0xFF222B3C), height: 18),
          // Active/Inactive Toggle & Edit Button Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    tenant.isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_rounded,
                    size: 14,
                    color: tenant.isActive ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    tenant.isActive ? 'Facility Active' : 'Facility Inactive',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: tenant.isActive ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    child: Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value: tenant.isActive,
                        activeThumbColor: AppColors.success,
                        activeTrackColor: AppColors.success.withValues(alpha: 0.3),
                        inactiveThumbColor: AppColors.error,
                        inactiveTrackColor: AppColors.error.withValues(alpha: 0.3),
                        onChanged: (val) async {
                          await widget.authController.toggleGymStatus(
                            tenantId: tenant.id,
                            isActive: val,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val
                                    ? 'Gym "${tenant.gymName}" activated successfully.'
                                    : 'Gym "${tenant.gymName}" marked as Inactive (Access suspended).',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: val ? AppColors.success : AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showSendNotificationDialog(preselectedTenant: tenant),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.send_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Notify',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showEditGymDialog(tenant),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2837),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E3D52)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMutedDark),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textMutedDark,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusPill(TenantStatus status) {
    Color color;
    String text;

    switch (status) {
      case TenantStatus.active:
        color = AppColors.success;
        text = 'Active';
        break;
      case TenantStatus.pendingApproval:
        color = AppColors.warning;
        text = 'Pending';
        break;
      case TenantStatus.suspended:
        color = AppColors.error;
        text = 'Suspended';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222B3C)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 44,
            color: AppColors.textMutedDark,
          ),
          const SizedBox(height: 12),
          Text(
            'No Gyms Found',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search criteria or register a new gym.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
