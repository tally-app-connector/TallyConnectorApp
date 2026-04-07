// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:screenshot/screenshot.dart';
// import '../theme/app_theme.dart';
// import '../icons/app_icons.dart';
// import '../../models/report_data.dart';
// import '../models/company_model.dart';
// import '../widgets/report_widgets.dart';
// import '../../widgets/detail_widgets.dart';
// import '../../widgets/charts/report_chart.dart';
// import '../service/sales/sales_service.dart';
// import '../service/company_logo_service.dart';
// import '../service/excel_export_service.dart';
// import '../main.dart';
// import '../../utils/amount_formatter.dart';
// import 'pdf_export_screen.dart';
// import 'excel_export_screen.dart';
// import 'group_outstanding_detail_screen.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // OutstandingDetailScreen — Dedicated detail screen for Receivable & Payable.
// //
// // Layout: Ledger/Group toggle → summary cards → date range → aging chart
// //         → aging party wise.
// // ─────────────────────────────────────────────────────────────────────────────

// class OutstandingDetailScreen extends StatefulWidget {
//   final ReportMetric metric;

//   const OutstandingDetailScreen({super.key, required this.metric});

//   @override
//   State<OutstandingDetailScreen> createState() =>
//       _OutstandingDetailScreenState();
// }

// class _OutstandingDetailScreenState extends State<OutstandingDetailScreen> {
//   // ═══════════════════════════════════════════════════════════════════════════
//   //  STATE
//   // ═══════════════════════════════════════════════════════════════════════════

//   // Ledger / Group toggle (0 = Ledger, 1 = Group)
//   int _viewMode = 1;

//   // Date range
//   DateRangeFilter _dateRange = DateRangeFilter.mom();

//   // Chart type for aging analysis
//   late ReportChartType _chartType = widget.metric.defaultChartType;

//   // Loading
//   bool _isLoading = true;

//   // Report data
//   ReportValue _reportValue = ReportValue(
//     primaryValue: '—',
//     primaryUnit: '',
//     primaryLabel: 'Loading...',
//     changePercent: '',
//     isPositiveChange: true,
//     periodStart: DateTime.now(),
//     periodEnd: DateTime.now(),
//   );
//   ReportChartData _chartData = const ReportChartData(
//     dataPoints: [],
//     chartType: ReportChartType.horizontalBar,
//     title: '',
//     legends: [],
//   );

//   // Aging filter
//   int? _selectedDaysFilter; // null = All
//   int? _customDaysValue;

//   // Service & company
//   final SalesAnalyticsService _salesAnalyticsService = SalesAnalyticsService();
//   final ScreenshotController _screenshotController = ScreenshotController();
//   String? _companyGuid;
//   Company? _company;
//   Uint8List? _companyLogoBytes;

//   // Summary values
//   String _mainValue = '—';
//   String _mainUnit = '';
//   String _pendingValue = '—';
//   String _pendingUnit = '';
//   String _advanceValue = '—';
//   String _advanceUnit = '';

//   // Fiscal year for Top Paying Parties
//   late FiscalYear _selectedFiscalYear = FiscalYear.current();
//   final List<FiscalYear> _fiscalYearOptions = FiscalYear.available();

//   // Party & group data loaded from DB
//   List<CreditLimitParty> _creditLimitParties = [];
//   List<PaymentDueParty> _paymentDueParties = [];
//   List<TopPayingParty> _topPayingParties = [];
//   List<TopVendorParty> _topVendors = [];
//   List<GroupOutstanding> _receivableGroups = [];
//   List<GroupOutstanding> _payableGroups = [];

//   // See More / See Less toggle for list sections
//   bool _agingPartyExpanded = false;
//   bool _valueWiseExpanded = false;
//   bool _ledgerWiseExpanded = false;
//   static const int _initialItemCount = 5;

//   // ═══════════════════════════════════════════════════════════════════════════
//   //  LIFECYCLE
//   // ═══════════════════════════════════════════════════════════════════════════

//   @override
//   void initState() {
//     super.initState();
//     _loadCompany();
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   //  DATA LOADING
//   // ═══════════════════════════════════════════════════════════════════════════

//   Future<void> _loadCompany() async {
//     final selected = AppState.selectedCompany;
//     if (selected != null) {
//       _companyGuid = selected.guid;
//       _company = selected;
//     }

//     if (_companyGuid != null) {
//       final logo = await CompanyLogoService.loadLogo(_companyGuid!);
//       if (mounted) {
//         setState(() => _companyLogoBytes = logo);
//       }
//     }

//     _loadData();
//   }

//   Future<void> _loadData() async {
//     final metric = widget.metric;

//     if (_companyGuid == null) {
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final guid = _companyGuid!;

//       // Fetch real value
//       ReportValue realValue;
//       ReportChartData realChart;

//       if (metric == ReportMetric.receivable) {
//         realValue =
//             await _salesAnalyticsService.getTotalReceivable(companyGuid: guid);
//         realChart = await _salesAnalyticsService.getReceivableChart(
//           companyGuid: guid,
//           chartType: _chartType,
//         );
//       } else {
//         realValue =
//             await _salesAnalyticsService.getTotalPayable(companyGuid: guid);
//         realChart = await _salesAnalyticsService.getPayableChart(
//           companyGuid: guid,
//           chartType: _chartType,
//         );
//       }

//       // Load party & group data from DB
//       final creditLimit =
//           await _salesAnalyticsService.getCreditLimitExceeded(companyGuid: guid);
//       final paymentDue =
//           await _salesAnalyticsService.getPaymentDueParties(companyGuid: guid);

//       final fy = _selectedFiscalYear;
//       final fyStart = fy.startDate;
//       final fyEnd = fy.endDate;
//       final topPaying = await _salesAnalyticsService.getTopPayingParties(
//         companyGuid: guid
//       );
//       final topVend = await _salesAnalyticsService.getTopVendors(
//         companyGuid: guid
//       );

//       final recGroups =
//           await _salesAnalyticsService.getReceivableGroups(companyGuid: guid);
//       final payGroups =
//           await _salesAnalyticsService.getPayableGroups(companyGuid: guid);

//       // Compute pending/advance from real DB data
//       final parentGroup = metric == ReportMetric.receivable
//           ? 'Sundry Debtors'
//           : 'Sundry Creditors';
//       final breakdown = await _salesAnalyticsService.getOutstandingBreakdown(
//         companyGuid: guid,
//         parentGroup: parentGroup,
//       );

//       setState(() {
//         _reportValue = realValue;
//         _chartData = realChart;
//         _mainValue = realValue.primaryValue;
//         _mainUnit = realValue.primaryUnit;
//         _computeSummaryCards(breakdown);
//         _creditLimitParties = creditLimit;
//         _paymentDueParties = paymentDue;
//         _topPayingParties = topPaying;
//         _topVendors = topVend;
//         _receivableGroups = recGroups;
//         _payableGroups = payGroups;
//         _isLoading = false;
//       });
//     } catch (e, stack) {
//       debugPrint('Error loading ${metric.displayName} data: $e');
//       debugPrint('$stack');
//       setState(() => _isLoading = false);
//     }
//   }

//   void _computeSummaryCards(Map<String, double> breakdown) {
//     final pending = breakdown['pending'] ?? 0;
//     final advance = breakdown['advance'] ?? 0;

//     final pendingFormatted = AmountFormatter.format(pending);
//     final advanceFormatted = AmountFormatter.format(advance);

//     _pendingValue = pendingFormatted['value']!;
//     _pendingUnit = pendingFormatted['unit']!;
//     _advanceValue = advanceFormatted['value']!;
//     _advanceUnit = advanceFormatted['unit']!;
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   //  USER ACTIONS
//   // ═══════════════════════════════════════════════════════════════════════════

//   void _onDateRangeChanged(DateRangeFilter range) {
//     setState(() => _dateRange = range);
//     _loadData();
//   }

//   void _showCustomDatePicker() async {
//     final now = DateTime.now();
//     final initialStart =
//         _dateRange.startDate.isAfter(now) ? now : _dateRange.startDate;
//     final initialEnd =
//         _dateRange.endDate.isAfter(now) ? now : _dateRange.endDate;

//     final range = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2020),
//       lastDate: now,
//       initialDateRange: DateTimeRange(
//         start: initialStart,
//         end: initialEnd,
//       ),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: AppColors.blue,
//               onPrimary: Colors.white,
//               onSurface: AppColors.textPrimary,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );
//     if (range != null) {
//       _onDateRangeChanged(DateRangeFilter.custom(range.start, range.end));
//     }
//   }

//   void _onDaysFilterChanged(int? days) {
//     setState(() {
//       _selectedDaysFilter = days;
//       if (days != _customDaysValue) {
//         _customDaysValue = null;
//       }
//     });
//   }

//   void _showCustomDaysDialog() async {
//     final controller = TextEditingController(
//       text: _customDaysValue?.toString() ?? '',
//     );
//     final result = await showDialog<int>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Custom Days Filter'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           decoration: const InputDecoration(
//             labelText: 'Days overdue (e.g. 45)',
//             border: OutlineInputBorder(),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel'),
//           ),
//           FilledButton(
//             onPressed: () {
//               final val = int.tryParse(controller.text);
//               if (val != null && val > 0) {
//                 Navigator.pop(ctx, val);
//               }
//             },
//             child: const Text('Apply'),
//           ),
//         ],
//       ),
//     );
//     if (result != null) {
//       setState(() {
//         _customDaysValue = result;
//         _selectedDaysFilter = result;
//       });
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   //  SHARE / EXPORT
//   // ═══════════════════════════════════════════════════════════════════════════

