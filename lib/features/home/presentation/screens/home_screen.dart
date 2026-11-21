import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dark_cockpit_header.dart';
import '../widgets/filter_pill_bar.dart';
import '../widgets/home_summary_card.dart';
import '../widgets/quick_actions_row.dart';
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

/// How far the summary card overlaps the green header.
const double _cardOverlap = 44;

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onAddExpenseTap;
  final VoidCallback? onSettleUpTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSpendsTap;

  const HomeScreen({
    super.key,
    this.onAddExpenseTap,
    this.onSettleUpTap,
    this.onProfileTap,
    this.onSpendsTap,
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

    final surfaceColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final primaryText =
        isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;

    void openAddExpense() {
      if (onAddExpenseTap != null) return onAddExpenseTap!();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
      );
    }

    void openProfile() {
      if (onProfileTap != null) return onProfileTap!();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }

    return Scaffold(
      backgroundColor: surfaceColor,
      body: summaryAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Couldn't load your balances. Restart the app and try again.",
              textAlign: TextAlign.center,
              style: AppTypography.bodySemiBold.copyWith(color: muted),
            ),
          ),
        ),
        data: (summary) {
          return Column(
            children: [
              // Green header; its bottom edge hides under the summary card.
              Container(
                width: double.infinity,
                decoration: BoxDecoration(gradient: cockpitGradient),
                padding: const EdgeInsets.only(bottom: _cardOverlap + 18),
                child: DarkCockpitHeader(
                  userName: summary.userName,
                  netStanding: summary.netStanding,
                  onProfileTap: openProfile,
                ),
              ),

              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: HomeSummaryCard.height - _cardOverlap + 14,
                          left: AppDimensions.screenHorizontalPadding,
                          right: AppDimensions.screenHorizontalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            QuickActionsRow(
                              actions: [
                                QuickAction(
                                  icon: Icons.add_rounded,
                                  label: 'Add expense',
                                  primary: true,
                                  onTap: openAddExpense,
                                ),
                                QuickAction(
                                  icon: Icons.handshake_outlined,
                                  label: 'Settle up',
                                  onTap: onSettleUpTap ??
                                      () => SettleUpSheet.show(
                                            context,
                                            peerId: 'sheeda',
                                            peerName: 'Sheeda',
                                          ),
                                ),
                                QuickAction(
                                  icon: Icons.pie_chart_outline_rounded,
                                  label: 'Spends',
                                  onTap: onSpendsTap ??
                                      () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const SpendsScreen(),
                                            ),
                                          ),
                                ),
                                QuickAction(
                                  icon: Icons.qr_code_2_rounded,
                                  label: 'Pay me',
                                  onTap: openProfile,
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Text(
                              'Recent activity',
                              style: AppTypography.cardTitle.copyWith(
                                color: primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),

                            FilterPillBar(
                              activeFilter: activeFilter,
                              onFilterChanged: (filter) {
                                ref.read(activeFilterProvider.notifier).state =
                                    filter;
                              },
                            ),

                            const SizedBox(height: 4),

                            Expanded(
                              child: feedItems.isEmpty
                                  ? _EmptyFeed(
                                      isFiltered: activeFilter != 'All',
                                      onAdd: openAddExpense,
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(
                                          bottom: 24, top: 4),
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: feedItems.length,
                                      itemBuilder: (context, index) {
                                        final item = feedItems[index];
                                        return Dismissible(
                                          key: ValueKey('feed_${item.id}'),
                                          direction:
                                              DismissDirection.endToStart,
                                          background:
                                              const _TrashSwipeBackground(),
                                          onDismissed: (_) => _moveToTrash(
                                              context, ref, item.id, item.title),
                                          child: TransactionFeedItem(
                                            item: item,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (ctx) =>
                                                      KhataDetailScreen(
                                                    peerId: item.title
                                                        .toLowerCase(),
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

                    // Summary card floating over the header's bottom edge.
                    Positioned(
                      top: -_cardOverlap,
                      left: AppDimensions.screenHorizontalPadding,
                      right: AppDimensions.screenHorizontalPadding,
                      child: HomeSummaryCard(
                        totalOwed: summary.totalOwed,
                        totalOwe: summary.totalOwe,
                        settledCount: summary.settledCount,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final bool isFiltered;
  final VoidCallback onAdd;

  const _EmptyFeed({required this.isFiltered, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final primaryText =
        isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final accent = Theme.of(context).colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkPillInactive
                    : AppColors.mintSquircleBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_alt_off_outlined
                    : Icons.menu_book_rounded,
                size: 28,
                color: isDark ? AppColors.mintTextDark : AppColors.mintTextLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered ? 'Nothing in this view' : 'Start your first khata',
              style: AppTypography.cardTitle.copyWith(
                color: primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered
                  ? 'Try another filter to see more entries.'
                  : 'Split a bill or log a loan. It takes a few seconds.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: muted, fontSize: 13),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Add your first expense',
                  style: AppTypography.cardTitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
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

