import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

class QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.primary = false,
  });
}

/// Row of square action tiles with a label underneath.
class QuickActionsRow extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final softBg = isDark ? AppColors.darkPillInactive : AppColors.mintSquircleBg;
    final softFg = isDark ? AppColors.mintTextDark : AppColors.mintTextLight;
    final label = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) {
        return Expanded(
          child: Semantics(
            button: true,
            label: a.label,
            excludeSemantics: true,
            child: InkWell(
              onTap: a.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: a.primary ? accent : softBg,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: a.primary
                            ? [
                                BoxShadow(
                                  color: accent.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        a.icon,
                        size: 26,
                        color: a.primary ? Colors.white : softFg,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: label,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
