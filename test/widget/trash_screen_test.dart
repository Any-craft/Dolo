import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/features/trash/presentation/screens/trash_screen.dart';

void main() {
  testWidgets('TrashScreen renders empty state when no trashed items exist', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trashedExpensesProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: TrashScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Trash'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.text('Trash is empty'), findsOneWidget);
    expect(
      find.text('Deleted expenses stay here for 30 days before permanent deletion.'),
      findsOneWidget,
    );
  });

  testWidgets('TrashScreen renders trashed items with days left and amount', (WidgetTester tester) async {
    final now = DateTime.now();
    final fiveDaysAgo = now.subtract(const Duration(days: 5)).toIso8601String();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trashedExpensesProvider.overrideWith((ref) => Future.value([
            {
              'id': 'exp_1',
              'title': 'Hostel Chai & Samosa',
              'category': 'Food',
              'total_amount': 450,
              'is_trashed': 1,
              'trashed_at': fiveDaysAgo,
              'receipt_image_path': null,
            },
            {
              'id': 'exp_2',
              'title': 'Uber to Campus',
              'category': 'Transport',
              'total_amount': 1200,
              'is_trashed': 1,
              'trashed_at': now.toIso8601String(),
              'receipt_image_path': null,
            },
          ])),
        ],
        child: const MaterialApp(
          home: TrashScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Hostel Chai & Samosa'), findsOneWidget);
    expect(find.text('Food • 25 days left'), findsOneWidget);
    expect(find.text('Rs 450'), findsOneWidget);

    expect(find.text('Uber to Campus'), findsOneWidget);
    expect(find.text('Transport • 30 days left'), findsOneWidget);
    expect(find.text('Rs 1200'), findsOneWidget);
  });
}
