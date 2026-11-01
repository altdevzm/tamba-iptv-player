import 'package:flutter/material.dart';

/// Design tokens extracted directly from the streaming reference interface.
class AppColors {
  AppColors._();

  // Core Canvas & Background
  static const Color background = Color(0xFF0D0D11);
  static const Color surface = Color(0xFF141419);
  static const Color surfaceElevated = Color(0xFF1C1C23);
  static const Color surfaceCard = Color(0xFF191920);

  // Glassmorphic Overlays
  static const Color glassSurface = Color(0xD917171F);
  static const Color glassBorder = Color(0x26FFFFFF);
  static const Color glassBorderSubtle = Color(0x14FFFFFF);

  // Brand & Accents
  static const Color primary = Color(0xFFE50914);
  static const Color primaryGlow = Color(0x59E50914);
  static const Color accentGreen = Color(0xFF46D369); // Match percentage
  static const Color accentAmber = Color(0xFFFFB800); // Rating stars

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A8);
  static const Color textMuted = Color(0xFF6B6B75);

  // Floating Player Pill
  static const Color playerPillBackground = Color(0xE6181820);
  static const Color playerPillBorder = Color(0x33FFFFFF);
  static const Color playerPillGlow = Color(0x20E50914);

  // Interactive States
  static const Color hoverHighlight = Color(0x1AFFFFFF);
  static const Color activeSelection = Color(0x2EFFFFFF);
  static const Color focusRing = Color(0xFFE50914);
}

