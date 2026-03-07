import 'package:flutter/material.dart';
import '../../models/report_data.dart';
import '../../utils/amount_formatter.dart';
import '../../../database/database_helper.dart';

class SalesAnalyticsService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ── Helper: convert DateTime to Tally YYYYMMDD format ─────────
  String _toTallyDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
  }

  // ── Helper: get company date range ────────────────────────────
  Future<Map<String, String>> _getCompanyDates() async {
    final company = await _db.getSelectedCompanyByGuid();

    
    return {
      'from': (company?['starting_from'] as String? ?? '20250401').replaceAll('-', ''),
      'to': (company?['ending_at'] as String? ?? '20260331').replaceAll('-', ''),
    };
  }

  // ── Helper: wrap a double into a ReportValue ─────────────────
  ReportValue _toReportValue(double amount, String label) {
    final f = AmountFormatter.format(amount);
    return ReportValue(
      primaryValue: f['value']!,
      primaryUnit: f['unit']!,
      primaryLabel: label,
      changePercent: '',
      isPositiveChange: amount >= 0,
      periodStart: DateTime.now(),
      periodEnd: DateTime.now(),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TOTALS — using proper Tally DB patterns
  // ══════════════════════════════════════════════════════════════════

  Future<ReportValue> getTotalSales({
    required String companyGuid,    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    final v = await _getNetSales(companyGuid, from, to);
    return _toReportValue(v, 'Net Sales');
  }

  Future<ReportValue> getTotalPurchase({
    required String companyGuid,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    final v = await _getNetPurchase(companyGuid, from, to);
    return _toReportValue(v, 'Net Purchase');
  }

  Future<ReportValue> getTotalProfit({
    required String companyGuid,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    final sales = await _getNetSales(companyGuid, from, to);
    final purchase = await _getNetPurchase(companyGuid, from, to);
    return _toReportValue(sales - purchase, 'Gross Profit');
  }

  Future<ReportValue> getTotalReceivable({
    required String companyGuid,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    final v = await _getReceivables(companyGuid, from, to);
    return _toReportValue(v, 'Receivables');
  }

  Future<ReportValue> getTotalPayable({
    required String companyGuid,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    final v = await _getPayables(companyGuid, from, to);
    return _toReportValue(v, 'Payables');
  }

  Future<ReportValue> getTotalGST({
    required String companyGuid,
    
    
  }) async {
    // GST = sum of gst_amount from voucher_inventory_entries for sales vouchers
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    try {
      final db = await _db.database;
      final result = await db.rawQuery('''
        SELECT COALESCE(SUM(ABS(vie.gst_amount)), 0) as total
        FROM voucher_inventory_entries vie
        INNER JOIN vouchers v ON v.voucher_guid = vie.voucher_guid
        WHERE v.company_guid = ? AND v.voucher_type = 'Sales'
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
      ''', [companyGuid, from, to]);
      final v = (result.first['total'] as num?)?.toDouble() ?? 0.0;
      return _toReportValue(v, 'GST');
    } catch (_) {
      return _toReportValue(0, 'GST');
    }
  }

  Future<ReportValue> getTotalReceipts({
    required String companyGuid,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    final v = await _getReceipts(companyGuid, from, to);
    return _toReportValue(v, 'Receipts');
  }

  Future<ReportValue> getTotalPayments({
    required String companyGuid,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    final v = await _getPayments(companyGuid, from, to);
    return _toReportValue(v, 'Payments');
  }

  Future<ReportValue> getTotalStock({
  required String companyGuid,
  
  
}) async {
  try {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(cb.closing_value), 0.0) AS total
      FROM stock_item_closing_balance cb
      INNER JOIN (
        SELECT stock_item_guid, MAX(closing_date) AS latest_date
        FROM stock_item_closing_balance
        WHERE company_guid = ?
        GROUP BY stock_item_guid
      ) latest
        ON latest.stock_item_guid = cb.stock_item_guid
        AND latest.latest_date = cb.closing_date
      INNER JOIN stock_items si
        ON si.stock_item_guid = cb.stock_item_guid
        AND si.company_guid = ?
        AND si.is_deleted = 0
      WHERE cb.company_guid = ?
    ''', [companyGuid, companyGuid, companyGuid]);

    final v = (result.first['total'] as num?)?.toDouble() ?? 0.0;
    return _toReportValue(v, 'Stock');
  } catch (_) {
    return _toReportValue(0, 'Stock');
  }
}

  // ══════════════════════════════════════════════════════════════════
  //  CORE DB QUERIES — matching MobileDashboardTab patterns
  // ══════════════════════════════════════════════════════════════════

  Future<double> _getNetSales(String companyGuid, String fromDate, String toDate) async {
    try {
      final db = await _db.database;
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
    -- Credit = deemed positive side (normal sales)
    SUM(CASE WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount) ELSE 0 END) as credit_total,
    
    -- Debit = deemed negative side (sales returns)
    SUM(CASE WHEN vle.is_deemed_positive = 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
    
    -- Net = credit - debit
    SUM(CASE 
      WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount)
      ELSE -ABS(vle.amount)
    END) as net_sales,
    
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

    final salesCredit =
        (salesResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
    final salesDebit =
        (salesResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
    final netSales =
        (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;
    final salesVouchers = salesResult.first['vouchers'] as int? ?? 0;

      return netSales;
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> _getNetPurchase(String companyGuid, String fromDate, String toDate) async {
    try {
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

    final debitTotal =
        (purchaseResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
    final creditTotal =
        (purchaseResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
    final netPurchase =
        (purchaseResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;
    final purchaseVouchers = purchaseResult.first['vouchers'] as int? ?? 0;

      return netPurchase;
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> _getReceivables(String companyGuid, String fromDate, String toDate) async {
    try {
      final db = await _db.database;
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
  companyGuid, 
  companyGuid,
  fromDate,      // debit_before
  fromDate,      // credit_before
  fromDate,      // debit_total start
  toDate,        // debit_total end
  fromDate,      // credit_total start
  toDate,        // credit_total end
  fromDate,      // transaction_count start
  toDate,        // transaction_count end
  companyGuid
]);

    final totalReceivables = receivablesResult.isNotEmpty 
        ? (receivablesResult.first['total_receivables'] as num?)?.toDouble() ?? 0.0
        : 0.0;
      return totalReceivables;
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> _getPayables(String companyGuid, String fromDate, String toDate) async {
    try {
      final db = await _db.database;
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
  companyGuid, 
  companyGuid,
  fromDate,      // credit_before
  fromDate,      // debit_before
  fromDate,      // credit_total start
  toDate,        // credit_total end
  fromDate,      // debit_total start
  toDate,        // debit_total end
  fromDate,      // transaction_count start
  toDate,        // transaction_count end
  companyGuid
]);

    final totalPayables = payablesResult.isNotEmpty 
        ? (payablesResult.first['total_payables'] as num?)?.toDouble() ?? 0.0
        : 0.0;

      return totalPayables;
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> _getPayments(String companyGuid, String fromDate, String toDate) async {
    try {
      final db = await _db.database;
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

    
      return totalPayments;
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> _getReceipts(String companyGuid, String fromDate, String toDate) async {
    try {
      final db = await _db.database;
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
      return totalReceipts;
    } catch (_) {
      return 0.0;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  TREND CHARTS — using voucher_ledger_entries with group tree
  // ══════════════════════════════════════════════════════════════════
Future<ReportChartData> getSalesTrend({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  final dates = await _getCompanyDates();
  final from = dates['from']!;
  final to = dates['to']!;
  try {
    final db = await _db.database;
    final rows = await db.rawQuery('''
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
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT 
        SUBSTR(v.date, 1, 6) as month,
        COALESCE(SUM(CASE WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount)
                         ELSE -ABS(vle.amount) END), 0) as total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      GROUP BY month ORDER BY month
    ''', [companyGuid, companyGuid, companyGuid, from, to]);

    return ReportChartData(
      dataPoints: rows.map((r) => ChartDataPoint(
        label: r['month']?.toString() ?? '',
        value: (r['total'] as num?)?.toDouble() ?? 0,
      )).toList(),
      chartType: chartType ?? ReportChartType.bar,
      title: 'Sales Trend',
      legends: [const ChartLegendItem(label: 'Sales', color: Colors.blue)],
    );
  } catch (_) {
    return ReportChartData(
      dataPoints: const [],
      chartType: chartType ?? ReportChartType.bar,
      title: 'Sales Trend',
    );
  }
}

Future<ReportChartData> getPurchaseTrend({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  final dates = await _getCompanyDates();
  final from = dates['from']!;
  final to = dates['to']!;
  try {
    final db = await _db.database;
    final rows = await db.rawQuery('''
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
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT
        SUBSTR(v.date, 1, 6) as month,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
                 SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN group_tree gt ON l.parent = gt.name
      WHERE v.company_guid = ?
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      GROUP BY month ORDER BY month
    ''', [companyGuid, companyGuid, companyGuid, from, to]);

    return ReportChartData(
      dataPoints: rows.map((r) => ChartDataPoint(
        label: r['month']?.toString() ?? '',
        value: (r['total'] as num?)?.toDouble() ?? 0,
      )).toList(),
      chartType: chartType ?? ReportChartType.bar,
      title: 'Purchase Trend',
      legends: [const ChartLegendItem(label: 'Purchase', color: Colors.orange)],
    );
  } catch (_) {
    return ReportChartData(
      dataPoints: const [],
      chartType: chartType ?? ReportChartType.bar,
      title: 'Purchase Trend',
    );
  }
}

Future<ReportChartData> getProfitTrend({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  final sales = await getSalesTrend(companyGuid: companyGuid, chartType: chartType);
  final purchase = await getPurchaseTrend(companyGuid: companyGuid, chartType: chartType);
  final points = <ChartDataPoint>[];
  for (var i = 0; i < sales.dataPoints.length; i++) {
    final pVal = i < purchase.dataPoints.length
        ? purchase.dataPoints[i].value
        : 0.0;
    points.add(ChartDataPoint(
      label: sales.dataPoints[i].label,
      value: sales.dataPoints[i].value - pVal,
    ));
  }
  return ReportChartData(
    dataPoints: points,
    chartType: chartType ?? ReportChartType.bar,
    title: 'Profit Trend',
    legends: [const ChartLegendItem(label: 'Profit', color: Colors.green)],
  );
}

Future<ReportChartData> getGSTTrend({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  final dates = await _getCompanyDates();
  final from = dates['from']!;
  final to = dates['to']!;
  try {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT 
        SUBSTR(v.date, 1, 6) as month,
        COALESCE(SUM(ABS(vie.gst_amount)), 0) as total
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON v.voucher_guid = vie.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Sales'
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      GROUP BY month ORDER BY month
    ''', [companyGuid, from, to]);

    return ReportChartData(
      dataPoints: rows.map((r) => ChartDataPoint(
        label: r['month']?.toString() ?? '',
        value: (r['total'] as num?)?.toDouble() ?? 0,
      )).toList(),
      chartType: chartType ?? ReportChartType.bar,
      title: 'GST Trend',
      legends: [const ChartLegendItem(label: 'GST', color: Colors.purple)],
    );
  } catch (_) {
    return ReportChartData(
      dataPoints: const [],
      chartType: chartType ?? ReportChartType.bar,
      title: 'GST Trend',
    );
  }
}

Future<ReportChartData> getReceiptsTrend({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  final dates = await _getCompanyDates();
  final from = dates['from']!;
  final to = dates['to']!;
  try {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        SUBSTR(v.date, 1, 6) as month,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Receipt'
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      GROUP BY month ORDER BY month
    ''', [companyGuid, from, to]);

    return ReportChartData(
      dataPoints: rows.map((r) => ChartDataPoint(
        label: r['month']?.toString() ?? '',
        value: (r['total'] as num?)?.toDouble() ?? 0,
      )).toList(),
      chartType: chartType ?? ReportChartType.bar,
      title: 'Receipts Trend',
      legends: [const ChartLegendItem(label: 'Receipts', color: Colors.green)],
    );
  } catch (_) {
    return ReportChartData(
      dataPoints: const [],
      chartType: chartType ?? ReportChartType.bar,
      title: 'Receipts Trend',
    );
  }
}

Future<ReportChartData> getPaymentsTrend({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  final dates = await _getCompanyDates();
  final from = dates['from']!;
  final to = dates['to']!;
  try {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        SUBSTR(v.date, 1, 6) as month,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as total
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Payment'
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      GROUP BY month ORDER BY month
    ''', [companyGuid, from, to]);

    return ReportChartData(
      dataPoints: rows.map((r) => ChartDataPoint(
        label: r['month']?.toString() ?? '',
        value: (r['total'] as num?)?.toDouble() ?? 0,
      )).toList(),
      chartType: chartType ?? ReportChartType.bar,
      title: 'Payments Trend',
      legends: [const ChartLegendItem(label: 'Payments', color: Colors.red)],
    );
  } catch (_) {
    return ReportChartData(
      dataPoints: const [],
      chartType: chartType ?? ReportChartType.bar,
      title: 'Payments Trend',
    );
  }
}

Future<ReportChartData> getReceivableChart({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  final dates = await _getCompanyDates();
  final from = dates['from']!;
  final to = dates['to']!;
  try {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ?
          AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
          AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT l.name as label,
        (l.opening_balance * -1) +
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as value
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.opening_balance
      HAVING value > 0
      ORDER BY value DESC LIMIT 10
    ''', [companyGuid, companyGuid, from, to, companyGuid]);

    return ReportChartData(
      dataPoints: rows.map((r) => ChartDataPoint(
        label: r['label']?.toString() ?? '',
        value: (r['value'] as num?)?.toDouble() ?? 0,
      )).toList(),
      chartType: chartType ?? ReportChartType.bar,
      title: 'Receivables',
      legends: [const ChartLegendItem(label: 'Receivables', color: Colors.blue)],
    );
  } catch (_) {
    return ReportChartData(
      dataPoints: const [],
      chartType: chartType ?? ReportChartType.bar,
      title: 'Receivables',
    );
  }
}

Future<ReportChartData> getPayableChart({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  final dates = await _getCompanyDates();
  final from = dates['from']!;
  final to = dates['to']!;
  try {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ?
          AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
          AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT l.name as label,
        l.opening_balance +
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as value
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.opening_balance
      HAVING value > 0
      ORDER BY value DESC LIMIT 10
    ''', [companyGuid, companyGuid, from, to, companyGuid]);

    return ReportChartData(
      dataPoints: rows.map((r) => ChartDataPoint(
        label: r['label']?.toString() ?? '',
        value: (r['value'] as num?)?.toDouble() ?? 0,
      )).toList(),
      chartType: chartType ?? ReportChartType.bar,
      title: 'Payables',
      legends: [const ChartLegendItem(label: 'Payables', color: Colors.red)],
    );
  } catch (_) {
    return ReportChartData(
      dataPoints: const [],
      chartType: chartType ?? ReportChartType.bar,
      title: 'Payables',
    );
  }
}

Future<ReportChartData> getStockChart({
  required String companyGuid,
  ReportChartType? chartType,
  ChartPeriod? period,
}) async {
  try {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT si.name as label, COALESCE(cb.closing_value, 0) as value
      FROM stock_items si
      INNER JOIN (
        SELECT stock_item_guid, MAX(closing_date) AS latest_date
        FROM stock_item_closing_balance
        WHERE company_guid = ?
        GROUP BY stock_item_guid
      ) latest
        ON latest.stock_item_guid = si.stock_item_guid
      LEFT JOIN stock_item_closing_balance cb
        ON cb.stock_item_guid = latest.stock_item_guid
        AND cb.closing_date = latest.latest_date
        AND cb.company_guid = ?
      WHERE si.company_guid = ?
        AND si.is_deleted = 0
      ORDER BY COALESCE(cb.closing_value, 0) DESC
      LIMIT 10
    ''', [companyGuid, companyGuid, companyGuid]);

    return ReportChartData(
      dataPoints: rows.map((r) => ChartDataPoint(
        label: r['label']?.toString() ?? '',
        value: (r['value'] as num?)?.toDouble() ?? 0,
      )).toList(),
      chartType: chartType ?? ReportChartType.bar,
      title: 'Stock',
      legends: [const ChartLegendItem(label: 'Stock', color: Colors.blue)],
    );
  } catch (_) {
    return ReportChartData(
      dataPoints: const [],
      chartType: chartType ?? ReportChartType.bar,
      title: 'Stock',
    );
  }
}

  // ══════════════════════════════════════════════════════════════════
  //  COMBO CHARTS
  // ══════════════════════════════════════════════════════════════════

  Future<SalesPurchaseChartData> getSalesPurchaseTrend({
    required String companyGuid,
    
    
    ChartPeriod? period,
  }) async {
    final sales = await getSalesTrend(companyGuid: companyGuid,  );
    final purchase = await getPurchaseTrend(companyGuid: companyGuid,  );
    final points = <SalesPurchaseDataPoint>[];
    for (var i = 0; i < sales.dataPoints.length; i++) {
      final pVal = i < purchase.dataPoints.length ? purchase.dataPoints[i].value : 0.0;
      points.add(SalesPurchaseDataPoint(
        label: sales.dataPoints[i].label,
        salesValue: sales.dataPoints[i].value,
        purchaseValue: pVal.toDouble(),
      ));
    }
    return SalesPurchaseChartData(dataPoints: points, title: 'Sales vs Purchase');
  }

  Future<RevenueExpenseProfitData> getRevenueExpenseProfit({
    required String companyGuid,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    final sales = await _getNetSales(companyGuid, from, to);
    final purchase = await _getNetPurchase(companyGuid, from, to);
    return RevenueExpenseProfitData(
      revenue: sales,
      expense: purchase,
      profit: sales - purchase,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  REPORT VALUE HELPER
  // ══════════════════════════════════════════════════════════════════

  Future<ReportValue> getReportValueForMetric(
    ReportMetric metric, {
    required String companyGuid,
  }) async {
    switch (metric) {
      case ReportMetric.sales:
        return getTotalSales(companyGuid: companyGuid);
      case ReportMetric.purchase:
        return getTotalPurchase(companyGuid: companyGuid);
      case ReportMetric.profit:
        return getTotalProfit(companyGuid: companyGuid);
      case ReportMetric.receivable:
        return getTotalReceivable(companyGuid: companyGuid);
      case ReportMetric.payable:
        return getTotalPayable(companyGuid: companyGuid);
      case ReportMetric.receipts:
        return getTotalReceipts(companyGuid: companyGuid);
      case ReportMetric.payments:
        return getTotalPayments(companyGuid: companyGuid);
      case ReportMetric.gst:
        return getTotalGST(companyGuid: companyGuid);
      case ReportMetric.stock:
        return getTotalStock(companyGuid: companyGuid);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  TOP ITEMS — using voucher_inventory_entries
  // ══════════════════════════════════════════════════════════════════

Future<List<TopSellingItem>> getTopItems(
  ReportMetric metric, {
  required String companyGuid,
  int limit = 10,
}) async {
  final dates = await _getCompanyDates();
  final from = dates['from']!;
  final to = dates['to']!;
  try {
    final db = await _db.database;
    List<Map<String, Object?>> rows;

    switch (metric) {
      case ReportMetric.sales:
        rows = await db.rawQuery('''
          WITH RECURSIVE group_tree AS (
            SELECT group_guid, name FROM groups
            WHERE company_guid = ?
              AND reserved_name = 'Sales Accounts'
              AND is_deleted = 0
            UNION ALL
            SELECT g.group_guid, g.name FROM groups g
            INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
            WHERE g.company_guid = ? AND g.is_deleted = 0
          )
          SELECT l.name,
            COALESCE(SUM(CASE WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount)
                             ELSE -ABS(vle.amount) END), 0) as total
          FROM voucher_ledger_entries vle
          INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
          INNER JOIN group_tree gt ON l.parent = gt.name
          WHERE v.company_guid = ?
            AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
            AND v.date >= ? AND v.date <= ?
          GROUP BY l.name
          ORDER BY total DESC LIMIT ?
        ''', [companyGuid, companyGuid, companyGuid, from, to, limit]);
        break;

      case ReportMetric.purchase:
        rows = await db.rawQuery('''
          WITH RECURSIVE group_tree AS (
            SELECT group_guid, name FROM groups
            WHERE company_guid = ?
              AND reserved_name = 'Purchase Accounts'
              AND is_deleted = 0
            UNION ALL
            SELECT g.group_guid, g.name FROM groups g
            INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
            WHERE g.company_guid = ? AND g.is_deleted = 0
          )
          SELECT l.name,
            COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
                     SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total
          FROM voucher_ledger_entries vle
          INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
          INNER JOIN group_tree gt ON l.parent = gt.name
          WHERE v.company_guid = ?
            AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
            AND v.date >= ? AND v.date <= ?
          GROUP BY l.name
          ORDER BY total DESC LIMIT ?
        ''', [companyGuid, companyGuid, companyGuid, from, to, limit]);
        break;

      case ReportMetric.receivable:
        rows = await db.rawQuery('''
          WITH RECURSIVE group_tree AS (
            SELECT group_guid, name FROM groups
            WHERE company_guid = ?
              AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
              AND is_deleted = 0
            UNION ALL
            SELECT g.group_guid, g.name FROM groups g
            INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
            WHERE g.company_guid = ? AND g.is_deleted = 0
          )
          SELECT l.name,
            (l.opening_balance * -1) +
            COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
            COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total
          FROM ledgers l
          INNER JOIN group_tree gt ON l.parent = gt.name
          LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
          LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
            AND v.company_guid = l.company_guid
            AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
            AND v.date >= ? AND v.date <= ?
          WHERE l.company_guid = ? AND l.is_deleted = 0
          GROUP BY l.name, l.opening_balance
          HAVING total > 0
          ORDER BY total DESC LIMIT ?
        ''', [companyGuid, companyGuid, from, to, companyGuid, limit]);
        break;

      case ReportMetric.payable:
        rows = await db.rawQuery('''
          WITH RECURSIVE group_tree AS (
            SELECT group_guid, name FROM groups
            WHERE company_guid = ?
              AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
              AND is_deleted = 0
            UNION ALL
            SELECT g.group_guid, g.name FROM groups g
            INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
            WHERE g.company_guid = ? AND g.is_deleted = 0
          )
          SELECT l.name,
            l.opening_balance +
            COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
            COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as total
          FROM ledgers l
          INNER JOIN group_tree gt ON l.parent = gt.name
          LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
          LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
            AND v.company_guid = l.company_guid
            AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
            AND v.date >= ? AND v.date <= ?
          WHERE l.company_guid = ? AND l.is_deleted = 0
          GROUP BY l.name, l.opening_balance
          HAVING total > 0
          ORDER BY total DESC LIMIT ?
        ''', [companyGuid, companyGuid, from, to, companyGuid, limit]);
        break;

      case ReportMetric.receipts:
        rows = await db.rawQuery('''
          SELECT vle.ledger_name as name,
            COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total
          FROM vouchers v
          INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
          WHERE v.company_guid = ?
            AND v.voucher_type = 'Receipt'
            AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
            AND v.date >= ? AND v.date <= ?
          GROUP BY vle.ledger_name
          HAVING total > 0
          ORDER BY total DESC LIMIT ?
        ''', [companyGuid, from, to, limit]);
        break;

      case ReportMetric.payments:
        rows = await db.rawQuery('''
          SELECT vle.ledger_name as name,
            COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as total
          FROM vouchers v
          INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
          WHERE v.company_guid = ?
            AND v.voucher_type = 'Payment'
            AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
            AND v.date >= ? AND v.date <= ?
          GROUP BY vle.ledger_name
          HAVING total > 0
          ORDER BY total DESC LIMIT ?
        ''', [companyGuid, from, to, limit]);
        break;

      case ReportMetric.gst:
        rows = await db.rawQuery('''
          SELECT vie.stock_item_name as name,
            COALESCE(SUM(ABS(vie.gst_amount)), 0) as total
          FROM voucher_inventory_entries vie
          INNER JOIN vouchers v ON v.voucher_guid = vie.voucher_guid
          WHERE v.company_guid = ?
            AND v.voucher_type = 'Sales'
            AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
            AND v.date >= ? AND v.date <= ?
          GROUP BY vie.stock_item_name
          HAVING total > 0
          ORDER BY total DESC LIMIT ?
        ''', [companyGuid, from, to, limit]);
        break;

      case ReportMetric.stock:
        rows = await db.rawQuery('''
          SELECT si.name, COALESCE(cb.closing_value, 0) as total
          FROM stock_items si
          INNER JOIN (
            SELECT stock_item_guid, MAX(closing_date) AS latest_date
            FROM stock_item_closing_balance
            WHERE company_guid = ?
            GROUP BY stock_item_guid
          ) latest ON latest.stock_item_guid = si.stock_item_guid
          LEFT JOIN stock_item_closing_balance cb
            ON cb.stock_item_guid = latest.stock_item_guid
            AND cb.closing_date = latest.latest_date
            AND cb.company_guid = ?
          WHERE si.company_guid = ?
            AND si.is_deleted = 0
          ORDER BY COALESCE(cb.closing_value, 0) DESC LIMIT ?
        ''', [companyGuid, companyGuid, companyGuid, limit]);
        break;

      case ReportMetric.profit:
        // Profit = Sales - Purchase, no meaningful "top items" by ledger
        return [];
    }

    return rows.asMap().entries.map((entry) {
      final r = entry.value;
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      return TopSellingItem(
        rank: entry.key + 1,
        name: r['name']?.toString() ?? 'Unknown',
        unitsSold: 0,
        revenue: total,
        changePercent: 0.0,
        isPositive: total >= 0,
      );
    }).toList();
  } catch (_) {
    return [];
  }
}
  // ══════════════════════════════════════════════════════════════════
  //  OUTSTANDING HELPERS
  // ══════════════════════════════════════════════════════════════════

  Future<List<CreditLimitParty>> getCreditLimitExceeded({required String companyGuid}) async {
    try {
      final db = await _db.database;
      final dates = await _getCompanyDates();
      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT l.name, l.credit_limit,
          (l.opening_balance * -1) +
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)
          as outstanding
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
          AND l.credit_limit IS NOT NULL AND l.credit_limit > 0
        GROUP BY l.name, l.opening_balance, l.credit_limit
        HAVING outstanding > l.credit_limit
        ORDER BY outstanding DESC
      ''', [companyGuid, companyGuid, dates['from'], dates['to'], companyGuid]);
      return rows.map((r) {
        final balance = (r['outstanding'] as num?)?.toDouble() ?? 0;
        final limit = (r['credit_limit'] as num?)?.toDouble() ?? 0;
        return CreditLimitParty(
          name: r['name']?.toString() ?? '',
          currentOutstanding: balance,
          creditLimit: limit,
          daysOverLimit: 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PaymentDueParty>> getPaymentDueParties({required String companyGuid}) async {
    try {
      final db = await _db.database;
      final dates = await _getCompanyDates();
      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT l.name,
          (l.opening_balance * -1) +
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)
          as outstanding,
          MIN(v.date) as earliest_date
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        HAVING outstanding > 0
        ORDER BY outstanding DESC LIMIT 20
      ''', [companyGuid, companyGuid, dates['from'], dates['to'], companyGuid]);
      final now = DateTime.now();
      return rows.map((r) {
        final balance = (r['outstanding'] as num?)?.toDouble() ?? 0;
        final dateStr = r['earliest_date']?.toString();
        int daysOverdue = 0;
        DateTime? dueDate;
        if (dateStr != null && dateStr.length == 8) {
          // Tally YYYYMMDD format
          final y = int.tryParse(dateStr.substring(0, 4)) ?? 0;
          final m = int.tryParse(dateStr.substring(4, 6)) ?? 0;
          final d = int.tryParse(dateStr.substring(6, 8)) ?? 0;
          if (y > 0 && m > 0 && d > 0) {
            dueDate = DateTime(y, m, d);
            daysOverdue = now.difference(dueDate).inDays;
          }
        }
        return PaymentDueParty(
          name: r['name']?.toString() ?? '',
          amountDue: balance,
          dueDate: dueDate,
          daysOverdue: daysOverdue,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TopPayingParty>> getTopPayingParties({
    required String companyGuid,
    int limit = 10,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    return _topOutstandingParties(companyGuid, 'Sundry Debtors', from, to, limit, true);
  }

  Future<List<TopVendorParty>> getTopVendors({
    required String companyGuid,
    int limit = 10,
    
    
  }) async {
    final dates = await _getCompanyDates();
    final from = dates['from']!;
    final to = dates['to']!;
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors') AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT l.name,
          l.opening_balance +
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)
          as outstanding
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        HAVING outstanding > 0
        ORDER BY outstanding DESC LIMIT ?
      ''', [companyGuid, companyGuid, from, to, companyGuid, limit]);
      return rows.map((r) {
        final total = (r['outstanding'] as num?)?.toDouble() ?? 0;
        return TopVendorParty(name: r['name']?.toString() ?? '', amount: total);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<GroupOutstanding>> getReceivableGroups({
    required String companyGuid,
  }) async {
    final dates = await _getCompanyDates();
    return _outstandingGroups(companyGuid, 'Sundry Debtors', dates['from']!, dates['to']!, true);
  }

  Future<List<GroupOutstanding>> getPayableGroups({
    required String companyGuid,
  }) async {
    final dates = await _getCompanyDates();
    return _outstandingGroups(companyGuid, 'Sundry Creditors', dates['from']!, dates['to']!, false);
  }

  /// Get individual ledger parties within a specific parent group.
  Future<List<Map<String, dynamic>>> getPartiesInGroup({
    required String companyGuid,
    required String groupName,
  }) async {
    try {
      final db = await _db.database;
      final dates = await _getCompanyDates();
      final now = DateTime.now();

      // Use recursive group tree to find all sub-groups under groupName
      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (name = ? OR reserved_name = ?) AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT l.name,
          (l.opening_balance * -1) +
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)
          as outstanding,
          MIN(v.date) as earliest_date
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        HAVING ABS(outstanding) > 0
        ORDER BY ABS(outstanding) DESC
      ''', [companyGuid, groupName, groupName, companyGuid, dates['from'], dates['to'], companyGuid]);

      return rows.map((r) {
        final amount = (r['outstanding'] as num?)?.toDouble() ?? 0;
        final dateStr = r['earliest_date']?.toString();
        int days = 0;
        if (dateStr != null && dateStr.length == 8) {
          final y = int.tryParse(dateStr.substring(0, 4)) ?? 0;
          final m = int.tryParse(dateStr.substring(4, 6)) ?? 0;
          final d = int.tryParse(dateStr.substring(6, 8)) ?? 0;
          if (y > 0 && m > 0 && d > 0) {
            days = now.difference(DateTime(y, m, d)).inDays;
          }
        }
        return {
          'name': r['name']?.toString() ?? '',
          'amount': amount.abs(),
          'days': days,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get the sum of pending (positive outstanding) and advance (negative outstanding)
  /// ledgers within a parent group, using proper outstanding calculation.
  Future<Map<String, double>> getOutstandingBreakdown({
    required String companyGuid,
    required String parentGroup,
  }) async {
    try {
      final db = await _db.database;
      final dates = await _getCompanyDates();
      final isReceivable = parentGroup.contains('Debtor');

      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (name = ? OR reserved_name = ?) AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT
          ${isReceivable ? '''
          (l.opening_balance * -1) +
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)
          ''' : '''
          l.opening_balance +
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)
          '''} as outstanding
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
      ''', [companyGuid, parentGroup, parentGroup, companyGuid, dates['from'], dates['to'], companyGuid]);

      double pending = 0;
      double advance = 0;
      for (final r in rows) {
        final outstanding = (r['outstanding'] as num?)?.toDouble() ?? 0;
        if (outstanding > 0) {
          pending += outstanding;
        } else {
          advance += outstanding.abs();
        }
      }
      return {'pending': pending, 'advance': advance};
    } catch (_) {
      return {'pending': 0, 'advance': 0};
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  PRIVATE: Monthly trend for Sales/Purchase group accounts
  // ══════════════════════════════════════════════════════════════════

  Future<ReportChartData> _salesGroupMonthlyTrend(
    String companyGuid, String reservedName, String fromDate, String toDate, {
    String? title, ReportChartType? chartType,
  }) async {
    final ct = chartType ?? ReportChartType.bar;
    final chartTitle = title ?? '$reservedName Trend';
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND reserved_name = ? AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT SUBSTR(v.date, 1, 6) as month,
          COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) -
          SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as total
        FROM voucher_ledger_entries vle
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
        INNER JOIN group_tree gt ON l.parent = gt.name
        WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0
          AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
        GROUP BY month ORDER BY month
      ''', [companyGuid, reservedName, companyGuid, companyGuid, fromDate, toDate]);
      return ReportChartData(
        dataPoints: rows.map((r) => ChartDataPoint(
          label: r['month']?.toString() ?? '',
          value: (r['total'] as num?)?.toDouble() ?? 0,
        )).toList(),
        chartType: ct,
        title: chartTitle,
        legends: [ChartLegendItem(label: chartTitle, color: Colors.blue)],
      );
    } catch (_) {
      return ReportChartData(dataPoints: const [], chartType: ct, title: chartTitle);
    }
  }

  Future<ReportChartData> _purchaseGroupMonthlyTrend(
    String companyGuid, String reservedName, String fromDate, String toDate, {
    String? title, ReportChartType? chartType,
  }) async {
    final ct = chartType ?? ReportChartType.bar;
    final chartTitle = title ?? '$reservedName Trend';
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND reserved_name = ? AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT SUBSTR(v.date, 1, 6) as month,
          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
          SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total
        FROM voucher_ledger_entries vle
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
        INNER JOIN group_tree gt ON l.parent = gt.name
        WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0
          AND v.is_optional = 0 AND v.date >= ? AND v.date <= ?
        GROUP BY month ORDER BY month
      ''', [companyGuid, reservedName, companyGuid, companyGuid, fromDate, toDate]);
      return ReportChartData(
        dataPoints: rows.map((r) => ChartDataPoint(
          label: r['month']?.toString() ?? '',
          value: (r['total'] as num?)?.toDouble() ?? 0,
        )).toList(),
        chartType: ct,
        title: chartTitle,
        legends: [ChartLegendItem(label: chartTitle, color: Colors.blue)],
      );
    } catch (_) {
      return ReportChartData(dataPoints: const [], chartType: ct, title: chartTitle);
    }
  }

  Future<ReportChartData> _voucherTypeMonthlyTrend(
    String companyGuid, String voucherType, String fromDate, String toDate, {
    required String field, required String table,
    String? title, ReportChartType? chartType,
  }) async {
    final ct = chartType ?? ReportChartType.bar;
    final chartTitle = title ?? '$voucherType Trend';
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT SUBSTR(v.date, 1, 6) as month, COALESCE(SUM(ABS(e.$field)), 0) as total
        FROM $table e
        INNER JOIN vouchers v ON v.voucher_guid = e.voucher_guid
        WHERE v.company_guid = ? AND v.voucher_type = ?
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        GROUP BY month ORDER BY month
      ''', [companyGuid, voucherType, fromDate, toDate]);
      return ReportChartData(
        dataPoints: rows.map((r) => ChartDataPoint(
          label: r['month']?.toString() ?? '',
          value: (r['total'] as num?)?.toDouble() ?? 0,
        )).toList(),
        chartType: ct,
        title: chartTitle,
        legends: [ChartLegendItem(label: chartTitle, color: Colors.blue)],
      );
    } catch (_) {
      return ReportChartData(dataPoints: const [], chartType: ct, title: chartTitle);
    }
  }

  Future<ReportChartData> _receiptPaymentMonthlyTrend(
    String companyGuid, String voucherType, String fromDate, String toDate, {
    required bool isPositive, String? title, ReportChartType? chartType,
  }) async {
    final ct = chartType ?? ReportChartType.bar;
    final chartTitle = title ?? '$voucherType Trend';
    final amountExpr = isPositive
        ? 'SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)'
        : 'SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)';
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT SUBSTR(v.date, 1, 6) as month, COALESCE($amountExpr, 0) as total
        FROM vouchers v
        INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ? AND v.voucher_type = ?
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        GROUP BY month ORDER BY month
      ''', [companyGuid, voucherType, fromDate, toDate]);
      return ReportChartData(
        dataPoints: rows.map((r) => ChartDataPoint(
          label: r['month']?.toString() ?? '',
          value: (r['total'] as num?)?.toDouble() ?? 0,
        )).toList(),
        chartType: ct,
        title: chartTitle,
        legends: [ChartLegendItem(label: chartTitle, color: Colors.blue)],
      );
    } catch (_) {
      return ReportChartData(dataPoints: const [], chartType: ct, title: chartTitle);
    }
  }

  Future<ReportChartData> _outstandingChart(
    String companyGuid, String groupName, String fromDate, String toDate, {
    required String title, required bool isReceivable, ReportChartType? chartType,
  }) async {
    final ct = chartType ?? ReportChartType.bar;
    try {
      final db = await _db.database;
      final outstandingExpr = isReceivable
          ? '''(l.opening_balance * -1) +
              COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
              COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)'''
          : '''l.opening_balance +
              COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
              COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)''';

      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (name = ? OR reserved_name = ?) AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT l.name as label, $outstandingExpr as value
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        HAVING value > 0
        ORDER BY value DESC LIMIT 10
      ''', [companyGuid, groupName, groupName, companyGuid, fromDate, toDate, companyGuid]);
      return ReportChartData(
        dataPoints: rows.map((r) => ChartDataPoint(
          label: r['label']?.toString() ?? '',
          value: (r['value'] as num?)?.toDouble() ?? 0,
        )).toList(),
        chartType: ct,
        title: title,
        legends: [ChartLegendItem(label: groupName, color: Colors.blue)],
      );
    } catch (_) {
      return ReportChartData(dataPoints: const [], chartType: ct, title: title);
    }
  }

  // ── Top outstanding parties helper ────────────────────────────
  Future<List<TopPayingParty>> _topOutstandingParties(
    String companyGuid, String groupName, String fromDate, String toDate, int limit, bool isReceivable,
  ) async {
    try {
      final db = await _db.database;
      final outstandingExpr = isReceivable
          ? '''(l.opening_balance * -1) +
              COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
              COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)'''
          : '''l.opening_balance +
              COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
              COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)''';

      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (name = ? OR reserved_name = ?) AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT l.name, $outstandingExpr as outstanding
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid AND v.is_deleted = 0
          AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.opening_balance
        HAVING outstanding > 0
        ORDER BY outstanding DESC LIMIT ?
      ''', [companyGuid, groupName, groupName, companyGuid, fromDate, toDate, companyGuid, limit]);
      return rows.map((r) {
        final total = (r['outstanding'] as num?)?.toDouble() ?? 0;
        return TopPayingParty(name: r['name']?.toString() ?? '', amount: total);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Outstanding groups (sub-groups under Sundry Debtors/Creditors) ──
  Future<List<GroupOutstanding>> _outstandingGroups(
    String companyGuid, String parentGroupName, String fromDate, String toDate, bool isReceivable,
  ) async {
    try {
      final db = await _db.database;
      // Find direct child groups under the parent, then compute outstanding per group
      final outstandingExpr = isReceivable
          ? '''(l.opening_balance * -1) +
              COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
              COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)'''
          : '''l.opening_balance +
              COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
              COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)''';

      // First get ledgers directly under the parent group
      final rows = await db.rawQuery('''
        WITH RECURSIVE group_tree AS (
          SELECT group_guid, name FROM groups
          WHERE company_guid = ? AND (name = ? OR reserved_name = ?) AND is_deleted = 0
          UNION ALL
          SELECT g.group_guid, g.name FROM groups g
          INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
          WHERE g.company_guid = ? AND g.is_deleted = 0
        )
        SELECT l.parent as group_name,
          SUM(CASE WHEN sub.outstanding > 0 THEN sub.outstanding ELSE 0 END) as total_amount,
          COUNT(*) as party_count
        FROM (
          SELECT l.name, l.parent, $outstandingExpr as outstanding
          FROM ledgers l
          INNER JOIN group_tree gt ON l.parent = gt.name
          LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
          LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
            AND v.company_guid = l.company_guid AND v.is_deleted = 0
            AND v.is_cancelled = 0 AND v.is_optional = 0
            AND v.date >= ? AND v.date <= ?
          WHERE l.company_guid = ? AND l.is_deleted = 0
          GROUP BY l.name, l.parent, l.opening_balance
          HAVING outstanding > 0
        ) sub
        LEFT JOIN ledgers l ON l.name = sub.name AND l.company_guid = ?
        GROUP BY l.parent
        ORDER BY total_amount DESC
      ''', [companyGuid, parentGroupName, parentGroupName, companyGuid,
            fromDate, toDate, companyGuid, companyGuid]);

      return rows.map((r) => GroupOutstanding(
        groupName: r['group_name']?.toString() ?? parentGroupName,
        amount: (r['total_amount'] as num?)?.toDouble() ?? 0,
        partyCount: (r['party_count'] as int?) ?? 0,
      )).toList();
    } catch (_) {
      return [];
    }
  }



}
