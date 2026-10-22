import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/white_label_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/gcrm_logo_widget.dart';
import '../../controllers/auth_controller.dart';
import 'forgot_password_screen.dart';
import 'gym_admin_dashboard_screen.dart';
import 'gym_inactive_screen.dart';
import 'super_admin_dashboard_screen.dart';
import 'super_admin_sign_up_screen.dart';

/// Clean, high-performance Login Screen for GCRM One.
/// Contains: Logo from assets, Email field, Password field, Forgot Password, and Sign In.
class LoginScreen extends StatefulWidget {
  final AuthController authController;

  const LoginScreen({
    super.key,
    required this.authController,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    widget.authController.clearMessages();
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final success = await widget.authController.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      final user = widget.authController.currentUser;
      if (user?.isSuperAdmin == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SuperAdminDashboardScreen(
              authController: widget.authController,
            ),
          ),
        );
      } else {
        await widget.authController.loadGymTenants();
        if (!mounted) return;
        final tenant = widget.authController.currentGymTenant;
        final Widget targetScreen = (tenant != null && tenant.isSuspended)
            ? GymInactiveScreen(authController: widget.authController)
            : GymAdminDashboardScreen(authController: widget.authController);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => targetScreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedBuilder(
                animation: widget.authController,
                builder: (context, _) {
                  final isLoading = widget.authController.isLoading;
                  final errorMessage = widget.authController.errorMessage;

                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. App Logo from assets
                        const Center(
                          child: GcrmLogoWidget(
                            size: 110,
                            showText: true,
                            showTagline: true,
                            isDark: true,
                            animateGlow: false,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Card Container
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
                              Text(
                                'Sign In',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter your email & password to access your account',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Error Banner
                              if (errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
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
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
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
                                const SizedBox(height: 16),
                              ],

                              // Email Field
                              CustomTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                hint: 'name@example.com',
                                prefixIcon: Icons.email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.email,
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              CustomTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: '••••••••••••',
                                isPassword: true,
                                prefixIcon: Icons.lock_rounded,
                                validator: Validators.password,
                                onFieldSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: 12),

                              // Forgot Password Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () {
                                    widget.authController.clearMessages();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordScreen(
                                          authController: widget.authController,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Sign In Button
                              CustomButton(
                                text: 'Sign In',
                                icon: Icons.login_rounded,
                                isLoading: isLoading,
                                onPressed: _handleLogin,
                              ),
                              const SizedBox(height: 20),

                              if (!WhiteLabelConfig.isRestricted)
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Need a Super Admin account? ',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      widget.authController.clearMessages();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SuperAdminSignUpScreen(
                                            authController: widget.authController,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Create Account',
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
