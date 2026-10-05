import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart' as format;

Color allocationColor(String symbol, int index) => switch (symbol) {
  'BTC' => AppColors.btc,
  'ETH' => AppColors.eth,
  'SOL' => AppColors.sol,
  _ => [
    AppColors.accent,
    AppColors.positive,
    AppColors.negative,
    const Color(0xFF87A9FF),
  ][index % 4],
};

class PortfolioDistribution extends StatelessWidget {
  const PortfolioDistribution({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final total = controller.portfolioTotal;
    if (total == null || total <= 0) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          total == 0
              ? 'O valor total dos ativos é zero. Não há distribuição percentual disponível.'
              : 'A distribuição estará disponível quando todos os ativos tiverem cotação.',
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    final entries = controller.positions;
    final slices = [
      for (var index = 0; index < entries.length; index++)
        (
          color: allocationColor(entries[index].symbol, index),
          share: (controller.positionValue(entries[index])! / total)
              .clamp(0.0, 1.0)
              .toDouble(),
        ),
    ];
    return Column(
      children: [
        const SizedBox(height: 12),
        Semantics(
          label: 'Distribuição do valor da carteira por ativo',
          child: SizedBox.square(
            dimension: 146,
            child: CustomPaint(painter: _AllocationPainter(slices)),
          ),
        ),
        const SizedBox(height: 20),
        for (var index = 0; index < entries.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: allocationColor(entries[index].symbol, index),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entries[index].coinName)),
                Text(
                  '${format.number(slices[index].share * 100, decimals: 1)}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AllocationPainter extends CustomPainter {
  _AllocationPainter(this.slices);
  final List<({Color color, double share})> slices;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = slice.share * math.pi * 2;
      canvas.drawArc(
        rect.deflate(13),
        start,
        sweep,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 23,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _AllocationPainter oldDelegate) => true;
}
