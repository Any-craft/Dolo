import 'package:flutter/material.dart';
import 'package:dolo/core/widgets/dolo_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dolo/core/constants/app_colors.dart';
import 'package:dolo/core/constants/app_dimensions.dart';
import 'package:dolo/core/constants/app_typography.dart';
import 'package:dolo/core/constants/reminder_tones.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';

// ───────────────────────── Keys & defaults ─────────────────────────

const String _kEnabled = 'daily_reminder_enabled';
const String _kFrequency = 'reminder_frequency';
const String _kReminderTime = 'reminder_time';
const String _kTone = ReminderTones.settingsKey; // 'whatsapp_tone'
const String _kAutoCopyRaast = 'auto_copy_raast';

const String _defaultTime = '21:00';

/// How often the local push reminder fires.
enum ReminderFrequency {
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly');

  const ReminderFrequency(this.id, this.label);
  final String id;
  final String label;

  static ReminderFrequency fromId(String? id) =>
      ReminderFrequency.values.firstWhere(
        (f) => f.id == id,
        orElse: () => ReminderFrequency.daily,
      );
}

// ───────────────────────── State ─────────────────────────

class ReminderSettings {
  final bool remindersEnabled;
  final ReminderFrequency frequency;
  final String reminderTime; // 'HH:mm', 24h
  final ReminderTone tone;
  final bool autoCopyRaast;

  const ReminderSettings({
    this.remindersEnabled = false,
    this.frequency = ReminderFrequency.daily,
    this.reminderTime = _defaultTime,
    this.tone = ReminderTone.friendly,
    this.autoCopyRaast = false,
  });

