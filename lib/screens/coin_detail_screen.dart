import 'dart:async';
import 'package:flutter/material.dart';
import '../models/coin_info.dart';
import '../models/portfolio_position.dart';
import '../providers/app_controller.dart';
import '../providers/coin_detail_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart' as format;
import '../utils/ui_actions.dart';
import '../widgets/app_widgets.dart';
import '../widgets/history_chart.dart';
import 'api_key_sheet.dart';
import 'portfolio_editor.dart';

class CoinDetailScreen extends StatefulWidget {
  const CoinDetailScreen({
    super.key,
    required this.controller,
    required this.coin,
  });
  final AppController controller;
  final CoinInfo coin;
  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  late final CoinDetailController _detail = CoinDetailController(
    api: widget.controller.api,
    symbol: widget.coin.symbol,
    quote: widget.controller.quoteFor(widget.coin.symbol),
  );
  @override
  void initState() {
    super.initState();
    unawaited(_detail.load());
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _configure() async {
    final revision = widget.controller.apiKeyRevision;
    await showApiKeySheet(context, widget.controller);
    if (mounted && revision != widget.controller.apiKeyRevision) {
      await _detail.load();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_detail, widget.controller]),
    builder: (context, _) {
      final quote = _detail.quote;
      final favorite = widget.controller.favorites.contains(widget.coin.symbol);
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.coin.symbol),
          actions: [
            IconButton(
              tooltip: favorite
                  ? 'Remover dos favoritos'
                  : 'Adicionar aos favoritos',
              onPressed: () => toggleFavorite(
                context,
                widget.controller,
                widget.coin.symbol,
              ),
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: favorite ? AppColors.accent : AppColors.muted,
              ),
            ),
            IconButton(
              tooltip: 'Configurar API',
              onPressed: _configure,
              icon: const Icon(Icons.key_rounded),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: _detail.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Row(
                    children: [
                      CoinAvatar(coin: widget.coin, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.coin.coinName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              '${widget.coin.symbol} · Real brasileiro',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_detail.quoteLoading && quote == null)
                    const LinearProgressIndicator(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      format.brl(quote?.price),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChangeBadge(percent: quote?.changePct24h),
                      const Text(
                        'últimas 24h',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_detail.quoteError != null) ...[
                    ErrorState(
                      message: _detail.quoteError!,
                      onRetry: _detail.loadQuote,
                      onConfigure: _configure,
                    ),
                    const SizedBox(height: 20),
                  ],
                  CryptoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeading(title: 'Histórico de preço'),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final period in HistoryPeriod.values)
                              ChoiceChip(
                                label: Text(period.label),
                                selected: _detail.period == period,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: _detail.period == period
                                      ? AppColors.ink
                                      : AppColors.muted,
                                ),
                                onSelected: (_) => _detail.selectPeriod(period),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_detail.historyLoading)
                          const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_detail.historyError != null)
                          Column(
                            children: [
                              Text(
                                _detail.historyError!,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              TextButton.icon(
                                onPressed: _detail.loadHistory,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Recarregar histórico'),
                              ),
                            ],
                          )
                        else
                          HistoryChart(points: _detail.points),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeading(title: 'Dados de mercado'),
                  const SizedBox(height: 14),
                  CryptoCard(
                    child: Column(
                      children: [
                        _stat('Máxima · 24h', format.brl(quote?.high24h)),
                        _stat('Mínima · 24h', format.brl(quote?.low24h)),
                        _stat('Abertura · 24h', format.brl(quote?.open24h)),
                        _stat(
                          'Volume · ${widget.coin.symbol}',
                          format.number(quote?.volume24h, decimals: 4),
                        ),
                        _stat(
                          'Volume · BRL',
                          format.compactBrl(quote?.volume24hTo),
                        ),
                        _stat(
                          'Valor de mercado',
                          format.compactBrl(quote?.marketCap),
                        ),
                        _stat(
                          'Oferta circulante',
                          format.number(quote?.supply, decimals: 0),
                        ),
                        _stat('Última negociação', quote?.lastMarket ?? '--'),
                        _stat(
                          'Atualizado em',
                          format.dateTimeLabel(quote?.lastUpdate),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  if (widget.coin.algorithm != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Algoritmo: ${widget.coin.algorithm}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => showPortfolioEditor(
                      context,
                      widget.controller,
                      coin: widget.coin,
                      position: _position(),
                      quote: _detail.quote,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar à carteira'),
                  ),
                  const DataFooter(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  PortfolioPosition? _position() {
    final values = widget.controller.positions.where(
      (p) => p.symbol == widget.coin.symbol,
    );
    return values.isEmpty ? null : values.first;
  }

  Widget _stat(String label, String value, {bool last = false}) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}
