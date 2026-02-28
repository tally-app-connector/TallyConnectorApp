// screens/group_detail_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'ledger_detail_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String companyGuid;
  final String companyName;
  final String groupName;
  final String fromDate;
  final String toDate;

  const GroupDetailScreen({
    Key? key,
    required this.companyGuid,
    required this.companyName,
    required this.groupName,
    required this.fromDate,
    required this.toDate,
  }) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _ledgers = [];

  @override
  void initState() {
    super.initState();
    _loadLedgers();
  }

  Future<void> _loadLedgers() async {
    setState(() => _loading = true);

    final db = await _db.database;

    // Determine the query based on group type
    String query;
    List<dynamic> params;

    if (widget.groupName == 'Purchase Accounts') {
      query = '''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name
          FROM groups
          WHERE company_guid = ?
            AND reserved_name = 'Purchase Accounts'
            AND is_deleted = 0
          
          UNION ALL
          
          SELECT g.group_guid, g.name
          FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ?
            AND g.is_deleted = 0
        )
        SELECT 
          l.name as ledger_name,
          l.opening_balance,
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
          (l.opening_balance + 
           COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) - 
           COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)) as closing_balance,
          COUNT(DISTINCT v.voucher_guid) as voucher_count
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
          AND v.company_guid = l.company_guid
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
          AND v.date >= ?
          AND v.date <= ?
        WHERE l.company_guid = ?
          AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        ORDER BY closing_balance DESC
      ''';
      params = [
        widget.companyGuid,
        widget.companyGuid,
        widget.fromDate,
        widget.toDate,
        widget.companyGuid,
      ];
    } else if (widget.groupName == 'Sales Accounts') {
      query = '''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name
          FROM groups
          WHERE company_guid = ?
            AND reserved_name = 'Sales Accounts'
            AND is_deleted = 0
          
          UNION ALL
          
          SELECT g.group_guid, g.name
          FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ?
            AND g.is_deleted = 0
        )
        SELECT 
          l.name as ledger_name,
          l.opening_balance,
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
          (l.opening_balance + 
           COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
           COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance,
          COUNT(DISTINCT v.voucher_guid) as voucher_count
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
          AND v.company_guid = l.company_guid
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
          AND v.date >= ?
          AND v.date <= ?
        WHERE l.company_guid = ?
          AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        ORDER BY closing_balance DESC
      ''';
      params = [
        widget.companyGuid,
        widget.companyGuid,
        widget.fromDate,
        widget.toDate,
        widget.companyGuid,
      ];
    } else {
      // For Direct/Indirect Expenses and Incomes
      query = '''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name
          FROM groups
          WHERE company_guid = ?
            AND name = ?
            AND is_deleted = 0
          
          UNION ALL
          
          SELECT g.group_guid, g.name
          FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ?
            AND g.is_deleted = 0
        )
        SELECT 
          l.name as ledger_name,
          l.opening_balance,
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
          (l.opening_balance + 
           COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
           COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance,
          COUNT(DISTINCT v.voucher_guid) as voucher_count
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
          AND v.company_guid = l.company_guid
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
          AND v.date >= ?
          AND v.date <= ?
        WHERE l.company_guid = ?
          AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        ORDER BY closing_balance DESC
      ''';
      params = [
        widget.companyGuid,
        widget.groupName,
        widget.companyGuid,
        widget.fromDate,
        widget.toDate,
        widget.companyGuid,
      ];
    }

    final result = await db.rawQuery(query, params);

    setState(() {
      _ledgers = result;
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
            Text(widget.groupName, style: TextStyle(fontSize: 18)),
            Text(
              '${_formatDate(widget.fromDate)} to ${_formatDate(widget.toDate)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadLedgers,
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
                  child: Text(
                    widget.companyName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Table Header
                Container(
                  color: Colors.grey[200],
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Ledger Name',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Opening',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Debit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Credit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Closing',
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
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _ledgers.length,
                          separatorBuilder: (context, index) => Divider(height: 1),
                          itemBuilder: (context, index) {
                            final ledger = _ledgers[index];
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LedgerDetailScreen(
                                      companyGuid: widget.companyGuid,
                                      companyName: widget.companyName,
                                      ledgerName: ledger['ledger_name'] as String,
                                      fromDate: widget.fromDate,
                                      toDate: widget.toDate,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ledger['ledger_name'] as String,
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 20,
                                            color: Colors.grey[600],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatAmount(
                                          (ledger['opening_balance'] as num?)
                                                  ?.toDouble() ??
                                              0.0,
                                        ),
                                        style: TextStyle(fontSize: 13),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatAmount(
                                          (ledger['debit_total'] as num?)
                                                  ?.toDouble() ??
                                              0.0,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.red[700],
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatAmount(
                                          (ledger['credit_total'] as num?)
                                                  ?.toDouble() ??
                                              0.0,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green[700],
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatAmount(
                                          (ledger['closing_balance'] as num?)
                                                  ?.toDouble() ??
                                              0.0,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
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
                        flex: 3,
                        child: Text(
                          'Total (${_ledgers.length} ledgers)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatAmount(_calculateTotal('opening_balance')),
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatAmount(_calculateTotal('debit_total')),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatAmount(_calculateTotal('credit_total')),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatAmount(_calculateTotal('closing_balance')),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
    return _ledgers.fold(
      0.0,
      (sum, ledger) => sum + ((ledger[field] as num?)?.toDouble() ?? 0.0),
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