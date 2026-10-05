import 'package:flutter/material.dart';

import '../models/coin_info.dart';
import '../models/coin_quote.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart' as format;

class CryptoCard extends StatelessWidget {
  const CryptoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    color: color ?? AppColors.surface,
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class CoinAvatar extends StatelessWidget {
  const CoinAvatar({super.key, required this.coin, this.size = 36});

  final CoinInfo coin;
  final double size;

  Color get _color => switch (coin.symbol.toUpperCase()) {
    'BTC' => AppColors.btc,
    'ETH' => AppColors.eth,
    'SOL' => AppColors.sol,
    _ => AppColors.accent,
  };

  String get _glyph => switch (coin.symbol.toUpperCase()) {
    'BTC' => '₿',
    'ETH' => 'Ξ',
    'SOL' => '◎',
    _ =>
      coin.symbol.isEmpty
          ? '?'
          : coin.symbol.toUpperCase().substring(
              0,
              coin.symbol.length.clamp(0, 3).toInt(),
            ),
  };

  Widget _fallback() => ColoredBox(
    color: _color.withValues(alpha: .14),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _glyph,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize:
                  const {
                    'BTC',
                    'ETH',
                    'SOL',
                  }.contains(coin.symbol.toUpperCase())
                  ? size * .5
                  : size * .31,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = coin.imageUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    final hasImage =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: hasImage
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }
}

class ChangeBadge extends StatelessWidget {
  const ChangeBadge({super.key, this.percent, this.compact = false});

  final double? percent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final valid = percent != null && percent!.isFinite;
    final color = !valid || percent == 0
        ? AppColors.muted
        : percent! > 0
        ? AppColors.positive
        : AppColors.negative;
    final label = format.percent(percent);
    return Semantics(
      label: valid
          ? 'Variação de 24 horas: $label'
          : 'Variação de 24 horas indisponível',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : 8,
          vertical: compact ? 0 : 4,
        ),
        decoration: compact
            ? null
            : BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(7),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (valid && percent != 0) ...[
              Icon(
                percent! > 0
                    ? Icons.north_east_rounded
                    : Icons.south_east_rounded,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DataFooter extends StatelessWidget {
  const DataFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.verified_outlined, size: 14, color: AppColors.muted),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Powered by CryptoCompare',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => CryptoCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 26, color: AppColors.accent),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAction,
            child: Text(actionLabel!, textAlign: TextAlign.center),
          ),
        ],
      ],
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.onConfigure,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) => CryptoCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          size: 32,
          color: AppColors.negative,
        ),
        const SizedBox(height: 16),
        Text(
          'Não foi possível carregar',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Tentar novamente'),
        ),
        if (onConfigure != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onConfigure,
            child: const Text('Configurar acesso'),
          ),
        ],
      ],
    ),
  );
}

class MarketSkeleton extends StatelessWidget {
  const MarketSkeleton({super.key, this.label = 'Carregando cotações'});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    excludeSemantics: true,
    child: Column(
      children: [
        for (var index = 0; index < 4; index++) ...[
          CryptoCard(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.raised,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _placeholder(96, 14),
                      const SizedBox(height: 10),
                      _placeholder(44, 11),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _placeholder(72, 14),
                    const SizedBox(height: 10),
                    _placeholder(42, 11),
                  ],
                ),
              ],
            ),
          ),
          if (index < 3) const SizedBox(height: 10),
        ],
      ],
    ),
  );

  Widget _placeholder(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(width: 8),
        Flexible(
          child: TextButton(
            onPressed: onAction,
            child: Text(actionLabel!, textAlign: TextAlign.right),
          ),
        ),
      ],
    ],
  );
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    this.onChanged,
    this.onTap,
    this.controller,
    this.readOnly = false,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    onTap: onTap,
    readOnly: readOnly,
    textInputAction: TextInputAction.search,
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.muted,
        size: 22,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 50),
    ),
  );
}

class QuoteTile extends StatelessWidget {
  const QuoteTile({
    super.key,
    required this.coin,
    required this.quote,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  final CoinInfo coin;
  final CoinQuote? quote;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return CryptoCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 14,
            right: 4,
            top: 12,
            bottom: 12,
          ),
          child: Row(
            children: [
              CoinAvatar(coin: coin),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (largeText) ...[
                      Text(
                        coin.coinName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        format.brl(quote?.price),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              coin.coinName,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                format.brl(quote?.price),
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 5),
                    if (largeText)
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            coin.symbol.toUpperCase(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                          ChangeBadge(
                            percent: quote?.changePct24h,
                            compact: true,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              coin.symbol.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: ChangeBadge(
                              percent: quote?.changePct24h,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                tooltip: isFavorite
                    ? 'Remover ${coin.coinName} dos favoritos'
                    : 'Adicionar ${coin.coinName} aos favoritos',
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite ? AppColors.accent : AppColors.muted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
