import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/coin_info.dart';
import '../models/coin_quote.dart';
import '../models/news_article.dart';
import '../models/portfolio_position.dart';
import '../services/crypto_api_service.dart';
import '../services/local_storage_service.dart';

class AppController extends ChangeNotifier {
  AppController({required this.api, required this.storage}) {
    const names = {
      'BTC': 'Bitcoin',
      'ETH': 'Ethereum',
      'SOL': 'Solana',
      'BNB': 'BNB',
      'XRP': 'XRP',
      'ADA': 'Cardano',
      'DOGE': 'Dogecoin',
      'AVAX': 'Avalanche',
    };
    _coins.addAll({
      for (final entry in names.entries)
        entry.key: CoinInfo(symbol: entry.key, coinName: entry.value),
    });
  }

  final CryptoApiService api;
  final LocalStorageService storage;
  final String currency = 'BRL';

  List<String> get marketSymbols => const [
    'BTC',
    'ETH',
    'SOL',
    'BNB',
    'XRP',
    'ADA',
    'DOGE',
    'AVAX',
  ];
  Map<String, CoinInfo> get coins => UnmodifiableMapView(_coins);
  Map<String, CoinQuote> get quotes => UnmodifiableMapView(_quotes);
  Set<String> get favorites => Set<String>.unmodifiable(_favorites);
  List<PortfolioPosition> get positions =>
      List<PortfolioPosition>.unmodifiable(_positions);
  List<NewsArticle> get news => List<NewsArticle>.unmodifiable(_news);
  bool get initialized => _initialized;
  bool get storageReady => _storageReady;
  bool get marketLoading => _marketLoading;
  bool get newsLoading => _newsLoading;
  bool get catalogLoading => _catalogLoading;
  bool get catalogLoaded => _catalogLoaded;
  bool get hasCachedQuotes =>
      _quotes.values.any((quote) => _usablePrice(quote));
  bool get hasApiKey => api.hasApiKey;
  int get apiKeyRevision => _apiKeyRevision;
  bool get offline => _offline;
  String? get marketError => _marketError;
  String? get newsError => _newsError;
  String? get catalogError => _catalogError;
  String? get storageError =>
      _userStorageError ?? _storageReadError ?? _cacheStorageError;
  DateTime? get lastRefresh => _lastRefresh;

  final Map<String, CoinInfo> _coins = {};
  final Map<String, CoinQuote> _quotes = {};
  final Map<String, DateTime> _quoteRefreshTimes = {};
  Set<String> _favorites = {};
  List<PortfolioPosition> _positions = [];
  List<NewsArticle> _news = [];
  bool _initialized = false;
  bool _storageReady = false;
  bool _marketLoading = false;
  bool _newsLoading = false;
  bool _catalogLoading = false;
  bool _catalogLoaded = false;
  bool _offline = false;
  bool _disposed = false;
  int _apiKeyRevision = 0;
  bool _newsRequested = false;
  bool _catalogRequested = false;
  String? _marketError;
  String? _newsError;
  String? _catalogError;
  String? _userStorageError;
  String? _storageReadError;
  String? _cacheStorageError;
  DateTime? _lastRefresh;
  Set<String> _lastAttemptedSymbols = {};
  Future<bool>? _storageLoadFuture;
  Future<void>? _initializeFuture;
  Future<void>? _marketFuture;
  Future<void>? _newsFuture;
  Future<void>? _catalogFuture;
  Future<void> _editTail = Future<void>.value();

  List<String> get quoteNeededSymbols => <String>{
    ...marketSymbols,
    ..._favorites,
    ..._positions.map((position) => position.symbol),
  }.toList(growable: false);

  CoinInfo coinFor(String symbol) {
    final normalized = symbol.trim().toUpperCase();
    return _coins[normalized] ??
        CoinInfo(symbol: normalized, coinName: normalized);
  }

  CoinQuote? quoteFor(String symbol) => _quotes[symbol.trim().toUpperCase()];

  DateTime? quoteRefreshedAt(String symbol) =>
      _quoteRefreshTimes[symbol.trim().toUpperCase()];

  /// A failed refresh or an older refresh cohort identifies a retained quote.
  bool isQuoteStale(String symbol) =>
      quoteFor(symbol) != null &&
      (_marketError != null || !_matchesLastRefresh(symbol));

