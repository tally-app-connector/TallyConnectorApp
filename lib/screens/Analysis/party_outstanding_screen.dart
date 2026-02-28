// screens/Analysis/party_outstanding_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'ledger_detail_screen.dart';

class PartyOutstandingScreen extends StatefulWidget {
  @override
  _PartyOutstandingScreenState createState() => _PartyOutstandingScreenState();
}

class _PartyOutstandingScreenState extends State<PartyOutstandingScreen> {
  final _db = DatabaseHelper.instance;
  
  String? _companyGuid;
  String? _companyName;
  bool _loading = true;
  
  List<Map<String, dynamic>> _receivableGroups = [];
  List<Map<String, dynamic>> _payableGroups = [];
  int _selectedTab = 0;
  
  String _fromDate = '20250401';
  String _toDate = '20250531';
  
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
    // _fromDate = company['starting_from'] as String? ?? '20230401';
    // _toDate = company['ending_at'] as String? ?? '20260331';
    
    await _fetchGroupWiseOutstandings();
    
    setState(() => _loading = false);
  }
  
  Future<void> _fetchGroupWiseOutstandings() async {
    final db = await _db.database;
    
    print('Date Filter - From: $_fromDate, To: $_toDate');
    
    // Get Sundry Debtors (Receivables)
    final receivablesResult = await db.rawQuery('''
  WITH RECURSIVE group_tree AS (
    SELECT group_guid, name
    FROM groups
    WHERE company_guid = ?
      AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
      AND is_deleted = 0
    
    UNION ALL
    
    SELECT g.group_guid, g.name
    FROM groups g
    INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
    WHERE g.company_guid = ?
      AND g.is_deleted = 0
  ),
  base_data AS (
    SELECT 
      l.name as party_name,
      l.parent as group_name,
      l.opening_balance as ledger_opening_balance,
      -- Debits before start date
      COALESCE(SUM(CASE 
        WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) 
        ELSE 0 
      END), 0) as debit_before,
      -- Credits before start date
      COALESCE(SUM(CASE 
        WHEN v.date < ? AND vle.amount > 0 THEN vle.amount 
        ELSE 0 
      END), 0) as credit_before,
      -- Debits in period
      COALESCE(SUM(CASE 
        WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) 
        ELSE 0 
      END), 0) as debit_total,
      -- Credits in period
      COALESCE(SUM(CASE 
        WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount 
        ELSE 0 
      END), 0) as credit_total,
      COUNT(DISTINCT CASE 
        WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid 
        ELSE NULL 
      END) as transaction_count
    FROM ledgers l
    INNER JOIN group_tree gt ON l.parent = gt.name
    LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0
      AND v.is_cancelled = 0
      AND v.is_optional = 0
    WHERE l.company_guid = ?
      AND l.is_deleted = 0
    GROUP BY l.name, l.parent, l.opening_balance
  )
  SELECT 
    party_name,
    group_name,
    ledger_opening_balance,
    debit_before,
    credit_before,
    ((ledger_opening_balance * -1) + debit_before - credit_before) as opening_balance,
    debit_total,
    credit_total,
    ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) as outstanding,
    transaction_count,
    SUM((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) OVER () as total_receivables
  FROM base_data
  WHERE ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) > 0.01
  ORDER BY outstanding DESC
''', [
  _companyGuid, 
  _companyGuid,
  _fromDate,      // debit_before
  _fromDate,      // credit_before
  _fromDate,      // debit_total start
  _toDate,        // debit_total end
  _fromDate,      // credit_total start
  _toDate,        // credit_total end
  _fromDate,      // transaction_count start
  _toDate,        // transaction_count end
  _companyGuid
]);
    
    // Get Sundry Creditors (Payables)
    final advancedReceived = await db.rawQuery('''
  WITH RECURSIVE group_tree AS (
    SELECT group_guid, name
    FROM groups
    WHERE company_guid = ?
      AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
      AND is_deleted = 0
    
    UNION ALL
    
    SELECT g.group_guid, g.name
    FROM groups g
    INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
    WHERE g.company_guid = ?
      AND g.is_deleted = 0
  ),
  base_data AS (
    SELECT 
      l.name as party_name,
      l.parent as group_name,
      l.opening_balance as ledger_opening_balance,
      -- Credits before start date
      COALESCE(SUM(CASE 
        WHEN v.date < ? AND vle.amount > 0 THEN vle.amount 
        ELSE 0 
      END), 0) as credit_before,
      -- Debits before start date
      COALESCE(SUM(CASE 
        WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) 
        ELSE 0 
      END), 0) as debit_before,
      -- Credits in period
      COALESCE(SUM(CASE 
        WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount 
        ELSE 0 
      END), 0) as credit_total,
      -- Debits in period
      COALESCE(SUM(CASE 
        WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) 
        ELSE 0 
      END), 0) as debit_total,
      COUNT(DISTINCT CASE 
        WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid 
        ELSE NULL 
      END) as transaction_count
    FROM ledgers l
    RIGHT JOIN group_tree gt ON l.parent = gt.name
    LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0
      AND v.is_cancelled = 0
      AND v.is_optional = 0
    WHERE l.company_guid = ?
      AND l.is_deleted = 0
    GROUP BY l.name, l.parent, l.opening_balance
  )
  SELECT 
    party_name,
    group_name,
    ledger_opening_balance,
    credit_before,
    debit_before,
    (ledger_opening_balance + credit_before - debit_before) as opening_balance,
    credit_total,
    debit_total,
    (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding,
    transaction_count,
    SUM(ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) OVER () as total_advanced_received
  FROM base_data
  WHERE (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
  ORDER BY outstanding DESC
''', [
  _companyGuid, 
  _companyGuid,
  _fromDate,      // credit_before
  _fromDate,      // debit_before
  _fromDate,      // credit_total start
  _toDate,        // credit_total end
  _fromDate,      // debit_total start
  _toDate,        // debit_total end
  _fromDate,      // transaction_count start
  _toDate,        // transaction_count end
  _companyGuid
]);

final advancedPayed = await db.rawQuery('''
  WITH RECURSIVE group_tree AS (
    SELECT group_guid, name
    FROM groups
    WHERE company_guid = ?
      AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
      AND is_deleted = 0
    
    UNION ALL
    
    SELECT g.group_guid, g.name
    FROM groups g
    INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
    WHERE g.company_guid = ?
      AND g.is_deleted = 0
  ),
  base_data AS (
    SELECT 
      l.name as party_name,
      l.parent as group_name,
      l.opening_balance as ledger_opening_balance,
      -- Debits before start date
      COALESCE(SUM(CASE 
        WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) 
        ELSE 0 
      END), 0) as debit_before,
      -- Credits before start date
      COALESCE(SUM(CASE 
        WHEN v.date < ? AND vle.amount > 0 THEN vle.amount 
        ELSE 0 
      END), 0) as credit_before,
      -- Debits in period
      COALESCE(SUM(CASE 
        WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) 
        ELSE 0 
      END), 0) as debit_total,
      -- Credits in period
      COALESCE(SUM(CASE 
        WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount 
        ELSE 0 
      END), 0) as credit_total,
      COUNT(DISTINCT CASE 
        WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid 
        ELSE NULL 
      END) as transaction_count
    FROM ledgers l
    RIGHT JOIN group_tree gt ON l.parent = gt.name
    LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0
      AND v.is_cancelled = 0
      AND v.is_optional = 0
    WHERE l.company_guid = ?
      AND l.is_deleted = 0
    GROUP BY l.name, l.parent, l.opening_balance
  )
  SELECT 
    party_name,
    group_name,
    ledger_opening_balance,
    debit_before,
    credit_before,
    (ledger_opening_balance - debit_before + credit_before) as opening_balance,
    debit_total,
    credit_total,
    (ledger_opening_balance - debit_before + credit_before - debit_total + credit_total) as outstanding,
    transaction_count,
    SUM(ledger_opening_balance - debit_before + credit_before - debit_total + credit_total) OVER () as total_advanced_payed
  FROM base_data
  WHERE (ledger_opening_balance - debit_before + credit_before - debit_total + credit_total) < -0.01
  ORDER BY outstanding ASC
''', [
  _companyGuid, 
  _companyGuid,
  _fromDate,      // debit_before
  _fromDate,      // credit_before
  _fromDate,      // debit_total start
  _toDate,        // debit_total end
  _fromDate,      // credit_total start
  _toDate,        // credit_total end
  _fromDate,      // transaction_count start
  _toDate,        // transaction_count end
  _companyGuid
]);

final payablesResult = await db.rawQuery('''
  WITH RECURSIVE group_tree AS (
    SELECT group_guid, name
    FROM groups
    WHERE company_guid = ?
      AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
      AND is_deleted = 0
    
    UNION ALL
    
    SELECT g.group_guid, g.name
    FROM groups g
    INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
    WHERE g.company_guid = ?
      AND g.is_deleted = 0
  ),
  base_data AS (
    SELECT 
      l.name as party_name,
      l.parent as group_name,
      l.opening_balance as ledger_opening_balance,
      -- Credits before start date
      COALESCE(SUM(CASE 
        WHEN v.date < ? AND vle.amount > 0 THEN vle.amount 
        ELSE 0 
      END), 0) as credit_before,
      -- Debits before start date
      COALESCE(SUM(CASE 
        WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) 
        ELSE 0 
      END), 0) as debit_before,
      -- Credits in period
      COALESCE(SUM(CASE 
        WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount 
        ELSE 0 
      END), 0) as credit_total,
      -- Debits in period
      COALESCE(SUM(CASE 
        WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) 
        ELSE 0 
      END), 0) as debit_total,
      COUNT(DISTINCT CASE 
        WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid 
        ELSE NULL 
      END) as transaction_count
    FROM ledgers l
    INNER JOIN group_tree gt ON l.parent = gt.name
    LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0
      AND v.is_cancelled = 0
      AND v.is_optional = 0
    WHERE l.company_guid = ?
      AND l.is_deleted = 0
    GROUP BY l.name, l.parent, l.opening_balance
  )
  SELECT 
    party_name,
    group_name,
    ledger_opening_balance,
    credit_before,
    debit_before,
    (ledger_opening_balance + credit_before - debit_before) as opening_balance,
    credit_total,
    debit_total,
    (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding,
    transaction_count,
    SUM(ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) OVER () as total_payables
  FROM base_data
  WHERE (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
  ORDER BY outstanding DESC
''', [
  _companyGuid, 
  _companyGuid,
  _fromDate,      // credit_before
  _fromDate,      // debit_before
  _fromDate,      // credit_total start
  _toDate,        // credit_total end
  _fromDate,      // debit_total start
  _toDate,        // debit_total end
  _fromDate,      // transaction_count start
  _toDate,        // transaction_count end
  _companyGuid
]);

    _receivableGroups = receivablesResult;
    _payableGroups = payablesResult;
  
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Party Outstanding'),
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
                  child: Text(
                    _companyName ?? '',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.green[50],
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'Receivables',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _formatAmount(_calculateTotal(_receivableGroups, 'outstanding')),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${_receivableGroups.length} ${_receivableGroups.length != 1 ? 'parties' : 'party'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          color: Colors.red[50],
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'Payables',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _formatAmount(_calculateTotal(_payableGroups, 'outstanding')),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${_payableGroups.length} ${_payableGroups.length != 1 ? 'parties' : 'party'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 0
                                      ? Colors.green
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              'Receivables',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: _selectedTab == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedTab == 0
                                    ? Colors.green[700]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 1
                                      ? Colors.red
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              'Payables',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: _selectedTab == 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedTab == 1
                                    ? Colors.red[700]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
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
                        child: Text(
                          'opening',
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
                  child: _buildGroupList(),
                ),
              ],
            ),
    );
  }
  
  Widget _buildGroupList() {
    final parties = _selectedTab == 0 ? _receivableGroups : _payableGroups;
    final color = _selectedTab == 0 ? Colors.green[700] : Colors.red[700];
    
    if (parties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No outstanding ${_selectedTab == 0 ? 'receivables' : 'payables'}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      itemCount: parties.length,
      separatorBuilder: (context, index) => Divider(height: 1),
      itemBuilder: (context, index) {
        final party = parties[index];
        final outstanding = (party['outstanding'] as num?)?.toDouble() ?? 0.0;
        final opening = (party['opening_balance'] as num?)?.toDouble() ?? 0.0;
        final partyName = party['party_name'] as String;
        final groupName = party['group_name'] as String? ?? '';
        final txnCount = party['transaction_count'] as int? ?? 0;
        
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LedgerDetailScreen(
                  companyGuid: _companyGuid!,
                  companyName: _companyName!,
                  ledgerName: partyName,
                  fromDate: _fromDate,
                  toDate: _toDate,
                ),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            color: index.isEven ? Colors.white : Colors.grey[50],
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              partyName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                      if (groupName.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            groupName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    _formatAmount(opening),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatAmount(outstanding),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  double _calculateTotal(List<Map<String, dynamic>> groups, String field) {
    return groups.fold(
      0.0,
      (sum, group) => sum + ((group[field] as num?)?.toDouble() ?? 0.0),
    );
  }
  
  String _formatAmount(double amount) {
    return '₹' + amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}