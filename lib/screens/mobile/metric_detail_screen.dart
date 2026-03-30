import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:screenshot/screenshot.dart';
import '../theme/app_theme.dart';
import '../icons/app_icons.dart';
import '../../models/report_data.dart';
import '../../models/company_model.dart';
import '../../widgets/report_widgets.dart';
import '../../widgets/charts/sales_purchase_combo_chart.dart';
import '../../widgets/charts/report_chart.dart' hide SalesPurchaseComboChart;
import '../../services/sales_service.dart';
import '../../services/company_logo_service.dart';
import '../../services/excel_export_service.dart';
import '../main.dart';
import '../../models/sales_data.dart' hide ChartPeriod;
import '../../widgets/detail_widgets.dart';
import '../../utils/chart_period_helper.dart';
import '../../utils/amount_formatter.dart';
import 'pdf_export_screen.dart';
import 'excel_export_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MetricDetailScreen — Reusable analytics detail screen for any ReportMetric.
//
// Pass the desired [metric] to display its title, icon, chart types, and data.
// Layout: value card → trend chart → combo chart → bar/stacked/grid/gauges.
// ─────────────────────────────────────────────────────────────────────────────

class MetricDetailScreen extends StatefulWidget {
  final ReportMetric metric;

  const MetricDetailScreen({super.key, required this.metric});

