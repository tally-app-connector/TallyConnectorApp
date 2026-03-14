// // screens/balance_sheet_screen.dart

// import 'package:flutter/material.dart';
// import '../../database/database_helper.dart';

// class AnalysisHomeScreen extends StatefulWidget {
//   @override
//   _AnalysisHomeScreenState createState() => _AnalysisHomeScreenState();
// }

// class _AnalysisHomeScreenState extends State<AnalysisHomeScreen> {
//   final _db = DatabaseHelper.instance;
  
//   String? _companyGuid;
//   String? _companyName;
//   bool _loading = true;
  
//   Map<String, dynamic>? _analysisData;
//   String _fromDate = '20250401'; // Financial year start
//   String _toDate = '20260331';   // Financial year end
  
//   DateTime? _selectedFromDate;
//   DateTime? _selectedToDate;

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
    
//     // Only set initial dates if not already set by user
//     if (_selectedFromDate == null || _selectedToDate == null) {
//       _fromDate = company['starting_from'] as String? ?? _fromDate;
//       _toDate = company['ending_at'] as String? ?? _toDate;
//       _selectedFromDate = _parseTallyDate(_fromDate);
//       _selectedToDate = _parseTallyDate(_toDate);
//     }

//     final analysisData = await _geAnalysisDetailed(_companyGuid!, _fromDate, _toDate);
    
//     setState(() {
//       _analysisData = analysisData;
//       _loading = false;
//     });
//   }

//   DateTime _parseTallyDate(String tallyDate) {
//     if (tallyDate.length != 8) return DateTime.now();
//     final year = int.parse(tallyDate.substring(0, 4));
//     final month = int.parse(tallyDate.substring(4, 6));
//     final day = int.parse(tallyDate.substring(6, 8));
//     return DateTime(year, month, day);
//   }

//   String _formatDateToTally(DateTime date) {
//     return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
//   }

//   Future<void> _selectDateRange() async {
//     final DateTimeRange? picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//       initialDateRange: DateTimeRange(
//         start: _selectedFromDate ?? DateTime.now(),
//         end: _selectedToDate ?? DateTime.now(),
//       ),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: ColorScheme.light(
//               primary: Colors.blue,
//               onPrimary: Colors.white,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );

//     if (picked != null) {
//       setState(() {
//         _selectedFromDate = picked.start;
//         _selectedToDate = picked.end;
//         _fromDate = _formatDateToTally(picked.start);
//         _toDate = _formatDateToTally(picked.end);
//       });
//       _loadData();
//     }
//   }

//   Future<Map<String, dynamic>> _geAnalysisDetailed(
//     String companyGuid,
//     String fromDate,
//     String toDate,
//   ) async {
//     final db = await _db.database;    
    
//     final purchaseResult = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND reserved_name = 'Purchase Accounts'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         COUNT(*) as vouchers,
//         SUM(debit_amount) as debit_total,
//         SUM(credit_amount) as credit_total,
//         SUM(net_amount) as net_purchase
//       FROM (
//         SELECT
//           SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
//           SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_amount,
//           (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
//            SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
//         FROM vouchers v
//         INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
//         INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//         INNER JOIN group_tree gt ON l.parent = gt.name
//         WHERE v.company_guid = ?
//           AND v.is_deleted = 0
//           AND v.is_cancelled = 0
//           AND v.is_optional = 0
//           AND v.date >= ?
//           AND v.date <= ?
//         GROUP BY v.voucher_guid
//       ) voucher_totals
//     ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

//     final netPurchase = (purchaseResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;

//     final salesResult = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND reserved_name = 'Sales Accounts'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//         (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
//          SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales,
//         COUNT(DISTINCT v.voucher_guid) as vouchers
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       WHERE v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//     ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

//     final netSales = (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;

//     final directExpenses = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND name = 'Direct Expenses'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         vle.ledger_name,
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
//         (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
//          SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount,
//         SUM(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
//             SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) OVER () as total_direct_expenses
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       WHERE v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//       GROUP BY vle.ledger_name
//       ORDER BY net_amount DESC
//     ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

