// screens/analytics_dashboard.dart

import 'package:flutter/material.dart';
import '../Analysis/bill_wise_outstanding_screen.dart';
import '../Analysis/profit_loss_screen2.dart';
import '../Analysis/balance_sheet_screen.dart';
import '../Analysis/stock_summary_screen.dart';
import '../Analysis/cash_flow_screen.dart';
import '../Analysis/trial_balance_screen.dart';
import '../Analysis/ledger_reports_screen.dart';
import '../Analysis/gst_reports_screen.dart';
import '../Analysis/party_outstanding_screen.dart';
import '../../database/database_helper.dart';
import '../Analysis/payment_screen.dart';
import '../Analysis/receipt_screen.dart';

class AnalyticsDashboard extends StatefulWidget {
  @override
  _AnalyticsDashboardState createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  final _db = DatabaseHelper.instance;
  
  String? _companyGuid;
  String? _companyName;
  String? _fromDate;
  String? _toDate;
  String? _companyStartDate;
  String? _companyEndDate;
  bool _loading = true;
  
  // Real data from database
  double _totalSales = 0.0;
  double _totalPurchase = 0.0;
  double _netProfit = 0.0;
  double _stockValue = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    final company = await _db.getSelectedCompanyByGuid();
    if (company == null) {
      setState(() => _loading = false);
      return;
    }
    
    _companyGuid = company['company_guid'] as String;
    _companyName = company['company_name'] as String;
    _companyStartDate = company['starting_from'] as String? ?? '20250401';
    _companyEndDate = company['ending_at'] as String? ?? '20260331';
    
    // Initialize date filter with company dates if not already set
    if (_fromDate == null || _toDate == null) {
      _fromDate = _companyStartDate;
      _toDate = _companyEndDate;
    }
    
    // Fetch real data
    await _fetchQuickStats();
    
