import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/features/settlement/presentation/screens/receipt_view_screen.dart';

void main() {
  testWidgets('ReceiptViewScreen renders cockpit, status badge, ticket, and Done CTA', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ReceiptViewScreen(
          peerId: 'peer_sheeda',
          peerName: 'Sheeda',
          amountRs: 1200,
          paymentMethod: 'Cash',
          isSettled: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('Settlement Receipt'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Verify Ticket details (TactileTicketReceipt)
    expect(find.text('✓ SETTLED'), findsOneWidget);
    expect(find.text('Auto-purge in 7 days'), findsOneWidget);
    expect(find.text('Settlement via Cash'), findsOneWidget);
    expect(find.text('Sheeda'), findsOneWidget);
    expect(find.text('Rs 1,200'), findsOneWidget);

    // Verify Actions
    expect(find.text('Share Receipt PNG'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('ReceiptViewScreen renders PENDING badge when isSettled is false', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ReceiptViewScreen(
          peerId: 'peer_sheeda',
          peerName: 'Sheeda',
          amountRs: 850,
          paymentMethod: 'Online Transfer',
          isSettled: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('⏳ PENDING'), findsOneWidget);
    expect(find.text('Settlement via Online Transfer'), findsOneWidget);
    expect(find.text('Rs 850'), findsOneWidget);
  });
}
