// // screens/Analysis/party_outstanding_screen.dart

// import 'package:flutter/material.dart';
// import '../../database/database_helper.dart';
// import 'ledger_detail_screen.dart';

// class PartyOutstandingScreen extends StatefulWidget {
//   @override
//   _PartyOutstandingScreenState createState() => _PartyOutstandingScreenState();
// }

// class _PartyOutstandingScreenState extends State<PartyOutstandingScreen> {
//   final _db = DatabaseHelper.instance;
  
//   String? _companyGuid;
//   String? _companyName;
//   bool _loading = true;
  
//   List<Map<String, dynamic>> _receivableGroups = [];
//   List<Map<String, dynamic>> _payableGroups = [];
//   int _selectedTab = 0;
  
//   String _fromDate = '20250401';
//   String _toDate = '20250531';
  
//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }
  
//   Future<void> _loadData() async {
//     setState(() => _loading = true);
    
//     final company = await _db.getSelectedCompanyByGuid();
//     if (company == null) {
//       setState(() => _loading = false);
//       return;
//     }
    
//     _companyGuid = company['company_guid'] as String;
//     _companyName = company['company_name'] as String;
//     // _fromDate = company['starting_from'] as String? ?? '20230401';
//     // _toDate = company['ending_at'] as String? ?? '20260331';
    
//     await _fetchGroupWiseOutstandings();
    
//     setState(() => _loading = false);
//   }
  
//   Future<void> _fetchGroupWiseOutstandings() async {
//     final db = await _db.database;
    
//     print('Date Filter - From: $_fromDate, To: $_toDate');
    
//     // Get Sundry Debtors (Receivables)
//     final receivablesResult = await db.rawQuery('''
//   WITH RECURSIVE group_tree AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   ),
//   base_data AS (
//     SELECT 
//       l.name as party_name,
//       l.parent as group_name,
//       l.opening_balance as ledger_opening_balance,
//       -- Debits before start date
//       COALESCE(SUM(CASE 
//         WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) 
//         ELSE 0 
//       END), 0) as debit_before,
//       -- Credits before start date
//       COALESCE(SUM(CASE 
//         WHEN v.date < ? AND vle.amount > 0 THEN vle.amount 
//         ELSE 0 
//       END), 0) as credit_before,
//       -- Debits in period
//       COALESCE(SUM(CASE 
//         WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) 
//         ELSE 0 
//       END), 0) as debit_total,
//       -- Credits in period
//       COALESCE(SUM(CASE 
//         WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount 
//         ELSE 0 
//       END), 0) as credit_total,
//       COUNT(DISTINCT CASE 
//         WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid 
//         ELSE NULL 
//       END) as transaction_count
//     FROM ledgers l
//     INNER JOIN group_tree gt ON l.parent = gt.name
//     LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//     LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       AND v.company_guid = l.company_guid
//       AND v.is_deleted = 0
//       AND v.is_cancelled = 0
//       AND v.is_optional = 0
//     WHERE l.company_guid = ?
//       AND l.is_deleted = 0
//     GROUP BY l.name, l.parent, l.opening_balance
//   )
//   SELECT 
//     party_name,
//     group_name,
//     ledger_opening_balance,
//     debit_before,
//     credit_before,
//     ((ledger_opening_balance * -1) + debit_before - credit_before) as opening_balance,
//     debit_total,
//     credit_total,
//     ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) as outstanding,
//     transaction_count,
//     SUM((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) OVER () as total_receivables
//   FROM base_data
//   WHERE ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) > 0.01
//   ORDER BY outstanding DESC
// ''', [
//   _companyGuid, 
//   _companyGuid,
//   _fromDate,      // debit_before
//   _fromDate,      // credit_before
//   _fromDate,      // debit_total start
//   _toDate,        // debit_total end
//   _fromDate,      // credit_total start
//   _toDate,        // credit_total end
//   _fromDate,      // transaction_count start
//   _toDate,        // transaction_count end
//   _companyGuid
// ]);
    
