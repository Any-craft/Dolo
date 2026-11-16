import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';
import '../../domain/models/dashboard_summary.dart';

const String _selfId = 'user_self';
const String _fallbackUserName = 'Ali';

final activeFilterProvider = StateProvider<String>((ref) => 'All');

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final db = await AppDatabase.instance.database;

  // Table names are quoted because "groups" is a reserved word in newer SQLite versions.
  const expenses = '"${DbTables.expenses}"';
  const splits = '"${DbTables.expenseSplits}"';
  const settlements = '"${DbTables.settlements}"';
  const contacts = '"${DbTables.contacts}"';
  const groups = '"${DbTables.groups}"';

  int asInt(Object? v) => (v as num?)?.toInt() ?? 0;

  // 1. Total owed to the user (you paid, others haven't settled)
  final owedRows = await db.rawQuery('''
    SELECT SUM(es.share_amount) AS total
    FROM $splits es
    INNER JOIN $expenses e ON e.id = es.expense_id
    WHERE e.payer_id = ?
      AND es.contact_id != ?
      AND es.is_paid = 0
      AND e.is_trashed = 0
  ''', [_selfId, _selfId]);
  final totalOwed = asInt(owedRows.first['total']);

  // 2. Total the user owes (others paid, your share is unpaid)
  final oweRows = await db.rawQuery('''
    SELECT SUM(es.share_amount) AS total
    FROM $splits es
    INNER JOIN $expenses e ON e.id = es.expense_id
    WHERE e.payer_id != ?
      AND es.contact_id = ?
      AND es.is_paid = 0
      AND e.is_trashed = 0
  ''', [_selfId, _selfId]);
  final totalOwe = asInt(oweRows.first['total']);

  // 3. Settled count from settlements table
  final settledRows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM $settlements');
  final settledCount = asInt(settledRows.first['cnt']);

  // 4. User name from contacts table where id = 'user_self'
  final userRows = await db.rawQuery(
    'SELECT name FROM $contacts WHERE id = ? LIMIT 1',
    [_selfId],
  );
  final fetchedName = userRows.isNotEmpty ? (userRows.first['name'] as String?) : null;
  final userName = (fetchedName == null || fetchedName.trim().isEmpty)
      ? _fallbackUserName
      : fetchedName;

  // 5. Feed: latest 20 non-trashed expenses
  final feedRows = await db.rawQuery('''
    SELECT
      e.id,
      e.title,
      e.group_id,
      e.payer_id,
      e.is_settled,
      e.receipt_image_path,
      g.name AS group_name,
      c.name AS payer_name,
      c.avatar_initials AS payer_initials,
      COALESCE((
        SELECT SUM(es.share_amount) FROM $splits es
        WHERE es.expense_id = e.id
          AND es.contact_id != ?
          AND es.is_paid = 0
      ), 0) AS owed_to_me,
      COALESCE((
        SELECT SUM(es.share_amount) FROM $splits es
        WHERE es.expense_id = e.id
          AND es.contact_id = ?
          AND es.is_paid = 0
      ), 0) AS i_owe
    FROM $expenses e
    LEFT JOIN $groups g ON g.id = e.group_id
    LEFT JOIN $contacts c ON c.id = e.payer_id
    WHERE e.is_trashed = 0
    ORDER BY e.created_at DESC, e.id DESC
    LIMIT 20
  ''', [_selfId, _selfId]);

  final feedItems = feedRows.map((row) {
    final isSettled = asInt(row['is_settled']) == 1;
    final groupId = row['group_id'] as String?;
    final groupName = row['group_name'] as String?;
    final payerId = row['payer_id'] as String?;
    final payerName = row['payer_name'] as String?;
    final title = (row['title'] as String?) ?? '';
    final paidByMe = payerId == _selfId;

    final int? amount;
    if (isSettled) {
      amount = null;
    } else if (paidByMe) {
      amount = asInt(row['owed_to_me']);
    } else {
      amount = -asInt(row['i_owe']);
    }

    final FeedItemType type = groupId != null
        ? FeedItemType.group
        : (isSettled ? FeedItemType.settled : FeedItemType.friend);

    final payerLabel = paidByMe ? 'You' : (payerName ?? 'Someone');
    final subtitle = groupName != null
        ? '$payerLabel paid • $groupName'
        : '$payerLabel paid';

    final initials = _initialsFor(
      groupName ?? (row['payer_initials'] as String?) ?? payerName ?? title,
    );

    return DashboardFeedItem(
      id: row['id'].toString(),
      title: title,
      subtitle: subtitle,
      initials: initials,
      amount: amount,
      isSettled: isSettled,
      type: type,
      receiptPath: row['receipt_image_path'] as String?,
    );
  }).toList();

  final netStanding = totalOwed - totalOwe;

  return DashboardSummary(
    userName: userName,
    netStanding: netStanding,
    totalOwed: totalOwed,
    totalOwe: totalOwe,
    settledCount: settledCount,
    feedItems: feedItems,
  );
});

final filteredFeedProvider = Provider<List<DashboardFeedItem>>((ref) {
  final summaryAsync = ref.watch(dashboardSummaryProvider);
  final activeFilter = ref.watch(activeFilterProvider);

  return summaryAsync.maybeWhen(
    data: (summary) {
      if (activeFilter == 'All') return summary.feedItems;
      if (activeFilter == 'Friends') {
        return summary.feedItems.where((i) => i.type == FeedItemType.friend).toList();
      }
      if (activeFilter == 'Groups') {
        return summary.feedItems.where((i) => i.type == FeedItemType.group).toList();
      }
      if (activeFilter == 'Pending') {
        return summary.feedItems.where((i) => !i.isSettled).toList();
      }
      return summary.feedItems;
    },
    orElse: () => const [],
  );
});

String _initialsFor(String source) {
  final parts = source.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final list = parts.toList();
  if (list.length == 1) {
    final w = list.first;
    return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (list.first[0] + list[1][0]).toUpperCase();
}
