import 'package:flutter/foundation.dart';
import '../models/portfolio_position.dart';
import '../models/price_history.dart';
import '../services/crypto_api_service.dart';

/// Applies today's quantities to historical prices; purchase dates are unknown.
class PortfolioHistoryController extends ChangeNotifier {
  PortfolioHistoryController(this.api);
  final CryptoApiService api;
  List<PriceHistoryPoint> points = [];
  bool loading = false;
  String? error;
  bool _disposed = false;
  int _generation = 0;

  Future<void> load(List<PortfolioPosition> positions, {int days = 30}) async {
    if (_disposed) return;
    positions = List.of(positions);
    final key = api.apiKey;
    final generation = ++_generation;
    loading = positions.isNotEmpty;
    error = null;
    points = [];
    notifyListeners();
    if (positions.isEmpty) return;
    try {
      final histories = <Map<DateTime, double>>[];
      for (var start = 0; start < positions.length; start += 3) {
        final batch = positions.skip(start).take(3).toList();
        final results = await Future.wait(
          batch.map(
            (position) => api.getDailyHistory(position.symbol, limit: days),
          ),
        );
        if (_disposed || generation != _generation) return;
        for (var index = 0; index < batch.length; index++) {
          final values = <DateTime, double>{};
          for (final point in results[index].points) {
            if (point.close == null ||
                !point.close!.isFinite ||
                point.close! <= 0) {
              continue;
            }
            final utc = point.time.toUtc();
            final date = DateTime.utc(utc.year, utc.month, utc.day);
            final value = point.close! * batch[index].quantity;
            if (value.isFinite && value > 0) values[date] = value;
          }
          histories.add(values);
        }
      }
      final dates = histories.first.keys.toSet();
      for (final history in histories.skip(1)) {
        dates.retainAll(history.keys);
      }
      final ordered = dates.toList()..sort();
      final combined = [
        for (final date in ordered)
          PriceHistoryPoint(
            time: date,
            close: histories.fold<double>(
              0,
              (sum, values) => sum + values[date]!,
            ),
          ),
      ].where((point) => point.close!.isFinite).toList();
      if (combined.isEmpty) {
        throw const ApiException(
          message:
              'Não há histórico completo para todos os ativos neste período.',
        );
      }
      if (!_disposed && generation == _generation && api.apiKey == key) {
        points = combined;
      }
    } catch (exception) {
      if (!_disposed && generation == _generation && api.apiKey == key) {
        error = exception is ApiException
            ? exception.message
            : 'Não foi possível calcular a evolução da carteira.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        if (api.apiKey != key) {
          await load(positions, days: days);
        } else {
          notifyListeners();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
