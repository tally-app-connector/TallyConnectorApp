// Analysis/payment_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _db = DatabaseHelper.instance;
  
  String? _companyGuid;
  String? _companyName;
  String? _fromDate;
  String? _toDate;
  bool _loading = true;
  
  List<Map<String, dynamic>> _payments = [];
  double _totalPayments = 0.0;
  
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
    _fromDate = company['starting_from'] as String? ?? '20250401';
    _toDate = company['ending_at'] as String? ?? '20260331';
    
    await _fetchPayments();
    
    setState(() => _loading = false);
  }
  
  Future<void> _fetchPayments() async {
    final db = await _db.database;
    
    final result = await db.rawQuery('''
      SELECT 
        v.voucher_guid,
        v.date,
        v.voucher_number,
        v.narration,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as amount,
        GROUP_CONCAT(DISTINCT CASE 
          WHEN vle.amount > 0 THEN vle.ledger_name 
          ELSE NULL 
        END) as party_names
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Payment'
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
      GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
      ORDER BY v.date DESC, v.voucher_number DESC
    ''', [_companyGuid, _fromDate, _toDate]);
    
    _payments = result;
    _totalPayments = _payments.fold(0.0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Vouchers'),
        backgroundColor: Colors.red[700],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  color: Colors.red[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _companyName ?? 'No Company Selected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Period: ${_formatDate(_fromDate ?? '')} to ${_formatDate(_toDate ?? '')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Payments',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatAmount(_totalPayments),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_payments.length} Vouchers',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Payments List
                Expanded(
                  child: _payments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'No Payment Vouchers Found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final payment = _payments[index];
                              return _buildPaymentCard(payment);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final date = payment['date'] as String;
    final voucherNumber = payment['voucher_number'] as String?;
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final partyNames = payment['party_names'] as String?;
    final narration = payment['narration'] as String?;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showPaymentDetails(payment),
        borderRadius: BorderRadius.circular(12),
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
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                voucherNumber ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (partyNames != null && partyNames.isNotEmpty)
                          Text(
                            partyNames,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatAmount(amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (narration != null && narration.isNotEmpty) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notes, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          narration,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _showPaymentDetails(Map<String, dynamic> payment) async {
    final voucherGuid = payment['voucher_guid'] as String;
    
    // Fetch detailed entries
    final db = await _db.database;
    final entries = await db.rawQuery('''
      SELECT 
        vle.ledger_name,
        vle.amount,
        l.parent as group_name
      FROM voucher_ledger_entries vle
      LEFT JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = ?
      WHERE vle.voucher_guid = ?
      ORDER BY vle.amount DESC
    ''', [_companyGuid, voucherGuid]);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Payment Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[900],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Voucher: ${payment['voucher_number']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  Text(
                    'Date: ${_formatDate(payment['date'])}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
                  final isDebit = amount < 0;
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDebit ? Colors.red[100] : Colors.green[100],
                        child: Icon(
                          isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isDebit ? Colors.red[700] : Colors.green[700],
                          size: 20,
                        ),
                      ),
                      title: Text(
                        entry['ledger_name'] as String,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: entry['group_name'] != null
                          ? Text(
                              entry['group_name'] as String,
                              style: TextStyle(fontSize: 12),
                            )
                          : null,
                      trailing: Text(
                        _formatAmount(amount.abs()),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDebit ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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