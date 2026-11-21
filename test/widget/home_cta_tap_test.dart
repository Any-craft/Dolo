import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/features/navigation/main_scaffold.dart';
import 'package:dolo/features/home/presentation/providers/dashboard_provider.dart';
import 'package:dolo/features/home/domain/models/dashboard_summary.dart';

void main() {
  testWidgets('MainScaffold + Add expense navigates to AddExpenseScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSummaryProvider.overrideWith((ref) async {
            return const DashboardSummary(
              userName: 'Test User',
              netStanding: 100,
              totalOwed: 200,
              totalOwe: 100,
              settledCount: 1,
              feedItems: [],
            );
          }),
          filteredFeedProvider.overrideWith((ref) => []),
        ],
        child: const MaterialApp(
          home: MainScaffold(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify + Add expense button navigates to AddExpenseScreen
    expect(find.text('Add expense'), findsOneWidget);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    expect(find.text('New expense'), findsOneWidget);

    // Pop back to home
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 2. Verify Settle up button opens sheet
    expect(find.text('Settle up'), findsOneWidget);
    await tester.tap(find.text('Settle up'));
    await tester.pumpAndSettle();
    expect(find.text('with Sheeda'), findsOneWidget);

    // Dismiss sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 3. Verify Bottom Navigation to Groups
    await tester.tap(find.byIcon(Icons.group_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Hostel Gang'), findsOneWidget);

    // 4. Verify Bottom Navigation to Profile
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();
    expect(find.text('PAY ME QR'), findsOneWidget);
  });
}
