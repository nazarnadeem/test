import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography definitions for GCRM One using Google Fonts (Poppins & Inter).
class AppTextStyles {
  AppTextStyles._();

  // --- Display & Headings ---
  static TextStyle displayLarge(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: color ?? AppColors.textPrimaryDark,
    );
  }

  static TextStyle displayMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: color ?? AppColors.textPrimaryDark,
    );
  }

  static TextStyle displaySmall(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.textPrimaryDark,
    );
  }

  // --- Brand Title & Logo Typography ---
  static TextStyle brandTitle(BuildContext context, {double fontSize = 28}) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      fontStyle: FontStyle.italic,
      color: AppColors.textPrimaryDark,
    );
  }

  static TextStyle brandTagline(BuildContext context, {double fontSize = 12}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: AppColors.textSecondaryDark,
    );
  }

  // --- Headings ---
  static TextStyle headingLarge(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.textPrimaryDark,
    );
  }

  static TextStyle headingMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.textPrimaryDark,
    );
  }

  static TextStyle headingSmall(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.textPrimaryDark,
    );
  }

  // --- Body Text ---
  static TextStyle bodyLarge(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.textPrimaryDark,
    );
  }

  static TextStyle bodyMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.textSecondaryDark,
    );
  }

  static TextStyle bodySmall(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.textMutedDark,
    );
  }

  // --- Button & Action Typography ---
  static TextStyle button(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: color ?? Colors.white,
    );
  }

  static TextStyle label(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.textSecondaryDark,
    );
  }

  static TextStyle badge(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: color ?? AppColors.primary,
    );
  }
}
