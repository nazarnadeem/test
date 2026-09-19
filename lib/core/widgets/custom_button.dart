import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

enum ButtonVariant { primary, secondary, outline, danger }

/// Gradient athletic action button with loading state, haptic feedback glow, and icon support.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final IconData? icon;
  final double height;
  final double? width;
  final Color? customColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.height = 52,
    this.width,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onPressed == null || isLoading;

    if (variant == ButtonVariant.outline) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: customColor ??
                  (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              width: 1.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: _buildChild(
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      );
    }

    // Primary & Gradient Variant
    LinearGradient gradient;
    if (variant == ButtonVariant.danger) {
      gradient = const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
      );
    } else if (variant == ButtonVariant.secondary) {
      gradient = LinearGradient(
        colors: isDark
            ? [const Color(0xFF242E40), const Color(0xFF19202C)]
            : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
      );
    } else {
      gradient = AppColors.primaryGradient;
    }

    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: isDisabled
            ? LinearGradient(
                colors: [
                  (customColor ?? AppColors.primary).withValues(alpha: 0.35),
                  (customColor ?? AppColors.primaryDark).withValues(alpha: 0.35),
                ],
              )
            : gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: (!isDisabled && variant == ButtonVariant.primary)
            ? [
                BoxShadow(
                  color: (customColor ?? AppColors.primary).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: _buildChild(
              variant == ButtonVariant.secondary && !isDark
                  ? AppColors.textPrimaryLight
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: textColor,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: textColor,
      ),
    );
  }
}
