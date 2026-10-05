import '../utils/json_readers.dart';

class CoinQuote {
  const CoinQuote({
    required this.fromSymbol,
    required this.toSymbol,
    this.price,
    this.open24h,
    this.high24h,
    this.low24h,
    this.change24h,
    this.changePct24h,
    this.volume24h,
    this.volume24hTo,
    this.marketCap,
    this.supply,
    this.lastUpdate,
    this.lastMarket,
  });

  final String fromSymbol;
  final String toSymbol;
  final double? price;
  final double? open24h;
  final double? high24h;
  final double? low24h;
  final double? change24h;
  final double? changePct24h;
  final double? volume24h;
  final double? volume24hTo;
  final double? marketCap;
  final double? supply;
  final DateTime? lastUpdate;
  final String? lastMarket;

  factory CoinQuote.fromJson(
    Object? value, {
    String? fromSymbol,
    String? toSymbol,
  }) {
    final json = jsonObject(value);
    return CoinQuote(
      fromSymbol: normalizeSymbol(
        jsonSymbol(json['FROMSYMBOL']) ??
            jsonSymbol(json['fromSymbol']) ??
            fromSymbol ??
            '',
      ),
      toSymbol: normalizeSymbol(
        jsonSymbol(json['TOSYMBOL']) ??
            jsonSymbol(json['toSymbol']) ??
            toSymbol ??
            '',
      ),
      price: jsonDouble(json['PRICE'] ?? json['price']),
      open24h: jsonDouble(json['OPEN24HOUR'] ?? json['open24h']),
      high24h: jsonDouble(json['HIGH24HOUR'] ?? json['high24h']),
      low24h: jsonDouble(json['LOW24HOUR'] ?? json['low24h']),
      change24h: jsonDouble(json['CHANGE24HOUR'] ?? json['change24h']),
      changePct24h: jsonDouble(json['CHANGEPCT24HOUR'] ?? json['changePct24h']),
      volume24h: jsonDouble(json['VOLUME24HOUR'] ?? json['volume24h']),
      volume24hTo: jsonDouble(json['VOLUME24HOURTO'] ?? json['volume24hTo']),
      marketCap: jsonDouble(json['MKTCAP'] ?? json['marketCap']),
      supply: jsonDouble(json['SUPPLY'] ?? json['supply']),
      lastUpdate: jsonTime(json['LASTUPDATE'] ?? json['lastUpdate']),
      lastMarket: jsonText(json['LASTMARKET']) ?? jsonText(json['lastMarket']),
    );
  }

  Map<String, Object?> toJson() => {
    'FROMSYMBOL': fromSymbol,
    'TOSYMBOL': toSymbol,
    'PRICE': price,
    'OPEN24HOUR': open24h,
    'HIGH24HOUR': high24h,
    'LOW24HOUR': low24h,
    'CHANGE24HOUR': change24h,
    'CHANGEPCT24HOUR': changePct24h,
    'VOLUME24HOUR': volume24h,
    'VOLUME24HOURTO': volume24hTo,
    'MKTCAP': marketCap,
    'SUPPLY': supply,
    'LASTUPDATE': lastUpdate == null
        ? null
        : lastUpdate!.millisecondsSinceEpoch / 1000,
    'LASTMARKET': lastMarket,
  };
}
