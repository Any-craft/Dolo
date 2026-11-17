import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:dolo/app.dart';
import 'package:dolo/core/constants/app_colors.dart';
import 'package:dolo/core/constants/app_dimensions.dart';
import 'package:dolo/core/constants/app_icons_config.dart';
import 'package:dolo/core/constants/app_typography.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';
import 'package:dolo/core/providers/app_icon_provider.dart';

// ───────────────────────── Keys ─────────────────────────

const String _kThemeMode = 'app_theme_mode';

// ───────────────────────── Persistence ─────────────────────────

Future<void> _persistSetting(String key, String value) async {
  try {
    final db = await AppDatabase.instance.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO ${DbTables.appSettings} (key, value) VALUES (?, ?)',
      [key, value],
    );
  } catch (_) {}
}

Future<String?> _readSetting(String key) async {
  try {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT value FROM "${DbTables.appSettings}" WHERE key = ? LIMIT 1',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  } catch (_) {
    return null;
  }
}

String _themeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

ThemeMode _themeFromString(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

// ───────────────────────── Screen ─────────────────────────

class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  static const _themeOptions = <_ThemeOption>[
    _ThemeOption(
      mode: ThemeMode.system,
      title: 'System Default',
      subtitle: 'Auto',
      icon: Icons.brightness_auto_rounded,
    ),
    _ThemeOption(
      mode: ThemeMode.dark,
      title: 'Dark Mode',
      subtitle: 'Obsidian',
      icon: Icons.dark_mode_rounded,
    ),
    _ThemeOption(
      mode: ThemeMode.light,
      title: 'Light Mode',
      subtitle: 'Clean Slate',
      icon: Icons.light_mode_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStoredTheme();
  }

  Future<void> _loadStoredTheme() async {
    final stored = await _readSetting(_kThemeMode);
    if (stored != null && mounted) {
      final mode = _themeFromString(stored);
      if (ref.read(themeModeProvider) != mode) {
        ref.read(themeModeProvider.notifier).state = mode;
      }
    }
  }

  void _onThemeSelected(ThemeMode mode) {
    ref.read(themeModeProvider.notifier).state = mode;
    _persistSetting(_kThemeMode, _themeToString(mode));
  }

  void _onIconSelected(AppIconOption icon) {
    ref.read(appIconProvider.notifier).setAppIcon(icon);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('App icon set to ${icon.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final themeMode = ref.watch(themeModeProvider);
    final activeIcon = ref.watch(appIconProvider);
    final icons = AppIconsConfig.availableIcons;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primary),
        title: Text(
          'Appearance & App Icon',
          style: AppTypography.cardTitle.copyWith(color: primary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.screenHorizontalPadding,
          8,
          AppDimensions.screenHorizontalPadding,
          32,
        ),
        children: [
          // ── Section 1: Theme ──
          _SectionLabel('THEME', muted: muted),
          for (final option in _themeOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ThemeTile(
                option: option,
                selected: themeMode == option.mode,
                surface: surface,
                primary: primary,
                muted: muted,
                border: border,
                onTap: () => _onThemeSelected(option.mode),
              ),
            ),
          const SizedBox(height: 18),

          // ── Section 2: App Icon ──
          _SectionLabel('APP ICON', muted: muted),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: icons.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 204,
            ),
            itemBuilder: (context, index) {
              final icon = icons[index];
              final isSelected = icon.id == activeIcon.id;
              return _IconCard(
                icon: icon,
                selected: isSelected,
                surface: surface,
                primary: primary,
                muted: muted,
                border: border,
                onTap: () => _onIconSelected(icon),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────

class _ThemeOption {
  final ThemeMode mode;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ThemeOption({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color muted;
  const _SectionLabel(this.text, {required this.muted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.sectionLabel.copyWith(color: muted),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final _ThemeOption option;
  final bool selected;
  final Color surface;
  final Color primary;
  final Color muted;
  final Color border;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.option,
    required this.selected,
    required this.surface,
    required this.primary,
    required this.muted,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.cardRadius);

    return Material(
      color: selected ? AppColors.indigoSquircleBg : surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.indigo : border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                color: selected ? AppColors.indigo : muted,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: AppTypography.cardTitle.copyWith(
                        color: selected ? AppColors.indigo : primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: AppTypography.caption.copyWith(
                        color: selected ? AppColors.indigo : muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.indigo : muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  final AppIconOption icon;
  final bool selected;
  final Color surface;
  final Color primary;
  final Color muted;
  final Color border;
  final VoidCallback onTap;

  const _IconCard({
    required this.icon,
    required this.selected,
    required this.surface,
    required this.primary,
    required this.muted,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.cardRadius);

    return Material(
      color: selected ? AppColors.indigoSquircleBg : surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.indigo : border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SvgPicture.asset(
                      icon.assetPath,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      placeholderBuilder: (_) => SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(Icons.apps_rounded, color: muted),
                      ),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      right: -6,
                      top: -6,
                      child: _CheckBadge(),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                icon.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.cardTitle.copyWith(
                  color: selected ? AppColors.indigo : primary,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  icon.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: muted),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selected ? 'ACTIVE' : '',
                style: AppTypography.caption.copyWith(
                  color: AppColors.indigo,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.mint,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
    );
  }
}