//   void _showShareOptions() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (ctx) => SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 8),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Center(
//                 child: Container(
//                   width: 36,
//                   height: 4,
//                   margin: const EdgeInsets.only(bottom: 16),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFD1D5DB),
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.only(left: 20, bottom: 12),
//                 child: Text('SHARE REPORT', style: AppTypography.cardLabel),
//               ),
//               ListTile(
//                 leading:
//                     SvgPicture.string(AppIcons.filePdf, width: 36, height: 36),
//                 title:
//                     Text('Share as PDF', style: AppTypography.itemTitle),
//                 subtitle: Text('Formatted report with charts',
//                     style: AppTypography.itemSubtitle),
//                 trailing: const Icon(Icons.chevron_right,
//                     color: AppColors.textSecondary, size: 20),
//                 onTap: () {
//                   Navigator.pop(ctx);
//                   _openPdfExport();
//                 },
//               ),
//               Divider(
//                 height: 1,
//                 thickness: 0.5,
//                 indent: 20,
//                 endIndent: 20,
//                 color: Colors.grey.shade300,
//               ),
//               ListTile(
//                 leading:
//                     SvgPicture.string(AppIcons.fileCsv, width: 36, height: 36),
//                 title: Text('Share as Excel',
//                     style: AppTypography.itemTitle),
//                 subtitle: Text('Raw data for spreadsheets',
//                     style: AppTypography.itemSubtitle),
//                 trailing: const Icon(Icons.chevron_right,
//                     color: AppColors.textSecondary, size: 20),
//                 onTap: () {
//                   Navigator.pop(ctx);
//                   _openExcelExport();
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _openPdfExport() async {
//     final now = DateTime.now().toIso8601String();
//     final company = _company ??
//         Company(
//           guid: 'demo-guid',
//           masterId: 0,
//           alterId: 0,
//           name: 'Demo Company',
//           startingFrom: now,
//           endingAt: now,
//           address: '123 Test Street',
//           city: 'Mumbai',
//           state: 'Maharashtra',
//           gsttin: '27AABCU9603R1ZM',
//           createdAt: now,
//           updatedAt: now,
//         );

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(
//         child: CircularProgressIndicator(color: AppColors.blue),
//       ),
//     );

//     try {
//       final width = MediaQuery.of(context).size.width;
//       final cards = _getReportCards();
//       final cardCaptures = <Uint8List>[];

//       for (final card in cards) {
//         final capture = await _screenshotController.captureFromLongWidget(
//           InheritedTheme.captureAll(
//             context,
//             MediaQuery(
//               data: MediaQuery.of(context),
//               child: Material(
//                 color: Colors.white,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 5),
//                   child: SizedBox(width: width, child: card),
//                 ),
//               ),
//             ),
//           ),
//           delay: const Duration(milliseconds: 100),
//           pixelRatio: 3.0,
//           context: context,
//         );
//         cardCaptures.add(capture);
//       }

//       if (!mounted) return;
//       Navigator.pop(context);

//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => PdfExportScreen(
//             company: company,
//             metric: widget.metric,
//             reportValue: _reportValue,
//             chartData: _chartData,
//             dateRange: _dateRange,
//             salesPurchaseData: const SalesPurchaseChartData(
//               dataPoints: [],
//               title: '',
//             ),
//             revExpProfitData: const RevenueExpenseProfitData(
//               revenue: 0,
//               expense: 0,
//               profit: 0,
//             ),
//             cardCaptures: cardCaptures,
//             companyLogoBytes: _companyLogoBytes,
//           ),
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to capture screen: $e')),
//       );
//     }
//   }

//   Future<void> _openExcelExport() async {
//     if (_companyGuid == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content:
//                 Text('No company selected. Please select a company first.')),
//       );
//       return;
//     }
//     final companyGuid = _companyGuid!;
//     final companyName = _company?.name ?? 'Company';

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(
//         child: CircularProgressIndicator(color: AppColors.blue),
//       ),
//     );

//     try {
//       final result = await ExcelExportService.generateStockItemsExcel(
//         companyGuid: companyGuid,
//         companyName: companyName,
//         dateRange: _dateRange,
//         companyLogoBytes: _companyLogoBytes,
//       );

//       final fileName = '${companyName.replaceAll(' ', '_')}_stock_items.xlsx';

//       if (!mounted) return;
//       Navigator.pop(context);

//       if (result.items.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               'No stock items found. Please sync stock items & vouchers with inventory entries first.',
//             ),
//             duration: Duration(seconds: 4),
//           ),
//         );
//         return;
//       }

//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => ExcelExportScreen(
//             companyName: companyName,
//             fileName: fileName,
//             excelBytes: result.bytes,
//             items: result.items,
//             dateRange: _dateRange,
//             companyLogoBytes: _companyLogoBytes,
//           ),
//         ),
//       );
//     } catch (e, stack) {
//       debugPrint('Excel export error: $e');
//       debugPrint('$stack');
//       if (!mounted) return;
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to generate Excel: $e')),
//       );
//     }
//   }

//   List<Widget> _getReportCards() {
//     return [
//       _buildChartCard(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(_chartData.title, style: AppTypography.cardLabel),
//             const SizedBox(height: 16),
//             ReportChart(data: _chartData, height: 200),
//             if (_chartData.legends.isNotEmpty) ...[
//               const SizedBox(height: 16),
//               Center(child: ChartLegend(items: _chartData.legends)),
//             ],
//           ],
//         ),
//       ),
//     ];
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   //  BUILD
//   // ═══════════════════════════════════════════════════════════════════════════

//   @override
//   Widget build(BuildContext context) {
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: SystemUiOverlayStyle.dark.copyWith(
//         statusBarColor: Colors.transparent,
//       ),
//       child: Scaffold(
//         backgroundColor: AppColors.background,
//         body: SafeArea(
//           child: Column(
//             children: [
//               _buildHeader(),
//               const SizedBox(height: 14),
//               Expanded(
//                 child: _isLoading
//                     ? const Center(
//                         child: CircularProgressIndicator(color: AppColors.blue),
//                       )
//                     : SingleChildScrollView(
//                         physics: const BouncingScrollPhysics(),
//                         padding: const EdgeInsets.only(bottom: 32),
//                         child: Column(
//                           children: [
//                             // Ledger / Group toggle
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: AppSpacing.pagePadding,
//                               ),
//                               child: _buildLedgerGroupToggle(),
//                             ),
//                             const SizedBox(height: 16),

//                             // Summary cards row
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: AppSpacing.pagePadding,
//                               ),
//                               child: _buildSummaryCards(),
//                             ),
//                             const SizedBox(height: 16),

//                             // Date range selector
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: AppSpacing.pagePadding,
//                               ),
//                               child: DateRangeSelector(
//                                 selected: _dateRange,
//                                 onChanged: _onDateRangeChanged,
//                                 onCustomTap: _showCustomDatePicker,
//                               ),
//                             ),
//                             const SizedBox(height: 20),

//                             // Aging Analysis chart
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: AppSpacing.pagePadding,
//                               ),
//                               child: _buildAgingAnalysisCard(),
//                             ),
//                             const SizedBox(height: 20),

//                             // Aging Party Wise
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: AppSpacing.pagePadding,
//                               ),
//                               child: _buildAgingPartyWiseCard(),
//                             ),
//                             const SizedBox(height: 20),

//                             // Party Wise Aging (Value Wise)
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: AppSpacing.pagePadding,
//                               ),
//                               child: _buildPartyWiseValueCard(),
//                             ),
//                             const SizedBox(height: 20),

//                             // Top Paying Parties / Top Vendors
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: AppSpacing.pagePadding,
//                               ),
//                               child: widget.metric == ReportMetric.payable
//                                   ? TopVendorsCard(
//                                       vendors: _topVendors,
//                                       selectedFiscalYear: _selectedFiscalYear,
//                                       fiscalYearOptions: _fiscalYearOptions,
//                                       onFiscalYearChanged: (fy) {
//                                         setState(
//                                             () => _selectedFiscalYear = fy);
//                                         _loadData();
//                                       },
//                                     )
//                                   : TopPayingPartiesCard(
//                                       parties: _topPayingParties,
//                                       selectedFiscalYear: _selectedFiscalYear,
//                                       fiscalYearOptions: _fiscalYearOptions,
//                                       onFiscalYearChanged: (fy) {
//                                         setState(
//                                             () => _selectedFiscalYear = fy);
//                                         _loadData();
//                                       },
//                                     ),
//                             ),
//                             const SizedBox(height: 20),

//                             // Ledger Wise / Group Wise Outstanding
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: AppSpacing.pagePadding,
//                               ),
//                               child: _viewMode == 0
//                                   ? _buildLedgerWiseOutstandingCard()
//                                   : _buildGroupWiseOutstandingCard(),
//                             ),
//                           ],
//                         ),
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   //  SUB-WIDGETS
//   // ═══════════════════════════════════════════════════════════════════════════

//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(12, 10, AppSpacing.pagePadding, 0),
//       child: Row(
//         children: [
//           GestureDetector(
//             onTap: () => Navigator.of(context).pop(),
//             child: const SizedBox(
//               width: 36,
//               height: 36,
//               child: Center(
//                 child: Icon(
//                   Icons.arrow_back_ios_new,
//                   size: 16,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Text(widget.metric.displayName, style: AppTypography.pageTitle),
//           const Spacer(),
//           GestureDetector(
//             onTap: _showShareOptions,
//             child: Container(
//               width: 36,
//               height: 36,
//               margin: const EdgeInsets.only(right: 10),
//               decoration: BoxDecoration(
//                 color: AppColors.surface,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: AppColors.divider),
//               ),
//               child: Center(
//                 child: SvgPicture.string(
//                   AppIcons.share,
//                   width: 18,
//                   height: 18,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Ledger / Group segmented toggle
//   Widget _buildLedgerGroupToggle() {
//     return Container(
//       padding: const EdgeInsets.all(3),
//       decoration: BoxDecoration(
//         color: AppColors.pillBg,
//         borderRadius: BorderRadius.circular(AppRadius.pill),
//       ),
//       child: Row(
//         children: [
//           _buildTogglePill('Ledger', 0),
//           _buildTogglePill('Group', 1),
//         ],
//       ),
//     );
//   }

//   Widget _buildTogglePill(String label, int index) {
//     final isActive = _viewMode == index;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => setState(() => _viewMode = index),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           padding: const EdgeInsets.symmetric(vertical: 9),
//           decoration: BoxDecoration(
//             color: isActive ? AppColors.surface : Colors.transparent,
//             borderRadius: BorderRadius.circular(AppRadius.pillInner),
//             boxShadow: isActive ? AppShadows.pillActive : null,
//           ),
//           child: Center(
//             child: Text(
//               label,
//               style: isActive
//                   ? AppTypography.pillActive
//                   : AppTypography.pillInactive,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   /// Three summary cards: Receivable/Payable, Pending, Advance
//   Widget _buildSummaryCards() {
//     final isReceivable = widget.metric == ReportMetric.receivable;
//     final mainLabel = isReceivable ? 'Receivable' : 'Payable';
//     final mainColor = isReceivable ? AppColors.purple : AppColors.red;

//     return Row(
//       children: [
//         Expanded(
//           child: _buildSummaryCard(
//             label: mainLabel,
//             value: _mainValue,
//             unit: _mainUnit,
//             color: mainColor,
//           ),
//         ),
//         const SizedBox(width: 10),
//         Expanded(
//           child: _buildSummaryCard(
//             label: 'Pending',
//             value: _pendingValue,
//             unit: _pendingUnit,
//             color: AppColors.amber,
//           ),
//         ),
//         const SizedBox(width: 10),
//         Expanded(
//           child: _buildSummaryCard(
//             label: 'Advance',
//             value: _advanceValue,
//             unit: _advanceUnit,
//             color: AppColors.green,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSummaryCard({
//     required String label,
//     required String value,
//     required String unit,
//     required Color color,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(AppRadius.card),
//         border: Border.all(color: AppColors.divider),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: AppTypography.cardLabel.copyWith(fontSize: 11),
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//           ),
//           const SizedBox(height: 6),
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.baseline,
//             textBaseline: TextBaseline.alphabetic,
//             children: [
//               Text(
//                 '₹$value',
//                 style: TextStyle(
//                   fontFamily: AppTypography.fontSerif,
//                   fontSize: 18,
//                   fontWeight: FontWeight.w700,
//                   color: color,
//                   letterSpacing: -0.5,
//                   height: 1.0,
//                 ),
//               ),
//               const SizedBox(width: 3),
//               Text(
//                 unit,
//                 style: TextStyle(
//                   fontFamily: AppTypography.fontBody,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w500,
//                   color: color,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   /// Aging Analysis card with horizontal bar chart
//   Widget _buildAgingAnalysisCard() {
//     final accentColor = widget.metric.accentColor;
//     final agingColors = [
//       AppColors.green, // 0-30 days
//       const Color(0xFFC8860A), // 31-60 days (dark amber)
//       const Color(0xFFE67E22), // 61-90 days (orange)
//       AppColors.red, // 90+ days
//     ];

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(AppRadius.card),
//         boxShadow: AppShadows.card,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header: title + chart type toggle
//           Row(
//             children: [
//               Text(
//                 _chartData.title.isNotEmpty
//                     ? _chartData.title
//                     : 'Aging Analysis',
//                 style: AppTypography.cardLabel,
//               ),
//               const Spacer(),
//               ChartTypeSelector(
//                 selected: _chartType,
//                 availableTypes: widget.metric.applicableChartTypes,
//                 onChanged: (type) {
//                   setState(() => _chartType = type);
//                   _loadData();
//                 },
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // Custom horizontal bar chart
//           _buildAgingBars(agingColors),

//           const SizedBox(height: 16),

//           // Legend
//           Row(
//             children: [
//               Container(
//                 width: 10,
//                 height: 10,
//                 decoration: BoxDecoration(
//                   color: accentColor,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 'Outstanding Amount',
//                 style: AppTypography.itemSubtitle.copyWith(fontSize: 11),
//               ),
//             ],
//           ),

//           const SizedBox(height: 12),

//           // View Detail button
//           Align(
//             alignment: Alignment.centerRight,
//             child: OutlinedButton.icon(
//               onPressed: () {},
//               style: OutlinedButton.styleFrom(
//                 foregroundColor: AppColors.blue,
//                 backgroundColor: AppColors.blue.withValues(alpha: 0.08),
//                 side: const BorderSide(color: AppColors.blue, width: 1),
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 minimumSize: const Size(0, 30),
//                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               icon: Icon(Icons.analytics_outlined,
//                   size: 15, color: AppColors.blue),
//               label: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text(
//                     'View Detail',
//                     style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
//                   ),
//                   const SizedBox(width: 4),
//                   SvgPicture.string(
//                     AppIcons.chevronRight,
//                     width: 12,
//                     height: 12,
//                     colorFilter: const ColorFilter.mode(
//                       AppColors.blue,
//                       BlendMode.srcIn,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Renders aging horizontal bars with per-bucket colors
//   Widget _buildAgingBars(List<Color> colors) {
//     final dataPoints = _chartData.dataPoints;
//     if (dataPoints.isEmpty) {
//       return SizedBox(
//         height: 160,
//         child: Center(
//           child: Text('No Data', style: AppTypography.itemSubtitle),
//         ),
//       );
//     }

//     final maxValue =
//         dataPoints.map((dp) => dp.value).reduce((a, b) => a > b ? a : b);

//     // X-axis ticks
//     final tickCount = 3;
//     final tickInterval = _niceInterval(maxValue, tickCount);
//     final adjustedMax = (maxValue / tickInterval).ceil() * tickInterval;

//     return Column(
//       children: [
//         // X-axis header labels
//         Padding(
//           padding: const EdgeInsets.only(left: 80),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: List.generate(tickCount + 1, (i) {
//               final val = tickInterval * i;
//               return Text(
//                 AmountFormatter.short(val),
//                 style: AppTypography.chartAxisLabel,
//               );
//             }),
//           ),
//         ),
//         const SizedBox(height: 8),

//         // Bars
//         ...List.generate(dataPoints.length, (i) {
//           final dp = dataPoints[i];
//           final color = i < colors.length ? colors[i] : colors.last;
//           final fraction =
//               adjustedMax > 0 ? (dp.value / adjustedMax).clamp(0.0, 1.0) : 0.0;

//           return Padding(
//             padding: const EdgeInsets.only(bottom: 12),
//             child: Row(
//               children: [
//                 // Label
//                 SizedBox(
//                   width: 76,
//                   child: Text(
//                     dp.label,
//                     style: AppTypography.chartAxisLabel.copyWith(fontSize: 11),
//                     textAlign: TextAlign.right,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 // Bar
//                 Expanded(
//                   child: LayoutBuilder(
//                     builder: (context, constraints) {
//                       return Stack(
//                         children: [
//                           // Background track
//                           Container(
//                             height: 24,
//                             decoration: BoxDecoration(
//                               color: Colors.grey.shade100,
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                           ),
//                           // Filled bar
//                           AnimatedContainer(
//                             duration: const Duration(milliseconds: 400),
//                             curve: Curves.easeOutCubic,
//                             height: 24,
//                             width: constraints.maxWidth * fraction,
//                             decoration: BoxDecoration(
//                               color: color,
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 // Value label
//                 SizedBox(
//                   width: 42,
//                   child: Text(
//                     AmountFormatter.short(dp.value),
//                     style: AppTypography.chartAxisLabel.copyWith(
//                       fontWeight: FontWeight.w600,
//                       color: AppColors.textPrimary,
//                     ),
//                     textAlign: TextAlign.right,
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }),
//       ],
//     );
//   }

//   double _niceInterval(double maxVal, int ticks) {
//     if (maxVal <= 0) return 1;
//     final raw = maxVal / ticks;
//     final magnitude = pow(10, (log(raw) / ln10).floor()).toDouble();
//     final residual = raw / magnitude;
//     double nice;
//     if (residual <= 1.5) {
//       nice = 1;
//     } else if (residual <= 3) {
//       nice = 2;
//     } else if (residual <= 7) {
//       nice = 5;
//     } else {
//       nice = 10;
//     }
//     return nice * magnitude;
//   }

//   /// Aging Party Wise card with days filter pills
//   Widget _buildAgingPartyWiseCard() {
//     final isReceivable = widget.metric == ReportMetric.receivable;
//     final accentColor = isReceivable ? AppColors.purple : AppColors.red;

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(AppRadius.card),
//         boxShadow: AppShadows.card,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Title
//           Text(
//             'Aging Party Wise (Day-Wise)',
//             style: AppTypography.cardLabel,
//           ),
//           const SizedBox(height: 12),

//           // Days filter pills
//           _OutstandingDaysFilterPills(
//             selectedDays: _selectedDaysFilter,
//             customValue: _customDaysValue,
//             onChanged: _onDaysFilterChanged,
//             onCustomTap: _showCustomDaysDialog,
//             accentColor: accentColor,
//           ),
//           const SizedBox(height: 16),

//           // Party list
//           if (isReceivable)
//             ..._buildReceivablePartyList()
//           else
//             ..._buildPayablePartyList(),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildReceivablePartyList() {
//     final parties = _creditLimitParties;
//     final filtered = _selectedDaysFilter == null
//         ? List<CreditLimitParty>.from(parties)
//         : parties
//             .where((p) => p.daysOverLimit >= _selectedDaysFilter!)
//             .toList();
//     // Sort by days overdue descending (highest days first)
//     filtered.sort((a, b) => b.daysOverLimit.compareTo(a.daysOverLimit));

//     if (filtered.isEmpty) {
//       return [
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16),
//           child: Center(
//             child: Text(
//               'No parties for ${_selectedDaysFilter}+ days',
//               style: AppTypography.itemSubtitle,
//             ),
//           ),
//         ),
//       ];
//     }

