import '../utils/json_readers.dart';

class CoinInfo {
  CoinInfo({
    required String symbol,
    this.id,
    String? coinName,
    this.algorithm,
    String? imageUrl,
  }) : symbol = normalizeSymbol(symbol),
       coinName = jsonString(coinName) ?? normalizeSymbol(symbol),
       imageUrl = cryptoCompareImageUrl(imageUrl);

  final String symbol;
  final String? id;
  final String coinName;
  final String? algorithm;
  final String? imageUrl;

  String get name => coinName;

  factory CoinInfo.fromJson(Object? value, {String? symbol}) {
    final json = jsonObject(value);
    return CoinInfo(
      symbol:
          jsonSymbol(json['Symbol']) ??
          jsonSymbol(json['Name']) ??
          jsonSymbol(json['symbol']) ??
          symbol ??
          '',
      id: jsonString(json['Id'] ?? json['id']),
      coinName: jsonText(json['CoinName']) ?? jsonText(json['coinName']),
      algorithm: jsonText(json['Algorithm']) ?? jsonText(json['algorithm']),
      imageUrl: jsonText(json['ImageUrl']) ?? jsonText(json['imageUrl']),
    );
  }

  Map<String, Object?> toJson() => {
    'symbol': symbol,
    'id': id,
    'coinName': coinName,
    'algorithm': algorithm,
    'imageUrl': imageUrl,
  };
}
