import 'dart:convert';

import 'package:cryptohub/models/coin_info.dart';
import 'package:cryptohub/models/coin_quote.dart';
import 'package:cryptohub/models/portfolio_position.dart';
import 'package:cryptohub/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'per coin cache timestamps survive storage and legacy cache uses the batch timestamp',
    () async {
      final latest = DateTime.utc(2026, 10, 1, 12);
      final older = latest.subtract(const Duration(hours: 1));
      final storage = LocalStorageService();
      await storage.saveQuoteCache(
        {
          'BTC': const CoinQuote(
            fromSymbol: 'BTC',
            toSymbol: 'BRL',
            price: 100,
          ),
          'ETH': const CoinQuote(fromSymbol: 'ETH', toSymbol: 'BRL', price: 50),
        },
        latest,
        quoteRefreshTimes: {'BTC': latest, 'ETH': older},
      );
      final saved = await storage.read();
      expect(saved.quoteRefreshTimes, {'BTC': latest, 'ETH': older});
      final preferences = await SharedPreferences.getInstance();
      final legacy =
          jsonDecode(preferences.getString(LocalStorageService.quoteCacheKey)!)
              as Map;
      legacy.remove('quoteUpdatedAt');
      await preferences.setString(
        LocalStorageService.quoteCacheKey,
        jsonEncode(legacy),
      );
      final restored = await storage.read();
      expect(restored.quoteRefreshTimes, {'BTC': latest, 'ETH': latest});
      expect(restored.error, isNull);
    },
  );

  test(
    'invalid cache fields cannot masquerade as a usable fresh price',
    () async {
      final updatedAt = DateTime.utc(2026, 10, 1, 12);
      SharedPreferences.setMockInitialValues({
        LocalStorageService.quoteCacheKey: jsonEncode({
          'currency': 'BRL',
          'updatedAt': updatedAt.toIso8601String(),
          'quotes': {
            'BTC': {'FROMSYMBOL': 'BTC', 'TOSYMBOL': 'BRL', 'PRICE': 100},
            'ETH': {'FROMSYMBOL': 'ETH', 'TOSYMBOL': 'BRL', 'PRICE': 'NaN'},
            'LTC': {'FROMSYMBOL': 'LTC', 'TOSYMBOL': 'BRL', 'PRICE': -1},
          },
          'quoteUpdatedAt': {'BTC': 'invalid date'},
        }),
      });
      final saved = await LocalStorageService().read();
      expect(saved.quotes.keys, ['BTC']);
      expect(saved.quoteRefreshTimes, isEmpty);
      expect(saved.error, contains('ignorados'));
      expect(saved.userDataReadable, isTrue);
    },
  );

  test(
    'optional metadata damage preserves quantities while malformed user documents block writes',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.userDataKey: jsonEncode({
          'favorites': ['BTC'],
          'positions': [
            {
              'symbol': 'BTC',
              'quantity': 1.25,
              'coinName': false,
              'imageUrl': 12,
            },
          ],
        }),
      });
      final storage = LocalStorageService();
      final saved = await storage.read();
      expect(saved.positions.single.quantity, 1.25);
      expect(saved.positions.single.coinName, 'BTC');
      expect(saved.userDataReadable, isTrue);
      expect(saved.error, contains('ignorados'));
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(LocalStorageService.userDataKey, '[not json');
      final malformed = await storage.read();
      expect(malformed.userDataReadable, isFalse);
      expect(malformed.error, isNotNull);
    },
  );

  test(
    'saved references retain id and algorithm and exclude unselected catalog coins',
    () async {
      final storage = LocalStorageService();
      final btc = CoinInfo(
        symbol: 'BTC',
        id: '1182',
        coinName: 'Bitcoin',
        algorithm: 'SHA-256',
        imageUrl: '/media/btc.png',
      );
      await storage.saveUserData(
        favorites: {'BTC'},
        positions: [
          PortfolioPosition(symbol: 'BTC', coinName: 'Bitcoin', quantity: 0.1),
        ],
        coins: {
          'BTC': btc,
          'ETH': CoinInfo(symbol: 'ETH', coinName: 'Ethereum'),
        },
      );
      final saved = await storage.read();
      expect(saved.coins.keys, ['BTC']);
      expect(saved.coins['BTC']?.id, '1182');
      expect(saved.coins['BTC']?.algorithm, 'SHA-256');
      expect(
        saved.coins['BTC']?.imageUrl,
        'https://www.cryptocompare.com/media/btc.png',
      );
    },
  );
}
