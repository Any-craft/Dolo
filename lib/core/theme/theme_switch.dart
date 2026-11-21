import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_settings_store.dart';
import '../providers/appearance_provider.dart';
import 'theme_reveal.dart';

/// Day/night sliding switch for the header.
///
/// Light: a sun on a sky track with a cloud. Dark: a moon on a night track
/// with stars. Tapping it flips light <-> dark, saves the choice, and lets
/// [ThemeReveal] uncover the new theme in a circle from the switch.
class ThemeSwitch extends ConsumerWidget {
  const ThemeSwitch({super.key});

  static const double _width = 64;
  static const double _height = 34;
  static const double _knob = 26;
  static const Duration _duration = Duration(milliseconds: 450);

  static const _dayTrack = [Color(0xFF7DD3FC), Color(0xFF38BDF8)];
  static const _nightTrack = [Color(0xFF1E1B4B), Color(0xFF3730A3)];

  void _toggle(BuildContext context, WidgetRef ref, bool isDark) {
    HapticFeedback.lightImpact();
    final next = isDark ? ThemeMode.light : ThemeMode.dark;

    void apply() {
      ref.read(themeModeProvider.notifier).state = next;
      AppSettingsStore.write(AppearanceKeys.themeMode, themeModeToId(next))
          .then((_) {}, onError: (_) {});
    }

    final reveal = ThemeReveal.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (reveal == null || box == null || !box.hasSize) {
      apply();
      return;
    }
    final center = box.localToGlobal(box.size.center(Offset.zero));
    reveal.reveal(center: center, applyChange: apply);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      toggled: isDark,
      label: 'Dark mode',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggle(context, ref, isDark),
        child: Padding(
          // Grows the tap target to 48px tall without changing the look.
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeInOut,
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_height / 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark ? _nightTrack : _dayTrack,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_height / 2),
              child: Stack(
                children: [
                  // Stars (night)
                  ..._stars.map(
                    (s) => Positioned(
                      left: s.$1,
                      top: s.$2,
                      child: AnimatedOpacity(
                        duration: _duration,
                        opacity: isDark ? 1 : 0,
                        child: Container(
                          width: s.$3,
                          height: s.$3,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Cloud (day)
                  AnimatedPositioned(
                    duration: _duration,
                    curve: Curves.easeOut,
                    right: isDark ? -24 : 6,
                    bottom: 6,
                    child: AnimatedOpacity(
                      duration: _duration,
                      opacity: isDark ? 0 : 1,
                      child: const _Cloud(),
                    ),
                  ),
                  // Sun / moon knob
                  AnimatedAlign(
                    duration: _duration,
                    curve: Curves.easeOutBack,
                    alignment:
                        isDark ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: AnimatedSwitcher(
                        duration: _duration,
                        transitionBuilder: (child, anim) => RotationTransition(
                          turns: Tween(begin: 0.5, end: 1.0).animate(anim),
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: isDark
                            ? const _Moon(key: ValueKey('moon'), size: _knob)
                            : const _Sun(key: ValueKey('sun'), size: _knob),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // (left, top, diameter)
  static const _stars = [
    (9.0, 8.0, 2.5),
    (18.0, 18.0, 1.8),
    (25.0, 7.0, 1.5),
    (12.0, 22.0, 1.2),
  ];
}

class _Sun extends StatelessWidget {
  const _Sun({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withOpacity(0.7),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _Moon extends StatelessWidget {
  const _Moon({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget crater(double l, double t, double d) => Positioned(
          left: l,
          top: t,
          child: Container(
            width: d,
            height: d,
            decoration: const BoxDecoration(
              color: Color(0xFFCBD5E1),
              shape: BoxShape.circle,
            ),
          ),
        );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F5F9),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          crater(6, 7, 6),
          crater(15, 4, 3.5),
          crater(14, 15, 4.5),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  const _Cloud();

  @override
  Widget build(BuildContext context) {
    Widget puff(double l, double t, double d) => Positioned(
          left: l,
          top: t,
          child: Container(
            width: d,
            height: d,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );

    return SizedBox(
      width: 22,
      height: 12,
      child: Stack(
        children: [
          puff(0, 4, 8),
          puff(5, 0, 11),
          puff(12, 3, 9),
        ],
      ),
    );
  }
}
