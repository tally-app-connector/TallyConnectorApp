// screens/ledger_detail_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'voucher_detail_screen.dart';

class LedgerDetailScreen extends StatefulWidget {
  final String companyGuid;
  final String companyName;
  final String ledgerName;
  final String fromDate;
  final String toDate;

  const LedgerDetailScreen({
    Key? key,
    required this.companyGuid,
    required this.companyName,
    required this.ledgerName,
    required this.fromDate,
    required this.toDate,
  }) : super(key: key);

  @override
  _LedgerDetailScreenState createState() => _LedgerDetailScreenState();
}

class _LedgerDetailScreenState extends State<LedgerDetailScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _vouchers = [];
  double _openingBalance = 0.0;
  double _runningBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() => _loading = true);

    final db = await _db.database;

    // Get opening balance
    final ledgerResult = await db.rawQuery('''
      SELECT opening_balance
      FROM ledgers
      WHERE company_guid = ?
        AND name = ?
        AND is_deleted = 0
      LIMIT 1
    ''', [widget.companyGuid, widget.ledgerName]);

    if (ledgerResult.isNotEmpty) {
      _openingBalance = (ledgerResult.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
      _runningBalance = _openingBalance;
    }

    // Get all vouchers affecting this ledger
    final voucherResult = await db.rawQuery('''
      SELECT 
        v.voucher_guid,
        v.date,
        v.voucher_type,
        v.voucher_number,
        v.narration,
        vle.amount,
        CASE 
          WHEN vle.amount < 0 THEN ABS(vle.amount)
          ELSE 0 
        END as debit,
        CASE 
          WHEN vle.amount > 0 THEN vle.amount
          ELSE 0 
        END as credit
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND vle.ledger_name = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
      ORDER BY v.date ASC, v.voucher_number ASC
    ''', [widget.companyGuid, widget.ledgerName, widget.fromDate, widget.toDate]);

    // Calculate running balance for each voucher
    List<Map<String, dynamic>> vouchersWithBalance = [];
    double balance = _openingBalance;

    for (final voucher in voucherResult) {
      print(voucher);
      final credit = (voucher['credit'] as num?)?.toDouble() ?? 0.0;
      final debit = (voucher['debit'] as num?)?.toDouble() ?? 0.0;
      balance = balance + credit - debit;

      vouchersWithBalance.add({
        ...voucher,
        'balance': balance,
      });
    }

    setState(() {
      _vouchers = vouchersWithBalance;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ledgerName, style: TextStyle(fontSize: 18)),
            Text(
              '${_formatDate(widget.fromDate)} to ${_formatDate(widget.toDate)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadVouchers,
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
                        widget.companyName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Opening Balance: ',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _formatAmount(_openingBalance),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _openingBalance >= 0
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Table Header
                Container(
                  color: Colors.grey[200],
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Date',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Particulars',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Vch Type',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Vch No.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Debit',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Credit',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Balance',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),

                // Voucher List
                Expanded(
                  child: _vouchers.isEmpty
                      ? Center(
                          child: Text(
                            'No transactions found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _vouchers.length,
                          separatorBuilder: (context, index) => Divider(height: 1),
                          itemBuilder: (context, index) {
                            final voucher = _vouchers[index];
                            final debit = (voucher['debit'] as num?)?.toDouble() ?? 0.0;
                            final credit = (voucher['credit'] as num?)?.toDouble() ?? 0.0;
                            final balance = (voucher['balance'] as num?)?.toDouble() ?? 0.0;

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VoucherDetailScreen(
                                      companyGuid: widget.companyGuid,
                                      companyName: widget.companyName,
                                      voucherGuid: voucher['voucher_guid'] as String,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                color: index.isEven ? Colors.white : Colors.grey[50],
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatDate(voucher['date'] as String),
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            voucher['narration'] as String? ?? '-',
                                            style: TextStyle(fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if ((voucher['narration'] as String?)
                                                  ?.isNotEmpty ==
                                              true)
                                            Icon(
                                              Icons.chevron_right,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        voucher['voucher_type'] as String? ?? '-',
                                        style: TextStyle(fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        voucher['voucher_number']?.toString() ?? '-',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        debit > 0 ? _formatAmount(debit) : '-',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: debit > 0 ? Colors.red[700] : Colors.grey,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        credit > 0 ? _formatAmount(credit) : '-',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: credit > 0 ? Colors.green[700] : Colors.grey,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatAmount(balance),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: balance >= 0
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Summary Footer
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      top: BorderSide(color: Colors.grey[400]!, width: 2),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 10,
                        child: Text(
                          'Total (${_vouchers.length} transactions)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(_calculateTotal('debit')),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(_calculateTotal('credit')),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(_vouchers.isNotEmpty
                              ? (_vouchers.last['balance'] as num?)?.toDouble() ?? 0.0
                              : _openingBalance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  double _calculateTotal(String field) {
    return _vouchers.fold(
      0.0,
      (sum, voucher) => sum + ((voucher[field] as num?)?.toDouble() ?? 0.0),
    );
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
}