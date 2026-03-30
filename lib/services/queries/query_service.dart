import '../../database/database_helper.dart';
import '../../models/data_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CENTRALIZED QUERY SERVICE
//  All database queries extracted from screen files into one place.
//  Screens call these static methods instead of containing inline SQL.
// ══════════════════════════════════════════════════════════════════════════════

class QueryService {
  static final _db = DatabaseHelper.instance;

  // ── Helper: group tree CTE ──────────────────────────────────────────────
  static String _groupTree(String seedField, String seedValue) => '''
    WITH RECURSIVE group_tree AS (
      SELECT group_guid, name FROM groups
      WHERE company_guid = ? AND $seedField = '$seedValue' AND is_deleted = 0
      UNION ALL
      SELECT g.group_guid, g.name FROM groups g
      INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
      WHERE g.company_guid = ? AND g.is_deleted = 0
    )
  ''';

  // ── Helper: previous date string ────────────────────────────────────────
  static String _getPreviousDate(String dateStr) {
    if (dateStr.length != 8) return dateStr;
    final y = int.parse(dateStr.substring(0, 4));
    final m = int.parse(dateStr.substring(4, 6));
    final d = int.parse(dateStr.substring(6, 8));
    final prev = DateTime(y, m, d).subtract(const Duration(days: 1));
    return '${prev.year}${prev.month.toString().padLeft(2, '0')}${prev.day.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VOUCHER QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Get voucher header by GUID
  static Future<Map<String, dynamic>?> getVoucherHeader(
    String companyGuid,
    String voucherGuid,
  ) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT
        voucher_guid, date, voucher_type, voucher_number,
        reference_number, reference_date, narration, party_name,
        is_invoice, is_accounting_voucher, is_inventory_voucher
      FROM vouchers
      WHERE company_guid = ? AND voucher_guid = ? AND is_deleted = 0
      LIMIT 1
    ''', [companyGuid, voucherGuid]);
    return result.isEmpty ? null : result.first;
  }

  /// Get all ledger entries for a voucher (debit/credit breakdown)
  static Future<List<Map<String, dynamic>>> getVoucherLedgerEntries(
    String voucherGuid,
  ) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT ledger_name, amount,
        CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END as debit,
        CASE WHEN amount > 0 THEN amount ELSE 0 END as credit
      FROM voucher_ledger_entries
      WHERE voucher_guid = ?
      ORDER BY CASE WHEN amount < 0 THEN 0 ELSE 1 END, ABS(amount) DESC
    ''', [voucherGuid]);
  }

  /// Fetch vouchers by type (Payment or Receipt) with party names and totals
  static Future<List<Map<String, dynamic>>> fetchVouchersByType(
    String companyGuid, String voucherType, String fromDate, String toDate,
  ) async {
    final db = await _db.database;
    final isPayment = voucherType == 'Payment';
    return db.rawQuery('''
      SELECT v.voucher_guid, v.date, v.voucher_number, v.narration,
        SUM(CASE WHEN vle.amount ${isPayment ? '< 0 THEN ABS(vle.amount)' : '> 0 THEN vle.amount'} ELSE 0 END) as amount,
        GROUP_CONCAT(DISTINCT CASE
          WHEN vle.amount ${isPayment ? '> 0' : '< 0'} THEN vle.ledger_name ELSE NULL
        END) as party_names
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ? AND v.voucher_type = ?
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
      ORDER BY v.date DESC, v.voucher_number DESC
    ''', [companyGuid, voucherType, fromDate, toDate]);
  }

  /// Fetch detailed ledger entries for a specific voucher (with group name)
  static Future<List<Map<String, dynamic>>> fetchVoucherEntries(
    String companyGuid, String voucherGuid,
  ) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT vle.ledger_name, vle.amount, l.parent as group_name
      FROM voucher_ledger_entries vle
      LEFT JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = ?
      WHERE vle.voucher_guid = ?
      ORDER BY vle.amount DESC
    ''', [companyGuid, voucherGuid]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LEDGER QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Get opening balance for a specific ledger
  static Future<double> getOpeningBalance(
    String companyGuid, String ledgerName,
  ) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT opening_balance FROM ledgers
      WHERE company_guid = ? AND name = ? AND is_deleted = 0
      LIMIT 1
    ''', [companyGuid, ledgerName]);
    if (result.isEmpty) return 0.0;
    return (result.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get all vouchers affecting a ledger with debit/credit breakdown
  static Future<List<Map<String, dynamic>>> getLedgerVouchers(
    String companyGuid, String ledgerName, String fromDate, String toDate,
  ) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT v.voucher_guid, v.date, v.voucher_type, v.voucher_number, v.narration, vle.amount,
        CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END AS debit,
        CASE WHEN vle.amount > 0 THEN vle.amount           ELSE 0 END AS credit
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ? AND vle.ledger_name = ?
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      ORDER BY v.date ASC, v.voucher_number ASC
    ''', [companyGuid, ledgerName, fromDate, toDate]);
  }

  /// Fetch all ledgers with their balances, with optional group and search filters
  static Future<List<Map<String, dynamic>>> fetchLedgersWithBalances(
    String companyGuid, String fromDate, String toDate, {
    String? selectedGroup, String? searchQuery,
  }) async {
    final db = await _db.database;
    String where = 'l.company_guid = ? AND l.is_deleted = 0';
    final params = <dynamic>[companyGuid];
    if (selectedGroup != null) { where += ' AND l.parent = ?'; params.add(selectedGroup); }
    if (searchQuery != null && searchQuery.isNotEmpty) { where += ' AND l.name LIKE ?'; params.add('%$searchQuery%'); }

    return db.rawQuery('''
      SELECT l.name AS ledger_name, l.parent AS group_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) AS debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) AS credit_total,
        (l.opening_balance + COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) AS closing_balance,
        COUNT(DISTINCT v.voucher_guid) AS voucher_count
      FROM ledgers l
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE $where
      GROUP BY l.name, l.parent, l.opening_balance
      ORDER BY l.name
    ''', [fromDate, toDate, ...params]);
  }

  /// Fetch distinct group names from ledgers
  static Future<List<String>> fetchDistinctGroups(String companyGuid) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT parent AS group_name FROM ledgers
      WHERE company_guid = ? AND is_deleted = 0 AND parent IS NOT NULL
      ORDER BY parent
    ''', [companyGuid]);
    return result.map((r) => r['group_name'] as String).toList();
  }

  /// Fetch party ledgers (Sundry Debtors / Sundry Creditors) with balances
  static Future<List<Map<String, dynamic>>> fetchPartyLedgers(
    String companyGuid, String groupName, bool isReceivable,
  ) async {
    final db = await _db.database;
    final isDebtors = groupName == 'Sundry Debtors';
    final treeName = isDebtors ? 'debtor_tree' : 'creditor_tree';
    final seedName = isDebtors ? 'Sundry Debtors' : 'Sundry Creditors';

    final result = await db.rawQuery('''
      WITH RECURSIVE $treeName AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name = '$seedName' OR reserved_name = '$seedName') AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN $treeName t ON g.parent_guid = t.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT l.name AS ledger_name, l.parent AS group_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) AS debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) AS credit_total,
        (l.opening_balance + COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)) AS closing_balance,
        COUNT(DISTINCT v.voucher_guid) AS voucher_count
      FROM ledgers l
      INNER JOIN $treeName t ON l.parent = t.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.parent, l.opening_balance
      ORDER BY ABS(closing_balance) DESC
    ''', [companyGuid, companyGuid, companyGuid]);

    return result.where((row) {
      final bal = (row['closing_balance'] as num?)?.toDouble() ?? 0.0;
      return isReceivable ? bal > 0.01 : bal < -0.01;
    }).toList();
  }

  /// Get trial balance for all ledgers
  static Future<List<Map<String, dynamic>>> getTrialBalance(
    String companyGuid, String fromDate, String toDate,
  ) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT l.name as ledger_name, l.parent as group_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
        (l.opening_balance + COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
      FROM ledgers l
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.parent, l.opening_balance
      ORDER BY l.parent, l.name
    ''', [fromDate, toDate, companyGuid]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GROUP QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Get ledgers for a group with balances (Purchase/Sales/Expenses/Incomes)
  static Future<List<Map<String, dynamic>>> getLedgersForGroup(
    String companyGuid, String groupName, String fromDate, String toDate,
  ) async {
    final db = await _db.database;
    final bool isPurchaseOrSales = groupName == 'Purchase Accounts' || groupName == 'Sales Accounts';
    final String groupFilter = isPurchaseOrSales ? "reserved_name = '$groupName'" : 'name = ?';
    final params = isPurchaseOrSales
        ? [companyGuid, companyGuid, fromDate, toDate, companyGuid]
        : [companyGuid, groupName, companyGuid, fromDate, toDate, companyGuid];

    return db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND $groupFilter AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT l.name as ledger_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
        (l.opening_balance + COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance,
        COUNT(DISTINCT v.voucher_guid) as voucher_count
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.opening_balance
      ORDER BY closing_balance DESC
    ''', params);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  OUTSTANDING QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Get bill-wise detail for a specific ledger
  static Future<List<Map<String, dynamic>>> getBillWiseDetail(
    String companyGuid, String ledgerName, String fromDate, String toDate,
  ) async {
    final db = await _db.database;
    return db.rawQuery('''
      WITH bill_entries AS (
        SELECT vle.ledger_name, vle.bill_name as reference_name, vle.bill_type,
          v.date as transaction_date, v.voucher_number, v.voucher_type, vle.bill_date,
          CASE WHEN vle.bill_type = 'New Ref' THEN vle.amount ELSE 0 END as bill_amount,
          CASE WHEN vle.bill_type = 'Agst Ref' THEN vle.amount ELSE 0 END as payment_amount,
          v.voucher_guid
        FROM voucher_ledger_entries vle
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ? AND vle.ledger_name = ?
          AND vle.bill_name IS NOT NULL AND vle.bill_name != ''
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
      ),
      bill_summary AS (
        SELECT reference_name, MIN(bill_date) as bill_date, MIN(transaction_date) as first_transaction_date,
          SUM(bill_amount) as total_bill_amount, SUM(payment_amount) as total_payment_amount,
          (SUM(bill_amount) + SUM(payment_amount)) as outstanding,
          COUNT(DISTINCT CASE WHEN bill_type = 'New Ref' THEN voucher_guid END) as bill_count,
          COUNT(DISTINCT CASE WHEN bill_type = 'Agst Ref' THEN voucher_guid END) as payment_count
        FROM bill_entries GROUP BY reference_name HAVING ABS(outstanding) > 0.01
      )
      SELECT reference_name, COALESCE(bill_date, first_transaction_date) as bill_date,
        total_bill_amount, ABS(total_payment_amount) as total_payment_amount, outstanding,
        bill_count, payment_count, SUM(outstanding) OVER () as total_outstanding
      FROM bill_summary
      ORDER BY COALESCE(bill_date, first_transaction_date) DESC, reference_name
    ''', [companyGuid, ledgerName, fromDate, toDate]);
  }

  /// Get bill-wise outstanding ledgers for a group (Sundry Debtors/Creditors)
  static Future<List<Map<String, dynamic>>> getBillWiseOutstandingLedgers(
    String companyGuid, String groupName, String fromDate, String toDate,
  ) async {
    final db = await _db.database;
    return db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name = ? OR reserved_name = ?) AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      ),
      base_data AS (
        SELECT l.name as ledger_name, l.parent as group_name, l.opening_balance as ledger_opening_balance,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
          COUNT(DISTINCT CASE WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid ELSE NULL END) as transaction_count
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.parent, l.opening_balance
      )
      SELECT ledger_name, group_name, ledger_opening_balance, credit_before, debit_before,
        (ledger_opening_balance + credit_before - debit_before) as opening_balance,
        credit_total, debit_total,
        (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding,
        transaction_count
      FROM base_data
      WHERE ABS(ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
      ORDER BY ABS(ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) DESC
    ''', [companyGuid, groupName, groupName, companyGuid,
      fromDate, fromDate, fromDate, toDate, fromDate, toDate, fromDate, toDate, companyGuid]);
  }

  /// Get receivables (Sundry Debtors outstanding with inverted opening balance)
  static Future<List<Map<String, dynamic>>> getReceivables(
    String companyGuid, String fromDate, String toDate,
  ) async {
    final db = await _db.database;
    return db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      ),
      base_data AS (
        SELECT l.name as party_name, l.parent as group_name, l.opening_balance as ledger_opening_balance,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
          COUNT(DISTINCT CASE WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid ELSE NULL END) as transaction_count
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
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
    ''', [companyGuid, companyGuid, fromDate, fromDate, fromDate, toDate, fromDate, toDate, fromDate, toDate, companyGuid]);
  }

  /// Get payables (Sundry Creditors outstanding)
  static Future<List<Map<String, dynamic>>> getPayables(
    String companyGuid, String fromDate, String toDate,
  ) async {
    final db = await _db.database;
    return db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors') AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      ),
      base_data AS (
        SELECT l.name as party_name, l.parent as group_name, l.opening_balance as ledger_opening_balance,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
          COUNT(DISTINCT CASE WHEN v.date >= ? AND v.date <= ? THEN v.voucher_guid ELSE NULL END) as transaction_count
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
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
    ''', [companyGuid, companyGuid, fromDate, fromDate, fromDate, toDate, fromDate, toDate, fromDate, toDate, companyGuid]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STOCK QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Get available closing months for stock
  static Future<List<String>> getAvailableStockMonths(String companyGuid) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT closing_date FROM stock_item_closing_balance
      WHERE company_guid = ? ORDER BY closing_date DESC
    ''', [companyGuid]);
    return rows.map((r) => r['closing_date'] as String).toList();
  }

  /// Fetch all stock items with closing balances for a specific date
  static Future<List<StockItemInfo>> fetchAllClosingStock(
    String companyGuid, String? closingDate,
  ) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT si.name as item_name, si.stock_item_guid,
        COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
        COALESCE(si.base_units, '') as unit,
        COALESCE(cb.closing_balance, 0.0) as closing_balance,
        COALESCE(cb.closing_value, 0.0) as closing_value,
        COALESCE(cb.closing_rate, 0.0) as closing_rate,
        COALESCE(si.parent, '') as parent_name
      FROM stock_items si
      INNER JOIN (
        SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
        UNION
        SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = ?
      ) active ON active.stock_item_guid = si.stock_item_guid
      LEFT JOIN stock_item_closing_balance cb
        ON cb.stock_item_guid = si.stock_item_guid AND cb.company_guid = ? AND cb.closing_date = ?
      WHERE si.company_guid = ? AND si.is_deleted = 0
      ORDER BY si.name ASC
    ''', [companyGuid, companyGuid, closingDate ?? '', companyGuid]);

    return result.map((row) => StockItemInfo(
      itemName: row['item_name'] as String,
      stockItemGuid: row['stock_item_guid'] as String,
      costingMethod: row['costing_method'] as String,
      unit: row['unit'] as String,
      parentName: row['parent_name'] as String,
      closingRate: (row['closing_rate'] as num?)?.toDouble() ?? 0.0,
      closingQty: (row['closing_balance'] as num?)?.toDouble() ?? 0.0,
      closingValue: (row['closing_value'] as num?)?.toDouble() ?? 0.0,
      openingData: [],
    )).toList();
  }

  /// Fetch all stock items with opening batch allocations (for P&L calculations)
  static Future<List<StockItemInfo>> fetchAllStockItemsWithBatches(String companyGuid) async {
    final db = await _db.database;
    final stockItemResults = await db.rawQuery('''
      SELECT si.name as item_name, si.stock_item_guid,
        COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
        COALESCE(si.base_units, '') as unit, COALESCE(si.parent, '') as parent_name
      FROM stock_items si
      WHERE si.company_guid = ? AND si.is_deleted = 0
        AND (EXISTS (SELECT 1 FROM stock_item_batch_allocation siba WHERE siba.stock_item_guid = si.stock_item_guid)
          OR EXISTS (SELECT 1 FROM voucher_inventory_entries vie WHERE vie.stock_item_guid = si.stock_item_guid AND vie.company_guid = si.company_guid))
    ''', [companyGuid]);

    final batchResults = await db.rawQuery('''
      SELECT siba.stock_item_guid, COALESCE(siba.godown_name, '') as godown_name,
        COALESCE(siba.batch_name, '') as batch_name, COALESCE(siba.opening_value, 0) as amount,
        COALESCE(siba.opening_balance, '') as actual_qty, siba.opening_rate as batch_rate
      FROM stock_item_batch_allocation siba
      INNER JOIN stock_items si ON siba.stock_item_guid = si.stock_item_guid
      WHERE si.company_guid = ? AND si.is_deleted = 0
    ''', [companyGuid]);

    final batchMap = <String, List<Map<String, dynamic>>>{};
    for (final batch in batchResults) {
      final guid = batch['stock_item_guid'] as String;
      batchMap.putIfAbsent(guid, () => []).add(batch);
    }

    return stockItemResults.map((row) {
      final guid = row['stock_item_guid'] as String;
      final batches = batchMap[guid] ?? [];
      return StockItemInfo(
        itemName: row['item_name'] as String, stockItemGuid: guid,
        costingMethod: row['costing_method'] as String, unit: row['unit'] as String,
        parentName: row['parent_name'] as String,
        closingRate: 0.0, closingQty: 0.0, closingValue: 0.0,
        openingData: batches.map((b) => BatchAllocation(
          godownName: b['godown_name'] as String, batchName: b['batch_name'] as String,
          amount: (b['amount'] as num?)?.toDouble() ?? 0.0,
          actualQty: b['actual_qty']?.toString() ?? '0', billedQty: '',
          trackingNumber: 'Not Applicable', batchRate: (b['batch_rate'] as num?)?.toDouble(),
        )).toList(),
      );
    }).toList();
  }

  /// Fetch all transactions for a specific stock item
  static Future<List<StockTransaction>> fetchTransactionsForStockItem(
    String companyGuid, String stockItemGuid, String endDate,
  ) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT v.voucher_guid, v.voucher_key as voucher_id, v.date as voucher_date,
        v.voucher_number, vba.godown_name, v.voucher_type,
        vba.actual_qty as stock, COALESCE(vba.batch_rate, 0) as rate,
        vba.amount, vba.is_deemed_positive as is_inward,
        COALESCE(vba.batch_name, '') as batch_name,
        COALESCE(vba.destination_godown_name, '') as destination_godown,
        COALESCE(vba.tracking_number, 'Not Applicable') as tracking_number
      FROM vouchers v
      INNER JOIN voucher_batch_allocations vba ON vba.voucher_guid = v.voucher_guid
      WHERE vba.stock_item_guid = ? AND v.company_guid = ?
        AND v.date <= ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      ORDER BY v.date, v.master_id
    ''', [stockItemGuid, companyGuid, endDate]);

    return result.map((row) => StockTransaction(
      voucherGuid: row['voucher_guid'] as String,
      voucherId: (row['voucher_id'] as num?)?.toInt() ?? 0,
      voucherDate: row['voucher_date'] as String,
      voucherNumber: row['voucher_number']?.toString() ?? '',
      godownName: row['godown_name']?.toString() ?? 'Main Location',
      voucherType: row['voucher_type'] as String,
      stock: double.tryParse(row['stock']?.toString() ?? '0') ?? 0.0,
      rate: (row['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
      isInward: (row['is_inward'] as int?) == 1,
      batchName: row['batch_name'] as String,
      destinationGodown: row['destination_godown'] as String,
      trackingNumber: row['tracking_number'] as String,
    )).toList();
  }

  /// Get all child voucher types recursively (for P&L stock tracking)
  static Future<List<String>> getAllChildVoucherTypes(
    String companyGuid, String voucherTypeName,
  ) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      WITH RECURSIVE voucher_type_tree AS (
        SELECT voucher_type_guid, name FROM voucher_types
        WHERE company_guid = ? AND (name = ? OR reserved_name = ?) AND is_deleted = 0
        UNION ALL
        SELECT vt.voucher_type_guid, vt.name FROM voucher_types vt
        INNER JOIN voucher_type_tree vtt ON vt.parent_guid = vtt.voucher_type_guid
        WHERE vt.company_guid = ? AND vt.is_deleted = 0 AND vt.voucher_type_guid != vt.parent_guid
      )
      SELECT name FROM voucher_type_tree ORDER BY name
    ''', [companyGuid, voucherTypeName, voucherTypeName, companyGuid]);
    return result.map((r) => r['name'] as String).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PROFIT & LOSS QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Analysis home detailed — P&L summary + receivables/payables/receipts/payments
  static Future<Map<String, dynamic>> getAnalysisDetailed(
    String companyGuid, String fromDate, String toDate,
  ) async {
    final db = await _db.database;

    final purchaseResult = await db.rawQuery('''
      ${_groupTree('reserved_name', 'Purchase Accounts')}
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
      ${_groupTree('reserved_name', 'Sales Accounts')}
      SELECT
        SUM(CASE WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount) ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.is_deemed_positive = 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(ABS(vle.amount)) as net_sales,
        COUNT(DISTINCT v.voucher_guid) as vouchers
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent_guid = gt.group_guid
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);
    final netSales = (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;

    Future<List<Map<String, dynamic>>> expGroup(String name) => db.rawQuery('''
      ${_groupTree('name', name)}
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
      ${_groupTree('name', name)}
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

    final directExpenses = await expGroup('Direct Expenses');
    final indirectExpenses = await expGroup('Indirect Expenses');
    final directIncomes = await incGroup('Direct Incomes');
    final indirectIncomes = await incGroup('Indirect Incomes');

    double t(List<Map<String, dynamic>> r, String k) =>
        r.isNotEmpty ? (r.first[k] as num?)?.toDouble() ?? 0.0 : 0.0;
    final totalDE = t(directExpenses, 'total');
    final totalIE = t(indirectExpenses, 'total');
    final totalDI = t(directIncomes, 'total');
    final totalII = t(indirectIncomes, 'total');
    final grossProfit = netSales - (netPurchase + totalDE);
    final netProfit = grossProfit + totalII - totalIE;

    Future<List<Map<String, dynamic>>> outstandingQuery(
        String group, String condition, String order) => db.rawQuery('''
      ${_groupTree('name', group).replaceAll("name = '$group'", "(name = '$group' OR reserved_name = '$group')")}
      , base_data AS (
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
      FROM base_data WHERE $condition ORDER BY $order
    ''', [companyGuid, companyGuid, fromDate, fromDate, fromDate, toDate, fromDate, toDate, fromDate, toDate, companyGuid]);

    final receivables = await outstandingQuery('Sundry Debtors', '((op * -1) + db - cb + dt - ct) > 0.01', 'outstanding DESC');
    final payables = await outstandingQuery('Sundry Creditors', '((op * -1) + db - cb + dt - ct) > 0.01', 'outstanding DESC');
    final totalReceivables = receivables.isNotEmpty ? (receivables.first['total_outstanding'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final totalPayables = payables.isNotEmpty ? (payables.first['total_outstanding'] as num?)?.toDouble() ?? 0.0 : 0.0;

    Future<double> voucherTotal(String type, String field) async {
      final r = await db.rawQuery('''
        SELECT SUM(CASE WHEN vle.amount ${field == 'receipts' ? '>' : '<'} 0 THEN ABS(vle.amount) ELSE 0 END) as total
        FROM vouchers v INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ? AND v.voucher_type = ? AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
      ''', [companyGuid, type, fromDate, toDate]);
      return (r.first['total'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'purchase': netPurchase, 'sales': netSales,
      'direct_expenses_total': totalDE, 'indirect_expenses_total': totalIE,
      'direct_incomes_total': totalDI, 'indirect_incomes_total': totalII,
      'gross_profit': grossProfit, 'net_profit': netProfit,
      'total_receivables': totalReceivables, 'total_payables': totalPayables,
      'total_receipts': await voucherTotal('Receipt', 'receipts'),
      'total_payments': await voucherTotal('Payment', 'payments'),
    };
  }

  /// P&L detailed with stock calculations
  static Future<Map<String, dynamic>> getProfitLossDetailed(
    String companyGuid, String fromDate, String toDate, {
    required bool isMaintainInventory, required String companyStartDate,
  }) async {
    final db = await _db.database;

    final purchResult = await db.rawQuery('''
      ${_groupTree('reserved_name', 'Purchase Accounts')}
      SELECT SUM(debit_amount) as debit_total, SUM(credit_total2) as credit_total, SUM(net_amount) as net_purchase
      FROM (
        SELECT SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
               SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total2,
               (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
        FROM vouchers v INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
        INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
        INNER JOIN group_tree gt ON l.parent = gt.name
        WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        GROUP BY v.voucher_guid
      ) t
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);
    final netPurchase = (purchResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;

    final salesResult = await db.rawQuery('''
      ${_groupTree('reserved_name', 'Sales Accounts')}
      SELECT
        SUM(CASE WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount) ELSE 0 END) as credit_total,
        SUM(CASE WHEN vle.is_deemed_positive = 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
        SUM(ABS(vle.amount)) as net_sales, COUNT(DISTINCT v.voucher_guid) as vouchers
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent_guid = gt.group_guid
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
    ''', [companyGuid, companyGuid, companyGuid, fromDate, toDate]);
    final netSales = (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;

    Future<List<Map<String, dynamic>>> fetchGroup(String groupName) => db.rawQuery('''
      ${_groupTree('name', groupName)}
      SELECT l.name as ledger_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
        (l.opening_balance + COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
      FROM ledgers l INNER JOIN group_tree gt ON l.parent = gt.name
      INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid AND v.company_guid = l.company_guid
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.opening_balance ORDER BY closing_balance DESC
    ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

    Future<List<Map<String, dynamic>>> fetchIncomeGroup(String groupName) => db.rawQuery('''
      ${_groupTree('name', groupName)}
      SELECT l.name as ledger_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
        COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
        (l.opening_balance +
         COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
      FROM ledgers l INNER JOIN group_tree gt ON l.parent = gt.name
      INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid AND v.company_guid = l.company_guid
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.opening_balance
      HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
      ORDER BY closing_balance DESC
    ''', [companyGuid, companyGuid, fromDate, toDate, companyGuid]);

    final directExpenses = await fetchGroup('Direct Expenses');
    final indirectExpenses = await fetchGroup('Indirect Expenses');
    final directIncomes = await fetchIncomeGroup('Direct Incomes');
    final indirectIncomes = await fetchIncomeGroup('Indirect Incomes');

    double sum(List<Map<String, dynamic>> rows) =>
        rows.fold(0.0, (s, r) => s + ((r['closing_balance'] as num?)?.toDouble() ?? 0.0));
    final totalDE = sum(directExpenses).abs();
    final totalIE = sum(indirectExpenses).abs();
    final totalDI = sum(directIncomes);
    final totalII = sum(indirectIncomes);

    double totalClosingStock = 0.0;
    double totalOpeningStock = 0.0;

    if (isMaintainInventory) {
      final allItemClosings = await fetchAllClosingStock(companyGuid, toDate);
      totalClosingStock = allItemClosings.fold(0.0, (s, item) => s + item.closingValue);
      final prevDay = fromDate.compareTo(companyStartDate) <= 0 ? fromDate : _getPreviousDate(fromDate);
      final allItemOpening = await fetchAllClosingStock(companyGuid, prevDay);
      totalOpeningStock = allItemOpening.fold(0.0, (s, item) => s + item.closingValue);
    } else {
      final closingResult = await db.rawQuery('''
        WITH RECURSIVE stock_groups AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (reserved_name='Stock-in-Hand' OR name='Stock-in-Hand') AND is_deleted=0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        ),
        latest_balances AS (
          SELECT lcb.ledger_guid, lcb.amount * -1 as closing_amount,
                 ROW_NUMBER() OVER (PARTITION BY lcb.ledger_guid ORDER BY lcb.closing_date DESC) as rn
          FROM ledger_closing_balances lcb
          INNER JOIN ledgers l ON l.ledger_guid = lcb.ledger_guid
          INNER JOIN stock_groups sg ON l.parent = sg.name
          WHERE lcb.company_guid = ? AND lcb.closing_date <= ? AND l.is_deleted = 0
        )
        SELECT COALESCE(SUM(closing_amount), 0) as total_closing_stock FROM latest_balances WHERE rn = 1
      ''', [companyGuid, companyGuid, companyGuid, toDate]);
      totalClosingStock = (closingResult.first['total_closing_stock'] as num?)?.toDouble() ?? 0.0;

      final prevDay = fromDate.compareTo(companyStartDate) <= 0 ? companyStartDate : _getPreviousDate(fromDate);
      final openingResult = await db.rawQuery('''
        WITH RECURSIVE stock_groups AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (reserved_name='Stock-in-Hand' OR name='Stock-in-Hand') AND is_deleted=0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        ),
        latest_balances AS (
          SELECT l.ledger_guid, COALESCE(lcb.amount, l.opening_balance) * -1 as opening_amount,
                 ROW_NUMBER() OVER (PARTITION BY l.ledger_guid ORDER BY lcb.closing_date DESC NULLS LAST) as rn
          FROM ledgers l INNER JOIN stock_groups sg ON l.parent = sg.name
          LEFT JOIN ledger_closing_balances lcb ON lcb.ledger_guid = l.ledger_guid
            AND lcb.company_guid = ? AND lcb.closing_date <= ?
          WHERE l.company_guid = ? AND l.is_deleted = 0
        )
        SELECT COALESCE(SUM(opening_amount), 0) as total_opening_stock FROM latest_balances WHERE rn = 1
      ''', [companyGuid, companyGuid, companyGuid, prevDay, companyGuid]);
      totalOpeningStock = (openingResult.first['total_opening_stock'] as num?)?.toDouble() ?? 0.0;
    }

    final grossProfit = (netSales + totalDI + totalClosingStock) - (totalOpeningStock + netPurchase + totalDE);
    final netProfit = grossProfit + totalII - totalIE;

    return {
      'opening_stock': totalOpeningStock, 'purchase': netPurchase,
      'direct_expenses': directExpenses, 'direct_expenses_total': totalDE,
      'gross_profit': grossProfit, 'closing_stock': totalClosingStock, 'sales': netSales,
      'indirect_expenses': indirectExpenses, 'indirect_expenses_total': totalIE,
      'indirect_incomes': indirectIncomes, 'indirect_incomes_total': totalII,
      'direct_incomes': directIncomes, 'direct_incomes_total': totalDI,
      'net_profit': netProfit,
    };
  }
}
