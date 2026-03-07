import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import '../theme/app_theme.dart';
import '../icons/app_icons.dart';
import '../models/report_data.dart';
import '../widgets/report_widgets.dart';
import '../widgets/detail_widgets.dart';
// import '../widgets/charts/report_chart.dart';

import '../service/sales/sales_service.dart';
import '../service/company_logo_service.dart';
import '../../database/database_helper.dart';
import '../main.dart';
import '../models/company_model.dart';
import '../utils/secure_storage.dart';
import '../utils/amount_formatter.dart';
import '../widgets/charts/sales_purchase_combo_chart.dart';
import '../widgets/charts/report_chart.dart' hide SalesPurchaseComboChart;
import 'pdf_export_screen.dart';
import '../service/excel_export_service.dart';
import 'excel_export_screen.dart';

class ReportsScreen extends StatefulWidget {
  final ReportMetric? initialMetric;

  const ReportsScreen({super.key, this.initialMetric});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Selected metric
  ReportMetric _selectedMetric = ReportMetric.sales;

  // All available metrics (for filtering)
  final List<ReportMetric> _allMetrics = ReportMetric.values.toList();
  List<ReportMetric> _filteredMetrics = ReportMetric.values.toList();

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Date range
  DateRangeFilter _dateRange = DateRangeFilter.ytd();

  // Chart settings
  late ReportChartType _chartType;
  int _chartPeriodIndex = 0; // 0=Monthly, 1=Quarterly, 2=YoY

  // Data
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

  // Receivable card filters
  int? _selectedDaysFilter; // null = All, otherwise 30, 60, 90, or custom
  int? _customDaysValue;
  late FiscalYear _selectedFiscalYear;
  late List<FiscalYear> _fiscalYearOptions;

  // Payable card filters
  int?
      _payableSelectedDaysFilter; // null = All, otherwise 30, 60, 90, or custom
  int? _payableCustomDaysValue;
  late FiscalYear _payableSelectedFiscalYear;

  // DB-loaded party data for receivable/payable cards
  List<CreditLimitParty> _creditLimitParties = [];
  List<TopPayingParty> _topPayingParties = [];
  List<PaymentDueParty> _paymentDueParties = [];
  List<TopVendorParty> _topVendors = [];

  final SalesAnalyticsService _salesAnalyticsService = SalesAnalyticsService();
  final ScreenshotController _screenshotController = ScreenshotController();
  String? _companyGuid;
  Company? _company;
  Uint8List? _companyLogoBytes;