//     final displayCount = _agingPartyExpanded
//         ? filtered.length
//         : filtered.length.clamp(0, _initialItemCount);

//     final widgets = <Widget>[];
//     for (var i = 0; i < displayCount; i++) {
//       final party = filtered[i];
//       final daysColor = party.daysOverLimit >= 90
//           ? AppColors.red
//           : party.daysOverLimit >= 60
//               ? const Color(0xFFE67E22)
//               : party.daysOverLimit >= 30
//                   ? AppColors.amber
//                   : AppColors.textSecondary;

//       widgets.add(
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   party.name,
//                   style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     '₹${AmountFormatter.short(party.currentOutstanding)}',
//                     style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                   ),
//                   const SizedBox(height: 4),
//                   Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
//                     decoration: BoxDecoration(
//                       color: daysColor.withValues(alpha: 0.1),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.access_time, size: 12, color: daysColor),
//                         const SizedBox(width: 3),
//                         Text(
//                           '${party.daysOverLimit} days',
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w600,
//                             color: daysColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       );

//       if (i < displayCount - 1) {
//         widgets.add(SizedBox(
//           height: 1,
//           child: OverflowBox(
//             maxWidth: MediaQuery.of(context).size.width,
//             child:
//                 Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
//           ),
//         ));
//       }
//     }

