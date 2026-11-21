import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/appearance_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_reveal.dart';
import 'features/navigation/main_scaffold.dart';

export 'core/providers/appearance_provider.dart'
    show themeModeProvider, accentColorProvider;

class DoloApp extends ConsumerWidget {
  const DoloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider).color;

    return MaterialApp(
      title: 'Dolo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: accent),
      darkTheme: AppTheme.dark(accent: accent),
      themeMode: themeMode,
      // Lets the header's theme switch reveal the new theme in a circle.
      builder: (context, child) => ThemeReveal(child: child!),
      home: const MainScaffold(),
    );
  }
}
