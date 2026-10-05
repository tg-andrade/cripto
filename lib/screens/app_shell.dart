import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_controller.dart';
import '../theme/app_theme.dart';
import 'api_key_sheet.dart';
import 'market_screen.dart';
import 'portfolio_screen.dart';
import 'news_screen.dart';
import 'favorites_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  void _select(int value) {
    setState(() => _index = value);
    if (value == 2 &&
        widget.controller.news.isEmpty &&
        !widget.controller.newsLoading) {
      unawaited(widget.controller.loadNews());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CRYPTOHUB',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                'Mercado',
                                'Carteira',
                                'Notícias',
                                'Favoritos',
                              ][_index],
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'BRL',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Configurar API',
                        onPressed: () =>
                            showApiKeySheet(context, widget.controller),
                        icon: const Icon(Icons.tune_rounded, size: 22),
                      ),
                    ],
                  ),
                ),
                if (widget.controller.storageError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.controller.storageError!,
                          style: const TextStyle(color: AppColors.negative),
                        ),
                        if (!widget.controller.storageReady)
                          TextButton(
                            onPressed: widget.controller.retryStorage,
                            child: const Text(
                              'Carregar dados salvos novamente',
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      MarketScreen(controller: widget.controller),
                      PortfolioScreen(
                        controller: widget.controller,
                        active: _index == 1,
                      ),
                      NewsScreen(controller: widget.controller),
                      FavoritesScreen(
                        controller: widget.controller,
                        onExplore: () => _select(0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          height: 72,
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Mercado',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Carteira',
            ),
            NavigationDestination(
              icon: Icon(Icons.article_outlined),
              label: 'Notícias',
            ),
            NavigationDestination(
              icon: Icon(Icons.star_border_rounded),
              selectedIcon: Icon(Icons.star_rounded),
              label: 'Favoritos',
            ),
          ],
        ),
      ),
    ),
  );
}
