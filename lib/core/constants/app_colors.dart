import 'package:flutter/material.dart';

/// Design system color tokens. Brand is "money green" (Nov 2026 refresh).
class AppColors {
  AppColors._();

  // --- Top Cockpit (Money Green Gradient) ---
  static const Color cockpitGradientStart = Color(0xFF12B76A);
  static const Color cockpitGradientEnd = Color(0xFF0A8F52);

  // Dark mode cockpit (deeper green so it doesn't glare at night)
  static const Color darkCockpitGradientStart = Color(0xFF0B7A47);
  static const Color darkCockpitGradientEnd = Color(0xFF075232);

  // --- Surface Sheets (Bottom 65%) ---
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF4FBF7);
  static const Color lightPillInactive = Color(0xFFEAF4EE);
  static const Color lightBorder = Color(0xFFCFE0D6);

  static const Color darkSurface = Color(0xFF13231B);
  static const Color darkBackground = Color(0xFF0B1611);
  static const Color darkPillInactive = Color(0xFF1C3327);
  static const Color darkPillActive = Color(0xFF264636);
  static const Color darkBorder = Color(0xFF2E4A3B);

  // --- Glass Triad Capsule ---
  static const Color glassTriadBg = Color(0x29FFFFFF); // rgba(255,255,255, 0.16)
  static const Color glassTriadBorder = Color(0x40FFFFFF); // rgba(255,255,255, 0.25)

  // --- The Financial Status Triad ---
  // 1. You Are Owed / brand (Money Green)
  static const Color mint = Color(0xFF12B76A);
  static const Color mintTextLight = Color(0xFF05804F);
  static const Color mintTextDark = Color(0xFF4ADE94);
  static const Color mintSquircleBg = Color(0xFFE3F8EE);
  static const Color mintGlass = Color(0x2912B76A);

  // 2. You Owe (Rose / Coral)
  static const Color rose = Color(0xFFE11D48);
  static const Color roseTextLight = Color(0xFFBE123C);
  static const Color roseTextDark = Color(0xFFFB7185);
  static const Color roseSquircleBg = Color(0xFFFFE4EA);
  static const Color roseGlass = Color(0x2EF43F5E);

  // 3. Settled / Groups (Indigo / Purple)
  static const Color indigo = Color(0xFF818CF8);
  static const Color indigoDeep = Color(0xFF6C5CE7);
  static const Color indigoTextLight = Color(0xFF5B4FD6);
  static const Color indigoTextDark = Color(0xFFA5B4FC);
  static const Color indigoSquircleBg = Color(0xFFE8E6FF);
  static const Color indigoNotice = Color(0xFF3B30A8);

  // --- Student Categories ---
  static const Color categoryFood = Color(0xFF12B76A);
  static const Color categoryHostel = Color(0xFF818CF8);
  static const Color categoryFuel = Color(0xFFF43F5E);
  static const Color categoryPrintouts = Color(0xFFF59E0B);
  static const Color categoryUdhar = Color(0xFF38BDF8);

  // --- Typography Contrasts ---
  static const Color textDarkPrimary = Color(0xFFFFFFFF);
  static const Color textDarkMuted = Color(0xFFA9C4B6);

  static const Color textLightPrimary = Color(0xFF0F1F17);
  static const Color textLightMuted = Color(0xFF5F7268);
  // Text on the green cockpit header
  static const Color onCockpit = Color(0xFFFFFFFF);
  static const Color onCockpitMuted = Color(0xD9FFFFFF); // white 85%

  static const Color textLightSecondary = Color(0xFF94A89D);
}
