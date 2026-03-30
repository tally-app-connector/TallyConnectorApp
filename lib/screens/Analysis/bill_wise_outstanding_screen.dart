// screens/bill_wise_outstanding_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/queries/query_service.dart';
import 'bill_wise_detail_screen.dart';

class BillWiseOutstandingScreen extends StatefulWidget {
  @override
  _BillWiseOutstandingScreenState createState() => _BillWiseOutstandingScreenState();
}

class _BillWiseOutstandingScreenState extends State<BillWiseOutstandingScreen> {
  final _db = DatabaseHelper.instance;
  
  String? _companyGuid;
  String? _companyName;
  bool _loading = true;
  
  List<Map<String, dynamic>> _ledgers = [];
  String _fromDate = '20250401';
  String _toDate = '20260331';
  
  DateTime? _selectedFromDate;
  DateTime? _selectedToDate;
  
  String _selectedType = 'Receivables'; // Receivables or Payables

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

    await _loadLedgers();
    
    setState(() => _loading = false);
  }

  DateTime _parseTallyDate(String tallyDate) {
    if (tallyDate.length != 8) return DateTime.now();
    final year = int.parse(tallyDate.substring(0, 4));
    final month = int.parse(tallyDate.substring(4, 6));
    final day = int.parse(tallyDate.substring(6, 8));
    return DateTime(year, month, day);
  }

  String _formatDateToTally(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _selectedFromDate ?? DateTime.now(),
        end: _selectedToDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedFromDate = picked.start;
        _selectedToDate = picked.end;
        _fromDate = _formatDateToTally(picked.start);
        _toDate = _formatDateToTally(picked.end);
      });
      _loadLedgers();
    }
  }

  Future<void> _loadLedgers() async {
    final groupName = _selectedType == 'Receivables' ? 'Sundry Debtors' : 'Sundry Creditors';

    final result = await QueryService.getBillWiseOutstandingLedgers(
      _companyGuid!, groupName, _fromDate!, _toDate!,
    );

      // prettyPrint(result);

      print('ledger_name, group_name, ledger_opening_balance, credit_before, debit_before, opening_balance, credit_total,debit_total, outstanding, transaction_count');

    for (final entry in result){
      print('${entry['ledger_name']}, ${entry['group_name']}, ${entry['ledger_opening_balance']}, ${entry['credit_before']}, ${entry['debit_before']}, ${entry['opening_balance']}, ${entry['credit_total']}, ${entry['debit_total']}, ${entry['outstanding']}, ${entry['transaction_count']}');
  }
    
    setState(() {
      _ledgers = result;
    });
  }

  String _formatCurrency(double amount) {
    return '₹${amount.abs().toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  void _navigateToDetail(Map<String, dynamic> ledger) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillWiseDetailScreen(
          companyGuid: _companyGuid!,
          ledgerName: ledger['ledger_name'] as String,
          fromDate: _fromDate,
          toDate: _toDate,
          selectedFromDate: _selectedFromDate!,
          selectedToDate: _selectedToDate!,
          ledgerType: _selectedType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalOutstanding = _ledgers.fold<double>(
      0.0,
      (sum, ledger) => sum + ((ledger['outstanding'] as num?)?.toDouble() ?? 0.0),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill-Wise Outstanding', style: TextStyle(fontSize: 18)),
            if (_companyName != null)
              Text(
                _companyName!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Display
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${DateFormat('dd MMM yyyy').format(_selectedFromDate!)} - ${DateFormat('dd MMM yyyy').format(_selectedToDate!)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selectDateRange,
                  child: Text('Change'),
                ),
              ],
            ),
          ),

          // Type Selector
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedType = 'Receivables');
                      _loadLedgers();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedType == 'Receivables'
                            ? Colors.green
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Receivables',
                          style: TextStyle(
                            color: _selectedType == 'Receivables'
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedType = 'Payables');
                      _loadLedgers();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedType == 'Payables'
                            ? Colors.orange
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Payables',
                          style: TextStyle(
                            color: _selectedType == 'Payables'
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Total Outstanding Card
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _selectedType == 'Receivables'
                    ? [Colors.green[400]!, Colors.green[600]!]
                    : [Colors.orange[400]!, Colors.orange[600]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_selectedType == 'Receivables' ? Colors.green : Colors.orange)
                      .withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  _selectedType == 'Receivables'
                      ? Icons.call_received
                      : Icons.call_made,
                  color: Colors.white,
                  size: 32,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Outstanding',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatCurrency(totalOutstanding),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_ledgers.length} Parties',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Ledgers List
          Expanded(
            child: _ledgers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No outstanding found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _ledgers.length,
                    itemBuilder: (context, index) {
                      final ledger = _ledgers[index];
                      final outstanding = (ledger['outstanding'] as num?)?.toDouble() ?? 0.0;
                      final transactionCount = (ledger['transaction_count'] as num?)?.toInt() ?? 0;

                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _navigateToDetail(ledger),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ledger['ledger_name'] as String,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            ledger['group_name'] as String,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatCurrency(outstanding),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: outstanding >= 0
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$transactionCount txns',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
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
}

void prettyPrint(dynamic obj) {
  if (obj is Map || obj is List) {
    print(JsonEncoder.withIndent('  ').convert(obj));
  } else {
    // Try to convert to JSON if it has toJson method
    try {
      final json = (obj as dynamic).toJson();
      print(JsonEncoder.withIndent('  ').convert(json));
    } catch (e) {
      print(obj.toString());
    }
  }
}