//     // Get Sundry Creditors (Payables)
//     final advancedReceived = await db.rawQuery('''
//   WITH RECURSIVE group_tree AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   ),
//   base_data AS (
//     SELECT 
//       l.name as party_name,
//       l.parent as group_name,
//       l.opening_balance as ledger_opening_balance,
//       -- Credits before start date
//       COALESCE(SUM(CASE 
//         WHEN v.date < ? AND vle.amount > 0 THEN vle.amount 
//         ELSE 0 
//       END), 0) as credit_before,
//       -- Debits before start date
//       COALESCE(SUM(CASE 
//         WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) 
//         ELSE 0 
//       END), 0) as debit_before,
//       -- Credits in period
//       COALESCE(SUM(CASE 
//         WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount 
//         ELSE 0 
//       END), 0) as credit_total,
//       -- Debits in period
//       COALESCE(SUM(CASE 
//         WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) 
//         ELSE 0 
//       END), 0) as debit_total,
//       COUNT(DISTINCT CASE 
//         WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid 
//         ELSE NULL 
//       END) as transaction_count
//     FROM ledgers l
//     RIGHT JOIN group_tree gt ON l.parent = gt.name
//     LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//     LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       AND v.company_guid = l.company_guid
//       AND v.is_deleted = 0
//       AND v.is_cancelled = 0
//       AND v.is_optional = 0
//     WHERE l.company_guid = ?
//       AND l.is_deleted = 0
//     GROUP BY l.name, l.parent, l.opening_balance
//   )
//   SELECT 
//     party_name,
//     group_name,
//     ledger_opening_balance,
//     credit_before,
//     debit_before,
//     (ledger_opening_balance + credit_before - debit_before) as opening_balance,
//     credit_total,
//     debit_total,
//     (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding,
//     transaction_count,
//     SUM(ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) OVER () as total_advanced_received
//   FROM base_data
//   WHERE (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
//   ORDER BY outstanding DESC
// ''', [
//   _companyGuid, 
//   _companyGuid,
//   _fromDate,      // credit_before
//   _fromDate,      // debit_before
//   _fromDate,      // credit_total start
//   _toDate,        // credit_total end
//   _fromDate,      // debit_total start
//   _toDate,        // debit_total end
//   _fromDate,      // transaction_count start
//   _toDate,        // transaction_count end
//   _companyGuid
// ]);

// final advancedPayed = await db.rawQuery('''
//   WITH RECURSIVE group_tree AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   ),
//   base_data AS (
//     SELECT 
//       l.name as party_name,
//       l.parent as group_name,
//       l.opening_balance as ledger_opening_balance,
//       -- Debits before start date
//       COALESCE(SUM(CASE 
//         WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) 
//         ELSE 0 
//       END), 0) as debit_before,
//       -- Credits before start date
//       COALESCE(SUM(CASE 
//         WHEN v.date < ? AND vle.amount > 0 THEN vle.amount 
//         ELSE 0 
//       END), 0) as credit_before,
//       -- Debits in period
//       COALESCE(SUM(CASE 
//         WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) 
//         ELSE 0 
//       END), 0) as debit_total,
//       -- Credits in period
//       COALESCE(SUM(CASE 
//         WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount 
//         ELSE 0 
//       END), 0) as credit_total,
//       COUNT(DISTINCT CASE 
//         WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid 
//         ELSE NULL 
//       END) as transaction_count
//     FROM ledgers l
//     RIGHT JOIN group_tree gt ON l.parent = gt.name
//     LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//     LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       AND v.company_guid = l.company_guid
//       AND v.is_deleted = 0
//       AND v.is_cancelled = 0
//       AND v.is_optional = 0
//     WHERE l.company_guid = ?
//       AND l.is_deleted = 0
//     GROUP BY l.name, l.parent, l.opening_balance
//   )
//   SELECT 
//     party_name,
//     group_name,
//     ledger_opening_balance,
//     debit_before,
//     credit_before,
//     (ledger_opening_balance - debit_before + credit_before) as opening_balance,
//     debit_total,
//     credit_total,
//     (ledger_opening_balance - debit_before + credit_before - debit_total + credit_total) as outstanding,
//     transaction_count,
//     SUM(ledger_opening_balance - debit_before + credit_before - debit_total + credit_total) OVER () as total_advanced_payed
//   FROM base_data
//   WHERE (ledger_opening_balance - debit_before + credit_before - debit_total + credit_total) < -0.01
//   ORDER BY outstanding ASC
// ''', [
//   _companyGuid, 
//   _companyGuid,
//   _fromDate,      // debit_before
//   _fromDate,      // credit_before
//   _fromDate,      // debit_total start
//   _toDate,        // debit_total end
//   _fromDate,      // credit_total start
//   _toDate,        // credit_total end
//   _fromDate,      // transaction_count start
//   _toDate,        // transaction_count end
//   _companyGuid
// ]);

