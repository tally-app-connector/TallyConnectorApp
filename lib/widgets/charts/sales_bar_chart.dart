import 'package:flutter/material.dart';
import '../../screens/theme/app_theme.dart';
import '../../models/sales_data.dart';
import '../../utils/amount_formatter.dart';

class SalesBarChart extends StatelessWidget {
  final List<SalesDataPoint> data;
  final ChartPeriod period;
  final double height;

  const SalesBarChart({
    Key? key,
    required this.data,
    required this.period,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data available',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ),
      );
    }

    final maxVal = data.fold<double>(0, (prev, dp) {
      final m = [dp.value, dp.previousValue ?? 0].reduce((a, b) => a > b ? a : b);
      return m > prev ? m : prev;
    });

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((dp) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AmountFormatter.shortSpaced(dp.value),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (dp.previousValue != null)
                        Container(
                          width: 10,
                          height: maxVal > 0 ? (height - 40) * (dp.previousValue! / maxVal).clamp(0.0, 1.0) : 0,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                      const SizedBox(width: 2),
                      Container(
                        width: 14,
                        height: maxVal > 0 ? (height - 40) * (dp.value / maxVal).clamp(0.0, 1.0) : 0,
                        decoration: BoxDecoration(
                          color: AppColors.blue,
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
