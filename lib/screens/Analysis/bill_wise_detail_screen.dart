// screens/bill_wise_detail_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/queries/query_service.dart';
import '../theme/app_theme.dart';

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

  final result = await QueryService.getBillWiseDetail(
    widget.companyGuid, widget.ledgerName, widget.fromDate, widget.toDate,
  );
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
    final parts = amount.abs().toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    // Indian numbering: last 3 digits, then groups of 2
    String formatted;
    if (intPart.length <= 3) {
      formatted = intPart;
    } else {
      final last3 = intPart.substring(intPart.length - 3);
      String rest = intPart.substring(0, intPart.length - 3);
      final buffer = StringBuffer();
      while (rest.length > 2) {
        buffer.write('${rest.substring(0, rest.length - 2)},');
        rest = rest.substring(rest.length - 2);
      }
      if (rest.isNotEmpty) buffer.write('$rest,');
      formatted = '$buffer$last3';
    }
    return '₹$formatted.$decPart';
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
      backgroundColor: AppColors.background, // old: Colors.grey[100]
      appBar: AppBar(
        backgroundColor: AppColors.surface, // old: default
        foregroundColor: AppColors.textPrimary, // old: default
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ledgerName, style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
            Text(
              'Bill-Wise Outstanding',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textSecondary),
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
              color: AppColors.iconBgBlue, // old: Colors.blue[50]
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blue.withOpacity(0.3)), // old: Colors.blue[200]
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.blue, size: 20), // old: Colors.blue[700]
                SizedBox(width: 12),
                Text(
                  '${DateFormat('dd MMM yyyy').format(widget.selectedFromDate)} - ${DateFormat('dd MMM yyyy').format(widget.selectedToDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary, // old: Colors.blue[900]
                  ),
                ),
              ],
            ),
          ),

          // Total Outstanding Card
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Outstanding',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_bills.length} Bills',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatCurrency(_totalOutstanding),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                        Icon(Icons.receipt, size: 64, color: AppColors.textSecondary), // old: Colors.grey[400]
                        SizedBox(height: 16),
                        Text(
                          'No pending bills',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary, // old: Colors.grey[600]
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                            color: AppColors.textPrimary, // old: Colors.black87
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _parseTallyDate(bill['bill_date'] as String),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary, // old: Colors.grey[600]
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        _formatCurrency(outstanding),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: outstanding >= 0
                                              ? AppColors.green // old: Colors.green[700]
                                              : AppColors.red,  // old: Colors.red[700]
                                        ),
                                      ),
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
                                            color: AppColors.textSecondary, // old: Colors.grey[600]
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _formatCurrency(billAmount),
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary, // old: Colors.black87
                                            ),
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
                                            color: AppColors.textSecondary, // old: Colors.grey[600]
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _formatCurrency(paymentAmount),
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary, // old: Colors.black87
                                            ),
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
                                      color: AppColors.iconBgBlue, // old: Colors.blue[50]
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${bill['payment_count']} payments',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.blue, // old: Colors.blue[700]
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