// final payablesResult = await db.rawQuery('''
//   WITH RECURSIVE group_tree AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   ),
//   base_data AS (
//     SELECT 
//       l.name as party_name,
//       l.parent as group_name,
//       l.opening_balance as ledger_opening_balance,
//       -- Credits before start date
//       COALESCE(SUM(CASE 
//         WHEN v.date < ? AND vle.amount > 0 THEN vle.amount 
//         ELSE 0 
//       END), 0) as credit_before,
//       -- Debits before start date
//       COALESCE(SUM(CASE 
//         WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) 
//         ELSE 0 
//       END), 0) as debit_before,
//       -- Credits in period
//       COALESCE(SUM(CASE 
//         WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount 
//         ELSE 0 
//       END), 0) as credit_total,
//       -- Debits in period
//       COALESCE(SUM(CASE 
//         WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) 
//         ELSE 0 
//       END), 0) as debit_total,
//       COUNT(DISTINCT CASE 
//         WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid 
//         ELSE NULL 
//       END) as transaction_count
//     FROM ledgers l
//     INNER JOIN group_tree gt ON l.parent = gt.name
//     LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//     LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       AND v.company_guid = l.company_guid
//       AND v.is_deleted = 0
//       AND v.is_cancelled = 0
//       AND v.is_optional = 0
//     WHERE l.company_guid = ?
//       AND l.is_deleted = 0
//     GROUP BY l.name, l.parent, l.opening_balance
//   )
//   SELECT 
//     party_name,
//     group_name,
//     ledger_opening_balance,
//     credit_before,
//     debit_before,
//     (ledger_opening_balance + credit_before - debit_before) as opening_balance,
//     credit_total,
//     debit_total,
//     (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding,
//     transaction_count,
//     SUM(ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) OVER () as total_payables
//   FROM base_data
//   WHERE (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
//   ORDER BY outstanding DESC
// ''', [
//   _companyGuid, 
//   _companyGuid,
//   _fromDate,      // credit_before
//   _fromDate,      // debit_before
//   _fromDate,      // credit_total start
//   _toDate,        // credit_total end
//   _fromDate,      // debit_total start
//   _toDate,        // debit_total end
//   _fromDate,      // transaction_count start
//   _toDate,        // transaction_count end
//   _companyGuid
// ]);

