import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/gcrm_logo_widget.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/utils/validators.dart';
import '../../controllers/auth_controller.dart';

/// Password recovery screen connected to Firebase Authentication.
/// Sends password reset links directly to registered email addresses.
class ForgotPasswordScreen extends StatefulWidget {
  final AuthController authController;

  const ForgotPasswordScreen({
    super.key,
    required this.authController,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;
  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendResetLink() async {
    widget.authController.clearMessages();
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final success = await widget.authController.requestPasswordReset(email);

    if (success && mounted) {
      setState(() {
        _emailSent = true;
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reset link dispatched to $email',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
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
          'Password Recovery',
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Brand Logo
                        const Center(
                          child: GcrmLogoWidget(
                            size: 100,
                            showText: true,
                            showTagline: true,
                            isDark: true,
                            animateGlow: false,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Form Card
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
                              if (!_emailSent) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.lock_reset_rounded,
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
                                            'Forgot Password',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            'Reset via email link',
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
                                const SizedBox(height: 16),
                                Text(
                                  'Enter your registered email address and Firebase will send you a secure link to reset your password.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondaryDark,
                                    height: 1.4,
                                  ),
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

                                // Email Input
                                CustomTextField(
                                  controller: _emailController,
                                  label: 'Registered Email Address',
                                  hint: 'superadmin@gcrmone.com',
                                  prefixIcon: Icons.email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: Validators.email,
                                  onFieldSubmitted: (_) => _handleSendResetLink(),
                                ),
                                const SizedBox(height: 24),

                                // Submit Button
                                CustomButton(
                                  text: 'Send Reset Link',
                                  icon: Icons.send_rounded,
                                  isLoading: isLoading,
                                  onPressed: _handleSendResetLink,
                                ),
                              ] else ...[
                                // Success confirmation state
                                Center(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.success.withValues(alpha: 0.4),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.mark_email_read_rounded,
                                      color: AppColors.success,
                                      size: 32,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Check Your Inbox',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'We have sent a secure password reset link to:',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B2230),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _emailController.text.trim(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Please click the link in the email to set your new password. If you do not see it, check your spam or promotions folder.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMutedDark,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Resend option
                                Center(
                                  child: _resendCountdown > 0
                                      ? Text(
                                          'Resend available in ${_resendCountdown}s',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            color: AppColors.textMutedDark,
                                          ),
                                        )
                                      : TextButton.icon(
                                          onPressed: isLoading
                                              ? null
                                              : _handleSendResetLink,
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                          label: Text(
                                            'Resend Reset Link',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 16),

                                CustomButton(
                                  text: 'Back to Sign In',
                                  icon: Icons.arrow_back_rounded,
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
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
