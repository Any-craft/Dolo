import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/core/providers/appearance_provider.dart';
import 'package:dolo/core/theme/app_theme.dart';
import 'package:dolo/core/theme/theme_reveal.dart';
import 'package:dolo/core/theme/theme_switch.dart';

void main() {
  Widget app(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ref.watch(themeModeProvider),
            // Reduced motion takes the instant path (no screen snapshot).
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: ThemeReveal(child: child!),
            ),
            home: const Scaffold(body: Center(child: ThemeSwitch())),
          ),
        ),
      );

  testWidgets('ThemeSwitch flips light to dark and back', (tester) async {
    final container = ProviderContainer(
      overrides: [themeModeProvider.overrideWith((ref) => ThemeMode.light)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(app(container));
    expect(
      tester.getSemantics(find.byType(ThemeSwitch)),
      matchesSemantics(
        label: 'Dark mode',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(ThemeSwitch));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.dark);

    await tester.tap(find.byType(ThemeSwitch));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
