import '../utils/json_readers.dart';

class PriceHistoryPoint {
  const PriceHistoryPoint({
    required this.time,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volumeFrom,
    this.volumeTo,
  });

  final DateTime time;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volumeFrom;
  final double? volumeTo;

  factory PriceHistoryPoint.fromJson(Object? value) {
    final point = tryFromJson(value);
    if (point == null) {
      throw const FormatException('Registro sem horário válido.');
    }
    return point;
  }

  /// Records without a timestamp cannot become points on a chart.
  static PriceHistoryPoint? tryFromJson(Object? value) {
    final json = jsonObject(value);
    final time = jsonTime(json['time']);
    if (time == null) return null;
    return PriceHistoryPoint(
      time: time,
      open: jsonDouble(json['open']),
      high: jsonDouble(json['high']),
      low: jsonDouble(json['low']),
      close: jsonDouble(json['close']),
      volumeFrom: jsonDouble(json['volumefrom'] ?? json['volumeFrom']),
      volumeTo: jsonDouble(json['volumeto'] ?? json['volumeTo']),
    );
  }

  Map<String, Object?> toJson() => {
    'time': time.millisecondsSinceEpoch / 1000,
    'open': open,
    'high': high,
    'low': low,
    'close': close,
    'volumefrom': volumeFrom,
    'volumeto': volumeTo,
  };
}

class PriceHistory {
  PriceHistory({required List<PriceHistoryPoint> points})
    : points = List.unmodifiable(points);

  final List<PriceHistoryPoint> points;

  factory PriceHistory.fromJson(Object? value) {
    final json = jsonObject(value);
    final data = json['Data'];
    final records = data is List ? data : jsonObject(data)['Data'];
    final points = <PriceHistoryPoint>[];
    if (records is List) {
      for (final record in records) {
        final point = PriceHistoryPoint.tryFromJson(record);
        if (point != null) points.add(point);
      }
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return PriceHistory(points: points);
  }
}
