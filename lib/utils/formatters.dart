import 'package:intl/intl.dart';

final _brl = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);
final _compactBrl = NumberFormat.compactCurrency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 1,
);
final _quantity = NumberFormat.decimalPattern('pt_BR')
  ..minimumFractionDigits = 0
  ..maximumFractionDigits = 8;

bool _hasValue(double? value) => value != null && value.isFinite;

String _scientific(double value) =>
    value.toStringAsExponential(3).replaceAll('.', ',');

bool _needsScientific(double value) =>
    value != 0 && (value.abs() < 1e-8 || value.abs() >= 1e15);

String brl(double? value) {
  if (!_hasValue(value)) return '--';
  final amount = value! == 0 ? 0.0 : value;
  if (_needsScientific(amount)) return 'R\$ ${_scientific(amount)}';
  if (amount != 0 && amount.abs() < .01) {
    final precise = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 8,
    );
    return precise.format(amount).replaceFirst(RegExp(r'0+$'), '');
  }
  return _brl.format(amount);
}

String compactBrl(double? value) {
  if (!_hasValue(value)) return '--';
  if (value!.abs() < 1 || _needsScientific(value)) return brl(value);
  return _compactBrl.format(value);
}

String number(double? value, {int decimals = 2}) {
  if (!_hasValue(value)) return '--';
  if (_needsScientific(value!)) return _scientific(value);
  final digits = decimals.clamp(0, 12).toInt();
  return NumberFormat.decimalPatternDigits(
    locale: 'pt_BR',
    decimalDigits: digits,
  ).format(value);
}

String quantity(double value) {
  if (!value.isFinite) return '--';
  if (_needsScientific(value)) return _scientific(value);
  return _quantity.format(value);
}

String percent(double? value) {
  if (!_hasValue(value)) return '--';
  final sign = value! > 0 ? '+' : '';
  final label = value != 0 && value.abs() < .01 && !_needsScientific(value)
      ? number(value, decimals: 8).replaceFirst(RegExp(r'0+$'), '')
      : number(value == 0 ? 0 : value);
  return '$sign$label%';
}

String dateTimeLabel(DateTime? value) {
  if (value == null) return '--';
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} às ${two(local.hour)}:${two(local.minute)}';
}
