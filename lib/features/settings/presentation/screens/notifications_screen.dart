import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dolo/core/constants/app_colors.dart';
import 'package:dolo/core/constants/app_dimensions.dart';
import 'package:dolo/core/constants/app_typography.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';

// ───────────────────────── Keys & defaults ─────────────────────────

const String _kDailyEnabled = 'daily_reminder_enabled';
const String _kReminderTime = 'reminder_time';
const String _kNudge = 'settlement_nudge_frequency';
const String _kAutoCopyRaast = 'auto_copy_raast';

const String _defaultTime = '21:00';
const String _defaultNudge = 'standard';

// ───────────────────────── State ─────────────────────────

class ReminderSettings {
  final bool dailyReminderEnabled;
  final String reminderTime; // 'HH:mm', 24h
  final String nudgeFrequency; // gentle | standard | urgent
  final bool autoCopyRaast;

  const ReminderSettings({
    this.dailyReminderEnabled = false,
    this.reminderTime = _defaultTime,
    this.nudgeFrequency = _defaultNudge,
    this.autoCopyRaast = false,
  });

  ReminderSettings copyWith({
    bool? dailyReminderEnabled,
    String? reminderTime,
    String? nudgeFrequency,
    bool? autoCopyRaast,
  }) {
    return ReminderSettings(
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      nudgeFrequency: nudgeFrequency ?? this.nudgeFrequency,
      autoCopyRaast: autoCopyRaast ?? this.autoCopyRaast,
    );
  }

  TimeOfDay get timeOfDay {
    final parts = reminderTime.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return const TimeOfDay(hour: 21, minute: 0);
  }
}

// ───────────────────────── Notifier ─────────────────────────

class ReminderSettingsNotifier
    extends StateNotifier<AsyncValue<ReminderSettings>> {
  ReminderSettingsNotifier([ReminderSettings? initialSettings])
      : super(initialSettings != null
            ? AsyncValue.data(initialSettings)
            : const AsyncValue.loading()) {
    if (initialSettings == null) {
      _load();
    }
  }

  static const _validNudges = {'gentle', 'standard', 'urgent'};

  Future<void> _load() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery(
        'SELECT key, value FROM "${DbTables.appSettings}" '
        'WHERE key IN (?, ?, ?, ?)',
        [_kDailyEnabled, _kReminderTime, _kNudge, _kAutoCopyRaast],
      );
      final map = {
        for (final r in rows) r['key'] as String: r['value'] as String?,
      };

      final nudge = map[_kNudge];
      final settings = ReminderSettings(
        dailyReminderEnabled: map[_kDailyEnabled] == 'true',
        reminderTime: map[_kReminderTime] ?? _defaultTime,
        nudgeFrequency: _validNudges.contains(nudge) ? nudge! : _defaultNudge,
        autoCopyRaast: map[_kAutoCopyRaast] == 'true',
      );
      if (mounted) state = AsyncValue.data(settings);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    await _load();
  }

  Future<void> _persist(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO ${DbTables.appSettings} (key, value) '
      'VALUES (?, ?)',
      [key, value],
    );
  }

  /// Optimistically applies [next], writes [key]/[value], and rolls back
  /// on failure. Returns true when the write succeeded.
  Future<bool> _apply(
    ReminderSettings next,
    String key,
    String value,
  ) async {
    final previous = state.value;
    if (previous == null) return false;

    state = AsyncValue.data(next);
    try {
      await _persist(key, value);
      return true;
    } catch (_) {
      if (mounted) state = AsyncValue.data(previous);
      return false;
    }
  }

  Future<bool> setDailyEnabled(bool enabled) {
    final cur = state.value;
    if (cur == null) return Future.value(false);
    return _apply(
      cur.copyWith(dailyReminderEnabled: enabled),
      _kDailyEnabled,
      enabled ? 'true' : 'false',
    );
  }

  Future<bool> setReminderTime(TimeOfDay time) {
    final cur = state.value;
    if (cur == null) return Future.value(false);
    final value = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return _apply(cur.copyWith(reminderTime: value), _kReminderTime, value);
  }

  Future<bool> setNudge(String frequency) {
    final cur = state.value;
    if (cur == null || !_validNudges.contains(frequency)) {
      return Future.value(false);
    }
    return _apply(cur.copyWith(nudgeFrequency: frequency), _kNudge, frequency);
  }

  Future<bool> setAutoCopyRaast(bool enabled) {
    final cur = state.value;
    if (cur == null) return Future.value(false);
    return _apply(
      cur.copyWith(autoCopyRaast: enabled),
      _kAutoCopyRaast,
      enabled ? 'true' : 'false',
    );
  }
}

final reminderSettingsProvider = StateNotifierProvider.autoDispose<
    ReminderSettingsNotifier, AsyncValue<ReminderSettings>>(
  (ref) => ReminderSettingsNotifier(),
);

