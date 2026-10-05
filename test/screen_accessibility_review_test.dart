import 'dart:convert';

import 'package:cryptohub/main.dart';
import 'package:cryptohub/providers/app_controller.dart';
import 'package:cryptohub/screens/coin_detail_screen.dart';
import 'package:cryptohub/screens/favorites_screen.dart';
import 'package:cryptohub/screens/market_screen.dart';
import 'package:cryptohub/screens/news_screen.dart';
import 'package:cryptohub/screens/portfolio_screen.dart';
import 'package:cryptohub/services/crypto_api_service.dart';
import 'package:cryptohub/services/local_storage_service.dart';
import 'package:cryptohub/utils/formatters.dart' as format;
import 'package:cryptohub/widgets/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prices = <String, double>{
  'BTC': 100000,
  'ETH': 10000,
  'SOL': 500,
  'BNB': 2000,
  'XRP': 10,
  'ADA': 5,
  'DOGE': 1,
  'AVAX': 200,
};
const _headline = 'Bitcoin e Ethereum: mudanças no mercado de criptomoedas';

Future<http.Response> _response(http.Request request) async {
  final uri = request.url;
  Object payload;
  if (uri.path.endsWith('/pricemultifull')) {
    payload = {
      'RAW': {
        for (final symbol in uri.queryParameters['fsyms']!.split(','))
          symbol: {
            'BRL': {
              'FROMSYMBOL': symbol,
              'TOSYMBOL': 'BRL',
              'PRICE': _prices[symbol],
              'CHANGEPCT24HOUR': symbol == 'ETH' ? -1.25 : 2.5,
              'OPEN24HOUR': _prices[symbol]! * .95,
              'HIGH24HOUR': _prices[symbol]! * 1.1,
              'LOW24HOUR': _prices[symbol]! * .9,
              'VOLUME24HOUR': 12.123456,
              'VOLUME24HOURTO': 2000000,
              'MKTCAP': 3500000000,
              'SUPPLY': 1000000,
              'LASTMARKET': 'Uma exchange com nome comprido',
              'LASTUPDATE': 1791061200,
            },
          },
      },
    };
  } else if (uri.path.contains('/histo')) {
    final symbol = uri.queryParameters['fsym']!;
    payload = {
      'Data': {
        'Data': [
          for (var index = 0; index < 3; index++)
            {
              'time': 1790888400 + index * 86400,
              'close': _prices[symbol]! * (.9 + index * .05),
            },
        ],
      },
    };
  } else if (uri.path.endsWith('/pricemulti')) {
    payload = {
      for (final symbol in uri.queryParameters['fsyms']!.split(','))
        symbol: {'BRL': _prices[symbol]},
    };
  } else if (uri.path.contains('/news')) {
    payload = {
      'Data': [
        {
          'title': _headline,
          'body':
              'Preço, volume e atividade das redes ajudam a acompanhar o mercado. Esta notícia possui uma descrição longa para verificar a leitura com texto ampliado.',
          'source_info': {'name': 'Portal de tecnologia e economia'},
          'published_on': 1791061200,
          'url': 'https://example.test/noticia-1',
        },
        {
          'title': 'Solana: atividade da rede e os últimos movimentos',
          'body': 'Informações sobre a rede e seu mercado.',
          'source_info': {'name': 'Fonte de notícias'},
          'published_on': 1790974800,
          'url': 'https://example.test/noticia-2',
        },
      ],
    };
  } else if (uri.path.endsWith('/all/coinlist')) {
    payload = {
      'Data': {
        for (final symbol in _prices.keys)
          symbol: {
            'Symbol': symbol,
            'CoinName': symbol == 'BTC'
                ? 'Bitcoin'
                : symbol == 'ETH'
                ? 'Ethereum'
                : symbol == 'SOL'
                ? 'Solana'
                : symbol,
          },
      },
    };
  } else {
    throw StateError('Unexpected request: $uri');
  }
  return http.Response(
    jsonEncode(payload),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Future<void> _tab(WidgetTester tester, String label) async {
  final destination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
  await tester.tap(destination);
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: '$label must lay out at 320 px with text scale 2',
  );
}

Future<void> _sweep(WidgetTester tester, Finder screen) async {
  final scrollable = find
      .descendant(of: screen, matching: find.byType(Scrollable))
      .first;
  final footer = find.descendant(of: screen, matching: find.byType(DataFooter));
  await tester.scrollUntilVisible(
    footer,
    250,
    scrollable: scrollable,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'The complete scrollable screen must lay out without overflow',
  );
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _reveal(WidgetTester tester, Finder target, Finder scope) async {
  await tester.pumpAndSettle();
  final scrollable = find
      .descendant(of: scope, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: scrollable,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'all populated screens and the quantity form work at 320 px with double-sized text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final api = CryptoApiService(client: MockClient(_response));
      final controller = AppController(
        api: api,
        storage: LocalStorageService(preferences: preferences),
      );
      addTearDown(() {
        controller.dispose();
        api.dispose();
      });
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await controller.initialize();
      expect(
        await controller.upsertPosition(controller.coinFor('BTC'), .25),
        isTrue,
      );
      expect(
        await controller.upsertPosition(controller.coinFor('SOL'), 5),
        isTrue,
      );
      expect(await controller.toggleFavorite('BTC'), isTrue);
      expect(await controller.toggleFavorite('ETH'), isTrue);
      await tester.pumpWidget(
        CryptoHubApp(controller: controller, initialize: false),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _sweep(tester, find.byType(MarketScreen));

      await _tab(tester, 'Carteira');
      expect(controller.portfolioTotal, 27500);
      expect(find.text(format.brl(27500)), findsOneWidget);
      await _sweep(tester, find.byType(PortfolioScreen));

      await _tab(tester, 'Notícias');
      expect(controller.news.length, 2);
      expect(find.text(_headline), findsOneWidget);
      await _sweep(tester, find.byType(NewsScreen));

      await _tab(tester, 'Favoritos');
      expect(controller.favorites, containsAll(['BTC', 'ETH']));
      expect(
        find.descendant(
          of: find.byType(FavoritesScreen),
          matching: find.byType(QuoteTile),
        ),
        findsAtLeastNWidgets(1),
      );
      await _sweep(tester, find.byType(FavoritesScreen));
      final eth = find.byWidgetPredicate(
        (widget) => widget is QuoteTile && widget.coin.symbol == 'ETH',
      );
      await _reveal(tester, eth, find.byType(FavoritesScreen));
      await tester.tap(
        find.descendant(of: eth, matching: find.text('Ethereum')),
      );
      await tester.pumpAndSettle();
      final detail = find.byType(CoinDetailScreen);
      expect(tester.widget<CoinDetailScreen>(detail).coin.symbol, 'ETH');
      expect(tester.takeException(), isNull);
      await _sweep(tester, detail);

      final add = find.descendant(
        of: detail,
        matching: find.text('Adicionar à carteira'),
      );
      await _reveal(tester, add, detail);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(tester.takeException(), isNull);
      final quantity = find.byKey(const ValueKey('portfolio-quantity'));
      await _reveal(tester, quantity, sheet);
      await tester.enterText(quantity, '0');
      final save = find.text('Salvar posição');
      await _reveal(tester, save, sheet);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text('Informe uma quantidade maior que zero. Exemplo: 0,025'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await _reveal(tester, quantity, sheet);
      await tester.enterText(quantity, '0,25');
      await _reveal(tester, save, sheet);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        controller.positions
            .singleWhere((position) => position.symbol == 'ETH')
            .quantity,
        .25,
      );
      expect(controller.portfolioTotal, 30000);
      expect(tester.takeException(), isNull);
      final saved = await LocalStorageService(preferences: preferences).read();
      expect(
        saved.positions
            .singleWhere((position) => position.symbol == 'ETH')
            .quantity,
        .25,
      );
    },
  );
}
