import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_controller.dart';
import '../widgets/app_widgets.dart';
import '../theme/app_theme.dart';
import 'api_key_sheet.dart';
import 'coin_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    this.selectCoin = false,
  });
  final AppController controller;
  final bool selectCoin;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (!widget.controller.catalogLoaded ||
        widget.controller.catalogError != null) {
      unawaited(widget.controller.loadCatalog());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.selectCoin ? 'Selecionar moeda' : 'Buscar criptomoeda',
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final state = widget.controller;
            final query = _query.trim().toLowerCase();
            final matches =
                state.coins.values
                    .where(
                      (coin) =>
                          coin.symbol.toLowerCase().contains(query) ||
                          coin.coinName.toLowerCase().contains(query),
                    )
                    .toList()
                  ..sort((a, b) {
                    final aExact = a.symbol.toLowerCase() == query;
                    final bExact = b.symbol.toLowerCase() == query;
                    if (aExact != bExact) return aExact ? -1 : 1;
                    final aPopular = state.marketSymbols.indexOf(a.symbol);
                    final bPopular = state.marketSymbols.indexOf(b.symbol);
                    if (query.isEmpty && (aPopular >= 0 || bPopular >= 0)) {
                      return (aPopular < 0 ? 999 : aPopular).compareTo(
                        bPopular < 0 ? 999 : bPopular,
                      );
                    }
                    final nameOrder = a.coinName.compareTo(b.coinName);
                    return nameOrder == 0
                        ? a.symbol.compareTo(b.symbol)
                        : nameOrder;
                  });
            final visible = matches.take(80).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: AppSearchField(
                    controller: _search,
                    hint: 'Nome ou símbolo: Bitcoin, ETH…',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                if (state.catalogLoading) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      if (state.catalogError != null) ...[
                        ErrorState(
                          message: state.catalogError!,
                          onRetry: state.loadCatalog,
                          onConfigure: () => showApiKeySheet(context, state),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (visible.isEmpty && !state.catalogLoading)
                        const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Nenhuma moeda encontrada',
                          message: 'Tente outro nome ou símbolo.',
                        ),
                      for (final coin in visible) ...[
                        CryptoCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CoinAvatar(coin: coin),
                            title: Text(coin.coinName),
                            subtitle: Text(
                              coin.symbol,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              if (widget.selectCoin) {
                                Navigator.pop(context, coin);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => CoinDetailScreen(
                                      controller: state,
                                      coin: coin,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (matches.length > visible.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Mostrando ${visible.length} de ${matches.length}. Refine a busca.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const DataFooter(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
