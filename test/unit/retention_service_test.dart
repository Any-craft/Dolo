import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';
import 'package:dolo/features/retention/data/retention_service.dart';

import '../helpers/test_database.dart';

Future<void> _insertExpense(String id, {String? trashedAt}) async {
  final db = await AppDatabase.instance.database;
  await db.insert(DbTables.expenses, {
    'id': id,
    'group_id': null,
    'payer_id': 'user_self',
    'title': 'Expense $id',
    'category': 'Food',
    'total_amount': 500,
    'split_mode': 'EQUAL',
    'payment_method': 'CASH',
    'is_settled': 0,
    'is_trashed': trashedAt == null ? 0 : 1,
    'trashed_at': trashedAt,
    'created_at': DateTime.now().toIso8601String(),
  });
}

Future<Map<String, Object?>?> _row(String id) async {
  final db = await AppDatabase.instance.database;
  final rows =
      await db.query(DbTables.expenses, where: 'id = ?', whereArgs: [id]);
  return rows.isEmpty ? null : rows.first;
}

void main() {
  setUpAll(setUpTestDatabase);

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete(DbTables.expenseSplits);
    await db.delete(DbTables.expenses);
  });

  final service = RetentionService();

  test('trashExpense soft-deletes and stamps trashed_at', () async {
    await _insertExpense('exp_a');

    await service.trashExpense('exp_a');

    final row = await _row('exp_a');
    expect(row, isNotNull);
    expect(row!['is_trashed'], 1);
    expect(DateTime.tryParse(row['trashed_at'] as String), isNotNull);
  });

  test('restoreExpense clears the trash flags', () async {
    await _insertExpense('exp_b', trashedAt: DateTime.now().toIso8601String());

    await service.restoreExpense('exp_b');

    final row = await _row('exp_b');
    expect(row!['is_trashed'], 0);
    expect(row['trashed_at'], isNull);
  });

  test('runAutoPurgeTask deletes only items trashed over 30 days ago',
      () async {
    final now = DateTime.now();
    await _insertExpense('exp_old',
        trashedAt: now.subtract(const Duration(days: 31)).toIso8601String());
    await _insertExpense('exp_recent',
        trashedAt: now.subtract(const Duration(days: 5)).toIso8601String());
    await _insertExpense('exp_active');

    await service.runAutoPurgeTask();

    expect(await _row('exp_old'), isNull);
    expect(await _row('exp_recent'), isNotNull);
    expect(await _row('exp_active'), isNotNull);
  });
}