  @override
  State<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends State<MetricDetailScreen> {
  // ═══════════════════════════════════════════════════════════════════════════
  //  STATE
  // ═══════════════════════════════════════════════════════════════════════════

  // Date range filter (MoM, YTD, Quarter, Custom)
  DateRangeFilter _dateRange = DateRangeFilter.ytd();

  // Chart display settings — default comes from the metric
  late ReportChartType _chartType = widget.metric.defaultChartType;
  final int _chartPeriodIndex = 0; // 0 = Monthly, 1 = Quarterly, 2 = YoY

  // Loading flags
  bool _isLoading = true;
  bool _isChartLoading = false;

  // Report data objects
  ReportValue _reportValue = ReportValue(
    primaryValue: '—',
    primaryUnit: '',
    primaryLabel: 'Loading...',
    changePercent: '',
    isPositiveChange: true,
    periodStart: DateTime.now(),
    periodEnd: DateTime.now(),
  );
  ReportChartData _chartData = const ReportChartData(
    dataPoints: [],
    chartType: ReportChartType.bar,
    title: '',
    legends: [],
  );
  SalesPurchaseChartData _salesPurchaseData = const SalesPurchaseChartData(
    dataPoints: [],
    title: '',
  );
  RevenueExpenseProfitData _revExpProfitData = const RevenueExpenseProfitData(
    revenue: 0,
    expense: 0,
    profit: 0,
  );

  // Top items
  List<TopSellingItem> _topItems = const [];

  // Service & company
  final SalesAnalyticsService _salesAnalyticsService = SalesAnalyticsService();
  final ScreenshotController _screenshotController = ScreenshotController();
  String? _companyGuid;
  Company? _company;
  Uint8List? _companyLogoBytes;

  // ═══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  /// Parse company date string (ISO "2024-04-01" or Tally "20240401") into DateTime.
  DateTime? _parseFYDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    if (dateStr.contains('-')) return DateTime.tryParse(dateStr);
    if (dateStr.length == 8) {
      final y = int.tryParse(dateStr.substring(0, 4));
      final m = int.tryParse(dateStr.substring(4, 6));
      final d = int.tryParse(dateStr.substring(6, 8));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DATA LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Resolves the active company GUID using a priority chain:
  ///   1. SecureStorage selected company
  ///   2. is_selected = 1 in companies table
  ///   3. Any company in companies table
  ///   4. Distinct company_guid from vouchers table
  Future<void> _loadCompany() async {
    _companyGuid = AppState.selectedCompany?.guid;
    _company = AppState.selectedCompany;

    // Load saved company logo
    if (_companyGuid != null) {
      final logo = await CompanyLogoService.loadLogo(_companyGuid!);
      if (mounted) {
        setState(() => _companyLogoBytes = logo);
      }
    }

    _loadData();
  }

  /// Fetches trend, combo, and revenue/expense/profit data from the analytics
  /// service for the current [widget.metric]. Falls back to mock data when no
  /// company is available or on error.
  Future<void> _loadData() async {
    if (!_isLoading) {
      setState(() => _isChartLoading = true);
    }
    final metric = widget.metric;
    final period = ChartPeriodExtension.fromIndex(_chartPeriodIndex);

    // No company found — show empty state
    if (_companyGuid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final guid = _companyGuid!;
      final today = DateTime.now();

      // Resolve start/end dates from selected filter
      late DateTime start;
      late DateTime end;

      // Get company's actual FY start from DB
      final fyStart = _parseFYDate(_company?.startingFrom) ??
          (today.month >= 4
              ? DateTime(today.year, 4, 1)
              : DateTime(today.year - 1, 4, 1));
      final fyMonth = fyStart.month;

      switch (_dateRange.type) {
        case DateRangeType.mom:
          start = DateTime(today.year, today.month, 1);
          end = today;
          break;
        case DateRangeType.ytd:
          // Use company's actual FY start date
          start = fyStart;
          end = today;
          break;
        case DateRangeType.quarter:
          // Fiscal quarter based on company's FY start month
          final fiscalMonth =
              today.month >= fyMonth ? today.month : today.month + 12;
          final qStartOffset = ((fiscalMonth - fyMonth) ~/ 3) * 3 + fyMonth;
          final qStartMonth =
              qStartOffset > 12 ? qStartOffset - 12 : qStartOffset;
          final qStartYear = qStartOffset > 12
              ? today.year
              : (today.month >= fyMonth ? today.year : today.year - 1);
          start = DateTime(qStartYear, qStartMonth, 1);
          end = today;
          break;
        case DateRangeType.custom:
          start = _dateRange.startDate;
          end = _dateRange.endDate.isAfter(today) ? today : _dateRange.endDate;
          break;
      }

      // Adjust start date for quarterly/yearly grouping
      switch (period) {
        case ChartPeriod.monthly:
          break;
        case ChartPeriod.quarterly:
          if (_dateRange.type != DateRangeType.mom) {
            start = DateTime(start.year, start.month, 1);
          }
          break;
        case ChartPeriod.yearly:
          if (_dateRange.type == DateRangeType.ytd ||
              _dateRange.type == DateRangeType.quarter) {
            start = DateTime(start.year, 1, 1);
          }
          break;
      }

      // Convert date range to Tally YYYYMMDD format
      String fmtDate(DateTime dt) =>
          '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
      final fromDate = fmtDate(start);
      final toDate = fmtDate(end);

      debugPrint('[MetricDetail] === LOAD === metric=${metric.displayName} '
          'period=${_dateRange.type} from=$fromDate to=$toDate');

      // Fetch trend chart data based on the actual metric
      Future<ReportChartData> fetchChart() {
        switch (metric) {
          case ReportMetric.sales:
            return _salesAnalyticsService.getSalesTrend(
              companyGuid: guid,
              chartType: _chartType,
              period: period,
              fromDate: fromDate,
              toDate: toDate,
            );
          case ReportMetric.purchase:
            return _salesAnalyticsService.getPurchaseTrend(
              companyGuid: guid,
              chartType: _chartType,
              period: period,
              fromDate: fromDate,
              toDate: toDate,
            );
          case ReportMetric.profit:
            return _salesAnalyticsService.getProfitTrend(
              companyGuid: guid,
              chartType: _chartType,
              period: period,
              fromDate: fromDate,
              toDate: toDate,
            );
          case ReportMetric.gst:
            return _salesAnalyticsService.getGSTTrend(
              companyGuid: guid,
              chartType: _chartType,
              period: period,
              fromDate: fromDate,
              toDate: toDate,
            );
          case ReportMetric.receipts:
            return _salesAnalyticsService.getReceiptsTrend(
              companyGuid: guid,
              chartType: _chartType,
              period: period,
              fromDate: fromDate,
              toDate: toDate,
            );
          case ReportMetric.payments:
            return _salesAnalyticsService.getPaymentsTrend(
              companyGuid: guid,
              chartType: _chartType,
              period: period,
              fromDate: fromDate,
              toDate: toDate,
            );
          case ReportMetric.receivable:
            return _salesAnalyticsService.getReceivableChart(
              companyGuid: guid,
              chartType: _chartType,
              fromDate: fromDate,
              toDate: toDate,
            );
          case ReportMetric.payable:
            return _salesAnalyticsService.getPayableChart(
              companyGuid: guid,
              chartType: _chartType,
              fromDate: fromDate,
              toDate: toDate,
            );
          case ReportMetric.stock:
            return _salesAnalyticsService.getStockChart(
              companyGuid: guid,
              chartType: _chartType,
            );
        }
      }

      // Run ALL queries in parallel instead of sequentially
      final results = await Future.wait([
        fetchChart(), // [0]
        _salesAnalyticsService.getSalesPurchaseTrend(
          // [1]
          companyGuid: guid, period: period,
          fromDate: fromDate, toDate: toDate,
        ),
        _salesAnalyticsService.getRevenueExpenseProfit(
          // [2]
          companyGuid: guid, fromDate: fromDate, toDate: toDate,
        ),
        _salesAnalyticsService.getReportValueForMetric(
          metric, // [3]
          companyGuid: guid, fromDate: fromDate, toDate: toDate,
        ),
        _salesAnalyticsService.getTopItems(
          metric, // [4]
          companyGuid: guid, fromDate: fromDate, toDate: toDate,
        ),
      ]);

      final realChart = results[0] as ReportChartData;
      final realCombo = results[1] as SalesPurchaseChartData;
      final revExpProfit = results[2] as RevenueExpenseProfitData;
      final derivedValue = results[3] as ReportValue;
      final topItems = results[4] as List<TopSellingItem>;

      debugPrint('[MetricDetail] === RESULTS === '
          'value=${derivedValue.primaryValue} ${derivedValue.primaryUnit} | '
          'chartPoints=${realChart.dataPoints.length} | '
          'comboPoints=${realCombo.dataPoints.length} | '
          'topItems=${topItems.length}');
      for (final dp in realChart.dataPoints) {
        debugPrint('[MetricDetail]   chart: ${dp.label} = ${dp.value}');
      }

      // Auto-aggregate monthly data into quarters/years based on data count
      final chartPeriod = autoSelectPeriod(realChart.dataPoints.length);
      final comboPeriod = autoSelectPeriod(realCombo.dataPoints.length);
      final aggChart = aggregateChartData(realChart, chartPeriod);
      final aggCombo = aggregateSalesPurchaseData(realCombo, comboPeriod);

      final useRevExpProfit =
          revExpProfit.revenue != 0 || revExpProfit.expense != 0;
      final finalRevExpProfit = useRevExpProfit
          ? revExpProfit
          : _deriveRevExpProfitFromCombo(aggCombo);

      if (!mounted) return;
      setState(() {
        _reportValue = derivedValue;
        _chartData = aggChart;
        _salesPurchaseData = aggCombo;
        _revExpProfitData = finalRevExpProfit;
        _topItems = topItems;
        _isLoading = false;
        _isChartLoading = false;
      });
    } catch (e, stack) {
      debugPrint('Error loading ${metric.displayName} data: $e');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isChartLoading = false;
      });
    }
  }

