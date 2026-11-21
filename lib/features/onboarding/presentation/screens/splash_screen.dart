import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Two-second opening animation: five rupee notes drop onto a growing
/// stack, a coin lands on top and glints, then the Dolo wordmark rises in.
///
/// Calls [onFinished] once the animation (and [minDuration]) is over.
/// With "reduce motion" on, the finished stack is shown briefly instead.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    this.minDuration = const Duration(milliseconds: 2000),
  });

  final VoidCallback onFinished;
  final Duration minDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.minDuration);
  bool _started = false;

  static const int _notes = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _c.value = 1;
      Future.delayed(const Duration(milliseconds: 700), _finish);
    } else {
      _c.forward().whenComplete(_finish);
    }
  }

  void _finish() {
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0→1 progress of [_c] inside the [start, end] window (fractions of 2s).
  double _seg(double start, double end, [Curve curve = Curves.linear]) {
    final t = ((_c.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              // Soft glow behind the stack
              Opacity(
                opacity: _seg(0.0, 0.5),
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tallest note rests at top 118 + 84 high (+ tilt), so 214.
                  SizedBox(width: 220, height: 214, child: _buildStack()),
                  const SizedBox(height: 28),
                  _buildWordmark(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStack() {
    final children = <Widget>[];

    // Notes: each falls in turn and lands with a small bounce.
    for (var i = 0; i < _notes; i++) {
      final start = 0.05 + i * 0.09;
      final t = _seg(start, start + 0.18, Curves.easeOutBack);
      final appear = _seg(start, start + 0.05);
      final restY = 118.0 - i * 13; // pile grows upwards
      final tilt = [-0.07, 0.05, -0.03, 0.06, -0.015][i];
      children.add(
        Positioned(
          left: 22,
          top: restY - (1 - t) * 260,
          child: Opacity(
            opacity: appear,
            child: Transform.rotate(
              angle: tilt + (1 - t) * (i.isEven ? -0.4 : 0.4),
              child: _Banknote(shade: i),
            ),
          ),
        ),
      );
    }

    // Coin drops last, then a glint sweeps across it.
    final coinT = _seg(0.55, 0.72, Curves.bounceOut);
    final glint = _seg(0.74, 0.9);
    children.add(
      Positioned(
        right: 14,
        top: 24 - (1 - coinT) * 220,
        child: Opacity(
          opacity: _seg(0.55, 0.58),
          child: _Coin(glint: glint, spin: coinT),
        ),
      ),
    );

    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _buildWordmark() {
    final t = _seg(0.62, 0.86, Curves.easeOutCubic);
    final tag = _seg(0.74, 0.95, Curves.easeOut);
    return Column(
      children: [
        Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: Text(
              'Dolo',
              style: AppTypography.heroBalance.copyWith(
                color: Colors.white,
                fontSize: 46,
                letterSpacing: -1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: tag,
          child: Text(
            'Hisaab saaf, dosti pakki',
            style: AppTypography.bodySemiBold.copyWith(
              color: AppColors.onCockpitMuted,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

/// A stylised green rupee note.
class _Banknote extends StatelessWidget {
  const _Banknote({required this.shade});
  final int shade;

  static const _fills = [
    Color(0xFF0B6B3E),
    Color(0xFF0E7C48),
    Color(0xFF108C51),
    Color(0xFF14A05D),
    Color(0xFF1DB86C),
  ];

  @override
  Widget build(BuildContext context) {
    final fill = _fills[shade % _fills.length];
    return Container(
      width: 176,
      height: 84,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _corner('Rs'),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'D',
                style: AppTypography.heroBalance.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 0,
                ),
              ),
            ),
            _corner('500'),
          ],
        ),
      ),
    );
  }

  Widget _corner(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: AppTypography.bodySemiBold.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

/// Gold coin with a light glint that sweeps across once.
class _Coin extends StatelessWidget {
  const _Coin({required this.glint, required this.spin});
  final double glint;
  final double spin;

  @override
  Widget build(BuildContext context) {
    // A quick flip while falling: squash horizontally, then settle round.
    final flip = math.cos(spin * math.pi * 2).abs().clamp(0.25, 1.0);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(spin >= 1 ? 1 : flip, 1, 1),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.35),
            colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFB45309)],
            stops: [0.0, 0.7, 1.0],
          ),
          border: Border.all(color: const Color(0xFFFCD34D), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              blurRadius: 14,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Rs',
                style: AppTypography.heroBalance.copyWith(
                  color: const Color(0xFF92400E),
                  fontSize: 17,
                  letterSpacing: 0,
                ),
              ),
              // Glint
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(-70 + glint * 140, 0),
                  child: Transform.rotate(
                    angle: 0.5,
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 90,
                        color: Colors.white.withValues(
                          alpha: glint > 0 && glint < 1 ? 0.55 : 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
