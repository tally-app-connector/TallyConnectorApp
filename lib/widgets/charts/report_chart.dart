import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../screens/theme/app_theme.dart';
import '../../models/report_data.dart';
import '../../utils/amount_formatter.dart';
import '../../utils/chart_period_helper.dart';

// ─────────────────────────────────────────────
//  REPORT CHART (generic bar/line/area/pie)
// ─────────────────────────────────────────────
class ReportChart extends StatelessWidget {
  final ReportChartData data;
  final double height;

  const ReportChart({
    Key? key,
    required this.data,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.dataPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data for selected period',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    switch (data.chartType) {
      case ReportChartType.bar:
        return _buildBarChart();
      case ReportChartType.horizontalBar:
        return _buildHorizontalBarChart();
      case ReportChartType.line:
        return _buildLineChart();
      case ReportChartType.area:
        return _buildAreaChart();
      case ReportChartType.pie:
        return _buildPieChart();
      case ReportChartType.scatter:
        return _buildScatterChart();
      case ReportChartType.stepLine:
        return _buildStepLineChart();
      case ReportChartType.rangeLine:
        return _buildRangeLineChart();
      case ReportChartType.gradientBar:
        return _buildGradientBarChart();
      case ReportChartType.lollipop:
        return _buildLollipopChart();
      case ReportChartType.candlestick:
        return _buildCandlestickChart();
    }
  }

  Widget _buildBarChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data for selected period',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);
    final defaultColor =
        data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;

    final n = data.dataPoints.length;
    final barWidth = n <= 5 ? 24.0 : (n <= 8 ? 16.0 : (n <= 14 ? 10.0 : 6.0));