//     final totalDirectExpenses = directExpenses.isNotEmpty 
//         ? (directExpenses.first['total_direct_expenses'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

//     final indirectExpenses = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND name = 'Indirect Expenses'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         vle.ledger_name,
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
//         (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
//          SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount,
//         SUM(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
//             SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) OVER () as total_indirect_expenses
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       WHERE v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//       GROUP BY vle.ledger_name
//       ORDER BY net_amount DESC
//     ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

//     final totalIndirectExpenses = indirectExpenses.isNotEmpty 
//         ? (indirectExpenses.first['total_indirect_expenses'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

//     final indirectIncomes = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND name = 'Indirect Incomes'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         l.name as ledger_name,
//         l.opening_balance,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//         (l.opening_balance + 
//          SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
//          SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as closing_balance,
//         SUM(l.opening_balance + 
//             SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
//             SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) OVER () as total_indirect_incomes
//       FROM ledgers l
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//       LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
//         AND v.company_guid = l.company_guid
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//       WHERE l.company_guid = ?
//         AND l.is_deleted = 0
//       GROUP BY l.name, l.opening_balance
//       ORDER BY closing_balance DESC
//     ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

//     final totalIndirectIncomes = indirectIncomes.isNotEmpty 
//         ? (indirectIncomes.first['total_indirect_incomes'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

//     final directIncomes = await db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name
//         FROM groups
//         WHERE company_guid = ?
//           AND name = 'Direct Incomes'
//           AND is_deleted = 0
        
//         UNION ALL
        
//         SELECT g.group_guid, g.name
//         FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ?
//           AND g.is_deleted = 0
//       )
//       SELECT 
//         l.name as ledger_name,
//         l.opening_balance,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//         (l.opening_balance + 
//          SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
//          SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as closing_balance,
//         SUM(l.opening_balance + 
//             SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
//             SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) OVER () as total_direct_incomes
//       FROM ledgers l
//       INNER JOIN group_tree gt ON l.parent = gt.name
//       LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//       LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
//         AND v.company_guid = l.company_guid
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//       WHERE l.company_guid = ?
//         AND l.is_deleted = 0
//       GROUP BY l.name, l.opening_balance
//       ORDER BY closing_balance DESC
//     ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

//     final totalDirectIncomes = directIncomes.isNotEmpty 
//         ? (directIncomes.first['total_direct_incomes'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

//     final grossProfit = netSales - (netPurchase + totalDirectExpenses);
//     final netProfit = grossProfit + totalIndirectIncomes - totalIndirectExpenses;

//      final receivablesResult = await db.rawQuery('''
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

//     final totalReceivables = receivablesResult.isNotEmpty 
//         ? (receivablesResult.first['total_receivables'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

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

//     final totalAdvancedReceived = advancedReceived.isNotEmpty 
//         ? (advancedReceived.first['total_advanced_received'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

//     final advancedPayed = await db.rawQuery('''
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

//     final totalAdvancedPayed = advancedPayed.isNotEmpty 
//         ? (advancedPayed.first['total_advanced_payed'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

//     final payablesResult = await db.rawQuery('''
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

//     final totalPayables = payablesResult.isNotEmpty 
//         ? (payablesResult.first['total_payables'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

//     final payments = await db.rawQuery('''
//       SELECT 
//         v.voucher_guid,
//         v.date,
//         v.voucher_number,
//         v.narration,
//         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as amount,
//         GROUP_CONCAT(DISTINCT CASE 
//           WHEN vle.amount > 0 THEN vle.ledger_name 
//           ELSE NULL 
//         END) as party_names,
//         SUM(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) OVER () as total_payments
//       FROM vouchers v
//       INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
//       WHERE v.company_guid = ?
//         AND v.voucher_type = 'Payment'
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//       GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
//       ORDER BY v.date DESC, v.voucher_number DESC
//     ''', [companyGuid, fromDate, toDate]);
    
