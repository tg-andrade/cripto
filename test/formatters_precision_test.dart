import 'package:cryptohub/utils/formatters.dart' as format;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prices smaller than one cent retain their nonzero value', () {
    expect(format.brl(.0000123), contains('0,0000123'));
    expect(format.compactBrl(.0000123), contains('0,0000123'));
    expect(format.brl(.00000001), contains('0,00000001'));
    expect(format.brl(-.0000123), contains('0,0000123'));
    expect(format.brl(-.0000123), contains('-'));
  });

  test('extreme finite values stay readable in every numeric formatter', () {
    expect(format.brl(1e300), contains('e+300'));
    expect(format.brl(1e300).length, lessThan(30));
    expect(format.compactBrl(1e-300), contains('e-300'));
    expect(format.quantity(1e300), contains('e+300'));
    expect(format.quantity(1e-300), contains('e-300'));
    expect(format.number(1e300), contains('e+300'));
    expect(format.percent(1e-300), contains('e-300%'));
  });

  test('small percentage changes retain their magnitude and sign', () {
    expect(format.percent(.0001), '+0,0001%');
    expect(format.percent(-.0001), '-0,0001%');
    expect(format.percent(2.5), '+2,50%');
    expect(format.percent(-0.0), '0,00%');
  });

  test('ordinary currency and quantity formatting is preserved', () {
    expect(format.brl(12.5), contains('12,50'));
    expect(format.brl(0), contains('0,00'));
    expect(format.quantity(.25), '0,25');
    expect(format.number(1234.56), '1.234,56');
  });

  test('missing and nonfinite values remain unavailable', () {
    for (final value in <double?>[
      null,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(format.brl(value), '--');
      expect(format.compactBrl(value), '--');
      expect(format.number(value), '--');
      expect(format.percent(value), '--');
    }
    expect(format.quantity(double.nan), '--');
  });
}
