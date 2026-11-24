import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../domain/models/khata_timeline_entry.dart';

const String _selfId = 'user_self';

class KhataState {
  final String peerName;
  final String peerInitials;
  final String? peerPhone;
  final String activeTab; // 'Open' or 'Cleared'
  final List<KhataTimelineEntry> entries;
  final bool isLoading;

  const KhataState({
    required this.peerName,
    required this.peerInitials,
    this.peerPhone,
    required this.activeTab,
    required this.entries,
    this.isLoading = false,
  });

  /// Net standing: positive means peer owes you (+), negative means you owe peer (-)
  int get netStanding {
    int total = 0;
    for (final e in entries) {
      if (e.isSettled) continue;
      if (e.isLent) {
        total += e.amount;
      } else {
        total -= e.amount;
      }
    }
    return total;
  }

  List<KhataTimelineEntry> get filteredEntries {
    if (activeTab == 'Cleared') {
      return entries.where((e) => e.isSettled).toList();
    }
    return entries.where((e) => !e.isSettled).toList();
  }

  KhataState copyWith({
    String? peerName,
    String? peerInitials,
    String? peerPhone,
    String? activeTab,
    List<KhataTimelineEntry>? entries,
    bool? isLoading,
  }) {
    return KhataState(
      peerName: peerName ?? this.peerName,
      peerInitials: peerInitials ?? this.peerInitials,
      peerPhone: peerPhone ?? this.peerPhone,
      activeTab: activeTab ?? this.activeTab,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final khataDetailProvider = StateNotifierProvider.family<KhataDetailNotifier, KhataState, String>(
  (ref, peerId) => KhataDetailNotifier(peerId, ref),
);

class KhataDetailNotifier extends StateNotifier<KhataState> {
  final String peerId;
  final Ref? _ref;

  KhataDetailNotifier(this.peerId, [this._ref])
      : super(
          KhataState(
            peerName: _defaultName(peerId),
            peerInitials: _initialsFor(_defaultName(peerId)),
            peerPhone: null,
            activeTab: 'Open',
            entries: const [],
            isLoading: true,
          ),
        ) {
    loadFromDb();
  }

  static String _defaultName(String id) {
    if (id == 'sheeda') return 'Sheeda';
    if (id == 'kaptaan') return 'Kaptaan';
    if (id == 'hamza') return 'Hamza';
    return id.isEmpty ? 'Friend' : id[0].toUpperCase() + id.substring(1);
  }

  static String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    if (list.length == 1) {
      final w = list.first;
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (list.first[0] + list[1][0]).toUpperCase();
  }

  static int _asInt(Object? v) => (v as num?)?.toInt() ?? 0;

  Future<void> loadFromDb() async {
    try {
      final db = await AppDatabase.instance.database;
      const expenses = '"${DbTables.expenses}"';
      const splits = '"${DbTables.expenseSplits}"';
      const contacts = '"${DbTables.contacts}"';

      // 1. Fetch contact info if exists
      final contactRows = await db.rawQuery(
        'SELECT name, phone, avatar_initials FROM $contacts WHERE id = ? LIMIT 1',
        [peerId],
      );

      String name = state.peerName;
      String? phone = state.peerPhone;
      String initials = state.peerInitials;

      if (contactRows.isNotEmpty) {
        final c = contactRows.first;
        final cName = c['name'] as String?;
        if (cName != null && cName.trim().isNotEmpty) {
          name = cName;
          initials = (c['avatar_initials'] as String?) ?? _initialsFor(name);
        }
        phone = c['phone'] as String?;
      }

      // 2. Fetch 1-on-1 expenses (group_id IS NULL)
      final rows = await db.rawQuery('''
        SELECT
          e.id,
          e.title,
          e.category,
          e.payer_id,
          e.is_settled,
          e.created_at,
          e.receipt_image_path,
          es.share_amount,
          es.is_paid
        FROM $expenses e
        INNER JOIN $splits es ON es.expense_id = e.id
        WHERE e.group_id IS NULL
          AND e.is_trashed = 0
          AND (
            (e.payer_id = ? AND es.contact_id = ?)
            OR (e.payer_id = ? AND es.contact_id = ?)
          )
        ORDER BY e.created_at DESC, e.id DESC
      ''', [_selfId, peerId, peerId, _selfId]);

      final entries = rows.map((r) {
        final payerId = r['payer_id'] as String?;
        final isPaid = _asInt(r['is_paid']) == 1;
        final isSettled = _asInt(r['is_settled']) == 1 || isPaid;

        return KhataTimelineEntry(
          id: r['id'].toString(),
          title: (r['title'] as String?) ?? '',
          category: (r['category'] as String?) ?? 'Other',
          date: DateTime.tryParse((r['created_at'] as String?) ?? '') ?? DateTime.now(),
          amount: _asInt(r['share_amount']),
          isLent: payerId == _selfId,
          isSettled: isSettled,
          receiptPath: r['receipt_image_path'] as String?,
        );
      }).toList();

      state = state.copyWith(
        peerName: name,
        peerPhone: phone,
        peerInitials: initials,
        entries: entries,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  Future<void> addEntry({
    required int amount,
    required String title,
    required String category,
    required bool isLent,
    String? receiptPath,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || amount <= 0) return;

    try {
      final db = await AppDatabase.instance.database;
      final id = 'exp_${DateTime.now().microsecondsSinceEpoch}';
      final payer = isLent ? _selfId : peerId;
      final debtor = isLent ? peerId : _selfId;
      final now = DateTime.now().toIso8601String();

      // Ensure peer contact row exists in SQLite contacts table
      await db.insert(
        DbTables.contacts,
        {
          'id': peerId,
          'name': state.peerName,
          'phone': state.peerPhone ?? '',
          'raast_id': '',
          'avatar_initials': state.peerInitials,
          'is_shadow': 0,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await db.transaction((txn) async {
        await txn.insert(DbTables.expenses, {
          'id': id,
          'group_id': null,
          'payer_id': payer,
          'title': cleanTitle,
          'category': category,
          'total_amount': amount,
          'split_mode': 'equal',
          'payment_method': 'Cash',
          'receipt_image_path': receiptPath,
          'is_settled': 0,
          'is_trashed': 0,
          'created_at': now,
        });

        await txn.insert(DbTables.expenseSplits, {
          'id': '${id}_split',
          'expense_id': id,
          'contact_id': debtor,
          'share_amount': amount,
          'is_paid': 0,
        });
      });

      await loadFromDb();
      _ref?.invalidate(dashboardSummaryProvider);
    } catch (_) {}
  }

  Future<void> deleteEntry(String id) async {
    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();
      await db.update(
        DbTables.expenses,
        {
          'is_trashed': 1,
          'trashed_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await loadFromDb();
      _ref?.invalidate(dashboardSummaryProvider);
    } catch (_) {}
  }

  Future<void> settleAll() async {
    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();
      final openIds = state.entries.where((e) => !e.isSettled).map((e) => e.id).toList();
      if (openIds.isEmpty) return;

      final placeholders = List.filled(openIds.length, '?').join(',');

      await db.transaction((txn) async {
        await txn.rawUpdate('''
          UPDATE "${DbTables.expenses}"
          SET is_settled = 1, settled_at = ?
          WHERE id IN ($placeholders)
        ''', [now, ...openIds]);

        await txn.rawUpdate('''
          UPDATE "${DbTables.expenseSplits}"
          SET is_paid = 1
          WHERE expense_id IN ($placeholders)
        ''', openIds);
      });

      await loadFromDb();
      _ref?.invalidate(dashboardSummaryProvider);
    } catch (_) {}
  }
}
