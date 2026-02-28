// screens/bill_wise_detail_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';

class BillWiseDetailScreen extends StatefulWidget {
  final String companyGuid;
  final String ledgerName;
  final String fromDate;
  final String toDate;
  final DateTime selectedFromDate;
  final DateTime selectedToDate;
  final String ledgerType;

  BillWiseDetailScreen({
    required this.companyGuid,
    required this.ledgerName,
    required this.fromDate,
    required this.toDate,
    required this.selectedFromDate,
    required this.selectedToDate,
    required this.ledgerType,
  });

  @override
  _BillWiseDetailScreenState createState() => _BillWiseDetailScreenState();
}

class _BillWiseDetailScreenState extends State<BillWiseDetailScreen> {
  final _db = DatabaseHelper.instance;
  
  bool _loading = true;
  List<Map<String, dynamic>> _bills = [];
  double _totalOutstanding = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
  setState(() => _loading = true);
  
  final db = await _db.database;
  
  final result = await db.rawQuery('''
    WITH bill_entries AS (
      SELECT 
        vle.ledger_name,
        vle.bill_name as reference_name,
        vle.bill_type,
        v.date as transaction_date,
        v.voucher_number,
        v.voucher_type,
        vle.bill_date,
        CASE 
          WHEN vle.bill_type = 'New Ref' THEN vle.amount
          ELSE 0
        END as bill_amount,
        CASE 
          WHEN vle.bill_type = 'Agst Ref' THEN vle.amount
          ELSE 0
        END as payment_amount,
        v.voucher_guid
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ?
        AND vle.ledger_name = ?
        AND vle.bill_name IS NOT NULL
        AND vle.bill_name != ''
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
    ),
    bill_summary AS (
      SELECT 
        reference_name,
        MIN(bill_date) as bill_date,
        MIN(transaction_date) as first_transaction_date,
        SUM(bill_amount) as total_bill_amount,
        SUM(payment_amount) as total_payment_amount,
        (SUM(bill_amount) + SUM(payment_amount)) as outstanding,
        COUNT(DISTINCT CASE WHEN bill_type = 'New Ref' THEN voucher_guid END) as bill_count,
        COUNT(DISTINCT CASE WHEN bill_type = 'Agst Ref' THEN voucher_guid END) as payment_count
      FROM bill_entries
      GROUP BY reference_name
      HAVING ABS(outstanding) > 0.01
    )
    SELECT 
      reference_name,
      COALESCE(bill_date, first_transaction_date) as bill_date,
      total_bill_amount,
      ABS(total_payment_amount) as total_payment_amount,
      outstanding,
      bill_count,
      payment_count,
      SUM(outstanding) OVER () as total_outstanding
    FROM bill_summary
    ORDER BY COALESCE(bill_date, first_transaction_date) DESC, reference_name
  ''', [widget.companyGuid, widget.ledgerName, widget.fromDate, widget.toDate]);
  // prettyPrint(result);
      print('reference_name, bill_date, total_bill_amount, total_payment_amount, outstanding, bill_count, payment_count');

  for (final entry in result){
      print('${entry['reference_name']}, ${entry['bill_date']}, ${entry['total_bill_amount']}, ${entry['total_payment_amount']}, ${entry['outstanding']}, ${entry['bill_count']}, ${entry['payment_count']}');
  }
  setState(() {
    _bills = result;
    _totalOutstanding = result.isNotEmpty
        ? (result.first['total_outstanding'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    _loading = false;
  });
}

  String _formatCurrency(double amount) {
    return '₹${amount.abs().toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  String _parseTallyDate(String tallyDate) {
    if (tallyDate.length != 8) return '-';
    final year = tallyDate.substring(0, 4);
    final month = tallyDate.substring(4, 6);
    final day = tallyDate.substring(6, 8);
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ledgerName, style: TextStyle(fontSize: 18)),
            Text(
              'Bill-Wise Outstanding',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Range
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
                Text(
                  '${DateFormat('dd MMM yyyy').format(widget.selectedFromDate)} - ${DateFormat('dd MMM yyyy').format(widget.selectedToDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),

          // Total Outstanding Card
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.ledgerType == 'Receivables'
                    ? [Colors.green[400]!, Colors.green[600]!]
                    : [Colors.orange[400]!, Colors.orange[600]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (widget.ledgerType == 'Receivables' ? Colors.green : Colors.orange)
                      .withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.white, size: 32),
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
                        _formatCurrency(_totalOutstanding),
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
                    '${_bills.length} Bills',
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

          // Bills List
          Expanded(
            child: _bills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No pending bills',
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
                    itemCount: _bills.length,
                    itemBuilder: (context, index) {
                      final bill = _bills[index];
                      final outstanding = (bill['outstanding'] as num?)?.toDouble() ?? 0.0;
                      final billAmount = (bill['total_bill_amount'] as num?)?.toDouble() ?? 0.0;
                      final paymentAmount = (bill['total_payment_amount'] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bill['reference_name'] as String,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _parseTallyDate(bill['bill_date'] as String),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(outstanding),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: outstanding >= 0
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                              
                              Divider(height: 24),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bill Amount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _formatCurrency(billAmount),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Paid',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _formatCurrency(paymentAmount),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${bill['payment_count']} payments',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
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