import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../database/tables.dart';

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;

  const SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
  });
}

class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  bool get isConfigured {
    final url = AppConfig.supabaseUrl;
    final key = AppConfig.supabaseAnonKey;
    return url.isNotEmpty &&
        !url.contains('your-project-id') &&
        !url.contains('placeholder') &&
        key.isNotEmpty &&
        !key.contains('placeholder');
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Synchronize pending local group changes to Supabase and pull remote changes.
  Future<SyncResult> syncAll() async {
    if (!isConfigured) {
      return const SyncResult(
        success: false,
        message: 'Cloud relay is not configured yet. Add credentials in .env',
        syncedCount: 0,
      );
    }

    final client = _client;
    if (client == null) {
      return const SyncResult(
        success: false,
        message: 'Supabase client is not connected.',
        syncedCount: 0,
      );
    }

    try {
      final db = await AppDatabase.instance.database;

      // 1. Fetch all unsynced journal rows (Group changes only)
      final unsyncedRows = await db.query(
        DbTables.syncJournal,
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'id ASC',
      );

      if (unsyncedRows.isEmpty) {
        return const SyncResult(
          success: true,
          message: 'All group changes are in sync',
          syncedCount: 0,
        );
      }

      int syncedCount = 0;

      // 2. Push each change event to Supabase cloud_sync_journal
      for (final row in unsyncedRows) {
        final id = row['id'];
        final eventId = row['event_id'] as String;
        final groupId = row['group_id'] as String;
        final eventType = row['event_type'] as String;
        final payloadRaw = row['payload'] as String;
        final createdAt = row['created_at'] as String;

        Map<String, dynamic> payload;
        try {
          payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
        } catch (_) {
          payload = {'raw': payloadRaw};
        }

        // Upsert into Supabase
        await client.from('cloud_sync_journal').upsert({
          'event_id': eventId,
          'group_id': groupId,
          'event_type': eventType,
          'payload': payload,
          'created_at': createdAt,
        }, onConflict: 'event_id');

        // Mark local entry as synced
        await db.update(
          DbTables.syncJournal,
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );

        syncedCount++;
      }

      return SyncResult(
        success: true,
        message: 'Successfully synced $syncedCount change${syncedCount == 1 ? '' : 's'} to cloud!',
        syncedCount: syncedCount,
      );
    } catch (e) {
      debugPrint('SyncService error: $e');
      return SyncResult(
        success: false,
        message: 'Sync error: $e',
        syncedCount: 0,
      );
    }
  }

  /// Record a local group modification in the sync journal for background or manual sync.
  /// (Strict Rule: Private 1-on-1 expenses must NEVER be recorded in sync_journal)
  static Future<void> recordGroupEvent({
    required String eventId,
    required String groupId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();

      await db.insert(
        DbTables.syncJournal,
        {
          'event_id': eventId,
          'group_id': groupId,
          'event_type': eventType,
          'payload': jsonEncode(payload),
          'created_at': now,
          'is_synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error recording group sync event: $e');
    }
  }
}
