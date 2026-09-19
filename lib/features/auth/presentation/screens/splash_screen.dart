import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/gcrm_logo_widget.dart';
import '../../controllers/auth_controller.dart';
import 'gym_admin_dashboard_screen.dart';
import 'gym_inactive_screen.dart';
import 'login_screen.dart';
import 'super_admin_dashboard_screen.dart';

/// Animated branded Splash Screen for GCRM One.
/// Automatically transitions to Dashboard if authenticated, otherwise LoginScreen.
class SplashScreen extends StatefulWidget {
  final AuthController authController;

  const SplashScreen({
    super.key,
    required this.authController,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    await widget.authController.checkInitialSession();

    if (!mounted) return;

    final user = widget.authController.currentUser;
    final Widget targetScreen;
    if (widget.authController.isAuthenticated) {
      if (user?.isSuperAdmin == true) {
        targetScreen = SuperAdminDashboardScreen(authController: widget.authController);
      } else {
        await widget.authController.loadGymTenants();
        if (!mounted) return;
        final tenant = widget.authController.currentGymTenant;
        if (tenant != null && tenant.isSuspended) {
          targetScreen = GymInactiveScreen(authController: widget.authController);
        } else {
          targetScreen = GymAdminDashboardScreen(authController: widget.authController);
        }
      }
    } else {
      targetScreen = LoginScreen(authController: widget.authController);
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Background ambient light glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryDark.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Center Logo & Tagline
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GcrmLogoWidget(
                      size: 130,
                      showText: true,
                      showTagline: true,
                      isDark: true,
                      animateGlow: true,
                    ),
                    SizedBox(height: 48),
                    // Loading indicator
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
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
}