  /// Derives revenue/expense/profit totals from combo chart data points.
  RevenueExpenseProfitData _deriveRevExpProfitFromCombo(
      SalesPurchaseChartData combo) {
    final totalRevenue =
        combo.dataPoints.fold<double>(0.0, (sum, dp) => sum + dp.salesValue.abs());
    final totalExpense =
        combo.dataPoints.fold<double>(0.0, (sum, dp) => sum + dp.purchaseValue.abs());
    final profit = totalRevenue - totalExpense;
    return RevenueExpenseProfitData(
      revenue: totalRevenue,
      expense: totalExpense,
      profit: profit,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  USER ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _onDateRangeChanged(DateRangeFilter range) {
    setState(() => _dateRange = range);
    _loadData();
  }

  void _showCustomDatePicker() async {
    final now = DateTime.now();
    final initialStart =
        _dateRange.startDate.isAfter(now) ? now : _dateRange.startDate;
    final initialEnd =
        _dateRange.endDate.isAfter(now) ? now : _dateRange.endDate;

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.blue,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      _onDateRangeChanged(DateRangeFilter.custom(range.start, range.end));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REPORT CARDS (for PDF screenshot capture)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns the chart card widgets for PDF capture via ScreenshotController.
  List<Widget> _getReportCards() {
    final metric = widget.metric;
    return [
      // Value card
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        child: ReportValueCard(
          value: _reportValue,
          icon: metric.icon,
          iconBgColor: metric.iconBgColor,
        ),
      ),

      // Trend chart card
      _buildChartCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_chartData.title, style: AppTypography.chartSectionTitle),
            const SizedBox(height: 16),
            ReportChart(data: _chartData, height: 200),
            if (_chartData.legends.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(child: ChartLegend(items: _chartData.legends)),
            ],
          ],
        ),
      ),

