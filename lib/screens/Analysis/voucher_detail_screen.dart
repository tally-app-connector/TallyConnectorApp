// screens/voucher_detail_screen.dart

import 'package:flutter/material.dart';
import '../../services/queries/query_service.dart';

class VoucherDetailScreen extends StatefulWidget {
  final String companyGuid;
  final String companyName;
  final String voucherGuid;

  const VoucherDetailScreen({
    Key? key,
    required this.companyGuid,
    required this.companyName,
    required this.voucherGuid,
  }) : super(key: key);

  @override
  _VoucherDetailScreenState createState() => _VoucherDetailScreenState();
}

class _VoucherDetailScreenState extends State<VoucherDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _voucherHeader;
  List<Map<String, dynamic>> _voucherEntries = [];

  @override
  void initState() {
    super.initState();
    _loadVoucherDetails();
  }

  Future<void> _loadVoucherDetails() async {
    setState(() => _loading = true);

    final header = await QueryService.getVoucherHeader(
      widget.companyGuid, widget.voucherGuid,
    );

    if (header == null) {
      setState(() => _loading = false);
      return;
    }

    _voucherHeader = header;

    final entries = await QueryService.getVoucherLedgerEntries(
      widget.voucherGuid,
    );

    setState(() {
      _voucherEntries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Voucher Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadVoucherDetails,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _voucherHeader == null
              ? Center(
                  child: Text(
                    'Voucher not found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Container(
                        width: double.infinity,
                        color: Colors.blue[50],
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.companyName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _voucherHeader!['voucher_type'] as String? ?? '-',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Voucher Info Card
                      Card(
                        margin: EdgeInsets.all(16),
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                'Voucher No.',
                                _voucherHeader!['voucher_number']?.toString() ?? '-',
                              ),
                              Divider(),
                              _buildInfoRow(
                                'Date',
                                _formatDate(_voucherHeader!['date'] as String),
                              ),
                              if (_voucherHeader!['reference_number'] != null)
                                Column(
                                  children: [
                                    Divider(),
                                    _buildInfoRow(
                                      'Ref. No.',
                                      _voucherHeader!['reference_number'] as String,
                                    ),
                                  ],
                                ),
                              if (_voucherHeader!['reference_date'] != null)
                                Column(
                                  children: [
                                    Divider(),
                                    _buildInfoRow(
                                      'Ref. Date',
                                      _formatDate(_voucherHeader!['reference_date'] as String),
                                    ),
                                  ],
                                ),
                              if (_voucherHeader!['party_name'] != null)
                                Column(
                                  children: [
                                    Divider(),
                                    _buildInfoRow(
                                      'Party Name',
                                      _voucherHeader!['party_name'] as String,
                                    ),
                                  ],
                                ),
                              Divider(),
                              Row(
                                children: [
                                  if ((_voucherHeader!['is_invoice'] as int?) == 1)
                                    Chip(
                                      label: Text('Invoice', style: TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.green[100],
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                    ),
                                  SizedBox(width: 8),
                                  if ((_voucherHeader!['is_accounting_voucher'] as int?) == 1)
                                    Chip(
                                      label: Text('Accounting', style: TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.blue[100],
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                    ),
                                  SizedBox(width: 8),
                                  if ((_voucherHeader!['is_inventory_voucher'] as int?) == 1)
                                    Chip(
                                      label: Text('Inventory', style: TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.orange[100],
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Narration
                      if (_voucherHeader!['narration'] != null &&
                          (_voucherHeader!['narration'] as String).isNotEmpty)
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.notes, size: 16, color: Colors.amber[900]),
                                  SizedBox(width: 8),
                                  Text(
                                    'Narration',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[900],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                _voucherHeader!['narration'] as String,
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: 16),

                      // Ledger Entries Section
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Ledger Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(height: 8),

                      // Table Header
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.grey[200],
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Ledger',
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

                      // Entries List
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            ..._voucherEntries.asMap().entries.map((entry) {
                              final index = entry.key;
                              final ledgerEntry = entry.value;
                              final debit = (ledgerEntry['debit'] as num?)?.toDouble() ?? 0.0;
                              final credit = (ledgerEntry['credit'] as num?)?.toDouble() ?? 0.0;

                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: index.isEven ? Colors.white : Colors.grey[50],
                                  border: Border(
                                    bottom: index < _voucherEntries.length - 1
                                        ? BorderSide(color: Colors.grey[200]!)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        ledgerEntry['ledger_name'] as String,
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        debit > 0 ? _formatAmount(debit) : '-',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: debit > 0 ? Colors.red[700] : Colors.grey,
                                          fontWeight: debit > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        credit > 0 ? _formatAmount(credit) : '-',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: credit > 0 ? Colors.green[700] : Colors.grey,
                                          fontWeight: credit > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            // Total Row
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border(
                                  top: BorderSide(color: Colors.grey[400]!, width: 2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
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
                                      _formatAmount(_calculateTotal('debit')),
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
                                      _formatAmount(_calculateTotal('credit')),
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
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Voucher GUID (for reference)
                      Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GUID: ${widget.voucherGuid}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotal(String field) {
    return _voucherEntries.fold(
      0.0,
      (sum, entry) => sum + ((entry[field] as num?)?.toDouble() ?? 0.0),
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