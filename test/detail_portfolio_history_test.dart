import 'dart:async';
import 'dart:convert';

import 'package:cryptohub/models/coin_quote.dart';
import 'package:cryptohub/models/portfolio_position.dart';
import 'package:cryptohub/providers/coin_detail_controller.dart';
import 'package:cryptohub/providers/portfolio_history_controller.dart';
import 'package:cryptohub/services/crypto_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _response(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _history(List<Map<String, Object?>> points) => _response({
  'Response': 'Success',
  'Data': {'Data': points},
});

Map<String, Object?> _point(DateTime time, Object? close) => {
  'time': time.toUtc().millisecondsSinceEpoch ~/ 1000,
  'close': close,
};

PortfolioPosition _position(String symbol, double quantity) =>
    PortfolioPosition(symbol: symbol, coinName: symbol, quantity: quantity);

void main() {
  group('CoinDetailController', () {
    test(
      'period selection sends hourly or daily requests with the right limit',
      () async {
        final requests = <http.Request>[];
        final api = CryptoApiService(
          client: MockClient((request) async {
            requests.add(request);
            return _history([_point(DateTime.utc(2026, 9, 30), 100)]);
          }),
        );
        final controller = CoinDetailController(api: api, symbol: 'BTC');
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        for (final period in HistoryPeriod.values) {
          await controller.selectPeriod(period);
          expect(controller.period, period);
          expect(controller.historyLoading, isFalse);
          expect(controller.historyError, isNull);
          expect(controller.points.single.close, 100);
        }

        expect(requests.length, HistoryPeriod.values.length);
        for (var index = 0; index < requests.length; index++) {
          final period = HistoryPeriod.values[index];
          expect(
            requests[index].url.path,
            period == HistoryPeriod.day
                ? '/data/v2/histohour'
                : '/data/v2/histoday',
          );
          expect(requests[index].url.queryParameters, {
            'fsym': 'BTC',
            'tsym': 'BRL',
            'limit': '${period.limit}',
          });
        }
        await controller.selectPeriod(HistoryPeriod.year);
        expect(
          requests.length,
          HistoryPeriod.values.length,
          reason: 'Selecting the loaded period again should reuse its points.',
        );
      },
    );

    test(
      'an older response cannot replace the newly selected period',
      () async {
        final oldResponse = Completer<http.Response>();
        final newResponse = Completer<http.Response>();
        final oldStarted = Completer<void>();
        final newStarted = Completer<void>();
        final api = CryptoApiService(
          client: MockClient((request) {
            if (request.url.path == '/data/v2/histohour') {
              oldStarted.complete();
              return oldResponse.future;
            }
            expect(request.url.queryParameters['limit'], '7');
            newStarted.complete();
            return newResponse.future;
          }),
        );
        final controller = CoinDetailController(api: api, symbol: 'BTC');
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        final older = controller.selectPeriod(HistoryPeriod.day);
        await oldStarted.future;
        final newer = controller.selectPeriod(HistoryPeriod.week);
        await newStarted.future;
        expect(controller.period, HistoryPeriod.week);
        expect(controller.historyLoading, isTrue);

        newResponse.complete(
          _history([_point(DateTime.utc(2026, 9, 30), 200)]),
        );
        await newer;
        expect(controller.points.single.close, 200);
        expect(controller.historyLoading, isFalse);

        oldResponse.complete(
          _history([_point(DateTime.utc(2026, 9, 30), 100)]),
        );
        await older;
        expect(controller.period, HistoryPeriod.week);
        expect(controller.points.single.close, 200);
        expect(controller.historyError, isNull);
        expect(controller.historyLoading, isFalse);
      },
    );

    test(
      'an older failure cannot replace a successful current history',
      () async {
        final oldResponse = Completer<http.Response>();
        final oldStarted = Completer<void>();
        final api = CryptoApiService(
          client: MockClient((request) {
            if (request.url.path == '/data/v2/histohour') {
              oldStarted.complete();
              return oldResponse.future;
            }
            return Future.value(
              _history([_point(DateTime.utc(2026, 9, 30), 200)]),
            );
          }),
        );
        final controller = CoinDetailController(api: api, symbol: 'BTC');
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        final older = controller.selectPeriod(HistoryPeriod.day);
        await oldStarted.future;
        await controller.selectPeriod(HistoryPeriod.year);
        oldResponse.complete(_response({'Response': 'Error'}, 503));
        await older;

        expect(controller.period, HistoryPeriod.year);
        expect(controller.points.single.close, 200);
        expect(controller.historyError, isNull);
        expect(controller.historyLoading, isFalse);
      },
    );

    test(
      'historical failure leaves a successful independent quote visible',
      () async {
        final api = CryptoApiService(
          client: MockClient((request) async {
            if (request.url.path == '/data/pricemultifull') {
              return _response({
                'RAW': {
                  'BTC': {
                    'BRL': {'PRICE': '320000', 'CHANGEPCT24HOUR': '2.5'},
                  },
                },
              });
            }
            expect(request.url.path, '/data/v2/histoday');
            return _response({'Response': 'Error'}, 503);
          }),
        );
        final controller = CoinDetailController(api: api, symbol: 'BTC');
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        await controller.load();
        expect(controller.quote?.price, 320000);
        expect(controller.quote?.changePct24h, 2.5);
        expect(controller.quoteError, isNull);
        expect(controller.historyError, isNotNull);
        expect(controller.points, isEmpty);
        expect(controller.quoteLoading, isFalse);
        expect(controller.historyLoading, isFalse);
      },
    );

    test(
      'quote failure preserves the cached quote and successful history',
      () async {
        final api = CryptoApiService(
          client: MockClient((request) async {
            if (request.url.path == '/data/pricemultifull') {
              return _response({'Response': 'Error'}, 503);
            }
            return _history([_point(DateTime.utc(2026, 9, 30), 200)]);
          }),
        );
        const cached = CoinQuote(
          fromSymbol: 'BTC',
          toSymbol: 'BRL',
          price: 190,
        );
        final controller = CoinDetailController(
          api: api,
          symbol: 'BTC',
          quote: cached,
        );
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        await controller.load();
        expect(controller.quote, same(cached));
        expect(controller.quoteError, isNotNull);
        expect(controller.points.single.close, 200);
        expect(controller.historyError, isNull);
      },
    );

    test('the previous period is cleared while the new period loads', () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final api = CryptoApiService(
        client: MockClient((request) {
          if (request.url.queryParameters['limit'] == '30') {
            return Future.value(
              _history([_point(DateTime.utc(2026, 9, 30), 100)]),
            );
          }
          started.complete();
          return pending.future;
        }),
      );
      final controller = CoinDetailController(api: api, symbol: 'BTC');
      addTearDown(() {
        controller.dispose();
        api.dispose();
      });

      await controller.loadHistory();
      expect(controller.points, isNotEmpty);
      final loading = controller.selectPeriod(HistoryPeriod.week);
      await started.future;
      expect(controller.period, HistoryPeriod.week);
      expect(controller.historyLoading, isTrue);
      expect(controller.points, isEmpty);
      pending.complete(_history([_point(DateTime.utc(2026, 9, 30), 200)]));
      await loading;
      expect(controller.points.single.close, 200);
    });
  });

  group('PortfolioHistoryController', () {
    test(
      'totals use only common UTC dates with actual prices for every asset',
      () async {
        final requested = <String>[];
        final api = CryptoApiService(
          client: MockClient((request) async {
            expect(request.url.path, '/data/v2/histoday');
            expect(request.url.queryParameters['tsym'], 'BRL');
            expect(request.url.queryParameters['limit'], '7');
            final symbol = request.url.queryParameters['fsym'];
            requested.add(symbol!);
            if (symbol == 'BTC') {
              return _history([
                _point(DateTime.utc(2026, 9, 3, 21), '30'),
                _point(DateTime.utc(2026, 9, 1, 21), '10'),
                _point(DateTime.utc(2026, 9, 2, 21), '20'),
                _point(DateTime.utc(2026, 9, 4, 21), '40'),
                _point(DateTime.utc(2026, 9, 6, 21), null),
              ]);
            }
            return _history([
              _point(DateTime.utc(2026, 9, 1, 3), '5'),
              _point(DateTime.utc(2026, 9, 2, 3), null),
              _point(DateTime.utc(2026, 9, 3, 3), '7'),
              _point(DateTime.utc(2026, 9, 5, 3), '9'),
              _point(DateTime.utc(2026, 9, 6, 3), '11'),
            ]);
          }),
        );
        final controller = PortfolioHistoryController(api);
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        await controller.load([
          _position('BTC', 2),
          _position('ETH', 3),
        ], days: 7);
        expect(requested.toSet(), {'BTC', 'ETH'});
        expect(controller.error, isNull);
        expect(controller.loading, isFalse);
        expect(controller.points.map((point) => point.time), [
          DateTime.utc(2026, 9, 1),
          DateTime.utc(2026, 9, 3),
        ]);
        expect(controller.points.map((point) => point.close), [35, 81]);
        expect(controller.points.every((point) => point.time.isUtc), isTrue);
      },
    );

    test(
      'an empty or disjoint asset history cannot produce a partial total',
      () async {
        for (final missing in [true, false]) {
          final api = CryptoApiService(
            client: MockClient((request) async {
              if (request.url.queryParameters['fsym'] == 'BTC') {
                return _history([_point(DateTime.utc(2026, 9, 1), 10)]);
              }
              return _history(
                missing ? [] : [_point(DateTime.utc(2026, 9, 2), 20)],
              );
            }),
          );
          final controller = PortfolioHistoryController(api);
          try {
            await controller.load([_position('BTC', 2), _position('ETH', 3)]);
            expect(controller.points, isEmpty);
            expect(controller.error, contains('todos os ativos'));
            expect(controller.loading, isFalse);
          } finally {
            controller.dispose();
            api.dispose();
          }
        }
      },
    );

    test(
      'failure in a later asset batch hides all prior successful totals',
      () async {
        final requested = <String>[];
        final api = CryptoApiService(
          client: MockClient((request) async {
            final symbol = request.url.queryParameters['fsym']!;
            requested.add(symbol);
            if (symbol == 'DOGE') {
              return _response({'Response': 'Error'}, 503);
            }
            return _history([_point(DateTime.utc(2026, 9, 1), 10)]);
          }),
        );
        final controller = PortfolioHistoryController(api);
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        await controller.load([
          _position('BTC', 2),
          _position('ETH', 3),
          _position('SOL', 4),
          _position('DOGE', 5),
        ]);
        expect(requested, ['BTC', 'ETH', 'SOL', 'DOGE']);
        expect(controller.points, isEmpty);
        expect(controller.error, contains('indisponível'));
        expect(controller.loading, isFalse);
      },
    );

    test(
      'zero and invalid closes are unavailable for a combined date',
      () async {
        final api = CryptoApiService(
          client: MockClient((request) async {
            return _history([
              _point(
                DateTime.utc(2026, 9, 1),
                request.url.queryParameters['fsym'] == 'BTC' ? 10 : 0,
              ),
              _point(DateTime.utc(2026, 9, 2), 'not a price'),
            ]);
          }),
        );
        final controller = PortfolioHistoryController(api);
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        await controller.load([_position('BTC', 2), _position('ETH', 3)]);
        expect(controller.points, isEmpty);
        expect(controller.error, isNotNull);
        expect(controller.loading, isFalse);
      },
    );

    test(
      'an older portfolio response cannot replace the current holdings',
      () async {
        final oldResponse = Completer<http.Response>();
        final oldStarted = Completer<void>();
        final api = CryptoApiService(
          client: MockClient((request) {
            if (request.url.queryParameters['fsym'] == 'BTC') {
              oldStarted.complete();
              return oldResponse.future;
            }
            return Future.value(
              _history([_point(DateTime.utc(2026, 9, 1), 20)]),
            );
          }),
        );
        final controller = PortfolioHistoryController(api);
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        final older = controller.load([_position('BTC', 2)]);
        await oldStarted.future;
        await controller.load([_position('ETH', 3)]);
        expect(controller.points.single.close, 60);
        oldResponse.complete(_history([_point(DateTime.utc(2026, 9, 1), 10)]));
        await older;
        expect(controller.points.single.close, 60);
        expect(controller.error, isNull);
        expect(controller.loading, isFalse);
      },
    );

    test(
      'empty holdings clear the history and invalidate pending requests',
      () async {
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        final api = CryptoApiService(
          client: MockClient((_) {
            started.complete();
            return pending.future;
          }),
        );
        final controller = PortfolioHistoryController(api);
        addTearDown(() {
          controller.dispose();
          api.dispose();
        });

        final oldLoad = controller.load([_position('BTC', 2)]);
        await started.future;
        await controller.load([]);
        expect(controller.loading, isFalse);
        expect(controller.points, isEmpty);
        pending.complete(_history([_point(DateTime.utc(2026, 9, 1), 10)]));
        await oldLoad;
        expect(controller.points, isEmpty);
        expect(controller.error, isNull);
        expect(controller.loading, isFalse);
      },
    );
  });
}