  @override
  void initState() {
    super.initState();
    if (widget.initialMetric != null) {
      _selectedMetric = widget.initialMetric!;
    }
    _chartType = _selectedMetric.defaultChartType;
    _fiscalYearOptions = FiscalYear.available();
    _selectedFiscalYear = _fiscalYearOptions.first; // Current FY
    _payableSelectedFiscalYear = _fiscalYearOptions.first; // Current FY
    _loadCompany();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _loadCompany() async {
    final selected = AppState.selectedCompany;
    if (selected != null) {
      _companyGuid = selected.guid;
      _company = selected;
    }

    if (_companyGuid != null) {
      final logo = await CompanyLogoService.loadLogo(_companyGuid!);
      if (mounted) {
        setState(() => _companyLogoBytes = logo);
      }
    }

    _loadReportData();
  }

  RevenueExpenseProfitData _deriveRevExpProfitFromCombo(
      SalesPurchaseChartData combo) {
    final totalRevenue =
        combo.dataPoints.fold<double>(0.0, (sum, dp) => sum + dp.salesValue);
    final totalExpense =
        combo.dataPoints.fold<double>(0.0, (sum, dp) => sum + dp.purchaseValue);
    return RevenueExpenseProfitData(
      revenue: totalRevenue,
      expense: totalExpense,
      profit: totalRevenue - totalExpense,
    );
  }

  void _onMetricChanged(ReportMetric metric) {
    setState(() {
      _selectedMetric = metric;
      _chartType = metric.defaultChartType;
    });
    _loadReportData();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredMetrics = _allMetrics
          .where(
              (m) => m.displayName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _onDateRangeChanged(DateRangeFilter range) {
    setState(() => _dateRange = range);
    _loadReportData();
  }

  void _showCustomDatePicker() async {
    final now = DateTime.now();
    // Ensure initial dates don't exceed lastDate
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
            colorScheme: const ColorScheme.light(
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

  Future<void> _loadReportData() async {
    final period = ChartPeriodExtension.fromIndex(_chartPeriodIndex);

    debugPrint('');
    debugPrint('========== _loadReportData ==========');
    debugPrint('Metric: ${_selectedMetric.displayName}');
    debugPrint(
        'DateRange: ${_dateRange.type.name} | ${_dateRange.startDate} → ${_dateRange.endDate}');
    debugPrint('ChartType: $_chartType | Period: $period');
    debugPrint('CompanyGUID: $_companyGuid');

    if (_companyGuid == null) {
      debugPrint('⚠️ No companyGuid — no data to display');
      return;
    }

    try {
      final guid = _companyGuid!;
      final now = DateTime.now();

      // M/Q/Y = zoom level: M uses selected range, Q expands to quarter, Y expands to year
      // late DateTime start;
      // late DateTime end;
      // switch (period) {
      //   case ChartPeriod.quarterly:
      //     // Always show full current quarter (monthly grouping)
      //     final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
      //     start = DateTime(now.year, qStart, 1);
      //     end = DateTime(now.year, qStart + 3, 0);
      //     break;
      //   case ChartPeriod.yearly:
      //     // Always show full year (monthly grouping)
      //     start = DateTime(now.year, 1, 1);
      //     end = DateTime(now.year, 12, 31);
      //     break;
      //   case ChartPeriod.monthly:
      //     // Use selected date range as-is
      //     // For Quarter type, expand M to full quarter so all 3 months show
      //     if (_dateRange.type == DateRangeType.quarter) {
      //       final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
      //       start = DateTime(now.year, qStart, 1);
      //       end = DateTime(now.year, qStart + 3, 0);
      //     } else {
      //       start = _dateRange.startDate;
      //       end = _dateRange.endDate;
      //     }
      //     break;
      // }

      late DateTime start;
      late DateTime end;

      final today = DateTime.now();

// Get company's actual FY start from DB
      final fyStart = _parseFYDate(_company?.startingFrom) ??
          (today.month >= 4 ? DateTime(today.year, 4, 1) : DateTime(today.year - 1, 4, 1));
      final fyMonth = fyStart.month;

// Step 1: resolve base range (MoM / YTD / Quarter / Custom)
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
          final fiscalMonth = today.month >= fyMonth ? today.month : today.month + 12;
          final qStartOffset = ((fiscalMonth - fyMonth) ~/ 3) * 3 + fyMonth;
          final qStartMonth = qStartOffset > 12 ? qStartOffset - 12 : qStartOffset;
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

// Step 2: apply M / Q / Y (grouping only — NEVER extend end date)
      switch (period) {
        case ChartPeriod.monthly:
          // weekly view inside current range
          break;

        case ChartPeriod.quarterly:
          // allow month grouping only if range spans > 1 month
          if (_dateRange.type != DateRangeType.mom) {
            start = DateTime(start.year, start.month, 1);
          }
          break;

        case ChartPeriod.yearly:
          // allow Jan expansion ONLY for YTD or Quarter
          if (_dateRange.type == DateRangeType.ytd ||
              _dateRange.type == DateRangeType.quarter) {
            start = DateTime(start.year, 1, 1);
          }
          break;
      }

      debugPrint('--- FETCHING REAL DATA FROM DB ---');

      switch (_selectedMetric) {
        case ReportMetric.sales:
          final realChart = await _salesAnalyticsService.getSalesTrend(
            companyGuid: guid,
            chartType: _chartType,
            period: period,
          );

          // 2️⃣ SALES vs PURCHASE COMBO (unchanged)
          final realCombo = await _salesAnalyticsService.getSalesPurchaseTrend(
            companyGuid: guid,
            period: period,
          );

          // 3️⃣ REVENUE / EXPENSE / PROFIT for bar chart
          final revExpProfit =
              await _salesAnalyticsService.getRevenueExpenseProfit(
                  companyGuid: guid);

          // 4️⃣ DERIVE SUMMARY VALUE FROM CHART DATA
          final totalSales = realChart.dataPoints.fold<double>(
            0,
            (sum, dp) => sum + dp.value,
          );

          final formatted = AmountFormatter.format(totalSales);

          final derivedValue = ReportValue(
            primaryValue: formatted['value']!,
            primaryUnit: formatted['unit']!,
            primaryLabel: 'TOTAL NET SALES',
            changePercent: '',
            isPositiveChange: true,
            periodStart: start,
            periodEnd: end,
          );

          final useRevExpProfit =
              revExpProfit.revenue != 0 || revExpProfit.expense != 0;
          final finalRevExpProfit = useRevExpProfit
              ? revExpProfit
              : _deriveRevExpProfitFromCombo(realCombo);

          setState(() {
            _reportValue = derivedValue;
            _chartData = realChart;
            _salesPurchaseData = realCombo;
            _revExpProfitData = finalRevExpProfit;
          });
          break;

        case ReportMetric.purchase:
          final realValue = await _salesAnalyticsService.getTotalPurchase(
              companyGuid: guid);
          final realChart = await _salesAnalyticsService.getPurchaseTrend(
              companyGuid: guid,
              
              chartType: _chartType,
              period: period);

          debugPrint(
              '  Value: ${realValue.primaryValue}${realValue.primaryUnit}');
          debugPrint('  Chart points: ${realChart.dataPoints.length}');
          for (final dp in realChart.dataPoints) {
            debugPrint('    [${dp.label}] = ${dp.value.toStringAsFixed(0)}');
          }

          final purchaseCombo = await _salesAnalyticsService.getSalesPurchaseTrend(
              companyGuid: guid, period: period);

          setState(() {
            _reportValue = realValue;
            _chartData = realChart;
            _salesPurchaseData = purchaseCombo;
          });
          break;

        case ReportMetric.profit:
          final realValue = await _salesAnalyticsService.getTotalProfit(
              companyGuid: guid);
          final realChart = await _salesAnalyticsService.getProfitTrend(
              companyGuid: guid,
              
              chartType: _chartType,
              period: period);
          final revExpProfit =
              await _salesAnalyticsService.getRevenueExpenseProfit(
                  companyGuid: guid);

          debugPrint(
              '  Value: ${realValue.primaryValue}${realValue.primaryUnit}');
          debugPrint('  Chart points: ${realChart.dataPoints.length}');
          for (final dp in realChart.dataPoints) {
            debugPrint('    [${dp.label}] = ${dp.value.toStringAsFixed(0)}');
          }

          final profitComboData =
              await _salesAnalyticsService.getSalesPurchaseTrend(
                companyGuid: guid, period: period);

          final useRevExpProfitData =
              revExpProfit.revenue != 0 || revExpProfit.expense != 0;
          final finalRevExpProfitData = useRevExpProfitData
              ? revExpProfit
              : _deriveRevExpProfitFromCombo(profitComboData);

          setState(() {
            _reportValue = realValue;
            _chartData = realChart;
            _salesPurchaseData = profitComboData;
            _revExpProfitData = finalRevExpProfitData;
          });
          break;

        case ReportMetric.gst:
          final realValue = await _salesAnalyticsService.getTotalGST(
              companyGuid: guid);
          final realChart = await _salesAnalyticsService.getGSTTrend(
              companyGuid: guid,
              chartType: _chartType,
              period: period);

          final gstCombo = await _salesAnalyticsService.getSalesPurchaseTrend(
              companyGuid: guid, period: period);

          setState(() {
            _reportValue = realValue;
            _chartData = realChart;
            _salesPurchaseData = gstCombo;
          });
          break;

        case ReportMetric.receivable:
          final realValue = await _salesAnalyticsService.getTotalReceivable(
              companyGuid: guid);
          final realChart = await _salesAnalyticsService.getReceivableChart(
              companyGuid: guid, chartType: _chartType);
          final recvCombo = await _salesAnalyticsService.getSalesPurchaseTrend(
              companyGuid: guid, period: period);
          final creditParties = await _salesAnalyticsService.getCreditLimitExceeded(
              companyGuid: guid);
          final topPaying = await _salesAnalyticsService.getTopPayingParties(
              companyGuid: guid);

          setState(() {
            _reportValue = realValue;
            _chartData = realChart;
            _salesPurchaseData = recvCombo;
            _creditLimitParties = creditParties;
            _topPayingParties = topPaying;
          });
          break;

        case ReportMetric.payable:
          final realValue =
              await _salesAnalyticsService.getTotalPayable(companyGuid: guid);
          final realChart = await _salesAnalyticsService.getPayableChart(
              companyGuid: guid, chartType: _chartType);
          final payCombo = await _salesAnalyticsService.getSalesPurchaseTrend(
              companyGuid: guid, period: period);
          final dueParties = await _salesAnalyticsService.getPaymentDueParties(
              companyGuid: guid);
          final topVendorsList = await _salesAnalyticsService.getTopVendors(
              companyGuid: guid);

          setState(() {
            _reportValue = realValue;
            _chartData = realChart;
            _salesPurchaseData = payCombo;
            _paymentDueParties = dueParties;
            _topVendors = topVendorsList;
          });
          break;

        case ReportMetric.stock:
          final realValue =
              await _salesAnalyticsService.getTotalStock(companyGuid: guid);
          final realChart = await _salesAnalyticsService.getStockChart(
              companyGuid: guid, chartType: _chartType);
          final stockCombo = await _salesAnalyticsService.getSalesPurchaseTrend(
              companyGuid: guid, period: period);

          setState(() {
            _reportValue = realValue;
            _chartData = realChart;
            _salesPurchaseData = stockCombo;
          });
          break;

        case ReportMetric.receipts:
          final realValue = await _salesAnalyticsService.getTotalReceipts(
              companyGuid: guid);
          final realChart = await _salesAnalyticsService.getReceiptsTrend(
              companyGuid: guid,
              
              chartType: _chartType,
              period: period);
          final rcptCombo = await _salesAnalyticsService.getSalesPurchaseTrend(
              companyGuid: guid, period: period);

          setState(() {
            _reportValue = realValue;
            _chartData = realChart;
            _salesPurchaseData = rcptCombo;
          });
          break;

        case ReportMetric.payments:
          final realValue = await _salesAnalyticsService.getTotalPayments(
              companyGuid: guid);
          final realChart = await _salesAnalyticsService.getPaymentsTrend(
              companyGuid: guid,
              
              chartType: _chartType,
              period: period);
          final pmtCombo = await _salesAnalyticsService.getSalesPurchaseTrend(
              companyGuid: guid, period: period);

          setState(() {
            _reportValue = realValue;
            _chartData = realChart;
            _salesPurchaseData = pmtCombo;
          });
          break;
      }

      debugPrint('========== END _loadReportData ==========');
    } catch (e, stack) {
      debugPrint('Error loading real data: $e');
      debugPrint('$stack');
    }
  }


  void _onDaysFilterChanged(int? days) {
    setState(() {
      _selectedDaysFilter = days;
      // Clear custom value if selecting a preset
      if (days == null || days == 30 || days == 60 || days == 90) {
        _customDaysValue = null;
      }
    });
  }

  void _showCustomDaysDialog() async {
    final controller = TextEditingController(
      text: _customDaysValue?.toString() ?? '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Custom Days Filter'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Days over limit',
            hintText: 'e.g., 45',
            suffixText: '+ days',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              Navigator.pop(context, value);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() {
        _customDaysValue = result;
        _selectedDaysFilter = result;
      });
    }
  }

  void _onFiscalYearChanged(FiscalYear fy) {
    setState(() {
      _selectedFiscalYear = fy;
      // In a real app, this would reload data for the selected FY
    });
  }

  // Payable filter handlers
  void _onPayableDaysFilterChanged(int? days) {
    setState(() {
      _payableSelectedDaysFilter = days;
      // Clear custom value if selecting a preset
      if (days == null || days == 30 || days == 60 || days == 90) {
        _payableCustomDaysValue = null;
      }
    });
  }

  void _showPayableCustomDaysDialog() async {
    final controller = TextEditingController(
      text: _payableCustomDaysValue?.toString() ?? '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Custom Days Filter'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Days overdue',
            hintText: 'e.g., 45',
            suffixText: '+ days',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              Navigator.pop(context, value);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() {
        _payableCustomDaysValue = result;
        _payableSelectedDaysFilter = result;
      });
    }
  }

  void _onPayableFiscalYearChanged(FiscalYear fy) {
    setState(() {
      _payableSelectedFiscalYear = fy;
      // In a real app, this would reload data for the selected FY
    });
  }

  Future<void> _pickCompanyLogo() async {
    if (_companyGuid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company not loaded yet. Please wait.')),
        );
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      await CompanyLogoService.saveLogo(_companyGuid!, bytes);
      if (mounted) {
        setState(() => _companyLogoBytes = bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company logo updated')),
        );
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open gallery: $e')),
        );
      }
    }
  }

  Future<void> _removeCompanyLogo() async {
    if (_companyGuid == null) return;
    await CompanyLogoService.deleteLogo(_companyGuid!);
    if (mounted) {
      setState(() => _companyLogoBytes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company logo removed')),
      );
    }
  }

  void _showLogoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Change Logo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCompanyLogo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove Logo',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _removeCompanyLogo();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a demo company when the DB is empty.
  Future<void> _ensureDemoCompany() async {
    final now = DateTime.now().toIso8601String();
    final testCompany = Company(
      guid: 'test-company-001',
      masterId: 1,
      alterId: 1,
      name: 'Smartfill Demo Company',
      startingFrom: '20240401',
      endingAt: '20250331',
      booksFrom: '20240401',
      state: 'Maharashtra',
      country: 'India',
      currencyName: 'INR',
      createdAt: now,
      updatedAt: now,
    );
    // Save directly to local DB
    final db = await DatabaseHelper.instance.database;
    await db.insert('companies', {
      'company_guid': testCompany.guid,
      'master_id': testCompany.masterId,
      'alter_id': testCompany.alterId,
      'company_name': testCompany.name,
      'starting_from': testCompany.startingFrom,
      'ending_at': testCompany.endingAt,
      'books_from': testCompany.booksFrom,
      'state': testCompany.state,
      'country': testCompany.country,
      'currency_name': testCompany.currencyName,
      'created_at': now,
      'updated_at': now,
    });
    await SecureStorage.saveCompanyGuid(testCompany.guid);
    debugPrint('✅ Demo company created');
    setState(() {
      _companyGuid = testCompany.guid;
      _company = testCompany;
    });
  }

  Future<void> _openExcelExport() async {
    // Auto-create demo company + seed data if database is empty
    if (_companyGuid == null) {
      await _ensureDemoCompany();
    }
    if (_companyGuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No company selected. Please select a company first.')),
      );
      return;
    }
    final companyGuid = _companyGuid!;
    final companyName = _company?.name ?? 'Company';

    debugPrint('');
    debugPrint('📤 Excel Export triggered');
    debugPrint('   companyGuid: $companyGuid');
    debugPrint('   companyName: $companyName');

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

      final fileName =
          '${companyName.replaceAll(' ', '_')}_stock_items.xlsx';

      debugPrint('✅ Excel generated: ${result.items.length} items, ${result.bytes.length} bytes');

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
      debugPrint('❌ Excel export error: $e');
      debugPrint('$stack');
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate Excel: $e')),
      );
    }
  }

  void _openPdfExport() async {
    // final company = _company;
    // if (company == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text("Company data not loaded yet")),
    //   );
    //   return;
    // }

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
      final cards = _getReportCards(forPdf: true);
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
                  child: SizedBox(
                    width: width,
                    child: card,
                  ),
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
            metric: _selectedMetric,
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

  /// Long-press on Excel FAB: seeds test data, then opens Excel export.
  Future<void> _seedAndExportExcel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
      ),
    );

    try {
      // Auto-create a test company if none exists
      if (_companyGuid == null) {
        debugPrint('🏢 No company found — creating test company...');
        await _ensureDemoCompany();
        debugPrint('✅ Test company created');
      }

      debugPrint('✅ Ready — now opening Excel export');

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      await _openExcelExport();
    } catch (e, stack) {
      debugPrint('❌ Seed error: $e');
      debugPrint('$stack');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seed failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onLongPress: _seedAndExportExcel,
              child: FloatingActionButton.small(
                heroTag: 'excel',
                onPressed: _openExcelExport,
                backgroundColor: const Color(0xFF16A34A),
                child: const Icon(Icons.table_chart, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'pdf',
              onPressed: _openPdfExport,
              backgroundColor: AppColors.blue,
              child: const Icon(Icons.picture_as_pdf, color: Colors.white),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 12),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                ),
                child: DetailSearchBar(
                  controller: _searchController,
                  placeholder: 'Search metrics...',
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(height: 12),

              // Metric chips
              ReportMetricChips(
                selected: _selectedMetric,
                metrics: _filteredMetrics,
                onSelected: _onMetricChanged,
              ),
              const SizedBox(height: 16),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: _buildReportContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns individual card widgets for both screen display and PDF capture.
  /// When [forPdf] is true, large party list cards are split into smaller
  /// batches (max 5 per card) so each fits on a single PDF page.
  List<Widget> _getReportCards({bool forPdf = false}) {
    return [
      // Date range selector — skipped in PDF
      if (!forPdf)
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

      // Value card
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
        ),
        child: ReportValueCard(
          value: _reportValue,
          icon: _selectedMetric.icon,
          iconBgColor: _selectedMetric.iconBgColor,
        ),
      ),

      // Chart section
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
        ),
        child: ChartSectionCard(
          title: _chartData.title,
          selectedChartType: _chartType,
          availableChartTypes: _selectedMetric.applicableChartTypes,
          onChartTypeChanged: (type) {
            setState(() {
              _chartType = type;
            });
            _loadReportData();
          },
          selectedPeriodIndex: _chartPeriodIndex,
          onPeriodChanged: (index) {
            setState(() {
              _chartPeriodIndex = index;
            });
            _loadReportData();
          },
          chart: ReportChart(
            data: _chartData,
            height: 200,
          ),
          legends: _chartData.legends,
          showSelectors: !forPdf,
        ),
      ),

      // Sales vs Purchase chart for Sales metric
      if (_selectedMetric == ReportMetric.sales) ...[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
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
                Text(
                  _salesPurchaseData.title,
                  style: AppTypography.cardLabel,
                ),
                const SizedBox(height: 16),
                (_salesPurchaseData.dataPoints.isEmpty)
                    ? SizedBox(
                        height: 220,
                        child: Center(
                          child: Text(
                            'No Data',
                            style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ) ??
                                TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : SalesPurchaseComboChart(
                        data: _salesPurchaseData,
                        height: 220,
                      )
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: SalesPurchaseProfitBarChart(
              data: _revExpProfitData,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: SalesPurchaseStackedBarChart(
              data: _salesPurchaseData,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: RevenueExpenseProfitGridChart(
              data: _revExpProfitData,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: SalesPurchaseProfitGauges(
              data: _revExpProfitData,
            ),
          ),
        ),
      ],

      // Revenue vs Expense chart for Profit metric
      if (_selectedMetric == ReportMetric.profit) ...[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: RevenueExpenseProfitChart(
              data: _revExpProfitData,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: RevenueExpenseProfitPieChart(
              data: _revExpProfitData,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: SalesPurchaseProfitBarChart(
              data: _revExpProfitData,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: RevenueExpenseProfitGridChart(
              data: _revExpProfitData,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: SalesPurchaseProfitGauges(
              data: _revExpProfitData,
            ),
          ),
        ),
      ],

      // Additional cards for Receivable metric
      if (_selectedMetric == ReportMetric.receivable) ...[
        if (forPdf) ...[
          // Split into batches per card for PDF
          // First batch (with header+filters) = 7, subsequent (no header) = 10
          for (var i = 0;
              i < _creditLimitParties.length;
              i += (i == 0 ? 7 : 10))
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
              ),
              child: CreditLimitExceededCard(
                parties: _creditLimitParties.sublist(
                  i,
                  min(i + (i == 0 ? 7 : 10),
                      _creditLimitParties.length),
                ),
                selectedDaysFilter: _selectedDaysFilter,
                customDaysValue: _customDaysValue,
                onFilterChanged: _onDaysFilterChanged,
                onCustomTap: _showCustomDaysDialog,
                showHeader: i == 0,
                totalPartyCount: _creditLimitParties.length,
              ),
            ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: CreditLimitExceededCard(
              parties: _creditLimitParties,
              selectedDaysFilter: _selectedDaysFilter,
              customDaysValue: _customDaysValue,
              onFilterChanged: _onDaysFilterChanged,
              onCustomTap: _showCustomDaysDialog,
            ),
          ),
        ],
        if (forPdf) ...[
          for (var j = 0;
              j <
                  _topPayingParties
                      .length;
              j += (j == 0 ? 3 : 10))
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
              ),
              child: TopPayingPartiesCard(
                parties:
                    _topPayingParties
                        .sublist(
                  j,
                  min(
                      j + (j == 0 ? 3 : 10),
                      _topPayingParties
                          .length),
                ),
                selectedFiscalYear: _selectedFiscalYear,
                fiscalYearOptions: _fiscalYearOptions,
                onFiscalYearChanged: _onFiscalYearChanged,
                showHeader: j == 0,
                startRank: j,
              ),
            ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: TopPayingPartiesCard(
              parties: _topPayingParties,
              selectedFiscalYear: _selectedFiscalYear,
              fiscalYearOptions: _fiscalYearOptions,
              onFiscalYearChanged: _onFiscalYearChanged,
            ),
          ),
        ],
      ],

      // Additional cards for Payable metric
      if (_selectedMetric == ReportMetric.payable) ...[
        if (forPdf) ...[
          // Split into batches per card for PDF
          // First batch (with header+filters) = 7, subsequent (no header) = 10
          for (var i = 0;
              i < _paymentDueParties.length;
              i += (i == 0 ? 7 : 10))
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
              ),
              child: PaymentDueCard(
                parties: _paymentDueParties.sublist(
                  i,
                  min(i + (i == 0 ? 7 : 10), _paymentDueParties.length),
                ),
                selectedDaysFilter: _payableSelectedDaysFilter,
                customDaysValue: _payableCustomDaysValue,
                onFilterChanged: _onPayableDaysFilterChanged,
                onCustomTap: _showPayableCustomDaysDialog,
                showHeader: i == 0,
                totalPartyCount: _paymentDueParties.length,
              ),
            ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: PaymentDueCard(
              parties: _paymentDueParties,
              selectedDaysFilter: _payableSelectedDaysFilter,
              customDaysValue: _payableCustomDaysValue,
              onFilterChanged: _onPayableDaysFilterChanged,
              onCustomTap: _showPayableCustomDaysDialog,
            ),
          ),
        ],
        if (forPdf) ...[
          for (var j = 0;
              j <
                  _topVendors
                      .length;
              j += (j == 0 ? 3 : 10))
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
              ),
              child: TopVendorsCard(
                vendors:
                    _topVendors
                        .sublist(
                  j,
                  min(
                      j + (j == 0 ? 3 : 10),
                      _topVendors
                          .length),
                ),
                selectedFiscalYear: _payableSelectedFiscalYear,
                fiscalYearOptions: _fiscalYearOptions,
                onFiscalYearChanged: _onPayableFiscalYearChanged,
                showHeader: j == 0,
                startRank: j,
              ),
            ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: TopVendorsCard(
              vendors:
                  _topVendors,
              selectedFiscalYear: _payableSelectedFiscalYear,
              fiscalYearOptions: _fiscalYearOptions,
              onFiscalYearChanged: _onPayableFiscalYearChanged,
            ),
          ),
        ],
      ],
    ];
  }

  Widget _buildReportContent() {
    final cards = _getReportCards();
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i < cards.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        12,
        AppSpacing.pagePadding,
        0,
      ),
      child: Row(
        children: [
          Text(
            'Reports',
            style: AppTypography.pageTitle,
          ),
          const Spacer(),
          // Company logo picker
          GestureDetector(
            onTap: _pickCompanyLogo,
            onLongPress:
                _companyLogoBytes != null ? () => _showLogoOptions() : null,
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _companyLogoBytes != null
                    ? Colors.transparent
                    : AppColors.blue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _companyLogoBytes != null
                  ? Image.memory(
                      _companyLogoBytes!,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.add_a_photo,
                      size: 16,
                      color: Colors.white,
                    ),
            ),
          ),
          // Date range indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.string(
                  AppIcons.calendar,
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _dateRange.displayText,
                  style: AppTypography.badge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
