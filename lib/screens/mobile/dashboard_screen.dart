// import 'dart:developer' as developer;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import '../theme/app_theme.dart';
// import '../icons/app_icons.dart';
// import '../../widgets/dashboard_widgets.dart';
// import '../../models/kpi_metric.dart';
// import '../../models/report_data.dart';
// import '../service/sales/sales_service.dart';
// import '../../services/aws_sync_service.dart';
// import '../service/data_sync_service.dart';
// import '../../utils/secure_storage.dart';
// import '../../models/company_model.dart';
// import '../main.dart';
// import 'net_sales_detail_screen.dart';
// import 'kpi_manager_screen.dart';
// import 'reports_overview_screen.dart';
// import 'metric_detail_screen.dart';
// import 'outstanding_detail_screen.dart';
// import 'mobile_profile_tab.dart';

// // ─────────────────────────────────────────────
// //  DASHBOARD METRIC DATA (private)
// // ─────────────────────────────────────────────
// class _MetricData {
//   final String icon;
//   final Color iconBgColor;
//   final String label;
//   final String value;
//   final String unit;
//   final String change;
//   final bool isPositive;
//   const _MetricData(
//     this.icon,
//     this.iconBgColor,
//     this.label,
//     this.value,
//     this.unit,
//     this.change,
//     this.isPositive,
//   );
// }


// // ─────────────────────────────────────────────
// //  HEADER ICON BUTTON (Bell, Settings)
// // ─────────────────────────────────────────────
// class _HeaderIconButton extends StatelessWidget {
//   final String svgIcon;
//   final bool showBadge;
//   final VoidCallback onTap;

//   const _HeaderIconButton({
//     required this.svgIcon,
//     this.showBadge = false,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 38,
//         height: 38,
//         decoration: BoxDecoration(
//           color: AppColors.surface,
//           borderRadius: BorderRadius.circular(11),
//           boxShadow: AppShadows.headerIcon,
//         ),
//         child: Stack(
//           children: [
//             Center(
//               child: SvgPicture.string(svgIcon, width: 17, height: 17),
//             ),
//             if (showBadge)
//               Positioned(
//                 top: 8,
//                 right: 9,
//                 child: Container(
//                   width: 6,
//                   height: 6,
//                   decoration: BoxDecoration(
//                     color: AppColors.red,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.white, width: 1.5),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ═════════════════════════════════════════════
// //  DASHBOARD SCREEN
// // ═════════════════════════════════════════════
// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   String _selectedPeriod = 'YTD';
//   DateTime? _customStart;
//   DateTime? _customEnd;
//   int _navIndex = 0;
//   List<KpiConfig> _kpiConfigs = [];
//   bool _kpiLoading = true;

//   // Dynamic metric data loaded from DB
//   List<_MetricData> _dashboardMetrics = [];
//   String _revenue = '';
//   String _expenses = '';
//   String _net = '';

//   bool _isSyncing = false;

//   final SalesAnalyticsService _salesService = SalesAnalyticsService();
//   String? _companyGuid;
//   Company? _company;

//   // ─── Lifecycle ───────────────────────────────

//   @override
//   void initState() {
//     super.initState();
//     _loadKpiConfigs();
//     _loadCompanyAndMetrics();
//   }

//   Future<void> _loadCompanyAndMetrics() async {
//     // Use globally loaded company from AppState
//     final company = AppState.selectedCompany;
//     if (company != null) {
//       _companyGuid = company.guid;
//       _company = company;
//     }
//     await _loadMetricData();
//   }

//   /// Parse company date string (ISO "2024-04-01" or Tally "20240401") into DateTime.
//   DateTime? _parseCompanyDate(String? dateStr) {
//     if (dateStr == null || dateStr.isEmpty) return null;
//     // ISO format: 2024-04-01
//     if (dateStr.contains('-')) {
//       return DateTime.tryParse(dateStr);
//     }
//     // Tally format: 20240401
//     if (dateStr.length == 8) {
//       final y = int.tryParse(dateStr.substring(0, 4));
//       final m = int.tryParse(dateStr.substring(4, 6));
//       final d = int.tryParse(dateStr.substring(6, 8));
//       if (y != null && m != null && d != null) return DateTime(y, m, d);
//     }
//     return null;
//   }

//   /// Get the company's financial year start date from DB, fallback to April 1.
//   DateTime _companyFYStart() {
//     final parsed = _parseCompanyDate(_company?.startingFrom);
//     if (parsed != null) return parsed;
//     // Fallback: assume April 1 of current/previous calendar year
//     final now = DateTime.now();
//     return now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
//   }

//   /// Get the company's financial year end date from DB, fallback to March 31.
//   DateTime _companyFYEnd() {
//     final parsed = _parseCompanyDate(_company?.endingAt);
//     if (parsed != null) return parsed;
//     final now = DateTime.now();
//     return now.month >= 4 ? DateTime(now.year + 1, 3, 31) : DateTime(now.year, 3, 31);
//   }

//   /// Compute (start, end) date range based on the selected period label.
//   (DateTime, DateTime) _dateRangeForPeriod(String period) {
//     final now = DateTime.now();
//     final fyStart = _companyFYStart();
//     final fyEnd = _companyFYEnd();
//     // FY start month from company (e.g. 4 for April, 1 for January)
//     final fyMonth = fyStart.month;

//     switch (period) {
//       case 'This Month':
//         return (DateTime(now.year, now.month, 1), now);
//       case 'Last Month':
//         final lastMonth = DateTime(now.year, now.month - 1, 1);
//         final lastDay = DateTime(now.year, now.month, 0); // last day of prev month
//         return (lastMonth, lastDay);
//       case 'Quarter':
//         // Fiscal quarter based on company's FY start month
//         final fiscalMonth = now.month >= fyMonth ? now.month : now.month + 12;
//         final qStart = ((fiscalMonth - fyMonth) ~/ 3) * 3 + fyMonth;
//         final qStartMonth = qStart > 12 ? qStart - 12 : qStart;
//         final qStartYear = qStart > 12 ? now.year : (now.month >= fyMonth ? now.year : now.year - 1);
//         return (DateTime(qStartYear, qStartMonth, 1), now);
//       case 'YTD':
//         // Use company's actual FY start date
//         return (fyStart, now.isBefore(fyEnd) ? now : fyEnd);
//       case 'Last Year':
//         // Previous FY: shift both start and end back by 1 year
//         final prevFyStart = DateTime(fyStart.year - 1, fyStart.month, fyStart.day);
//         final prevFyEnd = DateTime(fyEnd.year - 1, fyEnd.month, fyEnd.day);
//         return (prevFyStart, prevFyEnd);
//       case 'Custom':
//         if (_customStart != null && _customEnd != null) {
//           return (_customStart!, _customEnd!);
//         }
//         return (DateTime(now.year, now.month, 1), now);
//       default:
//         return (DateTime(now.year, now.month, 1), now);
//     }
//   }

//   Future<void> _loadMetricData() async {
//     if (_companyGuid == null) return;

//     final guid = _companyGuid!;
//     final (start, end) = _dateRangeForPeriod(_selectedPeriod);
//     developer.log(
//       '=== DASHBOARD LOAD === company="${_company?.name}" guid=$guid period=$_selectedPeriod '
//       'FY: ${_company?.startingFrom} → ${_company?.endingAt} '
//       'range: $start → $end',
//       name: 'Dashboard',
//     );

//     try {
//       final salesVal = await _salesService.getTotalSales(
//         companyGuid: guid);
//       final purchaseVal = await _salesService.getTotalPurchase(
//         companyGuid: guid);
//       final profitVal = await _salesService.getTotalProfit(
//         companyGuid: guid);
//       final receivableVal = await _salesService.getTotalReceivable(
//         companyGuid: guid);

//       if (!mounted) return;
//       setState(() {
//         _dashboardMetrics = [
//           _MetricData(
//             AppIcons.barChart, AppColors.iconBgBlue, 'Net Sales',
//             salesVal.primaryValue, salesVal.primaryUnit,
//             salesVal.changePercent, salesVal.isPositiveChange,
//           ),
//           _MetricData(
//             AppIcons.receipt, AppColors.iconBgAmber, 'Net Purchase',
//             purchaseVal.primaryValue, purchaseVal.primaryUnit,
//             purchaseVal.changePercent, purchaseVal.isPositiveChange,
//           ),
//           _MetricData(
//             AppIcons.arrowUpCircle, AppColors.iconBgGreen, 'Gross Profit',
//             profitVal.primaryValue, profitVal.primaryUnit,
//             profitVal.changePercent, profitVal.isPositiveChange,
//           ),
//           _MetricData(
//             AppIcons.users, AppColors.iconBgPurple, 'Receivables',
//             receivableVal.primaryValue, receivableVal.primaryUnit,
//             receivableVal.changePercent, receivableVal.isPositiveChange,
//           ),
//         ];

