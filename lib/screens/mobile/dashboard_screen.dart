import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../icons/app_icons.dart';
import '../widgets/dashboard_widgets.dart';
import '../models/kpi_metric.dart';
import '../models/report_data.dart';
import '../service/sales/sales_service.dart';
import '../service/aws_sync_service.dart';
import '../service/data_sync_service.dart';
import '../utils/secure_storage.dart';
import '../models/company_model.dart';
import '../main.dart';
import 'net_sales_detail_screen.dart';
import 'kpi_manager_screen.dart';
import 'reports_overview_screen.dart';
import 'metric_detail_screen.dart';
import 'outstanding_detail_screen.dart';
import 'mobile_profile_tab.dart';

// ─────────────────────────────────────────────
//  DASHBOARD METRIC DATA (private)
// ─────────────────────────────────────────────
class _MetricData {
  final String icon;
  final Color iconBgColor;
  final String label;
  final String value;
  final String unit;
  final String change;
  final bool isPositive;
  const _MetricData(
    this.icon,
    this.iconBgColor,
    this.label,
    this.value,
    this.unit,
    this.change,
    this.isPositive,
  );
}


// ─────────────────────────────────────────────
//  HEADER ICON BUTTON (Bell, Settings)
// ─────────────────────────────────────────────
class _HeaderIconButton extends StatelessWidget {
  final String svgIcon;
  final bool showBadge;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.svgIcon,
    this.showBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          boxShadow: AppShadows.headerIcon,
        ),
        child: Stack(
          children: [
            Center(
              child: SvgPicture.string(svgIcon, width: 17, height: 17),
            ),
            if (showBadge)
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════
//  DASHBOARD SCREEN
// ═════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'YTD';
  DateTime? _customStart;
  DateTime? _customEnd;
  int _navIndex = 0;
  List<KpiConfig> _kpiConfigs = [];
  bool _kpiLoading = true;

  // Dynamic metric data loaded from DB
  List<_MetricData> _dashboardMetrics = [];
  String _revenue = '';
  String _expenses = '';
  String _net = '';

  bool _isSyncing = false;

  final SalesAnalyticsService _salesService = SalesAnalyticsService();
  String? _companyGuid;
  Company? _company;

  // ─── Lifecycle ───────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadKpiConfigs();
    _loadCompanyAndMetrics();
  }

  Future<void> _loadCompanyAndMetrics() async {
    // Use globally loaded company from AppState
    final company = AppState.selectedCompany;
    if (company != null) {
      _companyGuid = company.guid;
      _company = company;
    }
    await _loadMetricData();
  }

  /// Parse company date string (ISO "2024-04-01" or Tally "20240401") into DateTime.
  DateTime? _parseCompanyDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    // ISO format: 2024-04-01
    if (dateStr.contains('-')) {
      return DateTime.tryParse(dateStr);
    }
    // Tally format: 20240401
    if (dateStr.length == 8) {
      final y = int.tryParse(dateStr.substring(0, 4));
      final m = int.tryParse(dateStr.substring(4, 6));
      final d = int.tryParse(dateStr.substring(6, 8));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return null;
  }

  /// Get the company's financial year start date from DB, fallback to April 1.
  DateTime _companyFYStart() {
    final parsed = _parseCompanyDate(_company?.startingFrom);
    if (parsed != null) return parsed;
    // Fallback: assume April 1 of current/previous calendar year
    final now = DateTime.now();
    return now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
  }

  /// Get the company's financial year end date from DB, fallback to March 31.
  DateTime _companyFYEnd() {
    final parsed = _parseCompanyDate(_company?.endingAt);
    if (parsed != null) return parsed;
    final now = DateTime.now();
    return now.month >= 4 ? DateTime(now.year + 1, 3, 31) : DateTime(now.year, 3, 31);
  }

  /// Compute (start, end) date range based on the selected period label.
  (DateTime, DateTime) _dateRangeForPeriod(String period) {
    final now = DateTime.now();
    final fyStart = _companyFYStart();
    final fyEnd = _companyFYEnd();
    // FY start month from company (e.g. 4 for April, 1 for January)
    final fyMonth = fyStart.month;

    switch (period) {
      case 'This Month':
        return (DateTime(now.year, now.month, 1), now);
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0); // last day of prev month
        return (lastMonth, lastDay);
      case 'Quarter':
        // Fiscal quarter based on company's FY start month
        final fiscalMonth = now.month >= fyMonth ? now.month : now.month + 12;
        final qStart = ((fiscalMonth - fyMonth) ~/ 3) * 3 + fyMonth;
        final qStartMonth = qStart > 12 ? qStart - 12 : qStart;
        final qStartYear = qStart > 12 ? now.year : (now.month >= fyMonth ? now.year : now.year - 1);
        return (DateTime(qStartYear, qStartMonth, 1), now);
      case 'YTD':
        // Use company's actual FY start date
        return (fyStart, now.isBefore(fyEnd) ? now : fyEnd);
      case 'Last Year':
        // Previous FY: shift both start and end back by 1 year
        final prevFyStart = DateTime(fyStart.year - 1, fyStart.month, fyStart.day);
        final prevFyEnd = DateTime(fyEnd.year - 1, fyEnd.month, fyEnd.day);
        return (prevFyStart, prevFyEnd);
      case 'Custom':
        if (_customStart != null && _customEnd != null) {
          return (_customStart!, _customEnd!);
        }
        return (DateTime(now.year, now.month, 1), now);
      default:
        return (DateTime(now.year, now.month, 1), now);
    }
  }

  Future<void> _loadMetricData() async {
    if (_companyGuid == null) return;

    final guid = _companyGuid!;
    final (start, end) = _dateRangeForPeriod(_selectedPeriod);
    developer.log(
      '=== DASHBOARD LOAD === company="${_company?.name}" guid=$guid period=$_selectedPeriod '
      'FY: ${_company?.startingFrom} → ${_company?.endingAt} '
      'range: $start → $end',
      name: 'Dashboard',
    );

    try {
      final salesVal = await _salesService.getTotalSales(
        companyGuid: guid);
      final purchaseVal = await _salesService.getTotalPurchase(
        companyGuid: guid);
      final profitVal = await _salesService.getTotalProfit(
        companyGuid: guid);
      final receivableVal = await _salesService.getTotalReceivable(
        companyGuid: guid);

      if (!mounted) return;
      setState(() {
        _dashboardMetrics = [
          _MetricData(
            AppIcons.barChart, AppColors.iconBgBlue, 'Net Sales',
            salesVal.primaryValue, salesVal.primaryUnit,
            salesVal.changePercent, salesVal.isPositiveChange,
          ),
          _MetricData(
            AppIcons.receipt, AppColors.iconBgAmber, 'Net Purchase',
            purchaseVal.primaryValue, purchaseVal.primaryUnit,
            purchaseVal.changePercent, purchaseVal.isPositiveChange,
          ),
          _MetricData(
            AppIcons.arrowUpCircle, AppColors.iconBgGreen, 'Gross Profit',
            profitVal.primaryValue, profitVal.primaryUnit,
            profitVal.changePercent, profitVal.isPositiveChange,
          ),
          _MetricData(
            AppIcons.users, AppColors.iconBgPurple, 'Receivables',
            receivableVal.primaryValue, receivableVal.primaryUnit,
            receivableVal.changePercent, receivableVal.isPositiveChange,
          ),
        ];

        _revenue = '${salesVal.primaryValue} ${salesVal.primaryUnit}';
        _expenses = '${purchaseVal.primaryValue} ${purchaseVal.primaryUnit}';
        _net = '${profitVal.primaryValue} ${profitVal.primaryUnit}';
      });
      // Also refresh KPI values with real data
      _refreshKpiValues(_kpiConfigs);
    } catch (e) {
      debugPrint('Error loading dashboard metrics: $e');
    }
  }

  Future<void> _loadKpiConfigs() async {
    final configs = await KpiConfigStorage.load();
    setState(() {
      _kpiConfigs = configs;
      _kpiLoading = false;
    });
    _refreshKpiValues(configs);
  }

  /// Map KPI metricId to ReportMetric enum
  ReportMetric? _metricFromId(String id) {
    switch (id) {
      case 'sales': return ReportMetric.sales;
      case 'purchase': return ReportMetric.purchase;
      case 'profit': return ReportMetric.profit;
      case 'receivable': return ReportMetric.receivable;
      case 'payable': return ReportMetric.payable;
      case 'receipts': return ReportMetric.receipts;
      case 'payments': return ReportMetric.payments;
      case 'stock': return ReportMetric.stock;
      default: return null;
    }
  }

  /// Fetch real values from DB for each active KPI config
  Future<void> _refreshKpiValues(List<KpiConfig> configs) async {
    if (_companyGuid == null || configs.isEmpty) return;

    final guid = _companyGuid!;
    final (start, end) = _dateRangeForPeriod(_selectedPeriod);
    final updated = <KpiConfig>[];

    for (final config in configs) {
      final metric = _metricFromId(config.metricId);
      if (metric == null) {
        updated.add(config);
        continue;
      }
      try {
        final rv = await _salesService.getReportValueForMetric(
          metric,
          companyGuid: guid,
        );
        updated.add(config.copyWith(
          value: '${rv.primaryValue} ${rv.primaryUnit}',
          sub: _selectedPeriod,
          badge: rv.changePercent.isNotEmpty ? rv.changePercent : null,
          isPositive: rv.isPositiveChange,
        ));
      } catch (_) {
        updated.add(config);
      }
    }

    if (mounted) {
      setState(() => _kpiConfigs = updated);
      KpiConfigStorage.save(updated);
    }
  }

  void _updateKpiConfigs(List<KpiConfig> newConfigs) {
    setState(() => _kpiConfigs = newConfigs);
    KpiConfigStorage.save(newConfigs);
    _refreshKpiValues(newConfigs);
  }

  // ─── Sync ───────────────────────────────────

  Future<void> _onSyncTap() async {
    if (_isSyncing || _companyGuid == null) return;
    setState(() => _isSyncing = true);
    try {
      await DataSyncService.instance.syncCompany(
        _companyGuid!,
        onProgress: (tableName, progress) {
          developer.log('Syncing $tableName...', name: 'Dashboard');
        },
      );
      if (mounted) await _loadMetricData();
    } catch (e) {
      developer.log('⚠️ Manual sync failed: $e', name: 'Dashboard');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showLocalDataInfo() async {
    if (_companyGuid == null) return;
    final counts = await DataSyncService.instance.getLocalRowCounts(_companyGuid!);
    final lastSync = DataSyncService.instance.lastSyncTime;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Local SQLite Data'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Company: ${_company?.name ?? _companyGuid}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (lastSync != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Last synced: ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')} on ${lastSync.day}/${lastSync.month}/${lastSync.year}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              const Divider(),
              ...counts.entries.map((e) {
                final hasData = e.value > 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 13)),
                      Text(
                        e.value == -1 ? 'N/A' : '${e.value} rows',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasData ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Text(
                'Mode: ${AppState.isOffline ? "OFFLINE" : "ONLINE"}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppState.isOffline ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ──────────────────────────────

  void _onBottomNavTap(int index) {
    setState(() => _navIndex = index);
  }

  void _showCompanyPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select Company',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              ...AppState.companies.map((company) {
                final isSelected =
                    company.guid == AppState.selectedCompany?.guid;
                return ListTile(
                  title: Text(company.name),
                  subtitle: Text(company.email ?? company.state ?? ''),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      AppState.selectedCompany = company;
                      _companyGuid = company.guid;
                      _company = company;
                      _dashboardMetrics = [];
                      _revenue = '';
                      _expenses = '';
                      _net = '';
                    });
                    // Persist for offline fallback
                    await SecureStorage.saveCompanyGuid(company.guid);
                    final schema = AwsSyncService.instance.getSchemaName(company.guid);
                    await AwsSyncService.instance.createViewsIfNeeded(schema);
                    // Sync this company's data to local SQLite (fire and forget)
                    // DataSyncService.instance.syncCompany(company.guid).catchError((e) {
                    //   developer.log('⚠️ Background sync failed: $e', name: 'Dashboard');
                    // });
                    _loadMetricData();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openKpiManager() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => KpiManagerScreen(
          currentConfigs: _kpiConfigs,
          onSave: _updateKpiConfigs,
        ),
      ),
    );
  }

  static const _metricMapping = [
    ReportMetric.sales,
    ReportMetric.purchase,
    ReportMetric.profit,
    ReportMetric.receivable,
  ];

  void _navigateToDetail(int index, _MetricData metric) {
    final reportMetric = _metricMapping[index];

    if (index == 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NetSalesDetailScreen(
            totalValue: metric.value,
            unit: metric.unit,
            changePercent: metric.change,
            isPositive: metric.isPositive,
          ),
        ),
      );
    } else if (reportMetric == ReportMetric.receivable) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OutstandingDetailScreen(metric: reportMetric),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MetricDetailScreen(metric: reportMetric),
        ),
      );
    }
  }

  // ─── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            IndexedStack(
              index: _navIndex,
              children: [
                // 0 – Home
                _buildHomePage(),
                // 1 – Reports (keyed by company GUID so it rebuilds on company switch)
                ReportsOverviewScreen(key: ValueKey(_companyGuid)),
                // 2 – Profile
                const MobileProfileTab(),
              ],
            ),
            // Floating bottom nav
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DashboardBottomNav(
                activeIndex: _navIndex,
                onTap: _onBottomNavTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  HOME PAGE (scrollable content)
  // ═══════════════════════════════════════════
  Widget _buildHomePage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        bottom: 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          // 1. Company Name + Notification + Settings
          _buildCompanyBar(),
          // 2. Date Range Selector
          _buildDateRangeSelector(),
          // 3. Quick Actions (horizontal scroll)
          _buildQuickActions(),
          // 4. Metric Cards (2×2 grid)
          _buildMetricGrid(),
          // 5. Key Metrics (KPI rows)
          _buildKeyMetrics(),
          // 6. Revenue Breakdown
          RevenueBreakdown(
            revenue: _revenue,
            expenses: _expenses,
            net: _net,
          ),
          // 7. Ask Anything (AI bar)
          const AiAskBar(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  1. COMPANY BAR (name + notification + settings)
  // ═══════════════════════════════════════════
  Widget _buildCompanyBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        8,
        AppSpacing.pagePadding,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title + Company selector
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DASHBOARD', style: AppTypography.dashboardLabel),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: _showCompanyPicker,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider, width: 1),
                      boxShadow: AppShadows.headerIcon,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            AppState.selectedCompany?.name ?? 'Select Company',
                            style: AppTypography.companyName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        SvgPicture.string(AppIcons.chevronDown,
                            width: 16, height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Action icons
          Row(
            children: [
              GestureDetector(
                onTap: _onSyncTap,
                onLongPress: _showLocalDataInfo,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F8),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: _isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                svgIcon: AppIcons.bell,
                showBadge: true,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                svgIcon: AppIcons.settings,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  2. DATE RANGE SELECTOR
  // ═══════════════════════════════════════════
  Widget _buildDateRangeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        0,
        AppSpacing.pagePadding,
        0,
      ),
      child: PeriodSelector(
        selected: _selectedPeriod,
        onChanged: (v) async {
          if (v == 'Custom') {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2015),
              lastDate: DateTime(2030),
              initialDateRange: _customStart != null && _customEnd != null
                  ? DateTimeRange(start: _customStart!, end: _customEnd!)
                  : null,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: const Color(0xFF2D8BE0),
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null && mounted) {
              setState(() {
                _selectedPeriod = 'Custom';
                _customStart = picked.start;
                _customEnd = picked.end;
              });
              _loadMetricData();
            }
          } else {
            setState(() => _selectedPeriod = v);
            _loadMetricData();
          }
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  3. QUICK ACTIONS (horizontal scroll)
  // ═══════════════════════════════════════════
  Widget _buildQuickActions() {
    const actions = ReportMetric.values;

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: Text(
              'Quick Actions',
              style: AppTypography.cardLabel,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
              ),
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final metric = actions[index];
                return GestureDetector(
                  onTap: () {
                    final isOutstanding =
                        metric == ReportMetric.receivable ||
                        metric == ReportMetric.payable;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => isOutstanding
                            ? OutstandingDetailScreen(metric: metric)
                            : MetricDetailScreen(metric: metric),
                      ),
                    );
                  },
                  child: Container(
                    width: 84,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: metric.iconBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: SvgPicture.string(
                              metric.icon,
                              width: 15,
                              height: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          metric.displayName,
                          style: AppTypography.cardLabel
                              .copyWith(letterSpacing: 0.2),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  4. METRIC CARDS (2×2 grid)
  // ═══════════════════════════════════════════
  Widget _buildMetricGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Wrap(
        spacing: AppSpacing.cardGap,
        runSpacing: AppSpacing.cardGap,
        children: _dashboardMetrics.asMap().entries.map((entry) {
          final index = entry.key;
          final m = entry.value;
          return SizedBox(
            width: (MediaQuery.of(context).size.width -
                    AppSpacing.pagePadding * 2 -
                    AppSpacing.cardGap) /
                2,
            child: MetricCard(
              svgIcon: m.icon,
              iconBgColor: m.iconBgColor,
              label: m.label,
              value: m.value,
              unit: m.unit,
              change: m.change,
              isPositive: m.isPositive,
              onTap: () => _navigateToDetail(index, m),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  4. KEY METRICS (Dynamic KPI rows)
  // ═══════════════════════════════════════════
  Widget _buildKeyMetrics() {
    if (_kpiLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.sectionGap,
          AppSpacing.pagePadding,
          0,
        ),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_kpiConfigs.isEmpty) {
      return KpiSection(
        onEditTap: _openKpiManager,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.dashboard_outlined,
                  size: 48,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No KPIs configured',
                  style: AppTypography.itemTitle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Edit to add metrics',
                  style: AppTypography.itemSubtitle,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return KpiSection(
      onEditTap: _openKpiManager,
      children: _kpiConfigs.asMap().entries.map((entry) {
        final i = entry.key;
        final config = entry.value;
        final metric = getMetricById(config.metricId);

        if (metric == null) return const SizedBox.shrink();

        return KeyMetricRow(
          svgIcon: metric.icon,
          iconBg: metric.iconBg,
          label: metric.name,
          value: config.value,
          sub: config.sub,
          badge: config.badge,
          isPositive: config.isPositive,
          showDivider: i < _kpiConfigs.length - 1,
          onTap: () {
            // Future: Navigate to detail page for this KPI
          },
        );
      }).toList(),
    );
  }
}
