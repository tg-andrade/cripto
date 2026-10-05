import 'dart:async';
import 'dart:convert';

import 'package:cryptohub/models/coin_info.dart';
import 'package:cryptohub/models/coin_quote.dart';
import 'package:cryptohub/providers/app_controller.dart';
import 'package:cryptohub/services/crypto_api_service.dart';
import 'package:cryptohub/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'initial refresh includes restored custom holdings and favorites',
    () async {
      final cachedAt = DateTime.utc(2026, 9, 30, 12);
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: jsonEncode({
          'favorites': ['LTC'],
          'positions': [
            {'symbol': 'LINK', 'coinName': 'Chainlink', 'quantity': 2},
          ],
        }),
        LocalStorageService.quoteCacheKey: _cache({
          'LINK': 10,
          'LTC': 100,
        }, cachedAt),
      });
      final requested = <Set<String>>[];
      final controller = _controller(
        MockClient((request) async {
          requested.add(_symbols(request));
          return _quotes({..._marketPrices, 'LINK': 50, 'LTC': 450});
        }),
      );

      await controller.initialize();

      expect(requested, hasLength(1));
      expect(
        requested.single,
        containsAll([...controller.marketSymbols, 'LINK', 'LTC']),
      );
      expect(controller.positions.single.symbol, 'LINK');
      expect(controller.quoteFor('LINK')?.price, 50);
      expect(controller.quoteFor('LTC')?.price, 450);
      expect(controller.portfolioTotal, 100);
      expect(controller.lastRefresh!.isAfter(cachedAt), isTrue);
      expect(controller.marketLoading, isFalse);
      expect(controller.marketError, isNull);
    },
  );

  test(
    'adding a cached custom holding during refresh fetches it before marking data current',
    () async {
      final cachedAt = DateTime.utc(2026, 9, 30, 12);
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: jsonEncode({
          'favorites': [],
          'positions': [
            {'symbol': 'BTC', 'coinName': 'Bitcoin', 'quantity': 1},
          ],
        }),
        // This quote was saved before LINK was removed from the user's holdings.
        LocalStorageService.quoteCacheKey: _cache({
          'BTC': 250000,
          'LINK': 10,
        }, cachedAt),
      });
      final requested = <Set<String>>[];
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      final firstResponse = Completer<http.Response>();
      final secondResponse = Completer<http.Response>();
      var activeRequests = 0;
      var maximumActiveRequests = 0;
      final controller = _controller(
        MockClient((request) async {
          requested.add(_symbols(request));
          activeRequests += 1;
          if (activeRequests > maximumActiveRequests) {
            maximumActiveRequests = activeRequests;
          }
          try {
            if (requested.length == 1) {
              firstStarted.complete();
              return await firstResponse.future;
            }
            if (requested.length == 2) {
              secondStarted.complete();
              return await secondResponse.future;
            }
            return _quotes({..._marketPrices, 'LINK': 50});
          } finally {
            activeRequests -= 1;
          }
        }),
      );

      final initialize = controller.initialize();
      await firstStarted.future;
      expect(requested.first, isNot(contains('LINK')));
      expect(controller.quoteFor('LINK')?.price, 10);
      await controller.upsertPosition(
        CoinInfo(symbol: 'LINK', coinName: 'Chainlink'),
        2,
      );
      final joinedRefresh = controller.refreshMarket();
      firstResponse.complete(_quotes(_marketPrices));

      await secondStarted.future;
      expect(requested.last, contains('LINK'));
      expect(controller.marketLoading, isTrue);
      expect(controller.quoteFor('LINK')?.price, 10);
      expect(controller.quoteRefreshedAt('LINK'), cachedAt);
      expect(controller.isQuoteStale('LINK'), isTrue);
      expect(controller.positionValue(controller.positions.last), 20);
      expect(controller.portfolioTotal, isNull);
      secondResponse.complete(_quotes({..._marketPrices, 'LINK': 50}));
      await Future.wait([initialize, joinedRefresh]);

      expect(requested, hasLength(2));
      expect(maximumActiveRequests, 1);
      expect(controller.quoteFor('LINK')?.price, 50);
      expect(controller.positionValue(controller.positions.last), 100);
      expect(controller.portfolioTotal, 300100);
      expect(controller.marketError, isNull);
      expect(controller.marketLoading, isFalse);
      final preferences = await SharedPreferences.getInstance();
      final persisted =
          jsonDecode(preferences.getString(LocalStorageService.quoteCacheKey)!)
              as Map;
      expect(((persisted['quotes'] as Map)['LINK'] as Map)['PRICE'], 50);
    },
  );

  test(
    'a favorite added during a pending refresh is fetched in the next sequential batch',
    () async {
      final requested = <Set<String>>[];
      final blockedRequestStarted = Completer<void>();
      final blockedResponse = Completer<http.Response>();
      var activeRequests = 0;
      var maximumActiveRequests = 0;
      final controller = _controller(
        MockClient((request) async {
          requested.add(_symbols(request));
          activeRequests += 1;
          if (activeRequests > maximumActiveRequests) {
            maximumActiveRequests = activeRequests;
          }
          try {
            if (requested.length == 2) {
              blockedRequestStarted.complete();
              return await blockedResponse.future;
            }
            return _quotes({
              ..._marketPrices,
              if (requested.length > 2) 'LTC': 450,
            });
          } finally {
            activeRequests -= 1;
          }
        }),
      );
      await controller.initialize();
      final refresh = controller.refreshMarket();
      await blockedRequestStarted.future;
      expect(requested.last, isNot(contains('LTC')));
      await controller.toggleFavorite('LTC');
      blockedResponse.complete(_quotes(_marketPrices));
      await refresh;

      expect(requested, hasLength(3));
      expect(requested.last, contains('LTC'));
      expect(maximumActiveRequests, 1);
      expect(controller.favorites, {'LTC'});
      expect(controller.quoteFor('LTC')?.price, 450);
      expect(controller.marketLoading, isFalse);
      expect(controller.marketError, isNull);
    },
  );

  test(
    'API key revision changes for replacements and removals while matching normalized keys stay stable',
    () async {
      const initialKey = 'initial-session-key';
      const nextKey = 'replacement-session-key';
      final controller = _controller(
        MockClient((_) async => _quotes(_marketPrices)),
        apiKey: initialKey,
      );
      await controller.initialize();
      expect(controller.hasApiKey, isTrue);
      expect(controller.apiKeyRevision, 0);

      await controller.setApiKey('  $initialKey  ');
      expect(controller.apiKeyRevision, 0);
      final replacement = controller.setApiKey('  $nextKey  ');
      expect(controller.apiKeyRevision, 1);
      await replacement;
      expect(controller.hasApiKey, isTrue);
      expect(controller.api.apiKey, nextKey);
      await controller.setApiKey(nextKey);
      expect(controller.apiKeyRevision, 1);
      await controller.setApiKey(' ');
      expect(controller.apiKeyRevision, 2);
      expect(controller.hasApiKey, isFalse);
      await controller.setApiKey(initialKey);
      expect(controller.apiKeyRevision, 3);

      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys()) {
        final stored = preferences.get(key).toString();
        expect(stored, isNot(contains(initialKey)));
        expect(stored, isNot(contains(nextKey)));
      }
    },
  );
}

