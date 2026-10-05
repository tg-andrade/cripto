import 'package:cryptohub/models/price_history.dart';
import 'package:cryptohub/theme/app_theme.dart';
import 'package:cryptohub/utils/formatters.dart' as format;
import 'package:cryptohub/widgets/history_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _chart(List<PriceHistoryPoint> points) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 312, child: HistoryChart(points: points)),
    ),
  ),
);

List<PriceHistoryPoint> _points(List<double> prices) => [
  for (var index = 0; index < prices.length; index++)
    PriceHistoryPoint(
      time: DateTime(2026, 10, 4, 10 + index),
      close: prices[index],
    ),
];

void main() {
  for (final prices in <List<double>>[
    [0, 0],
    [-1, -20],
    [0, -1],
  ]) {
    testWidgets('only nonpositive prices $prices show an empty period', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_points(prices)));
      expect(find.text('Sem preços no período'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('history-chart-touch-target')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(HistoryChart),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final invalid in [0.0, -5.0]) {
    testWidgets('a price of $invalid breaks the line into separate points', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_points([10, invalid, 30])));
      final chartPaint = find.descendant(
        of: find.byType(HistoryChart),
        matching: find.byType(CustomPaint),
      );
      final painter = tester.widget<CustomPaint>(chartPaint).painter!;
      expect(
        (Canvas canvas) => painter.paint(canvas, const Size(312, 180)),
        paints
          ..circle(color: AppColors.accent, radius: 3.5)
          ..circle(color: AppColors.accent, radius: 3.5),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard skips zero and negative records in both directions', (
    tester,
  ) async {
    await tester.pumpWidget(_chart(_points([10, 0, -5, 30])));
    final bounds = tester.getRect(
      find.byKey(const ValueKey('history-chart-touch-target')),
    );
    await tester.tapAt(Offset(bounds.left + 4, bounds.center.dy));
    await tester.pump();
    expect(find.text('Preço: ${format.brl(10)}'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Preço: ${format.brl(30)}'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Preço: ${format.brl(30)}'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Preço: ${format.brl(10)}'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Preço: ${format.brl(10)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'touch near unavailable records selects an actual positive price',
    (tester) async {
      await tester.pumpWidget(_chart(_points([10, 0, -5, 30])));
      final bounds = tester.getRect(
        find.byKey(const ValueKey('history-chart-touch-target')),
      );
      await tester.tapAt(
        Offset(bounds.left + bounds.width * .33, bounds.center.dy),
      );
      await tester.pump();
      expect(find.text('Preço: ${format.brl(10)}'), findsOneWidget);
      await tester.tapAt(
        Offset(bounds.left + bounds.width * .6, bounds.center.dy),
      );
      await tester.pump();
      expect(find.text('Preço: ${format.brl(30)}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
