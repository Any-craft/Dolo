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
        await client.from(remoteTable).upsert({
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

      // 3. Pull other members' events for the shared groups on this device.
      final pulledCount = await _pullRemoteEvents(client, db);

      if (syncedCount == 0 && pulledCount == 0) {
        return const SyncResult(
          success: true,
          message: 'All group changes are in sync',
          syncedCount: 0,
        );
      }

      String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
      final parts = [
        if (syncedCount > 0) 'sent ${plural(syncedCount, 'change')}',
        if (pulledCount > 0) 'received ${plural(pulledCount, 'update')}',
      ];
      return SyncResult(
        success: true,
        message: 'Synced: ${parts.join(', ')}',
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

  /// Supabase table holding the shared append-only event journal.
  static const String remoteTable = 'cloud_sync_journal';

  /// Fetches events for every cloud-synced group and stores the new ones.
  /// Returns how many events were new to this device.
  ///
  /// Fetches the full journal for those groups rather than using a
  /// "since" cursor: `created_at` is client-side, so an event pushed late by
  /// a member who was offline can carry an older timestamp and would be
  /// skipped by a cursor. Duplicates are dropped by the UNIQUE event_id.
  Future<int> _pullRemoteEvents(SupabaseClient client, Database db) async {
    final groupRows = await db.rawQuery(
      'SELECT id FROM "${DbTables.groups}" WHERE cloud_synced = 1',
    );
    if (groupRows.isEmpty) return 0;
    final groupIds = groupRows.map((r) => r['id'] as String).toList();

    final remote = await client
        .from(remoteTable)
        .select('event_id, group_id, event_type, payload, created_at')
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: true);

    return ingestRemoteEvents(List<Map<String, dynamic>>.from(remote));
  }

  /// Stores remote events in the local journal, already marked as synced so
  /// they are never pushed back. Events this device already has are ignored.
  /// Returns the number of newly stored events.
  static Future<int> ingestRemoteEvents(
    List<Map<String, dynamic>> events,
  ) async {
    final db = await AppDatabase.instance.database;
    var inserted = 0;
    await db.transaction((txn) async {
      for (final e in events) {
        final payload = e['payload'];
        final id = await txn.insert(
          DbTables.syncJournal,
          {
            'event_id': e['event_id'] as String,
            'group_id': e['group_id'] as String,
            'event_type': e['event_type'] as String,
            'payload': payload is String ? payload : jsonEncode(payload),
            'created_at': e['created_at']?.toString() ??
                DateTime.now().toUtc().toIso8601String(),
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id != 0) inserted++;
      }
    });
    return inserted;
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
