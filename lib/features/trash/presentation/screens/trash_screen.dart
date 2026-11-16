import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dolo/core/constants/app_colors.dart';
import 'package:dolo/core/constants/app_dimensions.dart';
import 'package:dolo/core/constants/app_typography.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';
import 'package:dolo/features/home/presentation/providers/dashboard_provider.dart';
import 'package:dolo/features/retention/data/retention_service.dart';

// ─────────────────────────── Provider ───────────────────────────

final trashedExpensesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = await AppDatabase.instance.database;
  final rows = await db.query(
    DbTables.expenses,
    where: 'is_trashed = ?',
    whereArgs: [1],
    orderBy: 'trashed_at DESC',
  );
  // sqflite returns read-only maps; copy them so callers get a plain Map.
  return rows.map((r) => Map<String, dynamic>.from(r)).toList();
});

// ─────────────────────────── Screen ───────────────────────────

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  /// IDs swiped away but not yet gone from the provider's data.
  /// A dismissed Dismissible must leave the tree immediately, or Flutter
  /// throws; the provider reload is async, so we hide rows locally.
  final Set<String> _removedIds = {};

  Future<void> _onDismissed(
    Map<String, dynamic> expense,
    DismissDirection direction,
  ) async {
    final id = expense['id'].toString();
    final title = (expense['title'] as String?) ?? 'expense';
    final receiptPath = expense['receipt_image_path'] as String?;
    final messenger = ScaffoldMessenger.of(context);
    final isRestore = direction == DismissDirection.startToEnd;

    setState(() => _removedIds.add(id));

    try {
      if (isRestore) {
        await RetentionService().restoreExpense(id);
      } else {
        final db = await AppDatabase.instance.database;
        await db.transaction((txn) async {
          await txn.delete(
            DbTables.expenseSplits,
            where: 'expense_id = ?',
            whereArgs: [id],
          );
          await txn.delete(
            DbTables.expenses,
            where: 'id = ?',
            whereArgs: [id],
          );
        });

        // Clean up local receipt file if exists
        if (receiptPath != null && receiptPath.isNotEmpty) {
          final file = File(receiptPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _removedIds.remove(id));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isRestore
                  ? 'Could not restore $title'
                  : 'Could not delete $title',
            ),
          ),
        );
      return;
    }

    // A restored expense counts toward the dashboard again.
    if (isRestore) ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(trashedExpensesProvider);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isRestore ? 'Restored $title' : 'Permanently deleted $title',
          ),
        ),
      );

    // Once fresh data has landed, the local hide-list is no longer needed.
    try {
      await ref.read(trashedExpensesProvider.future);
    } catch (_) {}
    if (mounted) setState(() => _removedIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final trashed = ref.watch(trashedExpensesProvider);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primary),
        title: Text(
          'Trash',
          style: AppTypography.cardTitle.copyWith(color: primary),
        ),
      ),
      body: trashed.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load trash',
                  style: AppTypography.cardTitle.copyWith(color: primary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(trashedExpensesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (rows) {
          final visible = rows
              .where((r) => !_removedIds.contains(r['id'].toString()))
              .toList();

          if (visible.isEmpty) {
            return _EmptyState(primary: primary, muted: muted);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final expense = visible[index];
              final id = expense['id'].toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                  child: Dismissible(
                    key: ValueKey('trashed_$id'),
                    direction: DismissDirection.horizontal,
                    background: const _SwipeBackground(
                      color: AppColors.mint,
                      icon: Icons.restore_rounded,
                      label: 'Restore',
                      alignment: Alignment.centerLeft,
                    ),
                    secondaryBackground: const _SwipeBackground(
                      color: AppColors.rose,
                      icon: Icons.delete_forever_rounded,
                      label: 'Delete',
                      alignment: Alignment.centerRight,
                    ),
                    onDismissed: (direction) =>
                        _onDismissed(expense, direction),
                    child: _TrashCard(
                      expense: expense,
                      surface: surface,
                      border: border,
                      primary: primary,
                      muted: muted,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────── Widgets ───────────────────────────

class _TrashCard extends StatelessWidget {
  final Map<String, dynamic> expense;
  final Color surface;
  final Color border;
  final Color primary;
  final Color muted;

  const _TrashCard({
    required this.expense,
    required this.surface,
    required this.border,
    required this.primary,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final title = (expense['title'] as String?) ?? '';
    final category = (expense['category'] as String?) ?? 'Uncategorized';
    final amount = (expense['total_amount'] as num?)?.toInt() ?? 0;
    final days = _daysRemaining(expense['trashed_at'] as String?);
    final dayLabel = days == 1 ? 'day' : 'days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle.copyWith(color: primary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$category • $days $dayLabel left',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Rs $amount',
            style: AppTypography.cardTitle.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static int _daysRemaining(String? trashedAt) {
    final parsed = trashedAt == null ? null : DateTime.tryParse(trashedAt);
    if (parsed == null) return 30;
    return (30 - DateTime.now().difference(parsed).inDays).clamp(0, 30).toInt();
  }
}

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    final children = <Widget>[
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(
        label,
        style: AppTypography.cardTitle.copyWith(color: Colors.white),
      ),
    ];

    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeft ? children : children.reversed.toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color primary;
  final Color muted;

  const _EmptyState({required this.primary, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, size: 64, color: muted),
            const SizedBox(height: 16),
            Text(
              'Trash is empty',
              style: AppTypography.cardTitle.copyWith(color: primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleted expenses stay here for 30 days before permanent deletion.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
