import '../utils/json_readers.dart';

class NewsArticle {
  const NewsArticle({
    required this.title,
    this.body = '',
    this.source = '',
    this.url = '',
    this.imageUrl,
    this.publishedOn,
    this.categories = const [],
  });

  final String title;
  final String body;
  final String source;
  final String url;
  final String? imageUrl;
  final DateTime? publishedOn;
  final List<String> categories;

  factory NewsArticle.fromJson(Object? value) {
    final json = jsonObject(value);
    final sourceInfo = jsonObject(json['source_info']);
    final rawCategories = json['categories'];
    final categories = <String>[];
    final entries = rawCategories is List
        ? rawCategories
        : (jsonText(rawCategories)?.split('|') ?? const <String>[]);
    for (final entry in entries) {
      final category = jsonText(entry);
      if (category != null && !categories.contains(category)) {
        categories.add(category);
      }
    }
    return NewsArticle(
      title: _decodeEntities(jsonText(json['title']) ?? ''),
      body: _decodeEntities(jsonText(json['body']) ?? ''),
      source: _decodeEntities(
        jsonText(sourceInfo['name']) ?? jsonText(json['source']) ?? '',
      ),
      url: jsonText(json['url']) ?? '',
      imageUrl: cryptoCompareImageUrl(json['imageurl'] ?? json['imageUrl']),
      publishedOn: jsonTime(json['published_on'] ?? json['publishedOn']),
      categories: List.unmodifiable(categories),
    );
  }

  static String _decodeEntities(String text) {
    const named = {
      'amp': '&',
      'apos': "'",
      'quot': '"',
      'lt': '<',
      'gt': '>',
      'nbsp': '\u00a0',
      'ndash': '–',
      'mdash': '—',
      'lsquo': '‘',
      'rsquo': '’',
      'ldquo': '“',
      'rdquo': '”',
      'hellip': '…',
    };
    return text.replaceAllMapped(
      RegExp(r'&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|[a-zA-Z]+);'),
      (match) {
        final entity = match.group(1)!;
        if (!entity.startsWith('#')) return named[entity] ?? match.group(0)!;
        final hexadecimal =
            entity.length > 1 && (entity[1] == 'x' || entity[1] == 'X');
        final codePoint = int.tryParse(
          entity.substring(hexadecimal ? 2 : 1),
          radix: hexadecimal ? 16 : 10,
        );
        if (codePoint == null ||
            codePoint <= 0 ||
            codePoint > 0x10ffff ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
          return match.group(0)!;
        }
        return String.fromCharCode(codePoint);
      },
    );
  }
}
