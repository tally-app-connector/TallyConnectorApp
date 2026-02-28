// services/analytics_service.dart

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class AnalyticsService {
  final _db = DatabaseHelper.instance;

  // ==================== SUMMARY ANALYTICS ====================

  /// Get sales summary (CORRECT calculation from voucher details)
  Future<Map<String, dynamic>> getSalesSummary(
    String companyGuid, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND v.date >= ? AND v.date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    // ✅ CORRECT: Calculate from inventory entries (actual items sold)
    final salesResult = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT v.voucher_guid) as total_invoices,
        SUM(vie.amount) as total_sales,
        AVG(invoice_totals.total) as avg_invoice_value
      FROM vouchers v
      INNER JOIN voucher_inventory_entries vie ON v.voucher_guid = vie.voucher_guid
      LEFT JOIN (
        SELECT voucher_guid, SUM(amount) as total
        FROM voucher_inventory_entries
        GROUP BY voucher_guid
      ) invoice_totals ON v.voucher_guid = invoice_totals.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Sales'
        AND v.is_deleted = 0
        $dateFilter
    ''', args);
    
    // Get GST collected
    final gstResult = await db.rawQuery('''
      SELECT 
        SUM(COALESCE(vie.cgst_amount, 0)) as total_cgst,
        SUM(COALESCE(vie.sgst_amount, 0)) as total_sgst,
        SUM(COALESCE(vie.igst_amount, 0)) as total_igst,
        SUM(COALESCE(vie.cess_amount, 0)) as total_cess
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Sales'
        AND v.is_deleted = 0
        $dateFilter
    ''', args);
    
    // Top selling items (by value)
    final topItems = await db.rawQuery('''
      SELECT 
        vie.stock_item_name,
        vie.hsn_code,
        SUM(CAST(REPLACE(REPLACE(vie.actual_qty, ' ', ''), 'NOS', '') AS REAL)) as total_qty,
        SUM(vie.amount) as total_amount,
        COUNT(DISTINCT v.voucher_guid) as invoice_count,
        AVG(CAST(REPLACE(REPLACE(vie.rate, ' ', ''), '/NOS', '') AS REAL)) as avg_rate
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Sales'
        AND v.is_deleted = 0
        $dateFilter
      GROUP BY vie.stock_item_name, vie.hsn_code
      ORDER BY total_amount DESC
      LIMIT 10
    ''', args);
    
    // Top customers (by value)
    final topCustomers = await db.rawQuery('''
      SELECT 
        v.party_ledger_name,
        v.party_gstin,
        COUNT(DISTINCT v.voucher_guid) as invoice_count,
        SUM(invoice_totals.total) as total_amount
      FROM vouchers v
      INNER JOIN (
        SELECT voucher_guid, SUM(amount) as total
        FROM voucher_inventory_entries
        GROUP BY voucher_guid
      ) invoice_totals ON v.voucher_guid = invoice_totals.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Sales'
        AND v.is_deleted = 0
        AND v.party_ledger_name IS NOT NULL
        $dateFilter
      GROUP BY v.party_ledger_name, v.party_gstin
      ORDER BY total_amount DESC
      LIMIT 10
    ''', args);
    
    final totalSales = (salesResult.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalCGST = (gstResult.first['total_cgst'] as num?)?.toDouble() ?? 0.0;
    final totalSGST = (gstResult.first['total_sgst'] as num?)?.toDouble() ?? 0.0;
    final totalIGST = (gstResult.first['total_igst'] as num?)?.toDouble() ?? 0.0;
    final totalCess = (gstResult.first['total_cess'] as num?)?.toDouble() ?? 0.0;
    
    final totalGST = totalCGST + totalSGST + totalIGST + totalCess;
    
    return {
      'total_invoices': (salesResult.first['total_invoices'] as int?) ?? 0,
      'total_sales': totalSales, // Before GST
      'total_gst': totalGST,
      'total_sales_with_gst': totalSales + totalGST, // After GST
      'avg_invoice_value': (salesResult.first['avg_invoice_value'] as num?)?.toDouble() ?? 0.0,
      'gst_breakdown': {
        'cgst': totalCGST,
        'sgst': totalSGST,
        'igst': totalIGST,
        'cess': totalCess,
      },
      'top_selling_items': topItems,
      'top_customers': topCustomers,
    };
  }

  // ==================== PURCHASE ANALYTICS (CORRECTED) ====================
  
  /// Get purchase summary (CORRECT calculation from voucher details)
  Future<Map<String, dynamic>> getPurchaseSummary(
    String companyGuid, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND v.date >= ? AND v.date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    // ✅ CORRECT: Calculate from inventory entries
    final purchaseResult = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT v.voucher_guid) as total_bills,
        SUM(vie.amount) as total_purchase,
        AVG(bill_totals.total) as avg_bill_value
      FROM vouchers v
      INNER JOIN voucher_inventory_entries vie ON v.voucher_guid = vie.voucher_guid
      LEFT JOIN (
        SELECT voucher_guid, SUM(amount) as total
        FROM voucher_inventory_entries
        GROUP BY voucher_guid
      ) bill_totals ON v.voucher_guid = bill_totals.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Purchase'
        AND v.is_deleted = 0
        $dateFilter
    ''', args);
    
    // Get GST paid
    final gstResult = await db.rawQuery('''
      SELECT 
        SUM(COALESCE(vie.cgst_amount, 0)) as total_cgst,
        SUM(COALESCE(vie.sgst_amount, 0)) as total_sgst,
        SUM(COALESCE(vie.igst_amount, 0)) as total_igst,
        SUM(COALESCE(vie.cess_amount, 0)) as total_cess
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Purchase'
        AND v.is_deleted = 0
        $dateFilter
    ''', args);
    
    // Top purchased items
    final topItems = await db.rawQuery('''
      SELECT 
        vie.stock_item_name,
        vie.hsn_code,
        SUM(CAST(REPLACE(REPLACE(vie.actual_qty, ' ', ''), 'NOS', '') AS REAL)) as total_qty,
        SUM(vie.amount) as total_amount,
        COUNT(DISTINCT v.voucher_guid) as bill_count,
        AVG(CAST(REPLACE(REPLACE(vie.rate, ' ', ''), '/NOS', '') AS REAL)) as avg_rate
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Purchase'
        AND v.is_deleted = 0
        $dateFilter
      GROUP BY vie.stock_item_name, vie.hsn_code
      ORDER BY total_amount DESC
      LIMIT 10
    ''', args);
    
    // Top suppliers (by value)
    final topSuppliers = await db.rawQuery('''
      SELECT 
        v.party_ledger_name,
        v.party_gstin,
        COUNT(DISTINCT v.voucher_guid) as bill_count,
        SUM(bill_totals.total) as total_amount
      FROM vouchers v
      INNER JOIN (
        SELECT voucher_guid, SUM(amount) as total
        FROM voucher_inventory_entries
        GROUP BY voucher_guid
      ) bill_totals ON v.voucher_guid = bill_totals.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Purchase'
        AND v.is_deleted = 0
        AND v.party_ledger_name IS NOT NULL
        $dateFilter
      GROUP BY v.party_ledger_name, v.party_gstin
      ORDER BY total_amount DESC
      LIMIT 10
    ''', args);
    
    final totalPurchase = (purchaseResult.first['total_purchase'] as num?)?.toDouble() ?? 0.0;
    final totalCGST = (gstResult.first['total_cgst'] as num?)?.toDouble() ?? 0.0;
    final totalSGST = (gstResult.first['total_sgst'] as num?)?.toDouble() ?? 0.0;
    final totalIGST = (gstResult.first['total_igst'] as num?)?.toDouble() ?? 0.0;
    final totalCess = (gstResult.first['total_cess'] as num?)?.toDouble() ?? 0.0;
    
    final totalGST = totalCGST + totalSGST + totalIGST + totalCess;
    
    return {
      'total_bills': (purchaseResult.first['total_bills'] as int?) ?? 0,
      'total_purchase': totalPurchase, // Before GST
      'total_gst': totalGST,
      'total_purchase_with_gst': totalPurchase + totalGST, // After GST
      'avg_bill_value': (purchaseResult.first['avg_bill_value'] as num?)?.toDouble() ?? 0.0,
      'gst_breakdown': {
        'cgst': totalCGST,
        'sgst': totalSGST,
        'igst': totalIGST,
        'cess': totalCess,
      },
      'top_purchased_items': topItems,
      'top_suppliers': topSuppliers,
    };
  }

  // ==================== PROFIT & LOSS (CORRECTED) ====================
  
  /// Get P&L summary (CORRECT calculation)
  Future<Map<String, dynamic>> getProfitLossSummary(
    String companyGuid, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND v.date >= ? AND v.date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    // ✅ Sales (from inventory entries)
    final salesResult = await db.rawQuery('''
      SELECT SUM(vie.amount) as total
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Sales'
        AND v.is_deleted = 0
        $dateFilter
    ''', args);
    
    // ✅ Purchase (from inventory entries)
    final purchaseResult = await db.rawQuery('''
      SELECT SUM(vie.amount) as total
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Purchase'
        AND v.is_deleted = 0
        $dateFilter
    ''', args);
    
    // Get other expenses (from ledger entries - expense groups)
    final expensesResult = await db.rawQuery('''
      SELECT SUM(ABS(vle.amount)) as total
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON vle.voucher_guid = v.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN groups g ON g.name = l.parent AND g.company_guid = l.company_guid
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND g.name IN ('Direct Expenses', 'Indirect Expenses', 'Expenses (Direct)', 'Expenses (Indirect)')
        $dateFilter
    ''', args);
    
    final sales = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final purchase = (purchaseResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final expenses = (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    
    final grossProfit = sales - purchase;
    final netProfit = grossProfit - expenses;
    final grossMargin = sales > 0 ? (grossProfit / sales * 100) : 0.0;
    final netMargin = sales > 0 ? (netProfit / sales * 100) : 0.0;
    
    return {
      'sales': sales,
      'purchase': purchase,
      'gross_profit': grossProfit,
      'gross_margin_percentage': grossMargin,
      'other_expenses': expenses,
      'net_profit': netProfit,
      'net_margin_percentage': netMargin,
    };
  }

  // ==================== VOUCHER-WISE BREAKDOWN ====================
  
  /// Get detailed voucher breakdown
  Future<Map<String, dynamic>> getVoucherBreakdown(
    String companyGuid, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND v.date >= ? AND v.date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    // Get breakdown by voucher type
    final breakdown = await db.rawQuery('''
      SELECT 
        v.voucher_type,
        COUNT(DISTINCT v.voucher_guid) as count,
        SUM(COALESCE(totals.total, 0)) as total_amount,
        AVG(COALESCE(totals.total, 0)) as avg_amount
      FROM vouchers v
      LEFT JOIN (
        SELECT voucher_guid, SUM(amount) as total
        FROM voucher_inventory_entries
        GROUP BY voucher_guid
      ) totals ON v.voucher_guid = totals.voucher_guid
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        $dateFilter
      GROUP BY v.voucher_type
      ORDER BY total_amount DESC
    ''', args);
    
    return {
      'breakdown': breakdown,
    };
  }

  // ==================== ITEM-WISE PROFIT ====================
  
  /// Get item-wise profit (if you track purchase price)
  Future<List<Map<String, dynamic>>> getItemWiseProfit(
    String companyGuid, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND v.date >= ? AND v.date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    return await db.rawQuery('''
      SELECT 
        stock_item_name,
        sales.total_sales_amount,
        sales.total_sales_qty,
        purchase.total_purchase_amount,
        purchase.total_purchase_qty,
        (sales.total_sales_amount - COALESCE(purchase.total_purchase_amount, 0)) as profit,
        CASE 
          WHEN sales.total_sales_amount > 0 
          THEN ((sales.total_sales_amount - COALESCE(purchase.total_purchase_amount, 0)) / sales.total_sales_amount * 100)
          ELSE 0 
        END as profit_margin
      FROM (
        SELECT 
          vie.stock_item_name,
          SUM(vie.amount) as total_sales_amount,
          SUM(CAST(REPLACE(REPLACE(vie.actual_qty, ' ', ''), 'NOS', '') AS REAL)) as total_sales_qty
        FROM voucher_inventory_entries vie
        INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
        WHERE v.company_guid = ?
          AND v.voucher_type = 'Sales'
          AND v.is_deleted = 0
          $dateFilter
        GROUP BY vie.stock_item_name
      ) sales
      LEFT JOIN (
        SELECT 
          vie.stock_item_name,
          SUM(vie.amount) as total_purchase_amount,
          SUM(CAST(REPLACE(REPLACE(vie.actual_qty, ' ', ''), 'NOS', '') AS REAL)) as total_purchase_qty
        FROM voucher_inventory_entries vie
        INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
        WHERE v.company_guid = ?
          AND v.voucher_type = 'Purchase'
          AND v.is_deleted = 0
          $dateFilter
        GROUP BY vie.stock_item_name
      ) purchase ON sales.stock_item_name = purchase.stock_item_name
      ORDER BY profit DESC
    ''', [...args, ...args]);
  }
  
  /// Get overall business summary
  Future<Map<String, dynamic>> getBusinessSummary(String companyGuid) async {
    final db = await _db.database;
    
    // Total counts
    final groupCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM groups WHERE company_guid = ? AND is_deleted = 0',
      [companyGuid]
    );
    
    final ledgerCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ledgers WHERE company_guid = ? AND is_deleted = 0',
      [companyGuid]
    );
    
    final stockItemCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM stock_items WHERE company_guid = ? AND is_deleted = 0',
      [companyGuid]
    );
    
    final voucherCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM vouchers WHERE company_guid = ? AND is_deleted = 0',
      [companyGuid]
    );
    
    return {
      'total_groups': (groupCount.first['count'] as int?) ?? 0,
      'total_ledgers': (ledgerCount.first['count'] as int?) ?? 0,
      'total_stock_items': (stockItemCount.first['count'] as int?) ?? 0,
      'total_vouchers': (voucherCount.first['count'] as int?) ?? 0,
    };
  }

  // ==================== SALES ANALYTICS ====================
  

  /// Get sales trend (day-wise, month-wise, year-wise)
  Future<List<Map<String, dynamic>>> getSalesTrend(
    String companyGuid, {
    required String groupBy, // 'day', 'month', 'year'
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateGrouping;
    switch (groupBy) {
      case 'day':
        dateGrouping = 'date';
        break;
      case 'month':
        dateGrouping = "substr(date, 1, 6) || '01'"; // YYYYMM01
        break;
      case 'year':
        dateGrouping = "substr(date, 1, 4) || '0101'"; // YYYY0101
        break;
      default:
        dateGrouping = 'date';
    }
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND date >= ? AND date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    return await db.rawQuery('''
      SELECT 
        $dateGrouping as period,
        COUNT(*) as invoice_count,
        SUM(ABS(amount)) as total_sales
      FROM vouchers
      WHERE company_guid = ?
        AND voucher_type = 'Sales'
        AND is_deleted = 0
        $dateFilter
      GROUP BY $dateGrouping
      ORDER BY period ASC
    ''', args);
  }

  // ==================== GROUP-WISE ANALYSIS ====================
  
  /// Get group-wise ledger summary
  Future<List<Map<String, dynamic>>> getGroupWiseSummary(String companyGuid) async {
    final db = await _db.database;
    
    return await db.rawQuery('''
      SELECT 
        g.name as group_name,
        g.parent as parent_group,
        COUNT(DISTINCT l.ledger_guid) as ledger_count,
        SUM(l.opening_balance) as total_opening_balance,
        SUM(l.closing_balance) as total_closing_balance
      FROM groups g
      LEFT JOIN ledgers l ON l.parent = g.name AND l.company_guid = g.company_guid
      WHERE g.company_guid = ? AND g.is_deleted = 0
      GROUP BY g.name, g.parent
      ORDER BY ledger_count DESC
    ''', [companyGuid]);
  }

  // ==================== LEDGER-WISE ANALYSIS ====================
  
  /// Get ledger balances
  Future<List<Map<String, dynamic>>> getLedgerBalances(
    String companyGuid, {
    String? groupName,
  }) async {
    final db = await _db.database;
    
    String groupFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (groupName != null) {
      groupFilter = ' AND parent = ?';
      args.add(groupName);
    }
    
    return await db.rawQuery('''
      SELECT 
        name,
        parent,
        opening_balance,
        closing_balance,
        (closing_balance - opening_balance) as net_change
      FROM ledgers
      WHERE company_guid = ?
        AND is_deleted = 0
        $groupFilter
      ORDER BY ABS(closing_balance) DESC
    ''', args);
  }

  /// Get party outstanding (receivables/payables)
  Future<List<Map<String, dynamic>>> getPartyOutstanding(
    String companyGuid, {
    String type = 'receivable', // 'receivable' or 'payable'
  }) async {
    final db = await _db.database;
    
    final condition = type == 'receivable' ? '> 0' : '< 0';
    
    return await db.rawQuery('''
      SELECT 
        name as party_name,
        closing_balance as outstanding_amount,
        email,
        ledger_mobile as phone,
        bill_credit_period
      FROM ledgers
      WHERE company_guid = ?
        AND is_deleted = 0
        AND closing_balance $condition
      ORDER BY ABS(closing_balance) DESC
    ''', [companyGuid]);
  }

  // ==================== STOCK ANALYSIS ====================
  
  /// Get stock summary
  Future<Map<String, dynamic>> getStockSummary(String companyGuid) async {
    final db = await _db.database;
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_items,
        SUM(opening_value) as total_stock_value,
        SUM(CASE WHEN opening_balance < 0 THEN 1 ELSE 0 END) as negative_stock_items
      FROM stock_items
      WHERE company_guid = ? AND is_deleted = 0
    ''', [companyGuid]);
    
    // Low stock items (less than 10% of opening balance)
    final lowStock = await db.rawQuery('''
      SELECT name, opening_balance, base_units
      FROM stock_items
      WHERE company_guid = ?
        AND is_deleted = 0
        AND opening_balance > 0
        AND opening_balance < 10
      ORDER BY opening_balance ASC
      LIMIT 20
    ''', [companyGuid]);
    
    return {
      'total_items': (result.first['total_items'] as int?) ?? 0,
      'total_value': (result.first['total_stock_value'] as num?)?.toDouble() ?? 0.0,
      'negative_stock_items': (result.first['negative_stock_items'] as int?) ?? 0,
      'low_stock_items': lowStock,
    };
  }

  /// Get stock movement (fast/slow moving)
  Future<List<Map<String, dynamic>>> getStockMovement(
    String companyGuid, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND v.date >= ? AND v.date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    return await db.rawQuery('''
      SELECT 
        vie.stock_item_name,
        si.base_units,
        SUM(CAST(REPLACE(vie.actual_qty, ' ', '') AS REAL)) as total_qty_sold,
        SUM(vie.amount) as total_value_sold,
        COUNT(DISTINCT v.voucher_guid) as transaction_count
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      LEFT JOIN stock_items si ON si.name = vie.stock_item_name AND si.company_guid = v.company_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Sales'
        AND v.is_deleted = 0
        $dateFilter
      GROUP BY vie.stock_item_name, si.base_units
      ORDER BY total_value_sold DESC
    ''', args);
  }

  // ==================== GST ANALYSIS ====================
  
  /// Get GST summary
  Future<Map<String, dynamic>> getGSTSummary(
    String companyGuid, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND date >= ? AND date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    // Sales GST (Output)
    final salesGST = await db.rawQuery('''
      SELECT 
        SUM(cgst_amount) as total_cgst,
        SUM(sgst_amount) as total_sgst,
        SUM(igst_amount) as total_igst
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Sales'
        AND v.is_deleted = 0
        $dateFilter
    ''', args);
    
    // Purchase GST (Input)
    final purchaseGST = await db.rawQuery('''
      SELECT 
        SUM(cgst_amount) as total_cgst,
        SUM(sgst_amount) as total_sgst,
        SUM(igst_amount) as total_igst
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON vie.voucher_guid = v.voucher_guid
      WHERE v.company_guid = ?
        AND v.voucher_type = 'Purchase'
        AND v.is_deleted = 0
        $dateFilter
    ''', args);
    
    final outputCGST = (salesGST.first['total_cgst'] as num?)?.toDouble() ?? 0.0;
    final outputSGST = (salesGST.first['total_sgst'] as num?)?.toDouble() ?? 0.0;
    final outputIGST = (salesGST.first['total_igst'] as num?)?.toDouble() ?? 0.0;
    
    final inputCGST = (purchaseGST.first['total_cgst'] as num?)?.toDouble() ?? 0.0;
    final inputSGST = (purchaseGST.first['total_sgst'] as num?)?.toDouble() ?? 0.0;
    final inputIGST = (purchaseGST.first['total_igst'] as num?)?.toDouble() ?? 0.0;
    
    return {
      'output_gst': {
        'cgst': outputCGST,
        'sgst': outputSGST,
        'igst': outputIGST,
        'total': outputCGST + outputSGST + outputIGST,
      },
      'input_gst': {
        'cgst': inputCGST,
        'sgst': inputSGST,
        'igst': inputIGST,
        'total': inputCGST + inputSGST + inputIGST,
      },
      'net_gst_payable': (outputCGST + outputSGST + outputIGST) - 
                         (inputCGST + inputSGST + inputIGST),
    };
  }

  // ==================== VOUCHER ANALYSIS ====================
  
  /// Get voucher type summary
  Future<List<Map<String, dynamic>>> getVoucherTypeSummary(
    String companyGuid, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    
    String dateFilter = '';
    List<dynamic> args = [companyGuid];
    
    if (fromDate != null && toDate != null) {
      dateFilter = ' AND date >= ? AND date <= ?';
      args.addAll([fromDate, toDate]);
    }
    
    return await db.rawQuery('''
      SELECT 
        voucher_type,
        COUNT(*) as count,
        SUM(ABS(amount)) as total_amount
      FROM vouchers
      WHERE company_guid = ?
        AND is_deleted = 0
        $dateFilter
      GROUP BY voucher_type
      ORDER BY count DESC
    ''', args);
  }
}