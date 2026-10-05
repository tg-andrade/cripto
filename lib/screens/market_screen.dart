import 'package:flutter/material.dart';
import '../providers/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart' as format;
import '../utils/ui_actions.dart';
import '../widgets/app_widgets.dart';
import 'api_key_sheet.dart';
import 'coin_detail_screen.dart';
import 'search_screen.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final btc = controller.quoteFor('BTC');
    return RefreshIndicator(
      onRefresh: controller.refreshMarket,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        children: [
          AppSearchField(
            hint: 'Buscar criptomoeda',
            readOnly: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SearchScreen(controller: controller),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (btc?.price != null) ...[
            CryptoCard(
              color: AppColors.raised,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CoinDetailScreen(
                      controller: controller,
                      coin: controller.coinFor('BTC'),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CoinAvatar(coin: controller.coinFor('BTC'), size: 40),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Bitcoin · BTC',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(
                          Icons.north_east_rounded,
                          color: AppColors.muted,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        format.brl(btc?.price),
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChangeBadge(percent: btc?.changePct24h),
                        const Text(
                          'nas últimas 24h',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (controller.isQuoteStale('BTC')) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Cotação salva · ${format.dateTimeLabel(controller.quoteRefreshedAt('BTC'))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Principais moedas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Atualizar cotações',
                onPressed: controller.marketLoading
                    ? null
                    : controller.refreshMarket,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (controller.lastRefresh != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'Última consulta concluída: ${format.dateTimeLabel(controller.lastRefresh)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (controller.marketError != null) ...[
            if (controller.hasCachedQuotes)
              CryptoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exibindo últimas cotações salvas',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.hasApiKey
                          ? controller.marketError!
                          : 'Configure sua chave da CryptoCompare para atualizar as cotações salvas.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    TextButton(
                      onPressed: controller.hasApiKey
                          ? controller.refreshMarket
                          : () => showApiKeySheet(context, controller),
                      child: Text(
                        controller.hasApiKey
                            ? 'Atualizar'
                            : 'Configurar acesso',
                      ),
                    ),
                  ],
                ),
              )
            else
              ErrorState(
                message: controller.hasApiKey
                    ? controller.marketError!
                    : 'Configure sua chave da CryptoCompare para consultar as cotações.',
                onRetry: controller.refreshMarket,
                onConfigure: () => showApiKeySheet(context, controller),
              ),
            const SizedBox(height: 16),
          ],
          if ((!controller.initialized || controller.marketLoading) &&
              !controller.hasCachedQuotes)
            const MarketSkeleton()
          else ...[
            if (controller.marketLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            for (final symbol in controller.marketSymbols) ...[
              QuoteTile(
                coin: controller.coinFor(symbol),
                quote: controller.quoteFor(symbol),
                isFavorite: controller.favorites.contains(symbol),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CoinDetailScreen(
                      controller: controller,
                      coin: controller.coinFor(symbol),
                    ),
                  ),
                ),
                onFavorite: () => toggleFavorite(context, controller, symbol),
              ),
              if (controller.isQuoteStale(symbol))
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Text(
                    'Cotação salva · ${format.dateTimeLabel(controller.quoteRefreshedAt(symbol))}',
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
