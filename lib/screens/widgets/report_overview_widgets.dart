import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class ReportMetricCard extends StatelessWidget {
  final Color iconBgColor;
  final String svgIcon;
  final String label;
  final String value;
  final String unit;
  final String change;
  final bool isPositive;
  final VoidCallback? onTap;

  const ReportMetricCard({
    Key? key,
    required this.iconBgColor,
    required this.svgIcon,
    required this.label,
    required this.value,
    this.unit = '',
    this.change = '',
    this.isPositive = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: SvgPicture.string(svgIcon, width: 18, height: 18),
              ),
            ),
            const SizedBox(height: 10),
            Text(label, style: AppTypography.cardLabel),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(value, style: AppTypography.cardValue, overflow: TextOverflow.ellipsis),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unit, style: AppTypography.cardUnit),
                ],
              ],
            ),
            if (change.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? AppColors.green : AppColors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