      // Sales vs Purchase combo chart
      _buildChartCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_salesPurchaseData.title, style: AppTypography.chartSectionTitle),
            const SizedBox(height: 16),
            (_salesPurchaseData.dataPoints.isEmpty)
                ? SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'No data for selected period',
                        style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary) ??
                            TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : SalesPurchaseComboChart(
                    data: _salesPurchaseData,
                    height: 220,
                    chartType: _chartType),
          ],
        ),
      ),

      // Sales / Purchase / Profit bar chart
      _buildChartCard(
        child: SalesPurchaseProfitBarChart(data: _revExpProfitData),
      ),

      // Gauges
      _buildChartCard(
        child: SalesPurchaseProfitGauges(data: _revExpProfitData),
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PDF EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _openPdfExport() async {
    final now = DateTime.now().toIso8601String();
    final company = _company ??
        Company(
          guid: 'demo-guid',
          masterId: 0,
          alterId: 0,
          name: 'Demo Company',
          startingFrom: now,
          endingAt: now,
          address: '123 Test Street',
          city: 'Mumbai',
          state: 'Maharashtra',
          gsttin: '27AABCU9603R1ZM',
          createdAt: now,
          updatedAt: now,
        );

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      ),
    );

    try {
      final width = MediaQuery.of(context).size.width;
      final cards = _getReportCards();
      final cardCaptures = <Uint8List>[];

      for (final card in cards) {
        final capture = await _screenshotController.captureFromLongWidget(
          InheritedTheme.captureAll(
            context,
            MediaQuery(
              data: MediaQuery.of(context),
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: SizedBox(width: width, child: card),
                ),
              ),
            ),
          ),
          delay: const Duration(milliseconds: 100),
          pixelRatio: 3.0,
          context: context,
        );
        cardCaptures.add(capture);
      }

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfExportScreen(
            company: company,
            metric: widget.metric,
            reportValue: _reportValue,
            chartData: _chartData,
            dateRange: _dateRange,
            salesPurchaseData: _salesPurchaseData,
            revExpProfitData: _revExpProfitData,
            cardCaptures: cardCaptures,
            companyLogoBytes: _companyLogoBytes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture screen: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EXCEL EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _openExcelExport() async {
    if (_companyGuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No company selected. Please select a company first.')),
      );
      return;
    }
    final companyGuid = _companyGuid!;
    final companyName = _company?.name ?? 'Company';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      ),
    );

    try {
      final result = await ExcelExportService.generateStockItemsExcel(
        companyGuid: companyGuid,
        companyName: companyName,
        dateRange: _dateRange,
        companyLogoBytes: _companyLogoBytes,
      );

      final fileName = '${companyName.replaceAll(' ', '_')}_stock_items.xlsx';

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (result.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No stock items found. Please sync stock items & vouchers with inventory entries first.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExcelExportScreen(
            companyName: companyName,
            fileName: fileName,
            excelBytes: result.bytes,
            items: result.items,
            dateRange: _dateRange,
            companyLogoBytes: _companyLogoBytes,
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('Excel export error: $e');
      debugPrint('$stack');
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate Excel: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SHARE REPORT BOTTOM SHEET
  //
  //  Opens a modal bottom sheet with two export options:
  //    • Share as PDF  — formatted report with charts
  //    • Share as Excel — raw tabular data for spreadsheets
  // ═══════════════════════════════════════════════════════════════════════════

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Section title
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 12),
                child: Text('SHARE REPORT', style: AppTypography.chartSectionTitle),
              ),

              // Option 1 — PDF export
              ListTile(
                leading: SvgPicture.string(
                  AppIcons.filePdf,
                  width: 36,
                  height: 36,
                ),
                title: Text('Share as PDF', style: AppTypography.itemTitle),
                subtitle: Text('Formatted report with charts',
                    style: AppTypography.itemSubtitle),
                trailing: Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPdfExport();
                },
              ),

              // Divider between options
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 20,
                endIndent: 20,
                color: Colors.grey.shade300,
              ),

              // Option 2 — Excel export
              ListTile(
                leading: SvgPicture.string(
                  AppIcons.fileCsv,
                  width: 36,
                  height: 36,
                ),
                title: Text('Share as Excel', style: AppTypography.itemTitle),
                subtitle: Text('Raw data for spreadsheets',
                    style: AppTypography.itemSubtitle),
                trailing: Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  _openExcelExport();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final metric = widget.metric;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header (back button + title + share icon) ──
              _buildHeader(),
              const SizedBox(height: 14),

              // ── Scrollable content ──
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.blue),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          children: [
                            // Date range selector (MoM / YTD / Quarter / Custom)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: DateRangeSelector(
                                selected: _dateRange,
                                onChanged: _onDateRangeChanged,
                                onCustomTap: _showCustomDatePicker,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Value card (icon + total value from the metric)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: ReportValueCard(
                                value: _reportValue,
                                icon: metric.icon,
                                iconBgColor: metric.iconBgColor,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Trend chart (bar / line / combo / etc.)
                            _buildChartCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_chartData.title,
                                      style: AppTypography.chartSectionTitle),
                                  const SizedBox(height: 10),
                                  ChartTypeSelector(
                                    selected: _chartType,
                                    availableTypes: metric.applicableChartTypes,
                                    onChanged: (type) {
                                      setState(() => _chartType = type);
                                      _loadData();
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _isChartLoading
                                        ? const ChartShimmerPlaceholder(
                                            key: ValueKey('shimmer-trend'),
                                            height: 200,
                                          )
                                        : ReportChart(
                                            key: ValueKey(_chartType),
                                            data: _chartData,
                                            height: 200,
                                          ),
                                  ),
                                  if (!_isChartLoading &&
                                      _chartData.legends.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: ChartLegend(
                                          items: _chartData.legends),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Sales vs Purchase combo chart
                            _buildChartCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_salesPurchaseData.title,
                                      style: AppTypography.chartSectionTitle),
                                  const SizedBox(height: 16),
                                  (_salesPurchaseData.dataPoints.isEmpty)
                                      ? SizedBox(
                                          height: 220,
                                          child: Center(
                                            child: Text(
                                              'No data for selected period',
                                              style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                      ) ??
                                                  TextStyle(
                                                      color: AppColors
                                                          .textSecondary),
                                            ),
                                          ),
                                        )
                                      : SalesPurchaseComboChart(
                                          data: _salesPurchaseData,
                                          height: 220,
                                          chartType: ReportChartType.bar,
                                        ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Sales / Purchase / Profit bar chart
                            _buildChartCard(
                              child: SalesPurchaseProfitBarChart(
                                data: _revExpProfitData,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Sales / Purchase / Profit gauges
                            _buildChartCard(
                              child: SalesPurchaseProfitGauges(
                                data: _revExpProfitData,
                              ),
                            ),

                            // Top items (not for receivable/payable)
                            if (_topItems.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildTopItems(),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REUSABLE SUB-WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Standard card wrapper used by every chart section.
  Widget _buildChartCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: child,
      ),
    );
  }

  /// Top items section using ExpandableCard + TopSellingItemRow
  Widget _buildTopItems() {
    final metric = widget.metric;
    return ExpandableCard(
      title: metric.topItemsTitle,
      initialVisibleCount: 5,
      loadMoreCount: 5,
      children: _topItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return TopSellingItemRow(
          rank: item.rank,
          name: item.name,
          units: _formatItemNumber(item.unitsSold),
          revenue: _formatItemCurrency(item.revenue),
          change:
              '${item.isPositive ? '+' : ''}${item.changePercent.toStringAsFixed(1)}%',
          isPositive: item.isPositive,
          showDivider: index < _topItems.length - 1,
        );
      }).toList(),
    );
  }

  String _formatItemNumber(int number) =>
      AmountFormatter.short(number.toDouble());

  String _formatItemCurrency(double amount) =>
      AmountFormatter.currencyShort(amount);

  /// Header row: back arrow, page title, and share button.
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, AppSpacing.pagePadding, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title — dynamic from metric
          Text(widget.metric.displayName, style: AppTypography.pageTitle.copyWith(fontSize: 20)),
          const Spacer(),

          // Share button — opens the share-report bottom sheet
          GestureDetector(
            onTap: _showShareOptions,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: SvgPicture.string(
                  AppIcons.share,
                  width: 18,
                  height: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
