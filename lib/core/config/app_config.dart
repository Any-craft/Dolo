import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration class managing confidential environment credentials.
class AppConfig {
  AppConfig._();

  /// Initialize environment variables from .env
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // In offline mode or if .env is missing, app runs safely with fallback defaults
    }
  }

  /// Supabase project URL (Free Tier Cloud Relay)
  static String get supabaseUrl {
    try {
      return dotenv.env['SUPABASE_URL'] ?? 'https://placeholder.supabase.co';
    } catch (_) {
      return 'https://placeholder.supabase.co';
    }
  }

  /// Supabase public anonymous API key
  static String get supabaseAnonKey {
    try {
      return dotenv.env['SUPABASE_ANON_KEY'] ?? 'placeholder-anon-key';
    } catch (_) {
      return 'placeholder-anon-key';
    }
  }

  /// Current environment name
  static String get environment {
    try {
      return dotenv.env['APP_ENV'] ?? 'development';
    } catch (_) {
      return 'development';
    }
  }

  /// Toggle for background cloud sync
  static bool get enableCloudSync {
    try {
      return (dotenv.env['ENABLE_CLOUD_SYNC'] ?? 'false').toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Debug logging enabled flag
  static bool get isDebugLogging {
    try {
      return (dotenv.env['DEBUG_LOGGING'] ?? 'true').toLowerCase() == 'true';
    } catch (_) {
      return true;
    }
  }
}