//     _receivableGroups = receivablesResult;
//     _payableGroups = payablesResult;
  
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Text('Party Outstanding'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadData,
//           ),
//         ],
//       ),
//       body: _loading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 Container(
//                   width: double.infinity,
//                   color: Colors.blue[50],
//                   padding: EdgeInsets.all(16),
//                   child: Text(
//                     _companyName ?? '',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
                
//                 Container(
//                   padding: EdgeInsets.all(16),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Card(
//                           color: Colors.green[50],
//                           child: Padding(
//                             padding: EdgeInsets.all(16),
//                             child: Column(
//                               children: [
//                                 Text(
//                                   'Receivables',
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     color: Colors.grey[700],
//                                   ),
//                                 ),
//                                 SizedBox(height: 8),
//                                 Text(
//                                   _formatAmount(_calculateTotal(_receivableGroups, 'outstanding')),
//                                   style: TextStyle(
//                                     fontSize: 20,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.green[700],
//                                   ),
//                                 ),
//                                 SizedBox(height: 4),
//                                 Text(
//                                   '${_receivableGroups.length} ${_receivableGroups.length != 1 ? 'parties' : 'party'}',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey[600],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(width: 12),
//                       Expanded(
//                         child: Card(
//                           color: Colors.red[50],
//                           child: Padding(
//                             padding: EdgeInsets.all(16),
//                             child: Column(
//                               children: [
//                                 Text(
//                                   'Payables',
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     color: Colors.grey[700],
//                                   ),
//                                 ),
//                                 SizedBox(height: 8),
//                                 Text(
//                                   _formatAmount(_calculateTotal(_payableGroups, 'outstanding')),
//                                   style: TextStyle(
//                                     fontSize: 20,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.red[700],
//                                   ),
//                                 ),
//                                 SizedBox(height: 4),
//                                 Text(
//                                   '${_payableGroups.length} ${_payableGroups.length != 1 ? 'parties' : 'party'}',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey[600],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     border: Border(
//                       bottom: BorderSide(color: Colors.grey[300]!),
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: InkWell(
//                           onTap: () => setState(() => _selectedTab = 0),
//                           child: Container(
//                             padding: EdgeInsets.symmetric(vertical: 16),
//                             decoration: BoxDecoration(
//                               border: Border(
//                                 bottom: BorderSide(
//                                   color: _selectedTab == 0
//                                       ? Colors.green
//                                       : Colors.transparent,
//                                   width: 3,
//                                 ),
//                               ),
//                             ),
//                             child: Text(
//                               'Receivables',
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontWeight: _selectedTab == 0
//                                     ? FontWeight.bold
//                                     : FontWeight.normal,
//                                 color: _selectedTab == 0
//                                     ? Colors.green[700]
//                                     : Colors.grey[700],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: InkWell(
//                           onTap: () => setState(() => _selectedTab = 1),
//                           child: Container(
//                             padding: EdgeInsets.symmetric(vertical: 16),
//                             decoration: BoxDecoration(
//                               border: Border(
//                                 bottom: BorderSide(
//                                   color: _selectedTab == 1
//                                       ? Colors.red
//                                       : Colors.transparent,
//                                   width: 3,
//                                 ),
//                               ),
//                             ),
//                             child: Text(
//                               'Payables',
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontWeight: _selectedTab == 1
//                                     ? FontWeight.bold
//                                     : FontWeight.normal,
//                                 color: _selectedTab == 1
//                                     ? Colors.red[700]
//                                     : Colors.grey[700],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 Container(
//                   color: Colors.grey[200],
//                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         flex: 3,
//                         child: Text(
//                           'Party Name',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                       ),
//                       Expanded(
//                         child: Text(
//                           'Txns',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                       Expanded(
//                         child: Text(
//                           'opening',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Outstanding',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 Expanded(
//                   child: _buildGroupList(),
//                 ),
//               ],
//             ),
//     );
//   }
  
//   Widget _buildGroupList() {
//     final parties = _selectedTab == 0 ? _receivableGroups : _payableGroups;
//     final color = _selectedTab == 0 ? Colors.green[700] : Colors.red[700];
    
//     if (parties.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.people_outline,
//               size: 64,
//               color: Colors.grey[400],
//             ),
//             SizedBox(height: 16),
//             Text(
//               'No outstanding ${_selectedTab == 0 ? 'receivables' : 'payables'}',
//               style: TextStyle(
//                 color: Colors.grey[600],
//                 fontSize: 16,
//               ),
//             ),
//           ],
//         ),
//       );
//     }
    
//     return ListView.separated(
//       itemCount: parties.length,
//       separatorBuilder: (context, index) => Divider(height: 1),
//       itemBuilder: (context, index) {
//         final party = parties[index];
//         final outstanding = (party['outstanding'] as num?)?.toDouble() ?? 0.0;
//         final opening = (party['opening_balance'] as num?)?.toDouble() ?? 0.0;
//         final partyName = party['party_name'] as String;
//         final groupName = party['group_name'] as String? ?? '';
//         final txnCount = party['transaction_count'] as int? ?? 0;
        
//         return InkWell(
//           onTap: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => LedgerDetailScreen(
//                   companyGuid: _companyGuid!,
//                   companyName: _companyName!,
//                   ledgerName: partyName,
//                   fromDate: _fromDate,
//                   toDate: _toDate,
//                 ),
//               ),
//             );
//           },
//           child: Container(
//             padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//             color: index.isEven ? Colors.white : Colors.grey[50],
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 3,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               partyName,
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                           Icon(
//                             Icons.chevron_right,
//                             size: 18,
//                             color: Colors.grey[600],
//                           ),
//                         ],
//                       ),
//                       if (groupName.isNotEmpty)
//                         Padding(
//                           padding: EdgeInsets.only(top: 4),
//                           child: Text(
//                             groupName,
//                             style: TextStyle(
//                               fontSize: 11,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 Expanded(
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.blue[100],
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       '$txnCount',
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.blue[700],
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 Expanded(
//                   flex: 2,
//                   child: Text(
//                     _formatAmount(opening),
//                     style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.bold,
//                       color: color,
//                     ),
//                     textAlign: TextAlign.right,
//                   ),
//                 ),
//                 Expanded(
//                   flex: 2,
//                   child: Text(
//                     _formatAmount(outstanding),
//                     style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.bold,
//                       color: color,
//                     ),
//                     textAlign: TextAlign.right,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
  
//   double _calculateTotal(List<Map<String, dynamic>> groups, String field) {
//     return groups.fold(
//       0.0,
//       (sum, group) => sum + ((group[field] as num?)?.toDouble() ?? 0.0),
//     );
//   }
  
//   String _formatAmount(double amount) {
//     return '₹' + amount.toStringAsFixed(2).replaceAllMapped(
//       RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
//       (Match m) => '${m[1]},',
//     );
//   }
// }

// screens/Analysis/party_outstanding_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'ledger_detail_screen.dart';

class PartyOutstandingScreen extends StatefulWidget {
  @override
  _PartyOutstandingScreenState createState() =>
      _PartyOutstandingScreenState();
}

class _PartyOutstandingScreenState extends State<PartyOutstandingScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  String? _companyGuid;
  String? _companyName;
  bool _loading = true;

  List<Map<String, dynamic>> _receivableGroups = [];
  List<Map<String, dynamic>> _payableGroups    = [];
  int _selectedTab = 0;

  String _fromDate = '20250401';
  String _toDate   = '20250531';

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF1A6FD8);
  static const Color _accent     = Color(0xFF00C9A7);
  static const Color _bg         = Color(0xFFF4F6FB);
  static const Color _cardBg     = Colors.white;
  static const Color _textDark   = Color(0xFF1A2340);
  static const Color _textMuted  = Color(0xFF8A94A6);
  static const Color _positiveC  = Color(0xFF1B8A5A);
  static const Color _positiveBg = Color(0xFFE8F5EE);
  static const Color _negativeC  = Color(0xFFD32F2F);
  static const Color _negativeBg = Color(0xFFFFEBEB);
  static const Color _tableBg    = Color(0xFFF0F3FA);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data (all SQL unchanged) ───────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final company = await _db.getSelectedCompanyByGuid();
    if (company == null) {
      setState(() => _loading = false);
      return;
    }

    _companyGuid = company['company_guid'] as String;
    _companyName = company['company_name'] as String;

    await _fetchGroupWiseOutstandings();

    setState(() => _loading = false);
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _fetchGroupWiseOutstandings() async {
    final db = await _db.database;

    // ── Receivables ───────────────────────────────────────────────────────────
    final receivablesResult = await db.rawQuery('''
  WITH RECURSIVE group_tree AS (
    SELECT group_guid, name FROM groups
    WHERE company_guid = ?
      AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
      AND is_deleted = 0
    UNION ALL
    SELECT g.group_guid, g.name FROM groups g
    INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
    WHERE g.company_guid = ? AND g.is_deleted = 0
  ),
  base_data AS (
    SELECT l.name as party_name, l.parent as group_name,
      l.opening_balance as ledger_opening_balance,
      COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
      COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
      COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
      COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
      COUNT(DISTINCT CASE WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid ELSE NULL END) as transaction_count
    FROM ledgers l
    INNER JOIN group_tree gt ON l.parent = gt.name
    LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid AND v.is_deleted = 0
      AND v.is_cancelled = 0 AND v.is_optional = 0
    WHERE l.company_guid = ? AND l.is_deleted = 0
    GROUP BY l.name, l.parent, l.opening_balance
  )
  SELECT party_name, group_name, ledger_opening_balance, debit_before, credit_before,
    ((ledger_opening_balance * -1) + debit_before - credit_before) as opening_balance,
    debit_total, credit_total,
    ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) as outstanding,
    transaction_count,
    SUM((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) OVER () as total_receivables
  FROM base_data
  WHERE ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) > 0.01
  ORDER BY outstanding DESC
''', [_companyGuid, _companyGuid, _fromDate, _fromDate, _fromDate, _toDate, _fromDate, _toDate, _fromDate, _toDate, _companyGuid]);

    // ── Payables ──────────────────────────────────────────────────────────────
    final payablesResult = await db.rawQuery('''
  WITH RECURSIVE group_tree AS (
    SELECT group_guid, name FROM groups
    WHERE company_guid = ?
      AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
      AND is_deleted = 0
    UNION ALL
    SELECT g.group_guid, g.name FROM groups g
    INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
    WHERE g.company_guid = ? AND g.is_deleted = 0
  ),
  base_data AS (
    SELECT l.name as party_name, l.parent as group_name,
      l.opening_balance as ledger_opening_balance,
      COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
      COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
      COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
      COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
      COUNT(DISTINCT CASE WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid ELSE NULL END) as transaction_count
    FROM ledgers l
    INNER JOIN group_tree gt ON l.parent = gt.name
    LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid AND v.is_deleted = 0
      AND v.is_cancelled = 0 AND v.is_optional = 0
    WHERE l.company_guid = ? AND l.is_deleted = 0
    GROUP BY l.name, l.parent, l.opening_balance
  )
  SELECT party_name, group_name, ledger_opening_balance, credit_before, debit_before,
    (ledger_opening_balance + credit_before - debit_before) as opening_balance,
    credit_total, debit_total,
    (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding,
    transaction_count,
    SUM(ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) OVER () as total_payables
  FROM base_data
  WHERE (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
  ORDER BY outstanding DESC
''', [_companyGuid, _companyGuid, _fromDate, _fromDate, _fromDate, _toDate, _fromDate, _toDate, _fromDate, _toDate, _companyGuid]);

    _receivableGroups = receivablesResult;
    _payableGroups    = payablesResult;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _calculateTotal(List<Map<String, dynamic>> groups, String field) =>
      groups.fold(0.0,
          (s, g) => s + ((g[field] as num?)?.toDouble() ?? 0.0));

  String _fmt(double amount) {
    final neg = amount < 0;
    final f = amount.abs().toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${neg ? '-' : ''}₹$f';
  }

  String _formatTallyDate(String d) {
    if (d.length != 8) return d;
    return '${d.substring(6)}-${d.substring(4, 6)}-${d.substring(0, 4)}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : FadeTransition(
              opacity: _fadeAnim,
              child: Column(children: [
                _buildHeaderBanner(),
                _buildSummaryCards(),
                _buildTabBar(),
                _buildTableHeader(),
                Expanded(child: _buildList()),
                _buildFooter(),
              ]),
            ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: _textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Party Outstanding',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
        Text(
          '${_formatTallyDate(_fromDate)} → ${_formatTallyDate(_toDate)}',
          style: const TextStyle(fontSize: 11, color: _textMuted),
        ),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textMuted, size: 20),
          onPressed: _loadData,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade100),
      ),
    );
  }

  // ── Header banner ──────────────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A6FD8), Color(0xFF0D4DA0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_companyName ?? '',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(
              '${_formatTallyDate(_fromDate)}  →  ${_formatTallyDate(_toDate)}',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.72)),
            ),
          ]),
        ),
        // Net position pill
        _bannerPill(
          _receivableGroups.length + _payableGroups.length == 0
              ? 'No Data'
              : '${_receivableGroups.length + _payableGroups.length} Parties',
          Icons.people_rounded,
        ),
      ]),
    );
  }

  Widget _bannerPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }

  // ── Summary cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    final totalRec = _calculateTotal(_receivableGroups, 'outstanding');
    final totalPay = _calculateTotal(_payableGroups, 'outstanding');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(children: [
        Expanded(child: _summaryCard(
          label: 'Receivables',
          amount: totalRec,
          count: _receivableGroups.length,
          color: _positiveC,
          bg: _positiveBg,
          icon: Icons.arrow_downward_rounded,
          onTap: () => setState(() => _selectedTab = 0),
          active: _selectedTab == 0,
        )),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard(
          label: 'Payables',
          amount: totalPay,
          count: _payableGroups.length,
          color: _negativeC,
          bg: _negativeBg,
          icon: Icons.arrow_upward_rounded,
          onTap: () => setState(() => _selectedTab = 1),
          active: _selectedTab == 1,
        )),
      ]),
    );
  }

  Widget _summaryCard({
    required String label,
    required double amount,
    required int count,
    required Color color,
    required Color bg,
    required IconData icon,
    required VoidCallback onTap,
    required bool active,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.08) : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? color : Colors.grey.shade200,
              width: active ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? color : _textMuted)),
              const SizedBox(height: 3),
              Text(_fmt(amount),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$count ${count == 1 ? 'party' : 'parties'}',
                  style: const TextStyle(fontSize: 10, color: _textMuted)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      height: 40,
      decoration: BoxDecoration(
        color: _tableBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        _tabPill(0, 'Receivables', _positiveC),
        _tabPill(1, 'Payables',    _negativeC),
      ]),
    );
  }

  Widget _tabPill(int idx, String label, Color activeColor) {
    final active = _selectedTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : _textMuted)),
          ),
        ),
      ),
    );
  }

  // ── Table header ───────────────────────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      color: _tableBg,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(children: [
        const Expanded(flex: 3, child: _hCell('Party Name')),
        const _hCell('Txns', flex: 1, align: TextAlign.center),
        const _hCell('Opening', flex: 2, align: TextAlign.right),
        const _hCell('Outstanding', flex: 2, align: TextAlign.right),
      ]),
    );
  }

  // ── Party list ─────────────────────────────────────────────────────────────

  Widget _buildList() {
    final parties = _selectedTab == 0 ? _receivableGroups : _payableGroups;
    final isRec   = _selectedTab == 0;

    if (parties.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline_rounded,
              size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            'No outstanding ${isRec ? 'receivables' : 'payables'}',
            style: const TextStyle(fontSize: 15, color: _textMuted),
          ),
        ]),
      );
    }

    return ListView.builder(
      itemCount: parties.length,
      itemBuilder: (ctx, i) => _buildRow(parties[i], i, isRec),
    );
  }

  Widget _buildRow(Map<String, dynamic> party, int index, bool isRec) {
    final outstanding = (party['outstanding'] as num?)?.toDouble() ?? 0.0;
    final opening     = (party['opening_balance'] as num?)?.toDouble() ?? 0.0;
    final partyName   = party['party_name'] as String;
    final groupName   = party['group_name'] as String? ?? '';
    final txnCount    = (party['transaction_count'] as num?)?.toInt() ?? 0;
    final color       = isRec ? _positiveC : _negativeC;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LedgerDetailScreen(
            companyGuid: _companyGuid!,
            companyName: _companyName!,
            ledgerName:  partyName,
            fromDate:    _fromDate,
            toDate:      _toDate,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: index.isEven ? _cardBg : _bg,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 0.8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          // Name + group
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(partyName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (groupName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(groupName,
                    style: const TextStyle(fontSize: 11, color: _textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),

          // Txn count badge
          SizedBox(
            width: 44,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$txnCount',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                    textAlign: TextAlign.center),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Opening
          Expanded(
            flex: 2,
            child: Text(_fmt(opening),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.7)),
                textAlign: TextAlign.right),
          ),

          // Outstanding + chevron
          Expanded(
            flex: 2,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(
                child: Text(_fmt(outstanding),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color),
                    textAlign: TextAlign.right),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: Colors.grey.shade300),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final parties = _selectedTab == 0 ? _receivableGroups : _payableGroups;
    final total   = _calculateTotal(parties, 'outstanding');
    final isRec   = _selectedTab == 0;
    final color   = isRec ? _positiveC : _negativeC;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: _bg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            '${parties.length} ${parties.length == 1 ? 'party' : 'parties'}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _textMuted),
          ),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Total ${isRec ? 'Receivables' : 'Payables'}',
            style: const TextStyle(fontSize: 10, color: _textMuted),
          ),
          const SizedBox(height: 2),
          Text(_fmt(total),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ]),
      ]),
    );
  }
}

// ── Header cell widget ─────────────────────────────────────────────────────────

class _hCell extends StatelessWidget {
  final String label;
  final int flex;
  final TextAlign align;
  const _hCell(this.label,
      {this.flex = 0, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    final text = Text(label,
        textAlign: align,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF8A94A6),
            letterSpacing: 0.3));
    if (flex == 0) return text;
    return Expanded(flex: flex, child: text);
  }
}