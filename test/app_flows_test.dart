import 'dart:convert';

import 'package:cryptohub/main.dart';
import 'package:cryptohub/providers/app_controller.dart';
import 'package:cryptohub/screens/coin_detail_screen.dart';
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

class _Fixture {
  _Fixture(this.preferences) {
    api = CryptoApiService(client: MockClient(_respond));
    controller = AppController(
      api: api,
      storage: LocalStorageService(preferences: preferences),
    );
  }

  final SharedPreferences preferences;
  final requests = <Uri>[];
  final unexpectedRequests = <Uri>[];
  late final CryptoApiService api;
  late final AppController controller;

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request.url);
    final path = request.url.path;
    Object payload;
    if (path.endsWith('/pricemultifull')) {
      final symbols = request.url.queryParameters['fsyms']!.split(',');
      payload = {
        'RAW': {
          for (final symbol in symbols)
            symbol: {
              'BRL': {
                'FROMSYMBOL': symbol,
                'TOSYMBOL': 'BRL',
                'PRICE': _prices[symbol],
                'OPEN24HOUR': _prices[symbol]! * .95,
                'HIGH24HOUR': _prices[symbol]! * 1.1,
                'LOW24HOUR': _prices[symbol]! * .9,
                'CHANGEPCT24HOUR': symbol == 'ETH' ? -1.2 : 2.4,
                'VOLUME24HOUR': 120,
                'VOLUME24HOURTO': 500000,
                'MKTCAP': 10000000,
                'SUPPLY': 1000,
                'LASTUPDATE': 1790802000,
                'LASTMARKET': 'Test exchange',
              },
            },
        },
      };
    } else if (path.endsWith('/pricemulti')) {
      final symbols = request.url.queryParameters['fsyms']!.split(',');
      payload = {
        for (final symbol in symbols) symbol: {'BRL': _prices[symbol]},
      };
    } else if (path.contains('/histo')) {
      final symbol = request.url.queryParameters['fsym']!;
      payload = {
        'Response': 'Success',
        'Data': {
          'Data': [
            for (var index = 0; index < 3; index++)
              {
                'time': 1790629200 + index * 86400,
                'close': _prices[symbol]! * (.9 + index * .05),
              },
          ],
        },
      };
    } else if (path.endsWith('/all/coinlist')) {
      payload = {
        'Data': {
          for (final symbol in _prices.keys)
            symbol: {
              'Symbol': symbol,
              'CoinName': switch (symbol) {
                'BTC' => 'Bitcoin',
                'ETH' => 'Ethereum',
                'SOL' => 'Solana',
                _ => symbol,
              },
            },
        },
      };
    } else if (path.contains('/news')) {
      payload = {'Data': <Object>[]};
    } else {
      unexpectedRequests.add(request.url);
      payload = {'Response': 'Error', 'Message': 'Unexpected test request'};
    }
    return http.Response(
      jsonEncode(payload),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  void dispose() {
    controller.dispose();
    api.dispose();
  }
}

Future<_Fixture> _fixture() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final fixture = _Fixture(preferences);
  addTearDown(() {
    expect(fixture.unexpectedRequests, isEmpty);
    fixture.dispose();
  });
  await fixture.controller.initialize();
  return fixture;
}

Future<void> _mount(WidgetTester tester, AppController controller) async {
  tester.view.physicalSize = const Size(360, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    CryptoHubApp(controller: controller, initialize: false),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Finder _quote(String symbol) => find.byWidgetPredicate(
  (widget) => widget is QuoteTile && widget.coin.symbol == symbol,
);

void main() {
  testWidgets('empty portfolio and favorites remain empty at 360 px', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _mount(tester, fixture.controller);

    await _tab(tester, 'Carteira');
    expect(fixture.controller.positions, isEmpty);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(format.brl(0)), findsNothing);
    expect(fixture.controller.portfolioTotal, 0);

    await _tab(tester, 'Favoritos');
    expect(fixture.controller.favorites, isEmpty);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(QuoteTile), findsNothing);
  });

  testWidgets('favoriting Bitcoin updates the tab and persists locally', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _mount(tester, fixture.controller);
    final star = find.descendant(
      of: _quote('BTC'),
      matching: find.byTooltip('Adicionar Bitcoin aos favoritos'),
    );
    await tester.ensureVisible(star);
    await tester.tap(star);
    await tester.pumpAndSettle();
    expect(fixture.controller.favorites, contains('BTC'));

    await _tab(tester, 'Favoritos');
    expect(_quote('BTC'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    final saved = await LocalStorageService(
      preferences: fixture.preferences,
    ).read();
    expect(saved.favorites, contains('BTC'));
    expect(saved.error, isNull);
  });

  testWidgets('opening Ethereum requests its own quote and history', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _mount(tester, fixture.controller);
    fixture.requests.clear();
    await tester.ensureVisible(_quote('ETH'));
    await tester.tap(
      find.descendant(of: _quote('ETH'), matching: find.text('Ethereum')),
    );
    await tester.pumpAndSettle();

    final detail = tester.widget<CoinDetailScreen>(
      find.byType(CoinDetailScreen),
    );
    expect(detail.coin.symbol, 'ETH');
    expect(find.text(format.brl(_prices['ETH'])), findsOneWidget);
    final historyRequests = fixture.requests.where(
      (uri) => uri.path.contains('/histo'),
    );
    expect(historyRequests, isNotEmpty);
    expect(
      historyRequests.every((uri) => uri.queryParameters['fsym'] == 'ETH'),
      isTrue,
    );
    expect(
      fixture.requests.any(
        (uri) =>
            uri.path.endsWith('/pricemultifull') &&
            uri.queryParameters['fsyms'] == 'ETH',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a comma decimal position survives a new controller', (
    tester,
  ) async {
    final fixture = await _fixture();
    await fixture.controller.upsertPosition(
      fixture.controller.coinFor('BTC'),
      .1,
    );
    await _mount(tester, fixture.controller);
    await _tab(tester, 'Carteira');
    expect(fixture.controller.portfolioTotal, 10000);
    expect(find.text(format.brl(10000)), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('portfolio-BTC')));
    await tester.pumpAndSettle();
    expect(find.text('Editar posição'), findsOneWidget);
    final quantity = find.byKey(const ValueKey('portfolio-quantity'));
    await tester.ensureVisible(quantity);
    await tester.enterText(quantity, '0,25');
    await tester.pump();
    final save = find.text('Salvar posição');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(fixture.controller.positions.single.quantity, .25);
    expect(fixture.controller.portfolioTotal, 25000);
    expect(find.text(format.brl(25000)), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    final restored = _Fixture(fixture.preferences);
    addTearDown(restored.dispose);
    await restored.controller.initialize();
    expect(restored.controller.positions.single.symbol, 'BTC');
    expect(restored.controller.positions.single.quantity, .25);
    expect(restored.controller.portfolioTotal, 25000);
    await _mount(tester, restored.controller);
    await _tab(tester, 'Carteira');
    expect(find.text(format.brl(25000)), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing quote keeps the portfolio total unavailable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = CryptoApiService(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'RAW': <String, Object>{}}), 200),
      ),
    );
    final controller = AppController(
      api: api,
      storage: LocalStorageService(preferences: preferences),
    );
    addTearDown(() {
      controller.dispose();
      api.dispose();
    });
    await controller.initialize();
    await controller.upsertPosition(controller.coinFor('BTC'), .25);
    await _mount(tester, controller);
    await _tab(tester, 'Carteira');

    expect(controller.portfolioTotal, isNull);
    expect(find.text('--'), findsWidgets);
    expect(find.text(format.brl(0)), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
