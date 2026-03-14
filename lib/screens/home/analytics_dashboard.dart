// // screens/analytics_dashboard.dart

// import 'package:flutter/material.dart';
// import '../Analysis/bill_wise_outstanding_screen.dart';
// import '../Analysis/ledger_list_screen.dart';
// import '../Analysis/profit_loss_screen2.dart';
// import '../Analysis/balance_sheet_screen.dart';
// import '../Analysis/stock_summary_screen.dart';
// import '../Analysis/cash_flow_screen.dart';
// import '../Analysis/trial_balance_screen.dart';
// import '../Analysis/ledger_reports_screen.dart';
// import '../Analysis/gst_reports_screen.dart';
// import '../Analysis/party_outstanding_screen.dart';
// import '../../database/database_helper.dart';
// import '../Analysis/payment_screen.dart';
// import '../Analysis/receipt_screen.dart';

// class AnalyticsDashboard extends StatefulWidget {
//   @override
//   _AnalyticsDashboardState createState() => _AnalyticsDashboardState();
// }

// class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
//   final _db = DatabaseHelper.instance;
  
//   String? _companyGuid;
//   String? _companyName;
//   String? _fromDate;
//   String? _toDate;
//   String? _companyStartDate;
//   String? _companyEndDate;
//   bool _loading = true;
  
//   // Real data from database
//   double _totalSales = 0.0;
//   double _totalPurchase = 0.0;
//   double _netProfit = 0.0;
//   double _stockValue = 0.0;
  
//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }
  
//   Future<void> _loadData() async {
//     setState(() => _loading = true);
    
//     final company = await _db.getSelectedCompanyByGuid();
//     if (company == null) {
//       setState(() => _loading = false);
//       return;
//     }
    
//     _companyGuid = company['company_guid'] as String;
//     _companyName = company['company_name'] as String;
//     _companyStartDate = company['starting_from'] as String? ?? '20250401';
//     _companyEndDate = company['ending_at'] as String? ?? '20260331';
    
//     // Initialize date filter with company dates if not already set
//     if (_fromDate == null || _toDate == null) {
//       _fromDate = _companyStartDate;
//       _toDate = _companyEndDate;
//     }
    
//     // Fetch real data
//     await _fetchQuickStats();
    
//     setState(() => _loading = false);
//   }
  
//   Future<void> _showDateFilterDialog() async {
//     DateTime tempFromDate = _parseTallyDate(_fromDate ?? _companyStartDate!);
//     DateTime tempToDate = _parseTallyDate(_toDate ?? _companyEndDate!);
//     DateTime companyStart = _parseTallyDate(_companyStartDate!);
//     DateTime companyEnd = _parseTallyDate(_companyEndDate!);
    
//     await showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return AlertDialog(
//               title: Text('Select Date Range'),
//               content: Container(
//                 width: double.maxFinite,
//                 child: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Quick Filters
//                       Text(
//                         'Quick Filters',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                         ),
//                       ),
//                       SizedBox(height: 12),
//                       Wrap(
//                         spacing: 8,
//                         runSpacing: 8,
//                         children: [
//                           _buildQuickFilterChip(
//                             'This Month',
//                             () {
//                               final now = DateTime.now();
//                               final firstDay = DateTime(now.year, now.month, 1);
//                               final lastDay = DateTime(now.year, now.month + 1, 0);
//                               setDialogState(() {
//                                 tempFromDate = firstDay;
//                                 tempToDate = lastDay;
//                               });
//                             },
//                           ),
//                           _buildQuickFilterChip(
//                             'Last Month',
//                             () {
//                               final now = DateTime.now();
//                               final firstDay = DateTime(now.year, now.month - 1, 1);
//                               final lastDay = DateTime(now.year, now.month, 0);
//                               setDialogState(() {
//                                 tempFromDate = firstDay;
//                                 tempToDate = lastDay;
//                               });
//                             },
//                           ),
//                           _buildQuickFilterChip(
//                             'This Quarter',
//                             () {
//                               final now = DateTime.now();
//                               final quarter = ((now.month - 1) ~/ 3);
//                               final firstDay = DateTime(now.year, quarter * 3 + 1, 1);
//                               final lastDay = DateTime(now.year, quarter * 3 + 4, 0);
//                               setDialogState(() {
//                                 tempFromDate = firstDay;
//                                 tempToDate = lastDay;
//                               });
//                             },
//                           ),
//                           _buildQuickFilterChip(
//                             'This Year',
//                             () {
//                               final now = DateTime.now();
//                               setDialogState(() {
//                                 tempFromDate = DateTime(now.year, 1, 1);
//                                 tempToDate = DateTime(now.year, 12, 31);
//                               });
//                             },
//                           ),
//                           _buildQuickFilterChip(
//                             'Financial Year',
//                             () {
//                               setDialogState(() {
//                                 tempFromDate = companyStart;
//                                 tempToDate = companyEnd;
//                               });
//                             },
//                           ),
//                           _buildQuickFilterChip(
//                             'All Time',
//                             () {
//                               setDialogState(() {
//                                 tempFromDate = companyStart;
//                                 tempToDate = companyEnd;
//                               });
//                             },
//                           ),
//                         ],
//                       ),
                      
