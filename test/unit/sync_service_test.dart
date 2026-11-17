import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';
import 'package:dolo/core/sync/sync_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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
}
