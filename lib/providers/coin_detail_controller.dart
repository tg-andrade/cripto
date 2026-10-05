import 'package:flutter/foundation.dart';
import '../models/coin_quote.dart';
import '../models/price_history.dart';
import '../services/crypto_api_service.dart';

enum HistoryPeriod {
  day('1D', 24),
  week('7D', 7),
  month('30D', 30),
  quarter('90D', 90),
  year('1A', 365);

  const HistoryPeriod(this.label, this.limit);
  final String label;
  final int limit;
}

class CoinDetailController extends ChangeNotifier {
  CoinDetailController({required this.api, required this.symbol, this.quote});
  final CryptoApiService api;
  final String symbol;
  CoinQuote? quote;
  List<PriceHistoryPoint> points = [];
  HistoryPeriod period = HistoryPeriod.month;
  bool quoteLoading = false, historyLoading = false;
  String? quoteError, historyError;
  bool _disposed = false;
  int _quoteGeneration = 0, _historyGeneration = 0;
  Future<void>? _quoteFuture;
  String? _quoteRequestKey;

  Future<void> load() async {
    await Future.wait([loadQuote(), loadHistory()]);
  }

  Future<void> loadQuote() {
    if (_disposed) return Future<void>.value();
    final key = api.apiKey;
    if (_quoteFuture != null && _quoteRequestKey == key) return _quoteFuture!;
    final generation = ++_quoteGeneration;
    _quoteRequestKey = key;
    final future = Future<void>.microtask(() => _loadQuote(generation, key));
    _quoteFuture = future;
    quoteLoading = true;
    quoteError = null;
    notifyListeners();
    return future;
  }

  Future<void> _loadQuote(int generation, String key) async {
    try {
      final result = await api.getCoinDetails(symbol);
      if (_isCurrentQuote(generation, key)) quote = result;
    } catch (error) {
      if (_isCurrentQuote(generation, key)) {
        quoteError = error is ApiException
            ? error.message
            : 'Não foi possível consultar esta moeda.';
      }
    } finally {
      if (!_disposed && generation == _quoteGeneration) {
        quoteLoading = false;
        _quoteFuture = null;
        if (api.apiKey != key) {
          await loadQuote();
        } else {
          notifyListeners();
        }
      }
    }
  }

  bool _isCurrentQuote(int generation, String key) =>
      !_disposed && generation == _quoteGeneration && api.apiKey == key;

  Future<void> selectPeriod(HistoryPeriod value) async {
    if (_disposed) return;
    if (period == value && (historyLoading || points.isNotEmpty)) return;
    period = value;
    await loadHistory();
  }

  Future<void> loadHistory() async {
    if (_disposed) return;
    final generation = ++_historyGeneration;
    final requested = period;
    final key = api.apiKey;
    historyLoading = true;
    historyError = null;
    points = [];
    notifyListeners();
    try {
      final result = requested == HistoryPeriod.day
          ? await api.getHourlyHistory(symbol, limit: requested.limit)
          : await api.getDailyHistory(symbol, limit: requested.limit);
      if (!_disposed && generation == _historyGeneration && key == api.apiKey) {
        points = result.points;
      }
    } catch (error) {
      if (!_disposed && generation == _historyGeneration && key == api.apiKey) {
        historyError = error is ApiException
            ? error.message
            : 'Não foi possível carregar o histórico.';
      }
    } finally {
      if (!_disposed && generation == _historyGeneration) {
        historyLoading = false;
        if (api.apiKey != key) {
          await loadHistory();
        } else {
          notifyListeners();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _quoteGeneration++;
    _historyGeneration++;
    super.dispose();
  }
}