  bool _matchesLastRefresh(String symbol) {
    final timestamp = quoteRefreshedAt(symbol);
    return timestamp != null &&
        _lastRefresh != null &&
        timestamp.isAtSameMomentAs(_lastRefresh!);
  }

  bool _usablePrice(CoinQuote quote) =>
      quote.toSymbol == currency &&
      quote.price != null &&
      quote.price!.isFinite &&
      quote.price! > 0;

  double? positionValue(PortfolioPosition position) {
    final quote = quoteFor(position.symbol);
    if (quote == null || !_usablePrice(quote)) return null;
    final value = quote.price! * position.quantity;
    return value.isFinite && value > 0 ? value : null;
  }

  /// Cached totals remain usable after a failed request. A partial successful
  /// refresh cannot mix old and new prices into one total; all positions must
  /// have prices from the latest successful refresh cohort.
  double? get portfolioTotal {
    var total = 0.0;
    for (final position in _positions) {
      if (!_matchesLastRefresh(position.symbol)) return null;
      final value = positionValue(position);
      if (value == null) return null;
      total += value;
      if (!total.isFinite) return null;
    }
    return total;
  }

  bool get portfolioIncomplete =>
      _positions.isNotEmpty && portfolioTotal == null;

  Future<void> initialize() {
    if (_disposed) return Future<void>.value();
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    await _loadSavedData();
    if (!_disposed) await refreshMarket();
  }

  Future<bool> _loadSavedData({bool retry = false}) {
    if (_disposed) return Future<bool>.value(false);
    if (_storageReady) return Future<bool>.value(true);
    if (_initialized && !retry) return Future<bool>.value(false);
    return _storageLoadFuture ??= Future<bool>.microtask(
      _readSavedData,
    ).whenComplete(() => _storageLoadFuture = null);
  }

  Future<bool> _readSavedData() async {
    try {
      final saved = await storage.read();
      if (_disposed) return false;
      _favorites = Set<String>.of(saved.favorites);
      _positions = List<PortfolioPosition>.of(saved.positions);
      if (_catalogLoaded) {
        for (final entry in saved.coins.entries) {
          _coins.putIfAbsent(entry.key, () => entry.value);
        }
      } else {
        _coins.addAll(saved.coins);
      }
      _quotes.addAll(saved.quotes);
      _quoteRefreshTimes.addAll(saved.quoteRefreshTimes);
      _lastRefresh = saved.lastRefresh;
      _storageReadError = saved.error;
      _storageReady = saved.userDataReadable;
      if (_storageReady) _userStorageError = null;
      _lastAttemptedSymbols = saved.quotes.keys.toSet().intersection(
        quoteNeededSymbols.toSet(),
      );
      return _storageReady;
    } catch (_) {
      if (!_disposed) {
        _storageReadError =
            'Não foi possível ler os dados salvos neste dispositivo. Tente novamente antes de editar.';
      }
      return false;
    } finally {
      if (!_disposed) {
        _initialized = true;
        _notify();
      }
    }
  }

  /// Retries the local read before enabling writes; existing unread data is
  /// never replaced by an empty portfolio after a storage initialization error.
  Future<bool> retryStorage() async {
    final loaded = await _loadSavedData(retry: true);
    if (loaded && !_disposed) unawaited(refreshMarket());
    return loaded;
  }

  Future<void> refreshMarket() {
    if (_disposed) return Future<void>.value();
    return _marketFuture ??= Future<void>.microtask(
      _refreshUntilStable,
    ).whenComplete(() => _marketFuture = null);
  }

