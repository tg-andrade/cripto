import 'package:cryptohub/models/price_history.dart';
import 'package:cryptohub/theme/app_theme.dart';
import 'package:cryptohub/utils/formatters.dart' as format;
import 'package:cryptohub/widgets/history_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget chart(List<PriceHistoryPoint> points) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 312, child: HistoryChart(points: points)),
    ),
  ),
);

void main() {
  testWidgets('constant series paints and selects a real value', (
    tester,
  ) async {
    final points = List.generate(
      4,
      (index) => PriceHistoryPoint(
        time: DateTime(2026, 9, 30, 10 + index),
        close: 120,
      ),
    );
    await tester.pumpWidget(chart(points));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('history-chart-touch-target')));
    await tester.pump();
    expect(find.byKey(const ValueKey('history-chart-tooltip')), findsOneWidget);
    expect(find.text('Preço: ${format.brl(120)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single point exposes its timestamp and price', (tester) async {
    final time = DateTime(2026, 9, 30, 12, 15);
    await tester.pumpWidget(
      chart([PriceHistoryPoint(time: time, close: 42.5)]),
    );
    await tester.tap(find.byKey(const ValueKey('history-chart-touch-target')));
    await tester.pump();
    expect(find.text(format.dateTimeLabel(time)), findsOneWidget);
    expect(find.text('Preço: ${format.brl(42.5)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch selects actual points across missing prices', (
    tester,
  ) async {
    final start = DateTime(2026, 9, 30, 10);
    final finish = DateTime(2026, 9, 30, 12);
    await tester.pumpWidget(
      chart([
        PriceHistoryPoint(time: start, close: 10),
        PriceHistoryPoint(time: DateTime(2026, 9, 30, 11), close: null),
        PriceHistoryPoint(time: finish, close: 30),
      ]),
    );
    final target = find.byKey(const ValueKey('history-chart-touch-target'));
    final bounds = tester.getRect(target);
    final gesture = await tester.startGesture(
      Offset(bounds.left + 4, bounds.center.dy),
    );
    await gesture.moveTo(Offset(bounds.right - 70, bounds.center.dy));
    await gesture.up();
    await tester.pump();
    expect(find.text(format.dateTimeLabel(finish)), findsOneWidget);
    expect(find.text('Preço: ${format.brl(30)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonfinite prices are excluded and large finite values paint', (
    tester,
  ) async {
    await tester.pumpWidget(
      chart([
        PriceHistoryPoint(time: DateTime(2026, 9, 30, 10), close: double.nan),
        PriceHistoryPoint(
          time: DateTime(2026, 9, 30, 11),
          close: double.infinity,
        ),
        PriceHistoryPoint(time: DateTime(2026, 9, 30, 12), close: 1e300),
        PriceHistoryPoint(time: DateTime(2026, 9, 30, 13), close: 1.1e300),
      ]),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('history-chart-touch-target')));
    await tester.pump();
    expect(find.byKey(const ValueKey('history-chart-tooltip')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
