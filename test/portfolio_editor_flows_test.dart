import 'dart:convert';

import 'package:cryptohub/main.dart';
import 'package:cryptohub/providers/app_controller.dart';
import 'package:cryptohub/screens/search_screen.dart';
import 'package:cryptohub/services/crypto_api_service.dart';
import 'package:cryptohub/services/local_storage_service.dart';
import 'package:cryptohub/utils/formatters.dart' as format;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EditorFixture {
  _EditorFixture(this.preferences) {
    api = CryptoApiService(client: MockClient(_respond));
    controller = AppController(
      api: api,
      storage: LocalStorageService(preferences: preferences),
    );
  }

  final SharedPreferences preferences;
  late final CryptoApiService api;
  late final AppController controller;

  double _price(String symbol) => symbol == 'BTC'
      ? 100000
      : symbol == 'SOL'
      ? 500
      : 100;

  Future<http.Response> _respond(http.Request request) async {
    final path = request.url.path;
    Object payload;
    if (path.endsWith('/pricemultifull')) {
      payload = {
        'RAW': {
          for (final symbol in request.url.queryParameters['fsyms']!.split(','))
            symbol: {
              'BRL': {
                'FROMSYMBOL': symbol,
                'TOSYMBOL': 'BRL',
                'PRICE': _price(symbol),
                'CHANGEPCT24HOUR': 1.2,
                'LASTUPDATE': 1790802000,
              },
            },
        },
      };
    } else if (path.endsWith('/all/coinlist')) {
      payload = {
        'Data': {
          'BTC': {'Symbol': 'BTC', 'CoinName': 'Bitcoin'},
          'SOL': {'Symbol': 'SOL', 'CoinName': 'Solana'},
        },
      };
    } else if (path.contains('/histo')) {
      final symbol = request.url.queryParameters['fsym']!;
      payload = {
        'Data': {
          'Data': [
            {'time': 1790629200, 'close': _price(symbol) * .9},
            {'time': 1790715600, 'close': _price(symbol)},
          ],
        },
      };
    } else if (path.endsWith('/pricemulti')) {
      payload = {
        for (final symbol in request.url.queryParameters['fsyms']!.split(','))
          symbol: {'BRL': _price(symbol)},
      };
    } else {
      throw StateError('Unexpected request: ${request.url}');
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

Future<_EditorFixture> _prepare(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final fixture = _EditorFixture(await SharedPreferences.getInstance());
  addTearDown(fixture.dispose);
  await fixture.controller.initialize();
  await fixture.controller.upsertPosition(fixture.controller.coinFor('BTC'), 5);
  tester.view.physicalSize = const Size(360, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    CryptoHubApp(controller: fixture.controller, initialize: false),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Carteira').last);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return fixture;
}

Future<void> _openAdd(WidgetTester tester) async {
  final add = find.text('Adicionar');
  await tester.ensureVisible(add);
  await tester.tap(add);
  await tester.pumpAndSettle();
  expect(find.text('Adicionar ativo'), findsOneWidget);
}

Future<void> _chooseCoin(WidgetTester tester, String symbol) async {
  final selector = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(ListTile),
  );
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final search = find.descendant(
    of: find.byType(SearchScreen),
    matching: find.byType(TextField),
  );
  await tester.enterText(search, symbol);
  await tester.pumpAndSettle();
  final result = find.descendant(
    of: find.byType(SearchScreen),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.subtitle is Text &&
          (widget.subtitle as Text).data == symbol,
    ),
  );
  await tester.tap(result);
  await tester.pumpAndSettle();
  expect(find.byType(SearchScreen), findsNothing);
  expect(tester.takeException(), isNull);
}

Finder get _quantity => find.byKey(const ValueKey('portfolio-quantity'));

Future<void> _save(WidgetTester tester) async {
  final save = find.text('Salvar posição');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'changing an existing BTC selection to SOL clears its quantity and rejects zero',
    (tester) async {
      final fixture = await _prepare(tester);
      await _openAdd(tester);
      await _chooseCoin(tester, 'BTC');
      expect(tester.widget<TextField>(_quantity).controller!.text, '5,0');

      await _chooseCoin(tester, 'SOL');
      expect(tester.widget<TextField>(_quantity).controller!.text, isEmpty);
      await tester.enterText(_quantity, '0');
      await _save(tester);
      expect(
        find.text('Informe uma quantidade maior que zero. Exemplo: 0,025'),
        findsOneWidget,
      );
      expect(fixture.controller.positions.single.symbol, 'BTC');
      expect(fixture.controller.positions.single.quantity, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'adding 0,25 SOL calculates the total and confirmation removes only SOL',
    (tester) async {
      final fixture = await _prepare(tester);
      await _openAdd(tester);
      await _chooseCoin(tester, 'SOL');
      await tester.enterText(_quantity, '0,25');
      await _save(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(fixture.controller.positions.length, 2);
      expect(
        fixture.controller.positions
            .singleWhere((position) => position.symbol == 'SOL')
            .quantity,
        .25,
      );
      expect(fixture.controller.portfolioTotal, 500125);
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text(format.brl(500125)), findsOneWidget);
      expect(tester.takeException(), isNull);

      final sol = find.byKey(const ValueKey('portfolio-SOL'));
      await tester.ensureVisible(sol);
      await tester.tap(sol);
      await tester.pumpAndSettle();
      final remove = find.text('Remover ativo');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.controller.positions.length, 2);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fixture.controller.positions.length, 2);

      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Remover'),
        ),
      );
      await tester.pumpAndSettle();
      expect(fixture.controller.positions.single.symbol, 'BTC');
      expect(fixture.controller.positions.single.quantity, 5);
      expect(fixture.controller.portfolioTotal, 500000);
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('portfolio-BTC')), findsOneWidget);
      expect(find.byKey(const ValueKey('portfolio-SOL')), findsNothing);
      final saved = await LocalStorageService(
        preferences: fixture.preferences,
      ).read();
      expect(saved.positions.single.symbol, 'BTC');
      expect(saved.positions.single.quantity, 5);
      expect(tester.takeException(), isNull);
    },
  );
}
