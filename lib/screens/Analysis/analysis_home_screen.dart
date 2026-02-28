// screens/balance_sheet_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class AnalysisHomeScreen extends StatefulWidget {
  @override
  _AnalysisHomeScreenState createState() => _AnalysisHomeScreenState();
}

class _AnalysisHomeScreenState extends State<AnalysisHomeScreen> {
  final _db = DatabaseHelper.instance;
  
  String? _companyGuid;
  String? _companyName;
  bool _loading = true;
  
  Map<String, dynamic>? _analysisData;
  String _fromDate = '20250401'; // Financial year start
  String _toDate = '20260331';   // Financial year end
  
  DateTime? _selectedFromDate;
  DateTime? _selectedToDate;

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
    
    // Only set initial dates if not already set by user
    if (_selectedFromDate == null || _selectedToDate == null) {
      _fromDate = company['starting_from'] as String? ?? _fromDate;
      _toDate = company['ending_at'] as String? ?? _toDate;
      _selectedFromDate = _parseTallyDate(_fromDate);
      _selectedToDate = _parseTallyDate(_toDate);
    }

    final analysisData = await _geAnalysisDetailed(_companyGuid!, _fromDate, _toDate);
    
    setState(() {
      _analysisData = analysisData;
      _loading = false;
    });
  }

  DateTime _parseTallyDate(String tallyDate) {
    if (tallyDate.length != 8) return DateTime.now();
    final year = int.parse(tallyDate.substring(0, 4));
    final month = int.parse(tallyDate.substring(4, 6));
    final day = int.parse(tallyDate.substring(6, 8));
    return DateTime(year, month, day);
  }

  String _formatDateToTally(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _selectedFromDate ?? DateTime.now(),
        end: _selectedToDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFromDate = picked.start;
        _selectedToDate = picked.end;
        _fromDate = _formatDateToTally(picked.start);
        _toDate = _formatDateToTally(picked.end);
      });
      _loadData();
    }
  }

  Future<Map<String, dynamic>> _geAnalysisDetailed(
    String companyGuid,
    String fromDate,
    String toDate,
  ) async {
    final db = await _db.database;    
    
    final purchaseResult = await db.rawQuery('''
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
        COUNT(*) as vouchers,
        SUM(debit_amount) as debit_total,
        SUM(credit_amount) as credit_total,
        SUM(net_amount) as net_purchase
      FROM (
        SELECT
          SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
          SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_amount,
          (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
           SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
        FROM vouchers v
        INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
        INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
        INNER JOIN group_tree gt ON l.parent = gt.name
        WHERE v.company_guid = ?
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
          AND v.date >= ?
          AND v.date <= ?
        GROUP BY v.voucher_guid
      ) voucher_totals
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

    final netPurchase = (purchaseResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;

    final salesResult = await db.rawQuery('''
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
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales,
        COUNT(DISTINCT v.voucher_guid) as vouchers
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

    final netSales = (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;

    final directExpenses = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND name = 'Direct Expenses'
          AND is_deleted = 0
        
        UNION ALL
        
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ?
          AND g.is_deleted = 0
      )
      SELECT 
        vle.ledger_name,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount,
        SUM(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
            SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) OVER () as total_direct_expenses
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
      GROUP BY vle.ledger_name
      ORDER BY net_amount DESC
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

    final totalDirectExpenses = directExpenses.isNotEmpty 
        ? (directExpenses.first['total_direct_expenses'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final indirectExpenses = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND name = 'Indirect Expenses'
          AND is_deleted = 0
        
        UNION ALL
        
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ?
          AND g.is_deleted = 0
      )
      SELECT 
        vle.ledger_name,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount,
        SUM(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
            SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) OVER () as total_indirect_expenses
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
      GROUP BY vle.ledger_name
      ORDER BY net_amount DESC
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);

    final totalIndirectExpenses = indirectExpenses.isNotEmpty 
        ? (indirectExpenses.first['total_indirect_expenses'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final indirectIncomes = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND name = 'Indirect Incomes'
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
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        (l.opening_balance + 
         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as closing_balance,
        SUM(l.opening_balance + 
            SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
            SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) OVER () as total_indirect_incomes
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
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
    ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

    final totalIndirectIncomes = indirectIncomes.isNotEmpty 
        ? (indirectIncomes.first['total_indirect_incomes'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final directIncomes = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND name = 'Direct Incomes'
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
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        (l.opening_balance + 
         SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
         SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as closing_balance,
        SUM(l.opening_balance + 
            SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - 
            SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) OVER () as total_direct_incomes
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
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
    ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

    final totalDirectIncomes = directIncomes.isNotEmpty 
        ? (directIncomes.first['total_direct_incomes'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final grossProfit = netSales - (netPurchase + totalDirectExpenses);
    final netProfit = grossProfit + totalIndirectIncomes - totalIndirectExpenses;

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

    final totalReceivables = receivablesResult.isNotEmpty 
        ? (receivablesResult.first['total_receivables'] as num?)?.toDouble() ?? 0.0
        : 0.0;

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

    final totalAdvancedReceived = advancedReceived.isNotEmpty 
        ? (advancedReceived.first['total_advanced_received'] as num?)?.toDouble() ?? 0.0
        : 0.0;

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

    final totalAdvancedPayed = advancedPayed.isNotEmpty 
        ? (advancedPayed.first['total_advanced_payed'] as num?)?.toDouble() ?? 0.0
        : 0.0;

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

    final totalPayables = payablesResult.isNotEmpty 
        ? (payablesResult.first['total_payables'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final payments = await db.rawQuery('''
      SELECT 
        v.voucher_guid,
        v.date,
        v.voucher_number,
        v.narration,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as amount,
        GROUP_CONCAT(DISTINCT CASE 
          WHEN vle.amount > 0 THEN vle.ledger_name 
          ELSE NULL 
        END) as party_names,
        SUM(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) OVER () as total_payments
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
    ''', [companyGuid, fromDate, toDate]);
    
    final totalPayments = payments.isNotEmpty 
        ? (payments.first['total_payments'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final receipts = await db.rawQuery('''
      SELECT 
        v.voucher_guid,
        v.date,
        v.voucher_number,
        v.narration,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as amount,
        GROUP_CONCAT(DISTINCT CASE 
          WHEN vle.amount < 0 THEN vle.ledger_name 
          ELSE NULL 
        END) as party_names,
        SUM(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) OVER () as total_receipts
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Receipt'
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date >= ?
        AND v.date <= ?
      GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
      ORDER BY v.date DESC, v.voucher_number DESC
    ''', [companyGuid, fromDate, toDate]);
    
    final totalReceipts = receipts.isNotEmpty 
        ? (receipts.first['total_receipts'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    
    return {
      'purchase': netPurchase,
      'direct_expenses': directExpenses,
      'direct_expenses_total': totalDirectExpenses,
      'gross_profit': grossProfit,
      'sales': netSales,
      'indirect_expenses': indirectExpenses,
      'indirect_expenses_total': totalIndirectExpenses,
      'indirect_incomes': indirectIncomes,
      'indirect_incomes_total': totalIndirectIncomes,
      'direct_incomes': directIncomes,
      'direct_incomes_total': totalDirectIncomes,
      'net_profit': netProfit,
      'receivables': receivablesResult,
      'total_receivables': totalReceivables,
      'advanced_received': advancedReceived,
      'total_advanced_received': totalAdvancedReceived,
      'advanced_payed': advancedPayed,
      'total_advanced_payed': totalAdvancedPayed,
      'payables': payablesResult,
      'total_payables': totalPayables,
      'payments': payments,
      'total_payments': totalPayments,
      'receipts': receipts,
      'total_receipts': totalReceipts,
    };
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatCurrency(amount),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: amount < 0 ? Colors.red : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading data')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _analysisData;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Business Analysis')),
        body: Center(child: Text('No data available')),
      );
    }
        
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Analysis', style: TextStyle(fontSize: 18)),
            if (_companyName != null)
              Text(
                _companyName!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Display
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_formatDateToTally(_selectedFromDate!)} - ${_formatDateToTally(_selectedToDate!)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectDateRange,
                    child: Text('Change'),
                  ),
                ],
              ),
            ),

            // Profit & Loss Section
            _buildSectionHeader('Profit & Loss'),
            _buildSummaryCard(
              title: 'Sales',
              amount: data['sales'] as double,
              icon: Icons.trending_up,
              color: Colors.green,
            ),
            _buildSummaryCard(
              title: 'Purchase',
              amount: data['purchase'] as double,
              icon: Icons.shopping_cart,
              color: Colors.orange,
            ),
            _buildSummaryCard(
              title: 'Direct Expenses',
              amount: data['direct_expenses_total'] as double,
              icon: Icons.account_balance_wallet,
              color: Colors.red,
            ),
            _buildSummaryCard(
              title: 'Gross Profit',
              amount: data['gross_profit'] as double,
              icon: Icons.assessment,
              color: data['gross_profit'] >= 0 ? Colors.green : Colors.red,
            ),
            _buildSummaryCard(
              title: 'Indirect Expenses',
              amount: data['indirect_expenses_total'] as double,
              icon: Icons.money_off,
              color: Colors.red,
            ),
            _buildSummaryCard(
              title: 'Indirect Incomes',
              amount: data['indirect_incomes_total'] as double,
              icon: Icons.add_circle_outline,
              color: Colors.green,
            ),
            _buildSummaryCard(
              title: 'Direct Incomes',
              amount: data['direct_incomes_total'] as double,
              icon: Icons.attach_money,
              color: Colors.green,
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: data['net_profit'] >= 0
                      ? [Colors.green[400]!, Colors.green[600]!]
                      : [Colors.red[400]!, Colors.red[600]!],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (data['net_profit'] >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance, color: Colors.white, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Net Profit',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatCurrency(data['net_profit'] as double),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Receivables & Payables Section
            _buildSectionHeader('Receivables & Payables'),
            _buildSummaryCard(
              title: 'Total Receivables',
              amount: data['total_receivables'] as double,
              icon: Icons.call_received,
              color: Colors.blue,
            ),
            _buildSummaryCard(
              title: 'Advanced Received',
              amount: data['total_advanced_received'] as double,
              icon: Icons.savings,
              color: Colors.teal,
            ),
            _buildSummaryCard(
              title: 'Total Payables',
              amount: data['total_payables'] as double,
              icon: Icons.call_made,
              color: Colors.purple,
            ),
            _buildSummaryCard(
              title: 'Advanced Payed',
              amount: data['total_advanced_payed'] as double,
              icon: Icons.payments,
              color: Colors.indigo,
            ),

            // Cash Flow Section
            _buildSectionHeader('Cash Flow'),
            _buildSummaryCard(
              title: 'Total Receipts',
              amount: data['total_receipts'] as double,
              icon: Icons.arrow_downward,
              color: Colors.green,
            ),
            _buildSummaryCard(
              title: 'Total Payments',
              amount: data['total_payments'] as double,
              icon: Icons.arrow_upward,
              color: Colors.red,
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}