// ───────────────────────── Screen ─────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const _tones = <_ToneOption>[
    _ToneOption('gentle', 'Gentle', 'Yaar hisaab dekh lo'),
    _ToneOption('standard', 'Standard', 'Dolo settlement pending'),
    _ToneOption('urgent', 'Strict', 'Outstanding dues reminder'),
  ];

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final ok = await action();
    if (!ok && context.mounted) {
      _snack(context, 'Could not save setting');
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.timeOfDay,
    );
    if (picked == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(reminderSettingsProvider.notifier).setReminderTime(picked),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final async = ref.watch(reminderSettingsProvider);
    final notifier = ref.read(reminderSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primary),
        title: Text(
          'Reminders & Notifications',
          style: AppTypography.cardTitle.copyWith(color: primary),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load settings',
                  style: AppTypography.cardTitle.copyWith(color: primary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: notifier.reload,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenHorizontalPadding,
            8,
            AppDimensions.screenHorizontalPadding,
            32,
          ),
          children: [
            // ── Section 1: Khata Reminders ──
            _SectionLabel('Khata Reminders', muted: muted),
            _Card(
              surface: surface,
              border: border,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    activeTrackColor: AppColors.mint,
                    title: Text(
                      'Daily reminder',
                      style: AppTypography.cardTitle.copyWith(color: primary),
                    ),
                    subtitle: Text(
                      'A gentle daily check on your khata',
                      style: AppTypography.caption.copyWith(color: muted),
                    ),
                    value: settings.dailyReminderEnabled,
                    onChanged: (v) =>
                        _run(context, () => notifier.setDailyEnabled(v)),
                  ),
                  Divider(height: 1, color: border),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    enabled: settings.dailyReminderEnabled,
                    leading: Icon(
                      Icons.schedule_rounded,
                      color: settings.dailyReminderEnabled
                          ? AppColors.indigo
                          : muted,
                    ),
                    title: Text(
                      'Reminder time',
                      style: AppTypography.cardTitle.copyWith(
                        color: settings.dailyReminderEnabled
                            ? primary
                            : muted,
                      ),
                    ),
                    trailing: Text(
                      settings.timeOfDay.format(context),
                      style: AppTypography.cardTitle.copyWith(
                        color: settings.dailyReminderEnabled
                            ? AppColors.indigo
                            : muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: settings.dailyReminderEnabled
                        ? () => _pickTime(context, ref, settings)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Section 2: Nudge Tone ──
            _SectionLabel('Nudge Tone', muted: muted),
            _Card(
              surface: surface,
              border: border,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final tone in _tones)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: tone == _tones.last ? 0 : 8,
                        ),
                        child: _ToneTile(
                          option: tone,
                          selected: settings.nudgeFrequency == tone.value,
                          primary: primary,
                          muted: muted,
                          border: border,
                          onTap: () => _run(
                            context,
                            () => notifier.setNudge(tone.value),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Section 3: Payment Sharing ──
            _SectionLabel('Payment Sharing', muted: muted),
            _Card(
              surface: surface,
              border: border,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                activeTrackColor: AppColors.mint,
                title: Text(
                  'Auto-attach Raast ID to reminder text',
                  style: AppTypography.cardTitle.copyWith(color: primary),
                ),
                subtitle: Text(
                  'Your Raast ID is added so friends can pay you faster',
                  style: AppTypography.caption.copyWith(color: muted),
                ),
                value: settings.autoCopyRaast,
                onChanged: (v) =>
                    _run(context, () => notifier.setAutoCopyRaast(v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────

class _ToneOption {
  final String value;
  final String label;
  final String sample;
  const _ToneOption(this.value, this.label, this.sample);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color muted;
  const _SectionLabel(this.text, {required this.muted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.sectionLabel.copyWith(color: muted),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Color surface;
  final Color border;
  final Widget child;
  const _Card({
    required this.surface,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

class _ToneTile extends StatelessWidget {
  final _ToneOption option;
  final bool selected;
  final Color primary;
  final Color muted;
  final Color border;
  final VoidCallback onTap;

  const _ToneTile({
    required this.option,
    required this.selected,
    required this.primary,
    required this.muted,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.cardRadius - 4 < 0
        ? 0
        : AppDimensions.cardRadius - 4);

    return Semantics(
      selected: selected,
      button: true,
      label: '${option.label}: ${option.sample}',
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.indigoSquircleBg : Colors.transparent,
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.indigo : border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.indigo : muted,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: AppTypography.cardTitle.copyWith(
                        color: selected ? AppColors.indigo : primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '"${option.sample}"',
                      style: AppTypography.caption.copyWith(
                        color: selected ? AppColors.indigo : muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
