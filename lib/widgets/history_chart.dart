import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/price_history.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart' as format;

class HistoryChart extends StatefulWidget {
  const HistoryChart({
    super.key,
    required this.points,
    this.height = 180,
    this.showDates = true,
    this.valueLabel = 'Preço',
  });

  final List<PriceHistoryPoint> points;
  final double height;
  final bool showDates;
  final String valueLabel;

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  final _focus = FocusNode();
  PriceHistoryPoint? _selectedPoint;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _selectAt(Offset touch, Size size, _ChartSeries series) {
    _focus.requestFocus();
    final plot = _plotRect(
      size,
      widget.showDates,
      MediaQuery.textScalerOf(context),
    );
    final selected = series.valid.reduce((a, b) {
      final positionA = series.position(a, plot);
      final positionB = series.position(b, plot);
      final distanceA = (positionA.dx - touch.dx).abs();
      final distanceB = (positionB.dx - touch.dx).abs();
      if (distanceA == distanceB) {
        return (positionA.dy - touch.dy).abs() <=
                (positionB.dy - touch.dy).abs()
            ? a
            : b;
      }
      return distanceA < distanceB ? a : b;
    });
    setState(() => _selectedPoint = selected);
  }

  int _nextIndex(int direction, _ChartSeries series) {
    final index = _selectedPoint == null
        ? -1
        : series.valid.indexOf(_selectedPoint!);
    return index < 0
        ? (direction > 0 ? 0 : series.valid.length - 1)
        : (index + direction).clamp(0, series.valid.length - 1).toInt();
  }

  void _step(int direction, _ChartSeries series) {
    final next = _nextIndex(direction, series);
    setState(() => _selectedPoint = series.valid[next]);
  }

  @override
  Widget build(BuildContext context) {
    final series = _ChartSeries(widget.points);
    if (series.valid.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Sem preços no período',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
      );
    }
    final selected = series.valid.contains(_selectedPoint)
        ? _selectedPoint
        : null;
    final textScaler = MediaQuery.textScalerOf(context);
    final largeText = textScaler.scale(12) > 18;
    String recordLabel(PriceHistoryPoint point) =>
        '${format.dateTimeLabel(point.time)}. ${widget.valueLabel}: ${format.brl(point.close)}';
    final summary = selected == null
        ? '${series.valid.length} registros disponíveis'
        : recordLabel(selected);

