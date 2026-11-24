import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/algorithms/debt_simplifier.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../domain/models/group_expense_item.dart';

const String _selfId = 'user_self';

int _asInt(Object? v) => (v as num?)?.toInt() ?? 0;

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '??';
  if (parts.length == 1) {
    final w = parts.first;
    return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

// ─────────────────────────── Models ───────────────────────────

class GroupSummary {
  final String id;
  final String name;
  final String? icon;
  final bool cloudSynced;
  final int memberCount;
  final int netBalance;
  final int simplifiedPayments;
  final String membersLine;
  final String initials;

  const GroupSummary({
    required this.id,
    required this.name,
    this.icon,
    required this.cloudSynced,
    required this.memberCount,
    this.netBalance = 0,
    this.simplifiedPayments = 0,
    this.membersLine = '',
    this.initials = '',
  });
}

class GroupMemberInput {
  final String contactId;
  final String? nickname;
  final String? name;
  final String? initials;
  final String? colorHex;
  final bool isShadow;

  const GroupMemberInput({
    required this.contactId,
    this.nickname,
    this.name,
    this.initials,
    this.colorHex,
    this.isShadow = false,
  });
}

class GroupDetailState {
  final String groupId;
  final String groupName;
  final String membersLine;
  final int yourNetBalance; // e.g. -1850 (You owe Rs 1,850)
  final String activeTab; // 'Expenses', 'Balances', 'Members'
  final int simplifiedPaymentCount;
  final List<GroupExpenseItem> expenses;
  final List<GroupMemberDisplay> members;

  const GroupDetailState({
    required this.groupId,
    required this.groupName,
    required this.membersLine,
    required this.yourNetBalance,
    required this.activeTab,
    required this.simplifiedPaymentCount,
    required this.expenses,
    required this.members,
  });

  GroupDetailState copyWith({
    String? activeTab,
    List<GroupExpenseItem>? expenses,
    List<GroupMemberDisplay>? members,
    int? yourNetBalance,
    String? groupName,
    String? membersLine,
    int? simplifiedPaymentCount,
  }) {
    return GroupDetailState(
      groupId: groupId,
      groupName: groupName ?? this.groupName,
      membersLine: membersLine ?? this.membersLine,
      yourNetBalance: yourNetBalance ?? this.yourNetBalance,
      activeTab: activeTab ?? this.activeTab,
      simplifiedPaymentCount: simplifiedPaymentCount ?? this.simplifiedPaymentCount,
      expenses: expenses ?? this.expenses,
      members: members ?? this.members,
    );
  }
}

// ─────────────────────────── Providers ───────────────────────────

final groupRepositoryProvider = Provider<GroupRepository>((ref) => GroupRepository(ref));

final groupsListProvider = FutureProvider.autoDispose<List<GroupSummary>>((ref) {
  return ref.watch(groupRepositoryProvider).listGroups();
});

final groupDetailProvider = StateNotifierProvider.family<GroupDetailNotifier, GroupDetailState, String>(
  (ref, groupId) => GroupDetailNotifier(groupId, ref),
);

// ─────────────────────────── Repository ───────────────────────────

class GroupRepository {
  static final GroupRepository instance = GroupRepository._();
  final Ref? _ref;

  GroupRepository._([this._ref]);
  factory GroupRepository([Ref? ref]) => ref == null ? instance : GroupRepository._(ref);

  Future<List<GroupSummary>> listGroups() async {
    const fallback = [
      GroupSummary(
        id: 'hostel_gang',
        name: 'Hostel Gang',
        cloudSynced: false,
        memberCount: 4,
        netBalance: -1850,
        simplifiedPayments: 2,
        membersLine: 'You, Sheeda, Kaptaan, Hamza',
        initials: 'HG',
      ),
      GroupSummary(
        id: 'trip_murree',
        name: 'Trip to Murree',
        cloudSynced: false,
        memberCount: 3,
        netBalance: 3200,
        simplifiedPayments: 1,
        membersLine: 'You, Bilal, Farhan',
        initials: 'TM',
      ),
    ];

    try {
      final db = await AppDatabase.instance.database;
      final groupRows = await db.rawQuery('''
        SELECT g.id, g.name, g.icon, g.cloud_synced,
          (SELECT COUNT(*) FROM "${DbTables.groupMembers}" gm WHERE gm.group_id = g.id) AS member_count
        FROM "${DbTables.groups}" g
        ORDER BY g.created_at DESC
      ''');

      if (groupRows.isEmpty) {
        return fallback;
      }

      final list = <GroupSummary>[];
      for (final r in groupRows) {
        final gid = r['id'].toString();
        final name = (r['name'] as String?) ?? '';
        final memberCount = _asInt(r['member_count']);
        final cloudSynced = _asInt(r['cloud_synced']) == 1;

        // Get member names for membersLine
        final mRows = await db.rawQuery('''
          SELECT gm.contact_id, gm.nickname, c.name AS contact_name
          FROM "${DbTables.groupMembers}" gm
          LEFT JOIN "${DbTables.contacts}" c ON c.id = gm.contact_id
          WHERE gm.group_id = ?
          ORDER BY gm.joined_at ASC
        ''', [gid]);

        final memberNames = mRows.map((m) {
          if (m['contact_id'] == _selfId) return 'You';
          final nick = (m['nickname'] as String?)?.trim();
          if (nick != null && nick.isNotEmpty) return nick;
          final cname = (m['contact_name'] as String?)?.trim();
          return (cname != null && cname.isNotEmpty) ? cname : 'Member';
        }).toList();
        final membersLine = memberNames.join(', ');

        // Balances from unpaid splits
        final splitRows = await db.rawQuery('''
          SELECT e.payer_id, es.contact_id, es.share_amount
          FROM "${DbTables.expenseSplits}" es
          INNER JOIN "${DbTables.expenses}" e ON e.id = es.expense_id
          WHERE e.group_id = ?
            AND e.is_trashed = 0
            AND es.is_paid = 0
            AND es.contact_id != e.payer_id
        ''', [gid]);

        final net = <String, int>{for (final m in mRows) (m['contact_id'] as String): 0};
        for (final s in splitRows) {
          final payer = s['payer_id'] as String;
          final debtor = s['contact_id'] as String;
          final share = _asInt(s['share_amount']);
          net[payer] = (net[payer] ?? 0) + share;
          net[debtor] = (net[debtor] ?? 0) - share;
        }

        final yourNetBalance = net[_selfId] ?? 0;
        final simplifiedTransfers = DebtSimplifier.simplifyNetBalances(net);

        list.add(GroupSummary(
          id: gid,
          name: name,
          icon: r['icon'] as String?,
          cloudSynced: cloudSynced,
          memberCount: memberCount,
          netBalance: yourNetBalance,
          simplifiedPayments: simplifiedTransfers.length,
          membersLine: membersLine,
          initials: _initials(name),
        ));
      }
      return list;
    } catch (_) {
      return fallback;
    }
  }

  Future<String> createGroup({
    required String name,
    required String icon,
    required List<GroupMemberInput> members,
    required String myNick,
  }) async {
    final groupName = name.trim();
    if (groupName.isEmpty) throw ArgumentError('Group name is required');

    final db = await AppDatabase.instance.database;
    final groupId = 'grp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(DbTables.groups, {
        'id': groupId,
        'name': groupName,
        'icon': icon,
        'created_at': now,
        'cloud_synced': 0,
      });

      // Ensure self contact exists
      await txn.rawInsert(
        'INSERT OR IGNORE INTO "${DbTables.contacts}" (id, name, avatar_initials, avatar_color, is_shadow, created_at) '
        'VALUES (?, ?, ?, ?, 0, ?)',
        [_selfId, 'You', 'ME', '#09121F', now],
      );

      // Add self to group_members
      await txn.insert(DbTables.groupMembers, {
        'id': '${groupId}_m0',
        'group_id': groupId,
        'contact_id': _selfId,
        'nickname': myNick.trim().isEmpty ? 'You' : myNick.trim(),
        'joined_at': now,
      });

      var i = 0;
      for (final m in members) {
        if (m.contactId == _selfId) continue;
        i++;

        // Ensure contact exists
        await txn.rawInsert(
          'INSERT OR IGNORE INTO "${DbTables.contacts}" (id, name, avatar_initials, avatar_color, is_shadow, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            m.contactId,
            m.name ?? m.nickname ?? 'Member $i',
            m.initials ?? _initials(m.name ?? 'M'),
            m.colorHex ?? '#09121F',
            m.isShadow ? 1 : 0,
            now,
          ],
        );

        await txn.insert(DbTables.groupMembers, {
          'id': '${groupId}_m$i',
          'group_id': groupId,
          'contact_id': m.contactId,
          'nickname': (m.nickname?.trim().isNotEmpty == true) ? m.nickname!.trim() : (m.name ?? 'Member $i'),
          'joined_at': now,
        });
      }
    });

    // Cloud step (best effort if signed in)
    try {
      final uid = await SyncService.instance.storedUserId();
      if (uid != null) {
        await Supabase.instance.client.rpc('create_group', params: {
          'gid': groupId,
          'gname': groupName,
          'gicon': icon,
          'nick': myNick,
        }).timeout(const Duration(seconds: 10));

        await db.update(
          DbTables.groups,
          {'cloud_synced': 1},
          where: 'id = ?',
          whereArgs: [groupId],
        );
      }
    } catch (_) {
      // Cloud sync can be retried later
    }

    _ref?.invalidate(groupsListProvider);
    _ref?.invalidate(dashboardSummaryProvider);
    return groupId;
  }
}

