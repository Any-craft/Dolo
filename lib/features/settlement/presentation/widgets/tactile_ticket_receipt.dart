import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import 'package:intl/intl.dart';

/// Dolo Settlement Ticket — dashed-border tactile receipt widget.
/// All currency amounts are whole-rupee [int] (no floating point).
class TactileTicketReceipt extends StatefulWidget {
  final String title;
  /// Total amount in whole rupees (int only — no decimals).
  final int amountRs;
  final String paidBy;
  final String recipient;
  /// Each entry: {'name': 'Ali', 'share': '500'} — share as String whole-Rs.
  final List<Map<String, String>> shares;
  final bool isSettled;

  const TactileTicketReceipt({
    super.key,
    required this.title,
    required this.amountRs,
    required this.paidBy,
    required this.recipient,
    this.shares = const [],
    this.isSettled = true,
  });

  @override
  State<TactileTicketReceipt> createState() => _TactileTicketReceiptState();
}

class _TactileTicketReceiptState extends State<TactileTicketReceipt> {
  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _shareTicketAsPng() async {
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/settlement_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Settlement receipt for ${widget.title} via Dolo',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share ticket: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: _TicketCard(
            title: widget.title,
            amountRs: widget.amountRs,
            paidBy: widget.paidBy,
            recipient: widget.recipient,
            shares: widget.shares,
            isSettled: widget.isSettled,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: AppDimensions.ctaHeight,
          child: ElevatedButton.icon(
            onPressed: _shareTicketAsPng,
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Receipt PNG'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mint,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.ctaRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  final String title;
  final int amountRs;
  final String paidBy;
  final String recipient;
  final List<Map<String, String>> shares;
  final bool isSettled;

  const _TicketCard({
    required this.title,
    required this.amountRs,
    required this.paidBy,
    required this.recipient,
    required this.shares,
    required this.isSettled,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primary =
        isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final rupees = NumberFormat('#,###');

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: borderColor,
        radius: AppDimensions.ticketRadius,
      ),
      child: Container(
        width: 310,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.ticketRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ticket header
            Text(
              'DOLO SETTLEMENT SLIP',
              style: AppTypography.sectionLabel.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTypography.bodySemiBold.copyWith(color: muted),
            ),
            const SizedBox(height: 10),
            // Amount — whole rupees, integer display
            Text(
              'Rs ${rupees.format(amountRs)}',
              style: AppTypography.heroBalance.copyWith(
                fontSize: 32,
                color: primary,
              ),
            ),
            const SizedBox(height: 16),
            _Perforation(color: borderColor),
            const SizedBox(height: 16),
            // Paid by / recipient
            _Row(
                label: 'Paid By',
                value: paidBy,
                primary: primary,
                muted: muted),
            const SizedBox(height: 8),
            _Row(
              label: 'Recipient',
              value: recipient,
              primary: primary,
              muted: muted,
            ),
            // Per-member shares
            if (shares.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Perforation(color: borderColor),
              const SizedBox(height: 12),
              ...shares.map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: _Row(
                    label: s['name'] ?? '',
                    value:
                        'Rs ${rupees.format(int.tryParse(s['share'] ?? '') ?? 0)}',
                    primary: primary,
                    muted: muted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _Perforation(color: borderColor),
            const SizedBox(height: 16),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSettled
                    ? (isDark
                        ? AppColors.indigo.withValues(alpha: 0.18)
                        : AppColors.indigoSquircleBg)
                    : (isDark
                        ? AppColors.rose.withValues(alpha: 0.18)
                        : AppColors.roseSquircleBg),
                borderRadius: BorderRadius.circular(AppDimensions.pillRadius),
              ),
              child: Text(
                isSettled ? '✓ SETTLED' : '⏳ PENDING',
                style: AppTypography.caption.copyWith(
                  color: isSettled
                      ? (isDark
                          ? AppColors.indigoTextDark
                          : AppColors.indigoTextLight)
                      : (isDark
                          ? AppColors.roseTextDark
                          : AppColors.roseTextLight),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Auto-purge note
            Text(
              'Auto-purge in 7 days',
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the 2px dashed outline of the ticket (Design System §3.5).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  static const double _strokeWidth = 2;
  static const double _dash = 6;
  static const double _gap = 4;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    const inset = _strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          inset, inset, size.width - _strokeWidth, size.height - _strokeWidth),
      Radius.circular(radius),
    );

    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0, metric.length).toDouble();
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += _dash + _gap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Horizontal dashed perforation line between ticket sections.
class _Perforation extends StatelessWidget {
  final Color color;
  const _Perforation({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 6.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dash, height: 1.5, color: color),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color primary;
  final Color muted;
  const _Row({
    required this.label,
    required this.value,
    required this.primary,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySemiBold.copyWith(color: muted)),
        Text(
          value,
          style: AppTypography.rupeeAmount.copyWith(
            fontSize: 14,
            color: primary,
          ),
        ),
      ],
    );
  }
}
