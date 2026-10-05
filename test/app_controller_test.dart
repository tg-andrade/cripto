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

  test('favorites and edited positions survive a new controller', () async {
    final preferences = await SharedPreferences.getInstance();
    final first = createController(preferences: preferences);
    await first.initialize();
    await Future.wait([
      first.toggleFavorite('btc'),
      first.toggleFavorite('ETH'),
      first.toggleFavorite('BTC'),
    ]);
    await first.upsertPosition(
      CoinInfo(symbol: 'BTC', coinName: 'Bitcoin'),
      0.025,
    );
    await first.upsertPosition(
      CoinInfo(symbol: 'ETH', coinName: 'Ethereum'),
      3,
    );
    await first.upsertPosition(
      CoinInfo(symbol: 'BTC', coinName: 'Bitcoin'),
      0.05,
    );
    await first.removePosition('ETH');

    final restored = createController(preferences: preferences);
    await restored.initialize();
    expect(restored.favorites, {'ETH'});
    expect(restored.positions, hasLength(1));
    expect(restored.positions.single.symbol, 'BTC');
    expect(restored.positions.single.coinName, 'Bitcoin');
    expect(restored.positions.single.quantity, 0.05);
    expect(restored.positions.single.coin.symbol, 'BTC');
    expect(restored.portfolioTotal, 15000);
    expect(restored.storageError, isNull);
  });

  test(
    'missing quotes make the total unavailable and an empty portfolio is zero',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: jsonEncode({
          'favorites': [],
          'positions': [
            {'symbol': 'BTC', 'coinName': 'Bitcoin', 'quantity': 0.1},
            {'symbol': 'ETH', 'coinName': 'Ethereum', 'quantity': 2},
          ],
        }),
      });
      final controller = createController(
        client: MockClient((_) async => quoteResponse({'BTC': 300000})),
      );
      await controller.initialize();
      expect(controller.positionValue(controller.positions.first), 30000);
      expect(controller.positionValue(controller.positions.last), isNull);
      expect(controller.portfolioTotal, isNull);
      expect(controller.portfolioIncomplete, isTrue);

      await controller.removePosition('ETH');
      expect(controller.portfolioTotal, 30000);
      expect(controller.portfolioIncomplete, isFalse);
      await controller.removePosition('BTC');
      expect(controller.portfolioTotal, 0);
      expect(controller.portfolioIncomplete, isFalse);
    },
  );

  test(
    'quantities must be finite and positive before a position is saved',
    () async {
      final controller = createController();
      await controller.initialize();
      final coin = CoinInfo(symbol: 'BTC', coinName: 'Bitcoin');
      for (final quantity in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => controller.upsertPosition(coin, quantity),
          throwsArgumentError,
        );
      }
      expect(controller.positions, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).get(
          LocalStorageService.userDataKey,
        ),
        isNull,
      );
    },
  );

  test(
    'a nonpositive quote cannot turn a holding into a zero portfolio total',
    () async {
      final controller = createController(
        client: MockClient((_) async => quoteResponse({'BTC': 0})),
      );
      await controller.initialize();
      await controller.upsertPosition(
        CoinInfo(symbol: 'BTC', coinName: 'Bitcoin'),
        1,
      );
      expect(controller.positionValue(controller.positions.single), isNull);
      expect(controller.portfolioTotal, isNull);
      expect(controller.portfolioIncomplete, isTrue);
    },
  );

  test(
    'an offline refresh retains persisted quotes and their last successful timestamp',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final online = createController(preferences: preferences);
      await online.initialize();
      await online.upsertPosition(
        CoinInfo(symbol: 'BTC', coinName: 'Bitcoin'),
        0.5,
      );
      final lastSuccessfulRefresh = online.lastRefresh;
      final cachedDocument = preferences.getString(
        LocalStorageService.quoteCacheKey,
      );

      final offline = createController(
        preferences: preferences,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await offline.initialize();
      expect(offline.initialized, isTrue);
      expect(offline.offline, isTrue);
      expect(offline.hasCachedQuotes, isTrue);
      expect(offline.marketLoading, isFalse);
      expect(offline.marketError, isNotNull);
      expect(offline.quoteFor('BTC')?.price, 300000);
      expect(offline.portfolioTotal, 150000);
      expect(offline.lastRefresh, lastSuccessfulRefresh?.toUtc());
      expect(
        preferences.getString(LocalStorageService.quoteCacheKey),
        cachedDocument,
      );
    },
  );

  test('an empty API response retains cached data and its timestamp', () async {
    var emptyResponse = false;
    final controller = createController(
      client: MockClient(
        (_) async => quoteResponse(emptyResponse ? {} : defaultPrices),
      ),
    );
    await controller.initialize();
    final lastSuccessfulRefresh = controller.lastRefresh;
    emptyResponse = true;
    await controller.refreshMarket();
    expect(controller.quoteFor('BTC')?.price, 300000);
    expect(controller.lastRefresh, lastSuccessfulRefresh);
    expect(controller.marketError, contains('cotações disponíveis'));
    expect(controller.marketLoading, isFalse);
  });

  for (final throwsWrite in [false, true]) {
    test(
      'failed preference writes roll back edits (${throwsWrite ? 'exception' : 'false'})',
      () async {
        final preferences = await SharedPreferences.getInstance();
        final controlledPreferences = RejectingPreferences(preferences);
        final controller = createController(preferences: controlledPreferences);
        await controller.initialize();
        controlledPreferences.rejectNextUserWrite = true;
        controlledPreferences.throwInstead = throwsWrite;
        await controller.toggleFavorite('BTC');
        expect(controller.favorites, isEmpty);
        expect(controller.storageError, isNotNull);
        expect(preferences.get(LocalStorageService.userDataKey), isNull);

        await controller.toggleFavorite('BTC');
        expect(controller.favorites, {'BTC'});
        expect(controller.storageError, isNull);
        await controller.upsertPosition(
          CoinInfo(symbol: 'BTC', coinName: 'Bitcoin'),
          1,
        );
        final previousDocument = preferences.getString(
          LocalStorageService.userDataKey,
        );

        controlledPreferences.rejectNextUserWrite = true;
        await controller.upsertPosition(
          CoinInfo(symbol: 'BTC', coinName: 'Bitcoin'),
          2,
        );
        expect(controller.positions.single.quantity, 1);
        expect(controller.storageError, isNotNull);
        expect(
          preferences.getString(LocalStorageService.userDataKey),
          previousDocument,
        );

        controlledPreferences.rejectNextUserWrite = true;
        await controller.removePosition('BTC');
        expect(controller.positions.single.quantity, 1);
        expect(controller.storageError, isNotNull);
        expect(
          preferences.getString(LocalStorageService.userDataKey),
          previousDocument,
        );

        await controller.removePosition('BTC');
        expect(controller.positions, isEmpty);
        expect(controller.storageError, isNull);
      },
    );
  }

  test(
    'corrupt rows are skipped while valid holdings favorites and quotes are restored',
    () async {
      final timestamp = DateTime.utc(2026, 9, 30, 12);
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: jsonEncode({
          'favorites': ['btc', '', 7, 'ETH'],
          'positions': [
            {'symbol': 'BTC', 'coinName': 'Bitcoin', 'quantity': 0.1},
            null,
            {'symbol': 'DOGE', 'coinName': 'Dogecoin', 'quantity': -1},
            {'symbol': 'SOL', 'coinName': 'Solana', 'quantity': 'invalid'},
          ],
          'coinReferences': {
            'ETH': {'coinName': 'Ethereum', 'imageUrl': 42},
          },
        }),
        LocalStorageService.quoteCacheKey: jsonEncode({
          'currency': 'BRL',
          'updatedAt': timestamp.toIso8601String(),
          'quotes': {
            'BTC': const CoinQuote(
              fromSymbol: 'BTC',
              toSymbol: 'BRL',
              price: 300000,
            ).toJson(),
            'ETH': 'invalid',
            'LTC': const CoinQuote(
              fromSymbol: 'LTC',
              toSymbol: 'USD',
              price: 70,
            ).toJson(),
          },
        }),
      });
      final controller = createController(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await controller.initialize();
      expect(controller.favorites, {'BTC', 'ETH'});
      expect(controller.positions, hasLength(1));
      expect(controller.positions.single.symbol, 'BTC');
      expect(controller.quotes.keys, ['BTC']);
      expect(controller.portfolioTotal, 30000);
      expect(controller.lastRefresh, timestamp);
      expect(controller.storageError, contains('ignorados'));
    },
  );

  test('catalog and news are fetched only when requested', () async {
    final paths = <String>[];
    final controller = createController(
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('all/coinlist')) {
          return http.Response(
            jsonEncode({
              'Data': {
                'BTC': {'Symbol': 'BTC', 'CoinName': 'Bitcoin'},
                'LINK': {
                  'Symbol': 'LINK',
                  'CoinName': 'Chainlink',
                  'Algorithm': 'N/A',
                },
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('v2/news/')) {
          return http.Response(
            jsonEncode({
              'Data': [
                {
                  'title': 'Notícia de teste',
                  'source_info': {'name': 'Fonte'},
                  'url': 'https://example.com',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return quoteResponse(defaultPrices);
      }),
    );
    await controller.initialize();
    expect(paths, ['/data/pricemultifull']);
    expect(controller.news, isEmpty);
    await controller.loadCatalog();
    expect(controller.coinFor('LINK').coinName, 'Chainlink');
    expect(controller.catalogLoading, isFalse);
    expect(controller.catalogError, isNull);
    await controller.loadNews();
    expect(controller.newsError, isNull);
    expect(controller.news.single.title, 'Notícia de teste');
    expect(controller.newsLoading, isFalse);
  });

  test(
    'a selected catalog reference survives reopening without caching the full catalog',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final controller = createController(
        preferences: preferences,
        client: MockClient((request) async {
          if (request.url.path.endsWith('all/coinlist')) {
            return http.Response(
              jsonEncode({
                'Data': {
                  'LINK': {
                    'Symbol': 'LINK',
                    'CoinName': 'Chainlink',
                    'ImageUrl': '/media/link.png',
                  },
                  'UNI': {'Symbol': 'UNI', 'CoinName': 'Uniswap'},
                },
              }),
              200,
            );
          }
          return quoteResponse({...defaultPrices, 'LINK': 50});
        }),
      );
      await controller.initialize();
      await controller.loadCatalog();
      await controller.toggleFavorite('LINK');
      await controller.refreshMarket();
      final document =
          jsonDecode(preferences.getString(LocalStorageService.userDataKey)!)
              as Map;
      expect((document['coinReferences'] as Map).keys, ['LINK']);

      final restored = createController(preferences: preferences);
      await restored.initialize();
      expect(restored.favorites, {'LINK'});
      expect(restored.coinFor('LINK').coinName, 'Chainlink');
      expect(
        restored.coinFor('LINK').imageUrl,
        'https://www.cryptocompare.com/media/link.png',
      );
      expect(restored.coins.containsKey('UNI'), isFalse);
    },
  );

  test('concurrent market refresh calls share one request', () async {
    var requests = 0;
    var blockRequest = false;
    final requestStarted = Completer<void>();
    final response = Completer<http.Response>();
    final controller = createController(
      client: MockClient((_) async {
        requests += 1;
        if (blockRequest) {
          requestStarted.complete();
          return response.future;
        }
        return quoteResponse(defaultPrices);
      }),
    );
    await controller.initialize();
    blockRequest = true;
    final first = controller.refreshMarket();
    final second = controller.refreshMarket();
    expect(identical(first, second), isTrue);
    await requestStarted.future;
    expect(controller.marketLoading, isTrue);
    response.complete(quoteResponse(defaultPrices));
    await Future.wait([first, second]);
    expect(requests, 2);
    expect(controller.marketLoading, isFalse);
  });

  test(
    'setting a session key retries after any active request and never persists the key',
    () async {
      const token = 'session-test-key';
      final preferences = await SharedPreferences.getInstance();
      final requestStarted = Completer<void>();
      final firstResponse = Completer<http.Response>();
      final authorizations = <String?>[];
      final controller = createController(
        preferences: preferences,
        client: MockClient((request) async {
          authorizations.add(request.headers['Authorization']);
          if (authorizations.length == 1) {
            requestStarted.complete();
            return firstResponse.future;
          }
          return quoteResponse(defaultPrices);
        }),
      );
      final initialize = controller.initialize();
      await requestStarted.future;
      final updateKey = controller.setApiKey(token);
      firstResponse.complete(quoteResponse(defaultPrices));
      await Future.wait([initialize, updateKey]);
      expect(controller.hasApiKey, isTrue);
      expect(authorizations, [null, 'Apikey $token']);
      for (final key in preferences.getKeys()) {
        expect(preferences.get(key).toString(), isNot(contains(token)));
      }
      final restored = createController(preferences: preferences);
      await restored.initialize();
      expect(restored.hasApiKey, isFalse);
    },
  );

  test(
    'finishing an async request after dispose does not notify listeners',
    () async {
      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();
      final api = CryptoApiService(
        apiKey: '',
        client: MockClient((_) async {
          requestStarted.complete();
          return response.future;
        }),
      );
      final controller = AppController(
        api: api,
        storage: LocalStorageService(),
      );
      addTearDown(api.dispose);
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      final initialize = controller.initialize();
      await requestStarted.future;
      controller.dispose();
      final beforeResponse = notifications;
      response.complete(quoteResponse(defaultPrices));
      await initialize;
      expect(notifications, beforeResponse);
    },
  );
}

const defaultPrices = <String, double>{
  'BTC': 300000,
  'ETH': 15000,
  'SOL': 700,
  'BNB': 3000,
  'XRP': 3,
  'ADA': 2,
  'DOGE': 0.5,
  'AVAX': 150,
};

http.Response quoteResponse(Map<String, double> prices) => http.Response(
  jsonEncode({
    'RAW': {
      for (final entry in prices.entries)
        entry.key: {
          'BRL': {
            'FROMSYMBOL': entry.key,
            'TOSYMBOL': 'BRL',
            'PRICE': entry.value,
            'CHANGEPCT24HOUR': 2,
            'LASTUPDATE': 1790769600,
          },
        },
    },
  }),
  200,
);

AppController createController({
  SharedPreferences? preferences,
  http.Client? client,
}) {
  final api = CryptoApiService(
    apiKey: '',
    client: client ?? MockClient((_) async => quoteResponse(defaultPrices)),
  );
  final controller = AppController(
    api: api,
    storage: LocalStorageService(preferences: preferences),
  );
  addTearDown(() {
    controller.dispose();
    api.dispose();
  });
  return controller;
}

/// Models a platform write that changes the preference cache before it fails.
class RejectingPreferences implements SharedPreferences {
  RejectingPreferences(this.delegate);

  final SharedPreferences delegate;
  bool rejectNextUserWrite = false;
  bool throwInstead = false;

  @override
  Object? get(String key) => delegate.get(key);

  @override
  Future<bool> setString(String key, String value) async {
    final result = await delegate.setString(key, value);
    if (key == LocalStorageService.userDataKey && rejectNextUserWrite) {
      rejectNextUserWrite = false;
      if (throwInstead) {
        throw StateError('The platform failed to save the preference.');
      }
      return false;
    }
    return result;
  }

  @override
  Future<bool> remove(String key) => delegate.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
