// screens/Analysis/party_ledger_detail_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'ledger_detail_screen.dart';

class PartyLedgerDetailScreen extends StatefulWidget {
  final String companyGuid;
  final String companyName;
  final String groupName;
  final bool isReceivable;

  const PartyLedgerDetailScreen({
    Key? key,
    required this.companyGuid,
    required this.companyName,
    required this.groupName,
    required this.isReceivable,
  }) : super(key: key);

  @override
  _PartyLedgerDetailScreenState createState() => _PartyLedgerDetailScreenState();
}

class _PartyLedgerDetailScreenState extends State<PartyLedgerDetailScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _parties = [];
  String? _fromDate;
  String? _toDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final company = await _db.getSelectedCompanyByGuid();
    _fromDate = company?['starting_from'] as String? ?? '20250401';
    _toDate = company?['ending_at'] as String? ?? '20260331';

    await _fetchParties();

    setState(() => _loading = false);
  }

  Future<void> _fetchParties() async {
    final db = await _db.database;

    String query;
    if (widget.groupName == 'Sundry Debtors') {
      query = '''
        WITH RECURSIVE debtor_tree AS (
          SELECT group_guid, name
          FROM groups
          WHERE company_guid = ?
            AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
            AND is_deleted = 0
          
          UNION ALL
          
          SELECT g.group_guid, g.name
          FROM groups g
          INNER JOIN debtor_tree dt ON g.parent_guid = dt.group_guid
          WHERE g.company_guid = ?
            AND g.is_deleted = 0
        )
        SELECT 
          l.name as party_name,
          l.opening_balance,
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
          (l.opening_balance + 
           COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) - 
           COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)) as balance,
          COUNT(DISTINCT v.voucher_guid) as transaction_count
        FROM ledgers l
        INNER JOIN debtor_tree dt ON l.parent = dt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
          AND v.company_guid = l.company_guid
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
        WHERE l.company_guid = ?
          AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        ORDER BY ABS(balance) DESC
      ''';
    } else {
      query = '''
        WITH RECURSIVE creditor_tree AS (
          SELECT group_guid, name
          FROM groups
          WHERE company_guid = ?
            AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
            AND is_deleted = 0
          
          UNION ALL
          
          SELECT g.group_guid, g.name
          FROM groups g
          INNER JOIN creditor_tree ct ON g.parent_guid = ct.group_guid
          WHERE g.company_guid = ?
            AND g.is_deleted = 0
        )
        SELECT 
          l.name as party_name,
          l.opening_balance,
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
          (l.opening_balance + 
           COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) - 
           COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)) as balance,
          COUNT(DISTINCT v.voucher_guid) as transaction_count
        FROM ledgers l
        INNER JOIN creditor_tree ct ON l.parent = ct.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
          AND v.company_guid = l.company_guid
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
        WHERE l.company_guid = ?
          AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        ORDER BY ABS(balance) DESC
      ''';
    }

    final result = await db.rawQuery(query, [widget.companyGuid, widget.companyGuid, widget.companyGuid]);

    _parties = result.where((party) {
      final balance = (party['balance'] as num?)?.toDouble() ?? 0.0;
      return widget.isReceivable ? balance > 0.01 : balance < -0.01;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
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
                Container(
                  width: double.infinity,
                  color: Colors.blue[50],
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        widget.companyName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.isReceivable ? 'Receivables' : 'Payables',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isReceivable ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  color: Colors.grey[200],
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Party Name',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Txns',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Outstanding',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _parties.isEmpty
                      ? Center(
                          child: Text(
                            'No parties found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _parties.length,
                          separatorBuilder: (context, index) => Divider(height: 1),
                          itemBuilder: (context, index) {
                            final party = _parties[index];
                            final balance = (party['balance'] as num?)?.toDouble() ?? 0.0;
                            final outstanding = balance.abs();
                            final txnCount = party['transaction_count'] as int? ?? 0;

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LedgerDetailScreen(
                                      companyGuid: widget.companyGuid,
                                      companyName: widget.companyName,
                                      ledgerName: party['party_name'] as String,
                                      fromDate: _fromDate!,
                                      toDate: _toDate!,
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
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              party['party_name'] as String,
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$txnCount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatAmount(outstanding),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: widget.isReceivable
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
                        flex: 4,
                        child: Text(
                          'Total (${_parties.length} parties)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(_calculateTotal()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: widget.isReceivable
                                ? Colors.green[700]
                                : Colors.red[700],
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

  double _calculateTotal() {
    return _parties.fold(0.0, (sum, party) {
      final balance = (party['balance'] as num?)?.toDouble() ?? 0.0;
      return sum + balance.abs();
    });
  }

  String _formatAmount(double amount) {
    return '₹' +
        amount.toStringAsFixed(2).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );
  }
}