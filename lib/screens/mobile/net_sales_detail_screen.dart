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
  int _selectedPeriodIndex = 0;
  String _searchQuery = '';
  bool _isLoading = true;

  List<SalesDataPoint> _monthlyData = [];
  List<SalesDataPoint> _quarterlyData = [];
  List<SalesDataPoint> _yoyData = [];
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
      final now = DateTime.now();
      final fyStart = now.month >= 4
          ? DateTime(now.year, 4, 1)
          : DateTime(now.year - 1, 4, 1);

      // Monthly trend for current FY
      final monthlyChart = await _salesService.getSalesTrend(
        companyGuid: companyGuid
      );
      final monthly = monthlyChart.dataPoints.map((dp) {
        // Convert "YYYYMM" (e.g. "202504") to short month label like "Apr"
        final label = dp.label;
        final monthNum = label.length >= 6 ? int.tryParse(label.substring(4, 6)) ?? 1 : 1;
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        return SalesDataPoint(label: months[monthNum - 1], value: dp.value);
      }).toList();

      // Quarterly: aggregate monthly data into quarters
      final quarterMap = <String, double>{};
      for (final dp in monthlyChart.dataPoints) {
        final label = dp.label;
        final monthNum = label.length >= 6 ? int.tryParse(label.substring(4, 6)) ?? 1 : 1;
        final q = 'Q${((monthNum - 1) ~/ 3) + 1}';
        quarterMap[q] = (quarterMap[q] ?? 0) + dp.value;
      }
      final quarterly = quarterMap.entries
          .map((e) => SalesDataPoint(label: e.key, value: e.value))
          .toList();

      // YoY: current year vs previous years
      final prevFyStart = DateTime(fyStart.year - 1, fyStart.month, fyStart.day);
      final prevFyEnd = DateTime(fyStart.year, fyStart.month, fyStart.day).subtract(const Duration(days: 1));
      final prevPrevFyStart = DateTime(fyStart.year - 2, fyStart.month, fyStart.day);
      final prevPrevFyEnd = DateTime(fyStart.year - 1, fyStart.month, fyStart.day).subtract(const Duration(days: 1));

      final currentYearTotal = monthlyChart.dataPoints.fold<double>(0, (s, dp) => s + dp.value);
      final prevChart = await _salesService.getSalesTrend(
        companyGuid: companyGuid);
      final prevTotal = prevChart.dataPoints.fold<double>(0, (s, dp) => s + dp.value);
      final prevPrevChart = await _salesService.getSalesTrend(
        companyGuid: companyGuid);
      final prevPrevTotal = prevPrevChart.dataPoints.fold<double>(0, (s, dp) => s + dp.value);

      final yoy = <SalesDataPoint>[];
      if (prevPrevTotal > 0) {
        yoy.add(SalesDataPoint(label: 'FY${prevPrevFyStart.year % 100}', value: prevPrevTotal));
      }
      if (prevTotal > 0) {
        yoy.add(SalesDataPoint(label: 'FY${prevFyStart.year % 100}', value: prevTotal, previousValue: prevPrevTotal));
      }
      yoy.add(SalesDataPoint(label: 'FY${fyStart.year % 100}', value: currentYearTotal, previousValue: prevTotal));

      // Top selling items
      final topItems = await _salesService.getTopItems(
        ReportMetric.sales,
        companyGuid: companyGuid
      );

      if (mounted) {
        setState(() {
          _monthlyData = monthly;
          _quarterlyData = quarterly;
          _yoyData = yoy;
          _topSellingItems = topItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading net sales data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SalesDataPoint> get _currentChartData {
    switch (_selectedPeriodIndex) {
      case 0:
        return _monthlyData;
      case 1:
        return _quarterlyData;
      case 2:
        return _yoyData;
      default:
        return _monthlyData;
    }
  }

  ChartPeriod get _currentPeriod {
    switch (_selectedPeriodIndex) {
      case 0:
        return ChartPeriod.monthly;
      case 1:
        return ChartPeriod.quarterly;
      case 2:
        return ChartPeriod.yoy;
      default:
        return ChartPeriod.monthly;
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
                      onChanged: (value) => setState(() => _searchQuery = value),
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
                  Text('TOTAL NET SALES', style: AppTypography.cardLabel),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SALES TREND', style: AppTypography.cardLabel),
              ChartPeriodSelector(
                selectedIndex: _selectedPeriodIndex,
                onChanged: (index) =>
                    setState(() => _selectedPeriodIndex = index),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SalesBarChart(
            data: _currentChartData,
            period: _currentPeriod,
            height: 200,
          ),
          if (_selectedPeriodIndex == 2) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Previous Year', AppColors.blue.withOpacity(0.3)),
                const SizedBox(width: 20),
                _buildLegendItem('Current Year', AppColors.blue),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.chartAxisLabel),
      ],
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

  String _formatNumber(int number) {
    if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(1)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString();
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)} L';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }
}