  Future<void> _refreshUntilStable() async {
    if (!_initialized) await _loadSavedData();
    if (_disposed) return;
    _marketLoading = true;
    _marketError = null;
    _notify();
    try {
      while (!_disposed) {
        final requested = quoteNeededSymbols.toSet();
        final revision = _apiKeyRevision;
        _lastAttemptedSymbols = requested;
        try {
          final loaded = await api.getQuotes(
            requested.toList(),
            currency: currency,
          );
          if (_disposed) return;
          if (revision != _apiKeyRevision) continue;
          final needed = quoteNeededSymbols.toSet();
          final valid = <String, CoinQuote>{
            for (final entry in loaded.entries)
              if (needed.contains(entry.key) &&
                  requested.contains(entry.key) &&
                  entry.value.fromSymbol.toUpperCase() == entry.key &&
                  _usablePrice(entry.value))
                entry.key: entry.value,
          };
          if (valid.isEmpty) {
            throw const ApiException(
              message: 'Não há cotações disponíveis para atualizar o mercado.',
            );
          }
          final refreshedAt = _nextRefreshTime();
          _quotes.addAll(valid);
          for (final symbol in valid.keys) {
            _quoteRefreshTimes[symbol] = refreshedAt;
          }
          _pruneQuotes();
          _lastRefresh = refreshedAt;
          _marketError = null;
          _offline = false;
          _notify();
          if (_storageReady) {
            try {
              await storage.saveQuoteCache(
                _quotes,
                refreshedAt,
                currency: currency,
                quoteRefreshTimes: _quoteRefreshTimes,
              );
              if (!_disposed) _cacheStorageError = null;
            } catch (_) {
              if (!_disposed) {
                _cacheStorageError =
                    'Não foi possível salvar as cotações neste dispositivo.';
              }
            }
          }
          if (_disposed) return;
          if (revision != _apiKeyRevision) continue;
          if (quoteNeededSymbols.toSet().difference(requested).isEmpty) return;
        } catch (error) {
          if (_disposed) return;
          if (revision != _apiKeyRevision) continue;
          _marketError = _apiMessage(error);
          _offline = error is ApiException && error.isOffline;
          return;
        }
      }
    } finally {
      if (!_disposed) {
        _marketLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadNews() {
    if (_disposed) return Future<void>.value();
    _newsRequested = true;
    return _newsFuture ??= Future<void>.microtask(
      _loadNews,
    ).whenComplete(() => _newsFuture = null);
  }

  Future<void> _loadNews() async {
    if (_disposed) return;
    _newsLoading = true;
    _newsError = null;
    _notify();
    try {
      while (!_disposed) {
        final revision = _apiKeyRevision;
        try {
          final loaded = await api.getNews();
          if (_disposed) return;
          if (revision != _apiKeyRevision) continue;
          _news = List<NewsArticle>.of(loaded);
          _offline = false;
          return;
        } catch (error) {
          if (_disposed) return;
          if (revision != _apiKeyRevision) continue;
          _newsError = _apiMessage(error);
          _offline = error is ApiException && error.isOffline;
          return;
        }
      }
    } finally {
      if (!_disposed) {
        _newsLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadCatalog() {
    if (_disposed) return Future<void>.value();
    _catalogRequested = true;
    return _catalogFuture ??= Future<void>.microtask(
      _loadCatalog,
    ).whenComplete(() => _catalogFuture = null);
  }

  Future<void> _loadCatalog() async {
    if (_disposed) return;
    _catalogLoading = true;
    _catalogError = null;
    _notify();
    try {
      while (!_disposed) {
        final revision = _apiKeyRevision;
        try {
          final loaded = await api.getCoinList();
          if (_disposed) return;
          if (revision != _apiKeyRevision) continue;
          _coins.addAll(loaded);
          _catalogLoaded = true;
          _offline = false;
          if (_storageReady &&
              (_favorites.isNotEmpty || _positions.isNotEmpty)) {
            await _enqueueEdit(
              () => _persistUserData(_favorites, _positions, _coins),
            );
          }
          if (_disposed) return;
          if (revision != _apiKeyRevision) continue;
          return;
        } catch (error) {
          if (_disposed) return;
          if (revision != _apiKeyRevision) continue;
          _catalogError = _apiMessage(error);
          _offline = error is ApiException && error.isOffline;
          return;
        }
      }
    } finally {
      if (!_disposed) {
        _catalogLoading = false;
        _notify();
      }
    }
  }

  Future<bool> toggleFavorite(String symbol) {
    final normalized = PortfolioPosition.normalizeSymbol(symbol);
    return _enqueueEdit(() async {
      final next = Set<String>.of(_favorites);
      final added = !next.remove(normalized);
      if (added) next.add(normalized);
      if (!await _persistUserData(next, _positions, _coins)) return false;
      _favorites = next;
      _pruneQuotes();
      _notify();
      if (added && !_disposed) unawaited(_refreshMissingQuote(normalized));
      return true;
    });
  }

  Future<bool> upsertPosition(CoinInfo coin, double quantity) {
    final position = PortfolioPosition(
      symbol: coin.symbol,
      coinName: coin.coinName,
      quantity: quantity,
      imageUrl: coin.imageUrl,
    );
    return _enqueueEdit(() async {
      final next = List<PortfolioPosition>.of(_positions);
      final index = next.indexWhere((item) => item.symbol == position.symbol);
      if (index < 0) {
        next.add(position);
      } else {
        next[index] = position;
      }
      final nextCoins = Map<String, CoinInfo>.of(_coins)
        ..[position.symbol] = coin;
      if (!await _persistUserData(_favorites, next, nextCoins)) return false;
      _positions = next;
      _coins[position.symbol] = coin;
      _notify();
      if (!_disposed) unawaited(_refreshMissingQuote(position.symbol));
      return true;
    });
  }

  Future<bool> removePosition(String symbol) {
    final normalized = PortfolioPosition.normalizeSymbol(symbol);
    return _enqueueEdit(() async {
      final next = _positions
          .where((position) => position.symbol != normalized)
          .toList();
      if (!await _persistUserData(_favorites, next, _coins)) return false;
      _positions = next;
      _pruneQuotes();
      _notify();
      return true;
    });
  }

  Future<bool> _persistUserData(
    Set<String> favorites,
    List<PortfolioPosition> positions,
    Map<String, CoinInfo> coins,
  ) async {
    try {
      await storage.saveUserData(
        favorites: favorites,
        positions: positions,
        coins: coins,
      );
      _userStorageError = null;
      _storageReadError = null;
      return true;
    } catch (_) {
      _userStorageError =
          'Não foi possível salvar a carteira e os favoritos. Tente novamente.';
      _notify();
      return false;
    }
  }

  Future<void> setApiKey(String value) async {
    if (_disposed) return;
    final trimmed = value.trim();
    if (api.apiKey != trimmed) _apiKeyRevision++;
    final revision = _apiKeyRevision;
    api.updateApiKey(trimmed);
    _marketError = null;
    _notify();
    // The shared request retries internally if its original key was replaced.
    await refreshMarket();
    if (_disposed || revision != _apiKeyRevision) return;
    if (_catalogRequested) await loadCatalog();
    if (_disposed || revision != _apiKeyRevision) return;
    if (_newsRequested) await loadNews();
  }

  Future<void> _refreshMissingQuote(String symbol) async {
    if (_disposed) return;
    final pending = _marketFuture;
    if (pending != null) {
      await pending;
      // A missing API price is not an instruction to issue the same request again.
      if (_lastAttemptedSymbols.contains(symbol)) return;
    }
    if (!_disposed &&
        quoteNeededSymbols.contains(symbol) &&
        (quoteFor(symbol) == null ||
            !_matchesLastRefresh(symbol) ||
            !_lastAttemptedSymbols.contains(symbol))) {
      await refreshMarket();
    }
  }

  void _pruneQuotes() {
    final needed = quoteNeededSymbols.toSet();
    _quotes.removeWhere((symbol, _) => !needed.contains(symbol));
    _quoteRefreshTimes.removeWhere((symbol, _) => !needed.contains(symbol));
  }

  DateTime _nextRefreshTime() {
    final now = DateTime.now().toUtc();
    final previous = _lastRefresh;
    return previous == null || now.isAfter(previous)
        ? now
        : previous.add(const Duration(microseconds: 1));
  }

  Future<bool> _enqueueEdit(Future<bool> Function() operation) {
    final edit = _editTail.then((_) async {
      if (_disposed) return false;
      if (!_initialized) await _loadSavedData();
      if (_disposed) return false;
      if (!_storageReady) {
        _userStorageError =
            'Os dados salvos ainda não foram lidos. Tente carregar o armazenamento novamente antes de editar.';
        _notify();
        return false;
      }
      return operation();
    });
    _editTail = edit.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return edit;
  }

  String _apiMessage(Object error) => error is ApiException
      ? error.message
      : 'Não foi possível atualizar os dados. Tente novamente.';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
