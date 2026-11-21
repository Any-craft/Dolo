import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_settings_store.dart';
import '../../../core/database/tables.dart';
import '../../home/presentation/providers/dashboard_provider.dart';
import '../../navigation/main_scaffold.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';

/// `app_settings` key set once the welcome flow is finished.
const String kOnboardingDoneKey = 'onboarding_done';

enum _Phase { splash, welcome, home }

/// What the app shows on launch: the splash animation, then the welcome
/// flow on first run, then the main tabs.
class AppStartGate extends ConsumerStatefulWidget {
  const AppStartGate({super.key});

  @override
  ConsumerState<AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends ConsumerState<AppStartGate> {
  _Phase _phase = _Phase.splash;
  late final Future<bool> _needsWelcome = _checkNeedsWelcome();

  /// First run = the welcome flow was never finished and the user never set
  /// a name (people who already set one in Profile skip it).
  static Future<bool> _checkNeedsWelcome() async {
    final done = await AppSettingsStore.read(kOnboardingDoneKey);
    if (done == 'true') return false;
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery(
        'SELECT name FROM "${DbTables.contacts}" WHERE id = ? LIMIT 1',
        ['user_self'],
      );
      final name = rows.isEmpty ? '' : (rows.first['name'] as String? ?? '');
      final hasName = name.trim().isNotEmpty && name.trim().toLowerCase() != 'you';
      if (hasName) {
        await _markDone();
        return false;
      }
    } catch (_) {
      // Database unavailable: still show the welcome flow.
    }
    return true;
  }

  static Future<void> _markDone() async {
    try {
      await AppSettingsStore.write(kOnboardingDoneKey, 'true');
    } catch (_) {}
  }

  Future<void> _afterSplash() async {
    final needsWelcome = await _needsWelcome;
    if (!mounted) return;
    setState(() => _phase = needsWelcome ? _Phase.welcome : _Phase.home);
  }

  Future<void> _afterWelcome() async {
    await _markDone();
    // Home greets the user by the name they just entered.
    ref.invalidate(dashboardSummaryProvider);
    if (mounted) setState(() => _phase = _Phase.home);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_phase) {
      _Phase.splash => SplashScreen(
          key: const ValueKey('splash'),
          onFinished: _afterSplash,
        ),
      _Phase.welcome => WelcomeScreen(
          key: const ValueKey('welcome'),
          onDone: _afterWelcome,
        ),
      _Phase.home => const MainScaffold(key: ValueKey('home')),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }
}