//     if (filtered.length > _initialItemCount) {
//       widgets.add(_buildSeeMoreButton(
//         expanded: _agingPartyExpanded,
//         totalCount: filtered.length,
//         onTap: () => setState(() => _agingPartyExpanded = !_agingPartyExpanded),
//       ));
//     }

//     return widgets;
//   }

//   List<Widget> _buildPayablePartyList() {
//     final parties = _paymentDueParties;
//     final filtered = _selectedDaysFilter == null
//         ? List<PaymentDueParty>.from(parties)
//         : parties.where((p) => p.daysOverdue >= _selectedDaysFilter!).toList();
//     // Sort by days overdue descending (highest days first)
//     filtered.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));

//     if (filtered.isEmpty) {
//       return [
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16),
//           child: Center(
//             child: Text(
//               'No vendors for ${_selectedDaysFilter}+ days',
//               style: AppTypography.itemSubtitle,
//             ),
//           ),
//         ),
//       ];
//     }

//     final displayCount = _agingPartyExpanded
//         ? filtered.length
//         : filtered.length.clamp(0, _initialItemCount);

//     final widgets = <Widget>[];
//     for (var i = 0; i < displayCount; i++) {
//       final party = filtered[i];
//       final daysColor = party.daysOverdue >= 90
//           ? AppColors.red
//           : party.daysOverdue >= 60
//               ? const Color(0xFFE67E22)
//               : party.daysOverdue >= 30
//                   ? AppColors.amber
//                   : AppColors.textSecondary;

//       widgets.add(
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   party.name,
//                   style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     '₹${AmountFormatter.short(party.amountDue)}',
//                     style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                   ),
//                   const SizedBox(height: 4),
//                   Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                     decoration: BoxDecoration(
//                       color: daysColor.withValues(alpha: 0.1),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.access_time, size: 12, color: daysColor),
//                         const SizedBox(width: 3),
//                         Text(
//                           '${party.daysOverdue} days',
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w600,
//                             color: daysColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       );

//       if (i < displayCount - 1) {
//         widgets.add(SizedBox(
//           height: 1,
//           child: OverflowBox(
//             maxWidth: MediaQuery.of(context).size.width,
//             child:
//                 Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
//           ),
//         ));
//       }
//     }

//     if (filtered.length > _initialItemCount) {
//       widgets.add(_buildSeeMoreButton(
//         expanded: _agingPartyExpanded,
//         totalCount: filtered.length,
//         onTap: () => setState(() => _agingPartyExpanded = !_agingPartyExpanded),
//       ));
//     }

//     return widgets;
//   }

//   /// Party Wise Aging (Value Wise) — sorted by outstanding amount descending
//   Widget _buildPartyWiseValueCard() {
//     final isReceivable = widget.metric == ReportMetric.receivable;

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(AppRadius.card),
//         boxShadow: AppShadows.card,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Party Wise Aging (Value Wise)',
//             style: AppTypography.cardLabel,
//           ),
//           const SizedBox(height: 16),
//           if (isReceivable)
//             ..._buildReceivableValueList()
//           else
//             ..._buildPayableValueList(),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildReceivableValueList() {
//     final parties = List<CreditLimitParty>.from(_creditLimitParties)
//       ..sort((a, b) => b.currentOutstanding.compareTo(a.currentOutstanding));

//     final now = DateTime.now();
//     final displayCount = _valueWiseExpanded
//         ? parties.length
//         : parties.length.clamp(0, _initialItemCount);
//     final widgets = <Widget>[];

//     for (var i = 0; i < displayCount; i++) {
//       final party = parties[i];
//       final dueDate = now.subtract(Duration(days: party.daysOverLimit));
//       final daysColor = party.daysOverLimit >= 90
//           ? AppColors.red
//           : party.daysOverLimit >= 60
//               ? const Color(0xFFE67E22)
//               : party.daysOverLimit >= 30
//                   ? AppColors.amber
//                   : AppColors.textSecondary;

//       widgets.add(
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       party.name,
//                       style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       'Due: ${_formatDate(dueDate)}',
//                       style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     '₹${AmountFormatter.shortSpaced(party.currentOutstanding)}',
//                     style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                   ),
//                   const SizedBox(height: 4),
//                   Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
//                     decoration: BoxDecoration(
//                       color: daysColor.withValues(alpha: 0.1),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.access_time, size: 12, color: daysColor),
//                         const SizedBox(width: 3),
//                         Text(
//                           '${party.daysOverLimit} days',
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w600,
//                             color: daysColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       );

//       if (i < displayCount - 1) {
//         widgets.add(SizedBox(
//           height: 1,
//           child: OverflowBox(
//             maxWidth: MediaQuery.of(context).size.width,
//             child:
//                 Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
//           ),
//         ));
//       }
//     }

//     if (parties.length > _initialItemCount) {
//       widgets.add(_buildSeeMoreButton(
//         expanded: _valueWiseExpanded,
//         totalCount: parties.length,
//         onTap: () => setState(() => _valueWiseExpanded = !_valueWiseExpanded),
//       ));
//     }

//     return widgets;
//   }

//   List<Widget> _buildPayableValueList() {
//     final parties = List<PaymentDueParty>.from(_paymentDueParties)
//       ..sort((a, b) => b.amountDue.compareTo(a.amountDue));

//     final displayCount = _valueWiseExpanded
//         ? parties.length
//         : parties.length.clamp(0, _initialItemCount);
//     final widgets = <Widget>[];

//     for (var i = 0; i < displayCount; i++) {
//       final party = parties[i];
//       final daysColor = party.daysOverdue >= 90
//           ? AppColors.red
//           : party.daysOverdue >= 60
//               ? const Color(0xFFE67E22)
//               : party.daysOverdue >= 30
//                   ? AppColors.amber
//                   : AppColors.textSecondary;

//       widgets.add(
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       party.name,
//                       style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       'Due: ${party.dueDate != null ? _formatDate(party.dueDate!) : 'N/A'}',
//                       style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     '₹${AmountFormatter.shortSpaced(party.amountDue)}',
//                     style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                   ),
//                   const SizedBox(height: 4),
//                   Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
//                     decoration: BoxDecoration(
//                       color: daysColor.withValues(alpha: 0.1),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.access_time, size: 12, color: daysColor),
//                         const SizedBox(width: 3),
//                         Text(
//                           '${party.daysOverdue} days',
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w600,
//                             color: daysColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       );

//       if (i < displayCount - 1) {
//         widgets.add(SizedBox(
//           height: 1,
//           child: OverflowBox(
//             maxWidth: MediaQuery.of(context).size.width,
//             child:
//                 Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
//           ),
//         ));
//       }
//     }

//     if (parties.length > _initialItemCount) {
//       widgets.add(_buildSeeMoreButton(
//         expanded: _valueWiseExpanded,
//         totalCount: parties.length,
//         onTap: () => setState(() => _valueWiseExpanded = !_valueWiseExpanded),
//       ));
//     }

//     return widgets;
//   }

//   String _formatDate(DateTime date) {
//     const months = [
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     return '${date.day} ${months[date.month - 1]} ${date.year}';
//   }

//   /// Ledger Wise Outstanding card
//   Widget _buildLedgerWiseOutstandingCard() {
//     final isReceivable = widget.metric == ReportMetric.receivable;
//     final parties = isReceivable
//         ? (List<CreditLimitParty>.from(_creditLimitParties)
//           ..sort(
//               (a, b) => b.currentOutstanding.compareTo(a.currentOutstanding)))
//         : <CreditLimitParty>[];
//     final payableParties = !isReceivable
//         ? (List<PaymentDueParty>.from(_paymentDueParties)
//           ..sort((a, b) => b.amountDue.compareTo(a.amountDue)))
//         : <PaymentDueParty>[];

