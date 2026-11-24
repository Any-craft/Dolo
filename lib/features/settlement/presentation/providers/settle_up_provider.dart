import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/algorithms/debt_offset_calculator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../../khata_1on1/presentation/providers/khata_detail_provider.dart';
import '../../../settlement/presentation/screens/spends_screen.dart';
import '../../domain/models/settlement_bill.dart';

enum PaymentMethod { cash, online }

class SettleUpState {
  final String peerId;
  final String peerName;
  final String? raastId;
  final List<SettlementBill> bills;
  final PaymentMethod paymentMethod;
  final String? receiptImagePath;
  final int counterDebtRs;
  final bool applyOffset;
  final bool isSubmitting;
  final bool isLoading;

  const SettleUpState({
    required this.peerId,
    required this.peerName,
    this.raastId,
    required this.bills,
    this.paymentMethod = PaymentMethod.online,
    this.receiptImagePath,
    this.counterDebtRs = 0,
    this.applyOffset = true,
    this.isSubmitting = false,
    this.isLoading = false,
  });

  int get totalSelectedRs => bills
      .where((b) => b.isSelected)
      .fold(0, (sum, b) => sum + b.amountRs);

  int get counterDebtOffset {
    if (totalSelectedRs <= 0 || counterDebtRs <= 0) return 0;
    final res = DebtOffsetCalculator.calculateOffset(
      grossDue: totalSelectedRs,
      peerOwesYou: counterDebtRs,
      applyOffset: applyOffset,
      peerName: peerName,
    );
    return res.offsetCredit;
  }

  int get netPayableRs {
    if (totalSelectedRs <= 0) return 0;
    final res = DebtOffsetCalculator.calculateOffset(
      grossDue: totalSelectedRs,
      peerOwesYou: counterDebtRs,
      applyOffset: applyOffset,
      peerName: peerName,
    );
    return res.netPayable;
  }

  SettleUpState copyWith({
    String? peerId,
    String? peerName,
    String? raastId,
    List<SettlementBill>? bills,
    PaymentMethod? paymentMethod,
    String? receiptImagePath,
    int? counterDebtRs,
    bool? applyOffset,
    bool? isSubmitting,
    bool? isLoading,
  }) =>
      SettleUpState(
        peerId: peerId ?? this.peerId,
        peerName: peerName ?? this.peerName,
        raastId: raastId ?? this.raastId,
        bills: bills ?? this.bills,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        receiptImagePath: receiptImagePath ?? this.receiptImagePath,
        counterDebtRs: counterDebtRs ?? this.counterDebtRs,
        applyOffset: applyOffset ?? this.applyOffset,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isLoading: isLoading ?? this.isLoading,
      );
}

class SettleUpNotifier extends StateNotifier<SettleUpState> {
  final String peerId;
  final String peerName;
  final Ref? _ref;

  SettleUpNotifier(this.peerId, this.peerName, [this._ref])
      : super(SettleUpState(
          peerId: peerId,
          peerName: peerName,
          bills: SettlementBill.mock(peerId, peerName),
        )) {
    _loadFromDb();
  }

  Future<void> reload() async => _loadFromDb();

  Future<void> _loadFromDb() async {
    try {
      final db = await AppDatabase.instance.database;

      // 1. What you owe the peer (unpaid splits where peer is payer and user_self is debtor)
      final billRows = await db.rawQuery('''
        SELECT es.id, e.id AS expense_id, e.title, e.created_at, es.share_amount
        FROM "${DbTables.expenseSplits}" es
        INNER JOIN "${DbTables.expenses}" e ON e.id = es.expense_id
        WHERE e.payer_id = ?
          AND es.contact_id = 'user_self'
          AND es.is_paid = 0
          AND e.is_trashed = 0
        ORDER BY e.created_at DESC, es.id ASC
      ''', [peerId]);

      // 2. What peer owes you (counter-debt)
      final debtRows = await db.rawQuery('''
        SELECT SUM(es.share_amount) AS peer_debt
        FROM "${DbTables.expenseSplits}" es
        INNER JOIN "${DbTables.expenses}" e ON e.id = es.expense_id
        WHERE e.payer_id = 'user_self'
          AND es.contact_id = ?
          AND es.is_paid = 0
          AND e.is_trashed = 0
      ''', [peerId]);

      final counterDebt = (debtRows.first['peer_debt'] as num?)?.toInt() ?? 0;

      // 3. Contact details for Raast ID / phone
      final contactRows = await db.query(
        DbTables.contacts,
        columns: ['name', 'phone', 'raast_id'],
        where: 'id = ?',
        whereArgs: [peerId],
        limit: 1,
      );

      String? realName;
      String? raastId;
      if (contactRows.isNotEmpty) {
        final c = contactRows.first;
        final cname = (c['name'] as String?)?.trim();
        if (cname != null && cname.isNotEmpty) realName = cname;

        final craast = (c['raast_id'] as String?)?.trim();
        final cphone = (c['phone'] as String?)?.trim();
        raastId = (craast != null && craast.isNotEmpty)
            ? craast
            : ((cphone != null && cphone.isNotEmpty) ? cphone : null);
      }

      if (billRows.isNotEmpty) {
        final bills = billRows.map((r) {
          final title = (r['title'] as String?)?.trim();
          return SettlementBill(
            id: r['id'].toString(),
            description: (title != null && title.isNotEmpty) ? title : 'Expense',
            amountRs: (r['share_amount'] as num?)?.toInt() ?? 0,
            peerId: peerId,
            peerName: realName ?? peerName,
            date: DateTime.tryParse((r['created_at'] as String?) ?? '') ?? DateTime.now(),
            isSelected: true,
          );
        }).toList();

        state = state.copyWith(
          peerName: realName ?? peerName,
          raastId: raastId,
          bills: bills,
          counterDebtRs: counterDebt,
        );
      } else {
        // Retain default bills or update peer name / counterDebt
        state = state.copyWith(
          peerName: realName ?? peerName,
          raastId: raastId,
          counterDebtRs: counterDebt,
        );
      }
    } catch (_) {
      // Maintain state on error
    }
  }

