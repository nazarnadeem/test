import 'package:flutter/material.dart';

/// Centralized Color Palette for GCRM One.
/// Extracted directly from the official GCRM One brand logo.
class AppColors {
  AppColors._();

  // --- Primary Brand Colors (Vibrant Athletic Orange) ---
  static const Color primary = Color(0xFFFF5500);
  static const Color primaryLight = Color(0xFFFF7A33);
  static const Color primaryDark = Color(0xFFD94400);
  static const Color primaryGlow = Color(0x33FF5500);

  // --- Secondary & Accent Tones ---
  static const Color accentOrange = Color(0xFFFF8C38);
  static const Color accentAmber = Color(0xFFFFAA00);
  static const Color accentCyan = Color(0xFF00D2FF);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentEmerald = Color(0xFF10B981);

  // --- Dark Surface & Carbon Palette (Logo Charcoal & Obsidian) ---
  static const Color darkBackground = Color(0xFF0A0D12);
  static const Color darkSurface = Color(0xFF121721);
  static const Color darkCard = Color(0xFF181F2C);
  static const Color darkCardBorder = Color(0xFF242E40);
  static const Color darkInputFill = Color(0xFF141923);
  static const Color darkInputFocusedBorder = Color(0xFFFF5500);

  // --- Light Surface Palette ---
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightInputFill = Color(0xFFF1F5F9);

  // --- Text Colors ---
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // --- Semantic & Status Colors ---
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // --- Role Identification Colors ---
  static const Color roleSuperAdmin = Color(0xFFFF5500); // Brand Orange
  static const Color roleGymOwner = Color(0xFF8B5CF6);   // Purple/Indigo
  static const Color roleTrainer = Color(0xFF06B6D4);    // Cyan
  static const Color roleMember = Color(0xFF10B981);     // Emerald

  // --- Brand Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B00), Color(0xFFFF3D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient logoGradient = LinearGradient(
    colors: [Color(0xFFFF8533), Color(0xFFFF4500)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF161C26), Color(0xFF0F131B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient superAdminGradient = LinearGradient(
    colors: [Color(0xFFFF5500), Color(0xFFB33600)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradientDark = LinearGradient(
    colors: [
      Color(0x33242E40),
      Color(0x1A121721),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
