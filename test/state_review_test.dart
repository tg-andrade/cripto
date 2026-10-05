import 'dart:async';
import 'dart:convert';

import 'package:cryptohub/models/coin_info.dart';
import 'package:cryptohub/models/portfolio_position.dart';
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
    'partial refresh preserves old prices but cannot mix refresh cohorts in a total',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: _user([
          {'symbol': 'BTC', 'quantity': 1},
          {'symbol': 'ETH', 'quantity': 1},
        ]),
      });
      var partial = false;
      final controller = _controller(
        client: MockClient(
          (_) async =>
              _quotes(partial ? {'BTC': 200} : {'BTC': 100, 'ETH': 50}),
        ),
      );
      await controller.initialize();
      final previousRefresh = controller.lastRefresh;
      expect(controller.portfolioTotal, 150);
      partial = true;
      await controller.refreshMarket();
      expect(controller.quoteFor('ETH')?.price, 50);
      expect(controller.quoteRefreshedAt('ETH'), previousRefresh);
      expect(controller.quoteRefreshedAt('BTC'), controller.lastRefresh);
      expect(controller.isQuoteStale('ETH'), isTrue);
      expect(controller.isQuoteStale('BTC'), isFalse);
      expect(controller.portfolioTotal, isNull);
      expect(controller.portfolioIncomplete, isTrue);
      final saved = await LocalStorageService().read();
      expect(saved.quoteRefreshTimes['ETH'], previousRefresh);
      expect(saved.quoteRefreshTimes['BTC'], controller.lastRefresh);
    },
  );

  test(
    'overflow of the combined total also marks the portfolio incomplete',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: _user([
          {'symbol': 'BTC', 'quantity': 1},
          {'symbol': 'ETH', 'quantity': 1},
        ]),
      });
      final controller = _controller(
        client: MockClient((_) async => _quotes({'BTC': 1e308, 'ETH': 1e308})),
      );
      await controller.initialize();
      expect(controller.positionValue(controller.positions.first), 1e308);
      expect(controller.positionValue(controller.positions.last), 1e308);
      expect(controller.portfolioTotal, isNull);
      expect(controller.portfolioIncomplete, isTrue);
    },
  );

  test(
    'a nonempty but entirely invalid quote batch preserves the last good cache',
    () async {
      var invalid = false;
      final controller = _controller(
        client: MockClient((_) async => _quotes({'BTC': invalid ? -1 : 100})),
      );
      await controller.initialize();
      final previousRefresh = controller.lastRefresh;
      final preferences = await SharedPreferences.getInstance();
      final previousCache = preferences.getString(
        LocalStorageService.quoteCacheKey,
      );
      invalid = true;
      await controller.refreshMarket();
      expect(controller.quoteFor('BTC')?.price, 100);
      expect(controller.lastRefresh, previousRefresh);
      expect(controller.marketError, isNotNull);
      expect(controller.isQuoteStale('BTC'), isTrue);
      expect(
        preferences.getString(LocalStorageService.quoteCacheKey),
        previousCache,
      );
    },
  );

  test(
    'failed reads block writes and retry restores holdings without overwriting them',
    () async {
      final original = _user([
        {'symbol': 'BTC', 'quantity': 2},
        {'symbol': 'ETH', 'quantity': 3},
      ]);
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: original,
      });
      final storage = _FailingReadStorage();
      final controller = _controller(storage: storage);
      await controller.initialize();
      expect(controller.initialized, isTrue);
      expect(controller.storageReady, isFalse);
      expect(
        await controller.upsertPosition(CoinInfo(symbol: 'BTC'), 8),
        isFalse,
      );
      expect(await controller.toggleFavorite('BTC'), isFalse);
      expect(await controller.removePosition('ETH'), isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(LocalStorageService.userDataKey), original);
      storage.failRead = false;
      expect(await controller.retryStorage(), isTrue);
      await controller.refreshMarket();
      expect(controller.storageReady, isTrue);
      expect(controller.positions.map((position) => position.quantity), [2, 3]);
      expect(controller.storageError, isNull);
      expect(
        await controller.upsertPosition(CoinInfo(symbol: 'BTC'), 8),
        isTrue,
      );
      expect(controller.positions.map((position) => position.quantity), [8, 3]);
    },
  );

  test(
    'malformed user JSON remains intact until it can be read successfully',
    () async {
      const original = '{"positions":';
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: original,
      });
      final controller = _controller();
      await controller.initialize();
      expect(controller.storageReady, isFalse);
      expect(await controller.toggleFavorite('BTC'), isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(LocalStorageService.userDataKey), original);
      await preferences.setString(
        LocalStorageService.userDataKey,
        _user([
          {'symbol': 'ETH', 'quantity': 4},
        ]),
      );
      expect(await controller.retryStorage(), isTrue);
      expect(controller.positions.single.symbol, 'ETH');
      expect(controller.positions.single.quantity, 4);
      await controller.refreshMarket();
    },
  );

  test(
    'corrupt optional metadata cannot erase a valid holding or hide its warning',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: _user([
          {'symbol': 'BTC', 'quantity': 2, 'coinName': 17, 'imageUrl': 42},
        ]),
      });
      final controller = _controller();
      await controller.initialize();
      expect(controller.storageReady, isTrue);
      expect(controller.positions.single.quantity, 2);
      expect(controller.positions.single.coinName, 'BTC');
      expect(controller.positions.single.imageUrl, isNull);
      expect(controller.storageError, contains('ignorados'));
      expect(
        await controller.upsertPosition(CoinInfo(symbol: 'BTC'), 2.5),
        isTrue,
      );
      expect(controller.storageError, isNull);
    },
  );

  test(
    'each queued edit returns its own result even when the next edit succeeds',
    () async {
      final controller = _controller(storage: _FailFirstUserWrite());
      await controller.initialize();
      final failed = controller.toggleFavorite('BTC');
      final saved = controller.toggleFavorite('ETH');
      expect(await Future.wait([failed, saved]), [false, true]);
      expect(controller.favorites, {'ETH'});
      expect(controller.storageError, isNull);
      final restored = await LocalStorageService().read();
      expect(restored.favorites, {'ETH'});
    },
  );

  test(
    'a position is published only after the storage write succeeds',
    () async {
      final storage = _GatedWriteStorage();
      final controller = _controller(storage: storage);
      await controller.initialize();
      final edit = controller.upsertPosition(CoinInfo(symbol: 'BTC'), 2);
      await storage.started.future;
      expect(controller.positions, isEmpty);
      storage.result.completeError(StateError('write refused'));
      expect(await edit, isFalse);
      expect(controller.positions, isEmpty);
      expect(controller.storageError, isNotNull);
    },
  );

  test(
    'changing the key during a market request never publishes the old response',
    () async {
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      final first = Completer<http.Response>();
      final second = Completer<http.Response>();
      final headers = <String?>[];
      final controller = _controller(
        apiKey: 'old-key',
        client: MockClient((request) async {
          headers.add(request.headers['Authorization']);
          if (headers.length == 1) {
            firstStarted.complete();
            return first.future;
          }
          secondStarted.complete();
          return second.future;
        }),
      );
      final observedPrices = <double?>[];
      controller.addListener(
        () => observedPrices.add(controller.quoteFor('BTC')?.price),
      );
      final initialize = controller.initialize();
      await firstStarted.future;
      final replace = controller.setApiKey('new-key');
      first.complete(_quotes({'BTC': 10}));
      await secondStarted.future;
      expect(controller.quoteFor('BTC'), isNull);
      second.complete(_quotes({'BTC': 20}));
      await Future.wait([initialize, replace]);
      expect(headers, ['Apikey old-key', 'Apikey new-key']);
      expect(observedPrices, isNot(contains(10)));
      expect(controller.quoteFor('BTC')?.price, 20);
      expect(controller.apiKeyRevision, 1);
    },
  );

  test(
    'catalog and news requests discard old key results and retry the replacement',
    () async {
      final oldCatalogStarted = Completer<void>();
      final oldNewsStarted = Completer<void>();
      final newCatalogStarted = Completer<void>();
      final newNewsStarted = Completer<void>();
      final oldCatalog = Completer<http.Response>();
      final oldNews = Completer<http.Response>();
      final newCatalog = Completer<http.Response>();
      final newNews = Completer<http.Response>();
      final controller = _controller(
        apiKey: 'old-key',
        client: MockClient((request) async {
          final old = request.headers['Authorization'] == 'Apikey old-key';
          if (request.url.path.endsWith('all/coinlist')) {
            if (old) {
              oldCatalogStarted.complete();
              return oldCatalog.future;
            }
            newCatalogStarted.complete();
            return newCatalog.future;
          }
          if (request.url.path.endsWith('v2/news/')) {
            if (old) {
              oldNewsStarted.complete();
              return oldNews.future;
            }
            newNewsStarted.complete();
            return newNews.future;
          }
          return _quotes({'BTC': 100, 'ETH': 50});
        }),
      );
      await controller.initialize();
      final catalog = controller.loadCatalog();
      final news = controller.loadNews();
      await Future.wait([oldCatalogStarted.future, oldNewsStarted.future]);
      final replace = controller.setApiKey('new-key');
      oldCatalog.complete(
        _json({
          'Data': {
            'LINK': {'Symbol': 'LINK', 'CoinName': 'old catalog'},
          },
        }),
      );
      oldNews.complete(
        _json({'Response': 'Error', 'Message': 'API key invalid'}, status: 403),
      );
      await Future.wait([newCatalogStarted.future, newNewsStarted.future]);
      expect(controller.coinFor('LINK').coinName, 'LINK');
      expect(controller.newsError, isNull);
      newCatalog.complete(
        _json({
          'Data': {
            'LINK': {'Symbol': 'LINK', 'CoinName': 'Chainlink'},
          },
        }),
      );
      newNews.complete(
        _json({
          'Data': [
            {'title': 'Latest article'},
          ],
        }),
      );
      await Future.wait([catalog, news, replace]);
      expect(controller.coinFor('LINK').coinName, 'Chainlink');
      expect(controller.catalogLoaded, isTrue);
      expect(controller.news.single.title, 'Latest article');
      expect(controller.catalogError, isNull);
      expect(controller.newsError, isNull);
    },
  );

  test(
    'a missing new favorite is queried once without an automatic extra retry',
    () async {
      var requests = 0;
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final controller = _controller(
        client: MockClient((_) async {
          requests += 1;
          if (requests == 2) {
            started.complete();
            return response.future;
          }
          return _quotes({'BTC': 100});
        }),
      );
      await controller.initialize();
      final refresh = controller.refreshMarket();
      await started.future;
      expect(await controller.toggleFavorite('LINK'), isTrue);
      response.complete(_quotes({'BTC': 100}));
      await refresh;
      await Future<void>.delayed(Duration.zero);
      expect(requests, 3);
      expect(controller.quoteFor('LINK'), isNull);
      expect(controller.marketLoading, isFalse);
    },
  );

  test(
    'disposing during the storage read cannot publish data or start HTTP requests',
    () async {
      final storage = _GatedReadStorage();
      var requests = 0;
      final api = CryptoApiService(
        client: MockClient((_) async {
          requests += 1;
          return _quotes({'BTC': 100});
        }),
      );
      final controller = AppController(api: api, storage: storage);
      addTearDown(api.dispose);
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      final initialize = controller.initialize();
      await storage.started.future;
      controller.dispose();
      storage.release.complete();
      await initialize;
      expect(notifications, 0);
      expect(requests, 0);
      expect(controller.initialized, isFalse);
    },
  );

  test(
    'a late storage read cannot replace a catalog that already finished loading',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: jsonEncode({
          'favorites': ['BTC'],
          'positions': [],
          'coinReferences': {
            'BTC': {'coinName': 'outdated saved name'},
          },
        }),
      });
      final storage = _GatedReadStorage();
      final controller = _controller(
        storage: storage,
        client: MockClient((request) async {
          if (request.url.path.endsWith('all/coinlist')) {
            return _json({
              'Data': {
                'BTC': {'Symbol': 'BTC', 'CoinName': 'Bitcoin'},
              },
            });
          }
          return _quotes({'BTC': 100});
        }),
      );
      final initialize = controller.initialize();
      await storage.started.future;
      await controller.loadCatalog();
      storage.release.complete();
      await initialize;
      expect(controller.catalogLoaded, isTrue);
      expect(controller.coinFor('BTC').coinName, 'Bitcoin');
      expect(controller.favorites, {'BTC'});
    },
  );

  test(
    'portfolio symbols accept punctuation supported by the API and reject separators',
    () {
      expect(
        PortfolioPosition(symbol: ' btt* ', coinName: '', quantity: 1).symbol,
        'BTT*',
      );
      expect(
        PortfolioPosition(symbol: r'$pac', coinName: '', quantity: 1).symbol,
        r'$PAC',
      );
      for (final symbol in [
        '',
        'BTC,ETH',
        'BTC ETH',
        'BTC\u0000',
        'BTC\u007f',
      ]) {
        expect(
          () => PortfolioPosition(symbol: symbol, coinName: '', quantity: 1),
          throwsArgumentError,
        );
      }
    },
  );
}

