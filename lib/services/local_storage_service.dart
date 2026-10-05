import 'dart:convert';

// Public constructor names stay independent from private storage fields.
// ignore_for_file: prefer_initializing_formals

import 'package:shared_preferences/shared_preferences.dart';

import '../models/coin_info.dart';
import '../models/coin_quote.dart';
import '../models/portfolio_position.dart';

class StoredAppData {
  const StoredAppData({
    this.favorites = const <String>{},
    this.positions = const <PortfolioPosition>[],
    this.coins = const <String, CoinInfo>{},
    this.quotes = const <String, CoinQuote>{},
    this.quoteRefreshTimes = const <String, DateTime>{},
    this.userDataReadable = true,
    this.lastRefresh,
    this.error,
  });

  final Set<String> favorites;
  final List<PortfolioPosition> positions;
  final Map<String, CoinInfo> coins;
  final Map<String, CoinQuote> quotes;
  final Map<String, DateTime> quoteRefreshTimes;
  final bool userDataReadable;
  final DateTime? lastRefresh;
  final String? error;
}

/// Favorites, positions and referenced coin metadata share one JSON document:
/// a local edit needs one preference write. Quotes and their timestamp use a
/// second document. API keys are never stored. Inject preferences for tests.
class LocalStorageService {
  LocalStorageService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const userDataKey = 'cryptohub.user.v1';
  static const quoteCacheKey = 'cryptohub.quotes.v1';

  SharedPreferences? _preferences;
  Future<void> _writeTail = Future<void>.value();

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  /// Invalid rows are skipped independently, preserving all valid saved data.
  Future<StoredAppData> read() async {
    await _writeTail;
    final preferences = await _prefs;
    var invalid = false;
    var userDataReadable = true;
    Map<String, dynamic>? document(String key) {
      final raw = preferences.get(key);
      if (raw == null) return null;
      try {
        if (raw is! String) throw const FormatException('Tipo inválido.');
        final decoded = jsonDecode(raw);
        if (decoded is! Map) throw const FormatException('Documento inválido.');
        return Map<String, dynamic>.from(decoded);
      } catch (_) {
        invalid = true;
        if (key == userDataKey) userDataReadable = false;
        return null;
      }
    }

    final favorites = <String>{};
    final positions = <String, PortfolioPosition>{};
    final coins = <String, CoinInfo>{};
    final user = document(userDataKey);
    if (user != null) {
      final savedFavorites = user['favorites'];
      if (savedFavorites is List) {
        for (final row in savedFavorites) {
          try {
            if (row is! String) {
              throw const FormatException('Favorito inválido.');
            }
            favorites.add(PortfolioPosition.normalizeSymbol(row));
          } catch (_) {
            invalid = true;
          }
        }
      } else if (savedFavorites != null) {
        invalid = true;
      }
      final savedPositions = user['positions'];
      if (savedPositions is List) {
        for (final row in savedPositions) {
          try {
            if (row is! Map) throw const FormatException('Posição inválida.');
            final positionJson = Map<String, dynamic>.from(row);
            final name = positionJson['coinName'];
            final image = positionJson['imageUrl'];
            if ((name != null && name is! String) ||
                (image != null && image is! String)) {
              invalid = true;
            }
            final position = PortfolioPosition.fromJson(positionJson);
            positions[position.symbol] = position;
            coins[position.symbol] = position.coin;
          } catch (_) {
            invalid = true;
          }
        }
      } else if (savedPositions != null) {
        invalid = true;
      }
      final savedCoins = user['coinReferences'];
      if (savedCoins is Map) {
        for (final entry in savedCoins.entries) {
          try {
            if (entry.key is! String || entry.value is! Map) {
              throw const FormatException('Moeda inválida.');
            }
            final symbol = PortfolioPosition.normalizeSymbol(
              entry.key as String,
            );
            if (!favorites.contains(symbol) && !positions.containsKey(symbol)) {
              continue;
            }
            final row = Map<String, dynamic>.from(entry.value as Map);
            final coinName = row['coinName'];
            final imageUrl = row['imageUrl'];
            if ((coinName != null && coinName is! String) ||
                (imageUrl != null && imageUrl is! String)) {
              throw const FormatException('Metadados inválidos.');
            }
            coins[symbol] = CoinInfo(
              symbol: symbol,
              id: row['id'] is String ? row['id'] as String : null,
              coinName: coinName as String?,
              algorithm: row['algorithm'] is String
                  ? row['algorithm'] as String
                  : null,
              imageUrl: imageUrl as String?,
            );
          } catch (_) {
            invalid = true;
          }
        }
      } else if (savedCoins != null) {
        invalid = true;
      }
    }

    final quotes = <String, CoinQuote>{};
    final quoteRefreshTimes = <String, DateTime>{};
    DateTime? lastRefresh;
    final cache = document(quoteCacheKey);
    if (cache != null) {
      final savedQuotes = cache['quotes'];
      if (cache['currency'] != 'BRL') {
        invalid = true;
      } else if (savedQuotes is Map) {
        for (final entry in savedQuotes.entries) {
          try {
            if (entry.key is! String || entry.value is! Map) {
              throw const FormatException('Cotação inválida.');
            }
            final symbol = PortfolioPosition.normalizeSymbol(
              entry.key as String,
            );
            final quote = CoinQuote.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
            if (quote.fromSymbol.toUpperCase() != symbol ||
                quote.toSymbol != 'BRL' ||
                quote.price == null ||
                !quote.price!.isFinite ||
                quote.price! <= 0) {
              throw const FormatException('Cotação inválida.');
            }
            quotes[symbol] = quote;
          } catch (_) {
            invalid = true;
          }
        }
      } else {
        invalid = true;
      }
      final savedTime = cache['updatedAt'];
      if (savedTime is String) {
        lastRefresh = DateTime.tryParse(savedTime)?.toUtc();
      }
      if (lastRefresh != null &&
          lastRefresh.isAfter(
            DateTime.now().toUtc().add(const Duration(minutes: 5)),
          )) {
        lastRefresh = null;
        invalid = true;
      }
      if (lastRefresh == null && quotes.isNotEmpty) invalid = true;
      final savedQuoteTimes = cache['quoteUpdatedAt'];
      if (savedQuoteTimes == null) {
        // Earlier versions wrote a single timestamp for the complete batch.
        if (lastRefresh != null) {
          for (final symbol in quotes.keys) {
            quoteRefreshTimes[symbol] = lastRefresh;
          }
        }
      } else if (savedQuoteTimes is Map) {
        for (final symbol in quotes.keys) {
          final raw = savedQuoteTimes[symbol];
          final timestamp = raw is String
              ? DateTime.tryParse(raw)?.toUtc()
              : null;
          if (timestamp == null ||
              lastRefresh == null ||
              timestamp.isAfter(lastRefresh)) {
            invalid = true;
          } else {
            quoteRefreshTimes[symbol] = timestamp;
          }
        }
      } else {
        invalid = true;
      }
    }
    return StoredAppData(
      favorites: favorites,
      positions: positions.values.toList(growable: false),
      coins: coins,
      quotes: quotes,
      quoteRefreshTimes: quoteRefreshTimes,
      userDataReadable: userDataReadable,
      lastRefresh: lastRefresh,
      error: invalid ? 'Alguns dados locais inválidos foram ignorados.' : null,
    );
  }

