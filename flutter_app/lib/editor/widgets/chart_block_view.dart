import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// 从 ```` ```chart ```` 围栏内容解析图表定义（行式 `key: value`，
/// design D6）；无法解析返回 null（渲染回退代码样式）。
ChartSpec? parseChartSpec(String body) {
  String? type;
  String? title;
  List<String>? xLabels;
  List<double>? yValues;

  for (final rawLine in body.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final idx = line.indexOf(':');
    if (idx <= 0) return null;
    final key = line.substring(0, idx).trim().toLowerCase();
    final value = line.substring(idx + 1).trim();
    switch (key) {
      case 'type':
        type = value.toLowerCase();
      case 'title':
        title = value;
      case 'x':
        xLabels = [
          for (final part in value.split(',')) part.trim(),
        ]..removeWhere((label) => label.isEmpty);
      case 'y':
        yValues = [];
        for (final part in value.split(',')) {
          final parsed = double.tryParse(part.trim());
          if (parsed == null) return null;
          yValues.add(parsed);
        }
      default:
        return null;
    }
  }

  if (type != 'line') return null;
  if (yValues == null || yValues.isEmpty) return null;
  if (xLabels != null && xLabels.isNotEmpty && xLabels.length != yValues.length) {
    return null;
  }
  return ChartSpec(
    title: title ?? '',
    xLabels: xLabels ?? const [],
    yValues: yValues,
  );
}

/// 解析结果：标题（可空）、横轴标签（可空）与数值序列。
class ChartSpec {
  const ChartSpec({
    required this.title,
    required this.xLabels,
    required this.yValues,
  });

  final String title;
  final List<String> xLabels;
  final List<double> yValues;
}

/// ```` ```chart ```` 围栏块渲染：fl_chart 折线图；解析失败回退代码样式
/// （spec：图表块渲染）。
class ChartBlockView extends StatelessWidget {
  const ChartBlockView({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final spec = parseChartSpec(body);
    if (spec == null) return _fallback(context);
    return _lineChart(context, spec);
  }

  Widget _lineChart(BuildContext context, ChartSpec spec) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = [
      for (var i = 0; i < spec.yValues.length; i++) FlSpot(i.toDouble(), spec.yValues[i]),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (spec.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  spec.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 2.5,
                      color: colorScheme.primary,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 42),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: spec.xLabels.isNotEmpty,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) =>
                            _xTitle(spec.xLabels, value),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                      left: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 横轴标签：value 即 x 序号；越界（fl_chart 会请求边缘值）渲染为空。
  static Widget _xTitle(List<String> labels, double value) {
    final index = value.round();
    if (index < 0 || index >= labels.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        labels[index],
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        body,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

/// chart 围栏块的现行扩展注册（gpt_markdown `blockComponents`，design D6）。
///
/// 顶层 final：实例保持稳定引用，避免反复失效解析缓存（官方文档要求）。
/// 注意 closing 必须显式传 '```'（默认 ':::' 用于 ::: 围栏）。
final MarkdownBlockComponent kChartBlockComponent = MarkdownBlockComponent(
  syntax: const FencedBlockSyntax(
    type: 'chart',
    opening: '```chart',
    closing: '```',
  ),
  builder: (context, node, config) => ChartBlockView(body: node.body),
);
