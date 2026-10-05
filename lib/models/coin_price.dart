import '../utils/json_readers.dart';

class CoinPrice {
  CoinPrice({required String symbol, required Map<String, double> prices})
    : symbol = normalizeSymbol(symbol),
      prices = Map.unmodifiable({
        for (final entry in prices.entries)
          if (entry.value.isFinite) normalizeSymbol(entry.key): entry.value,
      });

  final String symbol;
  final Map<String, double> prices;

  double? priceIn(String currency) => prices[normalizeSymbol(currency)];

  factory CoinPrice.fromJson(Object? value, {required String symbol}) {
    final json = jsonObject(value);
    final prices = <String, double>{};
    for (final entry in json.entries) {
      final price = jsonDouble(entry.value);
      if (price != null) prices[normalizeSymbol(entry.key)] = price;
    }
    return CoinPrice(symbol: symbol, prices: prices);
  }
}