//                       SizedBox(height: 24),
                      
//                       // Custom Date Selection
//                       Text(
//                         'Custom Range',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                         ),
//                       ),
//                       SizedBox(height: 12),
                      
//                       // From Date
//                       InkWell(
//                         onTap: () async {
//                           final picked = await showDatePicker(
//                             context: context,
//                             initialDate: tempFromDate,
//                             firstDate: DateTime(2000, 1, 1),
//                             lastDate: DateTime(2100, 12, 31),
//                             builder: (context, child) {
//                               return Theme(
//                                 data: Theme.of(context).copyWith(
//                                   colorScheme: ColorScheme.light(
//                                     primary: Colors.blue,
//                                     onPrimary: Colors.white,
//                                     onSurface: Colors.black,
//                                   ),
//                                 ),
//                                 child: child!,
//                               );
//                             },
//                           );
//                           if (picked != null) {
//                             setDialogState(() {
//                               tempFromDate = picked;
//                             });
//                           }
//                         },
//                         child: Container(
//                           padding: EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'From Date',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                   SizedBox(height: 4),
//                                   Text(
//                                     _formatDateDisplay(tempFromDate),
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               Icon(Icons.calendar_today, color: Colors.blue),
//                             ],
//                           ),
//                         ),
//                       ),
                      
//                       SizedBox(height: 12),
                      
//                       // To Date
//                       InkWell(
//                         onTap: () async {
//                           final picked = await showDatePicker(
//                             context: context,
//                             initialDate: tempToDate,
//                             firstDate: DateTime(2000, 1, 1),
//                             lastDate: DateTime(2100, 12, 31),
//                             builder: (context, child) {
//                               return Theme(
//                                 data: Theme.of(context).copyWith(
//                                   colorScheme: ColorScheme.light(
//                                     primary: Colors.blue,
//                                     onPrimary: Colors.white,
//                                     onSurface: Colors.black,
//                                   ),
//                                 ),
//                                 child: child!,
//                               );
//                             },
//                           );
//                           if (picked != null) {
//                             setDialogState(() {
//                               tempToDate = picked;
//                             });
//                           }
//                         },
//                         child: Container(
//                           padding: EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'To Date',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                   SizedBox(height: 4),
//                                   Text(
//                                     _formatDateDisplay(tempToDate),
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               Icon(Icons.calendar_today, color: Colors.blue),
//                             ],
//                           ),
//                         ),
//                       ),
                      
//                       SizedBox(height: 12),
                      
//                       // Date range info
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: Colors.blue[50],
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Company FY: ${_formatDateDisplay(companyStart)} to ${_formatDateDisplay(companyEnd)}',
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.blue[700],
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Cancel'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     if (tempFromDate.isAfter(tempToDate)) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text('From date must be before To date'),
//                           backgroundColor: Colors.red,
//                         ),
//                       );
//                       return;
//                     }
                    
//                     setState(() {
//                       _fromDate = _formatToTallyDate(tempFromDate);
//                       _toDate = _formatToTallyDate(tempToDate);
//                     });
//                     Navigator.pop(context);
//                     _loadData();
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                   ),
//                   child: Text('Apply Filter'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
  
