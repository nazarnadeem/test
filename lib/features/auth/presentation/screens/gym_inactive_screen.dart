import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../controllers/auth_controller.dart';
import 'gym_admin_dashboard_screen.dart';
import 'login_screen.dart';

/// Screen displayed to Gym Admins and staff when their gym facility
/// has been marked as Inactive / Suspended by the Platform Super Admin.
class GymInactiveScreen extends StatefulWidget {
  final AuthController authController;

  const GymInactiveScreen({
    super.key,
    required this.authController,
  });

  @override
  State<GymInactiveScreen> createState() => _GymInactiveScreenState();
}

class _GymInactiveScreenState extends State<GymInactiveScreen> {
  bool _isChecking = false;

  Future<void> _handleRefresh() async {
    setState(() => _isChecking = true);
    await widget.authController.loadGymTenants();
    await widget.authController.checkInitialSession();
    if (!mounted) return;
    setState(() => _isChecking = false);

    final tenant = widget.authController.currentGymTenant;
    if (tenant != null && tenant.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 Gym access restored! Welcome back.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GymAdminDashboardScreen(
            authController: widget.authController,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gym remains inactive. Please contact the Super Admin.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
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

  void _showContactAdminDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Super Admin Support',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF19202E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF283448)),
              ),
              child: Column(
                children: [
                  _buildContactItem(
                    icon: Icons.alternate_email_rounded,
                    title: 'Platform Admin Email',
                    value: AppStrings.adminEmail,
                  ),
                  const Divider(color: Color(0xFF283448), height: 16),
                  _buildContactItem(
                    icon: Icons.headset_mic_rounded,
                    title: 'Support Desk Email',
                    value: AppStrings.supportEmail,
                  ),
                  const Divider(color: Color(0xFF283448), height: 16),
                  _buildContactItem(
                    icon: Icons.phone_in_talk_rounded,
                    title: 'Direct Toll-Free Helpline',
                    value: AppStrings.supportPhone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Close',
              customColor: const Color(0xFF222B3C),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentCyan, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.currentUser;
    final tenant = widget.authController.currentGymTenant;
    final gymName = tenant?.gymName ?? (user?.gymName ?? 'Your Gym Facility');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D12),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Glowing Lockout Icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.domain_disabled_rounded,
                        size: 46,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Inactive Status Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          size: 13,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'FACILITY INACTIVE / SUSPENDED',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main Heading
                  Text(
                    'Gym Access Suspended',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Required user message banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141923),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Action Required by Administrator',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your gym "$gymName" has been marked as inactive by the platform administrator. Please contact him to restore access.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.45,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Facility Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131822),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF222B3C)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow(
                          label: 'Gym Facility',
                          value: gymName,
                          icon: Icons.fitness_center_rounded,
                        ),
                        const Divider(color: Color(0xFF222B3C), height: 16),
                        _buildSummaryRow(
                          label: 'Admin Account',
                          value: user?.fullName ?? 'Facility Admin',
                          icon: Icons.person_rounded,
                        ),
                        const Divider(color: Color(0xFF222B3C), height: 16),
                        _buildSummaryRow(
                          label: 'Admin Email',
                          value: user?.email ?? 'admin@gym.com',
                          icon: Icons.email_rounded,
                        ),
                        const Divider(color: Color(0xFF222B3C), height: 16),
                        _buildSummaryRow(
                          label: 'Account Status',
                          value: 'Marked Inactive / Suspended',
                          icon: Icons.lock_outline_rounded,
                          color: AppColors.error,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contact Super Admin Button
                  CustomButton(
                    text: 'Contact Super Admin',
                    icon: Icons.support_agent_rounded,
                    customColor: AppColors.primary,
                    onPressed: _showContactAdminDialog,
                  ),
                  const SizedBox(height: 10),

                  // Refresh Status Button
                  CustomButton(
                    text: _isChecking
                        ? 'Checking Access Status...'
                        : 'Check Reactivation Status',
                    icon: Icons.refresh_rounded,
                    isLoading: _isChecking,
                    customColor: const Color(0xFF1E2837),
                    onPressed: _isChecking ? null : _handleRefresh,
                  ),
                  const SizedBox(height: 12),

                  // Sign Out Button
                  TextButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: AppColors.textSecondaryDark,
                    ),
                    label: Text(
                      'Sign Out & Switch Account',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryDark,
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

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMutedDark),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondaryDark,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