    setState(() => _loading = false);
  }
  
  Future<void> _showDateFilterDialog() async {
    DateTime tempFromDate = _parseTallyDate(_fromDate ?? _companyStartDate!);
    DateTime tempToDate = _parseTallyDate(_toDate ?? _companyEndDate!);
    DateTime companyStart = _parseTallyDate(_companyStartDate!);
    DateTime companyEnd = _parseTallyDate(_companyEndDate!);
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select Date Range'),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Filters
                      Text(
                        'Quick Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickFilterChip(
                            'This Month',
                            () {
                              final now = DateTime.now();
                              final firstDay = DateTime(now.year, now.month, 1);
                              final lastDay = DateTime(now.year, now.month + 1, 0);
                              setDialogState(() {
                                tempFromDate = firstDay;
                                tempToDate = lastDay;
                              });
                            },
                          ),
                          _buildQuickFilterChip(
                            'Last Month',
                            () {
                              final now = DateTime.now();
                              final firstDay = DateTime(now.year, now.month - 1, 1);
                              final lastDay = DateTime(now.year, now.month, 0);
                              setDialogState(() {
                                tempFromDate = firstDay;
                                tempToDate = lastDay;
                              });
                            },
                          ),
                          _buildQuickFilterChip(
                            'This Quarter',
                            () {
                              final now = DateTime.now();
                              final quarter = ((now.month - 1) ~/ 3);
                              final firstDay = DateTime(now.year, quarter * 3 + 1, 1);
                              final lastDay = DateTime(now.year, quarter * 3 + 4, 0);
                              setDialogState(() {
                                tempFromDate = firstDay;
                                tempToDate = lastDay;
                              });
                            },
                          ),
                          _buildQuickFilterChip(
                            'This Year',
                            () {
                              final now = DateTime.now();
                              setDialogState(() {
                                tempFromDate = DateTime(now.year, 1, 1);
                                tempToDate = DateTime(now.year, 12, 31);
                              });
                            },
                          ),
                          _buildQuickFilterChip(
                            'Financial Year',
                            () {
                              setDialogState(() {
                                tempFromDate = companyStart;
                                tempToDate = companyEnd;
                              });
                            },
                          ),
                          _buildQuickFilterChip(
                            'All Time',
                            () {
                              setDialogState(() {
                                tempFromDate = companyStart;
                                tempToDate = companyEnd;
                              });
                            },
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Custom Date Selection
                      Text(
                        'Custom Range',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      // From Date
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempFromDate,
                            firstDate: DateTime(2000, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempFromDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'From Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _formatDateDisplay(tempFromDate),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.calendar_today, color: Colors.blue),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // To Date
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempToDate,
                            firstDate: DateTime(2000, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempToDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _formatDateDisplay(tempToDate),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.calendar_today, color: Colors.blue),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Date range info
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Company FY: ${_formatDateDisplay(companyStart)} to ${_formatDateDisplay(companyEnd)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (tempFromDate.isAfter(tempToDate)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('From date must be before To date'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    setState(() {
                      _fromDate = _formatToTallyDate(tempFromDate);
                      _toDate = _formatToTallyDate(tempToDate);
                    });
                    Navigator.pop(context);
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Apply Filter'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.blue[50],
      labelStyle: TextStyle(color: Colors.blue[700]),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
  
  DateTime _parseTallyDate(String tallyDate) {
    try {
      if (tallyDate.length != 8) return DateTime.now();
      final year = int.parse(tallyDate.substring(0, 4));
      final month = int.parse(tallyDate.substring(4, 6));
      final day = int.parse(tallyDate.substring(6, 8));
      return DateTime(year, month, day);
    } catch (e) {
      return DateTime.now();
    }
  }
  
  String _formatToTallyDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }
  
  String _formatDateDisplay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
  
  Future<void> _fetchQuickStats() async {
    final db = await _db.database;
    
    // Get Sales
    final salesResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND reserved_name = 'Sales Accounts'
          AND is_deleted = 0
        
        UNION ALL
        
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ?
          AND g.is_deleted = 0
      )
      SELECT 
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
    ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);
    
    if (salesResult.isNotEmpty) {
      final credit = (salesResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
      final debit = (salesResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
      _totalSales = credit - debit;
    }
    
    // Get Purchase
    final purchaseResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND reserved_name = 'Purchase Accounts'
          AND is_deleted = 0
        
        UNION ALL
        
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ?
          AND g.is_deleted = 0
      )
      SELECT 
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
    ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);
    
    if (purchaseResult.isNotEmpty) {
      final debit = (purchaseResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
      final credit = (purchaseResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
      _totalPurchase = debit - credit;
    }
    
    // Calculate Net Profit
    await _calculateNetProfit();
    
    // Get Stock Value
    // await _calculateStockValue();
  }
  
  Future<void> _calculateNetProfit() async {
    final db = await _db.database;
    
    // Get Direct Expenses
    final directExpResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND name = 'Direct Expenses'
          AND is_deleted = 0
        
        UNION ALL
        
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ?
          AND g.is_deleted = 0
      )
      SELECT 
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
    ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);
    
    double directExpenses = 0.0;
    if (directExpResult.isNotEmpty) {
      final debit = (directExpResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
      final credit = (directExpResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
      directExpenses = debit - credit;
    }
    
    // Get Indirect Expenses
    final indirectExpResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND name = 'Indirect Expenses'
          AND is_deleted = 0
        
        UNION ALL
        
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ?
          AND g.is_deleted = 0
      )
      SELECT 
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
    ''', [_companyGuid, _companyGuid, _companyGuid, _fromDate, _toDate]);
    
    double indirectExpenses = 0.0;
    if (indirectExpResult.isNotEmpty) {
      final debit = (indirectExpResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
      final credit = (indirectExpResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
      indirectExpenses = debit - credit;
    }
    
    // Get Indirect Incomes
    final indirectIncResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND name = 'Indirect Incomes'
          AND is_deleted = 0
        
        UNION ALL
        
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ?
          AND g.is_deleted = 0
      )
      SELECT 
        SUM(l.opening_balance) as opening_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
        AND v.company_guid = l.company_guid
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
      WHERE l.company_guid = ?
        AND l.is_deleted = 0
    ''', [_companyGuid, _companyGuid, _fromDate, _toDate, _companyGuid]);
    
    double indirectIncomes = 0.0;
    if (indirectIncResult.isNotEmpty) {
      final opening = (indirectIncResult.first['opening_total'] as num?)?.toDouble() ?? 0.0;
      final credit = (indirectIncResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
      final debit = (indirectIncResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
      indirectIncomes = opening + credit - debit;
    }
    
    // Calculate Net Profit
    final grossProfit = _totalSales - (_totalPurchase + directExpenses);
    _netProfit = grossProfit + indirectIncomes - indirectExpenses;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Business Analytics'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showDateFilterDialog,
            tooltip: 'Filter by Date',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Header
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _companyName ?? 'No Company Selected',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Financial Reports & Analysis',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.date_range, size: 16, color: Colors.blue[700]),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Period: ${_formatDate(_fromDate ?? '')} to ${_formatDate(_toDate ?? '')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _showDateFilterDialog,
                                  icon: Icon(Icons.filter_alt, size: 16),
                                  label: Text('Change'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Quick Stats Section
                    Text(
                      'Quick Insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Sales',
                            _formatAmount(_totalSales),
                            Icons.shopping_cart,
                            Colors.green[100]!,
                            _totalSales >= 0 ? Colors.green[700]! : Colors.red[700]!,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Purchase',
                            _formatAmount(_totalPurchase),
                            Icons.shopping_bag,
                            Colors.orange[100]!,
                            Colors.orange[700]!,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Net Profit',
                            _formatAmount(_netProfit),
                            Icons.trending_up,
                            _netProfit >= 0 ? Colors.blue[100]! : Colors.red[100]!,
                            _netProfit >= 0 ? Colors.blue[700]! : Colors.red[700]!,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Stock Value',
                            _formatAmount(_stockValue),
                            Icons.inventory,
                            Colors.purple[100]!,
                            Colors.purple[700]!,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Reports Section
                    Text(
                      'Financial Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Report Cards
                    _buildReportCard(
                      title: 'Profit & Loss A/c',
                      subtitle: 'View income, expenses, and profitability',
                      icon: Icons.trending_up,
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfitLossScreen(),
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 12),
                    
                    _buildReportCard(
                      title: 'Balance Sheet',
                      subtitle: 'View assets, liabilities, and capital',
                      icon: Icons.account_balance,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BalanceSheetScreen(),
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 12),
                    
                    _buildReportCard(
                      title: 'Stock Summary',
                      subtitle: 'View inventory and stock valuation',
                      icon: Icons.inventory_2,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StockSummaryScreen(),
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Additional Reports
                    Text(
                      'Other Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    _buildSimpleReportTile(
                        'Payment Vouchers',
                        Icons.payment,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentScreen(),
                            ),
                          );
                        },
                      ),

                      _buildSimpleReportTile(
                        'Bill-Wise Outstanding',
                        Icons.payment,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BillWiseOutstandingScreen(),
                            ),
                          );
                        },
                      ),

                      _buildSimpleReportTile(
                        'Receipt Vouchers',
                        Icons.receipt,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReceiptScreen(),
                            ),
                          );
                        },
                      ),
                    
                    _buildSimpleReportTile(
                      'Cash Flow Statement',
                      Icons.monetization_on,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CashFlowScreen(),
                          ),
                        );
                      },
                    ),
                    
                    _buildSimpleReportTile(
                      'Trial Balance',
                      Icons.balance,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrialBalanceScreen(),
                          ),
                        );
                      },
                    ),
                    
                    _buildSimpleReportTile(
                      'Ledger Reports',
                      Icons.book,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LedgerReportsScreen(),
                          ),
                        );
                      },
                    ),
                    
                    _buildSimpleReportTile(
                      'GST Reports',
                      Icons.receipt_long,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GSTReportsScreen(),
                          ),
                        );
                      },
                    ),
                    
                    _buildSimpleReportTile(
                      'Party Outstanding',
                      Icons.people,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PartyOutstandingScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildReportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color bgColor,
    Color textColor,
  ) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: textColor.withOpacity(0.7), size: 28),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSimpleReportTile(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
  
  String _formatAmount(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final formatted = absAmount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₹${isNegative ? '-' : ''}$formatted';
  }
  
  String _formatDate(String tallyDate) {
    if (tallyDate.length != 8) return tallyDate;
    final year = tallyDate.substring(0, 4);
    final month = tallyDate.substring(4, 6);
    final day = tallyDate.substring(6, 8);
    return '$day-$month-$year';
  }
}