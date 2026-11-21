import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dolo/core/widgets/dolo_app_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dolo/core/constants/app_colors.dart';
import 'package:dolo/core/constants/app_dimensions.dart';
import 'package:dolo/core/constants/app_typography.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/database/tables.dart';
import 'package:dolo/core/sync/sync_service.dart';

const String _imagesKey = 'auto_purge_images_days';
const String _metadataKey = 'auto_purge_metadata_days';
const String _never = 'never';

const String _imagesDefault = '7'; // matches DB seed + PRD Module 9
const String _metadataDefault = _never;

class _Option {
  final String value;
  final String label;
  const _Option(this.value, this.label);
}

const _imageOptions = [
  _Option('7', '7 days'),
  _Option('14', '14 days'),
  _Option('30', '30 days'),
  _Option(_never, 'Never'),
];

const _metadataOptions = [
  _Option('30', '30 days'),
  _Option('60', '60 days'),
  _Option('90', '90 days'),
  _Option(_never, 'Never'),
];

class StorageSyncScreen extends StatefulWidget {
  const StorageSyncScreen({super.key});

  @override
  State<StorageSyncScreen> createState() => _StorageSyncScreenState();
}

class _StorageSyncScreenState extends State<StorageSyncScreen> {
  String _imagesDays = _imagesDefault;
  String _metadataDays = _metadataDefault;
  int _unsyncedCount = 0;

  bool _loading = true;
  bool _exporting = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ───────────────────────── Data ─────────────────────────

