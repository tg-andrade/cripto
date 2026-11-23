import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/portfolio_position.dart';

class PortfolioApiException implements Exception {
  const PortfolioApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client for the CryptoHub API. Set CRYPTOHUB_API_URL to point the app at
/// the computer running the API when using an emulator or physical device.
class PortfolioApiService {
  PortfolioApiService({
    http.Client? client,
    String baseUrl = const String.fromEnvironment(
      'CRYPTOHUB_API_URL',
      defaultValue: 'http://localhost:3000/api',
    ),
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;

  Future<List<PortfolioPosition>> getPortfolio() async {
    final response = await _send('GET', '$_baseUrl/portfolio');
    final decoded = _decode(response);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const PortfolioApiException(
        'A API retornou uma carteira inválida.',
      );
    }
    try {
      return assets
          .whereType<Map>()
          .map(
            (row) => PortfolioPosition.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } on Object {
      throw const PortfolioApiException('A API retornou ativos inválidos.');
    }
  }

  Future<void> saveAsset(PortfolioPosition position) async {
    final symbol = Uri.encodeComponent(position.symbol);
    final response = await _send(
      'PUT',
      '$_baseUrl/portfolio/assets/$symbol',
      body: position.toJson(),
    );
    _decode(response);
  }

  Future<void> deleteAsset(String symbol) async {
    final response = await _send(
      'DELETE',
      '$_baseUrl/portfolio/assets/${Uri.encodeComponent(symbol)}',
    );
    _decode(response);
  }

  Future<http.Response> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse(url);
      final request = http.Request(method, uri)
        ..headers['accept'] = 'application/json';
      if (body != null) {
        request.headers['content-type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on Object catch (error) {
      if (error is PortfolioApiException) rethrow;
      throw const PortfolioApiException(
        'Não foi possível conectar à API da carteira. Confira se o servidor está iniciado.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const PortfolioApiException(
        'A API retornou uma resposta inválida.',
      );
    }
    if (decoded is! Map) {
      throw const PortfolioApiException(
        'A API retornou uma resposta inválida.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['error'];
      throw PortfolioApiException(
        message is String ? message : 'A API recusou a operação.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  void dispose() => _client.close();
}