String _user(List<Map<String, Object?>> positions) =>
    jsonEncode({'favorites': [], 'positions': positions});

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _quotes(Map<String, double> prices) => _json({
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
});

AppController _controller({
  http.Client? client,
  LocalStorageService? storage,
  String apiKey = '',
}) {
  final api = CryptoApiService(
    apiKey: apiKey,
    client: client ?? MockClient((_) async => _quotes({'BTC': 100, 'ETH': 50})),
  );
  final controller = AppController(
    api: api,
    storage: storage ?? LocalStorageService(),
  );
  addTearDown(() {
    controller.dispose();
    api.dispose();
  });
  return controller;
}

class _FailingReadStorage extends LocalStorageService {
  bool failRead = true;
  @override
  Future<StoredAppData> read() {
    if (failRead) throw StateError('read failed');
    return super.read();
  }
}

class _FailFirstUserWrite extends LocalStorageService {
  bool fail = true;
  @override
  Future<void> saveUserData({
    required Set<String> favorites,
    required List<PortfolioPosition> positions,
    required Map<String, CoinInfo> coins,
  }) {
    if (fail) {
      fail = false;
      throw StateError('first write failed');
    }
    return super.saveUserData(
      favorites: favorites,
      positions: positions,
      coins: coins,
    );
  }
}

class _GatedWriteStorage extends LocalStorageService {
  final started = Completer<void>();
  final result = Completer<void>();
  @override
  Future<void> saveUserData({
    required Set<String> favorites,
    required List<PortfolioPosition> positions,
    required Map<String, CoinInfo> coins,
  }) async {
    started.complete();
    await result.future;
    await super.saveUserData(
      favorites: favorites,
      positions: positions,
      coins: coins,
    );
  }
}

class _GatedReadStorage extends LocalStorageService {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<StoredAppData> read() async {
    started.complete();
    await release.future;
    return super.read();
  }
}