//     final totalPayments = payments.isNotEmpty 
//         ? (payments.first['total_payments'] as num?)?.toDouble() ?? 0.0
//         : 0.0;

//     final receipts = await db.rawQuery('''
//       SELECT 
//         v.voucher_guid,
//         v.date,
//         v.voucher_number,
//         v.narration,
//         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as amount,
//         GROUP_CONCAT(DISTINCT CASE 
//           WHEN vle.amount < 0 THEN vle.ledger_name 
//           ELSE NULL 
//         END) as party_names,
//         SUM(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) OVER () as total_receipts
//       FROM vouchers v
//       INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
//       WHERE v.company_guid = ?
//         AND v.voucher_type = 'Receipt'
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//       GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
//       ORDER BY v.date DESC, v.voucher_number DESC
//     ''', [companyGuid, fromDate, toDate]);
    
//     final totalReceipts = receipts.isNotEmpty 
//         ? (receipts.first['total_receipts'] as num?)?.toDouble() ?? 0.0
//         : 0.0;
    
//     return {
//       'purchase': netPurchase,
//       'direct_expenses': directExpenses,
//       'direct_expenses_total': totalDirectExpenses,
//       'gross_profit': grossProfit,
//       'sales': netSales,
//       'indirect_expenses': indirectExpenses,
//       'indirect_expenses_total': totalIndirectExpenses,
//       'indirect_incomes': indirectIncomes,
//       'indirect_incomes_total': totalIndirectIncomes,
//       'direct_incomes': directIncomes,
//       'direct_incomes_total': totalDirectIncomes,
//       'net_profit': netProfit,
//       'receivables': receivablesResult,
//       'total_receivables': totalReceivables,
//       'advanced_received': advancedReceived,
//       'total_advanced_received': totalAdvancedReceived,
//       'advanced_payed': advancedPayed,
//       'total_advanced_payed': totalAdvancedPayed,
//       'payables': payablesResult,
//       'total_payables': totalPayables,
//       'payments': payments,
//       'total_payments': totalPayments,
//       'receipts': receipts,
//       'total_receipts': totalReceipts,
//     };
//   }

//   String _formatCurrency(double amount) {
//     return '₹${amount.toStringAsFixed(2).replaceAllMapped(
//       RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
//       (Match m) => '${m[1]},',
//     )}';
//   }

//   Widget _buildSummaryCard({
//     required String title,
//     required double amount,
//     required IconData icon,
//     required Color color,
//     VoidCallback? onTap,
//   }) {
//     return Card(
//       elevation: 2,
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: EdgeInsets.all(16),
//           child: Row(
//             children: [
//               Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Icon(icon, color: color, size: 28),
//               ),
//               SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.grey[600],
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       _formatCurrency(amount),
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                         color: amount < 0 ? Colors.red : Colors.black87,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               if (onTap != null)
//                 Icon(Icons.chevron_right, color: Colors.grey),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSectionHeader(String title) {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
//       child: Text(
//         title,
//         style: TextStyle(
//           fontSize: 18,
//           fontWeight: FontWeight.bold,
//           color: Colors.black87,
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Loading data')),
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     final data = _analysisData;
//     if (data == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Business Analysis')),
//         body: Center(child: Text('No data available')),
//       );
//     }
        
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Business Analysis', style: TextStyle(fontSize: 18)),
//             if (_companyName != null)
//               Text(
//                 _companyName!,
//                 style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
//               ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.date_range),
//             onPressed: _selectDateRange,
//             tooltip: 'Select Date Range',
//           ),
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadData,
//             tooltip: 'Refresh',
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Date Range Display
//             Container(
//               margin: EdgeInsets.all(16),
//               padding: EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.blue[50],
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.blue[200]!),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       '${_formatDateToTally(_selectedFromDate!)} - ${_formatDateToTally(_selectedToDate!)}',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.blue[900],
//                       ),
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: _selectDateRange,
//                     child: Text('Change'),
//                   ),
//                 ],
//               ),
//             ),