//   Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
//     return ActionChip(
//       label: Text(label, style: TextStyle(fontSize: 12)),
//       onPressed: onTap,
//       backgroundColor: Colors.blue[50],
//       labelStyle: TextStyle(color: Colors.blue[700]),
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//     );
//   }
  
//   DateTime _parseTallyDate(String tallyDate) {
//     try {
//       if (tallyDate.length != 8) return DateTime.now();
//       final year = int.parse(tallyDate.substring(0, 4));
//       final month = int.parse(tallyDate.substring(4, 6));
//       final day = int.parse(tallyDate.substring(6, 8));
//       return DateTime(year, month, day);
//     } catch (e) {
//       return DateTime.now();
//     }
//   }
  
//   String _formatToTallyDate(DateTime date) {
//     return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
//   }
  
//   String _formatDateDisplay(DateTime date) {
//     return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
//   }
  
//   Future<void> _fetchQuickStats() async {
//     final db = await _db.database;
    
//     // Get Sales
//     final salesResult = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND reserved_name = 'Sales Accounts'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       WHERE v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//     ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);
    
//     if (salesResult.isNotEmpty) {
//       final credit = (salesResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
//       final debit = (salesResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
//       _totalSales = credit - debit;
//     }
    
//     // Get Purchase
//     final purchaseResult = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND reserved_name = 'Purchase Accounts'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       WHERE v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//     ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);
    
//     if (purchaseResult.isNotEmpty) {
//       final debit = (purchaseResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
//       final credit = (purchaseResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
//       _totalPurchase = debit - credit;
//     }
    
//     // Calculate Net Profit
//     await _calculateNetProfit();
    
//     // Get Stock Value
//     // await _calculateStockValue();
//   }
  
//   Future<void> _calculateNetProfit() async {
//     final db = await _db.database;
    
//     // Get Direct Expenses
//     final directExpResult = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND name = 'Direct Expenses'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       WHERE v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//     ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);
    
//     double directExpenses = 0.0;
//     if (directExpResult.isNotEmpty) {
//       final debit = (directExpResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
//       final credit = (directExpResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
//       directExpenses = debit - credit;
//     }
    
//     // Get Indirect Expenses
//     final indirectExpResult = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND name = 'Indirect Expenses'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       WHERE v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//     ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);
    
//     double indirectExpenses = 0.0;
//     if (indirectExpResult.isNotEmpty) {
//       final debit = (indirectExpResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
//       final credit = (indirectExpResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
//       indirectExpenses = debit - credit;
//     }
    
//     // Get Indirect Incomes
//     final indirectIncResult = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND name = 'Indirect Incomes'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         SUM(l.opening_balance) as opening_total,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total
//       FROM ledgers l
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//       LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
//         AND v.company_guid = l.company_guid
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//       WHERE l.company_guid = ?
//         AND l.is_deleted = 0
//     ''', [_companyGuid, _companyGuid, _fromDate, _toDate, _companyGuid]);
    
//     double indirectIncomes = 0.0;
//     if (indirectIncResult.isNotEmpty) {
//       final opening = (indirectIncResult.first['opening_total'] as num?)?.toDouble() ?? 0.0;
//       final credit = (indirectIncResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
//       final debit = (indirectIncResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
//       indirectIncomes = opening + credit - debit;
//     }
    
