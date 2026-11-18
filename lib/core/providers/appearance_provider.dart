import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../database/app_settings_store.dart';

/// `app_settings` keys for appearance (seeded in AppDatabase._onCreate).
class AppearanceKeys {
  AppearanceKeys._();
  static const String themeMode = 'theme_mode';
  static const String accentColor = 'accent_color';
}

/// The 5 accent swatches from Handoff Task 7 / Design System §1C.
enum AccentColor {
  mint('mint', 'Mint', AppColors.mint),
  rose('rose', 'Rose', AppColors.rose),
  indigo('indigo', 'Indigo', AppColors.indigo),
  amber('amber', 'Amber', AppColors.categoryPrintouts),
  sky('sky', 'Sky', AppColors.categoryUdhar);

  const AccentColor(this.id, this.label, this.color);
  final String id;
  final String label;
  final Color color;

  static AccentColor fromId(String? id) => AccentColor.values.firstWhere(
        (a) => a.id == id,
        orElse: () => AccentColor.mint,
      );
}

ThemeMode themeModeFromId(String? id) {
  switch (id) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String themeModeToId(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

/// Active theme mode. Seeded from the database at startup (see main.dart).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Active accent colour. Seeded from the database at startup (see main.dart).
final accentColorProvider =
    StateProvider<AccentColor>((ref) => AccentColor.mint);

/// Reads saved appearance so the first frame already uses it (no flash, and
/// the choice survives restarts).
Future<({ThemeMode themeMode, AccentColor accent})>
    loadSavedAppearance() async {
  final results = await Future.wait([
    AppSettingsStore.read(AppearanceKeys.themeMode),
    AppSettingsStore.read(AppearanceKeys.accentColor),
  ]);
  return (
    themeMode: themeModeFromId(results[0]),
    accent: AccentColor.fromId(results[1]),
  );
}
