/// Readers for API fields that may be absent or contain invalid values.
Map<String, Object?> jsonObject(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String? jsonString(Object? value) {
  if (value is! String && value is! num) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? jsonText(Object? value) => value is String ? jsonString(value) : null;

bool isValidCryptoSymbol(String value) {
  final symbol = normalizeSymbol(value);
  return symbol.isNotEmpty &&
      symbol.length <= 30 &&
      !RegExp(r'[,\s\x00-\x1f\x7f]').hasMatch(symbol);
}

String? jsonSymbol(Object? value) {
  final symbol = jsonText(value);
  return symbol != null && isValidCryptoSymbol(symbol)
      ? normalizeSymbol(symbol)
      : null;
}

double? jsonDouble(Object? value) {
  final number = switch (value) {
    num value => value.toDouble(),
    String value => double.tryParse(value.trim()),
    _ => null,
  };
  return number != null && number.isFinite ? number : null;
}

/// CryptoCompare timestamps use seconds since the Unix epoch.
DateTime? jsonTime(Object? value) {
  if (value is DateTime) return value.toUtc();
  final seconds = jsonDouble(value);
  if (seconds != null) {
    final milliseconds = seconds * 1000;
    if (!milliseconds.isFinite || milliseconds.abs() > 8640000000000000) {
      return null;
    }
    try {
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds.round(),
        isUtc: true,
      );
    } on ArgumentError {
      return null;
    }
  }
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  return null;
}

String? cryptoCompareImageUrl(Object? value) {
  final text = jsonText(value);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  final absolute = uri.hasScheme
      ? uri
      : Uri.parse('https://www.cryptocompare.com').resolveUri(uri);
  if ((absolute.scheme != 'https' && absolute.scheme != 'http') ||
      absolute.host.isEmpty) {
    return null;
  }
  return absolute.toString();
}

String normalizeSymbol(String value) => value.trim().toUpperCase();