//     final avatarColors = [
//       const Color(0xFF6366F1), // indigo
//       const Color(0xFFF59E0B), // amber
//       const Color(0xFF10B981), // emerald
//       const Color(0xFFEF4444), // red
//       const Color(0xFF8B5CF6), // violet
//       const Color(0xFF06B6D4), // cyan
//       const Color(0xFFF97316), // orange
//       const Color(0xFFEC4899), // pink
//     ];

//     final totalCount = isReceivable ? parties.length : payableParties.length;
//     final displayCount = _ledgerWiseExpanded
//         ? totalCount
//         : totalCount.clamp(0, _initialItemCount);

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(AppRadius.card),
//         boxShadow: AppShadows.card,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Ledger Wise Outstanding',
//             style: AppTypography.cardLabel,
//           ),
//           const SizedBox(height: 16),
//           for (var i = 0; i < displayCount; i++) ...[
//             _buildLedgerRow(
//               name: isReceivable ? parties[i].name : payableParties[i].name,
//               group: isReceivable ? 'Sundry Debtors' : 'Sundry Creditors',
//               amount: isReceivable
//                   ? parties[i].currentOutstanding
//                   : payableParties[i].amountDue,
//               days: isReceivable
//                   ? parties[i].daysOverLimit
//                   : payableParties[i].daysOverdue,
//               avatarColor: avatarColors[i % avatarColors.length],
//               amountColor: null,
//             ),
//             if (i < displayCount - 1)
//               SizedBox(
//                 height: 1,
//                 child: OverflowBox(
//                   maxWidth: MediaQuery.of(context).size.width,
//                   child: Divider(
//                       height: 1, thickness: 0.5, color: Colors.grey.shade200),
//                 ),
//               ),
//           ],
//           if (totalCount > _initialItemCount)
//             _buildSeeMoreButton(
//               expanded: _ledgerWiseExpanded,
//               totalCount: totalCount,
//               onTap: () =>
//                   setState(() => _ledgerWiseExpanded = !_ledgerWiseExpanded),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLedgerRow({
//     required String name,
//     required String group,
//     required double amount,
//     required int days,
//     required Color avatarColor,
//     Color? amountColor,
//   }) {
//     final daysColor = days >= 90
//         ? AppColors.red
//         : days >= 60
//             ? const Color(0xFFE67E22)
//             : days >= 30
//                 ? AppColors.amber
//                 : AppColors.textSecondary;

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 12),
//       child: Row(
//         children: [
//           // Avatar
//           Container(
//             width: 36,
//             height: 36,
//             decoration: BoxDecoration(
//               color: avatarColor.withValues(alpha: 0.15),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Center(
//               child: Text(
//                 name.isNotEmpty ? name[0].toUpperCase() : '?',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w700,
//                   color: avatarColor,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           // Name & group
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   name,
//                   style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 3),
//                 Text(
//                   group,
//                   style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 10),
//           // Amount & days
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 '₹${AmountFormatter.shortSpaced(amount)}',
//                 style: AppTypography.itemTitle.copyWith(
//                   fontSize: 13,
//                   color: amountColor,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: daysColor.withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   '${days}d',
//                   style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                     color: daysColor,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   /// Group Wise Outstanding card (shown when Group segment is selected)
//   Widget _buildGroupWiseOutstandingCard() {
//     final isReceivable = widget.metric == ReportMetric.receivable;
//     final groups =
//         isReceivable ? _receivableGroups : _payableGroups;

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(AppRadius.card),
//         boxShadow: AppShadows.card,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Group Wise Outstanding',
//             style: AppTypography.cardLabel,
//           ),
//           const SizedBox(height: 16),
//           for (var i = 0; i < groups.length; i++) ...[
//             _buildGroupRow(groups[i], isReceivable: isReceivable),
//             if (i < groups.length - 1)
//               SizedBox(
//                 height: 1,
//                 child: OverflowBox(
//                   maxWidth: MediaQuery.of(context).size.width,
//                   child: Divider(
//                       height: 1, thickness: 0.5, color: Colors.grey.shade200),
//                 ),
//               ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildGroupRow(GroupOutstanding group, {bool isReceivable = true}) {
//     final groupColor = isReceivable ? AppColors.purple : AppColors.red;
//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (_) => GroupOutstandingDetailScreen(
//               group: group,
//               isReceivable: widget.metric == ReportMetric.receivable,
//             ),
//           ),
//         );
//       },
//       behavior: HitTestBehavior.opaque,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Dot (top-aligned with group name)
//             Padding(
//               padding: const EdgeInsets.only(top: 5),
//               child: Container(
//                 width: 8,
//                 height: 8,
//                 decoration: BoxDecoration(
//                   color: groupColor,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 10),
//             // Content column
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Row 1: Group name + Amount & chevron
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           group.groupName,
//                           style: AppTypography.itemTitle.copyWith(fontSize: 13),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Text(
//                         '₹${AmountFormatter.shortSpaced(group.amount)}',
//                         style: AppTypography.itemTitle.copyWith(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: null,
//                         ),
//                       ),
//                       const SizedBox(width: 4),
//                       const Icon(
//                         Icons.chevron_right,
//                         size: 18,
//                         color: AppColors.textSecondary,
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 3),
//                   // Row 2: Party count + percentage
//                   Row(
//                     children: [
//                       Text(
//                         '${group.partyCount} parties',
//                         style:
//                             AppTypography.itemSubtitle.copyWith(fontSize: 12),
//                       ),
//                       const Spacer(),
//                       Text(
//                         '${group.percentage}%',
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w600,
//                           color: groupColor,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   // Row 3: Progress bar
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(2),
//                     child: SizedBox(
//                       height: 4,
//                       child: LinearProgressIndicator(
//                         value: group.percentage / 100,
//                         backgroundColor: Colors.grey.shade100,
//                         valueColor: AlwaysStoppedAnimation<Color>(
//                           groupColor,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSeeMoreButton({
//     required bool expanded,
//     required int totalCount,
//     required VoidCallback onTap,
//   }) {
//     final remaining = totalCount - _initialItemCount;
//     return GestureDetector(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.only(top: 12),
//         child: Center(
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             decoration: BoxDecoration(
//               color: AppColors.blue.withValues(alpha: 0.08),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   expanded ? 'See Less' : 'See More ($remaining)',
//                   style: const TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.blue,
//                   ),
//                 ),
//                 const SizedBox(width: 4),
//                 Icon(
//                   expanded
//                       ? Icons.keyboard_arrow_up
//                       : Icons.keyboard_arrow_down,
//                   size: 16,
//                   color: AppColors.blue,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildChartCard({required Widget child}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: AppColors.surface,
//           borderRadius: BorderRadius.circular(AppRadius.card),
//           boxShadow: AppShadows.card,
//         ),
//         child: child,
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// //  Days filter pills with configurable accent color
// // ─────────────────────────────────────────────────────────────────────────────

// class _OutstandingDaysFilterPills extends StatelessWidget {
//   final int? selectedDays;
//   final ValueChanged<int?> onChanged;
//   final VoidCallback onCustomTap;
//   final int? customValue;
//   final Color accentColor;

//   const _OutstandingDaysFilterPills({
//     required this.selectedDays,
//     required this.onChanged,
//     required this.onCustomTap,
//     required this.accentColor,
//     this.customValue,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Wrap(
//       spacing: 6,
//       runSpacing: 6,
//       children: [
//         _buildPill('All', null),
//         _buildPill('30+', 30),
//         _buildPill('60+', 60),
//         _buildPill('90+', 90),
//         _buildCustomPill(),
//       ],
//     );
//   }

//   Widget _buildPill(String label, int? days) {
//     final isActive = selectedDays == days && customValue == null;
//     return GestureDetector(
//       onTap: () => onChanged(days),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 150),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
//         decoration: BoxDecoration(
//           color: isActive ? accentColor : accentColor.withValues(alpha: 0.08),
//           borderRadius: BorderRadius.circular(16),
//           border: isActive
//               ? null
//               : Border.all(color: accentColor.withValues(alpha: 0.25)),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.w600,
//             color: isActive ? Colors.white : accentColor,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildCustomPill() {
//     final isActive = customValue != null && selectedDays == customValue;
//     return GestureDetector(
//       onTap: onCustomTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 150),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
//         decoration: BoxDecoration(
//           color: isActive ? accentColor : accentColor.withValues(alpha: 0.08),
//           borderRadius: BorderRadius.circular(16),
//           border: isActive
//               ? null
//               : Border.all(color: accentColor.withValues(alpha: 0.25)),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               isActive ? '${customValue}+' : 'Custom',
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: isActive ? Colors.white : accentColor,
//               ),
//             ),
//             const SizedBox(width: 4),
//             Icon(
//               Icons.arrow_drop_down,
//               size: 16,
//               color: isActive ? Colors.white : accentColor,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/desktop_responsive_wrapper.dart';
import '../theme/app_theme.dart';
import '../icons/app_icons.dart';
import '../../models/report_data.dart';
import '../../widgets/charts/report_chart.dart';
import '../../widgets/detail_widgets.dart';
import '../../services/sales_service.dart';
import '../main.dart';
import '../../utils/amount_formatter.dart';
import 'group_outstanding_detail_screen.dart';

class OutstandingDetailScreen extends StatefulWidget {
  final ReportMetric metric;

  const OutstandingDetailScreen({super.key, required this.metric});

  @override
  State<OutstandingDetailScreen> createState() =>
      _OutstandingDetailScreenState();
}

class _OutstandingDetailScreenState extends State<OutstandingDetailScreen> {
  // ═══════════════════════════════════════════════════════════════════════════
  //  STATE
  // ═══════════════════════════════════════════════════════════════════════════

  int _viewMode = 1; // 0 = Ledger, 1 = Group

  bool _isLoading = true;
  bool _isChartLoading = false;

  // Service & company
  final SalesAnalyticsService _salesAnalyticsService = SalesAnalyticsService();
  String? _companyGuid;

  // Summary values
  String _mainValue = '—';
  String _mainUnit = '';
  String _pendingValue = '—';
  String _pendingUnit = '';
  String _advanceValue = '—';
  String _advanceUnit = '';

  // Date range
  DateRangeFilter _dateRange = DateRangeFilter.mom();

  // Chart type for aging analysis
  late ReportChartType _chartType = widget.metric.defaultChartType;
  ReportChartData _chartData = const ReportChartData(
    dataPoints: [],
    chartType: ReportChartType.horizontalBar,
    title: '',
    legends: [],
  );

  // Aging filter
  int? _selectedDaysFilter; // null = All
  int? _customDaysValue;

  // Fiscal year for Top Paying Parties
  late FiscalYear _selectedFiscalYear = FiscalYear.current();
  final List<FiscalYear> _fiscalYearOptions = FiscalYear.available();

  // Party & group data loaded from DB
  List<CreditLimitParty> _creditLimitParties = [];
  List<PaymentDueParty> _paymentDueParties = [];
  List<TopPayingParty> _topPayingParties = [];
  List<TopVendorParty> _topVendors = [];
  List<GroupOutstanding> _receivableGroups = [];
  List<GroupOutstanding> _payableGroups = [];

  // See More / See Less toggle for list sections
  bool _agingPartyExpanded = false;
  bool _valueWiseExpanded = false;
  bool _ledgerWiseExpanded = false;
  static const int _initialItemCount = 5;

  bool get _isReceivable => widget.metric == ReportMetric.receivable;

  // ═══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _companyGuid = AppState.selectedCompany?.guid;
    _loadData();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DATA LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Format DateTime to YYYYMMDD string for service calls
  String _fmtDate(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    if (_companyGuid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // First load shows full-screen loader, subsequent loads only show chart loader
    final isFirstLoad = _isLoading;
    if (!isFirstLoad) {
      if (mounted) setState(() => _isChartLoading = true);
    }

    try {
      final guid = _companyGuid!;
      final from = _fmtDate(_dateRange.startDate);
      final to = _fmtDate(_dateRange.endDate);

      debugPrint('═══ OutstandingDetail _loadData ═══');
      debugPrint('  metric: ${widget.metric.displayName}');
      debugPrint('  dateRange: ${_dateRange.type} | from=$from | to=$to');
      debugPrint('  chartType: $_chartType');

      // Fetch real value
      ReportValue realValue;
      ReportChartData realChart;
      if (_isReceivable) {
        realValue = await _salesAnalyticsService.getTotalReceivable(
            companyGuid: guid, fromDate: from, toDate: to);
        realChart = await _salesAnalyticsService.getReceivableChart(
          companyGuid: guid,
          chartType: _chartType,
          fromDate: from,
          toDate: to,
        );
      } else {
        realValue = await _salesAnalyticsService.getTotalPayable(
            companyGuid: guid, fromDate: from, toDate: to);
        realChart = await _salesAnalyticsService.getPayableChart(
          companyGuid: guid,
          chartType: _chartType,
          fromDate: from,
          toDate: to,
        );
      }

      debugPrint(
          '  totalValue: ${realValue.primaryValue} ${realValue.primaryUnit}');
      debugPrint('  chartDataPoints: ${realChart.dataPoints.length}');
      for (final dp in realChart.dataPoints) {
        debugPrint('    - ${dp.label}: ${dp.value}');
      }

      // Load party & group data from DB
      final creditLimit = await _salesAnalyticsService.getCreditLimitExceeded(
          companyGuid: guid, fromDate: from, toDate: to);
      final paymentDue = await _salesAnalyticsService.getPaymentDueParties(
          companyGuid: guid, fromDate: from, toDate: to);

      final topPaying = await _salesAnalyticsService.getTopPayingParties(
        companyGuid: guid,
      );
      final topVend = await _salesAnalyticsService.getTopVendors(
        companyGuid: guid,
      );

      final recGroups =
          await _salesAnalyticsService.getReceivableGroups(companyGuid: guid);
      final payGroups =
          await _salesAnalyticsService.getPayableGroups(companyGuid: guid);

      // Compute pending/advance from real DB data
      final parentGroup = _isReceivable ? 'Sundry Debtors' : 'Sundry Creditors';
      final breakdown = await _salesAnalyticsService.getOutstandingBreakdown(
        companyGuid: guid,
        parentGroup: parentGroup,
      );

      if (!mounted) return;
      setState(() {
        _mainValue = realValue.primaryValue;
        _mainUnit = realValue.primaryUnit;
        _chartData = realChart;
        _computeSummaryCards(breakdown);
        _creditLimitParties = creditLimit;
        _paymentDueParties = paymentDue;
        _topPayingParties = topPaying;
        _topVendors = topVend;
        _receivableGroups = recGroups;
        _payableGroups = payGroups;
        _isLoading = false;
        _isChartLoading = false;
      });
    } catch (e, stack) {
      debugPrint('Error loading ${widget.metric.displayName} data: $e');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isChartLoading = false;
      });
    }
  }

  void _computeSummaryCards(Map<String, double> breakdown) {
    final pending = breakdown['pending'] ?? 0;
    final advance = breakdown['advance'] ?? 0;

    final pendingFormatted = AmountFormatter.format(pending);
    final advanceFormatted = AmountFormatter.format(advance);

    _pendingValue = pendingFormatted['value']!;
    _pendingUnit = pendingFormatted['unit']!;
    _advanceValue = advanceFormatted['value']!;
    _advanceUnit = advanceFormatted['unit']!;
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

  void _onDaysFilterChanged(int? days) {
    setState(() {
      _selectedDaysFilter = days;
      if (days != _customDaysValue) {
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
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Days Filter'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Days overdue (e.g. 45)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _customDaysValue = result;
        _selectedDaysFilter = result;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SHARE / EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface, // old: Colors.white
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider, // old: Color(0xFFD1D5DB)
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 12),
                child: Text('SHARE REPORT', style: AppTypography.cardLabel),
              ),
              ListTile(
                leading:
                    SvgPicture.string(AppIcons.filePdf, width: 36, height: 36),
                title: Text('Share as PDF', style: AppTypography.itemTitle),
                subtitle: Text('Formatted report with charts',
                    style: AppTypography.itemSubtitle),
                trailing: Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 20,
                endIndent: 20,
                color: AppColors.divider, // old: Colors.grey.shade300
              ),
              ListTile(
                leading:
                    SvgPicture.string(AppIcons.fileCsv, width: 36, height: 36),
                title: Text('Share as Excel', style: AppTypography.itemTitle),
                subtitle: Text('Raw data for spreadsheets',
                    style: AppTypography.itemSubtitle),
                trailing: Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
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
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Color _daysColor(int days) {
    if (days >= 90) return AppColors.red;
    if (days >= 60) return const Color(0xFFE67E22);
    if (days >= 30) return AppColors.amber;
    return AppColors.textSecondary;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.blue),
                      )
                    : DesktopResponsiveWrapper(
                        child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          children: [
                            // Ledger / Group toggle
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _buildLedgerGroupToggle(),
                            ),
                            const SizedBox(height: 16),

                            // Summary cards row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _buildSummaryCards(),
                            ),
                            const SizedBox(height: 16),

                            // Date range selector
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

                            // Aging Analysis chart
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _buildAgingAnalysisCard(),
                            ),
                            const SizedBox(height: 20),

                            // Aging Party Wise
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _buildAgingPartyWiseCard(),
                            ),
                            const SizedBox(height: 20),

                            // Party Wise Aging (Value Wise)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _buildPartyWiseValueCard(),
                            ),
                            const SizedBox(height: 20),

                            // Top Paying Parties / Top Vendors
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _isReceivable
                                  ? _buildFastestPayingPartiesCard()
                                  : _buildTopVendorsCard(),
                            ),
                            const SizedBox(height: 20),

                            // Ledger Wise / Group Wise Outstanding
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _viewMode == 0
                                  ? _buildLedgerWiseOutstandingCard()
                                  : _buildGroupWiseOutstandingCard(),
                            ),
                          ],
                        ),
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
  //  SUB-WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, AppSpacing.pagePadding, 0),
      child: Row(
        children: [
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
          Text(widget.metric.displayName, style: AppTypography.pageTitle),
          const Spacer(),
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

  /// Ledger / Group segmented toggle
  Widget _buildLedgerGroupToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.pillBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTogglePill('Ledger', 0),
          _buildTogglePill('Group', 1),
        ],
      ),
    );
  }

  Widget _buildTogglePill(String label, int index) {
    final isActive = _viewMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive ? AppShadows.pillActive : null,
          ),
          child: Center(
            child: Text(
              label,
              style: isActive
                  ? AppTypography.pillActive
                      .copyWith(color: AppColors.textPrimary)
                  : AppTypography.pillInactive,
            ),
          ),
        ),
      ),
    );
  }

  /// Three summary cards: Receivable/Payable, Pending, Advance
  Widget _buildSummaryCards() {
    final mainLabel = _isReceivable ? 'Receivable' : 'Payable';
    final mainColor = _isReceivable ? AppColors.purple : AppColors.red;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: mainLabel,
            value: _mainValue,
            unit: _mainUnit,
            color: mainColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            label: 'Pending',
            value: _pendingValue,
            unit: _pendingUnit,
            color: AppColors.amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            label: 'Advance',
            value: _advanceValue,
            unit: _advanceUnit,
            color: AppColors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.cardLabel.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹$value',
                  style: TextStyle(
                    fontFamily: AppTypography.fontSerif,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Aging Analysis card with chart
  Widget _buildAgingAnalysisCard() {
    final accentColor = widget.metric.accentColor;

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
          // Title
          Text('AGING ANALYSIS', style: AppTypography.cardLabel),
          const SizedBox(height: 12),

          // Chart type selector — scrollable row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: ReportChartType.values.map((type) {
                final isActive = _chartType == type;
                final label = _chartTypeLabel(type);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _chartType = type);
                      _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.blue.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? AppColors.blue : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AppColors.blue
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Chart
          if (_isChartLoading)
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.blue, strokeWidth: 2),
              ),
            )
          else if (_chartData.dataPoints.isNotEmpty)
            SizedBox(
              height: 220,
              child: ReportChart(data: _chartData, height: 220),
            )
          else
            SizedBox(
              height: 160,
              child: Center(
                child: Text('No Data', style: AppTypography.itemSubtitle),
              ),
            ),

          const SizedBox(height: 16),

          // Legend
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Outstanding Amount',
                style: AppTypography.itemSubtitle.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _chartTypeLabel(ReportChartType type) {
    switch (type) {
      case ReportChartType.bar:
        return 'Bar';
      case ReportChartType.line:
        return 'Line';
      case ReportChartType.area:
        return 'Area';
      case ReportChartType.pie:
        return 'Pie';
      case ReportChartType.horizontalBar:
        return 'H-Bar';
      case ReportChartType.scatter:
        return 'Scatter';
      case ReportChartType.stepLine:
        return 'Step';
      case ReportChartType.rangeLine:
        return 'Range';
      case ReportChartType.gradientBar:
        return 'Gradient';
      case ReportChartType.lollipop:
        return 'Lollipop';
      case ReportChartType.candlestick:
        return 'Candle';
    }
  }

  /// Aging Party Wise card with days filter pills
  Widget _buildAgingPartyWiseCard() {
    final accentColor = _isReceivable ? AppColors.purple : AppColors.red;

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
          Text(
            'AGING PARTY WISE (DAY-WISE)',
            style: AppTypography.cardLabel,
          ),
          const SizedBox(height: 12),

          // Days filter pills
          _OutstandingDaysFilterPills(
            selectedDays: _selectedDaysFilter,
            customValue: _customDaysValue,
            onChanged: _onDaysFilterChanged,
            onCustomTap: _showCustomDaysDialog,
            accentColor: accentColor,
          ),
          const SizedBox(height: 16),

          // Party list
          if (_isReceivable)
            ..._buildReceivablePartyList()
          else
            ..._buildPayablePartyList(),
        ],
      ),
    );
  }

  List<Widget> _buildReceivablePartyList() {
    final parties = _creditLimitParties;
    final filtered = _selectedDaysFilter == null
        ? List<CreditLimitParty>.from(parties)
        : parties
            .where((p) => p.daysOverLimit >= _selectedDaysFilter!)
            .toList();
    filtered.sort((a, b) => b.daysOverLimit.compareTo(a.daysOverLimit));

    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              _selectedDaysFilter != null
                  ? 'No parties for ${_selectedDaysFilter}+ days'
                  : 'No parties found',
              style: AppTypography.itemSubtitle,
            ),
          ),
        ),
      ];
    }

    final displayCount = _agingPartyExpanded
        ? filtered.length
        : filtered.length.clamp(0, _initialItemCount);

    final widgets = <Widget>[];
    for (var i = 0; i < displayCount; i++) {
      final party = filtered[i];
      final dc = _daysColor(party.daysOverLimit);

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: AppTypography.itemTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      party.creditLimit > 0
                          ? 'Credit Limit: ₹${AmountFormatter.shortSpaced(party.creditLimit)}'
                          : 'Sundry Debtors',
                      style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${AmountFormatter.shortSpaced(party.currentOutstanding)}',
                    style: AppTypography.itemTitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 12, color: dc),
                        const SizedBox(width: 3),
                        Text(
                          '${party.daysOverLimit} days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dc,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (i < displayCount - 1) {
        widgets.add(
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
        );
      }
    }

    if (filtered.length > _initialItemCount) {
      widgets.add(_buildSeeMoreButton(
        expanded: _agingPartyExpanded,
        totalCount: filtered.length,
        onTap: () => setState(() => _agingPartyExpanded = !_agingPartyExpanded),
      ));
    }

    return widgets;
  }

  List<Widget> _buildPayablePartyList() {
    final parties = _paymentDueParties;
    final filtered = _selectedDaysFilter == null
        ? List<PaymentDueParty>.from(parties)
        : parties.where((p) => p.daysOverdue >= _selectedDaysFilter!).toList();
    filtered.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));

    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              _selectedDaysFilter != null
                  ? 'No vendors for ${_selectedDaysFilter}+ days'
                  : 'No vendors found',
              style: AppTypography.itemSubtitle,
            ),
          ),
        ),
      ];
    }

    final displayCount = _agingPartyExpanded
        ? filtered.length
        : filtered.length.clamp(0, _initialItemCount);

    final widgets = <Widget>[];
    for (var i = 0; i < displayCount; i++) {
      final party = filtered[i];
      final dc = _daysColor(party.daysOverdue);

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: AppTypography.itemTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      party.dueDate != null
                          ? 'Due: ${_formatDate(party.dueDate!)}'
                          : 'Sundry Creditors',
                      style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${AmountFormatter.shortSpaced(party.amountDue)}',
                    style: AppTypography.itemTitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 12, color: dc),
                        const SizedBox(width: 3),
                        Text(
                          '${party.daysOverdue} days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dc,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (i < displayCount - 1) {
        widgets.add(
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
        );
      }
    }

    if (filtered.length > _initialItemCount) {
      widgets.add(_buildSeeMoreButton(
        expanded: _agingPartyExpanded,
        totalCount: filtered.length,
        onTap: () => setState(() => _agingPartyExpanded = !_agingPartyExpanded),
      ));
    }

    return widgets;
  }

  /// Party Wise Aging (Value Wise)
  Widget _buildPartyWiseValueCard() {
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
          Text(
            'PARTY WISE AGING (VALUE WISE)',
            style: AppTypography.cardLabel,
          ),
          const SizedBox(height: 16),
          if (_isReceivable)
            ..._buildReceivableValueList()
          else
            ..._buildPayableValueList(),
        ],
      ),
    );
  }

  List<Widget> _buildReceivableValueList() {
    final parties = List<CreditLimitParty>.from(_creditLimitParties)
      ..sort((a, b) => b.currentOutstanding.compareTo(a.currentOutstanding));

    if (parties.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'No party wise value found',
              style: AppTypography.itemSubtitle,
            ),
          ),
        ),
      ];
    }

    final now = DateTime.now();
    final displayCount = _valueWiseExpanded
        ? parties.length
        : parties.length.clamp(0, _initialItemCount);
    final widgets = <Widget>[];

    for (var i = 0; i < displayCount; i++) {
      final party = parties[i];
      final dueDate = now.subtract(Duration(days: party.daysOverLimit));
      final dc = _daysColor(party.daysOverLimit);

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: AppTypography.itemTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due: ${_formatDate(dueDate)}',
                      style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${AmountFormatter.shortSpaced(party.currentOutstanding)}',
                    style: AppTypography.itemTitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 12, color: dc),
                        const SizedBox(width: 3),
                        Text(
                          '${party.daysOverLimit} days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dc,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (i < displayCount - 1) {
        widgets.add(
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
        );
      }
    }

    if (parties.length > _initialItemCount) {
      widgets.add(_buildSeeMoreButton(
        expanded: _valueWiseExpanded,
        totalCount: parties.length,
        onTap: () => setState(() => _valueWiseExpanded = !_valueWiseExpanded),
      ));
    }

    return widgets;
  }

  List<Widget> _buildPayableValueList() {
    final parties = List<PaymentDueParty>.from(_paymentDueParties)
      ..sort((a, b) => b.amountDue.compareTo(a.amountDue));

    if (parties.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'No party wise value found',
              style: AppTypography.itemSubtitle,
            ),
          ),
        ),
      ];
    }

    final displayCount = _valueWiseExpanded
        ? parties.length
        : parties.length.clamp(0, _initialItemCount);
    final widgets = <Widget>[];

    for (var i = 0; i < displayCount; i++) {
      final party = parties[i];
      final dc = _daysColor(party.daysOverdue);

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: AppTypography.itemTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      party.dueDate != null
                          ? 'Due: ${_formatDate(party.dueDate!)}'
                          : 'N/A',
                      style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${AmountFormatter.shortSpaced(party.amountDue)}',
                    style: AppTypography.itemTitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 12, color: dc),
                        const SizedBox(width: 3),
                        Text(
                          '${party.daysOverdue} days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dc,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (i < displayCount - 1) {
        widgets.add(
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
        );
      }
    }

    if (parties.length > _initialItemCount) {
      widgets.add(_buildSeeMoreButton(
        expanded: _valueWiseExpanded,
        totalCount: parties.length,
        onTap: () => setState(() => _valueWiseExpanded = !_valueWiseExpanded),
      ));
    }

    return widgets;
  }

  /// Fastest Paying Parties card (Receivable)
  Widget _buildFastestPayingPartiesCard() {
    final fy = _selectedFiscalYear;
    final fyLabel =
        'FY${fy.startYear.toString().substring(2)}-${fy.endYear.toString().substring(2)}';
    final months = fy.endDate.difference(fy.startDate).inDays ~/ 30;

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
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.star_rounded,
                      color: Color(0xFFF59E0B), size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fastest Paying Parties',
                  style: AppTypography.itemTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B8A5A),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Early payers',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B8A5A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // FY selector
          GestureDetector(
            onTap: () {
              _showFiscalYearPicker();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0E3FF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Color(0xFF1A6FD8)),
                  const SizedBox(width: 8),
                  Text(
                    '$fyLabel ($months months)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A6FD8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down,
                      size: 18, color: Color(0xFF1A6FD8)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatMonthYear(fy.startDate)} - ${_formatMonthYear(fy.endDate)}',
            style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Party list
          if (_topPayingParties.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No data available',
                  style: AppTypography.itemSubtitle,
                ),
              ),
            )
          else
            ...List.generate(
              _topPayingParties.length.clamp(0, 4),
              (i) {
                final party = _topPayingParties[i];
                final rank = i + 1;
                // Derive avg days and early days from percentage
                final avgDays =
                    (30 - (party.percentage * 0.18)).round().clamp(5, 30);
                final earlyDays = (30 - avgDays).clamp(0, 30);
                final double onTimePercent = party.percentage > 0
                    ? party.percentage.clamp(0.0, 100.0)
                    : (100.0 - i * 3).clamp(80.0, 100.0);

                return Column(
                  children: [
                    _buildFastestPartyRow(
                      rank: rank,
                      name: party.name,
                      amount: party.amount,
                      avgDays: avgDays,
                      earlyDays: earlyDays,
                      onTimePercent: onTimePercent,
                    ),
                    if (i < _topPayingParties.length.clamp(0, 4) - 1)
                      const SizedBox(height: 4),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFastestPartyRow({
    required int rank,
    required String name,
    required double amount,
    required int avgDays,
    required int earlyDays,
    required double onTimePercent,
  }) {
    // Medal colors
    Color rankBg;
    Color rankFg;
    if (rank == 1) {
      rankBg = const Color(0xFFF59E0B); // gold
      rankFg = Colors.white;
    } else if (rank == 2) {
      rankBg = const Color(0xFF9CA3AF); // silver
      rankFg = Colors.white;
    } else if (rank == 3) {
      rankBg = const Color(0xFFCD7F32); // bronze
      rankFg = Colors.white;
    } else {
      rankBg = Colors.grey.shade200;
      rankFg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Rank circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: rankFg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name + avg days + early badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.itemTitle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Avg $avgDays days',
                      style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${earlyDays}d early',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B8A5A),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount + on-time %
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${AmountFormatter.shortSpaced(amount)}',
                style: AppTypography.itemTitle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${onTimePercent.toStringAsFixed(0)}% on-time',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B8A5A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Top Vendors card (Payable)
  Widget _buildTopVendorsCard() {
    final fy = _selectedFiscalYear;
    final fyLabel =
        'FY${fy.startYear.toString().substring(2)}-${fy.endYear.toString().substring(2)}';
    final months = fy.endDate.difference(fy.startDate).inDays ~/ 30;

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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.store_rounded,
                      color: Color(0xFFF59E0B), size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Top Vendors',
                  style: AppTypography.itemTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // FY selector
          GestureDetector(
            onTap: _showFiscalYearPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0E3FF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Color(0xFF1A6FD8)),
                  const SizedBox(width: 8),
                  Text(
                    '$fyLabel ($months months)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A6FD8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down,
                      size: 18, color: Color(0xFF1A6FD8)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_topVendors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No data available',
                    style: AppTypography.itemSubtitle),
              ),
            )
          else
            ...List.generate(
              _topVendors.length.clamp(0, 4),
              (i) {
                final vendor = _topVendors[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vendor.name,
                          style: AppTypography.itemTitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${AmountFormatter.shortSpaced(vendor.amount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showFiscalYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('SELECT FISCAL YEAR', style: AppTypography.cardLabel),
              ),
            ),
            ..._fiscalYearOptions.map((fy) {
              final isSelected = fy.startYear == _selectedFiscalYear.startYear;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? AppColors.blue : AppColors.textSecondary,
                  size: 20,
                ),
                title: Text(
                  'FY${fy.startYear.toString().substring(2)}-${fy.endYear.toString().substring(2)}',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.blue : AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${_formatMonthYear(fy.startDate)} - ${_formatMonthYear(fy.endDate)}',
                  style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedFiscalYear = fy);
                  _loadData();
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
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
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Ledger Wise Outstanding card
  Widget _buildLedgerWiseOutstandingCard() {
    // Use creditLimitParties/paymentDueParties if available,
    // otherwise fall back to chart data points
    final hasPartyData = _isReceivable
        ? _creditLimitParties.isNotEmpty
        : _paymentDueParties.isNotEmpty;

    final chartFallback =
        _chartData.dataPoints.where((dp) => dp.value > 0).toList();

    final avatarColors = [
      const Color(0xFF6366F1),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFFF97316),
      const Color(0xFFEC4899),
    ];

    final int totalCount;
    if (hasPartyData) {
      totalCount = _isReceivable
          ? _creditLimitParties.length
          : _paymentDueParties.length;
    } else {
      totalCount = chartFallback.length;
    }
    final displayCount = _ledgerWiseExpanded
        ? totalCount
        : totalCount.clamp(0, _initialItemCount);

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
          Text(
            'LEDGER WISE OUTSTANDING',
            style: AppTypography.cardLabel,
          ),
          const SizedBox(height: 16),
          if (totalCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No ledger data found',
                    style: AppTypography.itemSubtitle),
              ),
            )
          else
            for (var i = 0; i < displayCount; i++) ...[
              _buildLedgerRow(
                name: hasPartyData
                    ? (_isReceivable
                        ? _creditLimitParties[i].name
                        : _paymentDueParties[i].name)
                    : chartFallback[i].label,
                group: _isReceivable ? 'Sundry Debtors' : 'Sundry Creditors',
                amount: hasPartyData
                    ? (_isReceivable
                        ? _creditLimitParties[i].currentOutstanding
                        : _paymentDueParties[i].amountDue)
                    : chartFallback[i].value,
                days: hasPartyData
                    ? (_isReceivable
                        ? _creditLimitParties[i].daysOverLimit
                        : _paymentDueParties[i].daysOverdue)
                    : 0,
                avatarColor: avatarColors[i % avatarColors.length],
              ),
              if (i < displayCount - 1)
                Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
            ],
          if (totalCount > _initialItemCount)
            _buildSeeMoreButton(
              expanded: _ledgerWiseExpanded,
              totalCount: totalCount,
              onTap: () =>
                  setState(() => _ledgerWiseExpanded = !_ledgerWiseExpanded),
            ),
        ],
      ),
    );
  }

  Widget _buildLedgerRow({
    required String name,
    required String group,
    required double amount,
    required int days,
    required Color avatarColor,
  }) {
    final dc = _daysColor(days);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.itemTitle.copyWith(fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  group,
                  style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${AmountFormatter.shortSpaced(amount)}',
                style: AppTypography.itemTitle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: dc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${days}d',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dc,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Group Wise Outstanding card
  Widget _buildGroupWiseOutstandingCard() {
    final groups = _isReceivable ? _receivableGroups : _payableGroups;

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
          Text(
            'GROUP WISE OUTSTANDING',
            style: AppTypography.cardLabel,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < groups.length; i++) ...[
            _buildGroupRow(groups[i]),
            if (i < groups.length - 1)
              Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupRow(GroupOutstanding group) {
    final groupColor = _isReceivable ? AppColors.purple : AppColors.red;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupOutstandingDetailScreen(
              group: group,
              isReceivable: _isReceivable,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dot
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: groupColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group name + Amount & chevron
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.groupName,
                          style: AppTypography.itemTitle.copyWith(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${AmountFormatter.shortSpaced(group.amount)}',
                        style: AppTypography.itemTitle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Party count + percentage
                  Row(
                    children: [
                      Text(
                        '${group.partyCount} parties',
                        style:
                            AppTypography.itemSubtitle.copyWith(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '${group.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: groupColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: group.percentage / 100,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(groupColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeeMoreButton({
    required bool expanded,
    required int totalCount,
    required VoidCallback onTap,
  }) {
    final remaining = totalCount - _initialItemCount;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          child: Text(
            expanded ? 'See Less' : 'See More ($remaining more)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.blue,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Days filter pills
// ─────────────────────────────────────────────────────────────────────────────

class _OutstandingDaysFilterPills extends StatelessWidget {
  final int? selectedDays;
  final ValueChanged<int?> onChanged;
  final VoidCallback onCustomTap;
  final int? customValue;
  final Color accentColor;

  const _OutstandingDaysFilterPills({
    required this.selectedDays,
    required this.onChanged,
    required this.onCustomTap,
    required this.accentColor,
    this.customValue,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildPill('All', null),
        _buildPill('30+', 30),
        _buildPill('60+', 60),
        _buildPill('90+', 90),
        _buildCustomPill(),
      ],
    );
  }

  Widget _buildPill(String label, int? days) {
    final isActive =
        (days == null && selectedDays == null && customValue == null) ||
            (days != null && selectedDays == days && customValue == null);
    return GestureDetector(
      onTap: () => onChanged(days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accentColor : accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? null
              : Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPill() {
    final isActive = customValue != null && selectedDays == customValue;
    return GestureDetector(
      onTap: onCustomTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accentColor : accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? null
              : Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? '${customValue}+' : 'Custom',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : accentColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isActive ? Colors.white : accentColor,
            ),
          ],
        ),
      ),
    );
  }
}
