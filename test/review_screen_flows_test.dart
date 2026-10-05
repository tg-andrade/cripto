import 'dart:async';
import 'dart:convert';

import 'package:cryptohub/main.dart';
import 'package:cryptohub/models/coin_info.dart';
import 'package:cryptohub/models/portfolio_position.dart';
import 'package:cryptohub/providers/app_controller.dart';
import 'package:cryptohub/screens/api_key_sheet.dart';
import 'package:cryptohub/screens/portfolio_editor.dart';
import 'package:cryptohub/screens/search_screen.dart';
import 'package:cryptohub/services/crypto_api_service.dart';
import 'package:cryptohub/services/local_storage_service.dart';
import 'package:cryptohub/theme/app_theme.dart';
import 'package:cryptohub/utils/formatters.dart' as format;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object payload, [int status = 200]) => http.Response(
  jsonEncode(payload),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _quotes(http.Request request) => _json({
  'RAW': {
    for (final symbol in request.url.queryParameters['fsyms']!.split(','))
      symbol: {
        'BRL': {
          'FROMSYMBOL': symbol,
          'TOSYMBOL': 'BRL',
          'PRICE': symbol == 'LINK' ? 50 : 1000,
          'CHANGEPCT24HOUR': 2.5,
        },
      },
  },
});

class _FailingStorage extends LocalStorageService {
  _FailingStorage(SharedPreferences preferences)
    : super(preferences: preferences);
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<StoredAppData> read() async {
    if (failRead) throw StateError('Local read failed');
    return super.read();
  }

  @override
  Future<void> saveUserData({
    required Set<String> favorites,
    required List<PortfolioPosition> positions,
    required Map<String, CoinInfo> coins,
  }) async {
    if (failWrite) throw StateError('Local write failed');
    await super.saveUserData(
      favorites: favorites,
      positions: positions,
      coins: coins,
    );
  }
}

class _Fixture {
  _Fixture(this.storage) {
    api = CryptoApiService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/pricemultifull')) {
          quoteRequests.add(request.url.queryParameters['fsyms']!);
          if (failQuotes ||
              request.headers['Authorization'] == 'Apikey test-invalid') {
            return _json({'Message': 'API key invalid'}, 401);
          }
          if (request.headers['Authorization'] == 'Apikey test-pending') {
            pendingRequest = request;
            return pending!.future;
          }
          return _quotes(request);
        }
        if (request.url.path.endsWith('/all/coinlist')) {
          catalogRequests++;
          return _json({
            'Data': {
              'LINK': {'Symbol': 'LINK', 'CoinName': 'Chainlink'},
            },
          });
        }
        if (request.url.path.contains('/histo')) {
          return _json({
            'Data': {
              'Data': [
                {'time': 1790715600, 'close': 40},
                {'time': 1790802000, 'close': 50},
              ],
            },
          });
        }
        if (request.url.path.contains('/news')) {
          return _json({'Data': <Object>[]});
        }
        throw StateError('Unexpected request ${request.url}');
      }),
    );
    controller = AppController(api: api, storage: storage);
  }
  final _FailingStorage storage;
  late final CryptoApiService api;
  late final AppController controller;
  final quoteRequests = <String>[];
  int catalogRequests = 0;
  bool failQuotes = false;
  Completer<http.Response>? pending;
  http.Request? pendingRequest;
  void dispose() {
    controller.dispose();
    api.dispose();
  }
}

Future<_Fixture> _fixture() async {
  SharedPreferences.setMockInitialValues({});
  final fixture = _Fixture(
    _FailingStorage(await SharedPreferences.getInstance()),
  );
  addTearDown(fixture.dispose);
  await fixture.controller.initialize();
  return fixture;
}

