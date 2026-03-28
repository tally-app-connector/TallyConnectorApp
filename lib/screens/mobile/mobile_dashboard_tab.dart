import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../utils/amount_formatter.dart';
import '../../utils/secure_storage.dart';
import '../../models/user_model.dart';
import '../theme/app_theme.dart';
import 'dart:convert';

class MobileDashboardTab extends StatefulWidget {
  const MobileDashboardTab({Key? key}) : super(key: key);

  @override
  State<MobileDashboardTab> createState() => _MobileDashboardTabState();
}

class _MobileDashboardTabState extends State<MobileDashboardTab> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  User? _currentUser;
  String? _companyGuid;
  String? _companyName;
  Map<String, dynamic>? _summaryData;
  String _fromDate = '20250401';
  String _toDate = '20260331';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userData = await SecureStorage.getUser();
    if (userData != null) {
      _currentUser = User.fromJson(jsonDecode(userData));
    }

    final company = await _db.getSelectedCompanyByGuid();
    if (company == null) {
      setState(() => _loading = false);
      return;
    }

    _companyGuid = company['company_guid'] as String;
    _companyName = company['company_name'] as String;
    _fromDate = company['starting_from'] as String? ?? _fromDate;
    _toDate = company['ending_at'] as String? ?? _toDate;

    final summary = await _fetchSummary(_companyGuid!, _fromDate, _toDate);

    setState(() {
      _summaryData = summary;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>> _fetchSummary(
    String companyGuid,
    String fromDate,
    String toDate,
  ) async {
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
      -- OLD: used raw amount sign (ignores is_deemed_positive for credit notes/debit notes)
      -- COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) -
      -- SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as net_sales
      -- FIX: use is_deemed_positive to match sales_service.dart canonical formula
      SELECT
        COALESCE(SUM(CASE
          WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount)
          ELSE -ABS(vle.amount)
        END), 0) as net_sales
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0
        AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

    final netSales = (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;

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
      -- OLD: used raw amount sign (ignores is_deemed_positive for debit notes/purchase returns)
      -- COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
      -- SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as net_purchase
      -- FIX: use is_deemed_positive to match sales_service.dart canonical formula
      SELECT
        COUNT(DISTINCT v.voucher_guid) as vouchers,
        COALESCE(SUM(CASE
          WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount)
          ELSE -ABS(vle.amount)
        END), 0) as net_purchase
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0
        AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

    final netPurchase = (purchaseResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;

    // Receivables
    final receivablesResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT COALESCE(SUM(outstanding), 0) as total_receivables FROM (
        SELECT
          (l.opening_balance * -1) +
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)
          as outstanding
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        HAVING outstanding > 0
      )
    ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

    final totalReceivables = (receivablesResult.first['total_receivables'] as num?)?.toDouble() ?? 0.0;

    // Payables
    final payablesResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors') AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT COALESCE(SUM(outstanding), 0) as total_payables FROM (
        SELECT
          l.opening_balance +
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)
          as outstanding
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        HAVING outstanding > 0
      )
    ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

    final totalPayables = (payablesResult.first['total_payables'] as num?)?.toDouble() ?? 0.0;

    // Receipts & Payments totals
    final receiptsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total_receipts
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ? AND v.voucher_type = 'Receipt'
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
    ''', [companyGuid, fromDate, toDate]);

    final totalReceipts = (receiptsResult.first['total_receipts'] as num?)?.toDouble() ?? 0.0;

    final paymentsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as total_payments
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ? AND v.voucher_type = 'Payment'
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
    ''', [companyGuid, fromDate, toDate]);

    final totalPayments = (paymentsResult.first['total_payments'] as num?)?.toDouble() ?? 0.0;

    return {
      'sales': netSales,
      'purchase': netPurchase,
      'gross_profit': netSales - netPurchase,
      'receivables': totalReceivables,
      'payables': totalPayables,
      'receipts': totalReceipts,
      'payments': totalPayments,
    };
  }

  String _formatCurrency(double amount) {
    return AmountFormatter.currencyIndian(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (_companyName != null)
              Text(_companyName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summaryData == null
              ? _buildNoCompanyView()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome card
                        if (_currentUser != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade600, Colors.blue.shade800],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${_currentUser!.fullName}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _companyName ?? 'No company selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Sales & Purchase row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Sales',
                                _summaryData!['sales'] as double,
                                Icons.trending_up,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Purchase',
                                _summaryData!['purchase'] as double,
                                Icons.shopping_cart,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Gross Profit
                        _buildWideCard(
                          'Gross Profit',
                          _summaryData!['gross_profit'] as double,
                          Icons.assessment,
                          (_summaryData!['gross_profit'] as double) >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(height: 20),

                        // Receivables & Payables
                        const Text(
                          'Outstanding',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Receivables',
                                _summaryData!['receivables'] as double,
                                Icons.call_received,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Payables',
                                _summaryData!['payables'] as double,
                                Icons.call_made,
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Cash Flow
                        const Text(
                          'Cash Flow',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Receipts',
                                _summaryData!['receipts'] as double,
                                Icons.arrow_downward,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Payments',
                                _summaryData!['payments'] as double,
                                Icons.arrow_upward,
                                Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoCompanyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 80, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No Company Selected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sync your data from the Windows app and select a company in Profile settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: amount < 0 ? Colors.red : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideCard(String title, double amount, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(amount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
