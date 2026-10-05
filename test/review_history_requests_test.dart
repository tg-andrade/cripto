import 'dart:async';
import 'dart:convert';
import 'package:cryptohub/providers/coin_detail_controller.dart';
import 'package:cryptohub/providers/portfolio_history_controller.dart';
import 'package:cryptohub/models/portfolio_position.dart';
import 'package:cryptohub/services/crypto_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response quote(double price) => jsonResponse({
  'RAW': {
    'BTC': {
      'BRL': {'FROMSYMBOL': 'BTC', 'TOSYMBOL': 'BRL', 'PRICE': price},
    },
  },
});
http.Response history(double price) => jsonResponse({
  'Data': {
    'Data': [
      {'time': 1790802000, 'close': price},
    ],
  },
});
Future<void> turn() => Future<void>.delayed(Duration.zero);

void main() {
  test('concurrent quote refreshes await the same active request', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final api = CryptoApiService(
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    final controller = CoinDetailController(api: api, symbol: 'BTC');
    addTearDown(() {
      controller.dispose();
      api.dispose();
    });
    final first = controller.loadQuote();
    final second = controller.loadQuote();
    var finished = false;
    unawaited(second.then((_) => finished = true));
    await turn();
    expect(calls, 1);
    expect(finished, false);
    pending.complete(quote(50));
    await Future.wait([first, second]);
    expect(controller.quote?.price, 50);
    expect(finished, true);
  });

  test(
    'a quote from an old API key cannot replace the current quote',
    () async {
      final old = Completer<http.Response>();
      final api = CryptoApiService(
        apiKey: 'old-test-token',
        client: MockClient(
          (request) =>
              request.headers['Authorization'] == 'Apikey old-test-token'
              ? old.future
              : Future.value(quote(80)),
        ),
      );
      final controller = CoinDetailController(api: api, symbol: 'BTC');
      addTearDown(() {
        controller.dispose();
        api.dispose();
      });
      final stale = controller.loadQuote();
      await turn();
      api.updateApiKey('new-test-token');
      await controller.loadQuote();
      expect(controller.quote?.price, 80);
      old.complete(
        jsonResponse({'Response': 'Error', 'Message': 'Invalid API key'}, 401),
      );
      await stale;
      expect(controller.quote?.price, 80);
      expect(controller.quoteError, isNull);
      expect(controller.quoteLoading, false);
    },
  );

  test('a key changed during history retries with the new key', () async {
    final old = Completer<http.Response>();
    var currentCalls = 0;
    final api = CryptoApiService(
      apiKey: 'old-test-token',
      client: MockClient((request) {
        if (request.headers['Authorization'] == 'Apikey old-test-token') {
          return old.future;
        }
        currentCalls++;
        return Future.value(history(90));
      }),
    );
    final controller = CoinDetailController(api: api, symbol: 'BTC');
    addTearDown(() {
      controller.dispose();
      api.dispose();
    });
    final loading = controller.loadHistory();
    api.updateApiKey('new-test-token');
    old.complete(history(10));
    await loading;
    expect(currentCalls, 1);
    expect(controller.points.single.close, 90);
    expect(controller.historyError, isNull);
  });

  test('portfolio history snapshots positions before awaiting HTTP', () async {
    final response = Completer<http.Response>();
    final api = CryptoApiService(client: MockClient((_) => response.future));
    final controller = PortfolioHistoryController(api);
    addTearDown(() {
      controller.dispose();
      api.dispose();
    });
    final holdings = [
      PortfolioPosition(symbol: 'BTC', coinName: 'Bitcoin', quantity: 2),
    ];
    final loading = controller.load(holdings);
    holdings.clear();
    response.complete(history(10));
    await loading;
    expect(controller.points.single.close, 20);
    expect(controller.error, isNull);
  });

  test(
    'underflow cannot turn a nonempty portfolio into a zero chart',
    () async {
      final api = CryptoApiService(
        client: MockClient((_) async => history(double.minPositive)),
      );
      final controller = PortfolioHistoryController(api);
      addTearDown(() {
        controller.dispose();
        api.dispose();
      });
      await controller.load([
        PortfolioPosition(
          symbol: 'BTC',
          coinName: 'Bitcoin',
          quantity: double.minPositive,
        ),
      ]);
      expect(controller.points, isEmpty);
      expect(controller.error, isNotNull);
    },
  );

  test(
    'a portfolio history from an old key is discarded and retried',
    () async {
      final old = Completer<http.Response>();
      final api = CryptoApiService(
        apiKey: 'old-test-token',
        client: MockClient(
          (request) =>
              request.headers['Authorization'] == 'Apikey old-test-token'
              ? old.future
              : Future.value(history(100)),
        ),
      );
      final controller = PortfolioHistoryController(api);
      addTearDown(() {
        controller.dispose();
        api.dispose();
      });
      final loading = controller.load([
        PortfolioPosition(symbol: 'BTC', coinName: 'Bitcoin', quantity: 2),
      ]);
      api.updateApiKey('new-test-token');
      old.complete(history(1));
      await loading;
      expect(controller.points.single.close, 200);
      expect(controller.error, isNull);
      expect(controller.loading, false);
    },
  );
}
