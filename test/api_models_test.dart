import 'dart:convert';

import 'package:cryptohub/models/coin_info.dart';
import 'package:cryptohub/models/coin_price.dart';
import 'package:cryptohub/models/coin_quote.dart';
import 'package:cryptohub/models/news_article.dart';
import 'package:cryptohub/models/price_history.dart';
import 'package:cryptohub/services/crypto_api_service.dart';
import 'package:cryptohub/utils/json_readers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object? body, [int statusCode = 200]) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('API models', () {
    test(
      'Portuguese news decodes apostrophes and decimal or hex Unicode entities',
      () {
        final published = DateTime.utc(2021, 5, 19, 12);
        final article = NewsArticle.fromJson({
          'title': 'Bitcoin sofre &apos;crash&apos; &amp; Ethereum cai',
          'body':
              'O &apos;crash&apos; atingiu o mercado: &#39;Bitcoin&#x27;, '
              'cota&#231;&#227;o, &#x2014; e &#128640;. São Paulo mantém informação fiel.',
          'source_info': {'name': 'Fonte &amp; Mercado'},
          'published_on': published.millisecondsSinceEpoch ~/ 1000,
        });
        expect(article.title, "Bitcoin sofre 'crash' & Ethereum cai");
        expect(
          article.body,
          "O 'crash' atingiu o mercado: 'Bitcoin', "
          'cotação, — e 🚀. São Paulo mantém informação fiel.',
        );
        expect(article.source, 'Fonte & Mercado');
        expect(article.publishedOn, published);
      },
    );

    test(
      'invalid Unicode and unknown news entities are preserved without exceptions',
      () {
        const body =
            'Inválidas: &#0; &#xD800; &#1114112; &unknown;. '
            'Unicode válido: &#x1F680;.';
        final article = NewsArticle.fromJson({'body': body});
        expect(
          article.body,
          'Inválidas: &#0; &#xD800; &#1114112; &unknown;. '
          'Unicode válido: 🚀.',
        );
      },
    );

    test(
      'symbols support catalogue punctuation and reject separators or controls',
      () {
        for (final symbol in ['BTC', ' BTT* ', r'$PAC', 'A+B']) {
          expect(isValidCryptoSymbol(symbol), isTrue, reason: symbol);
        }
        for (final symbol in [
          '',
          '  ',
          'BTC,ETH',
          'BTC ETH',
          'BTC\tETH',
          'BTC\u0000',
          'BTC\u007f',
          List.filled(31, 'A').join(),
        ]) {
          expect(isValidCryptoSymbol(symbol), isFalse, reason: symbol);
        }
        expect(jsonSymbol(123), isNull);
        expect(jsonSymbol(' btt* '), 'BTT*');
      },
    );

    test('invalid metadata does not become invented names or image paths', () {
      final coin = CoinInfo.fromJson({
        'Symbol': '',
        'Name': r'$PAC',
        'CoinName': 123,
        'Algorithm': false,
        'ImageUrl': 42,
      });
      expect(coin.symbol, r'$PAC');
      expect(coin.name, r'$PAC');
      expect(coin.algorithm, isNull);
      expect(coin.imageUrl, isNull);
      expect(
        CoinInfo.fromJson({'Symbol': false, 'Name': 'BTT*'}).symbol,
        'BTT*',
      );
      final quote = CoinQuote.fromJson(
        {'FROMSYMBOL': '', 'TOSYMBOL': false, 'LASTMARKET': 123},
        fromSymbol: 'btc',
        toSymbol: 'brl',
      );
      expect(quote.fromSymbol, 'BTC');
      expect(quote.toSymbol, 'BRL');
      expect(quote.lastMarket, isNull);
      final news = NewsArticle.fromJson({
        'title': 123,
        'body': false,
        'url': 456,
        'source_info': {'name': ''},
        'source': 'Publisher',
        'categories': [123, false, 'BTC'],
        'imageurl': 12,
      });
      expect(news.title, '');
      expect(news.body, '');
      expect(news.url, '');
      expect(news.source, 'Publisher');
      expect(news.categories, ['BTC']);
      expect(news.imageUrl, isNull);
    });

    test('numeric readers preserve missing and invalid values', () {
      expect(jsonDouble(42), 42);
      expect(jsonDouble(' 42.5 '), 42.5);
      expect(jsonDouble('1e2'), 100);
      for (final value in [null, false, '', 'NaN', 'Infinity', [], {}]) {
        expect(jsonDouble(value), isNull, reason: '$value');
      }
      expect(jsonDouble(double.infinity), isNull);
      expect(jsonDouble(double.nan), isNull);
      expect(jsonDouble(0), 0);
      expect(jsonTime('invalid'), isNull);
      expect(jsonTime(double.infinity), isNull);
      expect(jsonTime('1e100'), isNull);
      expect(jsonTime(0), DateTime.utc(1970));
    });

    test('coin information uses the symbol when the name is unavailable', () {
      final coin = CoinInfo.fromJson({
        'Id': 1182,
        'Symbol': 'btc',
        'CoinName': null,
        'Algorithm': 'SHA-256',
        'ImageUrl': '/media/37746251/btc.png',
      });
      expect(coin.symbol, 'BTC');
      expect(coin.id, '1182');
      expect(coin.name, 'BTC');
      expect(coin.coinName, 'BTC');
      expect(coin.algorithm, 'SHA-256');
      expect(
        coin.imageUrl,
        'https://www.cryptocompare.com/media/37746251/btc.png',
      );
      expect(CoinInfo.fromJson(null, symbol: 'eth').name, 'ETH');
      expect(
        CoinInfo(symbol: 'BTC', imageUrl: 'javascript:alert(1)').imageUrl,
        isNull,
      );
      expect(CoinInfo.fromJson(coin.toJson()).imageUrl, coin.imageUrl);
    });

    test('prices accept finite strings and omit invalid currencies', () {
      final price = CoinPrice.fromJson({
        'BRL': '320000.45',
        'USD': 60000,
        'EUR': null,
        'JPY': 'unavailable',
        'GBP': false,
      }, symbol: 'btc');
      expect(price.symbol, 'BTC');
      expect(price.priceIn('brl'), 320000.45);
      expect(price.priceIn('USD'), 60000);
      expect(price.priceIn('EUR'), isNull);
      expect(price.priceIn('JPY'), isNull);
      expect(price.prices.length, 2);
      expect(() => price.prices['USD'] = 10, throwsUnsupportedError);
    });

    test('quotes parse every RAW numeric field and Unix seconds', () {
      final quote = CoinQuote.fromJson({
        'FROMSYMBOL': 'btc',
        'TOSYMBOL': 'brl',
        'PRICE': '100.5',
        'OPEN24HOUR': 90,
        'HIGH24HOUR': '110',
        'LOW24HOUR': '80',
        'CHANGE24HOUR': '10.5',
        'CHANGEPCT24HOUR': '11.67',
        'VOLUME24HOUR': '123',
        'VOLUME24HOURTO': 12345,
        'MKTCAP': '500000',
        'SUPPLY': 21000000,
        'LASTUPDATE': '1700000000',
        'LASTMARKET': 'CCCAGG',
      });
      expect(quote.fromSymbol, 'BTC');
      expect(quote.toSymbol, 'BRL');
      expect(quote.price, 100.5);
      expect(quote.open24h, 90);
      expect(quote.high24h, 110);
      expect(quote.low24h, 80);
      expect(quote.change24h, 10.5);
      expect(quote.changePct24h, 11.67);
      expect(quote.volume24h, 123);
      expect(quote.volume24hTo, 12345);
      expect(quote.marketCap, 500000);
      expect(quote.supply, 21000000);
      expect(
        quote.lastUpdate,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
      expect(quote.lastMarket, 'CCCAGG');
      final cached = CoinQuote.fromJson(jsonDecode(jsonEncode(quote.toJson())));
      expect(cached.toJson(), quote.toJson());
    });

    test('partial quotes and their cache never invent zero prices', () {
      final quote = CoinQuote.fromJson(
        {
          'PRICE': null,
          'CHANGEPCT24HOUR': 'NaN',
          'VOLUME24HOUR': false,
          'LASTUPDATE': 'bad',
        },
        fromSymbol: 'btc',
        toSymbol: 'brl',
      );
      expect(quote.fromSymbol, 'BTC');
      expect(quote.toSymbol, 'BRL');
      expect(quote.price, isNull);
      expect(quote.open24h, isNull);
      expect(quote.changePct24h, isNull);
      expect(quote.volume24h, isNull);
      expect(quote.lastUpdate, isNull);
      expect(CoinQuote.fromJson(quote.toJson()).price, isNull);
      expect(CoinQuote.fromJson({'price': '0'}).price, 0);
    });

    test('history parses nested Data and skips records without valid time', () {
      final history = PriceHistory.fromJson({
        'Data': {
          'Data': [
            {'time': 1700000060, 'close': '12.5', 'high': 13},
            {'time': null, 'close': 999},
            {'time': 'bad', 'close': 999},
            {'time': '1e100', 'close': 999},
            {
              'time': '1700000000',
              'open': '10',
              'close': null,
              'low': '9',
              'volumefrom': '100',
              'volumeto': '1000',
            },
          ],
        },
      });
      expect(history.points.length, 2);
      expect(
        history.points.first.time,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
      expect(history.points.first.open, 10);
      expect(history.points.first.close, isNull);
      expect(history.points.first.low, 9);
      expect(history.points.first.volumeFrom, 100);
      expect(history.points.first.volumeTo, 1000);
      expect(history.points.last.close, 12.5);
      expect(history.points.last.high, 13);
      expect(PriceHistory.fromJson({'Data': null}).points, isEmpty);
    });

    test(
      'news parses Portuguese content, categories and publication seconds',
      () {
        final article = NewsArticle.fromJson({
          'title': 'Cotação do Bitcoin',
          'body': 'Notícia em português.',
          'source': 'publisher',
          'source_info': {'name': 'Fonte da notícia'},
          'url': 'https://publisher.example/article',
          'imageurl': '/media/news.jpg',
          'published_on': 1700000000,
          'categories': 'BTC| Market |BTC||',
        });
        expect(article.title, 'Cotação do Bitcoin');
        expect(article.body, 'Notícia em português.');
        expect(article.source, 'Fonte da notícia');
        expect(article.url, 'https://publisher.example/article');
        expect(
          article.imageUrl,
          'https://www.cryptocompare.com/media/news.jpg',
        );
        expect(article.categories, ['BTC', 'Market']);
        expect(
          article.publishedOn,
          DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
        );
        final unavailable = NewsArticle.fromJson(null);
        expect(unavailable.title, '');
        expect(unavailable.imageUrl, isNull);
        expect(unavailable.publishedOn, isNull);
        expect(unavailable.categories, isEmpty);
      },
    );
  });

  group('CryptoApiService', () {
    test(
      'web authentication uses an API query key without an Authorization header',
      () async {
        final service = CryptoApiService(
          apiKey: ' query-test-key ',
          useQueryAuthentication: true,
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.scheme, 'https');
            expect(request.url.host, 'min-api.cryptocompare.com');
            expect(request.url.path, '/data/pricemultifull');
            expect(request.url.queryParameters, {
              'fsyms': 'BTC',
              'tsyms': 'BRL',
              'api_key': 'query-test-key',
            });
            expect(request.headers.containsKey('Authorization'), isFalse);
            expect(request.headers['Accept'], 'application/json');
            return jsonResponse({
              'RAW': {
                'BTC': {
                  'BRL': {'PRICE': 100},
                },
              },
            });
          }),
        );
        addTearDown(service.dispose);
        expect((await service.getCoinDetails('BTC')).price, 100);
      },
    );

    test(
      'web query authentication follows session key changes and clears the key',
      () async {
        final requests = <http.Request>[];
        final service = CryptoApiService(
          apiKey: '',
          useQueryAuthentication: true,
          client: MockClient((request) async {
            requests.add(request);
            expect(request.headers.containsKey('Authorization'), isFalse);
            return jsonResponse({'Data': []});
          }),
        );
        addTearDown(service.dispose);
        await service.getNews();
        service.updateApiKey(' new-query-test-key ');
        await service.getNews();
        service.apiKey = '';
        await service.getNews();
        expect(requests.map((request) => request.url.path), [
          '/data/v2/news/',
          '/data/v2/news/',
          '/data/v2/news/',
        ]);
        expect(requests[0].url.queryParameters, {'lang': 'PT'});
        expect(requests[1].url.queryParameters, {
          'lang': 'PT',
          'api_key': 'new-query-test-key',
        });
        expect(requests[2].url.queryParameters, {'lang': 'PT'});
      },
    );

    for (final price in [0.0, -10.0]) {
      test(
        'coin details reject price $price while bulk parsing stays faithful',
        () async {
          final service = CryptoApiService(
            client: MockClient((request) async {
              expect(request.url.path, '/data/pricemultifull');
              expect(request.url.queryParameters, {
                'fsyms': 'BTC',
                'tsyms': 'BRL',
              });
              return jsonResponse({
                'RAW': {
                  'BTC': {
                    'BRL': {'PRICE': price, 'SUPPLY': 21000000},
                  },
                },
              });
            }),
          );
          addTearDown(service.dispose);
          final rawQuotes = await service.getQuotes(['BTC']);
          expect(rawQuotes['BTC']?.price, price);
          await expectLater(
            service.getCoinDetails('BTC'),
            throwsA(
              isA<ApiException>()
                  .having(
                    (error) => error.message,
                    'message',
                    contains('cotação disponível'),
                  )
                  .having((error) => error.isOffline, 'isOffline', isFalse)
                  .having((error) => error.needsApiKey, 'needsApiKey', isFalse),
            ),
          );
        },
      );
    }

    test(
      'coin details preserve metadata when the current price is unavailable',
      () async {
        final service = CryptoApiService(
          client: MockClient(
            (_) async => jsonResponse({
              'RAW': {
                'BTC': {
                  'BRL': {
                    'PRICE': null,
                    'SUPPLY': '21000000',
                    'MKTCAP': '250000000000',
                    'LASTMARKET': 'CCCAGG',
                    'LASTUPDATE': 1700000000,
                  },
                },
              },
            }),
          ),
        );
        addTearDown(service.dispose);
        final details = await service.getCoinDetails('BTC');
        expect(details.price, isNull);
        expect(details.fromSymbol, 'BTC');
        expect(details.toSymbol, 'BRL');
        expect(details.supply, 21000000);
        expect(details.marketCap, 250000000000);
        expect(details.lastMarket, 'CCCAGG');
        expect(
          details.lastUpdate,
          DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
        );
      },
    );

    test(
      'catalogue symbols remain usable in requests and currency conversion',
      () async {
        final service = CryptoApiService(
          client: MockClient((request) async {
            expect(request.url.queryParameters, {
              'fsyms': r'BTT*,$PAC',
              'tsyms': r'$PAC',
            });
            return jsonResponse({
              'BTT*': {r'$PAC': 12},
              r'$PAC': {r'$PAC': 1},
            });
          }),
        );
        addTearDown(service.dispose);
        final prices = await service.getPrices([
          'btt*',
          r'$pac',
        ], currency: r'$pac');
        expect(prices['BTT*']?.priceIn(r'$PAC'), 12);
        expect(prices[r'$PAC']?.priceIn(r'$PAC'), 1);
      },
    );

    test('control characters and list separators fail before HTTP', () async {
      final service = CryptoApiService(
        client: MockClient((_) async {
          fail('Invalid symbols must not be sent to the API.');
        }),
      );
      addTearDown(service.dispose);
      for (final symbol in ['BTC,ETH', 'BTC ETH', 'BTC\u0000', 'BTC\u007f']) {
        await expectLater(
          service.getQuotes([symbol]),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          service.getDailyHistory('BTC', currency: symbol),
          throwsA(isA<ApiException>()),
        );
      }
    });

    test(
      'a quote with the wrong source or currency is never attached to a holding',
      () async {
        final service = CryptoApiService(
          client: MockClient(
            (_) async => jsonResponse({
              'RAW': {
                'BTC': {
                  'BRL': {'FROMSYMBOL': 'ETH', 'TOSYMBOL': 'BRL', 'PRICE': 10},
                },
                'ETH': {
                  'BRL': {'FROMSYMBOL': 'ETH', 'TOSYMBOL': 'USD', 'PRICE': 20},
                },
                'SOL': {
                  'BRL': {'FROMSYMBOL': 'SOL', 'TOSYMBOL': 'BRL', 'PRICE': 30},
                },
              },
            }),
          ),
        );
        addTearDown(service.dispose);
        final quotes = await service.getQuotes(['BTC', 'ETH', 'SOL']);
        expect(quotes.keys, ['SOL']);
        expect(quotes['SOL']?.price, 30);
        await expectLater(
          service.getCoinDetails('BTC'),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test(
      'catalogue excludes malformed symbols while preserving supported ones',
      () async {
        final service = CryptoApiService(
          client: MockClient(
            (_) async => jsonResponse({
              'Data': {
                'BTT*': {'Symbol': '', 'Name': 'BTT*'},
                r'$PAC': {'Symbol': r'$PAC'},
                'BAD,COIN': {'Symbol': 'BAD,COIN'},
                'BAD\u0000': {'Symbol': 'BAD\u0000'},
              },
            }),
          ),
        );
        addTearDown(service.dispose);
        expect((await service.getCoinList()).keys, ['BTT*', r'$PAC']);
      },
    );

    test(
      'malformed collection envelopes are errors instead of successful empty data',
      () async {
        final service = CryptoApiService(
          client: MockClient((request) async {
            return jsonResponse({
              'Response': 'Success',
              'Data': request.url.path == '/data/v2/histoday'
                  ? {'Data': null}
                  : 'invalid',
            });
          }),
        );
        addTearDown(service.dispose);
        await expectLater(service.getNews(), throwsA(isA<ApiException>()));
        await expectLater(service.getCoinList(), throwsA(isA<ApiException>()));
        await expectLater(
          service.getDailyHistory('BTC'),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test('valid empty collections are still legitimate successes', () async {
      final service = CryptoApiService(
        client: MockClient((request) async {
          if (request.url.path == '/data/all/coinlist') {
            return jsonResponse({'Data': {}});
          }
          if (request.url.path == '/data/v2/news/') {
            return jsonResponse({'Data': []});
          }
          return jsonResponse({
            'Data': {'Data': []},
          });
        }),
      );
      addTearDown(service.dispose);
      expect(await service.getCoinList(), isEmpty);
      expect(await service.getNews(), isEmpty);
      expect((await service.getDailyHistory('BTC')).points, isEmpty);
    });

    for (final status in [200, 429]) {
      test(
        'quota error $status mentioning API keys does not ask for a new key',
        () async {
          final service = CryptoApiService(
            client: MockClient(
              (_) async => jsonResponse({
                'Response': 'Error',
                'Message': 'Your API key is over its rate limit',
              }, status),
            ),
          );
          addTearDown(service.dispose);
          await expectLater(
            service.getNews(),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.needsApiKey, 'needsApiKey', isFalse)
                  .having((e) => e.message, 'message', contains('limite')),
            ),
          );
        },
      );
    }

    test('server failures mentioning a key remain server failures', () async {
      final service = CryptoApiService(
        client: MockClient(
          (_) async => jsonResponse({
            'Response': 'Error',
            'Message': 'Could not validate the API key: backend unavailable',
          }, 503),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.getNews(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.needsApiKey, 'needsApiKey', isFalse)
              .having((e) => e.message, 'message', contains('indisponível')),
        ),
      );
    });

    test(
      'prices use HTTPS, BRL and Authorization without a query key',
      () async {
        final service = CryptoApiService(
          apiKey: ' secret-token ',
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.scheme, 'https');
            expect(request.url.host, 'min-api.cryptocompare.com');
            expect(request.url.path, '/data/pricemulti');
            expect(request.url.queryParameters, {
              'fsyms': 'BTC,ETH',
              'tsyms': 'BRL',
            });
            expect(request.headers['Authorization'], 'Apikey secret-token');
            expect(request.url.toString(), isNot(contains('secret-token')));
            return jsonResponse({
              'BTC': {'BRL': '320000.45'},
              'ETH': {'BRL': null},
            });
          }),
        );
        addTearDown(service.dispose);
        final prices = await service.getPrices([' btc ', 'ETH', 'BTC']);
        expect(prices['BTC']?.priceIn('BRL'), 320000.45);
        expect(prices['ETH']?.priceIn('BRL'), isNull);
        expect(service.hasApiKey, isTrue);
      },
    );

    test('empty symbol sets do not make requests', () async {
      final service = CryptoApiService(
        client: MockClient((_) async {
          fail('An empty list must not send a request.');
        }),
      );
      addTearDown(service.dispose);
      expect(await service.getPrices([]), isEmpty);
      expect(await service.getQuotes([' ']), isEmpty);
    });

    test('large sets are chunked and every symbol is requested once', () async {
      final requested = <String>[];
      var calls = 0;
      final service = CryptoApiService(
        client: MockClient((request) async {
          calls++;
          final fsyms = request.url.queryParameters['fsyms']!;
          expect(fsyms.length, lessThanOrEqualTo(280));
          final symbols = fsyms.split(',');
          expect(symbols.length, lessThanOrEqualTo(40));
          requested.addAll(symbols);
          return jsonResponse({
            for (final symbol in symbols) symbol: {'BRL': 1},
          });
        }),
      );
      addTearDown(service.dispose);
      final symbols = List.generate(123, (index) => 'COIN$index');
      final result = await service.getPrices(symbols);
      expect(calls, greaterThan(1));
      expect(requested, symbols);
      expect(result.length, symbols.length);
    });

    test('quotes parse RAW and preserve missing prices', () async {
      final service = CryptoApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/data/pricemultifull');
          expect(request.url.queryParameters['tsyms'], 'USD');
          return jsonResponse({
            'RAW': {
              'BTC': {
                'USD': {'PRICE': '60000.5', 'CHANGEPCT24HOUR': null},
              },
              'ETH': {
                'USD': {'PRICE': null, 'MKTCAP': '250000000000'},
              },
            },
          });
        }),
      );
      addTearDown(service.dispose);
      final quotes = await service.getQuotes([
        'BTC',
        'ETH',
        'UNKNOWN',
      ], currency: 'usd');
      expect(quotes['BTC']?.price, 60000.5);
      expect(quotes['BTC']?.fromSymbol, 'BTC');
      expect(quotes['BTC']?.toSymbol, 'USD');
      expect(quotes['BTC']?.changePct24h, isNull);
      expect(quotes['ETH']?.price, isNull);
      expect(quotes.containsKey('UNKNOWN'), isFalse);
      expect(
        (await service.getCoinDetails('BTC', currency: 'USD')).price,
        60000.5,
      );
      await expectLater(
        service.getCoinDetails('UNKNOWN', currency: 'USD'),
        throwsA(isA<ApiException>()),
      );
    });

    test('null RAW does not crash or fabricate quotes', () async {
      final service = CryptoApiService(
        client: MockClient(
          (_) async => jsonResponse({'RAW': null, 'DISPLAY': null}),
        ),
      );
      addTearDown(service.dispose);
      expect(await service.getQuotes(['BTC']), isEmpty);
    });

    test(
      'coin list is fetched without requesting prices for its catalogue',
      () async {
        var calls = 0;
        final service = CryptoApiService(
          client: MockClient((request) async {
            calls++;
            expect(request.url.path, '/data/all/coinlist');
            return jsonResponse({
              'Response': 'Success',
              'Data': {
                'BTC': {'CoinName': 'Bitcoin', 'ImageUrl': '/media/btc.png'},
                'ETH': {'CoinName': null},
                'BAD': null,
              },
            });
          }),
        );
        addTearDown(service.dispose);
        final coins = await service.getCoinList();
        expect(calls, 1);
        expect(coins.keys, ['BTC', 'ETH']);
        expect(coins['BTC']?.coinName, 'Bitcoin');
        expect(coins['ETH']?.name, 'ETH');
      },
    );

    test(
      'daily, hourly and minute histories use their specified endpoints',
      () async {
        final paths = <String>[];
        final service = CryptoApiService(
          client: MockClient((request) async {
            paths.add(request.url.path);
            expect(request.url.queryParameters, {
              'fsym': 'BTC',
              'tsym': 'BRL',
              'limit': '60',
            });
            return jsonResponse({
              'Response': 'Success',
              'Data': {
                'Data': [
                  {'time': 1700000000, 'close': '50.5'},
                ],
              },
            });
          }),
        );
        addTearDown(service.dispose);
        final histories = [
          await service.getDailyHistory('btc', limit: 60),
          await service.getHourlyHistory('btc', limit: 60),
          await service.getMinuteHistory('btc', limit: 60),
        ];
        expect(paths, [
          '/data/v2/histoday',
          '/data/v2/histohour',
          '/data/v2/histominute',
        ]);
        for (final history in histories) {
          expect(history.points.single.close, 50.5);
          expect(history.points.single.time.year, 2023);
        }
      },
    );

    test(
      'news requests PT and handles nullable fields and malformed entries',
      () async {
        final service = CryptoApiService(
          client: MockClient((request) async {
            expect(request.url.path, '/data/v2/news/');
            expect(request.url.queryParameters, {'lang': 'PT'});
            return jsonResponse({
              'Data': [
                {
                  'title': 'Notícia',
                  'body': null,
                  'published_on': 1700000000,
                  'categories': ['BTC', 'ETH'],
                },
                null,
              ],
            });
          }),
        );
        addTearDown(service.dispose);
        final news = await service.getNews();
        expect(news.length, 1);
        expect(news.single.title, 'Notícia');
        expect(news.single.body, '');
        expect(news.single.categories, ['BTC', 'ETH']);
        expect(news.single.publishedOn?.year, 2023);
      },
    );

    test('HTTP 200 semantic errors become ApiException', () async {
      final service = CryptoApiService(
        client: MockClient(
          (_) async =>
              jsonResponse({'Response': 'Error', 'Message': 'Invalid fsym'}),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.getPrices(['BTC']),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 200)),
      );
    });

    test(
      'semantic authentication errors request configuration without keys',
      () async {
        final service = CryptoApiService(
          apiKey: 'private-token',
          client: MockClient(
            (_) async => jsonResponse({
              'Response': 'Error',
              'Message': 'Invalid API key private-token',
            }),
          ),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.getNews(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.needsApiKey, 'needsApiKey', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('private-token')),
                ),
          ),
        );
      },
    );

    for (final status in [401, 403]) {
      test(
        'HTTP $status requires an API key even with a non-JSON body',
        () async {
          final service = CryptoApiService(
            client: MockClient(
              (_) async => http.Response('Access denied', status),
            ),
          );
          addTearDown(service.dispose);
          await expectLater(
            service.getCoinList(),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.needsApiKey, 'needsApiKey', isTrue)
                  .having((e) => e.statusCode, 'status', status),
            ),
          );
        },
      );
    }

    for (final status in [429, 500]) {
      test('HTTP $status provides a usable Portuguese error', () async {
        final service = CryptoApiService(
          client: MockClient(
            (_) async => jsonResponse({'Response': 'Error'}, status),
          ),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.getNews(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.isOffline, 'isOffline', isFalse)
                .having(
                  (e) => e.message.toLowerCase(),
                  'message',
                  contains('tente'),
                ),
          ),
        );
      });
    }

    for (final body in ['not json', 'null', '[]', 'true']) {
      test('invalid successful response $body is rejected', () async {
        final service = CryptoApiService(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        addTearDown(service.dispose);
        await expectLater(service.getCoinList(), throwsA(isA<ApiException>()));
      });
    }

    test('client connection errors are classified as offline', () async {
      final service = CryptoApiService(
        client: MockClient((_) async {
          throw http.ClientException('Network failed');
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.getCoinList(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isOffline, 'isOffline', isTrue)
              .having((e) => e.message, 'message', contains('conexão')),
        ),
      );
    });

    test('a request that times out returns an offline error', () async {
      final service = CryptoApiService(
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonResponse({'Data': {}});
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.getCoinList(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isOffline, 'isOffline', isTrue)
              .having((e) => e.message, 'message', contains('demorou')),
        ),
      );
    });

    test(
      'the API key can be configured and cleared during the session',
      () async {
        final headers = <String?>[];
        final service = CryptoApiService(
          apiKey: '',
          client: MockClient((request) async {
            headers.add(request.headers['Authorization']);
            return jsonResponse({'Data': []});
          }),
        );
        addTearDown(service.dispose);
        expect(service.hasApiKey, isFalse);
        await service.getNews();
        service.updateApiKey(' new-key ');
        expect(service.hasApiKey, isTrue);
        await service.getNews();
        service.apiKey = '';
        await service.getNews();
        expect(headers, [null, 'Apikey new-key', null]);
      },
    );

    test('invalid history limits fail without sending a request', () async {
      final service = CryptoApiService(
        client: MockClient((_) async {
          fail('Invalid input must not send a request.');
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.getDailyHistory('BTC', limit: 0),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        service.getMinuteHistory('BTC', limit: 2001),
        throwsA(isA<ApiException>()),
      );
    });

    test('disposing the service prevents subsequent HTTP operations', () async {
      final service = CryptoApiService(
        client: MockClient((_) async {
          fail('Disposed service must not send a request.');
        }),
      );
      service.dispose();
      service.dispose();
      await expectLater(service.getNews(), throwsA(isA<ApiException>()));
    });
  });
}