const _marketPrices = <String, double>{
  'BTC': 300000,
  'ETH': 15000,
  'SOL': 700,
  'BNB': 3000,
  'XRP': 3,
  'ADA': 2,
  'DOGE': 0.5,
  'AVAX': 150,
};

Set<String> _symbols(http.Request request) {
  expect(request.url.path, '/data/pricemultifull');
  expect(request.url.queryParameters['tsyms'], 'BRL');
  return request.url.queryParameters['fsyms']!.split(',').toSet();
}

http.Response _quotes(Map<String, double> prices) => http.Response(
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
  headers: {'content-type': 'application/json; charset=utf-8'},
);

String _cache(Map<String, double> prices, DateTime updatedAt) => jsonEncode({
  'currency': 'BRL',
  'updatedAt': updatedAt.toIso8601String(),
  'quotes': {
    for (final entry in prices.entries)
      entry.key: CoinQuote(
        fromSymbol: entry.key,
        toSymbol: 'BRL',
        price: entry.value,
      ).toJson(),
  },
});

AppController _controller(http.Client client, {String apiKey = ''}) {
  final api = CryptoApiService(client: client, apiKey: apiKey);
  final controller = AppController(api: api, storage: LocalStorageService());
  addTearDown(() {
    controller.dispose();
    api.dispose();
  });
  return controller;
}
