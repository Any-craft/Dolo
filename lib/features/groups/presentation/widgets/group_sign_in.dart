import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/database/app_settings_store.dart';
import '../../../../core/sync/sync_service.dart';

/// Sign-in for shared ("combined") khatas. Personal khatas never need it.
class GroupAuth {
  GroupAuth._();

  /// Silently creates (or reuses) the anonymous Supabase session.
  /// Returns true when a session exists.
  static Future<bool> signInWithGoogle() async {
    final uid = await SyncService.instance.ensureAnonymousSession();
    return uid != null;
  }

  static const String promptSeenKey = 'group_signin_prompt_seen';

  static Future<bool> promptSeen() async =>
      (await AppSettingsStore.read(promptSeenKey)) == 'true';

  static Future<void> markPromptSeen() async {
    try {
      await AppSettingsStore.write(promptSeenKey, 'true');
    } catch (_) {}
  }
}

Future<void> _tryGoogle(BuildContext context) async {
  final ok = await GroupAuth.signInWithGoogle();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Signed in. Your groups will sync with friends.'
              : "Google sign-in isn't connected yet. Your groups still work on this phone.",
        ),
      ),
    );
}

/// Card at the top of the Groups list.
class GroupSignInCard extends StatelessWidget {
  const GroupSignInCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.selectedFill(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_alt_rounded,
                  color: AppColors.selectedInk(isDark), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Share a khata with friends',
                  style: AppTypography.cardTitle.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in so everyone in a group sees the same balances on their own phone.',
            style: AppTypography.caption.copyWith(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _GoogleButton(onPressed: () => _tryGoogle(context)),
        ],
      ),
    );
  }
}

/// Shown the first time someone taps "+ New" on Groups. "Use on this phone
/// only" runs [onContinueLocal] (opens the New group screen).
Future<void> showGroupSignInSheet(
  BuildContext context, {
  required VoidCallback onContinueLocal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final primary =
          isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
      final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

      Widget point(IconData icon, String text) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.selectedInk(isDark)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.bodySemiBold.copyWith(
                      color: primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Make it a combined khata?',
                style: AppTypography.screenTitle.copyWith(
                  color: primary,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Signing in lets everyone in the group add expenses and see the same totals.',
                style: AppTypography.caption.copyWith(color: muted, fontSize: 14),
              ),
              const SizedBox(height: 18),
              point(Icons.people_alt_outlined, 'Friends see expenses as you add them'),
              point(Icons.phonelink_rounded, 'Your groups come back if you change phones'),
              point(Icons.lock_outline_rounded, 'Personal khatas still never leave this phone'),
              const SizedBox(height: 8),
              _GoogleButton(onPressed: () {
                Navigator.pop(sheetContext);
                _tryGoogle(context);
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onContinueLocal();
                  },
                  child: const Text('Use on this phone only'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          foregroundColor:
              isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.login_rounded, size: 20),
        label: Text(
          'Continue with Google',
          style: AppTypography.cardTitle.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
