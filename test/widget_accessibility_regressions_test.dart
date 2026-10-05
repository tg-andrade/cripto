import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cryptohub/models/coin_info.dart';
import 'package:cryptohub/models/coin_quote.dart';
import 'package:cryptohub/models/price_history.dart';
import 'package:cryptohub/providers/app_controller.dart';
import 'package:cryptohub/services/crypto_api_service.dart';
import 'package:cryptohub/services/local_storage_service.dart';
import 'package:cryptohub/theme/app_theme.dart';
import 'package:cryptohub/utils/formatters.dart' as format;
import 'package:cryptohub/widgets/app_widgets.dart';
import 'package:cryptohub/widgets/history_chart.dart';
import 'package:cryptohub/widgets/portfolio_distribution.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child, {double width = 272, double scale = 2}) =>
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final screenWidth in [320.0, 360.0]) {
    for (final scale in [1.3, 2.0]) {
      testWidgets(
        'quote actions and large values fit at $screenWidth px / $scale text',
        (tester) async {
          var opened = false;
          var favorited = false;
          final coin = CoinInfo(symbol: 'BTC', coinName: 'Bitcoin');
          await tester.pumpWidget(
            _host(
              QuoteTile(
                coin: coin,
                quote: const CoinQuote(
                  fromSymbol: 'BTC',
                  toSymbol: 'BRL',
                  price: 1e300,
                  changePct24h: double.maxFinite,
                ),
                isFavorite: false,
                onTap: () => opened = true,
                onFavorite: () => favorited = true,
              ),
              width: screenWidth - 48,
              scale: scale,
            ),
          );
          expect(tester.takeException(), isNull);
          final star = find.byTooltip('Adicionar Bitcoin aos favoritos');
          expect(tester.getSize(star).width, greaterThanOrEqualTo(48));
          await tester.tap(star);
          expect(favorited, isTrue);
          expect(opened, isFalse);
          await tester.tap(find.text('Bitcoin'));
          expect(opened, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('section actions wrap with enlarged text', (tester) async {
    var activated = false;
    await tester.pumpWidget(
      _host(
        SectionHeading(
          title: 'Estatísticas da carteira',
          actionLabel: 'Visualizar todas as notícias',
          onAction: () => activated = true,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Visualizar todas as notícias'));
    expect(activated, isTrue);
  });

  testWidgets('keyboard can visit distinct records sharing a timestamp', (
    tester,
  ) async {
    final time = DateTime(2026, 10, 4, 12);
    await tester.pumpWidget(
      _host(
        HistoryChart(
          points: [
            PriceHistoryPoint(time: time, close: 10),
            PriceHistoryPoint(time: time, close: 20),
            PriceHistoryPoint(time: time, close: 30),
          ],
        ),
        scale: 1,
      ),
    );
    final rect = tester.getRect(
      find.byKey(const ValueKey('history-chart-touch-target')),
    );
    await tester.tapAt(Offset(rect.center.dx, rect.bottom - 30));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Preço: ${format.brl(20)}'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Preço: ${format.brl(30)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('microsecond timestamps keep separate chart positions', (
    tester,
  ) async {
    final time = DateTime(2026, 10, 4, 12);
    await tester.pumpWidget(
      _host(
        HistoryChart(
          points: [
            PriceHistoryPoint(time: time, close: 10),
            PriceHistoryPoint(
              time: time.add(const Duration(microseconds: 500)),
              close: 20,
            ),
            PriceHistoryPoint(
              time: time.add(const Duration(microseconds: 1000)),
              close: 30,
            ),
          ],
        ),
        scale: 1,
      ),
    );
    final rect = tester.getRect(
      find.byKey(const ValueKey('history-chart-touch-target')),
    );
    await tester.tapAt(Offset(rect.right - 70, rect.center.dy));
    await tester.pump();
    expect(find.text('Preço: ${format.brl(30)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard skips unavailable prices and clamps at the last record',
    (tester) async {
      final time = DateTime(2026, 10, 4, 12);
      await tester.pumpWidget(
        _host(
          HistoryChart(
            points: [
              PriceHistoryPoint(time: time, close: .00001),
              PriceHistoryPoint(
                time: time.add(const Duration(hours: 1)),
                close: null,
              ),
              PriceHistoryPoint(
                time: time.add(const Duration(hours: 2)),
                close: double.nan,
              ),
              PriceHistoryPoint(
                time: time.add(const Duration(hours: 3)),
                close: .00003,
              ),
            ],
          ),
          scale: 1,
        ),
      );
      final rect = tester.getRect(
        find.byKey(const ValueKey('history-chart-touch-target')),
      );
      await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Preço: ${format.brl(.00003)}'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Preço: ${format.brl(.00003)}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'enlarged chart details stay below the plot and inside the card width',
    (tester) async {
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: HistoryChart(
              points: [
                PriceHistoryPoint(time: DateTime(2026, 10, 4), close: 1e300),
              ],
            ),
          ),
          width: 240,
        ),
      );
      final target = find.byKey(const ValueKey('history-chart-touch-target'));
      await tester.tap(target);
      await tester.pump();
      final details = tester.getRect(
        find.byKey(const ValueKey('history-chart-tooltip')),
      );
      final plot = tester.getRect(target);
      expect(details.top, greaterThanOrEqualTo(plot.bottom));
      expect(details.left, greaterThanOrEqualTo(plot.left));
      expect(details.right, lessThanOrEqualTo(plot.right));
      expect(find.text('Preço: ${format.brl(1e300)}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('distribution painter retains its data when quotes change', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var prices = <String, double>{'BTC': 100, 'SOL': 50};
    final api = CryptoApiService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'RAW': {
              for (final entry in prices.entries)
                entry.key: {
                  'BRL': {
                    'FROMSYMBOL': entry.key,
                    'TOSYMBOL': 'BRL',
                    'PRICE': entry.value,
                  },
                },
            },
          }),
          200,
        ),
      ),
    );
    final controller = AppController(
      api: api,
      storage: LocalStorageService(preferences: preferences),
    );
    addTearDown(() {
      controller.dispose();
      api.dispose();
    });
    await controller.initialize();
    await controller.upsertPosition(controller.coinFor('BTC'), 1);
    await controller.upsertPosition(controller.coinFor('SOL'), 1);
    await tester.pumpWidget(
      _host(PortfolioDistribution(controller: controller)),
    );
    final painted = find.descendant(
      of: find.byType(PortfolioDistribution),
      matching: find.byType(CustomPaint),
    );
    final painter = tester.widget<CustomPaint>(painted).painter!;
    prices = {'BTC': 120};
    await controller.refreshMarket();
    expect(controller.portfolioTotal, isNull);
    final recorder = ui.PictureRecorder();
    expect(
      () => painter.paint(ui.Canvas(recorder), const Size(146, 146)),
      returnsNormally,
    );
    recorder.endRecording().dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an invalid zero quote leaves percentage distribution unavailable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = CryptoApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'RAW': {
                'BTC': {
                  'BRL': {'FROMSYMBOL': 'BTC', 'TOSYMBOL': 'BRL', 'PRICE': 0},
                },
              },
            }),
            200,
          ),
        ),
      );
      final controller = AppController(
        api: api,
        storage: LocalStorageService(
          preferences: await SharedPreferences.getInstance(),
        ),
      );
      addTearDown(() {
        controller.dispose();
        api.dispose();
      });
      await controller.initialize();
      await controller.upsertPosition(controller.coinFor('BTC'), 1);
      await tester.pumpWidget(
        _host(PortfolioDistribution(controller: controller)),
      );
      expect(
        find.text(
          'A distribuição estará disponível quando todos os ativos tiverem cotação.',
        ),
        findsOneWidget,
      );
      expect(controller.portfolioTotal, isNull);
      expect(controller.portfolioIncomplete, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
