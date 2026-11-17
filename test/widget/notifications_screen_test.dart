import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/features/settings/presentation/screens/notifications_screen.dart';

class TestReminderNotifier extends ReminderSettingsNotifier {
  TestReminderNotifier()
      : super(const ReminderSettings(
          dailyReminderEnabled: false,
          reminderTime: '21:00',
          nudgeFrequency: 'standard',
          autoCopyRaast: false,
        ));

  @override
  Future<bool> setDailyEnabled(bool enabled) async {
    state = AsyncValue.data(state.value!.copyWith(dailyReminderEnabled: enabled));
    return true;
  }

  @override
  Future<bool> setReminderTime(TimeOfDay time) async {
    state = AsyncValue.data(state.value!.copyWith(
      reminderTime: '${time.hour}:${time.minute}',
    ));
    return true;
  }

  @override
  Future<bool> setNudge(String frequency) async {
    state = AsyncValue.data(state.value!.copyWith(nudgeFrequency: frequency));
    return true;
  }

  @override
  Future<bool> setAutoCopyRaast(bool enabled) async {
    state = AsyncValue.data(state.value!.copyWith(autoCopyRaast: enabled));
    return true;
  }
}

void main() {
  testWidgets('NotificationsScreen renders sections, toggles and tones', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderSettingsProvider.overrideWith((ref) => TestReminderNotifier()),
        ],
        child: const MaterialApp(
          home: NotificationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Reminders & Notifications'), findsOneWidget);

    // Verify Sections
    expect(find.text('KHATA REMINDERS'), findsOneWidget);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);

    expect(find.text('NUDGE TONE'), findsOneWidget);
    expect(find.text('Gentle'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Strict'), findsOneWidget);

    expect(find.text('PAYMENT SHARING'), findsOneWidget);
    expect(find.text('Auto-attach Raast ID to reminder text'), findsOneWidget);

    // Toggle daily reminder
    await tester.tap(find.text('Daily reminder'));
    await tester.pumpAndSettle();

    // Tap Gentle nudge tone
    await tester.tap(find.text('Gentle'));
    await tester.pumpAndSettle();

    // Tap Auto-attach Raast ID
    await tester.tap(find.text('Auto-attach Raast ID to reminder text'));
    await tester.pumpAndSettle();
  });
}
