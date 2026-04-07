// screens/Analysis/trial_balance_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/queries/query_service.dart';
import '../theme/app_theme.dart';

class TrialBalanceScreen extends StatefulWidget {
  @override
  _TrialBalanceScreenState createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  final _db = DatabaseHelper.instance;
  
  String? _companyGuid;
  String? _companyName;
  bool _loading = true;
  
  List<Map<String, dynamic>> _ledgers = [];
  String _fromDate = '20250401';
  String _toDate = '20260331';
  
  DateTime? _selectedFromDate;
  DateTime? _selectedToDate;
  
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
    
    if (_selectedFromDate == null || _selectedToDate == null) {
      _fromDate = company['starting_from'] as String? ?? _fromDate;
      _toDate = company['ending_at'] as String? ?? _toDate;
      _selectedFromDate = _parseTallyDate(_fromDate);
      _selectedToDate = _parseTallyDate(_toDate);
    }
    
    await _fetchTrialBalance();
    
    setState(() => _loading = false);
  }
  
  DateTime _parseTallyDate(String tallyDate) {
    if (tallyDate.length != 8) return DateTime.now();
    final year = int.parse(tallyDate.substring(0, 4));
    final month = int.parse(tallyDate.substring(4, 6));
    final day = int.parse(tallyDate.substring(6, 8));
    return DateTime(year, month, day);
  }
  
  String _toTallyDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }
  
  Future<void> _fetchTrialBalance() async {
    _ledgers = await QueryService.getTrialBalance(
      _companyGuid!, _fromDate, _toDate,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    syncBrightness(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Trial Balance'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  color: Colors.blue[50],
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _companyName ?? '',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'As on ${_formatDate(_toDate)}',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                
                // Table Header
                Container(
                  color: AppColors.pillBg,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Particulars',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Group',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Debit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Credit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Ledger List
                Expanded(
                  child: _ledgers.isEmpty
                      ? Center(
                          child: Text(
                            'No ledgers found',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _ledgers.length,
                          separatorBuilder: (context, index) => Divider(height: 1),
                          itemBuilder: (context, index) {
                            final ledger = _ledgers[index];
                            final closing = (ledger['closing_balance'] as num?)?.toDouble() ?? 0.0;
                            final debit = closing < 0 ? closing.abs() : 0.0;
                            final credit = closing >= 0 ? closing : 0.0;
                            
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              color: index.isEven ? AppColors.surface : AppColors.pillBg,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      ledger['ledger_name'] as String,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      ledger['group_name'] as String? ?? '-',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      debit > 0 ? _formatAmount(debit) : '-',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: debit > 0 ? Colors.red[700] : AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      credit > 0 ? _formatAmount(credit) : '-',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: credit > 0 ? Colors.green[700] : AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                
                // Total Footer
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.pillBg,
                    border: Border(
                      top: BorderSide(color: AppColors.divider, width: 2),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(_calculateTotalDebit()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.red[700],
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(_calculateTotalCredit()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.green[700],
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Difference Indicator
                if ((_calculateTotalDebit() - _calculateTotalCredit()).abs() > 0.01)
                  Container(
                    padding: EdgeInsets.all(12),
                    color: Colors.red[50],
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Trial Balance not matching! Difference: ${_formatAmount((_calculateTotalDebit() - _calculateTotalCredit()).abs())}',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
  
  double _calculateTotalDebit() {
    return _ledgers.fold(0.0, (sum, ledger) {
      final closing = (ledger['closing_balance'] as num?)?.toDouble() ?? 0.0;
      return sum + (closing < 0 ? closing.abs() : 0.0);
    });
  }
  
  double _calculateTotalCredit() {
    return _ledgers.fold(0.0, (sum, ledger) {
      final closing = (ledger['closing_balance'] as num?)?.toDouble() ?? 0.0;
      return sum + (closing >= 0 ? closing : 0.0);
    });
  }
  
  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
  
  String _formatDate(String tallyDate) {
    if (tallyDate.length != 8) return tallyDate;
    final year = tallyDate.substring(0, 4);
    final month = tallyDate.substring(4, 6);
    final day = tallyDate.substring(6, 8);
    return '$day-$month-$year';
  }
  
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _selectedFromDate != null && _selectedToDate != null
          ? DateTimeRange(start: _selectedFromDate!, end: _selectedToDate!)
          : null,
    );
    
    if (picked != null) {
      setState(() {
        _selectedFromDate = picked.start;
        _selectedToDate = picked.end;
        _fromDate = _toTallyDate(picked.start);
        _toDate = _toTallyDate(picked.end);
      });
      
      await _loadData();
    }
  }
}