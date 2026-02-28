// screens/Analysis/ledger_reports_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'ledger_detail_screen.dart';

class LedgerReportsScreen extends StatefulWidget {
  @override
  _LedgerReportsScreenState createState() => _LedgerReportsScreenState();
}

class _LedgerReportsScreenState extends State<LedgerReportsScreen> {
  final _db = DatabaseHelper.instance;
  
  String? _companyGuid;
  String? _companyName;
  String? _fromDate;
  String? _toDate;
  bool _loading = true;
  
  List<Map<String, dynamic>> _ledgers = [];
  String _searchQuery = '';
  String? _selectedGroup;
  List<String> _groups = [];
  
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
    
    await _fetchLedgers();
    await _fetchGroups();
    
    setState(() => _loading = false);
  }
  
  Future<void> _fetchLedgers() async {
    final db = await _db.database;
    
    String whereClause = 'l.company_guid = ? AND l.is_deleted = 0';
    List<dynamic> params = [_companyGuid];
    
    if (_selectedGroup != null) {
      whereClause += ' AND l.parent = ?';
      params.add(_selectedGroup);
    }
    
    if (_searchQuery.isNotEmpty) {
      whereClause += ' AND l.name LIKE ?';
      params.add('%$_searchQuery%');
    }
    
    final result = await db.rawQuery('''
      SELECT 
        l.name as ledger_name,
        l.parent as group_name,
        l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
        (l.opening_balance + 
         COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance,
        COUNT(DISTINCT v.voucher_guid) as voucher_count
      FROM ledgers l
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
        AND v.company_guid = l.company_guid
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
      WHERE $whereClause
      GROUP BY l.name, l.parent, l.opening_balance
      ORDER BY l.name
    ''', [_fromDate, _toDate, ...params]);
    
    setState(() {
      _ledgers = result;
    });
  }
  
  Future<void> _fetchGroups() async {
    final db = await _db.database;
    
    final result = await db.rawQuery('''
      SELECT DISTINCT parent as group_name
      FROM ledgers
      WHERE company_guid = ?
        AND is_deleted = 0
        AND parent IS NOT NULL
      ORDER BY parent
    ''', [_companyGuid]);
    
    setState(() {
      _groups = result.map((r) => r['group_name'] as String).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Ledger Reports'),
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
                        '${_formatDate(_fromDate ?? '')} to ${_formatDate(_toDate ?? '')}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                
                // Filters
                Container(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search ledgers...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _fetchLedgers();
                        },
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Group Filter
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text('Filter by Group'),
                            value: _selectedGroup,
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text('All Groups'),
                              ),
                              ..._groups.map((group) {
                                return DropdownMenuItem(
                                  value: group,
                                  child: Text(group),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedGroup = value);
                              _fetchLedgers();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Results Count
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_ledgers.length} Ledger${_ledgers.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (_selectedGroup != null || _searchQuery.isNotEmpty)
                        TextButton.icon(
                          icon: Icon(Icons.clear, size: 16),
                          label: Text('Clear Filters'),
                          onPressed: () {
                            setState(() {
                              _selectedGroup = null;
                              _searchQuery = '';
                            });
                            _fetchLedgers();
                          },
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
                        flex: 3,
                        child: Text(
                          'Ledger Name',
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
                        child: Text(
                          'Entries',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No ledgers found',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _ledgers.length,
                          separatorBuilder: (context, index) => Divider(height: 1),
                          itemBuilder: (context, index) {
                            final ledger = _ledgers[index];
                            final closing = (ledger['closing_balance'] as num?)?.toDouble() ?? 0.0;
                            final voucherCount = ledger['voucher_count'] as int? ?? 0;
                            
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LedgerDetailScreen(
                                      companyGuid: _companyGuid!,
                                      companyName: _companyName!,
                                      ledgerName: ledger['ledger_name'] as String,
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
                                              ledger['ledger_name'] as String,
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
                                      flex: 2,
                                      child: Text(
                                        ledger['group_name'] as String? ?? '-',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
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
                                          '$voucherCount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatAmount(closing),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: closing >= 0
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
              ],
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
    return '${isNegative ? '-' : ''}₹$formatted';
  }
  
  String _formatDate(String tallyDate) {
    if (tallyDate.length != 8) return tallyDate;
    final year = tallyDate.substring(0, 4);
    final month = tallyDate.substring(4, 6);
    final day = tallyDate.substring(6, 8);
    return '$day-$month-$year';
  }
}