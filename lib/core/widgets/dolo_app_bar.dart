import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Green top bar shared by every screen that isn't Home: white title (and
/// optional subtitle), white back arrow, rounded bottom corners. Matches the
/// green header on Home so the whole app reads as one.
class DoloAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DoloAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 64 : 78);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      toolbarHeight: preferredSize.height,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      actions: actions,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.onCockpit,
      iconTheme: const IconThemeData(color: AppColors.onCockpit),
      actionsIconTheme: const IconThemeData(color: AppColors.onCockpit),
      elevation: 0,
      scrolledUnderElevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      // A childless Container fills the bar; a bare DecoratedBox would
      // shrink to zero height here.
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    AppColors.darkCockpitGradientStart,
                    AppColors.darkCockpitGradientEnd,
                  ]
                : const [
                    AppColors.cockpitGradientStart,
                    AppColors.cockpitGradientEnd,
                  ],
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.screenTitle.copyWith(
              color: AppColors.onCockpit,
              fontSize: 20,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.onCockpitMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
