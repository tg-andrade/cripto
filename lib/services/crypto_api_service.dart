import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/coin_info.dart';
import '../models/coin_price.dart';
import '../models/coin_quote.dart';
import '../models/news_article.dart';
import '../models/price_history.dart';
import '../utils/json_readers.dart';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.isOffline = false,
    this.needsApiKey = false,
    this.statusCode,
  });

  final String message;
  final bool isOffline;
  final bool needsApiKey;
  final int? statusCode;

  @override
  String toString() => message;
}

class CryptoApiService {
  CryptoApiService({
    http.Client? client,
    String apiKey = const String.fromEnvironment('CRYPTOCOMPARE_API_KEY'),
    Duration timeout = const Duration(seconds: 15),
    this.useQueryAuthentication = kIsWeb,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey.trim(),
       // Keep the injectable public parameter separate from internal state.
       // ignore: prefer_initializing_formals
       _timeout = timeout;

  final http.Client _client;
  final Duration _timeout;
  final bool useQueryAuthentication;
  String _apiKey;
  bool _disposed = false;

  String get apiKey => _apiKey;
  set apiKey(String value) => _apiKey = value.trim();
  bool get hasApiKey => _apiKey.isNotEmpty;

  void updateApiKey(String value) => apiKey = value;

  // The API limits fsyms by string length; keep every chunk below 300 chars.
  List<List<String>> _symbolChunks(List<String> symbols) {
    final normalized = symbols
        .map(normalizeSymbol)
        .where((symbol) => symbol.isNotEmpty)
        .toSet();
    final chunks = <List<String>>[];
    var chunk = <String>[];
    var length = 0;
    for (final symbol in normalized) {
      if (!isValidCryptoSymbol(symbol)) {
        throw const ApiException(message: 'O símbolo da moeda é inválido.');
      }
      final extra = symbol.length + (chunk.isEmpty ? 0 : 1);
      if (length + extra > 280 || chunk.length == 40) {
        chunks.add(chunk);
        chunk = <String>[];
        length = 0;
      }
      length += symbol.length + (chunk.isEmpty ? 0 : 1);
      chunk.add(symbol);
    }
    if (chunk.isNotEmpty) chunks.add(chunk);
    return chunks;
  }

  String _currency(String currency) {
    final normalized = normalizeSymbol(currency);
    if (!isValidCryptoSymbol(normalized)) {
      throw const ApiException(message: 'A moeda de conversão é inválida.');
    }
    return normalized;
  }

  Future<Map<String, CoinPrice>> getPrices(
    List<String> symbols, {
    String currency = 'BRL',
  }) async {
    final target = _currency(currency);
    final result = <String, CoinPrice>{};
    for (final chunk in _symbolChunks(symbols)) {
      final json = await _get('pricemulti', {
        'fsyms': chunk.join(','),
        'tsyms': target,
      });
      for (final symbol in chunk) {
        final raw = json[symbol];
        if (raw is! Map) continue;
        result[symbol] = CoinPrice.fromJson(raw, symbol: symbol);
      }
    }
    return result;
  }

  Future<Map<String, CoinQuote>> getQuotes(
    List<String> symbols, {
    String currency = 'BRL',
  }) async {
    final target = _currency(currency);
    final result = <String, CoinQuote>{};
    for (final chunk in _symbolChunks(symbols)) {
      final json = await _get('pricemultifull', {
        'fsyms': chunk.join(','),
        'tsyms': target,
      });
      final raw = jsonObject(json['RAW']);
      for (final symbol in chunk) {
        final quote = jsonObject(raw[symbol])[target];
        if (quote is! Map) continue;
        final parsed = CoinQuote.fromJson(
          quote,
          fromSymbol: symbol,
          toSymbol: target,
        );
        if (parsed.fromSymbol != symbol || parsed.toSymbol != target) continue;
        result[symbol] = parsed;
      }
    }
    return result;
  }

  Future<CoinQuote> getCoinDetails(
    String symbol, {
    String currency = 'BRL',
  }) async {
    final normalized = normalizeSymbol(symbol);
    final quotes = await getQuotes([normalized], currency: currency);
    final quote = quotes[normalized];
    if (quote == null || (quote.price != null && quote.price! <= 0)) {
      throw const ApiException(
        message: 'Não há cotação disponível para esta moeda.',
      );
    }
    return quote;
  }

  Future<Map<String, CoinInfo>> getCoinList() async {
    final json = await _get('all/coinlist');
    if (json['Data'] is! Map) throw _invalidResponse();
    final data = jsonObject(json['Data']);
    final coins = <String, CoinInfo>{};
    for (final entry in data.entries) {
      if (entry.value is! Map) continue;
      final coin = CoinInfo.fromJson(entry.value, symbol: entry.key);
      if (isValidCryptoSymbol(coin.symbol)) coins[coin.symbol] = coin;
    }
    return coins;
  }

  Future<PriceHistory> getDailyHistory(
    String symbol, {
    String currency = 'BRL',
    int limit = 30,
  }) => _getHistory('v2/histoday', symbol, currency, limit);

  Future<PriceHistory> getHourlyHistory(
    String symbol, {
    String currency = 'BRL',
    int limit = 30,
  }) => _getHistory('v2/histohour', symbol, currency, limit);

  Future<PriceHistory> getMinuteHistory(
    String symbol, {
    String currency = 'BRL',
    int limit = 30,
  }) => _getHistory('v2/histominute', symbol, currency, limit);

  Future<PriceHistory> _getHistory(
    String endpoint,
    String symbol,
    String currency,
    int limit,
  ) async {
    final chunks = _symbolChunks([symbol]);
    if (chunks.isEmpty) {
      throw const ApiException(message: 'Informe o símbolo da moeda.');
    }
    if (limit < 1 || limit > 2000) {
      throw const ApiException(
        message: 'O período deve conter entre 1 e 2000 registros.',
      );
    }
    final json = await _get(endpoint, {
      'fsym': chunks.single.single,
      'tsym': _currency(currency),
      'limit': limit.toString(),
    });
    final data = json['Data'];
    if (data is! List && (data is! Map || data['Data'] is! List)) {
      throw _invalidResponse();
    }
    return PriceHistory.fromJson(json);
  }

  Future<List<NewsArticle>> getNews() async {
    final json = await _get('v2/news/', {'lang': 'PT'});
    final data = json['Data'];
    if (data is! List) throw _invalidResponse();
    return [
      for (final article in data)
        if (article is Map) NewsArticle.fromJson(article),
    ];
  }

  Future<Map<String, Object?>> _get(
    String endpoint, [
    Map<String, String> parameters = const {},
  ]) async {
    if (_disposed) {
      throw const ApiException(message: 'O serviço de cotações foi encerrado.');
    }
    // Authorization causes a browser preflight that the legacy API rejects.
    final queryParameters = <String, String>{
      ...parameters,
      if (hasApiKey && useQueryAuthentication) 'api_key': _apiKey,
    };
    final uri = Uri.https(
      'min-api.cryptocompare.com',
      '/data/$endpoint',
      queryParameters.isEmpty ? null : queryParameters,
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      if (hasApiKey && !useQueryAuthentication)
        'Authorization': 'Apikey $_apiKey',
    };
    late final http.Response response;
    try {
      response = await _client.get(uri, headers: headers).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        message:
            'A consulta demorou demais. Verifique sua conexão e tente novamente.',
        isOffline: true,
      );
    } on http.ClientException {
      throw const ApiException(
        message:
            'Não foi possível conectar. Verifique sua conexão com a internet.',
        isOffline: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _responseError(response.statusCode, const {});
      }
      throw ApiException(
        message: 'O serviço enviou uma resposta inválida. Tente novamente.',
        statusCode: response.statusCode,
      );
    }
    final json = jsonObject(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseError(response.statusCode, json);
    }
    if (decoded is! Map) {
      throw ApiException(
        message: 'O serviço enviou uma resposta inválida. Tente novamente.',
        statusCode: response.statusCode,
      );
    }
    if (jsonString(json['Response'])?.toLowerCase() == 'error') {
      throw _responseError(response.statusCode, json);
    }
    return json;
  }

  ApiException _responseError(int statusCode, Map<String, Object?> json) {
    final message = (jsonString(json['Message']) ?? '').toLowerCase();
    final rateLimited =
        statusCode == 429 ||
        (statusCode != 401 &&
            statusCode != 403 &&
            statusCode < 500 &&
            (message.contains('rate limit') || message.contains('rate_limit')));
    if (rateLimited) {
      return ApiException(
        message:
            'O limite de consultas foi atingido. Aguarde e tente novamente.',
        statusCode: statusCode,
      );
    }
    final requiresKey =
        statusCode == 401 ||
        statusCode == 403 ||
        (statusCode < 500 &&
            (message.contains('api key') ||
                message.contains('apikey') ||
                message.contains('unauthorized') ||
                message.contains('authentication') ||
                message.contains('authorization')));
    if (requiresKey) {
      return ApiException(
        message:
            'Configure uma chave válida da CryptoCompare para consultar os dados.',
        needsApiKey: true,
        statusCode: statusCode,
      );
    }
    return ApiException(
      message: statusCode >= 500
          ? 'O serviço de cotações está indisponível. Tente novamente mais tarde.'
          : 'A CryptoCompare não conseguiu atender à consulta. Tente novamente.',
      statusCode: statusCode,
    );
  }

  ApiException _invalidResponse() => const ApiException(
    message: 'O serviço enviou uma resposta inválida. Tente novamente.',
    statusCode: 200,
  );

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
