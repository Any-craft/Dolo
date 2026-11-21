import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Floating card under the green header: what you'll get, what you'll give,
/// and how many settlements are done.
class HomeSummaryCard extends StatelessWidget {
  final int totalOwed;
  final int totalOwe;
  final int settledCount;

  const HomeSummaryCard({
    super.key,
    required this.totalOwed,
    required this.totalOwe,
    required this.settledCount,
  });

  static const double height = 104;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rs = NumberFormat('#,###');
    final card = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final line = isDark ? AppColors.darkPillInactive : AppColors.lightPillInactive;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    Widget figure(String label, int value, Color color) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rs ${rs.format(value)}',
                style: AppTypography.rupeeAmount.copyWith(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption.copyWith(color: muted, fontSize: 12),
              ),
            ],
          ),
        );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                figure(
                  "You'll get",
                  totalOwed,
                  isDark ? AppColors.mintTextDark : AppColors.mintTextLight,
                ),
                Container(width: 1, height: 40, color: line),
                figure(
                  "You'll give",
                  totalOwe,
                  isDark ? AppColors.roseTextDark : AppColors.roseTextLight,
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: line)),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: isDark ? AppColors.indigoTextDark : AppColors.indigoTextLight,
                ),
                const SizedBox(width: 5),
                Text(
                  settledCount == 1
                      ? '1 payment settled'
                      : '$settledCount payments settled',
                  style: AppTypography.caption.copyWith(
                    color: muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
