import 'app_database.dart';
import 'tables.dart';

/// Tiny key/value access to the `app_settings` table.
class AppSettingsStore {
  AppSettingsStore._();

  /// Returns the stored value, or null if missing or the DB is unavailable.
  static Future<String?> read(String key) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery(
        'SELECT value FROM "${DbTables.appSettings}" WHERE key = ? LIMIT 1',
        [key],
      );
      return rows.isEmpty ? null : rows.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Upserts [key] = [value]. Throws if the write fails.
  static Future<void> write(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO "${DbTables.appSettings}" (key, value) '
      'VALUES (?, ?)',
      [key, value],
    );
  }
}
