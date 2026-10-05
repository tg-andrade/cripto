import 'dart:async';
import 'package:flutter/material.dart';
import '../models/coin_info.dart';
import '../models/coin_quote.dart';
import '../models/portfolio_position.dart';
import '../providers/app_controller.dart';
import '../providers/coin_detail_controller.dart';
import '../utils/formatters.dart' as format;
import '../utils/ui_actions.dart';
import '../widgets/app_widgets.dart';
import '../theme/app_theme.dart';
import 'search_screen.dart';

Future<void> showPortfolioEditor(
  BuildContext context,
  AppController controller, {
  CoinInfo? coin,
  PortfolioPosition? position,
  CoinQuote? quote,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PortfolioEditor(
    controller: controller,
    initialCoin: coin,
    position: position,
    quote: quote,
  ),
);

class _PortfolioEditor extends StatefulWidget {
  const _PortfolioEditor({
    required this.controller,
    this.initialCoin,
    this.position,
    this.quote,
  });
  final AppController controller;
  final CoinInfo? initialCoin;
  final PortfolioPosition? position;
  final CoinQuote? quote;
  @override
  State<_PortfolioEditor> createState() => _PortfolioEditorState();
}

class _PortfolioEditorState extends State<_PortfolioEditor> {
  late CoinInfo? _coin = widget.position?.coin ?? widget.initialCoin;
  late final TextEditingController _quantity = TextEditingController(
    text: widget.position?.quantity.toString().replaceAll('.', ',') ?? '',
  );
  bool _saving = false;
  String? _error;
  CoinDetailController? _quote;
  late int _keyRevision;
  @override
  void initState() {
    super.initState();
    _keyRevision = widget.controller.apiKeyRevision;
    widget.controller.addListener(_onAppChanged);
    _loadEstimate(seed: widget.quote);
  }

  void _onAppChanged() {
    if (!mounted || _keyRevision == widget.controller.apiKeyRevision) return;
    _keyRevision = widget.controller.apiKeyRevision;
    if (_quote != null) unawaited(_quote!.loadQuote());
  }

  void _loadEstimate({CoinQuote? seed}) {
    _quote?.dispose();
    _quote = _coin == null
        ? null
        : CoinDetailController(
            api: widget.controller.api,
            symbol: _coin!.symbol,
            quote: seed ?? widget.controller.quoteFor(_coin!.symbol),
          );
    if (_quote != null) unawaited(_quote!.loadQuote());
  }

  double? get _amount =>
      double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
  @override
  void dispose() {
    widget.controller.removeListener(_onAppChanged);
    _quote?.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _select() async {
    final result = await Navigator.push<CoinInfo>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SearchScreen(controller: widget.controller, selectCoin: true),
      ),
    );
    if (result != null && mounted) {
      final existing = widget.controller.positions.where(
        (p) => p.symbol == result.symbol,
      );
      setState(() {
        final changedCoin = _coin?.symbol != result.symbol;
        _coin = result;
        _error = null;
        if (existing.isNotEmpty) {
          _quantity.text = existing.first.quantity.toString().replaceAll(
            '.',
            ',',
          );
        } else if (changedCoin) {
          _quantity.clear();
        }
        _loadEstimate();
      });
    }
  }

  Future<void> _save() async {
    final amount = _amount;
    if (_coin == null) {
      setState(() => _error = 'Selecione uma moeda.');
      return;
    }
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(
        () => _error = 'Informe uma quantidade maior que zero. Exemplo: 0,025',
      );
      return;
    }
    final quote =
        _quote?.quote?.price ??
        widget.controller.quoteFor(_coin!.symbol)?.price;
    if (quote != null && (!(quote * amount).isFinite || quote * amount <= 0)) {
      setState(
        () => _error =
            'Esta quantidade está fora do intervalo que permite calcular o valor.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    bool saved;
    try {
      saved = await widget.controller.upsertPosition(_coin!, amount);
    } on ArgumentError {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível registrar esta moeda ou quantidade.';
          _saving = false;
        });
      }
      return;
    }
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _error =
            'Não foi possível salvar esta posição. Seus dados anteriores foram preservados.';
        _saving = false;
      });
      return;
    }
    Navigator.pop(context);
    showFeedback(context, 'Posição de ${_coin!.symbol} salva.');
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover posição?'),
        content: Text('Remover ${_coin!.coinName} da sua carteira virtual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final removed = await widget.controller.removePosition(_coin!.symbol);
    if (!mounted) return;
    if (!removed) {
      setState(() {
        _error = 'Não foi possível remover este ativo. Tente novamente.';
        _saving = false;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.controller, ?_quote]),
        builder: (context, _) {
          final price = _coin == null
              ? null
              : _quote?.quote?.price ??
                    widget.controller.quoteFor(_coin!.symbol)?.price;
          final amount = _amount;
          final estimate =
              price != null && amount != null && amount.isFinite && amount > 0
              ? price * amount
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.position == null ? 'Adicionar ativo' : 'Editar posição',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Registre a quantidade que você possui.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              CryptoCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: _coin == null
                      ? const Icon(
                          Icons.currency_bitcoin_rounded,
                          color: AppColors.accent,
                        )
                      : CoinAvatar(coin: _coin!),
                  title: Text(_coin?.coinName ?? 'Selecionar moeda'),
                  subtitle: _coin == null ? null : Text(_coin!.symbol),
                  trailing: widget.position == null
                      ? const Icon(Icons.expand_more_rounded)
                      : const Icon(Icons.lock_outline_rounded, size: 18),
                  onTap: widget.position == null && !_saving ? _select : null,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('portfolio-quantity'),
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                enabled: !_saving,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  labelText: 'Quantidade',
                  hintText: '0,00',
                  suffixText: _coin?.symbol,
                  helperText: 'Use vírgula ou ponto para separar decimais.',
                  helperMaxLines: 3,
                  errorText: _error,
                  errorMaxLines: 5,
                ),
              ),
              const SizedBox(height: 20),
              CryptoCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Valor estimado',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        format.brl(estimate),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_quote?.quoteLoading ?? false)
                const LinearProgressIndicator(),
              if (_quote?.quoteError != null) ...[
                Text(
                  _quote!.quoteError!,
                  style: const TextStyle(color: AppColors.muted),
                ),
                TextButton(
                  onPressed: _quote!.loadQuote,
                  child: const Text('Atualizar valor estimado'),
                ),
              ],
              Text(
                'Carteira virtual. O registro não executa compras ou vendas. Salvar substitui a quantidade deste ativo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Salvando…' : 'Salvar posição'),
                ),
              ),
              if (widget.position != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _saving ? null : _remove,
                    child: const Text(
                      'Remover ativo',
                      style: TextStyle(color: AppColors.negative),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