//     // Calculate Net Profit
//     final grossProfit = _totalSales - (_totalPurchase + directExpenses);
//     _netProfit = grossProfit + indirectIncomes - indirectExpenses;
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Business Analytics'),
//         backgroundColor: Colors.blue[700],
//         actions: [
//           IconButton(
//             icon: Icon(Icons.filter_list),
//             onPressed: _showDateFilterDialog,
//             tooltip: 'Filter by Date',
//           ),
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadData,
//           ),
//         ],
//       ),
//       body: _loading
//           ? Center(child: CircularProgressIndicator())
//           : RefreshIndicator(
//               onRefresh: _loadData,
//               child: SingleChildScrollView(
//                 physics: AlwaysScrollableScrollPhysics(),
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Company Header
//                     Card(
//                       color: Colors.blue[50],
//                       child: Padding(
//                         padding: EdgeInsets.all(16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               _companyName ?? 'No Company Selected',
//                               style: TextStyle(
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.blue[900],
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             Text(
//                               'Financial Reports & Analysis',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey[700],
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             Row(
//                               children: [
//                                 Icon(Icons.date_range, size: 16, color: Colors.blue[700]),
//                                 SizedBox(width: 4),
//                                 Expanded(
//                                   child: Text(
//                                     'Period: ${_formatDate(_fromDate ?? '')} to ${_formatDate(_toDate ?? '')}',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.blue[700],
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                 ),
//                                 TextButton.icon(
//                                   onPressed: _showDateFilterDialog,
//                                   icon: Icon(Icons.filter_alt, size: 16),
//                                   label: Text('Change'),
//                                   style: TextButton.styleFrom(
//                                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
                    
//                     SizedBox(height: 24),
                    
//                     // Quick Stats Section
//                     Text(
//                       'Quick Insights',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 16),
                    
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _buildStatCard(
//                             'Sales',
//                             _formatAmount(_totalSales),
//                             Icons.shopping_cart,
//                             Colors.green[100]!,
//                             _totalSales >= 0 ? Colors.green[700]! : Colors.red[700]!,
//                           ),
//                         ),
//                         SizedBox(width: 12),
//                         Expanded(
//                           child: _buildStatCard(
//                             'Purchase',
//                             _formatAmount(_totalPurchase),
//                             Icons.shopping_bag,
//                             Colors.orange[100]!,
//                             Colors.orange[700]!,
//                           ),
//                         ),
//                       ],
//                     ),
                    
//                     SizedBox(height: 12),
                    
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _buildStatCard(
//                             'Net Profit',
//                             _formatAmount(_netProfit),
//                             Icons.trending_up,
//                             _netProfit >= 0 ? Colors.blue[100]! : Colors.red[100]!,
//                             _netProfit >= 0 ? Colors.blue[700]! : Colors.red[700]!,
//                           ),
//                         ),
//                         SizedBox(width: 12),
//                         Expanded(
//                           child: _buildStatCard(
//                             'Stock Value',
//                             _formatAmount(_stockValue),
//                             Icons.inventory,
//                             Colors.purple[100]!,
//                             Colors.purple[700]!,
//                           ),
//                         ),
//                       ],
//                     ),
                    
//                     SizedBox(height: 32),
                    
//                     // Reports Section
//                     Text(
//                       'Financial Reports',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 16),
                    
//                     // Report Cards
//                     _buildReportCard(
//                       title: 'Profit & Loss A/c',
//                       subtitle: 'View income, expenses, and profitability',
//                       icon: Icons.trending_up,
//                       color: Colors.green,
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => ProfitLossScreen(),
//                           ),
//                         );
//                       },
//                     ),
                    
//                     SizedBox(height: 12),

//                     _buildReportCard(
//                       title: 'Profit & Loss A/c',
//                       subtitle: 'View income, expenses, and profitability',
//                       icon: Icons.trending_up,
//                       color: Colors.green,
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => StockSummaryScreen(),
//                           ),
//                         );
//                       },
//                     ),
                    
//                     SizedBox(height: 12),
                    
//                     _buildReportCard(
//                       title: 'Balance Sheet',
//                       subtitle: 'View assets, liabilities, and capital',
//                       icon: Icons.account_balance,
//                       color: Colors.blue,
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => BalanceSheetScreen(),
//                           ),
//                         );
//                       },
//                     ),
                    
//                     SizedBox(height: 12),
                    
//                     _buildReportCard(
//                       title: 'Stock Summary',
//                       subtitle: 'View inventory and stock valuation',
//                       icon: Icons.inventory_2,
//                       color: Colors.orange,
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => StockSummaryScreen(),
//                           ),
//                         );
//                       },
//                     ),
                    
//                     SizedBox(height: 32),
                    
//                     // Additional Reports
//                     Text(
//                       'Other Reports',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 16),

//                     _buildSimpleReportTile(
//                         'Payment Vouchers',
//                         Icons.payment,
//                         () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => PaymentScreen(),
//                             ),
//                           );
//                         },
//                       ),

//                       _buildSimpleReportTile(
//                         'Bill-Wise Outstanding',
//                         Icons.payment,
//                         () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => BillWiseOutstandingScreen(),
//                             ),
//                           );
//                         },
//                       ),

//                       _buildSimpleReportTile(
//                         'Receipt Vouchers',
//                         Icons.receipt,
//                         () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => ReceiptScreen(),
//                             ),
//                           );
//                         },
//                       ),
                    
//                     _buildSimpleReportTile(
//                       'Cash Flow Statement',
//                       Icons.monetization_on,
//                       () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => CashFlowScreen(),
//                           ),
//                         );
//                       },
//                     ),
                    
//                     _buildSimpleReportTile(
//                       'Trial Balance',
//                       Icons.balance,
//                       () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => TrialBalanceScreen(),
//                           ),
//                         );
//                       },
//                     ),
                    
//                     _buildSimpleReportTile(
//                       'Ledger Reports',
//                       Icons.book,
//                       () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => const LedgerListScreen(),
//                           ),
//                         );
//                       },
//                     ),
                    
//                     _buildSimpleReportTile(
//                       'GST Reports',
//                       Icons.receipt_long,
//                       () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => GSTReportsScreen(),
//                           ),
//                         );
//                       },
//                     ),
                    
//                     _buildSimpleReportTile(
//                       'Party Outstanding',
//                       Icons.people,
//                       () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => PartyOutstandingScreen(),
//                           ),
//                         );
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }
  
//   Widget _buildReportCard({
//     required String title,
//     required String subtitle,
//     required IconData icon,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return Card(
//       elevation: 2,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: EdgeInsets.all(16),
//           child: Row(
//             children: [
//               Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Icon(icon, color: color, size: 32),
//               ),
//               SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       subtitle,
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
  
//   Widget _buildStatCard(
//     String label,
//     String value,
//     IconData icon,
//     Color bgColor,
//     Color textColor,
//   ) {
//     return Card(
//       color: bgColor,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Icon(icon, color: textColor.withOpacity(0.7), size: 28),
//             SizedBox(height: 12),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: textColor,
//               ),
//             ),
//             SizedBox(height: 4),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey[700],
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
  
//   Widget _buildSimpleReportTile(String title, IconData icon, VoidCallback onTap) {
//     return Card(
//       child: ListTile(
//         leading: Icon(icon, color: Colors.blue),
//         title: Text(title),
//         trailing: Icon(Icons.arrow_forward_ios, size: 16),
//         onTap: onTap,
//       ),
//     );
//   }
  
//   String _formatAmount(double amount) {
//     final isNegative = amount < 0;
//     final absAmount = amount.abs();
//     final formatted = absAmount.toStringAsFixed(2).replaceAllMapped(
//       RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
//       (Match m) => '${m[1]},',
//     );
//     return '₹${isNegative ? '-' : ''}$formatted';
//   }
  
//   String _formatDate(String tallyDate) {
//     if (tallyDate.length != 8) return tallyDate;
//     final year = tallyDate.substring(0, 4);
//     final month = tallyDate.substring(4, 6);
//     final day = tallyDate.substring(6, 8);
//     return '$day-$month-$year';
//   }
// }


// screens/analytics_dashboard.dart

import 'package:flutter/material.dart';
import '../Analysis/bill_wise_outstanding_screen.dart';
import '../Analysis/ledger_list_screen.dart';
import '../Analysis/profit_loss_screen2.dart';
import '../Analysis/balance_sheet_screen.dart';
import '../Analysis/stock_summary_screen.dart';
import '../Analysis/cash_flow_screen.dart';
import '../Analysis/trial_balance_screen.dart';
import '../Analysis/gst_reports_screen.dart';
import '../Analysis/party_outstanding_screen.dart';
import '../../database/database_helper.dart';
import '../Analysis/payment_screen.dart';
import '../Analysis/receipt_screen.dart';

class AnalyticsDashboard extends StatefulWidget {
  @override
  _AnalyticsDashboardState createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  String? _companyGuid;
  String? _companyName;
  String? _fromDate;
  String? _toDate;
  String? _companyStartDate;
  String? _companyEndDate;
  bool _loading = true;

  double _totalSales    = 0.0;
  double _totalPurchase = 0.0;
  double _netProfit     = 0.0;
  double _stockValue    = 0.0;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Design tokens ────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF1A6FD8);
  static const Color _accent     = Color(0xFF00C9A7);
  static const Color _bg         = Color(0xFFF4F6FB);
  static const Color _cardBg     = Colors.white;
  static const Color _textDark   = Color(0xFF1A2340);
  static const Color _textMuted  = Color(0xFF8A94A6);
  static const Color _positiveC  = Color(0xFF1B8A5A);
  static const Color _negativeC  = Color(0xFFD32F2F);

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final company = await _db.getSelectedCompanyByGuid();
    if (company == null) {
      setState(() => _loading = false);
      return;
    }

    _companyGuid      = company['company_guid'] as String;
    _companyName      = company['company_name'] as String;
    _companyStartDate = company['starting_from'] as String? ?? '20250401';
    _companyEndDate   = company['ending_at']     as String? ?? '20260331';

    _fromDate ??= _companyStartDate;
    _toDate   ??= _companyEndDate;

    await _fetchQuickStats();

    setState(() => _loading = false);
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _fetchQuickStats() async {
    final db = await _db.database;

    // Sales
    final salesResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND reserved_name = 'Sales Accounts' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT 
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0
        AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
    ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);

    if (salesResult.isNotEmpty) {
      final c = (salesResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
      final d = (salesResult.first['debit_total']  as num?)?.toDouble() ?? 0.0;
      _totalSales = c - d;
    }

    // Purchase
    final purchaseResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT 
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0
        AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
    ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);

    if (purchaseResult.isNotEmpty) {
      final d = (purchaseResult.first['debit_total']  as num?)?.toDouble() ?? 0.0;
      final c = (purchaseResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
      _totalPurchase = d - c;
    }

    await _calculateNetProfit();
  }

  Future<void> _calculateNetProfit() async {
    final db = await _db.database;

    double _fetchGroup(List<Map<String, dynamic>> r, {bool isIncome = false}) {
      if (r.isEmpty) return 0.0;
      final d = (r.first['debit_total']  as num?)?.toDouble() ?? 0.0;
      final c = (r.first['credit_total'] as num?)?.toDouble() ?? 0.0;
      return isIncome ? c - d : d - c;
    }

    String _groupQuery(String groupName) => '''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND name = '$groupName' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT 
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0
        AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
    ''';

    final directExp  = _fetchGroup(await db.rawQuery(_groupQuery('Direct Expenses'),
        [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]));
    final indirectExp = _fetchGroup(await db.rawQuery(_groupQuery('Indirect Expenses'),
        [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]));

    final indirectIncResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND name = 'Indirect Incomes' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT
        SUM(l.opening_balance) as opening_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid AND v.is_deleted = 0
        AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
    ''', [_companyGuid, _companyGuid, _fromDate, _toDate, _companyGuid]);

    double indirectInc = 0.0;
    if (indirectIncResult.isNotEmpty) {
      final op = (indirectIncResult.first['opening_total'] as num?)?.toDouble() ?? 0.0;
      final c  = (indirectIncResult.first['credit_total']  as num?)?.toDouble() ?? 0.0;
      final d  = (indirectIncResult.first['debit_total']   as num?)?.toDouble() ?? 0.0;
      indirectInc = op + c - d;
    }

    _netProfit = (_totalSales - (_totalPurchase + directExp)) + indirectInc - indirectExp;
  }

  // ── Date filter dialog ────────────────────────────────────────────────────────

  Future<void> _showDateFilterDialog() async {
    DateTime tempFrom = _parseTallyDate(_fromDate ?? _companyStartDate!);
    DateTime tempTo   = _parseTallyDate(_toDate   ?? _companyEndDate!);
    final compStart   = _parseTallyDate(_companyStartDate!);
    final compEnd     = _parseTallyDate(_companyEndDate!);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.date_range_rounded,
                            color: _primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Date Range',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _textDark)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Quick filters
                  const Text('Quick Filters',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textMuted,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _quickChip('This Month', () {
                        final n = DateTime.now();
                        setDs(() {
                          tempFrom = DateTime(n.year, n.month, 1);
                          tempTo   = DateTime(n.year, n.month + 1, 0);
                        });
                      }),
                      _quickChip('Last Month', () {
                        final n = DateTime.now();
                        setDs(() {
                          tempFrom = DateTime(n.year, n.month - 1, 1);
                          tempTo   = DateTime(n.year, n.month, 0);
                        });
                      }),
                      _quickChip('This Quarter', () {
                        final n = DateTime.now();
                        final q = ((n.month - 1) ~/ 3);
                        setDs(() {
                          tempFrom = DateTime(n.year, q * 3 + 1, 1);
                          tempTo   = DateTime(n.year, q * 3 + 4, 0);
                        });
                      }),
                      _quickChip('This Year', () {
                        final n = DateTime.now();
                        setDs(() {
                          tempFrom = DateTime(n.year, 1, 1);
                          tempTo   = DateTime(n.year, 12, 31);
                        });
                      }),
                      _quickChip('Financial Year', () {
                        setDs(() {
                          tempFrom = compStart;
                          tempTo   = compEnd;
                        });
                      }),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Custom range
                  const Text('Custom Range',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textMuted,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 10),

                  _datePicker(
                    label: 'From',
                    date: tempFrom,
                    onTap: () async {
                      final p = await _pickDate(context, tempFrom);
                      if (p != null) setDs(() => tempFrom = p);
                    },
                  ),
                  const SizedBox(height: 10),
                  _datePicker(
                    label: 'To',
                    date: tempTo,
                    onTap: () async {
                      final p = await _pickDate(context, tempTo);
                      if (p != null) setDs(() => tempTo = p);
                    },
                  ),

                  const SizedBox(height: 14),

                  // FY info
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: _primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'FY: ${_formatDateDisplay(compStart)} → ${_formatDateDisplay(compEnd)}',
                            style: const TextStyle(
                                fontSize: 11, color: _primary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textMuted,
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (tempFrom.isAfter(tempTo)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFFD32F2F),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  content: const Text(
                                      'From date must be before To date'),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _fromDate = _formatToTallyDate(tempFrom);
                              _toDate   = _formatToTallyDate(tempTo);
                            });
                            Navigator.pop(context);
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primary.withOpacity(0.2)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
      ),
    );
  }

  Widget _datePicker(
      {required String label,
      required DateTime date,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: _primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: _textMuted)),
                const SizedBox(height: 2),
                Text(_formatDateDisplay(date),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext ctx, DateTime initial) {
    return showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate:  DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            onSurface: _textDark,
          ),
        ),
        child: child!,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  DateTime _parseTallyDate(String d) {
    try {
      if (d.length != 8) return DateTime.now();
      return DateTime(
          int.parse(d.substring(0, 4)),
          int.parse(d.substring(4, 6)),
          int.parse(d.substring(6, 8)));
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatToTallyDate(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  String _formatDateDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  String _formatDate(String d) {
    if (d.length != 8) return d;
    return '${d.substring(6)}-${d.substring(4, 6)}-${d.substring(0, 4)}';
  }

  String _formatAmount(double amount) {
    final isNeg = amount < 0;
    final f = amount.abs().toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${isNeg ? '-' : ''}₹$f';
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: _primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKpiGrid(),
                          const SizedBox(height: 28),
                          _buildSectionLabel('Financial Reports'),
                          const SizedBox(height: 12),
                          _buildFinancialReportCards(),
                          const SizedBox(height: 28),
                          _buildSectionLabel('Other Reports'),
                          const SizedBox(height: 12),
                          _buildOtherReportsList(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Sliver AppBar ─────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: _primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
          onPressed: _showDateFilterDialog,
          tooltip: 'Date Filter',
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6FD8), Color(0xFF0D4DA0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _companyName ?? 'No Company Selected',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Financial Reports & Analytics',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  // Period pill + change button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range_rounded,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 5),
                            Text(
                              '${_formatDate(_fromDate ?? '')}  →  ${_formatDate(_toDate ?? '')}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showDateFilterDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35)),
                          ),
                          child: const Text('Change',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── KPI Row ───────────────────────────────────────────────────────────────────

  Widget _buildKpiGrid() {
    final kpis = [
      _KPI('Sales',      _totalSales,    Icons.trending_up_rounded,
          const Color(0xFF1B8A5A), const Color(0xFFE8F5EE)),
      _KPI('Purchase',   _totalPurchase, Icons.shopping_bag_rounded,
          const Color(0xFFB45309), const Color(0xFFFFF7E6)),
      _KPI('Net Profit', _netProfit,     Icons.account_balance_wallet_rounded,
          _netProfit >= 0 ? _primary : _negativeC,
          _netProfit >= 0 ? const Color(0xFFE8F0FB) : const Color(0xFFFFEBEB)),
      _KPI('Stock',      _stockValue,    Icons.inventory_2_rounded,
          const Color(0xFF7B2FBE), const Color(0xFFF3E8FF)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: kpis
            .map<Widget>((k) => Expanded(child: _buildKpiCard(k)))
            .expand((w) => [w, const SizedBox(width: 10)])
            .toList()
          ..removeLast(),
      ),
    );
  }

  Widget _buildKpiCard(_KPI kpi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kpi.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kpi.icon, color: kpi.color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Amount
          Text(
            _formatAmount(kpi.value),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kpi.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          // Label
          Text(kpi.label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textMuted)),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _accent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  letterSpacing: -0.2)),
        ],
      ),
    );
  }

  // ── Financial report cards ────────────────────────────────────────────────────

  Widget _buildFinancialReportCards() {
    final reports = [
      _Report(
        title: 'Profit & Loss A/c',
        subtitle: 'Income, expenses & profitability',
        icon: Icons.trending_up_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF1B8A5A), Color(0xFF3DBE82)]),
        onTap: () => _push(ProfitLossScreen()),
      ),
      _Report(
        title: 'Balance Sheet',
        subtitle: 'Assets, liabilities & capital',
        icon: Icons.account_balance_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF1A6FD8), Color(0xFF4898F0)]),
        onTap: () => _push(BalanceSheetScreen()),
      ),
      _Report(
        title: 'Stock Summary',
        subtitle: 'Inventory & stock valuation',
        icon: Icons.inventory_2_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFFB45309), Color(0xFFD97706)]),
        onTap: () => _push(StockSummaryScreen()),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: reports.map((r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFinancialCard(r),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFinancialCard(_Report r) {
    return GestureDetector(
      onTap: r.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: r.gradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(r.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textDark)),
                  const SizedBox(height: 3),
                  Text(r.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: _textMuted)),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Other reports list ────────────────────────────────────────────────────────

  Widget _buildOtherReportsList() {
    final tiles = [
      _Tile('Payment Vouchers',       Icons.payment_rounded,         const Color(0xFF1A6FD8), () => _push(PaymentScreen())),
      _Tile('Receipt Vouchers',       Icons.receipt_rounded,         const Color(0xFF1B8A5A), () => _push(ReceiptScreen())),
      _Tile('Bill-Wise Outstanding',  Icons.pending_actions_rounded,  const Color(0xFFB45309), () => _push(BillWiseOutstandingScreen())),
      _Tile('Cash Flow Statement',    Icons.monetization_on_rounded,  const Color(0xFF7B2FBE), () => _push(CashFlowScreen())),
      _Tile('Trial Balance',          Icons.balance_rounded,          const Color(0xFF0891B2), () => _push(TrialBalanceScreen())),
      _Tile('Ledger Reports',         Icons.book_rounded,             const Color(0xFF1A6FD8), () => _push(const LedgerListScreen())),
      _Tile('GST Reports',            Icons.receipt_long_rounded,     const Color(0xFF1B8A5A), () => _push(GSTReportsScreen())),
      _Tile('Party Outstanding',      Icons.people_rounded,           const Color(0xFFD32F2F), () => _push(PartyOutstandingScreen())),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: List.generate(tiles.length, (i) {
          final t = tiles[i];
          final isLast = i == tiles.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: t.onTap,
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: t.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.icon, color: t.color, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(t.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _textDark)),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: Colors.grey.shade300),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 66,
                    color: Colors.grey.shade100),
            ],
          );
        }),
      ),
    );
  }
}

// ── Internal data classes ─────────────────────────────────────────────────────────

class _KPI {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _KPI(this.label, this.value, this.icon, this.color, this.bgColor);
}

class _Report {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  const _Report(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.gradient,
      required this.onTap});
}

class _Tile {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Tile(this.title, this.icon, this.color, this.onTap);
}