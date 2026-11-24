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
  static SyncService get instance => _instance;
  SyncService._();

  static const String supabaseUserIdKey = 'supabase_user_id';
  Future<String?>? _inFlight;

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

  /// Call ONLY when the user creates or joins a cloud group.
  /// Private 1-on-1 khata flows must never call this.
  Future<String?> ensureAnonymousSession() {
    return _inFlight ??= _ensure().whenComplete(() => _inFlight = null);
  }

  Future<String?> _ensure() async {
    try {
      final client = _client;
      if (client == null) return null;

      var user = client.auth.currentUser;
      if (user == null) {
        final response = await client.auth.signInAnonymously();
        user = response.user;
      }
      if (user == null) return null;

      await _saveUserId(user.id);
      return user.id;
    } on AuthException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Local-only check. Returns the saved Supabase user id if available.
  Future<String?> storedUserId() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery(
        'SELECT value FROM "${DbTables.appSettings}" WHERE key = ? LIMIT 1',
        [supabaseUserIdKey],
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUserId(String userId) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.rawInsert(
        'INSERT OR REPLACE INTO "${DbTables.appSettings}" (key, value) VALUES (?, ?)',
        [supabaseUserIdKey, userId],
      );
    } catch (_) {}
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

    final userId = await storedUserId();
    if (userId == null) {
      return const SyncResult(
        success: false,
        message: 'Sign in required. Cloud sync is only for shared groups.',
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

  static const String _selfId = 'user_self';

  /// Stores remote events in the local journal, already marked as synced so
  /// they are never pushed back. For 'expense_created', applies it to local
  /// SQLite expenses and expense_splits tables.
  static Future<int> ingestRemoteEvents(
    List<Map<String, dynamic>> events,
  ) async {
    final db = await AppDatabase.instance.database;
    final ownUid = await instance.storedUserId();
    var inserted = 0;

    for (final e in events) {
      final eventId = (e['event_id'] ?? e['id'])?.toString();
      final groupId = e['group_id']?.toString();
      final type = e['event_type']?.toString();
      if (eventId == null || groupId == null || type == null) continue;

      try {
        final isNew = await db.transaction<bool>((txn) async {
          final dup = await txn.query(
            DbTables.syncJournal,
            columns: ['event_id'],
            where: 'event_id = ?',
            whereArgs: [eventId],
            limit: 1,
          );
          if (dup.isNotEmpty) return false;

          final rawPayload = e['payload'];
          final payload = rawPayload is String
              ? (jsonDecode(rawPayload) as Map<String, dynamic>)
              : Map<String, dynamic>.from(rawPayload as Map);

          await txn.insert(
            DbTables.syncJournal,
            {
              'event_id': eventId,
              'group_id': groupId,
              'event_type': type,
              'payload': jsonEncode(payload),
              'created_at': e['created_at']?.toString() ??
                  DateTime.now().toUtc().toIso8601String(),
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          if (type == 'expense_created') {
            await _applyRemoteExpense(txn, groupId, payload, ownUid);
          }
          return true;
        });

        if (isNew) inserted++;
      } catch (err) {
        debugPrint('Error applying remote event $eventId: $err');
      }
    }
    return inserted;
  }

  static Future<void> _applyRemoteExpense(
    Transaction txn,
    String groupId,
    Map<String, dynamic> wirePayload,
    String? ownUid,
  ) async {
    final p = _mapPayloadIds(wirePayload, from: ownUid, to: _selfId);
    final expenseId = p['expense_id']?.toString() ?? p['id']?.toString();
    final payerId = p['payer_id']?.toString();
    final total = (p['total_amount'] as num?)?.toInt();
    if (expenseId == null || payerId == null || total == null) return;

    final splits = (p['splits'] as List? ?? const [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();

    for (final id in {payerId, ...splits.map((s) => s['contact_id']?.toString())}) {
      if (id == null || id == _selfId) continue;
      await txn.rawInsert(
        'INSERT OR IGNORE INTO contacts (id, name, avatar_initials, is_shadow, created_at) '
        'VALUES (?, ?, ?, 0, ?)',
        [id, 'Group member', 'GM', DateTime.now().toIso8601String()],
      );
    }

    await txn.insert(
      DbTables.expenses,
      {
        'id': expenseId,
        'group_id': groupId,
        'payer_id': payerId,
        'title': (p['title'] as String?) ?? 'Group Expense',
        'category': (p['category'] as String?) ?? 'Other',
        'total_amount': total,
        'split_mode': (p['split_mode'] as String?) ?? 'equal',
        'payment_method': (p['payment_method'] as String?) ?? 'Cash',
        'is_settled': 0,
        'is_trashed': 0,
        'created_at': (p['created_at'] as String?) ?? DateTime.now().toIso8601String(),
        'receipt_image_path': null,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    for (final s in splits) {
      final contactId = s['contact_id']?.toString();
      if (contactId == null) continue;
      await txn.insert(
        DbTables.expenseSplits,
        {
          'id': s['id']?.toString() ?? '${expenseId}_$contactId',
          'expense_id': expenseId,
          'contact_id': contactId,
          'share_amount': (s['share_amount'] as num?)?.toInt() ?? 0,
          'is_paid': (s['is_paid'] as num?)?.toInt() ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Map<String, dynamic> _mapPayloadIds(
    Map<String, dynamic> payload, {
    required String? from,
    required String? to,
  }) {
    if (from == null || to == null) return payload;
    String swap(Object? v) => v.toString() == from ? to : v.toString();

    final out = Map<String, dynamic>.from(payload);
    if (out['payer_id'] != null) out['payer_id'] = swap(out['payer_id']);
    if (out['splits'] is List) {
      out['splits'] = [
        for (final s in out['splits'] as List)
          if (s is Map)
            {
              ...Map<String, dynamic>.from(s),
              if (s['contact_id'] != null)
                'contact_id': swap(s['contact_id']),
            },
      ];
    }
    return out;
  }

  /// Record a local group modification in the sync journal for background or manual sync.
  /// (Strict Rule: Private 1-on-1 expenses must NEVER be recorded in sync_journal)
  static Future<void> recordGroupEvent({
    String? eventId,
    required String groupId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();
      final ownUid = await instance.storedUserId();

      final wire = eventType == 'expense_created'
          ? _mapPayloadIds(payload, from: _selfId, to: ownUid)
          : payload;

      final eid = eventId ?? 'evt_${DateTime.now().microsecondsSinceEpoch}';

      await db.insert(
        DbTables.syncJournal,
        {
          'event_id': eid,
          'group_id': groupId,
          'event_type': eventType,
          'payload': jsonEncode(wire),
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
