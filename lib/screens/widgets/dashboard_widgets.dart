import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../models/kpi_metric.dart';

// ─────────────────────────────────────────────
//  METRIC CARD (2×2 grid item)
// ─────────────────────────────────────────────
class MetricCard extends StatelessWidget {
  final String svgIcon;
  final Color iconBgColor;
  final String label;
  final String value;
  final String unit;
  final String change;
  final bool isPositive;
  final VoidCallback? onTap;

  const MetricCard({
    Key? key,
    required this.svgIcon,
    required this.iconBgColor,
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
            const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PERIOD SELECTOR
// ─────────────────────────────────────────────
class PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final List<String> options;

  const PeriodSelector({
    Key? key,
    required this.selected,
    required this.onChanged,
    this.options = const ['MoM', 'YTD', 'QTD', 'Custom'],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final isSelected = opt == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.blue : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: AppColors.divider),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  REVENUE BREAKDOWN
// ─────────────────────────────────────────────
class RevenueBreakdown extends StatelessWidget {
  final String revenue;
  final String expenses;
  final String net;

  const RevenueBreakdown({
    Key? key,
    required this.revenue,
    required this.expenses,
    required this.net,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue Breakdown', style: AppTypography.cardLabel),
          const SizedBox(height: 16),
          _row('Revenue', revenue, AppColors.green),
          const SizedBox(height: 10),
          _row('Expenses', expenses, AppColors.red),
          const Divider(height: 24),
          _row('Net Profit', net, AppColors.green),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  AI ASK BAR
// ─────────────────────────────────────────────
class AiAskBar extends StatelessWidget {
  const AiAskBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 20, color: AppColors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ask anything about your business...',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DASHBOARD BOTTOM NAV
// ─────────────────────────────────────────────
class DashboardBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const DashboardBottomNav({
    Key? key,
    required this.activeIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: activeIndex,
      onTap: onTap,
      selectedItemColor: AppColors.blue,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  KPI SECTION
// ─────────────────────────────────────────────
class KpiSection extends StatelessWidget {
  final VoidCallback? onEditTap;
  final List<Widget> children;

  const KpiSection({
    Key? key,
    this.onEditTap,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Text('Key Metrics', style: AppTypography.cardLabel),
                const Spacer(),
                if (onEditTap != null)
                  IconButton(
                    onPressed: onEditTap,
                    icon: Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  KEY METRIC ROW
// ─────────────────────────────────────────────
class KeyMetricRow extends StatelessWidget {
  final String svgIcon;
  final Color iconBg;
  final String label;
  final String value;
  final String sub;
  final String badge;
  final bool isPositive;
  final bool showDivider;

  final VoidCallback? onTap;

  const KeyMetricRow({
    Key? key,
    required this.svgIcon,
    required this.iconBg,
    required this.label,
    required this.value,
    this.sub = '',
    this.badge = '',
    this.isPositive = true,
    this.showDivider = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: SvgPicture.string(svgIcon, width: 18, height: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    if (sub.isNotEmpty)
                      Text(sub, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (badge.isNotEmpty)
                    TrendBadge(text: badge, isPositive: isPositive),
                ],
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, indent: 68, color: AppColors.divider),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  TREND BADGE
// ─────────────────────────────────────────────
class TrendBadge extends StatelessWidget {
  final String text;
  final bool isPositive;

  const TrendBadge({
    Key? key,
    required this.text,
    this.isPositive = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
