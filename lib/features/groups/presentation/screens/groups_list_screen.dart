import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dolo/core/utils/money.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../providers/group_detail_provider.dart';
import 'group_detail_screen.dart';
import 'new_group_screen.dart';
import '../widgets/group_sign_in.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  /// First time: offer Google sign-in for a combined khata, then open the
  /// New group screen. After that, go straight to New group.
  Future<void> _onNewGroup(BuildContext context) async {
    void openNewGroup() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewGroupScreen()),
        );

    if (await GroupAuth.promptSeen()) {
      if (context.mounted) openNewGroup();
      return;
    }
    if (!context.mounted) return;
    await GroupAuth.markPromptSeen();
    if (!context.mounted) return;
    await showGroupSignInSheet(context, onContinueLocal: openNewGroup);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final groupsAsync = ref.watch(groupsListProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.darkCockpitGradientStart, AppColors.darkCockpitGradientEnd]
                : [AppColors.cockpitGradientStart, AppColors.cockpitGradientEnd],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cockpit Header
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Groups',
                            style: AppTypography.screenTitle.copyWith(
                              color: Colors.white,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Shared splits and roommate balances',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textDarkMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _onNewGroup(context),
                      borderRadius: BorderRadius.circular(AppDimensions.pillRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(AppDimensions.pillRadius),
                        ),
                        child: Text(
                          '+ New',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Surface Sheet
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppDimensions.surfaceSheetRadius),
                      topRight: Radius.circular(AppDimensions.surfaceSheetRadius),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const GroupSignInCard(),
                      const SizedBox(height: 16),
                      ...() {
                        final groups = groupsAsync.valueOrNull ??
                            const [
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

                        if (groups.isEmpty) {
                          return [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.group_outlined,
                                    size: 48,
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No groups yet',
                                    style: AppTypography.cardTitle.copyWith(
                                      color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap "+ New" above to create a group with your roommates or friends.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.caption.copyWith(
                                      color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        }

                        return [
                          for (final g in groups) ...[
                            _GroupCard(
                              name: g.name,
                              membersLine: g.membersLine,
                              initials: g.initials,
                              netBalance: g.netBalance,
                              simplifiedPayments: g.simplifiedPayments,
                              isDark: isDark,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GroupDetailScreen(groupId: g.id),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ];
                      }(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String name;
  final String membersLine;
  final String initials;
  final int netBalance;
  final int simplifiedPayments;
  final bool isDark;
  final VoidCallback onTap;

  const _GroupCard({
    required this.name,
    required this.membersLine,
    required this.initials,
    required this.netBalance,
    required this.simplifiedPayments,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final youOwe = netBalance < 0;
    final balanceColor = youOwe
        ? (isDark ? AppColors.roseTextDark : AppColors.roseTextLight)
        : (isDark ? AppColors.mintTextDark : AppColors.mintTextLight);

    final cardBg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: cardBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: AppDimensions.squircleSmallSize,
                  height: AppDimensions.squircleSmallSize,
                  decoration: BoxDecoration(
                    color: youOwe
                        ? (isDark ? AppColors.rose.withOpacity(0.18) : AppColors.roseSquircleBg)
                        : (isDark ? AppColors.mint.withOpacity(0.16) : AppColors.mintSquircleBg),
                    borderRadius: BorderRadius.circular(AppDimensions.squircleSmallRadius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.cardTitle.copyWith(
                          color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        membersLine,
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatRs(netBalance, signed: true),
                  style: AppTypography.rupeeAmount.copyWith(
                    color: balanceColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.indigo.withOpacity(0.18) : AppColors.indigoSquircleBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Simplified: $simplifiedPayments payments settle the whole group',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.indigoTextDark : AppColors.indigoNotice,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
