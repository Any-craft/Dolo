import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/core/database/app_database.dart';
import 'package:dolo/core/theme/app_theme.dart';
import 'package:dolo/features/groups/presentation/widgets/group_sign_in.dart';
import 'package:dolo/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:dolo/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:dolo/features/profile/presentation/providers/profile_provider.dart';

/// Records the saved profile instead of writing to SQLite.
class _FakeProfile extends UserProfileNotifier {
  _FakeProfile() : super(AppDatabase.instance);
  Map<String, String>? saved;

  @override
  Future<void> updateProfile({
    required String name,
    required String phone,
    required String raastId,
    String bankName = 'SadaPay',
  }) async {
    saved = {'name': name, 'phone': phone, 'raast': raastId};
  }
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Splash shows the wordmark and finishes after ~2 seconds',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: SplashScreen(onFinished: () => finished = true),
    ));

    await tester.pump(const Duration(milliseconds: 1000));
    expect(finished, isFalse);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(finished, isTrue);
    expect(find.text('Dolo'), findsOneWidget);
    expect(find.text('Hisaab saaf, dosti pakki'), findsOneWidget);
  });

  testWidgets('Welcome flow needs a name, then saves the profile',
      (tester) async {
    _phoneSize(tester);
    final fake = _FakeProfile();
    var done = false;

    await tester.pumpWidget(ProviderScope(
      overrides: [userProfileProvider.overrideWith((ref) => fake)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: WelcomeScreen(onDone: () => done = true),
      ),
    ));

    expect(find.text('Your khata, in your pocket'), findsOneWidget);

    // Skip straight to the profile form.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('What should we call you?'), findsOneWidget);

    // Empty name is rejected.
    await tester.tap(find.text('Start using Dolo'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name so friends know who sent it'),
        findsOneWidget);
    expect(done, isFalse);

    await tester.enterText(
        find.byKey(const ValueKey('onboarding_name')), 'Talha');
    await tester.enterText(
        find.byKey(const ValueKey('onboarding_phone')), '0300 1234567');
    await tester.tap(find.text('Start using Dolo'));
    // The spinner keeps animating until the app swaps screens, so pump frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(done, isTrue);
    expect(fake.saved, {'name': 'Talha', 'phone': '0300 1234567', 'raast': ''});
  });

  testWidgets('Group sign-in sheet offers Google and a local option',
      (tester) async {
    _phoneSize(tester);
    var openedLocal = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showGroupSignInSheet(
                context,
                onContinueLocal: () => openedLocal = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Use on this phone only'));
    await tester.pumpAndSettle();
    expect(openedLocal, isTrue);
  });
}