// ─────────────────────────── StateNotifier ───────────────────────────

class GroupDetailNotifier extends StateNotifier<GroupDetailState> {
  final String groupId;
  final Ref? _ref;

  GroupDetailNotifier(this.groupId, [this._ref]) : super(_initialState(groupId)) {
    _loadFromDb();
  }

  static GroupDetailState _initialState(String groupId) {
    if (groupId == 'hostel_gang') {
      return const GroupDetailState(
        groupId: 'hostel_gang',
        groupName: 'Hostel Gang',
        membersLine: 'You, Sheeda, Kaptaan, Hamza',
        yourNetBalance: -1850,
        activeTab: 'Expenses',
        simplifiedPaymentCount: 2,
        expenses: [
          GroupExpenseItem(
            id: '1',
            title: 'Dinner',
            categoryTag: 'FD',
            subtitle: 'Paid by Sheeda, Equal',
            yourShare: -900,
          ),
          GroupExpenseItem(
            id: '2',
            title: 'Hostel dues',
            categoryTag: 'HS',
            subtitle: 'Paid by Kaptaan, Exact',
            yourShare: -700,
          ),
          GroupExpenseItem(
            id: '3',
            title: 'Printouts',
            categoryTag: 'PR',
            subtitle: 'Paid by Hamza, Percent',
            yourShare: -250,
          ),
        ],
        members: [
          GroupMemberDisplay(
            id: 'user_self',
            name: 'You',
            nickname: 'Ali',
            initials: 'AL',
            netBalance: -1850,
          ),
          GroupMemberDisplay(
            id: 'sheeda',
            name: 'Sheeda',
            nickname: 'Sheeda',
            initials: 'SH',
            netBalance: 1200,
          ),
          GroupMemberDisplay(
            id: 'kaptaan',
            name: 'Kaptaan',
            nickname: 'Kaptaan',
            initials: 'KP',
            netBalance: 700,
          ),
          GroupMemberDisplay(
            id: 'hamza',
            name: 'Hamza',
            nickname: 'Hamza',
            initials: 'HM',
            netBalance: -50,
            isShadow: true,
          ),
        ],
      );
    }
    return GroupDetailState(
      groupId: groupId,
      groupName: '',
      membersLine: '',
      yourNetBalance: 0,
      activeTab: 'Expenses',
      simplifiedPaymentCount: 0,
      expenses: const [],
      members: const [],
    );
  }