//         _revenue = '${salesVal.primaryValue} ${salesVal.primaryUnit}';
//         _expenses = '${purchaseVal.primaryValue} ${purchaseVal.primaryUnit}';
//         _net = '${profitVal.primaryValue} ${profitVal.primaryUnit}';
//       });
//       // Also refresh KPI values with real data
//       _refreshKpiValues(_kpiConfigs);
//     } catch (e) {
//       debugPrint('Error loading dashboard metrics: $e');
//     }
//   }

//   Future<void> _loadKpiConfigs() async {
//     final configs = await KpiConfigStorage.load();
//     setState(() {
//       _kpiConfigs = configs;
//       _kpiLoading = false;
//     });
//     _refreshKpiValues(configs);
//   }

//   /// Map KPI metricId to ReportMetric enum
//   ReportMetric? _metricFromId(String id) {
//     switch (id) {
//       case 'sales': return ReportMetric.sales;
//       case 'purchase': return ReportMetric.purchase;
//       case 'profit': return ReportMetric.profit;
//       case 'receivable': return ReportMetric.receivable;
//       case 'payable': return ReportMetric.payable;
//       case 'receipts': return ReportMetric.receipts;
//       case 'payments': return ReportMetric.payments;
//       case 'stock': return ReportMetric.stock;
//       default: return null;
//     }
//   }

//   /// Fetch real values from DB for each active KPI config
//   Future<void> _refreshKpiValues(List<KpiConfig> configs) async {
//     if (_companyGuid == null || configs.isEmpty) return;

//     final guid = _companyGuid!;
//     final (start, end) = _dateRangeForPeriod(_selectedPeriod);
//     final updated = <KpiConfig>[];

//     for (final config in configs) {
//       final metric = _metricFromId(config.metricId);
//       if (metric == null) {
//         updated.add(config);
//         continue;
//       }
//       try {
//         final rv = await _salesService.getReportValueForMetric(
//           metric,
//           companyGuid: guid,
//         );
//         updated.add(config.copyWith(
//           value: '${rv.primaryValue} ${rv.primaryUnit}',
//           sub: _selectedPeriod,
//           badge: rv.changePercent.isNotEmpty ? rv.changePercent : null,
//           isPositive: rv.isPositiveChange,
//         ));
//       } catch (_) {
//         updated.add(config);
//       }
//     }

//     if (mounted) {
//       setState(() => _kpiConfigs = updated);
//       KpiConfigStorage.save(updated);
//     }
//   }

//   void _updateKpiConfigs(List<KpiConfig> newConfigs) {
//     setState(() => _kpiConfigs = newConfigs);
//     KpiConfigStorage.save(newConfigs);
//     _refreshKpiValues(newConfigs);
//   }

//   // ─── Sync ───────────────────────────────────

//   Future<void> _onSyncTap() async {
//     if (_isSyncing || _companyGuid == null) return;
//     setState(() => _isSyncing = true);
//     try {
//       await DataSyncService.instance.syncCompany(
//         _companyGuid!,
//         onProgress: (tableName, progress) {
//           developer.log('Syncing $tableName...', name: 'Dashboard');
//         },
//       );
//       if (mounted) await _loadMetricData();
//     } catch (e) {
//       developer.log('⚠️ Manual sync failed: $e', name: 'Dashboard');
//     } finally {
//       if (mounted) setState(() => _isSyncing = false);
//     }
//   }

//   Future<void> _showLocalDataInfo() async {
//     if (_companyGuid == null) return;
//     final counts = await DataSyncService.instance.getLocalRowCounts(_companyGuid!);
//     final lastSync = DataSyncService.instance.lastSyncTime;
//     if (!mounted) return;
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Local SQLite Data'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Company: ${_company?.name ?? _companyGuid}',
//                 style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
//               ),
//               if (lastSync != null)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 4, bottom: 8),
//                   child: Text(
//                     'Last synced: ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')} on ${lastSync.day}/${lastSync.month}/${lastSync.year}',
//                     style: const TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                 ),
//               const Divider(),
//               ...counts.entries.map((e) {
//                 final hasData = e.value > 0;
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 3),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(e.key, style: const TextStyle(fontSize: 13)),
//                       Text(
//                         e.value == -1 ? 'N/A' : '${e.value} rows',
//                         style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                           color: hasData ? Colors.green : Colors.red,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               }),
//               const Divider(),
//               Text(
//                 'Mode: ${AppState.isOffline ? "OFFLINE" : "ONLINE"}',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: AppState.isOffline ? Colors.orange : Colors.green,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Navigation ──────────────────────────────

//   void _onBottomNavTap(int index) {
//     setState(() => _navIndex = index);
//   }

//   void _showCompanyPicker() {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (ctx) {
//         return SafeArea(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text('Select Company',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//               ),
//               const Divider(height: 1),
//               ...AppState.companies.map((company) {
//                 final isSelected =
//                     company.guid == AppState.selectedCompany?.guid;
//                 return ListTile(
//                   title: Text(company.name),
//                   subtitle: Text(company.email ?? company.state ?? ''),
//                   trailing: isSelected
//                       ? const Icon(Icons.check_circle, color: Colors.blue)
//                       : null,
//                   onTap: () async {
//                     Navigator.pop(ctx);
//                     setState(() {
//                       AppState.selectedCompany = company;
//                       _companyGuid = company.guid;
//                       _company = company;
//                       _dashboardMetrics = [];
//                       _revenue = '';
//                       _expenses = '';
//                       _net = '';
//                     });
//                     // Persist for offline fallback
//                     await SecureStorage.saveCompanyGuid(company.guid);
//                     // Sync this company's data to local SQLite (fire and forget)
//                     // DataSyncService.instance.syncCompany(company.guid).catchError((e) {
//                     //   developer.log('⚠️ Background sync failed: $e', name: 'Dashboard');
//                     // });
//                     _loadMetricData();
//                   },
//                 );
//               }),
//               const SizedBox(height: 8),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _openKpiManager() {
//     Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) => KpiManagerScreen(
//           currentConfigs: _kpiConfigs,
//           onSave: _updateKpiConfigs,
//         ),
//       ),
//     );
//   }

//   static const _metricMapping = [
//     ReportMetric.sales,
//     ReportMetric.purchase,
//     ReportMetric.profit,
//     ReportMetric.receivable,
//   ];

//   void _navigateToDetail(int index, _MetricData metric) {
//     final reportMetric = _metricMapping[index];

//     if (index == 0) {
//       Navigator.of(context).push(
//         MaterialPageRoute(
//           builder: (context) => NetSalesDetailScreen(
//             totalValue: metric.value,
//             unit: metric.unit,
//             changePercent: metric.change,
//             isPositive: metric.isPositive,
//           ),
//         ),
//       );
//     } else if (reportMetric == ReportMetric.receivable) {
//       Navigator.of(context).push(
//         MaterialPageRoute(
//           builder: (context) => OutstandingDetailScreen(metric: reportMetric),
//         ),
//       );
//     } else {
//       Navigator.of(context).push(
//         MaterialPageRoute(
//           builder: (context) => MetricDetailScreen(metric: reportMetric),
//         ),
//       );
//     }
//   }

