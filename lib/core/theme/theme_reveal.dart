import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Wraps the app so a theme change is uncovered by a circle that grows from
/// a point on screen (the theme switch).
///
/// How it works: snapshot the screen in the old theme, switch the theme
/// underneath, then draw the snapshot on top with a growing hole cut out of
/// it. Only one image is animated, so it stays smooth on low-end phones.
/// With "reduce motion" on, or if the snapshot fails, the theme just switches.
class ThemeReveal extends StatefulWidget {
  const ThemeReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
  });

  final Widget child;
  final Duration duration;

  static ThemeRevealState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ThemeRevealState>();

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  ui.Image? _snapshot;
  Offset _center = Offset.zero;

  bool get isRevealing => _snapshot != null;

  /// Captures the screen, calls [applyChange] to switch the theme, then
  /// uncovers the new theme in a circle growing from [center] (global).
  Future<void> reveal({
    required Offset center,
    required VoidCallback applyChange,
  }) async {
    if (_snapshot != null) return; // ignore taps mid-animation

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    ui.Image? image;
    if (!reduceMotion) {
      try {
        final boundary = _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          image = await boundary.toImage(
            pixelRatio: MediaQuery.devicePixelRatioOf(context),
          );
        }
      } catch (_) {
        image = null;
      }
    }

    if (!mounted) {
      image?.dispose();
      return;
    }
    if (image == null) {
      applyChange();
      return;
    }

    final box = context.findRenderObject() as RenderBox;
    setState(() {
      _snapshot = image;
      _center = box.globalToLocal(center);
    });
    applyChange();

    try {
      await _controller.forward(from: 0);
    } finally {
      if (mounted) setState(() => _snapshot = null);
      // Dispose after the frame that stops painting it.
      final done = image;
      WidgetsBinding.instance.addPostFrameCallback((_) => done.dispose());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final maxRadius = _farthestCorner(_center, size);
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t =
                          Curves.easeInOutCubic.transform(_controller.value);
                      return ClipPath(
                        clipper: _HoleClipper(_center, maxRadius * t),
                        child: child,
                      );
                    },
                    child: RawImage(image: snapshot, fit: BoxFit.fill),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  static double _farthestCorner(Offset c, Size s) {
    final dx = math.max(c.dx, s.width - c.dx);
    final dy = math.max(c.dy, s.height - c.dy);
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Everything except a circle of [radius] around [center].
class _HoleClipper extends CustomClipper<Path> {
  _HoleClipper(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_HoleClipper old) =>
      old.radius != radius || old.center != center;
}
