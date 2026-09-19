import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

/// Official Brand Logo Widget for GCRM One.
/// Loads the official brand logo from assets ([AppAssets.logo]).
/// 
/// Supports:
/// - Full brand badge for Splash, Login, and Header banners
/// - Compact emblem/avatar mode for AppBars and navigation headers
/// - Ambient glow effect, customizable size, and graceful error fallback
class GcrmLogoWidget extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showTagline;
  final bool isDark;
  final bool animateGlow;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const GcrmLogoWidget({
    super.key,
    this.size = 110,
    this.showText = true,
    this.showTagline = true,
    this.isDark = true,
    this.animateGlow = false,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!showText) {
      // Compact Icon / Badge mode (for AppBars, chips, compact headers)
      final radius = borderRadius ?? BorderRadius.circular(math.max(6.0, size * 0.22));
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.0,
          ),
          boxShadow: animateGlow
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: size * 0.4,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.all(size * 0.06),
            child: Image.asset(
              AppAssets.logo,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: size * 0.6,
                    color: AppColors.primary,
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Full Logo Display (Splash Screen, Auth Screens, Header Banners)
    final radius = borderRadius ?? BorderRadius.circular(math.max(14.0, size * 0.14));
    final glowColor = isDark ? AppColors.primary : AppColors.primaryDark;

    return Container(
      width: size * 1.35,
      height: size * 1.35,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          if (animateGlow)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.4),
              blurRadius: size * 0.35,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Image.asset(
            AppAssets.logo,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: size * 0.5,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.appName,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        fontSize: size * 0.18,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
