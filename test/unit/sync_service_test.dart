import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';
import 'package:dolo/core/sync/sync_service.dart';

import '../helpers/test_database.dart';

void main() {
  setUpAll(setUpTestDatabase);

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete(DbTables.syncJournal);
  });

  test('SyncService handles unconfigured cloud state gracefully', () async {
    final syncService = SyncService();
    // Default placeholder in template .env
    expect(syncService.isConfigured, isFalse);

    final result = await syncService.syncAll();
    expect(result.success, isFalse);
    expect(result.syncedCount, 0);
    expect(result.message, contains('Cloud relay is not configured'));
  });

  test('SyncService.recordGroupEvent inserts into local sync_journal', () async {
    await SyncService.recordGroupEvent(
      eventId: 'evt_test_1',
      groupId: 'group_hostel',
      eventType: 'insert_expense',
      payload: {'title': 'Hostel Milk', 'amount': 250},
    );

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      DbTables.syncJournal,
      where: 'event_id = ?',
      whereArgs: ['evt_test_1'],
    );

    expect(rows.length, 1);
    expect(rows.first['group_id'], 'group_hostel');
    expect(rows.first['event_type'], 'insert_expense');
    expect(rows.first['is_synced'], 0);
  });

  test('ingestRemoteEvents stores pulled events as synced and skips duplicates',
      () async {
    final events = [
      {
        'event_id': 'remote_1',
        'group_id': 'group_hostel',
        'event_type': 'EVENT_EXPENSE_CREATED',
        'payload': {'title': 'Mess bill', 'total_amount': 4800},
        'created_at': '2026-11-01T10:00:00Z',
      },
      {
        'event_id': 'remote_2',
        'group_id': 'group_hostel',
        'event_type': 'EVENT_SETTLEMENT_RECORDED',
        'payload': {'total_paid': 1200},
        'created_at': '2026-11-02T10:00:00Z',
      },
    ];

    expect(await SyncService.ingestRemoteEvents(events), 2);
    // A second pull of the same events adds nothing.
    expect(await SyncService.ingestRemoteEvents(events), 0);

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      DbTables.syncJournal,
      orderBy: 'event_id',
    );
    expect(rows.map((r) => r['event_id']), ['remote_1', 'remote_2']);
    // Pulled rows must never be pushed back to the cloud.
    expect(rows.every((r) => r['is_synced'] == 1), isTrue);
    expect(rows.first['payload'], contains('Mess bill'));
  });
}