Future<void> _host(
  WidgetTester tester,
  Widget Function(BuildContext) child,
) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Builder(builder: child)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cached quotes without a session key offer API configuration', (
    tester,
  ) async {
    final fixture = await _fixture();
    fixture.failQuotes = true;
    await fixture.controller.refreshMarket();
    expect(fixture.controller.hasCachedQuotes, isTrue);
    expect(fixture.controller.hasApiKey, isFalse);
    await tester.pumpWidget(
      CryptoHubApp(controller: fixture.controller, initialize: false),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Configure sua chave da CryptoCompare para atualizar as cotações salvas.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Configurar acesso'));
    expect(find.byKey(const ValueKey('api-key-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a rejected API key remains editable with the error visible', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _host(
      tester,
      (context) => TextButton(
        onPressed: () => showApiKeySheet(context, fixture.controller),
        child: const Text('Open API'),
      ),
    );
    await _tap(tester, find.text('Open API'));
    final input = find.byKey(const ValueKey('api-key-input'));
    await tester.enterText(input, 'test-invalid');
    await _tap(tester, find.text('Salvar e consultar'));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.text(
        'Configure uma chave válida da CryptoCompare para consultar os dados.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(input).enabled, isTrue);
    expect(tester.takeException(), isNull);

    await tester.enterText(input, 'test-valid');
    await _tap(tester, find.text('Salvar e consultar'));
    expect(find.byType(BottomSheet), findsNothing);
    expect(fixture.controller.marketError, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the key input is disabled while its consultation is pending', (
    tester,
  ) async {
    final fixture = await _fixture();
    fixture.pending = Completer<http.Response>();
    await _host(
      tester,
      (context) => TextButton(
        onPressed: () => showApiKeySheet(context, fixture.controller),
        child: const Text('Open API'),
      ),
    );
    await _tap(tester, find.text('Open API'));
    final input = find.byKey(const ValueKey('api-key-input'));
    await tester.enterText(input, 'test-pending');
    await tester.ensureVisible(find.text('Salvar e consultar'));
    await tester.tap(find.text('Salvar e consultar'));
    await tester.pump();
    expect(tester.widget<TextField>(input).enabled, isFalse);
    expect(find.text('Consultando…'), findsOneWidget);
    fixture.pending!.complete(_quotes(fixture.pendingRequest!));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a coin outside the market list has an estimate before saving', (
    tester,
  ) async {
    final fixture = await _fixture();
    await fixture.controller.loadCatalog();
    final link = fixture.controller.coinFor('LINK');
    expect(fixture.controller.quoteFor('LINK'), isNull);
    await _host(
      tester,
      (context) => TextButton(
        onPressed: () =>
            showPortfolioEditor(context, fixture.controller, coin: link),
        child: const Text('Open portfolio'),
      ),
    );
    await _tap(tester, find.text('Open portfolio'));
    expect(fixture.quoteRequests, contains('LINK'));
    final input = find.byKey(const ValueKey('portfolio-quantity'));
    await tester.enterText(input, '2,5');
    await tester.pumpAndSettle();
    expect(find.text(format.brl(125)), findsOneWidget);
    expect(fixture.controller.positions, isEmpty);
    await _tap(tester, find.text('Salvar posição'));
    expect(fixture.controller.positions.single.symbol, 'LINK');
    expect(fixture.controller.positions.single.quantity, 2.5);
    expect(fixture.controller.portfolioTotal, 125);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed portfolio writes leave the editor and quantity available', (
    tester,
  ) async {
    final fixture = await _fixture();
    fixture.storage.failWrite = true;
    await _host(
      tester,
      (context) => TextButton(
        onPressed: () => showPortfolioEditor(
          context,
          fixture.controller,
          coin: fixture.controller.coinFor('BTC'),
        ),
        child: const Text('Open portfolio'),
      ),
    );
    await _tap(tester, find.text('Open portfolio'));
    final input = find.byKey(const ValueKey('portfolio-quantity'));
    await tester.enterText(input, '0,25');
    await _tap(tester, find.text('Salvar posição'));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, '0,25');
    expect(tester.widget<TextField>(input).enabled, isTrue);
    expect(fixture.controller.positions, isEmpty);
    expect(
      find.text(
        'Não foi possível salvar esta posição. Seus dados anteriores foram preservados.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening search reuses a successfully loaded catalogue', (
    tester,
  ) async {
    final fixture = await _fixture();
    for (var opening = 0; opening < 2; opening++) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: SearchScreen(controller: fixture.controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'LINK');
      await tester.pumpAndSettle();
      expect(find.text('Chainlink'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    expect(fixture.catalogRequests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a failed local read offers a retry that restores saved holdings',
    (tester) async {
      final fixture = await _fixture();
      await fixture.controller.upsertPosition(
        fixture.controller.coinFor('BTC'),
        2,
      );
      fixture.storage.failRead = true;
      final restored = AppController(
        api: fixture.api,
        storage: fixture.storage,
      );
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.storageReady, isFalse);
      await tester.pumpWidget(
        CryptoHubApp(controller: restored, initialize: false),
      );
      await tester.pumpAndSettle();
      fixture.storage.failRead = false;
      await _tap(tester, find.text('Carregar dados salvos novamente'));
      expect(restored.storageReady, isTrue);
      expect(restored.positions.single.symbol, 'BTC');
      expect(restored.positions.single.quantity, 2);
      expect(find.text('Carregar dados salvos novamente'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
