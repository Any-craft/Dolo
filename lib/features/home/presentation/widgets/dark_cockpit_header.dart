import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/app_icon_provider.dart';
import '../../../../core/theme/theme_switch.dart';

/// Green top section of Home: greeting, theme switch, profile shortcut and
/// the net balance. The get/give card sits just below it (HomeSummaryCard).
class DarkCockpitHeader extends ConsumerWidget {
  final String userName;
  final int netStanding;
  final VoidCallback? onProfileTap;

  const DarkCockpitHeader({
    super.key,
    required this.userName,
    required this.netStanding,
    this.onProfileTap,
  });

  /// "+Rs 1,200", "−Rs 450", or null when everything is settled.
  static String? formatNet(int net) {
    if (net == 0) return null;
    final amount = NumberFormat('#,###').format(net.abs());
    return '${net > 0 ? '+' : '−'}Rs $amount';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIcon = ref.watch(appIconProvider);
    final net = formatNet(netStanding);
    final hasName =
        userName.trim().isNotEmpty && userName.trim().toLowerCase() != 'you';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.screenHorizontalPadding,
          AppDimensions.cockpitTopPadding - 8,
          AppDimensions.screenHorizontalPadding - 4,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasName ? 'Salaam, $userName' : 'Salaam!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySemiBold.copyWith(
                      color: AppColors.onCockpit,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const ThemeSwitch(),
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: 'Profile',
                  child: GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.glassTriadBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.glassTriadBorder,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: SvgPicture.asset(
                        activeIcon.assetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Net balance',
              style: AppTypography.bodySemiBold.copyWith(
                color: AppColors.onCockpitMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              net ?? 'All settled up',
              style: AppTypography.heroBalance.copyWith(
                color: AppColors.onCockpit,
                fontSize: net == null ? 30 : 38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
