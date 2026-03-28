import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../icons/app_icons.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/detail_widgets.dart';
import '../widgets/charts/sales_bar_chart.dart';
import '../models/sales_data.dart';
import '../models/report_data.dart' hide ChartPeriod;
import '../utils/amount_formatter.dart';
import '../service/sales/sales_service.dart';
import '../main.dart';

class NetSalesDetailScreen extends StatefulWidget {
  final String totalValue;
  final String unit;
  final String changePercent;
  final bool isPositive;

  const NetSalesDetailScreen({
    super.key,
    required this.totalValue,
    required this.unit,
    required this.changePercent,
    required this.isPositive,
  });

  @override
  State<NetSalesDetailScreen> createState() => _NetSalesDetailScreenState();
}

class _NetSalesDetailScreenState extends State<NetSalesDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SalesAnalyticsService _salesService = SalesAnalyticsService();
  String _searchQuery = '';
  bool _isLoading = true;

  List<SalesDataPoint> _monthlyData = [];
  List<TopSellingItem> _topSellingItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final companyGuid = AppState.selectedCompany?.guid;
    if (companyGuid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Monthly trend for current FY
      final monthlyChart =
          await _salesService.getSalesTrend(companyGuid: companyGuid);
      print('=== NET SALES DEBUG ===');
      print('Total data points: ${monthlyChart.dataPoints.length}');
      for (final dp in monthlyChart.dataPoints) {
        print('  ${dp.label} → ${dp.value}');
      }
      final years =
          monthlyChart.dataPoints.map((dp) => dp.label.substring(0, 4)).toSet();
      print('Years in data: $years (${years.length} year(s))');
      print('=======================');
      print('=== BAR VALUES (raw → formatted) ===');
      for (final dp in monthlyChart.dataPoints) {
        final formatted = AmountFormatter.shortSpaced(dp.value);
        print('  ${dp.label} → raw: ${dp.value} → bar label: $formatted');
      }
      print('====================================');
      final monthly = monthlyChart.dataPoints.map((dp) {
        // Convert "YYYYMM" (e.g. "202504") to short month label like "Apr"
        final label = dp.label;
        final monthNum =
            label.length >= 6 ? int.tryParse(label.substring(4, 6)) ?? 1 : 1;
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        final year = label.length >= 4 ? label.substring(2, 4) : '';
        return SalesDataPoint(label: "${months[monthNum - 1]}'$year", value: dp.value);
      }).toList();

      // Top selling items
      final topItems = await _salesService.getTopItems(ReportMetric.sales,
          companyGuid: companyGuid);

      if (mounted) {
        setState(() {
          _monthlyData = monthly;
          _topSellingItems = topItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading net sales data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TopSellingItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _topSellingItems;
    return _topSellingItems.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  bottom: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailPageHeader(
                      title: 'Net Sales',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 16),
                    DetailSearchBar(
                      controller: _searchController,
                      placeholder: 'Search items...',
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildTotalSalesCard(),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildChartSection(),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildTopSellingItems(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTotalSalesCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            SvgPicture.string(AppIcons.barChart, width: 42, height: 42),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL NET SALES', style: AppTypography.chartSectionTitle),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(widget.totalValue, style: AppTypography.cardValue),
                      const SizedBox(width: 4),
                      Text(widget.unit, style: AppTypography.cardUnit),
                    ],
                  ),
                ],
              ),
            ),
            TrendBadge(
              text: widget.changePercent,
              isPositive: widget.isPositive,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SALES TREND', style: AppTypography.chartSectionTitle),
          const SizedBox(height: 20),
          SalesBarChart(
            data: _monthlyData,
            period: ChartPeriod.monthly,
            height: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingItems() {
    final items = _filteredItems;

    return ExpandableCard(
      title: 'Top Selling Items',
      initialVisibleCount: 5,
      loadMoreCount: 5,
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return TopSellingItemRow(
          rank: item.rank,
          name: item.name,
          units: _formatNumber(item.unitsSold),
          revenue: _formatCurrency(item.revenue),
          change:
              '${item.isPositive ? '+' : ''}${item.changePercent.toStringAsFixed(0)}%',
          isPositive: item.isPositive,
          showDivider: index < items.length - 1,
        );
      }).toList(),
    );
  }

  String _formatNumber(int number) =>
      AmountFormatter.short(number.toDouble());

  String _formatCurrency(double amount) =>
      AmountFormatter.currencyShort(amount);
}
