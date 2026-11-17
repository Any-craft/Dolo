import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/app.dart';
import 'package:dolo/core/constants/app_icons_config.dart';
import 'package:dolo/core/providers/app_icon_provider.dart';
import 'package:dolo/features/settings/presentation/screens/appearance_screen.dart';

void main() {
  testWidgets('AppearanceScreen renders theme choices and app icons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppearanceScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Appearance & App Icon'), findsOneWidget);

    // Verify Theme Section
    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('System Default'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Light Mode'), findsOneWidget);

    // Verify App Icon Section
    expect(find.text('APP ICON'), findsOneWidget);
    expect(find.text('Interlocking Coins'), findsOneWidget);
    expect(find.text('Aurora Glow'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Tap Light Mode
    await tester.tap(find.text('Light Mode'));
    await tester.pumpAndSettle();

    // Tap Aurora Glow icon card
    await tester.tap(find.text('Aurora Glow'));
    await tester.pumpAndSettle();
  });
}
