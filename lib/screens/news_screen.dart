import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_article.dart';
import '../providers/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart' as format;
import '../utils/ui_actions.dart';
import '../widgets/app_widgets.dart';
import 'api_key_sheet.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.controller});
  final AppController controller;
  Future<void> _open(BuildContext context, NewsArticle article) async {
    final uri = Uri.tryParse(article.url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      showFeedback(context, 'Esta notícia não possui um link válido.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        showFeedback(context, 'Não foi possível abrir a fonte desta notícia.');
      }
    } catch (_) {
      if (context.mounted) {
        showFeedback(context, 'Não foi possível abrir o navegador.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: controller.loadNews,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        const Text(
          'O que acontece no mundo cripto',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        if (controller.newsLoading && controller.news.isEmpty)
          const MarketSkeleton(label: 'Carregando notícias'),
        if (controller.newsError != null) ...[
          ErrorState(
            message: controller.newsError!,
            onRetry: controller.loadNews,
            onConfigure: () => showApiKeySheet(context, controller),
          ),
          const SizedBox(height: 16),
        ],
        if (!controller.newsLoading &&
            controller.newsError == null &&
            controller.news.isEmpty)
          const EmptyState(
            icon: Icons.article_outlined,
            title: 'Sem notícias disponíveis',
            message: 'Atualize a lista para consultar novas publicações.',
          ),
        for (final article in controller.news) ...[
          CryptoCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _open(context, article),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.imageUrl != null)
                    SizedBox(
                      width: double.infinity,
                      height: 170,
                      child: Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.raised,
                          child: Center(
                            child: Icon(
                              Icons.article_outlined,
                              size: 40,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              article.source,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              format.dateTimeLabel(article.publishedOn),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          article.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (article.body.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            article.body.replaceAll(RegExp(r'<[^>]*>'), ''),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => _open(context, article),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Ler na fonte'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        const DataFooter(),
      ],
    ),
  );
}
