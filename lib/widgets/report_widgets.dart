import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/theme/app_theme.dart';
import '../models/report_data.dart';
import '../utils/amount_formatter.dart';

// ─────────────────────────────────────────────
//  REPORT VALUE CARD
// ─────────────────────────────────────────────
class ReportValueCard extends StatelessWidget {
  final ReportValue? value;
  final String icon;
  final Color iconBgColor;

  const ReportValueCard({
    Key? key,
    this.value,
    required this.icon,
    required this.iconBgColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SvgPicture.string(icon, width: 22, height: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (value != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(value!.primaryValue, style: AppTypography.cardValue),
                      const SizedBox(width: 4),
                      Text(value!.primaryUnit, style: AppTypography.cardUnit),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (value!.primaryLabel.isNotEmpty)
                        Text(value!.primaryLabel,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      if (value!.changePercent.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (value!.isPositiveChange ? AppColors.green : AppColors.red)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            value!.changePercent,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: value!.isPositiveChange ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else
                  Text('—', style: AppTypography.cardValue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHART LEGEND
// ─────────────────────────────────────────────
class ChartLegend extends StatelessWidget {
  final List<ChartLegendItem> items;

  const ChartLegend({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(item.label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  CHART TYPE SELECTOR
// ─────────────────────────────────────────────
class ChartTypeSelector extends StatelessWidget {
  final ReportChartType selected;
  final List<ReportChartType> availableTypes;
  final ValueChanged<ReportChartType> onChanged;

  const ChartTypeSelector({
    Key? key,
    required this.selected,
    required this.availableTypes,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: availableTypes.map((type) {
          final isSelected = type == selected;
          return GestureDetector(
            onTap: () => onChanged(type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.blue.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.blue : AppColors.divider,
                ),
              ),
              child: Text(
                type.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.blue : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REPORT CHART PERIOD SELECTOR
// ─────────────────────────────────────────────
class ReportChartPeriodSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  const ReportChartPeriodSelector({
    Key? key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels = const ['M', 'Q', 'Y'],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(labels.length, (i) {
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
//  SALES PURCHASE PROFIT BAR CHART
// ─────────────────────────────────────────────
class SalesPurchaseProfitBarChart extends StatelessWidget {
  final RevenueExpenseProfitData data;

  const SalesPurchaseProfitBarChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxVal = [data.revenue, data.expense, data.profit.abs()].reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox(height: 120);

    return SizedBox(
      height: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar('Revenue', data.revenue, maxVal, AppColors.blue),
          _bar('Expense', data.expense, maxVal, AppColors.red),
          _bar('Profit', data.profit, maxVal, data.profit >= 0 ? AppColors.green : AppColors.amber),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, double max, Color color) {
    final ratio = max > 0 ? (value.abs() / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(AmountFormatter.shortSpaced(value), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 100 * ratio,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SALES PURCHASE STACKED BAR CHART
// ─────────────────────────────────────────────
class SalesPurchaseStackedBarChart extends StatelessWidget {
  final SalesPurchaseChartData data;

  const SalesPurchaseStackedBarChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.dataPoints.isEmpty) return const SizedBox(height: 120);
    final maxVal = data.dataPoints.fold<double>(
      0,
      (prev, dp) => [prev, dp.salesValue, dp.purchaseValue].reduce((a, b) => a > b ? a : b),
    );
    if (maxVal == 0) return const SizedBox(height: 120);

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.dataPoints.length,
        itemBuilder: (context, i) {
          final dp = data.dataPoints[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 20,
                  height: 120 * (dp.salesValue / maxVal).clamp(0.0, 1.0),
                  color: AppColors.blue.withValues(alpha: 0.8),
                ),
                Container(
                  width: 20,
                  height: 120 * (dp.purchaseValue / maxVal).clamp(0.0, 1.0),
                  color: AppColors.amber.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 4),
                Text(dp.label, style: AppTypography.chartAxisLabel),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REVENUE EXPENSE PROFIT GRID CHART
// ─────────────────────────────────────────────
class RevenueExpenseProfitGridChart extends StatelessWidget {
  final RevenueExpenseProfitData data;

  const RevenueExpenseProfitGridChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _cell('Revenue', data.revenue, AppColors.green),
        _cell('Expense', data.expense, AppColors.red),
        _cell('Profit', data.profit, data.profit >= 0 ? AppColors.green : AppColors.red),
      ],
    );
  }

  Widget _cell(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(AmountFormatter.shortSpaced(value),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SALES PURCHASE PROFIT GAUGES
// ─────────────────────────────────────────────
class SalesPurchaseProfitGauges extends StatelessWidget {
  final RevenueExpenseProfitData data;

  const SalesPurchaseProfitGauges({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = data.revenue + data.expense;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _gauge('Revenue', data.revenue, total, AppColors.green),
        _gauge('Expense', data.expense, total, AppColors.red),
        _gauge('Margin', total > 0 ? (data.profit / data.revenue * 100) : 0, 100, AppColors.blue),
      ],
    );
  }

  Widget _gauge(String label, double value, double max, Color color) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            value: pct,
            strokeWidth: 6,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 8),
        Text(AmountFormatter.shortSpaced(value),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  REPORT METRIC CHIPS
// ─────────────────────────────────────────────
class ReportMetricChips extends StatelessWidget {
  final ReportMetric selected;
  final List<ReportMetric> metrics;
  final ValueChanged<ReportMetric> onSelected;

  const ReportMetricChips({
    Key? key,
    required this.selected,
    required this.metrics,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        itemCount: metrics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final m = metrics[index];
          final isSelected = m == selected;
          return GestureDetector(
            onTap: () => onSelected(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.blue : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: AppColors.divider),
              ),
              child: Text(
                m.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHART SECTION CARD
// ─────────────────────────────────────────────
class ChartSectionCard extends StatelessWidget {
  final String title;
  final ReportChartType selectedChartType;
  final List<ReportChartType> availableChartTypes;
  final ValueChanged<ReportChartType> onChartTypeChanged;
  final int selectedPeriodIndex;
  final ValueChanged<int> onPeriodChanged;
  final Widget chart;
  final List<ChartLegendItem> legends;
  final bool showSelectors;

  const ChartSectionCard({
    Key? key,
    required this.title,
    required this.selectedChartType,
    required this.availableChartTypes,
    required this.onChartTypeChanged,
    required this.selectedPeriodIndex,
    required this.onPeriodChanged,
    required this.chart,
    this.legends = const [],
    this.showSelectors = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTypography.cardLabel)),
              if (showSelectors)
                ReportChartPeriodSelector(
                  selectedIndex: selectedPeriodIndex,
                  onChanged: onPeriodChanged,
                ),
            ],
          ),
          if (showSelectors) ...[
            const SizedBox(height: 10),
            ChartTypeSelector(
              selected: selectedChartType,
              availableTypes: availableChartTypes,
              onChanged: onChartTypeChanged,
            ),
          ],
          const SizedBox(height: 16),
          chart,
          if (legends.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(child: ChartLegend(items: legends)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REVENUE EXPENSE PROFIT CHART (bar variant)
// ─────────────────────────────────────────────
class RevenueExpenseProfitChart extends StatelessWidget {
  final RevenueExpenseProfitData data;

  const RevenueExpenseProfitChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SalesPurchaseProfitBarChart(data: data);
  }
}

// ─────────────────────────────────────────────
//  REVENUE EXPENSE PROFIT PIE CHART
// ─────────────────────────────────────────────
class RevenueExpenseProfitPieChart extends StatelessWidget {
  final RevenueExpenseProfitData data;

  const RevenueExpenseProfitPieChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SalesPurchaseProfitGauges(data: data);
  }
}

// ─────────────────────────────────────────────
//  CREDIT LIMIT EXCEEDED CARD
// ─────────────────────────────────────────────
class CreditLimitExceededCard extends StatelessWidget {
  final List<CreditLimitParty> parties;
  final int? selectedDaysFilter;
  final int? customDaysValue;
  final ValueChanged<int?> onFilterChanged;
  final VoidCallback? onCustomTap;
  final bool showHeader;
  final int totalPartyCount;

  const CreditLimitExceededCard({
    Key? key,
    required this.parties,
    this.selectedDaysFilter,
    this.customDaysValue,
    required this.onFilterChanged,
    this.onCustomTap,
    this.showHeader = true,
    this.totalPartyCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text('Credit Limit Exceeded', style: AppTypography.cardLabel),
            const SizedBox(height: 8),
            Text('${totalPartyCount > 0 ? totalPartyCount : parties.length} parties',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
          ],
          ...parties.map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: AppTypography.itemTitle),
                      Text('Limit: ${AmountFormatter.shortSpaced(p.creditLimit)}',
                          style: AppTypography.itemSubtitle),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\u20B9${AmountFormatter.shortSpaced(p.currentOutstanding)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red)),
                    if (p.daysOverLimit > 0)
                      Text('${p.daysOverLimit}d over',
                          style: TextStyle(fontSize: 11, color: AppColors.red)),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOP PAYING PARTIES CARD
// ─────────────────────────────────────────────
class TopPayingPartiesCard extends StatelessWidget {
  final List<dynamic> parties;
  final FiscalYear selectedFiscalYear;
  final List<FiscalYear>? fiscalYearOptions;
  final ValueChanged<FiscalYear>? onFiscalYearChanged;
  final bool showHeader;
  final int startRank;

  const TopPayingPartiesCard({
    Key? key,
    required this.parties,
    required this.selectedFiscalYear,
    this.fiscalYearOptions,
    this.onFiscalYearChanged,
    this.showHeader = true,
    this.startRank = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Expanded(child: Text('Top Paying Parties', style: AppTypography.cardLabel)),
                Text(selectedFiscalYear.displayText,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...parties.asMap().entries.map((entry) {
            final i = entry.key + startRank;
            final p = entry.value;
            final name = p is TopPayingParty ? p.name : (p is TopSellingItem ? p.name : '');
            final amount = p is TopPayingParty ? p.amount : (p is TopSellingItem ? p.revenue : 0.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: AppTypography.itemTitle, overflow: TextOverflow.ellipsis)),
                  Text('\u20B9${AmountFormatter.shortSpaced(amount.toDouble())}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAYMENT DUE CARD
// ─────────────────────────────────────────────
class PaymentDueCard extends StatelessWidget {
  final List<PaymentDueParty> parties;
  final int? selectedDaysFilter;
  final int? customDaysValue;
  final ValueChanged<int?> onFilterChanged;
  final VoidCallback? onCustomTap;
  final bool showHeader;
  final int totalPartyCount;

  const PaymentDueCard({
    Key? key,
    required this.parties,
    this.selectedDaysFilter,
    this.customDaysValue,
    required this.onFilterChanged,
    this.onCustomTap,
    this.showHeader = true,
    this.totalPartyCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text('Payment Due', style: AppTypography.cardLabel),
            const SizedBox(height: 8),
            Text('${totalPartyCount > 0 ? totalPartyCount : parties.length} parties',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
          ],
          ...parties.map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: AppTypography.itemTitle),
                      if (p.daysOverdue > 0)
                        Text('${p.daysOverdue} days overdue',
                            style: TextStyle(fontSize: 11, color: AppColors.amber)),
                    ],
                  ),
                ),
                Text('\u20B9${AmountFormatter.shortSpaced(p.amountDue)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOP VENDORS CARD
// ─────────────────────────────────────────────
class TopVendorsCard extends StatelessWidget {
  final List<dynamic> vendors;
  final FiscalYear selectedFiscalYear;
  final List<FiscalYear>? fiscalYearOptions;
  final ValueChanged<FiscalYear>? onFiscalYearChanged;
  final bool showHeader;
  final int startRank;

  const TopVendorsCard({
    Key? key,
    required this.vendors,
    required this.selectedFiscalYear,
    this.fiscalYearOptions,
    this.onFiscalYearChanged,
    this.showHeader = true,
    this.startRank = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Expanded(child: Text('Top Vendors', style: AppTypography.cardLabel)),
                Text(selectedFiscalYear.displayText,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...vendors.asMap().entries.map((entry) {
            final i = entry.key + startRank;
            final v = entry.value;
            final name = v is TopVendorParty ? v.name : (v is TopSellingItem ? v.name : '');
            final amount = v is TopVendorParty ? v.amount : (v is TopSellingItem ? v.revenue : 0.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: AppTypography.itemTitle, overflow: TextOverflow.ellipsis)),
                  Text('\u20B9${AmountFormatter.shortSpaced(amount.toDouble())}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
