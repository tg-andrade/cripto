import 'package:flutter/material.dart';
import '../providers/app_controller.dart';
import '../utils/formatters.dart' as format;
import '../utils/ui_actions.dart';
import '../widgets/app_widgets.dart';
import 'coin_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    required this.controller,
    required this.onExplore,
  });
  final AppController controller;
  final VoidCallback onExplore;
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    final symbols = state.favorites.where((symbol) {
      final coin = state.coinFor(symbol);
      final query = _query.trim().toLowerCase();
      return symbol.toLowerCase().contains(query) ||
          coin.coinName.toLowerCase().contains(query);
    }).toList()..sort();
    return RefreshIndicator(
      onRefresh: state.refreshMarket,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        children: [
          if (state.favorites.isEmpty)
            EmptyState(
              icon: Icons.star_border_rounded,
              title: 'Seus favoritos começam aqui',
              message:
                  'Toque na estrela de uma moeda para acompanhá-la nesta lista.',
              actionLabel: 'Explorar mercado',
              onAction: widget.onExplore,
            )
          else ...[
            AppSearchField(
              hint: 'Buscar nos favoritos',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 20),
            if (state.marketError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(state.marketError!),
              ),
            if (symbols.isEmpty)
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Nenhum resultado',
                message: 'Tente outro nome ou símbolo.',
              ),
            for (final symbol in symbols) ...[
              QuoteTile(
                coin: state.coinFor(symbol),
                quote: state.quoteFor(symbol),
                isFavorite: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CoinDetailScreen(
                      controller: state,
                      coin: state.coinFor(symbol),
                    ),
                  ),
                ),
                onFavorite: () => toggleFavorite(context, state, symbol),
              ),
              if (state.isQuoteStale(symbol))
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Text(
                    'Cotação salva · ${format.dateTimeLabel(state.quoteRefreshedAt(symbol))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ],
          const DataFooter(),
        ],
      ),
    );
  }
}
