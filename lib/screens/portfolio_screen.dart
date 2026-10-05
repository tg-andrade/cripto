import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_controller.dart';
import '../providers/portfolio_history_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart' as format;
import '../widgets/app_widgets.dart';
import '../widgets/history_chart.dart';
import '../widgets/portfolio_distribution.dart';
import 'portfolio_editor.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({
    super.key,
    required this.controller,
    required this.active,
  });
  final AppController controller;
  final bool active;
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final _history = PortfolioHistoryController(widget.controller.api);
  String _signature = '';
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(covariant PortfolioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _changed();
  }

  void _changed() {
    if (!widget.active) return;
    final signature =
        '${widget.controller.apiKeyRevision}:${widget.controller.positions.map((p) => '${p.symbol}:${p.quantity}').join(',')}';
    if (signature != _signature) {
      _signature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_history.load(widget.controller.positions));
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _history.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await widget.controller.refreshMarket();
    await _history.load(widget.controller.positions);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        children: [
          if (state.positions.isEmpty)
            EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Monte sua carteira virtual',
              message:
                  'Adicione suas moedas e quantidades para acompanhar o valor em reais.',
              actionLabel: 'Adicionar primeiro ativo',
              onAction: () => showPortfolioEditor(context, state),
            )
          else ...[
            CryptoCard(
              color: AppColors.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Valor total estimado',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      format.brl(state.portfolioTotal),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.portfolioIncomplete
                        ? 'Total indisponível. Atualize as cotações de todos os ativos para calcular o total.'
                        : '${state.positions.length} ativos · valores em BRL',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (state.marketError != null && state.portfolioTotal != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Total com cotações salvas · ${format.dateTimeLabel(state.lastRefresh)}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeading(
              title: 'Meus ativos',
              actionLabel: 'Adicionar',
              onAction: () => showPortfolioEditor(context, state),
            ),
            const SizedBox(height: 12),
            for (final position in state.positions) ...[
              CryptoCard(
                key: ValueKey('portfolio-${position.symbol}'),
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () =>
                      showPortfolioEditor(context, state, position: position),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        CoinAvatar(coin: position.coin),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                position.coinName,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${format.quantity(position.quantity)} ${position.symbol}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  format.brl(state.positionValue(position)),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  state.portfolioTotal != null &&
                                          state.portfolioTotal! > 0
                                      ? '${format.number(state.positionValue(position)! / state.portfolioTotal! * 100, decimals: 1)}% · editar'
                                      : 'Editar',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.isQuoteStale(position.symbol))
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Text(
                    'Cotação salva · ${format.dateTimeLabel(state.quoteRefreshedAt(position.symbol))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            CryptoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: 'Distribuição'),
                  PortfolioDistribution(controller: state),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CryptoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: 'Evolução simulada · 30D'),
                  const SizedBox(height: 8),
                  const Text(
                    'Quantidades atuais aplicadas aos preços históricos. Não representa sua rentabilidade.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  ListenableBuilder(
                    listenable: _history,
                    builder: (context, _) {
                      if (_history.loading) {
                        return const SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (_history.error != null) {
                        return Column(
                          children: [
                            Text(
                              _history.error!,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            TextButton(
                              onPressed: () => _history.load(state.positions),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        );
                      }
                      return HistoryChart(
                        points: _history.points,
                        valueLabel: 'Valor',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Carteira virtual · dados salvos neste dispositivo',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const DataFooter(),
        ],
      ),
    );
  }
}
