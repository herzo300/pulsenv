import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soobshio/screens/map/widgets/map_glass_panel.dart';
import 'package:soobshio/theme/pulse_colors.dart';

void main() {
  group('MapGlassPanel', () {
    Widget buildTestWidget({Widget? child, Color? fillColor}) {
      return MaterialApp(
        home: Scaffold(
          body: MapGlassPanel(
            fillColor: fillColor,
            child: child ?? const Text('Test Content'),
          ),
        ),
      );
    }

    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('renders with custom fill color', (tester) async {
      await tester
          .pumpWidget(buildTestWidget(fillColor: PulseColors.surfaceSoft));
      expect(find.byType(MapGlassPanel), findsOneWidget);
    });

    testWidgets('contains BackdropFilter for glass effect', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('renders complex child widgets', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: Column(
          children: const [
            Icon(Icons.map),
            Text('Map Panel'),
            SizedBox(height: 10),
            Text('Sub-content'),
          ],
        ),
      ));

      expect(find.text('Map Panel'), findsOneWidget);
      expect(find.text('Sub-content'), findsOneWidget);
      expect(find.byIcon(Icons.map), findsOneWidget);
    });
  });
}
