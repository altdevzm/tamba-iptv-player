import 'package:flutter/material.dart';

/// Design tokens extracted directly from the streaming reference interface.
class AppColors {
  AppColors._();

  // Core Canvas & Background
  static const Color background = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF141419);
  static const Color surfaceElevated = Color(0xFF1C1C24);
  static const Color surfaceCard = Color(0xFF17171E);

  // Subtle Overlays & Borders
  static const Color glassSurface = Color(0xEB141419);
  static const Color glassBorder = Color(0x1EFFFFFF);
  static const Color glassBorderSubtle = Color(0x10FFFFFF);

  // Brand & Accents
  static const Color primary = Color(0xFFE50914);
  static const Color primaryGlow = Color(0x59E50914);
  static const Color accentGreen = Color(0xFF46D369); // Match percentage
  static const Color accentAmber = Color(0xFFFFB800); // Rating stars

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA8A8B3);
  static const Color textMuted = Color(0xFF6E6E7A);

  // Floating Player Pill
  static const Color playerPillBackground = Color(0xF5181820);
  static const Color playerPillBorder = Color(0x26FFFFFF);
  static const Color playerPillGlow = Color(0x20E50914);

  // Interactive States
  static const Color hoverHighlight = Color(0x1AFFFFFF);
  static const Color activeSelection = Color(0x2EFFFFFF);

  // Smart TV Focus System (Tamba Blue — distinct from Red Selected/Active states)
  static const Color tvFocus = Color(0xFF2F80FF);
  static const Color tvFocusBright = Color(0xFF60A5FA);
  static const Color tvFocusFill = Color(0x332F80FF);
  static const Color tvFocusGlow = Color(0x802F80FF);
  static const Color focusRing = tvFocus;
}

