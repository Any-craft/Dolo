import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/algorithms/split_calculator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables.dart';
import '../../../../core/models/expense_model.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../../settlement/presentation/screens/spends_screen.dart';

class MemberShareItem {
  final String id;
  final String name;
  final String initials;
  final String colorHex;
  final int shareAmount;

  const MemberShareItem({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorHex,
    required this.shareAmount,
  });

  MemberShareItem copyWith({int? shareAmount}) {
    return MemberShareItem(
      id: id,
      name: name,
      initials: initials,
      colorHex: colorHex,
      shareAmount: shareAmount ?? this.shareAmount,
    );
  }
}

class AddExpenseState {
  final int totalAmount;
  final String title;
  final String category;
  final String payerName;
  final String groupName;
  final SplitMode splitMode;
  final List<MemberShareItem> members;
  final String? receiptPath;
  final bool isSaving;

  const AddExpenseState({
    required this.totalAmount,
    required this.title,
    required this.category,
    required this.payerName,
    required this.groupName,
    required this.splitMode,
    required this.members,
    this.receiptPath,
    this.isSaving = false,
  });

  bool get hasRemainder => (totalAmount % members.length) != 0;

  AddExpenseState copyWith({
    int? totalAmount,
    String? title,
    String? category,
    String? payerName,
    String? groupName,
    SplitMode? splitMode,
    List<MemberShareItem>? members,
    String? receiptPath,
    bool? isSaving,
  }) {
    return AddExpenseState(
      totalAmount: totalAmount ?? this.totalAmount,
      title: title ?? this.title,
      category: category ?? this.category,
      payerName: payerName ?? this.payerName,
      groupName: groupName ?? this.groupName,
      splitMode: splitMode ?? this.splitMode,
      members: members ?? this.members,
      receiptPath: receiptPath ?? this.receiptPath,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

final addExpenseProvider = StateNotifierProvider<AddExpenseNotifier, AddExpenseState>((ref) {
  return AddExpenseNotifier(ref);
});

class AddExpenseNotifier extends StateNotifier<AddExpenseState> {
  final Ref? _ref;

  AddExpenseNotifier([this._ref])
      : super(
          const AddExpenseState(
            totalAmount: 3600,
            title: 'Dinner at Bundu Khan',
            category: 'Food',
            payerName: 'You',
            groupName: 'Hostel Gang',
            splitMode: SplitMode.equal,
            members: [
              const MemberShareItem(
                id: 'user_self',
                name: 'You',
                initials: 'AL',
                colorHex: '#09121F',
                shareAmount: 900,
              ),
              MemberShareItem(
                id: 'sheeda',
                name: 'Sheeda',
                initials: 'SH',
                colorHex: '#DDF7F2',
                shareAmount: 900,
              ),
              MemberShareItem(
                id: 'kaptaan',
                name: 'Kaptaan',
                initials: 'KP',
                colorHex: '#E8E6FF',
                shareAmount: 900,
              ),
              MemberShareItem(
                id: 'hamza',
                name: 'Hamza',
                initials: 'HM',
                colorHex: '#FFE4EA',
                shareAmount: 900,
              ),
            ],
          ),
        ) {
    _recalculateShares();
  }

  void setTotalAmount(int amount) {
    state = state.copyWith(totalAmount: amount);
    _recalculateShares();
  }

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void setCategory(String category) {
    state = state.copyWith(category: category);
  }

  void setSplitMode(SplitMode mode) {
    state = state.copyWith(splitMode: mode);
    _recalculateShares();
  }

  void setReceiptPath(String? path) {
    state = state.copyWith(receiptPath: path);
  }

  void _recalculateShares() {
    if (state.members.isEmpty) return;

    if (state.splitMode == SplitMode.equal) {
      final shares = SplitCalculator.calculateEqualSplit(
        totalAmount: state.totalAmount,
        memberCount: state.members.length,
        payerIndex: 0, // 'You' absorbs the remainder if any
      );

      final updatedMembers = <MemberShareItem>[];
      for (int i = 0; i < state.members.length; i++) {
        updatedMembers.add(state.members[i].copyWith(shareAmount: shares[i]));
      }

      state = state.copyWith(members: updatedMembers);
    }
  }

  Future<bool> saveExpense() async {
    state = state.copyWith(isSaving: true);
    try {
      final db = await AppDatabase.instance.database;
      final expenseId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      // Ensure mock contacts exist so foreign key constraint passes
      for (final m in state.members) {
        if (m.id != 'user_self') {
          await db.insert(
            DbTables.contacts,
            {
              'id': m.id,
              'name': m.name,
              'phone': '',
              'raast_id': '',
              'avatar_initials': m.initials,
              'avatar_color': m.colorHex,
              'is_shadow': 0,
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      await db.transaction((txn) async {
        await txn.insert(DbTables.expenses, {
          'id': expenseId,
          'group_id': null,
          'payer_id': 'user_self',
          'title': state.title,
          'category': state.category,
          'total_amount': state.totalAmount,
          'split_mode': state.splitMode.name,
          'payment_method': 'Cash',
          'receipt_image_path': state.receiptPath,
          'is_settled': 0,
          'is_trashed': 0,
          'created_at': now,
        });

        for (final m in state.members) {
          await txn.insert(DbTables.expenseSplits, {
            'id': const Uuid().v4(),
            'expense_id': expenseId,
            'contact_id': m.id,
            'share_amount': m.shareAmount,
            'is_paid': m.id == 'user_self' ? 1 : 0,
          });
        }
      });

      _ref?.invalidate(dashboardSummaryProvider);
      _ref?.invalidate(spendsCategoryProvider);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (_) {
      state = state.copyWith(isSaving: false);
      return false;
    }
  }
}