    return Semantics(
      container: true,
      label: 'Histórico de ${widget.valueLabel.toLowerCase()}',
      value: summary,
      increasedValue: recordLabel(series.valid[_nextIndex(1, series)]),
      decreasedValue: recordLabel(series.valid[_nextIndex(-1, series)]),
      hint:
          'Toque ou arraste para consultar. Use as setas para percorrer os registros.',
      onIncrease: () => _step(1, series),
      onDecrease: () => _step(-1, series),
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowRight): _StepHistoryIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _StepHistoryIntent(-1),
        },
        child: Actions(
          actions: {
            _StepHistoryIntent: CallbackAction<_StepHistoryIntent>(
              onInvoke: (intent) {
                _step(intent.direction, series);
                return null;
              },
            ),
          },
          child: Focus(
            focusNode: _focus,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: widget.height,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, widget.height);
                      final plot = _plotRect(
                        size,
                        widget.showDates,
                        textScaler,
                      );
                      final tooltipWidth = math.min(214.0, size.width);
                      final tooltipLeft = selected == null
                          ? 0.0
                          : (series.position(selected, plot).dx -
                                    tooltipWidth / 2)
                                .clamp(
                                  0.0,
                                  math.max(0.0, size.width - tooltipWidth),
                                )
                                .toDouble();
                      return GestureDetector(
                        key: const ValueKey('history-chart-touch-target'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) =>
                            _selectAt(details.localPosition, size, series),
                        onHorizontalDragStart: (details) =>
                            _selectAt(details.localPosition, size, series),
                        onHorizontalDragUpdate: (details) =>
                            _selectAt(details.localPosition, size, series),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: ExcludeSemantics(
                                child: CustomPaint(
                                  painter: _HistoryPainter(
                                    series: series,
                                    selected: selected,
                                    showDates: widget.showDates,
                                    textScaler: textScaler,
                                  ),
                                ),
                              ),
                            ),
                            if (selected != null && !largeText)
                              Positioned(
                                left: tooltipLeft,
                                top: 0,
                                width: tooltipWidth,
                                child: ExcludeSemantics(
                                  child: IgnorePointer(
                                    child: Container(
                                      key: const ValueKey(
                                        'history-chart-tooltip',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.raised,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            format.dateTimeLabel(selected.time),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.muted,
                                                ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${widget.valueLabel}: ${format.brl(selected.close)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: AppColors.accent,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (selected != null && largeText) ...[
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: Container(
                      key: const ValueKey('history-chart-tooltip'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            format.dateTimeLabel(selected.time),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.valueLabel}: ${format.brl(selected.close)}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          series.valid.length == 1
                              ? 'Um registro disponível · toque para consultar'
                              : 'Toque e arraste para consultar',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
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
    );
  }
}

class _StepHistoryIntent extends Intent {
  const _StepHistoryIntent(this.direction);
  final int direction;
}

Rect _plotRect(Size size, bool showDates, TextScaler textScaler) {
  final labelHeight = textScaler.scale(11) * 1.2;
  final labelWidth = math.min(size.width * .45, 64 * textScaler.scale(11) / 11);
  final left = math.min(4.0, size.width / 4);
  final top = math.min(size.height / 3, labelHeight / 2 + 8);
  final right = math.max(left + 1, size.width - labelWidth);
  final bottom = math.max(
    top + 1,
    size.height - (showDates ? labelHeight + 12 : 8),
  );
  return Rect.fromLTRB(left, top, right, bottom);
}

bool _hasUsablePrice(PriceHistoryPoint point) {
  final price = point.close;
  return price != null && price.isFinite && price > 0;
}

class _ChartSeries {
  _ChartSeries(List<PriceHistoryPoint> source) {
    final ordered = source.indexed.toList()
      ..sort((a, b) {
        final timeOrder = a.$2.time.compareTo(b.$2.time);
        return timeOrder == 0 ? a.$1.compareTo(b.$1) : timeOrder;
      });
    points = ordered.map((entry) => entry.$2).toList();
    valid = points.where(_hasUsablePrice).toList();
    if (valid.isEmpty) return;
    firstTime = points.first.time.microsecondsSinceEpoch;
    lastTime = points.last.time.microsecondsSinceEpoch;
    final prices = valid.map((point) => point.close!);
    final min = prices.reduce(math.min);
    final max = prices.reduce(math.max);
    magnitude = math.max(min.abs(), max.abs());
    if (magnitude == 0) magnitude = 1;
    final normalizedMin = min / magnitude;
    final normalizedMax = max / magnitude;
    final range = normalizedMax - normalizedMin;
    final padding = range == 0 ? .08 : range * .14;
    bottom = normalizedMin - padding;
    top = normalizedMax + padding;
  }

  late final List<PriceHistoryPoint> points;
  late final List<PriceHistoryPoint> valid;
  int firstTime = 0;
  int lastTime = 0;
  double magnitude = 1;
  double bottom = 0;
  double top = 1;

  Offset position(PriceHistoryPoint point, Rect plot) {
    final timeRange = lastTime - firstTime;
    final x = timeRange == 0
        ? .5
        : (point.time.microsecondsSinceEpoch - firstTime) / timeRange;
    final y = ((point.close! / magnitude - bottom) / (top - bottom)).clamp(
      0.0,
      1.0,
    );
    return Offset(plot.left + plot.width * x, plot.bottom - plot.height * y);
  }

  double gridValue(double fraction) {
    final value = (top - (top - bottom) * fraction) * magnitude;
    return value.isFinite
        ? value
        : value.isNegative
        ? -double.maxFinite
        : double.maxFinite;
  }
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.series,
    required this.selected,
    required this.showDates,
    required this.textScaler,
  });

  final _ChartSeries series;
  final PriceHistoryPoint? selected;
  final bool showDates;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || series.valid.isEmpty) return;
    final plot = _plotRect(size, showDates, textScaler);
    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: .8)
      ..strokeWidth = .7;
    for (var index = 0; index < 4; index++) {
      final fraction = index / 3;
      final y = plot.top + plot.height * fraction;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        format.compactBrl(series.gridValue(fraction)),
        Offset(plot.right + 8, y - textScaler.scale(11) * .6),
        maxWidth: math.max(0, size.width - plot.right - 8),
      );
    }

    canvas.save();
    canvas.clipRect(plot.inflate(4));
    final segments = <List<Offset>>[];
    var segment = <Offset>[];
    for (final point in series.points) {
      if (!_hasUsablePrice(point)) {
        if (segment.isNotEmpty) segments.add(segment);
        segment = <Offset>[];
      } else {
        segment.add(series.position(point, plot));
      }
    }
    if (segment.isNotEmpty) segments.add(segment);
    final stroke = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x33D8FA7A), Color(0x00D8FA7A)],
      ).createShader(plot);
    for (final points in segments) {
      if (points.length == 1) {
        canvas.drawCircle(points.first, 3.5, Paint()..color = AppColors.accent);
        continue;
      }
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        line.lineTo(point.dx, point.dy);
      }
      final area = Path.from(line)
        ..lineTo(points.last.dx, plot.bottom)
        ..lineTo(points.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(area, fill);
      canvas.drawPath(line, stroke);
    }
    if (selected != null) {
      final position = series.position(selected!, plot);
      final guide = Paint()
        ..color = AppColors.accent.withValues(alpha: .5)
        ..strokeWidth = 1;
      for (var y = plot.top; y < plot.bottom; y += 7) {
        canvas.drawLine(
          Offset(position.dx, y),
          Offset(position.dx, math.min(y + 3, plot.bottom)),
          guide,
        );
      }
      canvas.drawCircle(position, 6, Paint()..color = AppColors.surface);
      canvas.drawCircle(position, 4, Paint()..color = AppColors.accent);
    }
    canvas.restore();

    if (showDates) {
      final first = series.points.first.time.toLocal();
      final last = series.points.last.time.toLocal();
      final sameDay =
          first.year == last.year &&
          first.month == last.month &&
          first.day == last.day;
      String two(int value) => value.toString().padLeft(2, '0');
      String label(DateTime time) => sameDay
          ? '${two(time.hour)}:${two(time.minute)}'
          : '${two(time.day)}/${two(time.month)}';
      _text(
        canvas,
        label(first),
        Offset(plot.left, plot.bottom + 9),
        maxWidth: plot.width / 2,
      );
      if (first != last) {
        _text(
          canvas,
          label(last),
          Offset(plot.right, plot.bottom + 9),
          maxWidth: plot.width / 2,
          rightAligned: true,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String label,
    Offset offset, {
    required double maxWidth,
    bool rightAligned = false,
  }) {
    if (maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          height: 1.2,
          color: AppColors.muted,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(rightAligned ? offset.dx - painter.width : offset.dx, offset.dy),
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) => true;
}