  Future<int> _queryUnsyncedCount() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM "${DbTables.syncJournal}" '
      'WHERE is_synced = 0',
    );
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<void> _load() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery(
        'SELECT key, value FROM "${DbTables.appSettings}" '
        'WHERE key IN (?, ?)',
        [_imagesKey, _metadataKey],
      );
      final settings = {
        for (final r in rows) r['key'] as String: r['value'] as String?,
      };
      final count = await _queryUnsyncedCount();

      String pick(String? stored, List<_Option> options, String fallback) =>
          options.any((o) => o.value == stored) ? stored! : fallback;

      if (!mounted) return;
      setState(() {
        _imagesDays =
            pick(settings[_imagesKey], _imageOptions, _imagesDefault);
        _metadataDays =
            pick(settings[_metadataKey], _metadataOptions, _metadataDefault);
        _unsyncedCount = count;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Could not load settings');
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO ${DbTables.appSettings} (key, value) '
      'VALUES (?, ?)',
      [key, value],
    );
  }

  Future<void> _onSettingChanged({
    required String key,
    required String newValue,
    required String oldValue,
    required void Function(String) apply,
  }) async {
    if (newValue == oldValue) return;
    setState(() => apply(newValue)); // optimistic
    try {
      await _saveSetting(key, newValue);
    } catch (_) {
      if (!mounted) return;
      setState(() => apply(oldValue)); // roll back
      _snack('Could not save setting');
    }
  }

  // ───────────────────────── Export ─────────────────────────

  static String _csvCell(Object? value) {
    if (value == null) return '';
    final s = value.toString();
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final db = await AppDatabase.instance.database;
      const expenses = '"${DbTables.expenses}"';
      const splits = '"${DbTables.expenseSplits}"';

      // Verify split_mode existence safely
      final info = await db.rawQuery('PRAGMA table_info($expenses)');
      final hasSplitMode = info.any((c) => c['name'] == 'split_mode');
      final splitModeExpr = hasSplitMode ? 'e.split_mode' : "''";

      final rows = await db.rawQuery('''
        SELECT
          e.id AS expense_id,
          e.title,
          e.category,
          e.total_amount,
          $splitModeExpr AS split_mode,
          e.created_at,
          es.contact_id,
          es.share_amount,
          es.is_paid
        FROM $expenses e
        LEFT JOIN $splits es ON es.expense_id = e.id
        WHERE e.is_trashed = 0
        ORDER BY e.created_at DESC, e.id, es.id
      ''');

      if (rows.isEmpty) {
        _snack('Nothing to export yet');
        return;
      }

      final buffer = StringBuffer('\uFEFF'); // BOM so Excel reads UTF-8
      buffer.write(
        'Expense ID,Title,Category,Total Amount (Rs),Split Mode,'
        'Created At,Contact ID,Share Amount (Rs),Is Paid\r\n',
      );

      for (final r in rows) {
        final isPaidRaw = r['is_paid'];
        final isPaid = isPaidRaw == null
            ? ''
            : ((isPaidRaw as num).toInt() == 1 ? 'Yes' : 'No');

        buffer.write([
          _csvCell(r['expense_id']),
          _csvCell(r['title']),
          _csvCell(r['category']),
          _csvCell((r['total_amount'] as num?)?.toInt()),
          _csvCell(r['split_mode']),
          _csvCell(r['created_at']),
          _csvCell(r['contact_id']),
          _csvCell((r['share_amount'] as num?)?.toInt()),
          _csvCell(isPaid),
        ].join(','));
        buffer.write('\r\n');
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/settlement_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(buffer.toString(), flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'Dolo Expense Data Export',
      );
    } catch (_) {
      _snack('Export failed. Please try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ───────────────────────── Sync ─────────────────────────

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    try {
      final syncResult = await SyncService().syncAll();
      final count = await _queryUnsyncedCount();
      if (!mounted) return;
      setState(() => _unsyncedCount = count);
      _snack(syncResult.message);
    } catch (_) {
      _snack('Could not check sync status');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: surface,
      appBar: const DoloAppBar(title: 'Storage & Sync'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── Section 1: Auto-purge ──
                _SectionLabel('AUTO-PURGE', muted: muted),
                _Card(
                  surface: surface,
                  border: border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ChoiceGroup(
                        title: 'Delete receipt images after',
                        options: _imageOptions,
                        selected: _imagesDays,
                        primary: primary,
                        muted: muted,
                        border: border,
                        onSelected: (v) => _onSettingChanged(
                          key: _imagesKey,
                          newValue: v,
                          oldValue: _imagesDays,
                          apply: (x) => _imagesDays = x,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, color: border),
                      ),
                      _ChoiceGroup(
                        title: 'Delete expense records after',
                        options: _metadataOptions,
                        selected: _metadataDays,
                        primary: primary,
                        muted: muted,
                        border: border,
                        onSelected: (v) => _onSettingChanged(
                          key: _metadataKey,
                          newValue: v,
                          oldValue: _metadataDays,
                          apply: (x) => _metadataDays = x,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Section 2: Data export ──
                _SectionLabel('DATA EXPORT', muted: muted),
                _Card(
                  surface: surface,
                  border: border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download every expense and its splits as a '
                        'spreadsheet-ready CSV file.',
                        style: AppTypography.caption.copyWith(color: muted),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: AppDimensions.ctaHeight,
                        child: OutlinedButton.icon(
                          onPressed: _exporting ? null : _exportCsv,
                          icon: _exporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.ios_share_rounded),
                          label: const Text('Export all data as CSV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.selectedInk(Theme.of(context).brightness == Brightness.dark),
                            side: const BorderSide(color: AppColors.mint),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.ctaRadius),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Section 3: Group sync ──
                _SectionLabel('GROUP SYNC', muted: muted),
                _Card(
                  surface: surface,
                  border: border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.mintSquircleBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded,
                                size: 14, color: AppColors.mint),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Offline-first • Zero server tracking',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.mint,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Unsynced changes',
                              style: AppTypography.cardTitle
                                  .copyWith(color: primary),
                            ),
                          ),
                          Text(
                            '$_unsyncedCount',
                            style: AppTypography.cardTitle.copyWith(
                              color: _unsyncedCount == 0
                                  ? AppColors.mint
                                  : AppColors.rose,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: AppDimensions.ctaHeight,
                        child: ElevatedButton(
                          onPressed: _syncing ? null : _syncNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mint,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.ctaRadius),
                            ),
                          ),
                          child: _syncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Sync now',
                                  style: AppTypography.cardTitle
                                      .copyWith(color: Colors.white),
                                ),
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
        text,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  final String title;
  final List<_Option> options;
  final String selected;
  final Color primary;
  final Color muted;
  final Color border;
  final ValueChanged<String> onSelected;

  const _ChoiceGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.primary,
    required this.muted,
    required this.border,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.cardTitle.copyWith(color: primary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(o.label),
                selected: o.value == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(o.value),
                backgroundColor: Colors.transparent,
                selectedColor: AppColors.selectedFill(Theme.of(context).brightness == Brightness.dark),
                side: BorderSide(
                  color: o.value == selected ? AppColors.mint : border,
                ),
                labelStyle: AppTypography.caption.copyWith(
                  color: o.value == selected ? AppColors.selectedInk(Theme.of(context).brightness == Brightness.dark) : muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