  /// Only referenced metadata is persisted, never the entire remote catalog.
  Future<void> saveUserData({
    required Set<String> favorites,
    required List<PortfolioPosition> positions,
    required Map<String, CoinInfo> coins,
  }) {
    final references = <String>{
      ...favorites,
      ...positions.map((p) => p.symbol),
    };
    final encoded = jsonEncode({
      'favorites': favorites.toList()..sort(),
      'positions': positions.map((position) => position.toJson()).toList(),
      'coinReferences': {
        for (final symbol in references)
          if (coins[symbol] != null) symbol: coins[symbol]!.toJson(),
      },
    });
    return _serializeWrite(() => _writeString(userDataKey, encoded));
  }

  Future<void> saveQuoteCache(
    Map<String, CoinQuote> quotes,
    DateTime updatedAt, {
    String currency = 'BRL',
    Map<String, DateTime>? quoteRefreshTimes,
  }) {
    final encoded = jsonEncode({
      'currency': currency,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'quoteUpdatedAt': {
        for (final symbol in quotes.keys)
          if (quoteRefreshTimes == null || quoteRefreshTimes[symbol] != null)
            symbol: (quoteRefreshTimes?[symbol] ?? updatedAt)
                .toUtc()
                .toIso8601String(),
      },
      'quotes': {
        for (final entry in quotes.entries) entry.key: entry.value.toJson(),
      },
    });
    return _serializeWrite(() => _writeString(quoteCacheKey, encoded));
  }

  Future<void> _serializeWrite(Future<void> Function() operation) {
    final write = _writeTail.then((_) => operation());
    _writeTail = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

  Future<void> _writeString(String key, String value) async {
    final preferences = await _prefs;
    final previous = preferences.get(key);
    try {
      if (!await preferences.setString(key, value)) {
        throw StateError('O armazenamento recusou a gravação.');
      }
    } catch (_) {
      // SharedPreferences updates memory before awaiting the platform result.
      // Restore that cache too when the platform refuses or fails a write.
      try {
        if (previous is String) {
          await preferences.setString(key, previous);
        } else {
          await preferences.remove(key);
        }
      } catch (_) {
        // The controller still restores its visible state and reports failure.
      }
      rethrow;
    }
  }
}
