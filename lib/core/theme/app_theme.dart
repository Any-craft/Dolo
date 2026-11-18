import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  /// [accent] is the user-picked accent (Settings → Appearance).
  static ThemeData light({Color accent = AppColors.mint}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: accent,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: AppColors.indigo,
        surface: AppColors.lightSurface,
        error: AppColors.rose,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
    );
  }

  static ThemeData dark({Color accent = AppColors.mint}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkCockpitGradientStart,
      primaryColor: accent,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: AppColors.indigo,
        surface: AppColors.darkSurface,
        error: AppColors.rose,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );
  }

  static ThemeData get lightTheme => light();
  static ThemeData get darkTheme => dark();
}
