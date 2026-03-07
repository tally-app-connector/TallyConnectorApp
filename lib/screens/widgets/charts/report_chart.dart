import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/report_data.dart';
import '../../utils/amount_formatter.dart';

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
          child: Text('No chart data', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    switch (data.chartType) {
      case ReportChartType.bar:
      case ReportChartType.horizontalBar:
        return _buildBarChart();
      case ReportChartType.line:
      case ReportChartType.area:
        return _buildLineChart();
      case ReportChartType.pie:
        return _buildPieChart();
    }
  }

  Widget _buildBarChart() {
    final maxVal = data.dataPoints.fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.dataPoints.map((dp) {
          final ratio = maxVal > 0 ? (dp.value.abs() / maxVal).clamp(0.0, 1.0) : 0.0;
          final color = data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(AmountFormatter.shortSpaced(dp.value),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Container(
                    width: double.infinity,
                    height: (height - 40) * ratio,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(dp.label, style: AppTypography.chartAxisLabel, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart() {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _LineChartPainter(
          data.dataPoints,
          data.legends.isNotEmpty ? data.legends.first.color : AppColors.blue,
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final total = data.dataPoints.fold<double>(0, (p, dp) => p + dp.value.abs());
    final colors = [AppColors.blue, AppColors.green, AppColors.amber, AppColors.red, AppColors.purple];

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size(height, height),
              painter: _PieChartPainter(data.dataPoints, total, colors),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.dataPoints.asMap().entries.take(5).map((entry) {
              final color = colors[entry.key % colors.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text(entry.value.label, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartDataPoint> points;
  final Color color;

  _LineChartPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxVal = points.fold<double>(0, (p, dp) => dp.value.abs() > p ? dp.value.abs() : p);
    if (maxVal == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = size.height - (points[i].value / maxVal) * size.height * 0.85;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PieChartPainter extends CustomPainter {
  final List<ChartDataPoint> points;
  final double total;
  final List<Color> colors;

  _PieChartPainter(this.points, this.total, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width.clamp(0, size.height) / 2 * 0.85;
    var startAngle = -3.14159 / 2;

    for (var i = 0; i < points.length && i < colors.length; i++) {
      final sweep = (points[i].value.abs() / total) * 3.14159 * 2;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────
//  SALES PURCHASE COMBO CHART
// ─────────────────────────────────────────────
class SalesPurchaseComboChart extends StatelessWidget {
  final SalesPurchaseChartData data;
  final double height;

  const SalesPurchaseComboChart({
    Key? key,
    required this.data,
    this.height = 220,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.dataPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final maxVal = data.dataPoints.fold<double>(
      0,
      (prev, dp) => [prev, dp.salesValue, dp.purchaseValue].reduce((a, b) => a > b ? a : b),
    );

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.dataPoints.map((dp) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 10,
                        height: maxVal > 0 ? (height - 30) * (dp.salesValue / maxVal).clamp(0.0, 1.0) : 0,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Container(
                        width: 10,
                        height: maxVal > 0 ? (height - 30) * (dp.purchaseValue / maxVal).clamp(0.0, 1.0) : 0,
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(dp.label, style: AppTypography.chartAxisLabel, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
