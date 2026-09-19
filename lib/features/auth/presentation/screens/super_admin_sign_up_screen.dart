import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/gcrm_logo_widget.dart';
import '../../controllers/auth_controller.dart';
import 'super_admin_dashboard_screen.dart';

/// Screen for creating a Master Super Admin account on Firebase.
class SuperAdminSignUpScreen extends StatefulWidget {
  final AuthController authController;

  const SuperAdminSignUpScreen({
    super.key,
    required this.authController,
  });

  @override
  State<SuperAdminSignUpScreen> createState() => _SuperAdminSignUpScreenState();
}

class _SuperAdminSignUpScreenState extends State<SuperAdminSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _securityPinController = TextEditingController();
  final _orgController = TextEditingController(text: 'GCRM ONE Global Platform');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _securityPinController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    widget.authController.clearMessages();
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Passwords do not match.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await widget.authController.registerSuperAdmin(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim().isEmpty
          ? '+91 98765 43210'
          : _phoneController.text.trim(),
      securityPin: _securityPinController.text.trim().isEmpty
          ? '884920'
          : _securityPinController.text.trim(),
      organization: _orgController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Super Admin account created successfully! Welcome to GCRM ONE.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SuperAdminDashboardScreen(
            authController: widget.authController,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Super Admin Registration',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedBuilder(
                animation: widget.authController,
                builder: (context, _) {
                  final isLoading = widget.authController.isLoading;
                  final errorMessage = widget.authController.errorMessage;

                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo & Brand Header
                        const Center(
                          child: GcrmLogoWidget(
                            size: 80,
                            showText: true,
                            showTagline: false,
                            isDark: true,
                            animateGlow: false,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form Container Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131822),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF222B3C),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.admin_panel_settings_rounded,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Create Super Admin',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'Master platform governance account',
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
                              const SizedBox(height: 20),

                              // Error Banner
                              if (errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.error.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: AppColors.error,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          errorMessage,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFFFFB4AB),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Full Name
                              CustomTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                hint: 'e.g. Nazar Nadeem',
                                prefixIcon: Icons.person_rounded,
                                validator: (v) =>
                                    Validators.requiredField(v, 'Full Name'),
                              ),
                              const SizedBox(height: 16),

                              // Email
                              CustomTextField(
                                controller: _emailController,
                                label: 'Super Admin Email',
                                hint: 'superadmin@gcrmone.com',
                                prefixIcon: Icons.email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.email,
                              ),
                              const SizedBox(height: 16),

                              // Phone Number
                              CustomTextField(
                                controller: _phoneController,
                                label: 'Phone Number',
                                hint: '+91 98765 43210',
                                prefixIcon: Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              CustomTextField(
                                controller: _passwordController,
                                label: 'Master Password',
                                hint: 'Minimum 8 characters',
                                prefixIcon: Icons.lock_rounded,
                                isPassword: true,
                                validator: Validators.password,
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password
                              CustomTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hint: 'Re-enter master password',
                                prefixIcon: Icons.lock_outline_rounded,
                                isPassword: true,
                                validator: (v) => Validators.confirmPassword(
                                  v,
                                  _passwordController.text,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Security PIN
                              CustomTextField(
                                controller: _securityPinController,
                                label: 'Master Security PIN (Optional)',
                                hint: '6-digit clearance code',
                                prefixIcon: Icons.pin_rounded,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 24),

                              // Submit Button
                              CustomButton(
                                text: 'Create Super Admin Account',
                                icon: Icons.how_to_reg_rounded,
                                isLoading: isLoading,
                                onPressed: _handleSignUp,
                              ),
                              const SizedBox(height: 20),

                              // Link to Login
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      'Sign In',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
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
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
