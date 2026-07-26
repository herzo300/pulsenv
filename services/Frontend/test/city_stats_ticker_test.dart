import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soobshio/screens/map/widgets/city_stats_ticker.dart';
import 'package:soobshio/theme/pulse_colors.dart';

void main() {
  group('CityStatsTicker', () {
    Widget buildTestWidget({
      int total = 24,
      int resolved = 18,
      int active = 6,
      List<int>? totalHistory,
      List<int>? resolvedHistory,
      List<int>? activeHistory,
    }) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: PulseColors.background,
          body: Center(
            child: CityStatsTicker(
              total: total,
              resolved: resolved,
              active: active,
              totalHistory: totalHistory,
              resolvedHistory: resolvedHistory,
              activeHistory: activeHistory,
            ),
          ),
        ),
      );
    }

    testWidgets('renders with basic stats', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should display all three stat labels
      expect(find.text('Сегодня'), findsOneWidget);
      expect(find.text('Решено'), findsOneWidget);
      expect(find.text('Работа'), findsOneWidget);

      // Should display values
      expect(find.text('24'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('renders with zero values', (tester) async {
      await tester.pumpWidget(buildTestWidget(total: 0, resolved: 0, active: 0));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets('renders with sparkline history data', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        total: 30,
        resolved: 25,
        active: 5,
        totalHistory: [10, 15, 20, 25, 30],
        resolvedHistory: [5, 10, 15, 20, 25],
        activeHistory: [5, 5, 5, 5, 5],
      ));
      await tester.pumpAndSettle();

      // Stats should still render correctly
      expect(find.text('30'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Sparkline CustomPaint widgets should exist
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with large numbers', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        total: 99999,
        resolved: 88888,
        active: 11111,
      ));
      await tester.pumpAndSettle();

      expect(find.text('99999'), findsOneWidget);
      expect(find.text('88888'), findsOneWidget);
      expect(find.text('11111'), findsOneWidget);
    });

    testWidgets('has BackdropFilter for glass effect', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Glass-morphism: should contain BackdropFilter
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('contains proper icons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });

    testWidgets('animation controller runs staggered entry', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Before animation settles, partial state
      await tester.pump(const Duration(milliseconds: 100));

      // Should still contain the widget tree
      expect(find.byType(CityStatsTicker), findsOneWidget);

      // Let animation complete
      await tester.pumpAndSettle();
      expect(find.text('24'), findsOneWidget);
    });
  });
}