    final hasMultipleColors = data.legends.length > 1 &&
        data.legends.length == data.dataPoints.length;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble(),
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1A1A2E),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = data.dataPoints[groupIndex];
                return BarTooltipItem(
                  '${point.label}\n',
                  AppTypography.chartTooltipLabel,
                  children: [
                    TextSpan(
                      text: AmountFormatter.shortSpaced(point.value),
                      style: AppTypography.chartTooltipValue,
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.dataPoints.length) {
                    return const SizedBox.shrink();
                  }
                  // Skip alternate labels when too many bars
                  final n = data.dataPoints.length;
                  final step = n > 10 ? 2 : 1;
                  if (n > 10 && index % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return Transform.translate(
                    offset: const Offset(-5, 12),
                    child: Transform.rotate(
                      angle: -0.60,
                      child: Text(
                        _formatLabel(data.dataPoints[index].label),
                        style: AppTypography.chartAxisLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
                reservedSize: 75,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  if (value > adjustedMaxY + 0.01)
                    return const SizedBox.shrink();
                  if (value % niceInterval != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      AmountFormatter.short(value),
                      style: AppTypography.chartAxisLabel,
                      maxLines: 1,
                    ),
                  );
                },
                reservedSize: 58,
                interval: niceInterval,
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
              left: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: niceInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFFBFC3CA),
              strokeWidth: 0.8,
              dashArray: [5, 3],
            ),
          ),
          barGroups: data.dataPoints.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final barColor =
                hasMultipleColors ? data.legends[index].color : defaultColor;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: point.value.abs(),
                  color: barColor,
                  width: barWidth,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  static String _formatLabel(String label) => formatChartLabel(label);

  /// Compute a "nice" Y-axis interval for fl_chart grid lines.
  static double _chartNiceInterval(double maxVal) {
    if (maxVal <= 0) return 1;
    final rough = maxVal / 4;
    final exp = (rough.abs()).toString().split('.').first.length - 1;
    double mag = 1;
    for (int i = 0; i < exp; i++) mag *= 10;
    final normalized = rough / mag;
    if (normalized <= 1) return mag;
    if (normalized <= 2) return 2 * mag;
    if (normalized <= 5) return 5 * mag;
    return 10 * mag;
  }

  Widget _buildLineChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data for selected period',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);
    final lineColor =
        data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;

    final spots = data.dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.abs());
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1A1A2E),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final label = index >= 0 && index < data.dataPoints.length
                        ? _formatLabel(data.dataPoints[index].label)
                        : '';
                    return LineTooltipItem(
                      '$label\n${AmountFormatter.shortSpaced(spot.y)}',
                      AppTypography.chartTooltipValue,
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= data.dataPoints.length) {
                      return const SizedBox.shrink();
                    }
                    if (value != index.toDouble())
                      return const SizedBox.shrink();
                    // Skip alternate labels when too many bars
                    final n = data.dataPoints.length;
                    if (n > 10 && index % 2 != 0) {
                      return const SizedBox.shrink();
                    }
                    return Transform.translate(
                      offset: const Offset(-5, 12),
                      child: Transform.rotate(
                        angle: -0.60,
                        child: Text(
                          _formatLabel(data.dataPoints[index].label),
                          style: AppTypography.chartAxisLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                  reservedSize: 75,
                  interval: 1,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    if (value > adjustedMaxY + 0.01)
                      return const SizedBox.shrink();
                    if (value % niceInterval != 0)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        AmountFormatter.short(value),
                        style: AppTypography.chartAxisLabel,
                        maxLines: 1,
                      ),
                    );
                  },
                  reservedSize: 58,
                  interval: niceInterval,
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
                left: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: niceInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFFBFC3CA),
                strokeWidth: 0.8,
                dashArray: [5, 3],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: lineColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: lineColor,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: lineColor.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  Widget _buildAreaChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);
    final areaColor =
        data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;

    final spots = data.dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.abs());
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1A1A2E),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final label = index >= 0 && index < data.dataPoints.length
                        ? _formatLabel(data.dataPoints[index].label)
                        : '';
                    return LineTooltipItem(
                      '$label\n${AmountFormatter.shortSpaced(spot.y)}',
                      AppTypography.chartTooltipValue,
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: _buildTitlesData(adjustedMaxY, niceInterval),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
                left: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: niceInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFFBFC3CA),
                  strokeWidth: 0.8,
                  dashArray: [5, 3]),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: areaColor,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      areaColor.withValues(alpha: 0.4),
                      areaColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  Widget _buildHorizontalBarChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxX = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxX = adjustedMaxX + (adjustedMaxX * 0.02);
    final defaultColor =
        data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;
    final hasMultipleColors = data.legends.length > 1 &&
        data.legends.length == data.dataPoints.length;
    final n = data.dataPoints.length;
    final barWidth = n <= 5 ? 20.0 : (n <= 8 ? 14.0 : (n <= 14 ? 10.0 : 6.0));

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: RotatedBox(
          quarterTurns: 1,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxX.toDouble(),
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1A1A2E),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = data.dataPoints[groupIndex];
                    return BarTooltipItem(
                      '${_formatLabel(point.label)}\n${AmountFormatter.shortSpaced(point.value)}',
                      AppTypography.chartTooltipValue,
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.dataPoints.length)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: Text(
                            _formatLabel(data.dataPoints[index].label),
                            style: AppTypography.chartAxisLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                    reservedSize: 80,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      if (value > adjustedMaxX + 0.01)
                        return const SizedBox.shrink();
                      if (value % niceInterval != 0)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: Text(
                            AmountFormatter.short(value),
                            style: AppTypography.chartAxisLabel,
                          ),
                        ),
                      );
                    },
                    reservedSize: 50,
                    interval: niceInterval,
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                  left: BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: niceInterval,
                getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFBFC3CA),
                    strokeWidth: 0.8,
                    dashArray: [5, 3]),
              ),
              barGroups: data.dataPoints.asMap().entries.map((entry) {
                final index = entry.key;
                final point = entry.value;
                final barColor = hasMultipleColors
                    ? data.legends[index].color
                    : defaultColor;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: point.value.abs(),
                      color: barColor,
                      width: barWidth,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final total =
        data.dataPoints.fold<double>(0, (p, dp) => p + dp.value.abs());
    if (total == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final colors = [
      AppColors.blue,
      AppColors.green,
      AppColors.amber,
      AppColors.red,
      AppColors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lime,
      Colors.brown
    ];

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (event, response) {},
                ),
                sections: data.dataPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  final color = colors[index % colors.length];
                  final pct = point.value.abs() / total * 100;
                  final percentage = pct.toStringAsFixed(1);
                  return PieChartSectionData(
                    color: color,
                    value: point.value.abs(),
                    title: pct >= 9 ? '$percentage%' : '',
                    titleStyle: AppTypography.chartPieLabel.copyWith(fontSize: 8),
                    radius: height / 4,
                    titlePositionPercentageOffset: 0.45,
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SizedBox(
              height: height,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.dataPoints.asMap().entries.map((entry) {
                    final color = colors[entry.key % colors.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${_formatLabel(entry.value.label)} ${AmountFormatter.short(entry.value.value)}',
                              style: AppTypography.chartLegendLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared titles config for line/area charts.
  FlTitlesData _buildTitlesData(double adjustedMaxY, double niceInterval) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= data.dataPoints.length)
              return const SizedBox.shrink();
            if (value != index.toDouble()) return const SizedBox.shrink();
            return Transform.translate(
              offset: const Offset(-5, 12),
              child: Transform.rotate(
                angle: -0.60,
                child: Text(
                  _formatLabel(data.dataPoints[index].label),
                  style: AppTypography.chartAxisLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
          reservedSize: 75,
          interval: 1,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            if (value > adjustedMaxY + 0.01) return const SizedBox.shrink();
            if (value % niceInterval != 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                AmountFormatter.short(value),
                style: AppTypography.chartAxisLabel,
                maxLines: 1,
              ),
            );
          },
          reservedSize: 58,
          interval: niceInterval,
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // ── SCATTER CHART ─────────────────────────────────────────────────────────

  Widget _buildScatterChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);
    final defaultColor =
        data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;
    final hasMultipleColors = data.legends.length > 1 &&
        data.legends.length == data.dataPoints.length;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        height: height,
        child: ScatterChart(
          ScatterChartData(
            maxY: maxY,
            minY: 0,
            maxX: (data.dataPoints.length - 1).toDouble() + 0.5,
            minX: -0.5,
            scatterTouchData: ScatterTouchData(
              enabled: true,
              touchTooltipData: ScatterTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => const Color(0xFF1A1A2E),
                getTooltipItems: (touchedSpot) {
                  final index = touchedSpot.x.toInt();
                  final label = index >= 0 && index < data.dataPoints.length
                      ? _formatLabel(data.dataPoints[index].label)
                      : '';
                  return ScatterTooltipItem(
                    '$label\n${AmountFormatter.shortSpaced(touchedSpot.y)}',
                    textStyle: AppTypography.chartTooltipValue,
                  );
                },
              ),
            ),
            titlesData: _buildTitlesData(adjustedMaxY, niceInterval),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
                left: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: niceInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFFBFC3CA),
                strokeWidth: 0.8,
                dashArray: [5, 3],
              ),
            ),
            scatterSpots: data.dataPoints.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;
              final dotColor = hasMultipleColors
                  ? data.legends[index].color
                  : defaultColor;
              final normalizedRadius =
                  4 + (point.value.abs() / rawMaxY) * 12;
              return ScatterSpot(
                index.toDouble(),
                point.value.abs(),
                dotPainter: FlDotCirclePainter(
                  radius: normalizedRadius,
                  color: dotColor.withValues(alpha: 0.7),
                  strokeWidth: 2,
                  strokeColor: dotColor,
                ),
              );
            }).toList(),
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  // ── STEP LINE CHART ───────────────────────────────────────────────────────

  Widget _buildStepLineChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);
    final lineColor =
        data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;

    final spots = data.dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.abs());
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => const Color(0xFF1A1A2E),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final label = index >= 0 && index < data.dataPoints.length
                        ? _formatLabel(data.dataPoints[index].label)
                        : '';
                    return LineTooltipItem(
                      '$label\n${AmountFormatter.shortSpaced(spot.y)}',
                      AppTypography.chartTooltipValue,
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: _buildTitlesData(adjustedMaxY, niceInterval),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
                left: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: niceInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFFBFC3CA),
                strokeWidth: 0.8,
                dashArray: [5, 3],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                isStepLineChart: true,
                color: lineColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: lineColor,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withValues(alpha: 0.3),
                      lineColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  // ── RANGE LINE CHART ──────────────────────────────────────────────────────

  static const _rangeHighColor = AppColors.green;
  static const _rangeMedColor = Color(0xFFF59E0B);
  static const _rangeLowColor = AppColors.red;

  Color _rangeColor(double value, double maxVal) {
    final ratio = maxVal > 0 ? value / maxVal : 0.0;
    if (ratio >= 0.66) return _rangeHighColor;
    if (ratio >= 0.33) return _rangeMedColor;
    return _rangeLowColor;
  }

  Widget _buildRangeLineChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);

    final highThreshold = rawMaxY * 0.66;
    final medThreshold = rawMaxY * 0.33;

    final spots = data.dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.abs());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: SizedBox(
            height: height,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => const Color(0xFF1A1A2E),
                    getTooltipItems: (touchedSpots) {
                      bool shown = false;
                      return touchedSpots.map((spot) {
                        if (shown) return null;
                        if (spot.barIndex != touchedSpots.last.barIndex) return null;
                        shown = true;
                        final index = spot.x.toInt();
                        final label = index >= 0 && index < data.dataPoints.length
                            ? _formatLabel(data.dataPoints[index].label)
                            : '';
                        final val = spot.y;
                        final level = val >= highThreshold
                            ? 'High'
                            : (val >= medThreshold ? 'Medium' : 'Low');
                        return LineTooltipItem(
                          '$label\n${AmountFormatter.shortSpaced(val)} ($level)',
                          AppTypography.chartTooltipValue,
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: _buildTitlesData(adjustedMaxY, niceInterval),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 0.5),
                    left: BorderSide(color: AppColors.divider, width: 0.5),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: niceInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFBFC3CA),
                    strokeWidth: 0.8,
                    dashArray: [5, 3],
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: highThreshold,
                      color: _rangeHighColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(fontSize: 8, color: _rangeHighColor, fontWeight: FontWeight.w600),
                        labelResolver: (_) => 'High',
                      ),
                    ),
                    HorizontalLine(
                      y: medThreshold,
                      color: _rangeMedColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(fontSize: 8, color: _rangeMedColor, fontWeight: FontWeight.w600),
                        labelResolver: (_) => 'Medium',
                      ),
                    ),
                  ],
                ),
                lineBarsData: [
                  for (int i = 0; i < spots.length - 1; i++)
                    LineChartBarData(
                      spots: [spots[i], spots[i + 1]],
                      isCurved: false,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      color: _rangeColor(
                        (spots[i].y + spots[i + 1].y) / 2,
                        rawMaxY,
                      ),
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final dotColor = _rangeColor(spot.y, rawMaxY);
                        return FlDotCirclePainter(
                          radius: 5,
                          color: dotColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.blue.withValues(alpha: 0.06),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _rangeLegendDot(_rangeHighColor, 'High'),
            const SizedBox(width: 16),
            _rangeLegendDot(_rangeMedColor, 'Medium'),
            const SizedBox(width: 16),
            _rangeLegendDot(_rangeLowColor, 'Low'),
          ],
        ),
      ],
    );
  }

  Widget _rangeLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.chartLegendLabel),
      ],
    );
  }

  // ── GRADIENT BAR CHART ────────────────────────────────────────────────────

  Widget _buildGradientBarChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);
    final defaultColor =
        data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;

    final n = data.dataPoints.length;
    final barWidth = n <= 5 ? 24.0 : (n <= 8 ? 16.0 : (n <= 14 ? 10.0 : 6.0));

    final hasMultipleColors = data.legends.length > 1 &&
        data.legends.length == data.dataPoints.length;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble(),
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) => const Color(0xFF1A1A2E),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = data.dataPoints[groupIndex];
                return BarTooltipItem(
                  '${point.label}\n',
                  AppTypography.chartTooltipLabel,
                  children: [
                    TextSpan(
                      text: AmountFormatter.shortSpaced(point.value),
                      style: AppTypography.chartTooltipValue,
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.dataPoints.length) {
                    return const SizedBox.shrink();
                  }
                  final step = n > 10 ? 2 : 1;
                  if (n > 10 && index % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return Transform.translate(
                    offset: const Offset(-5, 12),
                    child: Transform.rotate(
                      angle: -0.60,
                      child: Text(
                        _formatLabel(data.dataPoints[index].label),
                        style: AppTypography.chartAxisLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
                reservedSize: 75,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  if (value > adjustedMaxY + 0.01) return const SizedBox.shrink();
                  if (value % niceInterval != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      AmountFormatter.short(value),
                      style: AppTypography.chartAxisLabel,
                      maxLines: 1,
                    ),
                  );
                },
                reservedSize: 58,
                interval: niceInterval,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
              left: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: niceInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFFBFC3CA),
              strokeWidth: 0.8,
              dashArray: [5, 3],
            ),
          ),
          barGroups: data.dataPoints.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final baseColor =
                hasMultipleColors ? data.legends[index].color : defaultColor;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: point.value.abs(),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      baseColor,
                      baseColor.withValues(alpha: 0.3),
                    ],
                  ),
                  width: barWidth,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  // ── LOLLIPOP CHART ────────────────────────────────────────────────────────

  Widget _buildLollipopChart() {
    final rawMaxY = data.dataPoints
        .fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);
    final defaultColor =
        data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;
    final hasMultipleColors = data.legends.length > 1 &&
        data.legends.length == data.dataPoints.length;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble(),
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) => const Color(0xFF1A1A2E),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = data.dataPoints[groupIndex];
                return BarTooltipItem(
                  '${point.label}\n',
                  AppTypography.chartTooltipLabel,
                  children: [
                    TextSpan(
                      text: AmountFormatter.shortSpaced(point.value),
                      style: AppTypography.chartTooltipValue,
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.dataPoints.length) {
                    return const SizedBox.shrink();
                  }
                  final n = data.dataPoints.length;
                  final step = n > 10 ? 2 : 1;
                  if (n > 10 && index % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return Transform.translate(
                    offset: const Offset(-5, 12),
                    child: Transform.rotate(
                      angle: -0.60,
                      child: Text(
                        _formatLabel(data.dataPoints[index].label),
                        style: AppTypography.chartAxisLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
                reservedSize: 75,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  if (value > adjustedMaxY + 0.01) return const SizedBox.shrink();
                  if (value % niceInterval != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      AmountFormatter.short(value),
                      style: AppTypography.chartAxisLabel,
                      maxLines: 1,
                    ),
                  );
                },
                reservedSize: 58,
                interval: niceInterval,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
              left: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: niceInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFFBFC3CA),
              strokeWidth: 0.8,
              dashArray: [5, 3],
            ),
          ),
          barGroups: data.dataPoints.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final color =
                hasMultipleColors ? data.legends[index].color : defaultColor;
            final val = point.value.abs();
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: color.withValues(alpha: 0.5),
                  width: 2,
                  borderRadius: BorderRadius.zero,
                ),
                BarChartRodData(
                  fromY: val > (maxY * 0.03) ? val - (maxY * 0.03) : 0,
                  toY: val,
                  color: color,
                  width: 14,
                  borderRadius: BorderRadius.circular(7),
                ),
              ],
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  // ── CANDLESTICK CHART ─────────────────────────────────────────────────────

  Widget _buildCandlestickChart() {
    if (data.dataPoints.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('Not enough data for candlestick',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final candles = <_CandleData>[];
    for (int i = 0; i < data.dataPoints.length; i++) {
      final open = i > 0 ? data.dataPoints[i - 1].value.abs() : data.dataPoints[i].value.abs();
      final close = data.dataPoints[i].value.abs();
      final spread = (open - close).abs() * 0.3;
      final high = (open > close ? open : close) + spread;
      final low = ((open < close ? open : close) - spread).clamp(0.0, double.infinity);
      candles.add(_CandleData(
        label: data.dataPoints[i].label,
        open: open,
        close: close,
        high: high,
        low: low,
      ));
    }

    double rawMaxY = 0;
    for (final c in candles) {
      if (c.high > rawMaxY) rawMaxY = c.high;
    }
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _chartNiceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);

    final n = candles.length;
    final bodyWidth = n <= 5 ? 16.0 : (n <= 8 ? 12.0 : (n <= 14 ? 8.0 : 5.0));

    return Column(
      children: [
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => const Color(0xFF1A1A2E),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (rodIndex != 1) return null;
                    final c = candles[groupIndex];
                    return BarTooltipItem(
                      '${_formatLabel(c.label)}\n',
                      AppTypography.chartTooltipLabel,
                      children: [
                        TextSpan(
                          text: AmountFormatter.shortSpaced(c.close),
                          style: AppTypography.chartTooltipValue,
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= candles.length) {
                        return const SizedBox.shrink();
                      }
                      final step = n > 10 ? 2 : 1;
                      if (n > 10 && index % step != 0) {
                        return const SizedBox.shrink();
                      }
                      return Transform.translate(
                        offset: const Offset(-5, 12),
                        child: Transform.rotate(
                          angle: -0.60,
                          child: Text(
                            _formatLabel(candles[index].label),
                            style: AppTypography.chartAxisLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                    reservedSize: 75,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      if (value > adjustedMaxY + 0.01) return const SizedBox.shrink();
                      if (value % niceInterval != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          AmountFormatter.short(value),
                          style: AppTypography.chartAxisLabel,
                          maxLines: 1,
                        ),
                      );
                    },
                    reservedSize: 58,
                    interval: niceInterval,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                  left: BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: niceInterval,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFFBFC3CA),
                  strokeWidth: 0.8,
                  dashArray: [5, 3],
                ),
              ),
              barGroups: candles.asMap().entries.map((entry) {
                final index = entry.key;
                final c = entry.value;
                final isUp = c.close >= c.open;
                final bodyColor = isUp ? AppColors.green : AppColors.red;
                final wickColor = bodyColor.withValues(alpha: 0.6);
                final minBody = maxY * 0.015;
                var bodyTop = isUp ? c.close : c.open;
                var bodyBottom = isUp ? c.open : c.close;
                if ((bodyTop - bodyBottom) < minBody) {
                  bodyTop = c.close + minBody / 2;
                  bodyBottom = c.close - minBody / 2;
                  if (bodyBottom < 0) bodyBottom = 0;
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      fromY: c.low,
                      toY: c.high,
                      color: wickColor,
                      width: 1.5,
                      borderRadius: BorderRadius.zero,
                    ),
                    BarChartRodData(
                      fromY: bodyBottom,
                      toY: bodyTop,
                      color: bodyColor,
                      width: bodyWidth,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ],
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 4),
            Text('Up', style: AppTypography.chartLegendLabel),
            const SizedBox(width: 16),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 4),
            Text('Down', style: AppTypography.chartLegendLabel),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  CANDLESTICK DATA MODEL
// ─────────────────────────────────────────────
class _CandleData {
  final String label;
  final double open;
  final double close;
  final double high;
  final double low;

  const _CandleData({
    required this.label,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
  });
}

// ─────────────────────────────────────────────
//  SALES PURCHASE COMBO CHART
// ─────────────────────────────────────────────
class SalesPurchaseComboChart extends StatelessWidget {
  final SalesPurchaseChartData data;
  final double height;
  final ReportChartType chartType;

  const SalesPurchaseComboChart({
    Key? key,
    required this.data,
    this.height = 220,
    this.chartType = ReportChartType.bar,
  }) : super(key: key);

  static double _niceInterval(double maxVal) {
    if (maxVal <= 0) return 1;
    final rough = maxVal / 4;
    final exp = (rough.abs()).toString().split('.').first.length - 1;
    double mag = 1;
    for (int i = 0; i < exp; i++) mag *= 10;
    final normalized = rough / mag;
    if (normalized <= 1) return mag;
    if (normalized <= 2) return 2 * mag;
    if (normalized <= 5) return 5 * mag;
    return 10 * mag;
  }

  static String _formatLabel(String label) => formatChartLabel(label);

  @override
  Widget build(BuildContext context) {
    if (data.dataPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data for selected period',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final rawMaxY = data.dataPoints.fold<double>(
      0,
      (prev, dp) => [prev, dp.salesValue.abs(), dp.purchaseValue.abs()]
          .reduce((a, b) => a > b ? a : b),
    );
    if (rawMaxY == 0) {
      return SizedBox(
        height: height,
        child: Center(
            child: Text('No data for selected period',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final niceInterval = _niceInterval(rawMaxY);
    final adjustedMaxY = (rawMaxY / niceInterval).ceil() * niceInterval;
    final maxY = adjustedMaxY + (adjustedMaxY * 0.02);

    final Widget chartWidget;
    switch (chartType) {
      case ReportChartType.line:
        chartWidget = _buildLineChart(maxY, adjustedMaxY, niceInterval);
        break;
      case ReportChartType.area:
        chartWidget = _buildAreaChart(maxY, adjustedMaxY, niceInterval);
        break;
      case ReportChartType.pie:
        return _buildPieChart();
      case ReportChartType.horizontalBar:
        chartWidget =
            _buildHorizontalBarChart(maxY, adjustedMaxY, niceInterval);
        break;
      default:
        chartWidget = _buildBarChart(maxY, adjustedMaxY, niceInterval);
        break;
    }

    return Column(
      children: [
        SizedBox(height: height, child: chartWidget),
        const SizedBox(height: 12),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text('Sales', style: AppTypography.chartLegendLabel),
            const SizedBox(width: 16),
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text('Purchase', style: AppTypography.chartLegendLabel),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart(double maxY, double adjustedMaxY, double niceInterval) {
    final n = data.dataPoints.length;
    final barWidth = n <= 5 ? 12.0 : (n <= 8 ? 8.0 : (n <= 14 ? 6.0 : 4.0));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY.toDouble(),
        minY: 0,
        groupsSpace: 12,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A1A2E),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final dp = data.dataPoints[groupIndex];
              final label = _formatLabel(dp.label);
              final isSales = rodIndex == 0;
              final value = isSales ? dp.salesValue : dp.purchaseValue;
              return BarTooltipItem(
                '$label\n${isSales ? "Sales" : "Purchase"}: ${AmountFormatter.shortSpaced(value.abs())}',
                AppTypography.chartTooltipValue,
              );
            },
          ),
        ),
        titlesData: _comboBarTitlesData(adjustedMaxY, niceInterval),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
            left: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: niceInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFBFC3CA),
            strokeWidth: 0.8,
            dashArray: [5, 3],
          ),
        ),
        barGroups: data.dataPoints.asMap().entries.map((entry) {
          final dp = entry.value;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: dp.salesValue.abs(),
                color: AppColors.blue,
                width: barWidth,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(3),
                ),
              ),
              BarChartRodData(
                toY: dp.purchaseValue.abs(),
                color: AppColors.amber,
                width: barWidth,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(3),
                ),
              ),
            ],
          );
        }).toList(),
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildLineChart(
      double maxY, double adjustedMaxY, double niceInterval) {
    final salesSpots = data.dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.salesValue.abs());
    }).toList();
    final purchaseSpots = data.dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.purchaseValue.abs());
    }).toList();

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A1A2E),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final label = index >= 0 && index < data.dataPoints.length
                    ? _formatLabel(data.dataPoints[index].label)
                    : '';
                final isSales = spot.barIndex == 0;
                return LineTooltipItem(
                  '$label\n${isSales ? "Sales" : "Purchase"}: ${AmountFormatter.shortSpaced(spot.y)}',
                  AppTypography.chartTooltipValue,
                );
              }).toList();
            },
          ),
        ),
        titlesData: _buildLineTitlesData(adjustedMaxY, niceInterval),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
            left: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: niceInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFBFC3CA),
            strokeWidth: 0.8,
            dashArray: [5, 3],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: salesSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.blue,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppColors.blue,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: purchaseSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.amber,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppColors.amber,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildAreaChart(
      double maxY, double adjustedMaxY, double niceInterval) {
    final salesSpots = data.dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.salesValue.abs());
    }).toList();
    final purchaseSpots = data.dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.purchaseValue.abs());
    }).toList();

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A1A2E),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final label = index >= 0 && index < data.dataPoints.length
                    ? _formatLabel(data.dataPoints[index].label)
                    : '';
                final isSales = spot.barIndex == 0;
                return LineTooltipItem(
                  '$label\n${isSales ? "Sales" : "Purchase"}: ${AmountFormatter.shortSpaced(spot.y)}',
                  AppTypography.chartTooltipValue,
                );
              }).toList();
            },
          ),
        ),
        titlesData: _buildLineTitlesData(adjustedMaxY, niceInterval),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
            left: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: niceInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFBFC3CA),
            strokeWidth: 0.8,
            dashArray: [5, 3],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: salesSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.blue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.blue.withValues(alpha: 0.3),
                  AppColors.blue.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          LineChartBarData(
            spots: purchaseSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.amber,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.amber.withValues(alpha: 0.3),
                  AppColors.amber.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildHorizontalBarChart(
      double maxY, double adjustedMaxY, double niceInterval) {
    final n = data.dataPoints.length;
    final barWidth = n <= 5 ? 10.0 : (n <= 8 ? 7.0 : (n <= 14 ? 5.0 : 3.5));

    return RotatedBox(
      quarterTurns: 1,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble(),
          minY: 0,
          groupsSpace: 12,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1A1A2E),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dp = data.dataPoints[groupIndex];
                final label = _formatLabel(dp.label);
                final isSales = rodIndex == 0;
                final value = isSales ? dp.salesValue : dp.purchaseValue;
                return BarTooltipItem(
                  '$label\n${isSales ? "Sales" : "Purchase"}: ${AmountFormatter.shortSpaced(value.abs())}',
                  AppTypography.chartTooltipValue,
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.dataPoints.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: Text(
                        _formatLabel(data.dataPoints[index].label),
                        style: AppTypography.chartAxisLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
                reservedSize: 80,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  if (value > adjustedMaxY + 0.01)
                    return const SizedBox.shrink();
                  if (value % niceInterval != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: Text(
                        AmountFormatter.short(value),
                        style: AppTypography.chartAxisLabel,
                      ),
                    ),
                  );
                },
                reservedSize: 55,
                interval: niceInterval,
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
              left: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: niceInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFFBFC3CA),
              strokeWidth: 0.8,
              dashArray: [5, 3],
            ),
          ),
          barGroups: data.dataPoints.asMap().entries.map((entry) {
            final dp = entry.value;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: dp.salesValue.abs(),
                  color: AppColors.blue,
                  width: barWidth,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
                BarChartRodData(
                  toY: dp.purchaseValue.abs(),
                  color: AppColors.amber,
                  width: barWidth,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildPieChart() {
    final totalSales =
        data.dataPoints.fold<double>(0, (p, dp) => p + dp.salesValue.abs());
    final totalPurchase =
        data.dataPoints.fold<double>(0, (p, dp) => p + dp.purchaseValue.abs());
    final total = totalSales + totalPurchase;

    if (total == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data for selected period',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final salesPercent = (totalSales / total * 100).toStringAsFixed(1);
    final purchasePercent = (totalPurchase / total * 100).toStringAsFixed(1);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (event, response) {},
                ),
                sections: [
                  PieChartSectionData(
                    color: AppColors.blue,
                    value: totalSales,
                    title: '$salesPercent%',
                    titleStyle: AppTypography.chartPieLabel,
                    radius: height / 4,
                  ),
                  PieChartSectionData(
                    color: AppColors.amber,
                    value: totalPurchase,
                    title: '$purchasePercent%',
                    titleStyle: AppTypography.chartPieLabel,
                    radius: height / 4,
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text('Sales', style: AppTypography.chartLegendLabel),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AmountFormatter.shortSpaced(totalSales),
                style: AppTypography.chartLegendValue,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text('Purchase', style: AppTypography.chartLegendLabel),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AmountFormatter.shortSpaced(totalPurchase),
                style: AppTypography.chartLegendValue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  FlTitlesData _comboBarTitlesData(double adjustedMaxY, double niceInterval) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= data.dataPoints.length) {
              return const SizedBox.shrink();
            }
            return Transform.translate(
              offset: const Offset(-5, 12),
              child: Transform.rotate(
                angle: -0.60,
                child: Text(
                  _formatLabel(data.dataPoints[index].label),
                  style: AppTypography.chartAxisLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
          reservedSize: 75,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            if (value > adjustedMaxY + 0.01) return const SizedBox.shrink();
            if (value % niceInterval != 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                AmountFormatter.short(value),
                style: AppTypography.chartAxisLabel,
                maxLines: 1,
              ),
            );
          },
          reservedSize: 58,
          interval: niceInterval,
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlTitlesData _buildLineTitlesData(double adjustedMaxY, double niceInterval) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= data.dataPoints.length) {
              return const SizedBox.shrink();
            }
            if (value != index.toDouble()) return const SizedBox.shrink();
            return Transform.translate(
              offset: const Offset(-5, 12),
              child: Transform.rotate(
                angle: -0.60,
                child: Text(
                  _formatLabel(data.dataPoints[index].label),
                  style: AppTypography.chartAxisLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
          reservedSize: 75,
          interval: 1,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            if (value > adjustedMaxY + 0.01) return const SizedBox.shrink();
            if (value % niceInterval != 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                AmountFormatter.short(value),
                style: AppTypography.chartAxisLabel,
                maxLines: 1,
              ),
            );
          },
          reservedSize: 58,
          interval: niceInterval,
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}

// ─────────────────────────────────────────────
//  CHART LOADING PLACEHOLDER
// ─────────────────────────────────────────────
class ChartShimmerPlaceholder extends StatelessWidget {
  final double height;

  const ChartShimmerPlaceholder({Key? key, this.height = 200})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.blue,
          ),
        ),
      ),
    );
  }
}
