import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/report_data.dart';
import '../widgets/report_overview_widgets.dart';
import '../widgets/detail_widgets.dart';
import '../service/sales/sales_service.dart';
import '../main.dart';
import 'metric_detail_screen.dart';
import 'outstanding_detail_screen.dart';

class ReportsOverviewScreen extends StatefulWidget {
  const ReportsOverviewScreen({super.key});

  @override
  State<ReportsOverviewScreen> createState() => _ReportsOverviewScreenState();
}

class _ReportsOverviewScreenState extends State<ReportsOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ReportMetric> _filteredMetrics = ReportMetric.values.toList();

  final SalesAnalyticsService _salesService = SalesAnalyticsService();
  String? _companyGuid;
  final Map<ReportMetric, ReportValue> _metricValues = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyAndData();
  }

  Future<void> _loadCompanyAndData() async {
    _companyGuid = AppState.selectedCompany?.guid;

    if (_companyGuid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    // Use company's actual FY start from DB, fallback to April 1
    final company = AppState.selectedCompany;
    DateTime start;
    final fyStr = company?.startingFrom;
    if (fyStr != null && fyStr.isNotEmpty) {
      final parsed = fyStr.contains('-')
          ? DateTime.tryParse(fyStr)
          : (fyStr.length == 8
              ? DateTime.tryParse(
                  '${fyStr.substring(0, 4)}-${fyStr.substring(4, 6)}-${fyStr.substring(6, 8)}')
              : null);
      start = parsed ?? (now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1));
    } else {
      start = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
    }
    final end = now;

    try {
      for (final metric in ReportMetric.values) {
        final value = await _salesService.getReportValueForMetric(
          metric,
          companyGuid: _companyGuid!,
        );
        _metricValues[metric] = value;
      }
    } catch (e) {
      debugPrint('Error loading report overview data: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMetrics = ReportMetric.values.toList();
      } else {
        _filteredMetrics = ReportMetric.values
            .where((m) =>
                m.displayName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _navigateToMetric(ReportMetric metric) {
    final isOutstanding =
        metric == ReportMetric.receivable || metric == ReportMetric.payable;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => isOutstanding
            ? OutstandingDetailScreen(metric: metric)
            : MetricDetailScreen(metric: metric),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              16,
              AppSpacing.pagePadding,
              0,
            ),
            child: Text(
              'Reports',
              style: AppTypography.pageTitle,
            ),
          ),
          const SizedBox(height: 16),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: DetailSearchBar(
              controller: _searchController,
              placeholder: 'Search reports...',
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.pagePadding),

          // Metric cards grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      left: AppSpacing.pagePadding,
                      right: AppSpacing.pagePadding,
                      bottom: 90,
                    ),
                    child: _buildMetricGrid(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid() {
    if (_filteredMetrics.isEmpty) {
      return const SizedBox(
        height: 350,
        child: Center(
          child: Text(
            'No reports found',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.cardGap,
      runSpacing: AppSpacing.cardGap,
      children: _filteredMetrics.map((metric) {
        final value = _metricValues[metric];
        return SizedBox(
          width: (MediaQuery.of(context).size.width -
                  AppSpacing.pagePadding * 2 -
                  AppSpacing.cardGap) /
              2,
          child: ReportMetricCard(
            iconBgColor: metric.iconBgColor,
            svgIcon: metric.icon,
            label: metric.displayName,
            value: value?.primaryValue ?? '—',
            unit: value?.primaryUnit ?? '',
            change: value?.changePercent ?? '',
            isPositive: value?.isPositiveChange ?? true,
            onTap: () => _navigateToMetric(metric),
          ),
        );
      }).toList(),
    );
  }
}