  Future<void> reload() async => _loadFromDb();

  Future<void> _loadFromDb() async {
    try {
      final db = await AppDatabase.instance.database;
      final gRows = await db.query(
        DbTables.groups,
        where: 'id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (gRows.isEmpty) return; // Retain fallback / mock state

      final g = gRows.first;
      final groupName = (g['name'] as String?) ?? '';

      // Members
      final memberRows = await db.rawQuery('''
        SELECT gm.contact_id, gm.nickname, c.name, c.avatar_initials, c.is_shadow
        FROM "${DbTables.groupMembers}" gm
        LEFT JOIN "${DbTables.contacts}" c ON c.id = gm.contact_id
        WHERE gm.group_id = ?
        ORDER BY gm.joined_at ASC
      ''', [groupId]);

      final memberMap = <String, String>{};
      final memberDisplays = <GroupMemberDisplay>[];
      final memberNamesLine = <String>[];

      for (final r in memberRows) {
        final cid = r['contact_id'] as String;
        final nick = (r['nickname'] as String?)?.trim();
        final cname = (r['name'] as String?)?.trim();
        final displayName = (nick != null && nick.isNotEmpty)
            ? nick
            : ((cname != null && cname.isNotEmpty) ? cname : (cid == _selfId ? 'You' : cid));
        memberMap[cid] = displayName;
        memberNamesLine.add(cid == _selfId ? 'You' : displayName);
      }

      // Expenses
      final expenseRows = await db.rawQuery('''
        SELECT e.id, e.title, e.category, e.total_amount, e.payer_id, e.split_mode,
               e.is_settled, e.created_at,
               (SELECT share_amount FROM "${DbTables.expenseSplits}" es WHERE es.expense_id = e.id AND es.contact_id = '$_selfId' LIMIT 1) AS my_share,
               (SELECT is_paid FROM "${DbTables.expenseSplits}" es WHERE es.expense_id = e.id AND es.contact_id = '$_selfId' LIMIT 1) AS my_paid
        FROM "${DbTables.expenses}" e
        WHERE e.group_id = ? AND e.is_trashed = 0
        ORDER BY e.created_at DESC
      ''', [groupId]);

      final expensesList = <GroupExpenseItem>[];
      for (final r in expenseRows) {
        final eid = r['id'].toString();
        final title = (r['title'] as String?) ?? 'Expense';
        final category = (r['category'] as String?) ?? 'Other';
        final payerId = r['payer_id'] as String;
        final isSettled = _asInt(r['is_settled']) == 1;
        final payerName = payerId == _selfId ? 'You' : (memberMap[payerId] ?? payerId);
        final splitMode = (r['split_mode'] as String?) ?? 'equal';
        final subtitle = 'Paid by $payerName, ${splitMode[0].toUpperCase()}${splitMode.substring(1)}';

        int yourShare = 0;
        if (payerId == _selfId) {
          final total = _asInt(r['total_amount']);
          final myShare = _asInt(r['my_share']);
          yourShare = total - myShare;
        } else {
          final myShare = _asInt(r['my_share']);
          yourShare = -myShare;
        }

        final tag = category.length >= 2 ? category.substring(0, 2).toUpperCase() : 'OT';

        expensesList.add(GroupExpenseItem(
          id: eid,
          title: title,
          categoryTag: tag,
          subtitle: subtitle,
          yourShare: yourShare,
          isSettled: isSettled,
        ));
      }

      // Net balances from unpaid splits
      final splitRows = await db.rawQuery('''
        SELECT e.payer_id, es.contact_id, es.share_amount
        FROM "${DbTables.expenseSplits}" es
        INNER JOIN "${DbTables.expenses}" e ON e.id = es.expense_id
        WHERE e.group_id = ?
          AND e.is_trashed = 0
          AND es.is_paid = 0
          AND es.contact_id != e.payer_id
      ''', [groupId]);

      final net = <String, int>{for (final cid in memberMap.keys) cid: 0};
      for (final s in splitRows) {
        final payer = s['payer_id'] as String;
        final debtor = s['contact_id'] as String;
        final share = _asInt(s['share_amount']);
        net[payer] = (net[payer] ?? 0) + share;
        net[debtor] = (net[debtor] ?? 0) - share;
      }

      for (final r in memberRows) {
        final cid = r['contact_id'] as String;
        final nick = (r['nickname'] as String?) ?? '';
        final cname = (r['name'] as String?) ?? (cid == _selfId ? 'You' : cid);
        final initials = (r['avatar_initials'] as String?) ?? _initials(cname);
        final isShadow = _asInt(r['is_shadow']) == 1;

        memberDisplays.add(GroupMemberDisplay(
          id: cid,
          name: cname,
          nickname: nick.isNotEmpty ? nick : cname,
          initials: initials,
          netBalance: net[cid] ?? 0,
          isShadow: isShadow,
        ));
      }

      final yourNet = net[_selfId] ?? 0;
      final simplified = DebtSimplifier.simplifyNetBalances(net);

      state = state.copyWith(
        groupName: groupName,
        membersLine: memberNamesLine.join(', '),
        yourNetBalance: yourNet,
        simplifiedPaymentCount: simplified.length,
        expenses: expensesList,
        members: memberDisplays,
      );
    } catch (_) {
      // Keep state on error
    }
  }

  void setTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  Future<void> clearAllDues() async {
    try {
      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        // Mark your unpaid splits for this group as paid
        await txn.rawUpdate('''
          UPDATE "${DbTables.expenseSplits}"
          SET is_paid = 1
          WHERE contact_id = ?
            AND expense_id IN (
              SELECT id FROM "${DbTables.expenses}" WHERE group_id = ?
            )
        ''', [_selfId, groupId]);

        // Settle expenses that have no unpaid splits left
        await txn.rawUpdate('''
          UPDATE "${DbTables.expenses}"
          SET is_settled = 1
          WHERE group_id = ?
            AND NOT EXISTS (
              SELECT 1 FROM "${DbTables.expenseSplits}" es
              WHERE es.expense_id = "${DbTables.expenses}".id AND es.is_paid = 0
            )
        ''', [groupId]);
      });

      _ref?.invalidate(dashboardSummaryProvider);
      await _loadFromDb();
    } catch (_) {
      state = state.copyWith(
        yourNetBalance: 0,
        expenses: state.expenses.map((e) => GroupExpenseItem(
          id: e.id,
          title: e.title,
          categoryTag: e.categoryTag,
          subtitle: e.subtitle,
          yourShare: 0,
          isSettled: true,
        )).toList(),
      );
    }
  }
}