  void toggleBill(String billId) {
    state = state.copyWith(
      bills: state.bills
          .map((b) => b.id == billId ? b.copyWith(isSelected: !b.isSelected) : b)
          .toList(),
    );
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setReceiptImage(String path) {
    state = state.copyWith(receiptImagePath: path);
  }

  void setApplyOffset(bool apply) {
    state = state.copyWith(applyOffset: apply);
  }

  /// Records the settlement in SQLite, marks selected splits as paid,
  /// updates expense settlement status, and reconciles counter-debt.
  Future<bool> confirmSettlement() async {
    if (state.isSubmitting) return false;
    final selected = state.bills.where((b) => b.isSelected).toList();
    if (selected.isEmpty) return false;

    state = state.copyWith(isSubmitting: true);

    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now();
      final netPayable = state.netPayableRs;
      final offsetCredit = state.counterDebtOffset;
      final method = state.paymentMethod == PaymentMethod.cash ? 'Cash' : 'Online Transfer';
      final selectedIds = selected.map((b) => b.id).toList();

      await db.transaction((txn) async {
        // 1. Insert settlement entry
        await txn.insert(DbTables.settlements, {
          'id': 'stl_${now.microsecondsSinceEpoch}',
          'payer_id': 'user_self',
          'payee_id': peerId,
          'total_paid': netPayable,
          'payment_method': method,
          'offset_amount': offsetCredit,
          'screenshot_path': state.receiptImagePath,
          'settled_at': now.toIso8601String(),
        });

        // 2. Mark selected splits as paid
        final marks = List.filled(selectedIds.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE "${DbTables.expenseSplits}" SET is_paid = 1 WHERE id IN ($marks)',
          selectedIds,
        );

        // 3. Settle expenses that have no unpaid splits remaining
        await txn.rawUpdate('''
          UPDATE "${DbTables.expenses}" SET is_settled = 1
          WHERE id IN (
            SELECT DISTINCT expense_id FROM "${DbTables.expenseSplits}" WHERE id IN ($marks)
          )
          AND NOT EXISTS (
            SELECT 1 FROM "${DbTables.expenseSplits}" es2
            WHERE es2.expense_id = "${DbTables.expenses}".id AND es2.is_paid = 0
          )
        ''', selectedIds);

        // 4. Reconcile counter-debt up to offsetCredit
        if (offsetCredit > 0) {
          final peerDebtSplits = await txn.rawQuery('''
            SELECT es.id, es.share_amount
            FROM "${DbTables.expenseSplits}" es
            INNER JOIN "${DbTables.expenses}" e ON e.id = es.expense_id
            WHERE e.payer_id = 'user_self'
              AND es.contact_id = ?
              AND es.is_paid = 0
              AND e.is_trashed = 0
            ORDER BY es.share_amount ASC, es.id ASC
          ''', [peerId]);

          var remainingOffset = offsetCredit;
          for (final row in peerDebtSplits) {
            if (remainingOffset <= 0) break;
            final sid = row['id'].toString();
            final sAmt = (row['share_amount'] as num?)?.toInt() ?? 0;
            if (sAmt <= remainingOffset) {
              await txn.rawUpdate(
                'UPDATE "${DbTables.expenseSplits}" SET is_paid = 1 WHERE id = ?',
                [sid],
              );
              remainingOffset -= sAmt;
            } else {
              // Partial offset: reduce remaining share_amount on this split
              await txn.rawUpdate(
                'UPDATE "${DbTables.expenseSplits}" SET share_amount = share_amount - ? WHERE id = ?',
                [remainingOffset, sid],
              );
              remainingOffset = 0;
            }
          }
        }
      });

      _ref?.invalidate(dashboardSummaryProvider);
      _ref?.invalidate(khataDetailProvider(peerId));
      _ref?.invalidate(spendsCategoryProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      return false;
    }
  }
}

/// Family provider keyed by peerId
final settleUpProvider = StateNotifierProvider.autoDispose.family<SettleUpNotifier, SettleUpState, String>(
  (ref, peerId) => SettleUpNotifier(peerId, 'Sheeda', ref),
);
