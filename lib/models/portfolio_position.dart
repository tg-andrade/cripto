import 'coin_info.dart';
import '../utils/json_readers.dart' show isValidCryptoSymbol;

/// A locally saved holding. Its value comes from a separate quote.
class PortfolioPosition {
  PortfolioPosition({
    required String symbol,
    required String coinName,
    required this.quantity,
    String? imageUrl,
  }) : symbol = normalizeSymbol(symbol),
       coinName = coinName.trim().isEmpty
           ? symbol.trim().toUpperCase()
           : coinName.trim(),
       imageUrl = CoinInfo(symbol: symbol, imageUrl: imageUrl).imageUrl {
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Use uma quantidade positiva e finita.',
      );
    }
  }

  final String symbol;
  final String coinName;
  final double quantity;
  final String? imageUrl;

  CoinInfo get coin =>
      CoinInfo(symbol: symbol, coinName: coinName, imageUrl: imageUrl);

  factory PortfolioPosition.fromJson(Map<String, dynamic> json) {
    final symbol = json['symbol'];
    final quantity = json['quantity'];
    if (symbol is! String || quantity is! num) {
      throw const FormatException('Posição sem símbolo ou quantidade válida.');
    }
    final coinName = json['coinName'];
    final imageUrl = json['imageUrl'];
    return PortfolioPosition(
      symbol: symbol,
      coinName: coinName is String ? coinName : symbol,
      quantity: quantity.toDouble(),
      imageUrl: imageUrl is String ? imageUrl : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'coinName': coinName,
    'quantity': quantity,
    'imageUrl': imageUrl,
  };

  static String normalizeSymbol(String value) {
    final symbol = value.trim().toUpperCase();
    if (!isValidCryptoSymbol(symbol)) {
      throw ArgumentError.value(value, 'symbol', 'Símbolo de moeda inválido.');
    }
    return symbol;
  }
}
