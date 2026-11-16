import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolo/features/home/domain/models/dashboard_summary.dart';
import 'package:dolo/features/home/presentation/providers/dashboard_provider.dart';

void main() {
  group('Dashboard Provider & Filtering Tests', () {
    test('filteredFeedProvider filters items accurately by category', () async {
      final container = ProviderContainer(
        overrides: [
          dashboardSummaryProvider.overrideWith(
            (ref) => Future.value(DashboardSummary.mock()),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the future provider to resolve
      await container.read(dashboardSummaryProvider.future);

      // Default 'All' filter returns all 4 items
      expect(container.read(activeFilterProvider), 'All');
      expect(container.read(filteredFeedProvider).length, 4);

      // Filter by 'Friends'
      container.read(activeFilterProvider.notifier).state = 'Friends';
      final friendItems = container.read(filteredFeedProvider);
      expect(friendItems.length, 1);
      expect(friendItems.first.type, FeedItemType.friend);
      expect(friendItems.first.title, 'Sheeda');

      // Filter by 'Groups'
      container.read(activeFilterProvider.notifier).state = 'Groups';
      final groupItems = container.read(filteredFeedProvider);
      expect(groupItems.length, 1);
      expect(groupItems.first.type, FeedItemType.group);
      expect(groupItems.first.title, 'Hostel Gang');

      // Filter by 'Pending'
      container.read(activeFilterProvider.notifier).state = 'Pending';
      final pendingItems = container.read(filteredFeedProvider);
      expect(pendingItems.length, 3);
      expect(pendingItems.every((item) => !item.isSettled), isTrue);
    });

    test('DashboardSummary calculations adhere to whole-rupee int rules', () {
      final summary = DashboardSummary.mock();
      expect(summary.totalOwed, isA<int>());
      expect(summary.totalOwe, isA<int>());
      expect(summary.netStanding, isA<int>());
      expect(summary.netStanding, summary.totalOwed - summary.totalOwe);
    });
  });
}