//   // ─── Build ───────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: SystemUiOverlayStyle.dark.copyWith(
//         statusBarColor: Colors.transparent,
//       ),
//       child: Scaffold(
//         backgroundColor: AppColors.background,
//         body: Stack(
//           children: [
//             IndexedStack(
//               index: _navIndex,
//               children: [
//                 // 0 – Home
//                 _buildHomePage(),
//                 // 1 – Reports (keyed by company GUID so it rebuilds on company switch)
//                 ReportsOverviewScreen(key: ValueKey(_companyGuid)),
//                 // 2 – Profile
//                 const MobileProfileTab(),
//               ],
//             ),
//             // Floating bottom nav
//             Positioned(
//               left: 0,
//               right: 0,
//               bottom: 0,
//               child: DashboardBottomNav(
//                 activeIndex: _navIndex,
//                 onTap: _onBottomNavTap,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════
//   //  HOME PAGE (scrollable content)
//   // ═══════════════════════════════════════════
//   Widget _buildHomePage() {
//     return SingleChildScrollView(
//       physics: const BouncingScrollPhysics(),
//       padding: EdgeInsets.only(
//         top: MediaQuery.of(context).padding.top,
//         bottom: 100,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         spacing: 20,
//         children: [
//           // 1. Company Name + Notification + Settings
//           _buildCompanyBar(),
//           // 2. Date Range Selector
//           _buildDateRangeSelector(),
//           // 3. Quick Actions (horizontal scroll)
//           _buildQuickActions(),
//           // 4. Metric Cards (2×2 grid)
//           _buildMetricGrid(),
//           // 5. Key Metrics (KPI rows)
//           _buildKeyMetrics(),
//           // 6. Revenue Breakdown
//           RevenueBreakdown(
//             revenue: _revenue,
//             expenses: _expenses,
//             net: _net,
//           ),
//           // 7. Ask Anything (AI bar)
//           const AiAskBar(),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════
//   //  1. COMPANY BAR (name + notification + settings)
//   // ═══════════════════════════════════════════
//   Widget _buildCompanyBar() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(
//         AppSpacing.pagePadding,
//         8,
//         AppSpacing.pagePadding,
//         0,
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           // Title + Company selector
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('DASHBOARD', style: AppTypography.dashboardLabel),
//                 const SizedBox(height: 5),
//                 GestureDetector(
//                   onTap: _showCompanyPicker,
//                   child: Container(
//                     padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
//                     decoration: BoxDecoration(
//                       color: AppColors.surface,
//                       borderRadius: BorderRadius.circular(10),
//                       border: Border.all(color: AppColors.divider, width: 1),
//                       boxShadow: AppShadows.headerIcon,
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Flexible(
//                           child: Text(
//                             AppState.selectedCompany?.name ?? 'Select Company',
//                             style: AppTypography.companyName,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         SvgPicture.string(AppIcons.chevronDown,
//                             width: 16, height: 16),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Action icons
//           Row(
//             children: [
//               GestureDetector(
//                 onTap: _onSyncTap,
//                 onLongPress: _showLocalDataInfo,
//                 child: Container(
//                   width: 38,
//                   height: 38,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF5F6F8),
//                     borderRadius: BorderRadius.circular(11),
//                   ),
//                   child: _isSyncing
//                       ? const Padding(
//                           padding: EdgeInsets.all(10),
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         )
//                       : const Icon(Icons.sync, size: 18, color: Color(0xFF6B7280)),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               _HeaderIconButton(
//                 svgIcon: AppIcons.bell,
//                 showBadge: true,
//                 onTap: () {},
//               ),
//               const SizedBox(width: 8),
//               _HeaderIconButton(
//                 svgIcon: AppIcons.settings,
//                 onTap: () {},
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════
//   //  2. DATE RANGE SELECTOR
//   // ═══════════════════════════════════════════
//   Widget _buildDateRangeSelector() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(
//         AppSpacing.pagePadding,
//         0,
//         AppSpacing.pagePadding,
//         0,
//       ),
//       child: PeriodSelector(
//         selected: _selectedPeriod,
//         onChanged: (v) async {
//           if (v == 'Custom') {
//             final picked = await showDateRangePicker(
//               context: context,
//               firstDate: DateTime(2015),
//               lastDate: DateTime(2030),
//               initialDateRange: _customStart != null && _customEnd != null
//                   ? DateTimeRange(start: _customStart!, end: _customEnd!)
//                   : null,
//               builder: (context, child) => Theme(
//                 data: Theme.of(context).copyWith(
//                   colorScheme: Theme.of(context).colorScheme.copyWith(
//                     primary: const Color(0xFF2D8BE0),
//                   ),
//                 ),
//                 child: child!,
//               ),
//             );
//             if (picked != null && mounted) {
//               setState(() {
//                 _selectedPeriod = 'Custom';
//                 _customStart = picked.start;
//                 _customEnd = picked.end;
//               });
//               _loadMetricData();
//             }
//           } else {
//             setState(() => _selectedPeriod = v);
//             _loadMetricData();
//           }
//         },
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════
//   //  3. QUICK ACTIONS (horizontal scroll)
//   // ═══════════════════════════════════════════
//   Widget _buildQuickActions() {
//     const actions = ReportMetric.values;

