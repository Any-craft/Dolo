import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class AppTheme {
  AppTheme._();

  /// [accent] is the user-picked accent (Settings → Appearance).
  static ThemeData light({Color accent = AppColors.mint}) {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: accent,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: AppColors.indigo,
        surface: AppColors.lightSurface,
        error: AppColors.rose,
      ),
      textTheme: _textTheme(base.textTheme, AppColors.textLightPrimary),
      appBarTheme: _appBarTheme(),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: accent,
        unselectedItemColor: AppColors.textLightSecondary,
        elevation: 0,
      ),
      switchTheme: _switchTheme(accent, AppColors.lightPillInactive,
          AppColors.lightBorder),
      elevatedButtonTheme: _elevatedButtonTheme(accent),
      filledButtonTheme: _filledButtonTheme(accent),
      dividerTheme:
          const DividerThemeData(color: AppColors.lightPillInactive, space: 1),
    );
  }

  static ThemeData dark({Color accent = AppColors.mint}) {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: accent,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: AppColors.indigo,
        surface: AppColors.darkSurface,
        error: AppColors.rose,
      ),
      textTheme: _textTheme(base.textTheme, AppColors.textDarkPrimary),
      appBarTheme: _appBarTheme(),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: accent,
        unselectedItemColor: AppColors.textDarkMuted,
        elevation: 0,
      ),
      switchTheme: _switchTheme(
          accent, AppColors.darkPillInactive, AppColors.darkBorder),
      elevatedButtonTheme: _elevatedButtonTheme(accent),
      filledButtonTheme: _filledButtonTheme(accent),
      dividerTheme:
          const DividerThemeData(color: AppColors.darkPillInactive, space: 1),
    );
  }

  static ThemeData get lightTheme => light();
  static ThemeData get darkTheme => dark();

  /// Plus Jakarta Sans everywhere, so screens that use plain Text widgets
  /// match the ones that use AppTypography.
  static TextTheme _textTheme(TextTheme base, Color color) =>
      GoogleFonts.plusJakartaSansTextTheme(base)
          .apply(bodyColor: color, displayColor: color);

  /// Settings screens use a green bar with white title and back arrow.
  static AppBarTheme _appBarTheme() => AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.onCockpit,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: AppColors.onCockpit),
        actionsIconTheme: const IconThemeData(color: AppColors.onCockpit),
      );

  static SwitchThemeData _switchTheme(
          Color accent, Color offTrack, Color offOutline) =>
      SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textLightSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : offTrack,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : offOutline,
        ),
      );

  static ElevatedButtonThemeData _elevatedButtonTheme(Color accent) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.ctaRadius),
          ),
        ),
      );

  static FilledButtonThemeData _filledButtonTheme(Color accent) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.ctaRadius),
          ),
        ),
      );
}