//             // Profit & Loss Section
//             _buildSectionHeader('Profit & Loss'),
//             _buildSummaryCard(
//               title: 'Sales',
//               amount: data['sales'] as double,
//               icon: Icons.trending_up,
//               color: Colors.green,
//             ),
//             _buildSummaryCard(
//               title: 'Purchase',
//               amount: data['purchase'] as double,
//               icon: Icons.shopping_cart,
//               color: Colors.orange,
//             ),
//             _buildSummaryCard(
//               title: 'Direct Expenses',
//               amount: data['direct_expenses_total'] as double,
//               icon: Icons.account_balance_wallet,
//               color: Colors.red,
//             ),
//             _buildSummaryCard(
//               title: 'Gross Profit',
//               amount: data['gross_profit'] as double,
//               icon: Icons.assessment,
//               color: data['gross_profit'] >= 0 ? Colors.green : Colors.red,
//             ),
//             _buildSummaryCard(
//               title: 'Indirect Expenses',
//               amount: data['indirect_expenses_total'] as double,
//               icon: Icons.money_off,
//               color: Colors.red,
//             ),
//             _buildSummaryCard(
//               title: 'Indirect Incomes',
//               amount: data['indirect_incomes_total'] as double,
//               icon: Icons.add_circle_outline,
//               color: Colors.green,
//             ),
//             _buildSummaryCard(
//               title: 'Direct Incomes',
//               amount: data['direct_incomes_total'] as double,
//               icon: Icons.attach_money,
//               color: Colors.green,
//             ),
//             Container(
//               margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               padding: EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: data['net_profit'] >= 0
//                       ? [Colors.green[400]!, Colors.green[600]!]
//                       : [Colors.red[400]!, Colors.red[600]!],
//                 ),
//                 borderRadius: BorderRadius.circular(16),
//                 boxShadow: [
//                   BoxShadow(
//                     color: (data['net_profit'] >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
//                     blurRadius: 8,
//                     offset: Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.account_balance, color: Colors.white, size: 32),
//                   SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Net Profit',
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.white.withOpacity(0.9),
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         SizedBox(height: 4),
//                         Text(
//                           _formatCurrency(data['net_profit'] as double),
//                           style: TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // Receivables & Payables Section
//             _buildSectionHeader('Receivables & Payables'),
//             _buildSummaryCard(
//               title: 'Total Receivables',
//               amount: data['total_receivables'] as double,
//               icon: Icons.call_received,
//               color: Colors.blue,
//             ),
//             _buildSummaryCard(
//               title: 'Advanced Received',
//               amount: data['total_advanced_received'] as double,
//               icon: Icons.savings,
//               color: Colors.teal,
//             ),
//             _buildSummaryCard(
//               title: 'Total Payables',
//               amount: data['total_payables'] as double,
//               icon: Icons.call_made,
//               color: Colors.purple,
//             ),
//             _buildSummaryCard(
//               title: 'Advanced Payed',
//               amount: data['total_advanced_payed'] as double,
//               icon: Icons.payments,
//               color: Colors.indigo,
//             ),

//             // Cash Flow Section
//             _buildSectionHeader('Cash Flow'),
//             _buildSummaryCard(
//               title: 'Total Receipts',
//               amount: data['total_receipts'] as double,
//               icon: Icons.arrow_downward,
//               color: Colors.green,
//             ),
//             _buildSummaryCard(
//               title: 'Total Payments',
//               amount: data['total_payments'] as double,
//               icon: Icons.arrow_upward,
//               color: Colors.red,
//             ),

//             SizedBox(height: 24),
//           ],
//         ),
//       ),
//     );
//   }
// }

// screens/Analysis/analysis_home_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class AnalysisHomeScreen extends StatefulWidget {
  @override
  _AnalysisHomeScreenState createState() => _AnalysisHomeScreenState();
}