  ReminderSettings copyWith({
    bool? remindersEnabled,
    ReminderFrequency? frequency,
    String? reminderTime,
    ReminderTone? tone,
    bool? autoCopyRaast,
  }) {
    return ReminderSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      frequency: frequency ?? this.frequency,
      reminderTime: reminderTime ?? this.reminderTime,
      tone: tone ?? this.tone,
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

  Future<void> _load() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery(
        'SELECT key, value FROM "${DbTables.appSettings}" '
        'WHERE key IN (?, ?, ?, ?, ?)',
        [_kEnabled, _kFrequency, _kReminderTime, _kTone, _kAutoCopyRaast],
      );
      final map = {
        for (final r in rows) r['key'] as String: r['value'] as String?,
      };

      final settings = ReminderSettings(
        remindersEnabled: map[_kEnabled] == 'true',
        frequency: ReminderFrequency.fromId(map[_kFrequency]),
        reminderTime: map[_kReminderTime] ?? _defaultTime,
        tone: ReminderTone.fromId(map[_kTone]),
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

  Future<bool> setRemindersEnabled(bool enabled) {
    final cur = state.value;
    if (cur == null) return Future.value(false);
    return _apply(
      cur.copyWith(remindersEnabled: enabled),
      _kEnabled,
      enabled ? 'true' : 'false',
    );
  }

  Future<bool> setFrequency(ReminderFrequency frequency) {
    final cur = state.value;
    if (cur == null) return Future.value(false);
    return _apply(
        cur.copyWith(frequency: frequency), _kFrequency, frequency.id);
  }

  Future<bool> setReminderTime(TimeOfDay time) {
    final cur = state.value;
    if (cur == null) return Future.value(false);
    final value = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return _apply(cur.copyWith(reminderTime: value), _kReminderTime, value);
  }

  Future<bool> setTone(ReminderTone tone) {
    final cur = state.value;
    if (cur == null) return Future.value(false);
    return _apply(cur.copyWith(tone: tone), _kTone, tone.id);
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

  /// Sample amount used for the tone preview bubble.
  static const int previewAmountRs = 1200;

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

  /// Saves [tone] and previews the WhatsApp message it produces.
  Future<void> _selectTone(
    BuildContext context,
    WidgetRef ref,
    ReminderTone tone,
  ) async {
    await _run(
      context,
      () => ref.read(reminderSettingsProvider.notifier).setTone(tone),
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _TonePreviewDialog(tone: tone),
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
      appBar: const DoloAppBar(title: 'Reminders & Notifications'),
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
        data: (settings) {
          final on = settings.remindersEnabled;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenHorizontalPadding,
              8,
              AppDimensions.screenHorizontalPadding,
              32,
            ),
            children: [
              // ── Section 1: Local push reminders ──
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
                        'Local push reminders',
                        style: AppTypography.cardTitle.copyWith(color: primary),
                      ),
                      subtitle: Text(
                        'On-device nudges about pending khata dues',
                        style: AppTypography.caption.copyWith(color: muted),
                      ),
                      value: on,
                      onChanged: (v) =>
                          _run(context, () => notifier.setRemindersEnabled(v)),
                    ),
                    if (on) ...[
                      Divider(height: 1, color: border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Frequency',
                                style: AppTypography.cardTitle
                                    .copyWith(color: primary),
                              ),
                            ),
                            for (final f in ReminderFrequency.values)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FrequencyPill(
                                  label: f.label,
                                  selected: settings.frequency == f,
                                  isDark: isDark,
                                  onTap: () => _run(
                                    context,
                                    () => notifier.setFrequency(f),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: border),
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading: Icon(
                          Icons.schedule_rounded,
                          color: AppColors.selectedInk(Theme.of(context).brightness == Brightness.dark),
                        ),
                        title: Text(
                          'Reminder time',
                          style:
                              AppTypography.cardTitle.copyWith(color: primary),
                        ),
                        trailing: Text(
                          settings.timeOfDay.format(context),
                          style: AppTypography.cardTitle.copyWith(
                            color: AppColors.selectedInk(Theme.of(context).brightness == Brightness.dark),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => _pickTime(context, ref, settings),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Section 2: WhatsApp tone presets ──
              _SectionLabel('WhatsApp Reminder Tone', muted: muted),
              for (final tone in ReminderTone.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ToneCard(
                    tone: tone,
                    selected: settings.tone == tone,
                    surface: surface,
                    primary: primary,
                    muted: muted,
                    border: border,
                    onTap: () => _selectTone(context, ref, tone),
                  ),
                ),
              const SizedBox(height: 14),

              // ── Section 3: Payment sharing ──
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
          );
        },
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────

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
    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _FrequencyPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FrequencyPill({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveBg =
        isDark ? AppColors.darkPillInactive : AppColors.lightPillInactive;
    final inactiveText =
        isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.mint : inactiveBg,
        borderRadius: BorderRadius.circular(AppDimensions.pillRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.pillRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.textLightPrimary : inactiveText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToneCard extends StatelessWidget {
  final ReminderTone tone;
  final bool selected;
  final Color surface;
  final Color primary;
  final Color muted;
  final Color border;
  final VoidCallback onTap;

  const _ToneCard({
    required this.tone,
    required this.selected,
    required this.surface,
    required this.primary,
    required this.muted,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppDimensions.cardRadius);
    final selectedBg = isDark
        ? AppColors.mintGlass
        : AppColors.mintSquircleBg;
    final accent =
        isDark ? AppColors.mintTextDark : AppColors.mintTextLight;

    return Semantics(
      selected: selected,
      button: true,
      label: '${tone.label} tone',
      child: Material(
        color: selected ? selectedBg : surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.mint : border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.selectedFill(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_toneIcon(tone),
                      size: 20, color: AppColors.selectedInk(isDark)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tone.label,
                        style: AppTypography.cardTitle.copyWith(
                          color: selected ? accent : primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"${tone.message(NotificationsScreen.previewAmountRs)}"',
                        style: AppTypography.caption.copyWith(
                          color: selected ? accent : muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.selectedInk(Theme.of(context).brightness == Brightness.dark) : muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// WhatsApp-style chat bubble previewing the selected tone.
class _TonePreviewDialog extends StatelessWidget {
  final ReminderTone tone;
  const _TonePreviewDialog({required this.tone});

  // WhatsApp outgoing-bubble greens, used only inside this preview.
  static const Color _bubbleLight = Color(0xFFD9FDD3);
  static const Color _bubbleDark = Color(0xFF005C4B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      title: Text(
        '${tone.label} tone saved',
        style: AppTypography.cardTitle.copyWith(color: primary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your WhatsApp reminders will read like this:',
            style: AppTypography.caption.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? _bubbleDark : _bubbleLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(
                tone.message(NotificationsScreen.previewAmountRs),
                style: AppTypography.bodySemiBold.copyWith(color: primary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

/// Icon shown for each WhatsApp reminder tone.
IconData _toneIcon(ReminderTone tone) {
  switch (tone) {
    case ReminderTone.friendly:
      return Icons.waving_hand_outlined;
    case ReminderTone.campus:
      return Icons.school_outlined;
    case ReminderTone.firm:
      return Icons.assignment_outlined;
  }
}