//     return Padding(
//       padding: const EdgeInsets.only(bottom: 0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: AppSpacing.pagePadding,
//             ),
//             child: Text(
//               'Quick Actions',
//               style: AppTypography.cardLabel,
//             ),
//           ),
//           const SizedBox(height: 10),
//           SizedBox(
//             height: 90,
//             child: ListView.separated(
//               scrollDirection: Axis.horizontal,
//               physics: const BouncingScrollPhysics(),
//               padding: const EdgeInsets.symmetric(
//                 horizontal: AppSpacing.pagePadding,
//               ),
//               itemCount: actions.length,
//               separatorBuilder: (_, __) => const SizedBox(width: 12),
//               itemBuilder: (context, index) {
//                 final metric = actions[index];
//                 return GestureDetector(
//                   onTap: () {
//                     final isOutstanding =
//                         metric == ReportMetric.receivable ||
//                         metric == ReportMetric.payable;
//                     Navigator.of(context).push(
//                       MaterialPageRoute(
//                         builder: (context) => isOutstanding
//                             ? OutstandingDetailScreen(metric: metric)
//                             : MetricDetailScreen(metric: metric),
//                       ),
//                     );
//                   },
//                   child: Container(
//                     width: 84,
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     decoration: BoxDecoration(
//                       color: AppColors.surface,
//                       borderRadius: BorderRadius.circular(AppRadius.card),
//                       boxShadow: AppShadows.card,
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           width: 30,
//                           height: 30,
//                           decoration: BoxDecoration(
//                             color: metric.iconBgColor,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Center(
//                             child: SvgPicture.string(
//                               metric.icon,
//                               width: 15,
//                               height: 15,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         Text(
//                           metric.displayName,
//                           style: AppTypography.cardLabel
//                               .copyWith(letterSpacing: 0.2),
//                           textAlign: TextAlign.center,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════
//   //  4. METRIC CARDS (2×2 grid)
//   // ═══════════════════════════════════════════
//   Widget _buildMetricGrid() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
//       child: Wrap(
//         spacing: AppSpacing.cardGap,
//         runSpacing: AppSpacing.cardGap,
//         children: _dashboardMetrics.asMap().entries.map((entry) {
//           final index = entry.key;
//           final m = entry.value;
//           return SizedBox(
//             width: (MediaQuery.of(context).size.width -
//                     AppSpacing.pagePadding * 2 -
//                     AppSpacing.cardGap) /
//                 2,
//             child: MetricCard(
//               svgIcon: m.icon,
//               iconBgColor: m.iconBgColor,
//               label: m.label,
//               value: m.value,
//               unit: m.unit,
//               change: m.change,
//               isPositive: m.isPositive,
//               onTap: () => _navigateToDetail(index, m),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════
//   //  4. KEY METRICS (Dynamic KPI rows)
//   // ═══════════════════════════════════════════
//   Widget _buildKeyMetrics() {
//     if (_kpiLoading) {
//       return Container(
//         margin: const EdgeInsets.fromLTRB(
//           AppSpacing.pagePadding,
//           AppSpacing.sectionGap,
//           AppSpacing.pagePadding,
//           0,
//         ),
//         padding: const EdgeInsets.all(32),
//         decoration: BoxDecoration(
//           color: AppColors.surface,
//           borderRadius: BorderRadius.circular(AppRadius.card),
//           boxShadow: AppShadows.card,
//         ),
//         child: const Center(
//           child: CircularProgressIndicator(strokeWidth: 2),
//         ),
//       );
//     }

//     if (_kpiConfigs.isEmpty) {
//       return KpiSection(
//         onEditTap: _openKpiManager,
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               children: [
//                 Icon(
//                   Icons.dashboard_outlined,
//                   size: 48,
//                   color: AppColors.textSecondary.withValues(alpha: 0.5),
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   'No KPIs configured',
//                   style: AppTypography.itemTitle.copyWith(
//                     color: AppColors.textSecondary,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Tap Edit to add metrics',
//                   style: AppTypography.itemSubtitle,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       );
//     }

//     return KpiSection(
//       onEditTap: _openKpiManager,
//       children: _kpiConfigs.asMap().entries.map((entry) {
//         final i = entry.key;
//         final config = entry.value;
//         final metric = getMetricById(config.metricId);

//         if (metric == null) return const SizedBox.shrink();

//         return KeyMetricRow(
//           svgIcon: metric.icon,
//           iconBg: metric.iconBg,
//           label: metric.name,
//           value: config.value,
//           sub: config.sub,
//           badge: config.badge,
//           isPositive: config.isPositive,
//           showDivider: i < _kpiConfigs.length - 1,
//           onTap: () {
//             // Future: Navigate to detail page for this KPI
//           },
//         );
//       }).toList(),
//     );
//   }
// }


import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../icons/app_icons.dart';
import '../../widgets/dashboard_widgets.dart';
import '../../models/kpi_metric.dart';
import '../../models/report_data.dart';
import '../../services/sales_service.dart';
import '../../services/data_sync_service.dart';
import '../../utils/secure_storage.dart';
import '../../models/company_model.dart';
import '../main.dart';
import 'kpi_manager_screen.dart';
import 'metric_detail_screen.dart';
import 'outstanding_detail_screen.dart';
import 'Recevaible_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/amount_formatter.dart';
import '../../utils/chart_period_helper.dart';

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

class _PieItem {
  final String label;
  final double value;
  final Color color;
  const _PieItem(this.label, this.value, this.color);
}

// ─────────────────────────────────────────────
//  HEADER ICON BUTTON
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
  List<KpiConfig> _kpiConfigs = [];
  bool _kpiLoading = true;

  List<_MetricData> _dashboardMetrics = [];
  String _revenue  = '';
  String _expenses = '';
  String _net      = '';
  double _rawSales    = 0;
  double _rawPurchase = 0;

  // Helper: get current text scale factor for responsive sizing
  double _ts(BuildContext ctx) => MediaQuery.textScalerOf(ctx).scale(1.0);

  // Monthly trend data for line/bar charts
  List<ChartDataPoint> _monthlySales = [];
  List<ChartDataPoint> _monthlyPurchase = [];
  List<ChartDataPoint> _monthlyProfit = [];

  // Purchase category breakdown for detailed pie chart
  List<Map<String, dynamic>> _purchaseCategories = [];
  bool _showAllCategories = false;

  bool _isSyncing = false;

  final SalesAnalyticsService _salesService = SalesAnalyticsService();
  String? _companyGuid;
  Company? _company;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadKpiConfigs();
    _loadCompanyAndMetrics();
  }

  Future<void> _loadCompanyAndMetrics() async {
    final company = AppState.selectedCompany;
    if (company != null) {
      _companyGuid = company.guid;
      _company = company;
    }
    await _loadMetricData();
  }

  // ── Date helpers ───────────────────────────────────────────────────────────

  DateTime? _parseCompanyDate(String? dateStr) {
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

  DateTime _companyFYStart() {
    final parsed = _parseCompanyDate(_company?.startingFrom);
    if (parsed != null) return parsed;
    final now = DateTime.now();
    return now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
  }

  DateTime _companyFYEnd() {
    final parsed = _parseCompanyDate(_company?.endingAt);
    if (parsed != null) return parsed;
    final now = DateTime.now();
    return now.month >= 4
        ? DateTime(now.year + 1, 3, 31)
        : DateTime(now.year, 3, 31);
  }

  (DateTime, DateTime) _dateRangeForPeriod(String period) {
    final now     = DateTime.now();
    final fyStart = _companyFYStart();
    final fyEnd   = _companyFYEnd();
    final fyMonth = fyStart.month;

    switch (period) {
      case 'MoM':
      case 'This Month':
        return (DateTime(now.year, now.month, 1), now);
      case 'Last Month':
        return (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0),
        );
      case 'QTD':
      case 'Quarter':
        final fiscalMonth = now.month >= fyMonth ? now.month : now.month + 12;
        final qStart = ((fiscalMonth - fyMonth) ~/ 3) * 3 + fyMonth;
        final qStartMonth = qStart > 12 ? qStart - 12 : qStart;
        final qStartYear  = qStart > 12
            ? now.year
            : (now.month >= fyMonth ? now.year : now.year - 1);
        return (DateTime(qStartYear, qStartMonth, 1), now);
      case 'YTD':
        return (fyStart, now.isBefore(fyEnd) ? now : fyEnd);
      case 'Last Year':
        return (
          DateTime(fyStart.year - 1, fyStart.month, fyStart.day),
          DateTime(fyEnd.year   - 1, fyEnd.month,   fyEnd.day),
        );
      case 'Custom':
        if (_customStart != null && _customEnd != null) {
          return (_customStart!, _customEnd!);
        }
        return (DateTime(now.year, now.month, 1), now);
      default:
        return (DateTime(now.year, now.month, 1), now);
    }
  }

  // ── Metric loading ─────────────────────────────────────────────────────────

  Future<void> _loadMetricData() async {
    if (_companyGuid == null) return;

    final guid        = _companyGuid!;
    final (start, end) = _dateRangeForPeriod(_selectedPeriod);

    // Convert to Tally YYYYMMDD format
    String fmtDate(DateTime dt) =>
        '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
    final fromDate = fmtDate(start);
    final toDate = fmtDate(end);

    developer.log(
      '=== DASHBOARD LOAD === company="${_company?.name}" guid=$guid '
      'period=$_selectedPeriod FY: ${_company?.startingFrom} → ${_company?.endingAt} '
      'range: $start → $end',
      name: 'Dashboard',
    );

    try {
      final dashResults = await Future.wait([
        _salesService.getTotalSales(companyGuid: guid, fromDate: fromDate, toDate: toDate),
        _salesService.getTotalPurchase(companyGuid: guid, fromDate: fromDate, toDate: toDate),
        _salesService.getTotalProfit(companyGuid: guid, fromDate: fromDate, toDate: toDate),
        _salesService.getTotalReceivable(companyGuid: guid, fromDate: fromDate, toDate: toDate),
      ]);
      final salesVal      = dashResults[0];
      final purchaseVal   = dashResults[1];
      final profitVal     = dashResults[2];
      final receivableVal = dashResults[3];

      // Guard against widget being disposed while awaiting
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

        _revenue  = '${salesVal.primaryValue} ${salesVal.primaryUnit}';
        _expenses = '${purchaseVal.primaryValue} ${purchaseVal.primaryUnit}';
        _net      = '${profitVal.primaryValue} ${profitVal.primaryUnit}';

        _rawSales    = double.tryParse(salesVal.primaryValue.replaceAll(',', '')) ?? 0;
        _rawPurchase = double.tryParse(purchaseVal.primaryValue.replaceAll(',', '')) ?? 0;
      });

      _refreshKpiValues(_kpiConfigs, fromDate: fromDate, toDate: toDate);

      // Load monthly trend data for line/bar charts
      final trendResults = await Future.wait([
        _salesService.getSalesTrend(companyGuid: guid, fromDate: fromDate, toDate: toDate),
        _salesService.getPurchaseTrend(companyGuid: guid, fromDate: fromDate, toDate: toDate),
        _salesService.getProfitTrend(companyGuid: guid, fromDate: fromDate, toDate: toDate),
      ]);
      if (mounted) {
        setState(() {
          _monthlySales = trendResults[0].dataPoints;
          _monthlyPurchase = trendResults[1].dataPoints;
          _monthlyProfit = trendResults[2].dataPoints;
        });
      }

      // Load purchase category breakdown
      final categories = await _salesService.getPurchaseByCategory(
        companyGuid: guid, fromDate: fromDate, toDate: toDate,
      );
      if (mounted) {
        setState(() {
          _purchaseCategories = categories;
          _showAllCategories = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard metrics: $e');
    }
  }

  Future<void> _loadKpiConfigs() async {
    final configs = await KpiConfigStorage.load();
    if (!mounted) return;
    setState(() {
      _kpiConfigs = configs;
      _kpiLoading = false;
    });
    _refreshKpiValues(configs);
  }

  ReportMetric? _metricFromId(String id) {
    switch (id) {
      case 'sales':      return ReportMetric.sales;
      case 'purchase':   return ReportMetric.purchase;
      case 'profit':     return ReportMetric.profit;
      case 'receivable': return ReportMetric.receivable;
      case 'payable':    return ReportMetric.payable;
      case 'receipts':   return ReportMetric.receipts;
      case 'payments':   return ReportMetric.payments;
      case 'stock':      return ReportMetric.stock;
      default:           return null;
    }
  }

  Future<void> _refreshKpiValues(List<KpiConfig> configs, {String? fromDate, String? toDate}) async {
    if (_companyGuid == null || configs.isEmpty) return;

    final guid           = _companyGuid!;
    final updated        = <KpiConfig>[];

    // If no dates passed, compute from current period
    if (fromDate == null || toDate == null) {
      final (start, end) = _dateRangeForPeriod(_selectedPeriod);
      String fmtDate(DateTime dt) =>
          '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
      fromDate = fmtDate(start);
      toDate = fmtDate(end);
    }

    for (final config in configs) {
      final metric = _metricFromId(config.metricId);
      if (metric == null) {
        updated.add(config);
        continue;
      }
      try {
        final rv = await _salesService.getReportValueForMetric(
            metric, companyGuid: guid, fromDate: fromDate, toDate: toDate);
        updated.add(config.copyWith(
          value:      '${rv.primaryValue} ${rv.primaryUnit}',
          sub:        _selectedPeriod,
          badge:      rv.changePercent.isNotEmpty ? rv.changePercent : null,
          isPositive: rv.isPositiveChange,
        ));
      } catch (_) {
        updated.add(config);
      }
    }

    if (!mounted) return;
    setState(() => _kpiConfigs = updated);
    KpiConfigStorage.save(updated);
  }

  void _updateKpiConfigs(List<KpiConfig> newConfigs) {
    setState(() => _kpiConfigs = newConfigs);
    KpiConfigStorage.save(newConfigs);
    _refreshKpiValues(newConfigs);
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

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
    final counts   = await DataSyncService.instance.getLocalRowCounts(_companyGuid!);
    final lastSync = DataSyncService.instance.lastSyncTime;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Local SQLite Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Company: ${_company?.name ?? _companyGuid}',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (lastSync != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Last synced: ${lastSync.hour.toString().padLeft(2, '0')}:'
                    '${lastSync.minute.toString().padLeft(2, '0')} on '
                    '${lastSync.day}/${lastSync.month}/${lastSync.year}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              const Divider(),
              ...counts.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key,
                            style: const TextStyle(fontSize: 13)),
                        Text(
                          e.value == -1 ? 'N/A' : '${e.value} rows',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: e.value > 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(),
              Text(
                'Mode: ${AppState.isOffline ? "OFFLINE" : "ONLINE"}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      AppState.isOffline ? Colors.orange : Colors.green,
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

  void _showCompanyPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Company',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: AppState.companies.map((company) {
              final isSelected =
                  company.guid == AppState.selectedCompany?.guid;
              return ListTile(
                title: Text(company.name),
                subtitle:
                    Text(company.email ?? company.state ?? ''),
                trailing: isSelected
                    ? const Icon(Icons.check_circle,
                        color: Colors.blue)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() {
                    AppState.selectedCompany = company;
                    _companyGuid = company.guid;
                    _company = company;
                    _dashboardMetrics = [];
                    _revenue  = '';
                    _expenses = '';
                    _net      = '';
                  });
                  await SecureStorage.saveCompanyGuid(company.guid);
                  _loadMetricData();
                },
              );
            }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openKpiManager() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KpiManagerScreen(
        currentConfigs: _kpiConfigs,
        onSave: _updateKpiConfigs,
      ),
    ));
  }

  static const _metricMapping = [
    ReportMetric.sales,
    ReportMetric.purchase,
    ReportMetric.profit,
    ReportMetric.receivable,
  ];

  void _navigateToDetail(int index, _MetricData metric) {
    final reportMetric = _metricMapping[index];
    if (reportMetric == ReportMetric.receivable) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ReceivableScreen(),
      ));
    } else if (reportMetric == ReportMetric.payable) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            OutstandingDetailScreen(metric: reportMetric),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MetricDetailScreen(metric: reportMetric),
      ));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  // DashboardScreen is now just the "Home" tab content.
  // Navigation (Reports, Profile tabs) is owned by AppShell in main.dart.

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _buildHomePage(),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  HOME PAGE
  // ═══════════════════════════════════════════

  Widget _buildHomePage() {
    // Use LayoutBuilder to get precise available width — avoids sizing crashes
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomPad = MediaQuery.of(context).padding.bottom;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            // 72 = approximate nav bar height + extra breathing room
            bottom: bottomPad + 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompanyBar(),
              const SizedBox(height: 20),
              _buildDateRangeSelector(),
              const SizedBox(height: 20),
              _buildQuickActions(),
              const SizedBox(height: 20),
              _buildMetricGrid(constraints.maxWidth),
              const SizedBox(height: 20),
              _buildKeyMetrics(),
              const SizedBox(height: 20),
              RevenueBreakdown(
                revenue: _revenue,
                expenses: _expenses,
                net: _net,
              ),
              const SizedBox(height: 20),
              _buildSalesPurchasePieChart(),
              const SizedBox(height: 20),
              _buildDetailedRevenueBreakdown(),
              const SizedBox(height: 20),
              _buildCombinedTrendChart(),
              const SizedBox(height: 20),
              _buildGapAreaChart(),
              const SizedBox(height: 20),
              _buildProfitMarginChart(),
              const SizedBox(height: 20),
              const AiAskBar(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ── 1. Company bar ─────────────────────────────────────────────────────────

  Widget _buildCompanyBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, 8, AppSpacing.pagePadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DASHBOARD', style: AppTypography.dashboardLabel),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Company selector
              Expanded(
                child: GestureDetector(
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
                        SvgPicture.string(AppIcons.chevronDown, width: 16, height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Action icons
              GestureDetector(
                onTap: _onSyncTap,
                onLongPress: _showLocalDataInfo,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: AppShadows.headerIcon,
                  ),
                  child: _isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.sync, size: 18, color: AppColors.textSecondary),
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

  // ── 2. Date range selector ─────────────────────────────────────────────────

  Widget _buildDateRangeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding),
      child: PeriodSelector(
        selected: _selectedPeriod,
        onChanged: (v) async {
          if (v == 'Custom') {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2015),
              lastDate: now,
              currentDate: now,
              initialDateRange:
                  _customStart != null && _customEnd != null
                      ? DateTimeRange(
                          start: _customStart!,
                          end: _customEnd!)
                      : DateTimeRange(
                          start: DateTime(now.year, now.month, 1),
                          end: now),
              initialEntryMode: DatePickerEntryMode.calendarOnly,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme:
                      Theme.of(ctx).colorScheme.copyWith(
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

  // ── 3. Quick actions ───────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    const actions = ReportMetric.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding),
          child: Text('Quick Actions',
              style: AppTypography.cardLabel),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding + 4),
          child: IntrinsicHeight(
            child: Row(
              children: actions.asMap().entries.map((entry) {
                final index = entry.key;
                final metric = entry.value;
                return Padding(
                  padding: EdgeInsets.only(left: index > 0 ? 14 : 0),
                  child: GestureDetector(
                    onTap: () {
                      if (metric == ReportMetric.receivable) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReceivableScreen(),
                          ),
                        );
                      } else {
                        final isOutstanding =
                            metric == ReportMetric.payable;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => isOutstanding
                                ? OutstandingDetailScreen(
                                    metric: metric)
                                : MetricDetailScreen(
                                    metric: metric),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 84,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                            AppRadius.card),
                        boxShadow: AppShadows.card,
                        border: AppShadows.cardBorder,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: metric.iconBgColor,
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: SvgPicture.string(
                                metric.icon,
                                width: 15,
                                height: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                metric.displayName,
                                style: AppTypography.cardLabel
                                    .copyWith(fontSize: 10, letterSpacing: 0.2),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Metric grid ─────────────────────────────────────────────────────────
  //
  // Uses LayoutBuilder-supplied width instead of MediaQuery to avoid
  // potential layout crashes when the widget hasn't been laid out yet.
  // Falls back gracefully when _dashboardMetrics is empty (shows shimmer
  // placeholders via the loop guard).

  Widget _buildMetricGrid(double availableWidth) {
    if (_dashboardMetrics.isEmpty) {
      // Show 4 loading skeleton cards while data is loading
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding),
        child: Wrap(
          spacing: AppSpacing.cardGap,
          runSpacing: AppSpacing.cardGap,
          children: List.generate(4, (i) {
            final cardWidth =
                (availableWidth - AppSpacing.pagePadding * 2 -
                        AppSpacing.cardGap) /
                    2;
            return Container(
              width: cardWidth,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppRadius.card),
                boxShadow: AppShadows.card,
                border: AppShadows.cardBorder,
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2),
                ),
              ),
            );
          }),
        ),
      );
    }

    final cardWidth =
        (availableWidth - AppSpacing.pagePadding * 2 -
                AppSpacing.cardGap) /
            2;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding),
      child: Wrap(
        spacing: AppSpacing.cardGap,
        runSpacing: AppSpacing.cardGap,
        children:
            _dashboardMetrics.asMap().entries.map((entry) {
          final index = entry.key;
          final m     = entry.value;
          return SizedBox(
            width: cardWidth,
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

  // ── Revenue Breakdown Donut Chart ───────────────────────────────────────────

  Widget _buildSalesPurchasePieChart() {
    final sales = _rawSales.abs();
    final purchase = _rawPurchase.abs();
    final profit = (sales - purchase).abs();
    final total = sales;
    if (total <= 0) return const SizedBox.shrink();

    final ts = _ts(context);
    final purchasePct = purchase / total * 100;
    final profitPct = profit / total * 100;

    final data = [
      _PieItem('Purchase (Cost)', purchase, AppColors.amber),
      _PieItem('Profit', profit, AppColors.green),
    ];
    final displayValues = [_expenses, AmountFormatter.shortSpaced(profit)];
    final percentages = [purchasePct, profitPct];

    final pieSize = 150 * ts;
    final pieRadius = 35 * ts;
    final centerRadius = 30 * ts;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
        border: AppShadows.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue Breakdown', style: AppTypography.chartSectionTitle),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: pieSize,
              height: pieSize,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: centerRadius,
                  sections: data.map((item) {
                    final pct = item.value / total * 100;
                    return PieChartSectionData(
                      color: item.color,
                      value: item.value,
                      title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                      radius: pieRadius,
                      titleStyle: AppTypography.chartPieLabel,
                      titlePositionPercentageOffset: 0.55,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Total Sales row
          Row(
            children: [
              Container(
                width: 10 * ts,
                height: 10 * ts,
                decoration: BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Total Sales',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              Text('₹$_revenue',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(width: 10),
              Text('100%',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  textAlign: TextAlign.right),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(data.length, (i) {
            final item = data[i];
            final pct = percentages[i];
            return Column(
              children: [
                if (i == data.length - 1) Divider(height: 1, color: AppColors.divider),
                if (i == data.length - 1) const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10 * ts,
                        height: 10 * ts,
                        decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: i == data.length - 1 ? FontWeight.w600 : FontWeight.normal,
                                color: AppColors.textSecondary)),
                      ),
                      Text('₹${displayValues[i]}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: i == data.length - 1 ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 10),
                      Text('${pct.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          textAlign: TextAlign.right),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Detailed Revenue Breakdown (Profit + Top 5 Categories + Others) ───────

  Widget _buildDetailedRevenueBreakdown() {
    final sales = _rawSales.abs();
    final purchase = _rawPurchase.abs();
    final profit = (sales - purchase).abs();
    final ts = _ts(context);

    if (sales <= 0 || _purchaseCategories.isEmpty) return const SizedBox.shrink();

    // _rawSales/_rawPurchase are in display units (e.g. 307.31 for "307.31 Cr")
    // Category amounts from DB are raw (e.g. 1122500000).
    // Normalize categories to same unit as _rawPurchase.
    final totalCatRaw = _purchaseCategories.fold<double>(
        0, (s, c) => s + (c['net_amount'] as double).abs());
    final scale = totalCatRaw > 0 ? purchase / totalCatRaw : 0.0;

    // Step 1: Only keep categories >= 2% of total purchase as individual slices.
    // Everything else merges into "Others". This guarantees every legend = visible slice.
    const maxSlices = 5;
    const minPct = 0.02; // 2% threshold
    final significantCats = <Map<String, dynamic>>[];
    double othersRaw = 0;
    for (final cat in _purchaseCategories) {
      final raw = (cat['net_amount'] as double).abs();
      if (significantCats.length < maxSlices && totalCatRaw > 0 && (raw / totalCatRaw) >= minPct) {
        significantCats.add(cat);
      } else {
        othersRaw += raw;
      }
    }

    // Distinct colors — no duplicates, no confusion
    const categoryColors = [
      Color(0xFFF59E0B), // amber
      Color(0xFF3B82F6), // blue
      Color(0xFFEF4444), // red
      Color(0xFF8B5CF6), // purple
      Color(0xFF14B8A6), // teal
    ];
    const profitColor = Color(0xFF22C55E);  // green
    const othersColor = Color(0xFF6B7280);  // grey

    // Build pie items — every item here WILL be visible in the chart
    final pieItems = <_PieItem>[];
    pieItems.add(_PieItem('Profit', profit, profitColor));
    for (int i = 0; i < significantCats.length; i++) {
      final scaled = (significantCats[i]['net_amount'] as double).abs() * scale;
      pieItems.add(_PieItem(
        significantCats[i]['ledger_name'] as String,
        scaled,
        categoryColors[i],
      ));
    }
    if (othersRaw > 0) {
      pieItems.add(_PieItem('Others', othersRaw * scale, othersColor));
    }

    // Total for percentages
    final pieTotal = pieItems.fold<double>(0, (s, item) => s + item.value);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
        border: AppShadows.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue Breakdown (Detailed)', style: AppTypography.chartSectionTitle),
          const SizedBox(height: 20),
          // Donut chart — true proportions, labels inside or outside based on slice size
          Center(
            child: SizedBox(
              width: 260 * ts,
              height: 260 * ts,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40 * ts,
                  sections: List.generate(pieItems.length, (i) {
                    final item = pieItems[i];
                    final pct = pieTotal > 0 ? (item.value / pieTotal * 100) : 0.0;
                    final labelText = pct >= 1
                        ? '${pct.toStringAsFixed(0)}%'
                        : '<1%';
                    final showLabel = pct >= 8;
                    return PieChartSectionData(
                      color: item.color,
                      value: item.value,
                      title: showLabel ? labelText : '',
                      radius: 50 * ts,
                      titleStyle: AppTypography.chartPieLabel,
                      titlePositionPercentageOffset: 0.5,
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend — dot + full name (no truncation) + amount
          ...pieItems.map((item) {
            // Convert back to raw for AmountFormatter
            final displayAmount = item.label == 'Profit'
                ? profit * (totalCatRaw > 0 ? totalCatRaw / purchase : 1.0)
                : item.value * (totalCatRaw > 0 ? totalCatRaw / purchase : 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 10 * ts,
                      height: 10 * ts,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AmountFormatter.currencyShort(displayAmount),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          // Total Sales row
          Row(
            children: [
              Text('Total Sales',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              Text(
                '₹$_revenue',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          // "See More" / "See Less" toggle — always show if > 1 category
          if (_purchaseCategories.length > 1) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() => _showAllCategories = !_showAllCategories),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showAllCategories ? 'See Less' : 'See All ${_purchaseCategories.length} Categories',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.blue),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAllCategories ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: AppColors.blue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // All categories as progress bars
            if (_showAllCategories) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 14),
              Text('All Purchase Categories', style: AppTypography.chartSectionTitle),
              const SizedBox(height: 14),
              ...List.generate(_purchaseCategories.length, (i) {
                final cat = _purchaseCategories[i];
                final name = cat['ledger_name'] as String;
                final rawAmount = (cat['net_amount'] as double).abs();
                final pct = totalCatRaw > 0 ? (rawAmount / totalCatRaw) : 0.0;
                final pctDisplay = pct * 100;
                final pctText = pctDisplay < 1 && pctDisplay > 0
                    ? '<1%'
                    : '${pctDisplay.toStringAsFixed(0)}%';
                // Assign color: match pie color if it's a significant cat, else grey
                final sigIndex = significantCats.indexOf(cat);
                final barColor = sigIndex >= 0 ? categoryColors[sigIndex] : othersColor;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AmountFormatter.currencyShort(rawAmount),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 32,
                            child: Text(
                              pctText,
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  // ── Combined Sales/Purchase/Profit Chart ──────────────────────────────────

  Widget _buildCombinedTrendChart() {
    if (_monthlySales.isEmpty && _monthlyPurchase.isEmpty && _monthlyProfit.isEmpty) {
      return const SizedBox.shrink();
    }

    // Merge all months
    final allMonths = <String>{};
    for (final p in _monthlySales) { allMonths.add(p.label); }
    for (final p in _monthlyPurchase) { allMonths.add(p.label); }
    for (final p in _monthlyProfit) { allMonths.add(p.label); }
    final months = allMonths.toList()..sort();

    // Aggregate if > 12 months
    final period = autoSelectPeriod(months.length);

    final aggSales = aggregateChartData(
      ReportChartData(dataPoints: _monthlySales, chartType: ReportChartType.bar, title: ''),
      period,
    ).dataPoints;
    final aggPurchase = aggregateChartData(
      ReportChartData(dataPoints: _monthlyPurchase, chartType: ReportChartType.bar, title: ''),
      period,
    ).dataPoints;
    final aggProfit = aggregateChartData(
      ReportChartData(dataPoints: _monthlyProfit, chartType: ReportChartType.bar, title: ''),
      period,
    ).dataPoints;

    // Build unified labels — preserve chronological order from aggSales
    final labelSet = <String>{};
    final sortedLabels = <String>[];
    // Use the longest dataset as the base order (they come chronologically)
    final baseOrder = [aggSales, aggPurchase, aggProfit]
        .reduce((a, b) => a.length >= b.length ? a : b);
    for (final p in baseOrder) {
      if (labelSet.add(p.label)) sortedLabels.add(p.label);
    }
    // Add any missing labels from other datasets (in their order)
    for (final list in [aggSales, aggPurchase, aggProfit]) {
      for (final p in list) {
        if (labelSet.add(p.label)) sortedLabels.add(p.label);
      }
    }

    final salesMap = {for (final p in aggSales) p.label: p.value.abs()};
    final purchaseMap = {for (final p in aggPurchase) p.label: p.value.abs()};
    // Profit = Sales - Purchase per period
    final profitMap = <String, double>{};
    final marginValues = <double>[];
    for (final label in sortedLabels) {
      final s = salesMap[label] ?? 0;
      final p = purchaseMap[label] ?? 0;
      profitMap[label] = s - p;
      final margin = s > 0 ? ((s - p) / s * 100) : 0.0;
      marginValues.add(margin);
    }
    final avgMargin = marginValues.isNotEmpty
        ? marginValues.fold<double>(0, (sum, v) => sum + v) / marginValues.length
        : 0.0;
    final avgMarginColor = avgMargin >= 20
        ? const Color(0xFF22C55E)
        : avgMargin >= 10
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    // Line spots for sales/purchase
    final salesSpots = <FlSpot>[];
    final purchaseSpots = <FlSpot>[];
    for (int i = 0; i < sortedLabels.length; i++) {
      salesSpots.add(FlSpot(i.toDouble(), salesMap[sortedLabels[i]] ?? 0));
      purchaseSpots.add(FlSpot(i.toDouble(), purchaseMap[sortedLabels[i]] ?? 0));
    }

    double rawMax = 0;
    for (final s in salesSpots) { if (s.y > rawMax) rawMax = s.y; }
    for (final s in purchaseSpots) { if (s.y > rawMax) rawMax = s.y; }
    for (final v in profitMap.values) { if (v.abs() > rawMax) rawMax = v.abs(); }
    // Round maxY up to next nice interval so top gridline aligns with chart top
    final interval = rawMax > 0 ? rawMax / 4 : 1.0;
    final niceInterval = (interval / 1000000).ceil() * 1000000.0; // round to nearest million
    // Top gridline + small extra so fl_chart draws the line inside the chart
    final topGrid = ((rawMax / niceInterval).ceil()) * niceInterval;
    final maxY = topGrid + (niceInterval * 0.15);
    final ts = _ts(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
        border: AppShadows.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(

                child: Text('Sales · Purchase · Profit', style: AppTypography.chartSectionTitle),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: avgMarginColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Avg ${avgMargin.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: avgMarginColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            children: [
              Container(width: 14, height: 3, decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Sales', style: AppTypography.chartLegendLabel),
              const SizedBox(width: 12),
              Container(width: 14, height: 3, decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Purchase', style: AppTypography.chartLegendLabel),
              const SizedBox(width: 12),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Profit', style: AppTypography.chartLegendLabel),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200 * ts,
            child: Stack(
              children: [
                // Profit bar chart (behind)
                BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    minY: 0,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: niceInterval,
                      getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[300]!, strokeWidth: 0.5, dashArray: [4, 4]),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60 * ts,
                          interval: niceInterval,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                            if (value == 0) {
                              return Text('0', style: AppTypography.chartAxisLabel);
                            }
                            return Text(
                              AmountFormatter.short(value),
                              style: AppTypography.chartAxisLabel,
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= sortedLabels.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Transform.rotate(
                                angle: -0.5,
                                child: Text(
                                  formatChartLabel(sortedLabels[idx]),
                                  style: AppTypography.chartAxisLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                          reservedSize: 46 * ts,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 0.5),
                        bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1A1A2E),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final label = sortedLabels[group.x];
                          return BarTooltipItem(
                            '$label\nProfit: ₹${AmountFormatter.shortSpaced(rod.toY)}',
                            AppTypography.chartTooltipValue,
                          );
                        },
                      ),
                    ),
                    barGroups: List.generate(sortedLabels.length, (i) {
                      final profitVal = profitMap[sortedLabels[i]] ?? 0;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: profitVal.abs(),
                            color: const Color(0xFF4CAF50),
                            width: sortedLabels.length > 8 ? 6 : 10,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                // Sales + Purchase line chart (on top)
                Padding(
                  padding: EdgeInsets.only(bottom: 22 * ts),
                  child: LineChart(
                    LineChartData(
                      minX: -0.5,
                      maxX: sortedLabels.length - 0.5,
                      minY: 0,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60 * ts, getTitlesWidget: (_, __) => const SizedBox.shrink())),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF1A1A2E),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final label = spot.barIndex == 0 ? 'Sales' : 'Purchase';
                              final color = spot.barIndex == 0 ? AppColors.blue : AppColors.amber;
                              final idx = spot.x.toInt();
                              final period = idx >= 0 && idx < sortedLabels.length ? sortedLabels[idx] : '';
                              return LineTooltipItem(
                                '$period\n$label: ₹${AmountFormatter.shortSpaced(spot.y)}',
                                TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: salesSpots,
                          isCurved: true,
                          color: AppColors.blue,
                          barWidth: 2.5,
                          dotData: FlDotData(show: sortedLabels.length <= 12),
                          belowBarData: BarAreaData(show: false),
                        ),
                        LineChartBarData(
                          spots: purchaseSpots,
                          isCurved: true,
                          color: AppColors.amber,
                          barWidth: 2.5,
                          dotData: FlDotData(show: sortedLabels.length <= 12),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ── Shared data preparation for trend charts ──────────────────────────────

  Map<String, dynamic>? _prepareTrendData() {
    if (_monthlySales.isEmpty && _monthlyPurchase.isEmpty) return null;

    final allMonths = <String>{};
    for (final p in _monthlySales) { allMonths.add(p.label); }
    for (final p in _monthlyPurchase) { allMonths.add(p.label); }
    final months = allMonths.toList()..sort();

    final period = autoSelectPeriod(months.length);

    final aggSales = aggregateChartData(
      ReportChartData(dataPoints: _monthlySales, chartType: ReportChartType.bar, title: ''),
      period,
    ).dataPoints;
    final aggPurchase = aggregateChartData(
      ReportChartData(dataPoints: _monthlyPurchase, chartType: ReportChartType.bar, title: ''),
      period,
    ).dataPoints;

    final labelSet = <String>{};
    final sortedLabels = <String>[];
    final baseOrder = [aggSales, aggPurchase]
        .reduce((a, b) => a.length >= b.length ? a : b);
    for (final p in baseOrder) {
      if (labelSet.add(p.label)) sortedLabels.add(p.label);
    }
    for (final list in [aggSales, aggPurchase]) {
      for (final p in list) {
        if (labelSet.add(p.label)) sortedLabels.add(p.label);
      }
    }

    final salesMap = {for (final p in aggSales) p.label: p.value.abs()};
    final purchaseMap = {for (final p in aggPurchase) p.label: p.value.abs()};

    final salesSpots = <FlSpot>[];
    final purchaseSpots = <FlSpot>[];
    for (int i = 0; i < sortedLabels.length; i++) {
      salesSpots.add(FlSpot(i.toDouble(), salesMap[sortedLabels[i]] ?? 0));
      purchaseSpots.add(FlSpot(i.toDouble(), purchaseMap[sortedLabels[i]] ?? 0));
    }

    double rawMax = 0;
    for (final s in salesSpots) { if (s.y > rawMax) rawMax = s.y; }
    for (final s in purchaseSpots) { if (s.y > rawMax) rawMax = s.y; }

    final interval = rawMax > 0 ? rawMax / 4 : 1.0;
    final niceInterval = (interval / 1000000).ceil() * 1000000.0;
    final topGrid = ((rawMax / niceInterval).ceil()) * niceInterval;
    final maxY = topGrid + (niceInterval * 0.15);

    return {
      'sortedLabels': sortedLabels,
      'salesMap': salesMap,
      'purchaseMap': purchaseMap,
      'salesSpots': salesSpots,
      'purchaseSpots': purchaseSpots,
      'maxY': maxY,
      'niceInterval': niceInterval,
    };
  }

  // ── Card: Gap Area Chart (Sales vs Purchase, shaded gap = Profit) ────────

  Widget _buildGapAreaChart() {
    final data = _prepareTrendData();
    if (data == null) return const SizedBox.shrink();
    final ts = _ts(context);

    final sortedLabels = data['sortedLabels'] as List<String>;
    final salesSpots = data['salesSpots'] as List<FlSpot>;
    final purchaseSpots = data['purchaseSpots'] as List<FlSpot>;
    final salesMap = data['salesMap'] as Map<String, double>;
    final purchaseMap = data['purchaseMap'] as Map<String, double>;
    final maxY = data['maxY'] as double;
    final niceInterval = data['niceInterval'] as double;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
        border: AppShadows.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales vs Purchase Trend', style: AppTypography.chartSectionTitle),
          const SizedBox(height: 4),
          Text('Shaded area = Profit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 14, height: 3, decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Sales', style: AppTypography.chartLegendLabel),
              const SizedBox(width: 16),
              Container(width: 14, height: 3, decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Purchase', style: AppTypography.chartLegendLabel),
              const SizedBox(width: 16),
              Container(width: 14, height: 8, decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFF22C55E), width: 0.5),
              )),
              const SizedBox(width: 4),
              Text('Profit', style: AppTypography.chartLegendLabel),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220 * ts,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (sortedLabels.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: niceInterval,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[300]!, strokeWidth: 0.5, dashArray: [4, 4]),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 60 * ts, interval: niceInterval,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                        return Text(AmountFormatter.short(value), style: AppTypography.chartAxisLabel);
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, interval: 1, reservedSize: 46 * ts,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= sortedLabels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Text(
                              formatChartLabel(sortedLabels[idx]),
                              style: AppTypography.chartAxisLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true, border: Border(
                  left: BorderSide(color: Colors.grey[300]!, width: 0.5),
                  bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
                )),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A2E),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final pl = idx >= 0 && idx < sortedLabels.length ? sortedLabels[idx] : '';
                        if (spot.barIndex == 0) {
                          final s = salesMap[pl] ?? 0;
                          final p = purchaseMap[pl] ?? 0;
                          return LineTooltipItem(
                            '$pl\nSales: ₹${AmountFormatter.shortSpaced(s)}\nProfit: ₹${AmountFormatter.shortSpaced(s - p)}',
                            AppTypography.chartTooltipValue,
                          );
                        }
                        return LineTooltipItem(
                          'Purchase: ₹${AmountFormatter.shortSpaced(spot.y)}',
                          AppTypography.chartTooltipValue,
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: salesSpots, isCurved: true, color: AppColors.blue, barWidth: 2.5,
                    dotData: FlDotData(show: sortedLabels.length <= 12),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF22C55E).withValues(alpha: 0.18)),
                  ),
                  LineChartBarData(
                    spots: purchaseSpots, isCurved: true, color: AppColors.amber, barWidth: 2.5,
                    dotData: FlDotData(show: sortedLabels.length <= 12),
                    belowBarData: BarAreaData(show: true, color: AppColors.surface),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  // ── Card: Profit Margin % Trend ──────────────────────────────────────────

  Widget _buildProfitMarginChart() {
    final data = _prepareTrendData();
    if (data == null) return const SizedBox.shrink();
    final ts = _ts(context);

    final sortedLabels = data['sortedLabels'] as List<String>;
    final salesMap = data['salesMap'] as Map<String, double>;
    final purchaseMap = data['purchaseMap'] as Map<String, double>;

    final marginSpots = <FlSpot>[];
    final marginValues = <double>[];
    for (int i = 0; i < sortedLabels.length; i++) {
      final s = salesMap[sortedLabels[i]] ?? 0;
      final p = purchaseMap[sortedLabels[i]] ?? 0;
      final margin = s > 0 ? ((s - p) / s * 100) : 0.0;
      marginSpots.add(FlSpot(i.toDouble(), margin));
      marginValues.add(margin);
    }

    if (marginSpots.isEmpty) return const SizedBox.shrink();

    final maxMargin = marginValues.reduce((a, b) => a > b ? a : b);
    final minMargin = marginValues.reduce((a, b) => a < b ? a : b);
    final avgMargin = marginValues.fold<double>(0, (s, v) => s + v) / marginValues.length;

    final chartMinY = (minMargin - 5).clamp(-100.0, 100.0);
    final chartMaxY = (maxMargin + 10).clamp(chartMinY + 10, 100.0);
    final yInterval = ((chartMaxY - chartMinY) / 4).ceilToDouble().clamp(5.0, 25.0);

    final marginColor = avgMargin >= 20
        ? const Color(0xFF22C55E)
        : avgMargin >= 10
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
        border: AppShadows.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Profit Margin Trend', style: AppTypography.chartSectionTitle),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: marginColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Avg ${avgMargin.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: marginColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('(Sales − Purchase) ÷ Sales × 100', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180 * ts,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                minX: 0,
                maxX: (sortedLabels.length - 1).toDouble(),
                minY: chartMinY,
                maxY: chartMaxY,
                gridData: FlGridData(
                  show: true, drawVerticalLine: false, horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[300]!, strokeWidth: 0.5, dashArray: [4, 4]),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 40 * ts, interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                        return Text('${value.toStringAsFixed(0)}%', style: AppTypography.chartAxisLabel);
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, interval: 1, reservedSize: 44 * ts,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= sortedLabels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Transform.rotate(
                            angle: -0.45,
                            child: Text(formatChartLabel(sortedLabels[idx]), style: AppTypography.chartAxisLabel),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true, border: Border(
                  left: BorderSide(color: Colors.grey[300]!, width: 0.5),
                  bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
                )),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A2E),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final pl = idx >= 0 && idx < sortedLabels.length ? sortedLabels[idx] : '';
                        final s = salesMap[pl] ?? 0;
                        final p = purchaseMap[pl] ?? 0;
                        return LineTooltipItem(
                          '$pl\nMargin: ${spot.y.toStringAsFixed(1)}%\nProfit: ₹${AmountFormatter.shortSpaced(s - p)}',
                          AppTypography.chartTooltipValue,
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: marginSpots, isCurved: true, curveSmoothness: 0.2, preventCurveOverShooting: true, color: marginColor, barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5, color: marginColor, strokeWidth: 1.5, strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(show: true, color: marginColor.withValues(alpha: 0.10)),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: avgMargin,
                      color: marginColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(fontSize: 11, color: marginColor, fontWeight: FontWeight.w600),
                        labelResolver: (_) => 'Avg ${avgMargin.toStringAsFixed(1)}%',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  // ── 5. Key metrics (KPI rows) ──────────────────────────────────────────────

  Widget _buildKeyMetrics() {
    if (_kpiLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          0,
          AppSpacing.pagePadding,
          0,
        ),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
          border: AppShadows.cardBorder,
        ),
        child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
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
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No KPIs configured',
                  style: AppTypography.itemTitle
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text('Tap Edit to add metrics',
                    style: AppTypography.itemSubtitle),
              ],
            ),
          ),
        ],
      );
    }

    return KpiSection(
      onEditTap: _openKpiManager,
      children:
          _kpiConfigs.asMap().entries.map((entry) {
        final i      = entry.key;
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
          onTap: () {},
        );
      }).toList(),
    );
  }
}
