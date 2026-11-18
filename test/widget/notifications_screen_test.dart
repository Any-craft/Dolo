import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/core/constants/reminder_tones.dart';
import 'package:dolo/features/settings/presentation/screens/notifications_screen.dart';

/// In-memory notifier: no database access during widget tests.
class TestReminderNotifier extends ReminderSettingsNotifier {
  TestReminderNotifier() : super(const ReminderSettings());

  ReminderSettings get _cur => state.value!;

  @override
  Future<bool> setRemindersEnabled(bool enabled) async {
    state = AsyncValue.data(_cur.copyWith(remindersEnabled: enabled));
    return true;
  }

  @override
  Future<bool> setFrequency(ReminderFrequency frequency) async {
    state = AsyncValue.data(_cur.copyWith(frequency: frequency));
    return true;
  }

  @override
  Future<bool> setReminderTime(TimeOfDay time) async {
    state = AsyncValue.data(_cur.copyWith(
      reminderTime: '${time.hour}:${time.minute}',
    ));
    return true;
  }

  @override
  Future<bool> setTone(ReminderTone tone) async {
    state = AsyncValue.data(_cur.copyWith(tone: tone));
    return true;
  }

  @override
  Future<bool> setAutoCopyRaast(bool enabled) async {
    state = AsyncValue.data(_cur.copyWith(autoCopyRaast: enabled));
    return true;
  }
}

void main() {
  late TestReminderNotifier notifier;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    notifier = TestReminderNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderSettingsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders sections, toggle and the three tone presets',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Reminders & Notifications'), findsOneWidget);

    expect(find.text('KHATA REMINDERS'), findsOneWidget);
    expect(find.text('Local push reminders'), findsOneWidget);

    expect(find.text('WHATSAPP REMINDER TONE'), findsOneWidget);
    expect(find.text('Friendly'), findsOneWidget);
    expect(find.text('Campus Urdu'), findsOneWidget);
    expect(find.text('Firm'), findsOneWidget);
    expect(
      find.text('"Bhai, woh Rs 1,200 yaad hai? Settle kar do yaar"'),
      findsOneWidget,
    );

    expect(find.text('PAYMENT SHARING'), findsOneWidget);
    expect(find.text('Auto-attach Raast ID to reminder text'), findsOneWidget);
  });

  testWidgets('frequency and time only appear when reminders are on',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Frequency'), findsNothing);
    expect(find.text('Reminder time'), findsNothing);

    await tester.tap(find.text('Local push reminders'));
    await tester.pumpAndSettle();

    expect(notifier.state.value!.remindersEnabled, isTrue);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(notifier.state.value!.frequency, ReminderFrequency.weekly);
  });

  testWidgets('tapping a tone saves it and shows a preview dialog',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Firm'));
    await tester.pumpAndSettle();

    expect(notifier.state.value!.tone, ReminderTone.firm);
    expect(find.text('📋  Firm tone saved'), findsOneWidget);
    expect(
      find.text(
          'Payment of Rs 1,200 is overdue. Please settle at your earliest.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('📋  Firm tone saved'), findsNothing);
  });

  test('ReminderTone.message formats rupees and appends Raast ID', () {
    expect(
      ReminderTone.friendly.message(9100),
      'Hey! Just a reminder about the Rs 9,100 from our last hangout 😊',
    );
    expect(
      ReminderTone.firm.message(450, raastId: '03001234567'),
      'Payment of Rs 450 is overdue. Please settle at your earliest.\n'
      'Raast ID: 03001234567',
    );
    expect(ReminderTone.fromId('nonsense'), ReminderTone.friendly);
  });
}
