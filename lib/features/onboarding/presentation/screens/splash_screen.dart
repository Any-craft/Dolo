import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../widgets/flying_money.dart';

/// Three-second opening animation on a white, faintly green background:
/// the money stack pops in at the centre, two wings fly in from opposite
/// corners of the screen and attach, a sunlight glint sweeps across the
/// notes from top-right to bottom-left, and the Dolo wordmark appears.
///
/// Calls [onFinished] when done. With "reduce motion" on, the finished
/// logo is shown briefly instead.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    this.minDuration = const Duration(milliseconds: 3000),
  });

  final VoidCallback onFinished;
  final Duration minDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// Logo geometry, relative to the centre of the money stack.
const Size _moneySize = Size(230, 170);
const Size _wingSize = Size(124, 104);
// Where each wing's root sits once attached.
const Offset _leftRoot = Offset(-52, -18);
const Offset _rightRoot = Offset(58, 22);
// Root position inside the wing's own box (see WingPainter).
const Offset _rootInBox = Offset(124 * 0.86, 104 * 0.84);

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.minDuration);
  bool _started = false;

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

  /// Progress of the timeline inside [start, end] (fractions of 3 s).
  double _seg(double start, double end, [Curve curve = Curves.linear]) {
    final t = ((_c.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(
          child: DecoratedBox(
            // White with just a breath of green towards the edges.
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.1,
                colors: [Colors.white, Color(0xFFF3FBF6), Color(0xFFE6F6EC)],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Stack(
                  children: [
                    Center(child: _buildLogo(constraints.biggest)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 56,
                      child: _buildLoader(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Size screen) {
    // Money pops in, then gives a small bounce when the wings attach.
    final appear = _seg(0.0, 0.22, Curves.easeOutBack);
    final attachPop = math.sin(_seg(0.58, 0.72) * math.pi) * 0.06;
    // Gentle float once assembled.
    final float = math.sin(_seg(0.6, 1.0) * math.pi * 2) * 4;

    final wordmark = _seg(0.6, 0.85, Curves.easeOutCubic);
    final tagline = _seg(0.72, 0.95, Curves.easeOut);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(0, -float),
          child: SizedBox(
            width: _moneySize.width,
            height: _moneySize.height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _wing(screen, left: true), // behind the notes
                Opacity(
                  opacity: _seg(0.0, 0.12),
                  child: Transform.scale(
                    scale: (0.7 + 0.3 * appear) + attachPop,
                    child: _shinyMoney(),
                  ),
                ),
                _wing(screen, left: false), // in front of the notes
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        Opacity(
          opacity: wordmark,
          child: Transform.translate(
            offset: Offset(0, (1 - wordmark) * 14),
            child: Text(
              'Dolo',
              style: AppTypography.heroBalance.copyWith(
                color: AppColors.cockpitGradientEnd,
                fontSize: 44,
                letterSpacing: -1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: tagline,
          child: Text(
            'Hisaab saaf, dosti pakki',
            style: AppTypography.bodySemiBold.copyWith(
              color: AppColors.textLightMuted,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  /// Notes with a sunlight band sliding from top-right to bottom-left.
  Widget _shinyMoney() {
    final p = _seg(0.62, 0.92, Curves.easeInOut);
    final active = p > 0 && p < 1;
    // Band position along the diagonal, from just off one corner to the other.
    final pos = -0.25 + p * 1.5;
    double s(double v) => v.clamp(0.0, 1.0);

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: active ? 0.75 : 0),
          Colors.white.withValues(alpha: 0),
        ],
        stops: [s(pos - 0.14), s(pos), s(pos + 0.14)],
      ).createShader(rect),
      child: const CustomPaint(
        size: _moneySize,
        painter: MoneyStackPainter(),
      ),
    );
  }

  /// A wing that flies in from a screen corner (left: top-left, right:
  /// bottom-right), flapping hard on the way and gently once attached.
  Widget _wing(Size screen, {required bool left}) {
    final fly = _seg(left ? 0.12 : 0.18, left ? 0.58 : 0.62, Curves.easeOutCubic);
    final attached = fly >= 1;

    // Start just beyond the screen corner, measured from the logo centre.
    final start = left
        ? Offset(-screen.width / 2 - 140, -screen.height / 2 - 120)
        : Offset(screen.width / 2 + 140, screen.height / 2 + 120);
    final end = left ? _leftRoot : _rightRoot;
    // Curve the path a little so it swoops in rather than sliding.
    final straight = Offset.lerp(start, end, fly)!;
    final swoop = math.sin(fly * math.pi) * 60 * (left ? 1 : -1);
    final root = straight + Offset(swoop, -swoop * 0.4);

    // Flap: fast and wide in flight, slow and small once attached.
    final t = _c.value;
    final flap = attached
        ? math.sin(t * math.pi * 6) * 0.07
        : math.sin(t * math.pi * 22) * 0.38;

    // Mirrored wing for the right side, turned to point down-right.
    final baseTilt = left ? 0.0 : 0.95;
    final rootInBox = left
        ? _rootInBox
        : Offset(_wingSize.width - _rootInBox.dx, _rootInBox.dy);
    final rootAlign = Alignment(
      rootInBox.dx / _wingSize.width * 2 - 1,
      rootInBox.dy / _wingSize.height * 2 - 1,
    );

    final boxTopLeft = root - rootInBox;
    return Positioned(
      left: _moneySize.width / 2 + boxTopLeft.dx,
      top: _moneySize.height / 2 + boxTopLeft.dy,
      child: Opacity(
        opacity: _seg(left ? 0.12 : 0.18, left ? 0.2 : 0.26),
        child: Transform.rotate(
          alignment: rootAlign,
          angle: baseTilt + (left ? -flap : flap),
          child: CustomPaint(
            size: _wingSize,
            painter: WingPainter(mirror: !left),
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    final show = _seg(0.15, 0.35);
    final t = _c.value * 3; // three pulses over the splash
    return Opacity(
      opacity: show,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.mint.withValues(
                      alpha: 0.3 +
                          0.7 *
                              (0.5 +
                                  0.5 * math.sin((t - i * 0.18) * math.pi * 2)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Getting your khata ready',
            style: AppTypography.caption.copyWith(
              color: AppColors.textLightMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