class _AnalysisHomeScreenState extends State<AnalysisHomeScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  String? _companyGuid;
  String? _companyName;
  bool _loading = true;

  Map<String, dynamic>? _data;
  String _fromDate = '20250401';
  String _toDate   = '20260331';

  DateTime? _selectedFromDate;
  DateTime? _selectedToDate;

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
  static const Color _amberC     = Color(0xFFB45309);
  static const Color _amberBg    = Color(0xFFFFF7E6);
  static const Color _purpleC    = Color(0xFF7B2FBE);
  static const Color _purpleBg   = Color(0xFFF3E8FF);
  static const Color _tealC      = Color(0xFF0891B2);
  static const Color _tealBg     = Color(0xFFE0F7FA);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading (logic unchanged) ────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final company = await _db.getSelectedCompanyByGuid();
    if (company == null) {
      setState(() => _loading = false);
      return;
    }

    _companyGuid = company['company_guid'] as String;
    _companyName = company['company_name'] as String;

    if (_selectedFromDate == null || _selectedToDate == null) {
      _fromDate = company['starting_from'] as String? ?? _fromDate;
      _toDate   = company['ending_at']     as String? ?? _toDate;
      _selectedFromDate = _parseTallyDate(_fromDate);
      _selectedToDate   = _parseTallyDate(_toDate);
    }

    final analysisData =
        await _geAnalysisDetailed(_companyGuid!, _fromDate, _toDate);

    setState(() {
      _data    = analysisData;
      _loading = false;
    });
    _fadeCtrl.forward(from: 0);
  }

  DateTime _parseTallyDate(String d) {
    if (d.length != 8) return DateTime.now();
    return DateTime(int.parse(d.substring(0, 4)),
        int.parse(d.substring(4, 6)), int.parse(d.substring(6, 8)));
  }

  String _toTally(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  // ── Date selection ─────────────────────────────────────────────────────────

  Future<void> _selectDateRange() async {
    DateTime tempFrom = _selectedFromDate ?? DateTime.now();
    DateTime tempTo   = _selectedToDate   ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.date_range_rounded,
                          color: _primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Select Period',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _textDark)),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Quick Select',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _textMuted,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _qChip('This Month', () {
                      final n = DateTime.now();
                      setDs(() { tempFrom = DateTime(n.year, n.month, 1); tempTo = DateTime(n.year, n.month + 1, 0); });
                    }),
                    _qChip('Last Month', () {
                      final n = DateTime.now();
                      setDs(() { tempFrom = DateTime(n.year, n.month - 1, 1); tempTo = DateTime(n.year, n.month, 0); });
                    }),
                    _qChip('Q1', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 4, 1); tempTo = DateTime(y, 6, 30); }); }),
                    _qChip('Q2', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 7, 1); tempTo = DateTime(y, 9, 30); }); }),
                    _qChip('Q3', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 10, 1); tempTo = DateTime(y, 12, 31); }); }),
                    _qChip('Q4', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y + 1, 1, 1); tempTo = DateTime(y + 1, 3, 31); }); }),
                    _qChip('Full FY', () { setDs(() { tempFrom = _selectedFromDate!; tempTo = _selectedToDate!; }); }),
                  ]),
                  const SizedBox(height: 22),
                  const Text('Custom Range',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _textMuted,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 10),
                  _dateTile('From', tempFrom, () async {
                    final p = await showDatePicker(context: ctx,
                        initialDate: tempFrom,
                        firstDate: DateTime(2000), lastDate: DateTime(2100),
                        builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: _textDark)),
                            child: child!));
                    if (p != null) setDs(() => tempFrom = p);
                  }),
                  const SizedBox(height: 10),
                  _dateTile('To', tempTo, () async {
                    final p = await showDatePicker(context: ctx,
                        initialDate: tempTo,
                        firstDate: DateTime(2000), lastDate: DateTime(2100),
                        builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: _textDark)),
                            child: child!));
                    if (p != null) setDs(() => tempTo = p);
                  }),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _textMuted,
                          side: BorderSide(color: Colors.grey.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedFromDate = tempFrom;
                          _selectedToDate   = tempTo;
                          _fromDate = _toTally(tempFrom);
                          _toDate   = _toTally(tempTo);
                        });
                        Navigator.pop(ctx);
                        _loadData();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primary, foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('Apply'))),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _qChip(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _primary.withOpacity(0.2)),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
        ),
      );

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: _primary),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: _textMuted)),
              const SizedBox(height: 2),
              Text(_displayDate(date),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
            ]),
          ]),
        ),
      );

  // ── All SQL queries (unchanged) ────────────────────────────────────────────

  Future<Map<String, dynamic>> _geAnalysisDetailed(
      String companyGuid, String fromDate, String toDate) async {
    final db = await _db.database;

    final purchaseResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT SUM(debit_amount) as debit_total, SUM(credit_amount) as credit_total, SUM(net_amount) as net_purchase
      FROM (
        SELECT SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
               SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_amount,
               (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
        FROM vouchers v
        INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
        INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
        INNER JOIN group_tree gt ON l.parent = gt.name
        WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        GROUP BY v.voucher_guid
      ) t
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);
    final netPurchase = (purchaseResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;

    final salesResult = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND reserved_name = 'Sales Accounts' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
             SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
             (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);
    final netSales = (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;

    Future<List<Map<String, dynamic>>> expGroup(String name) => db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups WHERE company_guid = ? AND name = '$name' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT vle.ledger_name,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount,
        SUM(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) OVER () as total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      GROUP BY vle.ledger_name ORDER BY net_amount DESC
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

    Future<List<Map<String, dynamic>>> incGroup(String name) => db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups WHERE company_guid = ? AND name = '$name' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT l.name as ledger_name, l.opening_balance,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        (l.opening_balance + SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as closing_balance,
        SUM(l.opening_balance + SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) OVER () as total
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.opening_balance ORDER BY closing_balance DESC
    ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

    final directExpenses    = await expGroup('Direct Expenses');
    final indirectExpenses  = await expGroup('Indirect Expenses');
    final directIncomes     = await incGroup('Direct Incomes');
    final indirectIncomes   = await incGroup('Indirect Incomes');

    double _t(List<Map<String, dynamic>> r, String k) =>
        r.isNotEmpty ? (r.first[k] as num?)?.toDouble() ?? 0.0 : 0.0;

    final totalDE  = _t(directExpenses,   'total');
    final totalIE  = _t(indirectExpenses, 'total');
    final totalDI  = _t(directIncomes,    'total');
    final totalII  = _t(indirectIncomes,  'total');

    final grossProfit = netSales - (netPurchase + totalDE);
    final netProfit   = grossProfit + totalII - totalIE;

    // Receivables / payables / payments / receipts (unchanged SQL)
    Future<List<Map<String, dynamic>>> outstandingQuery(
        String group, String condition, String order) => db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name = '$group' OR reserved_name = '$group') AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      ),
      base_data AS (
        SELECT l.name as party_name, l.parent as group_name, l.opening_balance as op,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as db,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as cb,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as dt,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as ct,
          COUNT(DISTINCT CASE WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid ELSE NULL END) as tc
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.parent, l.opening_balance
      )
      SELECT party_name, group_name,
        ((op * -1) + db - cb + dt - ct) as outstanding,
        SUM((op * -1) + db - cb + dt - ct) OVER () as total_outstanding
      FROM base_data
      WHERE $condition
      ORDER BY $order
    ''', [_companyGuid, _companyGuid, _fromDate, _fromDate, _fromDate, _toDate, _fromDate, _toDate, _fromDate, _toDate, _companyGuid]);

    final receivables = await outstandingQuery('Sundry Debtors', '((op * -1) + db - cb + dt - ct) > 0.01', 'outstanding DESC');
    final payables    = await outstandingQuery('Sundry Creditors', '((op * -1) + db - cb + dt - ct) > 0.01', 'outstanding DESC');

    final totalReceivables = receivables.isNotEmpty ? (receivables.first['total_outstanding'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final totalPayables    = payables.isNotEmpty    ? (payables.first['total_outstanding']    as num?)?.toDouble() ?? 0.0 : 0.0;

    Future<double> voucherTotal(String type, String field) async {
      final r = await db.rawQuery('''
        SELECT SUM(CASE WHEN vle.amount ${field == 'receipts' ? '>' : '<'} 0 THEN ABS(vle.amount) ELSE 0 END) as total
        FROM vouchers v INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ? AND v.voucher_type = ? AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
      ''', [companyGuid, type, fromDate, toDate]);
      return (r.first['total'] as num?)?.toDouble() ?? 0.0;
    }

    final totalReceipts  = await voucherTotal('Receipt', 'receipts');
    final totalPayments  = await voucherTotal('Payment', 'payments');

    return {
      'purchase': netPurchase,
      'sales': netSales,
      'direct_expenses_total': totalDE,
      'indirect_expenses_total': totalIE,
      'direct_incomes_total': totalDI,
      'indirect_incomes_total': totalII,
      'gross_profit': grossProfit,
      'net_profit': netProfit,
      'total_receivables': totalReceivables,
      'total_payables': totalPayables,
      'total_receipts': totalReceipts,
      'total_payments': totalPayments,
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(double amount) {
    final neg = amount < 0;
    final f = amount.abs().toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${neg ? '-' : ''}₹$f';
  }

  double _d(String key) =>
      (_data?[key] as double?) ?? 0.0;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _data == null
              ? const Center(
                  child: Text('No data available',
                      style: TextStyle(color: _textMuted)))
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    color: _primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderBanner(),
                          const SizedBox(height: 20),
                          _buildSectionLabel('Profit & Loss'),
                          const SizedBox(height: 12),
                          _buildPLGrid(),
                          const SizedBox(height: 8),
                          _buildNetProfitBanner(),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Outstanding'),
                          const SizedBox(height: 12),
                          _buildOutstandingRow(),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Cash Flow'),
                          const SizedBox(height: 12),
                          _buildCashFlowRow(),
                        ],
                      ),
                    ),
                  ),
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
        const Text('Business Analysis',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
        if (_companyName != null)
          Text(_companyName!,
              style: const TextStyle(fontSize: 11, color: _textMuted)),
      ]),
      actions: [
        // Period pill
        GestureDetector(
          onTap: _selectDateRange,
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.date_range_rounded,
                  size: 13, color: _primary),
              const SizedBox(width: 4),
              Text(
                _selectedFromDate != null && _selectedToDate != null
                    ? '${_displayDate(_selectedFromDate!)} → ${_displayDate(_selectedToDate!)}'
                    : 'Set Period',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _primary),
              ),
            ]),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textMuted, size: 20),
          onPressed: _loadData,
        ),
      ],
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade100)),
    );
  }

  // ── Header banner ──────────────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    final netProfit = _d('net_profit');
    final isProfit  = netProfit >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [const Color(0xFF1B8A5A), const Color(0xFF0D5C3A)]
              : [const Color(0xFFD32F2F), const Color(0xFF8B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_companyName ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 4),
                if (_selectedFromDate != null && _selectedToDate != null)
                  Text(
                    '${_displayDate(_selectedFromDate!)}  →  ${_displayDate(_selectedToDate!)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.72)),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  _bannerPill('Sales',    _d('sales')),
                  const SizedBox(width: 8),
                  _bannerPill('Purchase', _d('purchase')),
                ]),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(children: [
            Text(isProfit ? 'Net Profit' : 'Net Loss',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.75))),
            const SizedBox(height: 4),
            Text(_fmt(netProfit.abs()),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ]),
        ),
      ]),
    );
  }

  Widget _bannerPill(String label, double amount) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$label: ${_fmt(amount)}',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: Colors.white)),
      );

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String title) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primary, _accent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: _textDark, letterSpacing: -0.2)),
        ]),
      );

  // ── P&L grid (2×2) ─────────────────────────────────────────────────────────

  Widget _buildPLGrid() {
    final items = [
      _KpiItem('Sales',            _d('sales'),                   Icons.trending_up_rounded,       _positiveC, _positiveBg),
      _KpiItem('Purchase',         _d('purchase'),                Icons.shopping_bag_rounded,      _amberC,    _amberBg),
      _KpiItem('Direct Exp.',      _d('direct_expenses_total'),   Icons.money_off_rounded,         _negativeC, _negativeBg),
      _KpiItem('Indirect Exp.',    _d('indirect_expenses_total'), Icons.arrow_downward_rounded,    _negativeC, _negativeBg),
      _KpiItem('Direct Inc.',      _d('direct_incomes_total'),    Icons.attach_money_rounded,      _positiveC, _positiveBg),
      _KpiItem('Indirect Inc.',    _d('indirect_incomes_total'),  Icons.add_circle_outline_rounded,_positiveC, _positiveBg),
      _KpiItem('Gross Profit',     _d('gross_profit'),
          Icons.assessment_rounded,
          _d('gross_profit') >= 0 ? _positiveC : _negativeC,
          _d('gross_profit') >= 0 ? _positiveBg : _negativeBg),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 52) / 2,
            child: _kpiCard(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _kpiCard(_KpiItem item) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: item.bg, shape: BoxShape.circle),
            child: Icon(item.icon, color: item.color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textMuted)),
                  const SizedBox(height: 3),
                  Text(_fmt(item.value),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: item.color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
        ]),
      );

  // ── Net profit banner ──────────────────────────────────────────────────────

  Widget _buildNetProfitBanner() {
    final np       = _d('net_profit');
    final isProfit = np >= 0;
    final color    = isProfit ? _positiveC : _negativeC;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isProfit ? _positiveBg : _negativeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(
              isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isProfit ? 'Net Profit' : 'Net Loss',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 3),
            Text(_fmt(np.abs()),
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Gross Profit',
              style: const TextStyle(fontSize: 10, color: _textMuted)),
          const SizedBox(height: 2),
          Text(_fmt(_d('gross_profit')),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _d('gross_profit') >= 0 ? _positiveC : _negativeC)),
        ]),
      ]),
    );
  }

  // ── Outstanding row ────────────────────────────────────────────────────────

  Widget _buildOutstandingRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: _outstandingCard(
          label: 'Receivables',
          amount: _d('total_receivables'),
          icon: Icons.arrow_downward_rounded,
          color: _positiveC, bg: _positiveBg,
        )),
        const SizedBox(width: 12),
        Expanded(child: _outstandingCard(
          label: 'Payables',
          amount: _d('total_payables'),
          icon: Icons.arrow_upward_rounded,
          color: _negativeC, bg: _negativeBg,
        )),
      ]),
    );
  }

  Widget _outstandingCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required Color bg,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 10),
          Text(_fmt(amount),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );

  // ── Cash flow row ──────────────────────────────────────────────────────────

  Widget _buildCashFlowRow() {
    final receipts = _d('total_receipts');
    final payments = _d('total_payments');
    final net      = receipts - payments;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _outstandingCard(
            label: 'Receipts',
            amount: receipts,
            icon: Icons.south_rounded,
            color: _positiveC, bg: _positiveBg,
          )),
          const SizedBox(width: 12),
          Expanded(child: _outstandingCard(
            label: 'Payments',
            amount: payments,
            icon: Icons.north_rounded,
            color: _negativeC, bg: _negativeBg,
          )),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Cash Flow',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark)),
                Text(
                  _fmt(net),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: net >= 0 ? _positiveC : _negativeC),
                ),
              ]),
        ),
      ]),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────────────────

class _KpiItem {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final Color bg;
  const _KpiItem(this.label, this.value, this.icon, this.color, this.bg);
}