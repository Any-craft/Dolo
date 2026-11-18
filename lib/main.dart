import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers/appearance_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Chrome / Web
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  
  // Load confidential environment variables (.env)
  await AppConfig.init();

  // Safely initialize Supabase if valid credentials exist
  if (AppConfig.supabaseUrl.isNotEmpty &&
      !AppConfig.supabaseUrl.contains('your-project-id') &&
      !AppConfig.supabaseUrl.contains('placeholder')) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase init skipped (offline mode): $e');
    }
  }

  // Restore theme + accent before the first frame so they survive restarts.
  final appearance = await loadSavedAppearance();

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => appearance.themeMode),
        accentColorProvider.overrideWith((ref) => appearance.accent),
      ],
      child: const DoloApp(),
    ),
  );
}
