import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/queries/query_service.dart';
import '../../utils/amount_formatter.dart';
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
    final data = await QueryService.getAnalysisDetailed(
      companyGuid, fromDate, toDate,
    );

    return {
      'sales': data['sales'],
      'purchase': data['purchase'],
      'gross_profit': data['gross_profit'],
      'receivables': data['total_receivables'],
      'payables': data['total_payables'],
      'receipts': data['total_receipts'],
      'payments': data['total_payments'],
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
