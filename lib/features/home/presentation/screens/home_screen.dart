import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dark_cockpit_header.dart';
import '../widgets/filter_pill_bar.dart';
import '../widgets/transaction_feed_item.dart';
import '../../../khata_1on1/presentation/screens/khata_detail_screen.dart';
import '../../../expense/presentation/screens/add_expense_screen.dart';
import '../../../settlement/presentation/screens/settle_up_sheet.dart';
import '../../../settlement/presentation/screens/profile_screen.dart';
import '../../../settlement/presentation/screens/spends_screen.dart';
import '../../../retention/data/retention_service.dart';
import '../../../trash/presentation/screens/trash_screen.dart';

/// Feed rows swiped into Trash but not yet gone from the reloaded dashboard.
/// A dismissed Dismissible must leave the tree immediately, while the
/// provider reload is async, so we hide the rows locally in the meantime.
final _hiddenFeedIdsProvider = StateProvider<Set<String>>((ref) => const {});

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onAddExpenseTap;
  final VoidCallback? onSettleUpTap;
  final VoidCallback? onProfileTap;

  const HomeScreen({
    super.key,
    this.onAddExpenseTap,
    this.onSettleUpTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final activeFilter = ref.watch(activeFilterProvider);
    final hiddenIds = ref.watch(_hiddenFeedIdsProvider);
    final feedItems = ref
        .watch(filteredFeedProvider)
        .where((i) => !hiddenIds.contains(i.id))
        .toList();

    final cockpitGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppColors.darkCockpitGradientStart, AppColors.darkCockpitGradientEnd]
          : [AppColors.cockpitGradientStart, AppColors.cockpitGradientEnd],
    );

    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: cockpitGradient),
        child: summaryAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mint),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Error loading dashboard: $err',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          data: (summary) {
            return Column(
              children: [
                // Top 35% Cockpit Header
                DarkCockpitHeader(
                  userName: summary.userName,
                  netStanding: summary.netStanding,
                  totalOwed: summary.totalOwed,
                  totalOwe: summary.totalOwe,
                  settledCount: summary.settledCount,
                  onProfileTap: onProfileTap ??
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                ),

                // Bottom 65% Surface Sheet
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppDimensions.surfaceSheetRadius),
                        topRight: Radius.circular(AppDimensions.surfaceSheetRadius),
                      ),
                    ),
                    padding: const EdgeInsets.only(
                      top: 22,
                      left: AppDimensions.screenHorizontalPadding,
                      right: AppDimensions.screenHorizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Action CTAs (+ Add expense, Settle up)
                        Row(
                          children: [
                            Expanded(
                              child: _PrimaryCta(
                                text: '+ Add expense',
                                backgroundColor: AppColors.mint,
                                textColor: AppColors.textLightPrimary,
                                onTap: onAddExpenseTap ??
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AddExpenseScreen(),
                                        ),
                                      );
                                    },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PrimaryCta(
                                text: 'Settle up',
                                backgroundColor: isDark
                                    ? AppColors.darkPillInactive
                                    : AppColors.lightPillInactive,
                                textColor: isDark
                                    ? AppColors.textDarkPrimary
                                    : AppColors.textLightPrimary,
                                onTap: onSettleUpTap ??
                                    () {
                                      SettleUpSheet.show(
                                        context,
                                        peerId: 'sheeda',
                                        peerName: 'Sheeda',
                                      );
                                    },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Horizontal Filter Pill Bar
                        FilterPillBar(
                          activeFilter: activeFilter,
                          onFilterChanged: (filter) {
                            ref.read(activeFilterProvider.notifier).state = filter;
                          },
                        ),

                        const SizedBox(height: 8),

                        // Transaction Feed
                        Expanded(
                          child: feedItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'No transactions in this view',
                                    style: AppTypography.caption.copyWith(
                                      color: isDark
                                          ? AppColors.textDarkMuted
                                          : AppColors.textLightMuted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 24, top: 4),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: feedItems.length,
                                  itemBuilder: (context, index) {
                                    final item = feedItems[index];
                                    return Dismissible(
                                      key: ValueKey('feed_${item.id}'),
                                      direction: DismissDirection.endToStart,
                                      background: const _TrashSwipeBackground(),
                                      onDismissed: (_) => _moveToTrash(
                                          context, ref, item.id, item.title),
                                      child: TransactionFeedItem(
                                        item: item,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (ctx) =>
                                                  KhataDetailScreen(
                                                peerId:
                                                    item.title.toLowerCase(),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Soft-deletes an expense (Module 10) and offers an Undo.
Future<void> _moveToTrash(
  BuildContext context,
  WidgetRef ref,
  String expenseId,
  String title,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final hidden = ref.read(_hiddenFeedIdsProvider.notifier);
  hidden.state = {...hidden.state, expenseId};

  void refreshAll() {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(spendsCategoryProvider);
    ref.invalidate(trashedExpensesProvider);
  }

  void unhide() {
    hidden.state = {...hidden.state}..remove(expenseId);
  }

  try {
    await RetentionService().trashExpense(expenseId);
  } catch (_) {
    unhide();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Could not move $title to Trash')));
    return;
  }

  refreshAll();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$title moved to Trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await RetentionService().restoreExpense(expenseId);
            refreshAll();
          },
        ),
      ),
    );

  // Once the reloaded feed no longer contains the row, stop hiding it so an
  // Undo can bring it back.
  try {
    await ref.read(dashboardSummaryProvider.future);
  } catch (_) {}
  unhide();
}

class _TrashSwipeBackground extends StatelessWidget {
  const _TrashSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.rose,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Trash',
            style: AppTypography.cardTitle.copyWith(color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _PrimaryCta({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppDimensions.ctaRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppDimensions.ctaHeight,
          child: Center(
            child: Text(
              text,
              style: AppTypography.cardTitle.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}