import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/features/settings/presentation/screens/storage_sync_screen.dart';

void main() {
  testWidgets('StorageSyncScreen renders sections, purge options, export and sync CTAs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StorageSyncScreen(),
      ),
    );

    // Let any async loading complete
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Storage & Sync'), findsOneWidget);

    // Verify Section Headers
    expect(find.text('AUTO-PURGE'), findsOneWidget);
    expect(find.text('DATA EXPORT'), findsOneWidget);
    expect(find.text('GROUP SYNC'), findsOneWidget);

    // Verify Auto-Purge items
    expect(find.text('Delete receipt images after'), findsOneWidget);
    expect(find.text('Delete expense records after'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('14 days'), findsOneWidget);
    expect(find.text('Never'), findsWidgets);

    // Verify Data Export
    expect(find.text('Export all data as CSV'), findsOneWidget);

    // Verify Group Sync
    expect(find.text('Offline-first • Zero server tracking'), findsOneWidget);
    expect(find.text('Unsynced changes'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
  });
}
