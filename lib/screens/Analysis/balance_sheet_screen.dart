// balance_sheet_combined.dart
// This file combines: BalanceSheetScreen, BalanceSheetDetailScreen, and LedgerTransactionsScreen

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../theme/app_theme.dart';

// ============================================================================
// MAIN BALANCE SHEET SCREEN
// ============================================================================

class BalanceSheetScreen extends StatefulWidget {
  @override
  _BalanceSheetScreenState createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  final _db = DatabaseHelper.instance;

  String? _companyGuid;
  String? _companyName;
  bool _loading = true;

  Map<String, dynamic>? _bsData;
  String _fromDate = '20250401';
  String _toDate = '20260331';

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

    if (_selectedFromDate == null || _selectedToDate == null) {
      _fromDate = company['starting_from'] as String? ?? _fromDate;
      _toDate = company['ending_at'] as String? ?? _toDate;
      _selectedFromDate = _parseTallyDate(_fromDate);
      _selectedToDate = _parseTallyDate(_toDate);
    }

    final bsData =
        await _getBalanceSheetSummary(_companyGuid!, _fromDate, _toDate);

    setState(() {
      _bsData = bsData;
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
    return DateFormat('yyyyMMdd').format(date);
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
        final dk = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: dk
                ? ColorScheme.dark(primary: Colors.blue, onPrimary: Colors.white, surface: AppColors.surface, onSurface: AppColors.textPrimary)
                : ColorScheme.light(primary: Colors.blue, onPrimary: Colors.white),
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

  Future<Map<String, dynamic>> _getBalanceSheetSummary(
    String companyGuid,
    String fromDate,
    String toDate,
  ) async {
    final db = await _db.database;

    print('\n=== BALANCE SHEET SUMMARY DEBUG ===');
    print('Company GUID: $companyGuid');
    print('From Date: $fromDate');
    print('To Date: $toDate');

    // Helper function to get group closing balance AS AT the toDate
    Future<double> _getGroupBalance(List<String> groupNames) async {
  print('\n--- Getting Balance for Groups: ${groupNames.join(", ")} ---');
  
  final result = await db.rawQuery('''
    WITH RECURSIVE group_tree AS (
      SELECT group_guid, name
      FROM groups
      WHERE company_guid = ?
        AND name IN (${groupNames.map((_) => '?').join(',')})
        AND is_deleted = 0
      
      UNION ALL
      
      SELECT g.group_guid, g.name
      FROM groups g
      INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
      WHERE g.company_guid = ?
        AND g.is_deleted = 0
    ),
    ledger_transactions AS (
      SELECT 
        vle.ledger_name,
        SUM(vle.amount) as transaction_sum
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
        AND v.date <= ?
      GROUP BY vle.ledger_name
    ),
    ledger_balances AS (
      SELECT 
        l.name as ledger_name,
        l.ledger_guid,
        l.parent as group_name,
        l.opening_balance,
        COALESCE(lt.transaction_sum, 0) as transaction_sum,
        l.opening_balance + COALESCE(lt.transaction_sum, 0) as closing_balance
      FROM ledgers l
      INNER JOIN group_tree gt ON l.parent = gt.name
      LEFT JOIN ledger_transactions lt ON lt.ledger_name = l.name
      WHERE l.company_guid = ?
        AND l.is_deleted = 0
    )
    SELECT 
      ledger_name,
      group_name,
      opening_balance,
      transaction_sum,
      closing_balance,
      (SELECT COALESCE(SUM(closing_balance), 0) FROM ledger_balances) as total
    FROM ledger_balances
  ''', [
    companyGuid, ...groupNames, companyGuid,  // group_tree
    companyGuid, toDate,  // ledger_transactions
    companyGuid,  // ledger_balances WHERE
  ]);

  if (result.isNotEmpty) {
    final total = (result.first['total'] as num?)?.toDouble() ?? 0.0;
    print('Found ${result.length} ledgers under these groups:');
    for (var ledger in result) {
      print('  - ${ledger['ledger_name']} (${ledger['group_name']}): Opening=${ledger['opening_balance']}, Txn=${ledger['transaction_sum']}, Closing=${ledger['closing_balance']}');
    }
    print('Total for ${groupNames.join(", ")}: $total');
    return total;
  }

  print('No ledgers found for ${groupNames.join(", ")}');
  return 0.0;
}

    // Calculate Liabilities - Use only TOP-LEVEL group names
    final capital = await _getGroupBalance(['Capital Account']);
    final loans = await _getGroupBalance(['Loans (Liability)']);
    final currentLiabilities = await _getGroupBalance(['Current Liabilities']);

    // Calculate Profit & Loss from P&L statement components
    final plCalculation = await db.rawQuery('''
  WITH 
  -- Sales (Revenue)
  sales_data AS (
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
      COALESCE(SUM(vle.amount), 0) as total_sales
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
  ),
  -- Purchase
  purchase_data AS (
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
      COALESCE(SUM(vle.amount), 0) as total_purchase
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
  ),
  -- Direct Expenses
  direct_expenses_data AS (
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
      COALESCE(SUM(vle.amount), 0) as total_direct_expenses
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
  ),
  -- Direct Incomes
  direct_incomes_data AS (
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
      COALESCE(SUM(vle.amount), 0) as total_direct_incomes
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
  ),
  -- Indirect Expenses
  indirect_expenses_data AS (
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
      COALESCE(SUM(vle.amount), 0) as total_indirect_expenses
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
  ),
  -- Indirect Incomes
  indirect_incomes_data AS (
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
      COALESCE(SUM(vle.amount), 0) as total_indirect_incomes
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
  )
  SELECT 
    (SELECT total_sales FROM sales_data) as sales,
    (SELECT total_purchase FROM purchase_data) as purchase,
    (SELECT total_direct_expenses FROM direct_expenses_data) as direct_expenses,
    (SELECT total_direct_incomes FROM direct_incomes_data) as direct_incomes,
    (SELECT total_indirect_expenses FROM indirect_expenses_data) as indirect_expenses,
    (SELECT total_indirect_incomes FROM indirect_incomes_data) as indirect_incomes
''', [
      // Sales
      companyGuid, companyGuid, companyGuid, fromDate, toDate,
      // Purchase
      companyGuid, companyGuid, companyGuid, fromDate, toDate,
      // Direct Expenses
      companyGuid, companyGuid, companyGuid, fromDate, toDate,
      // Direct Incomes
      companyGuid, companyGuid, companyGuid, fromDate, toDate,
      // Indirect Expenses
      companyGuid, companyGuid, companyGuid, fromDate, toDate,
      // Indirect Incomes
      companyGuid, companyGuid, companyGuid, fromDate, toDate,
    ]);

    final plData = plCalculation.first;
    final sales = (plData['sales'] as num?)?.toDouble() ?? 0.0;
    final purchase = (plData['purchase'] as num?)?.toDouble() ?? 0.0;
    final directExpenses =
        (plData['direct_expenses'] as num?)?.toDouble() ?? 0.0;
    final directIncomes = (plData['direct_incomes'] as num?)?.toDouble() ?? 0.0;
    final indirectExpenses =
        (plData['indirect_expenses'] as num?)?.toDouble() ?? 0.0;
    final indirectIncomes =
        (plData['indirect_incomes'] as num?)?.toDouble() ?? 0.0;

    final netProfit = sales +
        purchase +
        directIncomes +
        directExpenses +
        indirectIncomes +
        indirectExpenses;

    print('=== P&L Breakdown ===');
    print('Sales: $sales');
    print('Purchase: $purchase');
    print('Direct Incomes: $directIncomes');
    print('Direct Expenses: $directExpenses');
    print('Indirect Incomes: $indirectIncomes');
    print('Indirect Expenses: $indirectExpenses');
    print('Net Profit: $netProfit');
    print('====================');


    final financialYearStartMonth = 4;
  final financialYearStartDay = 1;
  
  String getFinancialYearStartDate(String dateStr) {
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));
    
    if (month < financialYearStartMonth) {
      return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
    } else {
      return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
    }
  }
  
  // Get ALL stock items
  final allStockItemNames = await db.rawQuery('''
    SELECT DISTINCT stock_item_name as name
    FROM (
      SELECT si.name as stock_item_name
      FROM stock_items si
      WHERE si.company_guid = ?
        AND si.is_deleted = 0
      
      UNION
      
      SELECT DISTINCT vie.stock_item_name
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON v.voucher_guid = vie.voucher_guid
      WHERE v.company_guid = ?
        AND v.is_deleted = 0
    )
  ''', [companyGuid, companyGuid]);
  
  Map<String, Map<String, Map<String, double>>> itemGodownClosing = {};
  
  for (var itemRow in allStockItemNames) {
    final itemName = itemRow['name'] as String;
    
    itemGodownClosing[itemName] = {};
    
    // Get stock item GUID
    final stockItemQuery = await db.rawQuery('''
      SELECT stock_item_guid
      FROM stock_items
      WHERE name = ?
        AND company_guid = ?
        AND is_deleted = 0
    ''', [itemName, companyGuid]);
    
    String? itemGuid;
    if (stockItemQuery.isNotEmpty) {
      itemGuid = stockItemQuery[0]['stock_item_guid'] as String?;
    }
    
    // Get opening allocations
    List<Map<String, Object?>> openingAllocations = [];
    if (itemGuid != null) {
      openingAllocations = await db.rawQuery('''
        SELECT 
          godown_name,
          opening_balance,
          opening_value
        FROM stock_item_batch_allocation
        WHERE stock_item_guid = ?
          AND company_guid = ?
      ''', [itemGuid, companyGuid]);
    }
    
    // Get all transactions
    final transactions = await db.rawQuery('''
      SELECT 
        v.voucher_guid,
        v.date,
        v.voucher_type
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON v.voucher_guid = vie.voucher_guid
      WHERE vie.stock_item_name = ?
        AND v.company_guid = ?
        AND v.is_deleted = 0
        AND v.is_cancelled = 0
        AND v.is_optional = 0
      GROUP BY v.voucher_guid
      ORDER BY v.date
    ''', [itemName, companyGuid]);
    
    if (openingAllocations.isEmpty && transactions.isEmpty) continue;
    
    // Initialize with original opening from database
    Map<String, Map<String, double>> fyStock = {};
    
    for (var allocation in openingAllocations) {
      final godown = (allocation['godown_name'] as String?) ?? 'Primary';
      final openingQty = (allocation['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final openingValue = (allocation['opening_value'] as num?)?.toDouble() ?? 0.0;
      
      if (openingQty != 0) {
        fyStock[godown] = {
          'total_inward_qty': openingQty.abs(),
          'total_inward_value': openingValue.abs(),
          'current_stock_qty': openingQty,
        };
      }
    }
    
    String currentFyStart = '';
    
    // Process transactions FY by FY
    for (var txn in transactions) {
      final voucherGuid = txn['voucher_guid'] as String;
      final dateStr = txn['date'].toString();
      final voucherType = txn['voucher_type'] as String?;
      
      if (dateStr.compareTo(toDate) > 0) break;
      
      final txnFyStart = getFinancialYearStartDate(dateStr);
      
      // Check for FY boundary
      if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
        // Calculate closing of previous FY
        Map<String, Map<String, double>> fyClosing = {};
        
        for (var godown in fyStock.keys) {
          final data = fyStock[godown]!;
          final totalInwardQty = data['total_inward_qty']!;
          final totalInwardValue = data['total_inward_value']!;
          final currentQty = data['current_stock_qty']!;
          
          if (totalInwardQty > 0 && currentQty != 0) {
            final avgRate = totalInwardValue / totalInwardQty;
            final closingValue = currentQty.abs() * avgRate;
            
            fyClosing[godown] = {
              'closing_qty': currentQty,
              'closing_value': closingValue,
            };
          }
        }
        
        // Start new FY with previous FY's closing as opening
        Map<String, Map<String, double>> newFyStock = {};
        for (var godown in fyClosing.keys) {
          final closing = fyClosing[godown]!;
          final qty = closing['closing_qty']!;
          final value = closing['closing_value']!;
          
          newFyStock[godown] = {
            'total_inward_qty': qty.abs(),
            'total_inward_value': value,
            'current_stock_qty': qty,
          };
        }
        
        fyStock = newFyStock;
      }
      
      currentFyStart = txnFyStart;
      
      // Get batches
      final voucherBatches = await db.rawQuery('''
        SELECT 
          vba.godown_name,
          vba.actual_qty,
          vba.amount
        FROM voucher_batch_allocations vba
        WHERE vba.voucher_guid = ?
          AND vba.stock_item_name = ?
      ''', [voucherGuid, itemName]);
      
      if (voucherBatches.isEmpty) continue;
      
      // Determine voucher type
      final isCreditNote = voucherType != null && 
        (voucherType.toLowerCase().contains('credit') || 
         voucherType == 'Credit Note');
      
      final isDebitNote = voucherType != null && 
        (voucherType.toLowerCase().contains('debit') || 
         voucherType == 'Debit Note');
      
      bool isStockJournal = voucherType != null && voucherType == 'Stock Journal';
      
      // For Stock Journals, determine if it's a transfer or addition
      bool isStockJournalTransfer = false;
      if (isStockJournal) {
        bool hasInward = false;
        bool hasOutward = false;
        
        for (var batch in voucherBatches) {
          final amount = (batch['amount'] as num).toDouble();
          if (amount < 0) hasInward = true;
          if (amount > 0) hasOutward = true;
        }
        
        isStockJournalTransfer = hasInward && hasOutward;
        
        if (!isStockJournalTransfer) {
          isStockJournal = false;
        }
      }
      
      // Process batches
      for (var batch in voucherBatches) {
        final godown = (batch['godown_name'] as String?) ?? 'Primary';
        final amount = (batch['amount'] as num).toDouble();
        final isInward = amount < 0;
        final absAmount = amount.abs();
        
        String qtyStr = (batch['actual_qty'])?.toString() ?? '';
        double qty = 0.0;
        if (qtyStr.isNotEmpty) {
          final parts = qtyStr.split(' ');
          if (parts.isNotEmpty) {
            qty = double.tryParse(parts[0]) ?? 0.0;
          }
        }
        
        if ((isCreditNote || isDebitNote) && qty == 0) {
          continue;
        }
        
        if (!fyStock.containsKey(godown)) {
          fyStock[godown] = {
            'total_inward_qty': 0.0,
            'total_inward_value': 0.0,
            'current_stock_qty': 0.0,
          };
        }
        
        if (isStockJournal && isStockJournalTransfer) {
          if (isInward) {
            if (fyStock[godown]!['total_inward_qty']! == 0) {
              double sourceRate = 0.0;
              
              for (var sourceBatch in voucherBatches) {
                final sourceGodown = (sourceBatch['godown_name'] as String?) ?? 'Primary';
                final sourceAmount = (sourceBatch['amount'] as num).toDouble();
                
                if (sourceAmount > 0 && fyStock.containsKey(sourceGodown)) {
                  final sourceData = fyStock[sourceGodown]!;
                  if (sourceData['total_inward_qty']! > 0) {
                    sourceRate = sourceData['total_inward_value']! / sourceData['total_inward_qty']!;
                    break;
                  }
                }
              }
              
              if (sourceRate > 0) {
                fyStock[godown]!['total_inward_qty'] = qty;
                fyStock[godown]!['total_inward_value'] = qty * sourceRate;
              }
            }
            
            fyStock[godown]!['current_stock_qty'] = 
              fyStock[godown]!['current_stock_qty']! + qty;
          } else {
            fyStock[godown]!['current_stock_qty'] = 
              fyStock[godown]!['current_stock_qty']! - qty;
          }
        } else if (isCreditNote) {
          final currentRate = fyStock[godown]!['total_inward_qty']! > 0
              ? fyStock[godown]!['total_inward_value']! / fyStock[godown]!['total_inward_qty']!
              : 0.0;
          final costValue = qty * currentRate;
          
          fyStock[godown]!['total_inward_qty'] = 
            fyStock[godown]!['total_inward_qty']! + qty;
          fyStock[godown]!['total_inward_value'] = 
            fyStock[godown]!['total_inward_value']! + costValue;
          fyStock[godown]!['current_stock_qty'] = 
            fyStock[godown]!['current_stock_qty']! + qty;
        } else if (isDebitNote) {
          fyStock[godown]!['total_inward_qty'] = 
            fyStock[godown]!['total_inward_qty']! - qty;
          fyStock[godown]!['total_inward_value'] = 
            fyStock[godown]!['total_inward_value']! - absAmount;
          fyStock[godown]!['current_stock_qty'] = 
            fyStock[godown]!['current_stock_qty']! - qty;
        } else {
          if (isInward) {
            fyStock[godown]!['total_inward_qty'] = 
              fyStock[godown]!['total_inward_qty']! + qty;
            fyStock[godown]!['total_inward_value'] = 
              fyStock[godown]!['total_inward_value']! + absAmount;
            fyStock[godown]!['current_stock_qty'] = 
              fyStock[godown]!['current_stock_qty']! + qty;
          } else {
            fyStock[godown]!['current_stock_qty'] = 
              fyStock[godown]!['current_stock_qty']! - qty;
          }
        }
      }
    }
    
    // Set closing from final FY stock
    for (var godown in fyStock.keys) {
      itemGodownClosing[itemName]![godown] = {
        'total_inward_qty': fyStock[godown]!['total_inward_qty']!,
        'total_inward_value': fyStock[godown]!['total_inward_value']!,
        'current_stock_qty': fyStock[godown]!['current_stock_qty']!,
      };
    }
  }
  
  // Calculate closing total
  double totalClosingStock = 0.0;
  
  for (var itemName in itemGodownClosing.keys) {
    for (var godown in itemGodownClosing[itemName]!.keys) {
      final data = itemGodownClosing[itemName]![godown]!;
      final totalInwardQty = data['total_inward_qty']!;
      final totalInwardValue = data['total_inward_value']!;
      final currentStockQty = data['current_stock_qty']!;
      
      if (currentStockQty != 0 && totalInwardQty > 0) {
        final avgRate = totalInwardValue / totalInwardQty;
        final closingStockValue = currentStockQty * avgRate;
        totalClosingStock += closingStockValue;
      }
    }
  }

    // Calculate Assets - Use only TOP-LEVEL group names
    final fixedAssets = await _getGroupBalance(['Fixed Assets']);
    final investments = await _getGroupBalance(['Investments']);
    final currentAssets = await _getGroupBalance(['Current Assets']);

    return {
      'capital': capital,
      'loans': loans,
      'current_liabilities': currentLiabilities,
      'profit_loss': netProfit,
      'fixed_assets': fixedAssets,
      'investments': investments,
      'current_assets': (currentAssets - totalClosingStock),
    };
  }

  void _navigateToDetail(String groupName, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BalanceSheetDetailScreen(
          companyGuid: _companyGuid!,
          groupName: groupName,
          title: title,
          fromDate: _fromDate,
          toDate: _toDate,
          selectedFromDate: _selectedFromDate!,
          selectedToDate: _selectedToDate!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    syncBrightness(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Balance Sheet')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalLiabilities = (_bsData?['capital'] ?? 0.0) +
        (_bsData?['loans'] ?? 0.0) +
        (_bsData?['current_liabilities'] ?? 0.0) +
        (_bsData?['profit_loss'] ?? 0.0);

    final totalAssets = (_bsData?['fixed_assets'] ?? 0.0) +
        (_bsData?['investments'] ?? 0.0) +
        (_bsData?['current_assets'] ?? 0.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance Sheet', style: TextStyle(fontSize: 18)),
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
                      'As at ${DateFormat('dd MMM yyyy').format(_selectedToDate!)}',
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

            // Main Content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side - Liabilities
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Liabilities'),
                      _buildClickableItem(
                        'Capital Account',
                        _bsData?['capital'] ?? 0.0,
                        () => _navigateToDetail(
                            'Capital Account', 'Capital Account'),
                        Colors.amber[100],
                      ),
                      _buildClickableItem(
                        'Loans (Liability)',
                        _bsData?['loans'] ?? 0.0,
                        () => _navigateToDetail(
                            'Loans (Liability)', 'Loans (Liability)'),
                      ),
                      _buildClickableItem(
                        'Current Liabilities',
                        _bsData?['current_liabilities'] ?? 0.0,
                        () => _navigateToDetail(
                            'Current Liabilities', 'Current Liabilities'),
                      ),
                      _buildClickableItem(
                        'Profit & Loss A/c',
                        _bsData?['profit_loss'] ?? 0.0,
                        null,
                        Colors.green[100],
                      ),
                      Divider(height: 1, thickness: 2),
                      _buildTotalItem('Total', totalLiabilities),
                    ],
                  ),
                ),

                VerticalDivider(width: 1, thickness: 2),

                // Right Side - Assets
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Assets'),
                      _buildClickableItem(
                        'Fixed Assets',
                        _bsData?['fixed_assets'] ?? 0.0,
                        () => _navigateToDetail('Fixed Assets', 'Fixed Assets'),
                        Colors.amber[100],
                      ),
                      _buildClickableItem(
                        'Investments',
                        _bsData?['investments'] ?? 0.0,
                        () => _navigateToDetail('Investments', 'Investments'),
                      ),
                      _buildClickableItem(
                        'Current Assets',
                        _bsData?['current_assets'] ?? 0.0,
                        () => _navigateToDetail(
                            'Current Assets', 'Current Assets'),
                      ),
                      Divider(height: 1, thickness: 2),
                      _buildTotalItem('Total', totalAssets),
                    ],
                  ),
                ),
              ],
            ),

            // Difference Display
            if ((totalLiabilities - totalAssets).abs() > 0.01)
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.red[700]),
                    SizedBox(width: 8),
                    Text(
                      'Difference: ${_formatAmount(totalLiabilities - totalAssets)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      color: AppColors.divider,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildClickableItem(String label, double amount, VoidCallback? onTap,
      [Color? bgColor]) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight:
                      bgColor != null ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              _formatAmount(amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    bgColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalItem(String label, double amount) {
    return Container(
      color: AppColors.pillBg,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _formatAmount(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  String _formatAmount(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  return formatter.format(amount.abs());
}
}

// ============================================================================
// BALANCE SHEET DETAIL SCREEN
// ============================================================================

class BalanceSheetDetailScreen extends StatefulWidget {
  final String companyGuid;
  final String groupName;
  final String title;
  final String fromDate;
  final String toDate;
  final DateTime selectedFromDate;
  final DateTime selectedToDate;

  BalanceSheetDetailScreen({
    required this.companyGuid,
    required this.groupName,
    required this.title,
    required this.fromDate,
    required this.toDate,
    required this.selectedFromDate,
    required this.selectedToDate,
  });

  @override
  _BalanceSheetDetailScreenState createState() => _BalanceSheetDetailScreenState();
}

class _BalanceSheetDetailScreenState extends State<BalanceSheetDetailScreen> {
  final _db = DatabaseHelper.instance;
  
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    final db = await _db.database;

    print('=== BALANCE SHEET DETAIL DEBUG ===');
    print('Group Name: ${widget.groupName}');
    print('Company GUID: ${widget.companyGuid}');
    print('From Date: ${widget.fromDate}');
    print('To Date: ${widget.toDate}');

    // First, get the parent group's guid
    final parentGroup = await db.rawQuery('''
      SELECT group_guid, name
      FROM groups
      WHERE company_guid = ?
        AND name = ? OR reserved_name = ?
        AND is_deleted = 0
      LIMIT 1
    ''', [widget.companyGuid, widget.groupName, widget.groupName]);

    if (parentGroup.isEmpty) {
      print('ERROR: Parent group not found!');
      setState(() {
        _items = [];
        _total = 0.0;
        _loading = false;
      });
      return;
    }
    
    final parentGuid = parentGroup.first['group_guid'] as String;
    print('Parent GUID: $parentGuid');
    
    // Get immediate child groups
    final childGroups = await db.rawQuery('''
      SELECT DISTINCT
        g.name,
        'group' as type,
        g.group_guid as guid
      FROM groups g
      WHERE g.company_guid = ?
        AND g.parent_guid = ?
        AND g.is_deleted = 0
    ''', [widget.companyGuid, parentGuid]);
    
    print('Child Groups Found: ${childGroups.length}');
    for (var group in childGroups) {
      print('  - ${group['name']}');
    }
    
    // Get ledgers directly under this group
    final childLedgers = await db.rawQuery('''
      SELECT DISTINCT
        l.name,
        'ledger' as type,
        l.ledger_guid as guid
      FROM ledgers l
      WHERE l.company_guid = ?
        AND l.parent_guid = ?
        AND l.is_deleted = 0
    ''', [widget.companyGuid, parentGuid]);
    
    print('Child Ledgers Found: ${childLedgers.length}');
    for (var ledger in childLedgers) {
      print('  - ${ledger['name']}');
    }
    
    List<Map<String, dynamic>> items = [];
    double total = 0.0;
    
    print('\n--- Calculating Group Balances ---');
    // Calculate balance for each child group
    for (var group in childGroups) {
      final groupName = group['name'] as String;
      
      // // Get all ledgers under this group recursively
      // final ledgersInGroup = await db.rawQuery('''
      //   WITH RECURSIVE group_tree AS (
      //     SELECT group_guid, name
      //     FROM groups
      //     WHERE company_guid = ?
      //       AND name = ?
      //       AND is_deleted = 0
          
      //     UNION ALL
          
      //     SELECT g.group_guid, g.name
      //     FROM groups g
      //     INNER JOIN group_tree gt ON g.parentGuid = gt.group_guid
      //     WHERE g.company_guid = ?
      //       AND g.is_deleted = 0
      //   )
      //   SELECT l.name, l.ledger_guid, l.opening_balance
      //   FROM ledgers l
      //   INNER JOIN group_tree gt ON l.parent = gt.name
      //   WHERE l.company_guid = ?
      //     AND l.is_deleted = 0
      // ''', [widget.companyGuid, groupName, widget.companyGuid, widget.companyGuid]);
      
      // print('Group "$groupName" has ${ledgersInGroup.length} ledgers');
      
final balanceResult = await db.rawQuery('''
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
  ),
  ledger_transactions AS (
    SELECT 
      vle.ledger_name,
      SUM(vle.amount) as transaction_sum
    FROM voucher_ledger_entries vle
    INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    WHERE v.company_guid = ?
      AND v.is_deleted = 0
      AND v.is_cancelled = 0
      AND v.is_optional = 0
      AND v.date <= ?
    GROUP BY vle.ledger_name
  ),
  ledger_balances AS (
    SELECT 
      l.name as ledger_name,
      l.ledger_guid,
      l.opening_balance,
      COALESCE(lt.transaction_sum, 0) as transaction_sum,
      l.opening_balance + COALESCE(lt.transaction_sum, 0) as closing_balance
    FROM ledgers l
    INNER JOIN group_tree gt ON l.parent = gt.name
    LEFT JOIN ledger_transactions lt ON lt.ledger_name = l.name
    WHERE l.company_guid = ?
      AND l.is_deleted = 0
  )
  SELECT 
    ledger_name,
    ledger_guid,
    opening_balance,
    transaction_sum,
    closing_balance,
    (SELECT COALESCE(SUM(closing_balance), 0) FROM ledger_balances) as total
  FROM ledger_balances
  WHERE ABS(closing_balance) > 0.01
  ORDER BY ABS(closing_balance) DESC
''', [
  widget.companyGuid, groupName, widget.companyGuid,  // group_tree
  widget.companyGuid, widget.toDate,  // ledger_transactions
  widget.companyGuid,  // ledger_balances WHERE
]);
      
      double groupTotal = 0.0;
      if (balanceResult.isNotEmpty) {
        groupTotal = (balanceResult.first['total'] as num?)?.toDouble() ?? 0.0;
        
        print('  Ledgers in "$groupName":');
        for (var ledger in balanceResult) {
          print('    - ${ledger['ledger_name']}: Opening=${ledger['opening_balance']}, Txn=${ledger['transaction_sum']}, Closing=${ledger['closing_balance']}');
        }
      }
      
      print('  Group "$groupName" Total: $groupTotal');
      
      if (groupTotal.abs() > 0) {
        items.add({
          'name': groupName,
          'type': 'group',
          'guid': group['guid'],
          'balance': groupTotal,
        });
        total += groupTotal;
      }
    }
    
    print('\n--- Calculating Ledger Balances ---');
    // Calculate balance for each child ledger
    for (var ledger in childLedgers) {
      final ledgerName = ledger['name'] as String;
      
      // final balanceResult = await db.rawQuery('''
      //   SELECT 
      //     l.name,
      //     l.ledger_guid,
      //     l.opening_balance,
      //     COALESCE(SUM(vle.amount), 0) as transaction_sum,
      //     l.opening_balance + COALESCE(SUM(vle.amount), 0) as closing_balance,
      //     COUNT(DISTINCT vle.voucher_guid) as voucher_count
      //   FROM ledgers l
      //   LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      //   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      //     AND v.company_guid = l.company_guid
      //     AND v.is_deleted = 0
      //     AND v.is_cancelled = 0
      //     AND v.is_optional = 0
      //     AND v.date <= ?
      //   WHERE l.company_guid = ?
      //     AND l.name = ?
      //     AND l.is_deleted = 0
      //   GROUP BY l.ledger_guid, l.name, l.opening_balance
      // ''', [widget.toDate, widget.companyGuid, ledgerName]);

//       final balanceResult = await db.rawQuery('''
//   SELECT 
//     l.name,
//     l.ledger_guid,
//     l.opening_balance,
//     COALESCE((
//       SELECT SUM(vle.amount)
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       WHERE vle.ledger_name = l.name
//         AND v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date <= ?
//     ), 0) as transaction_sum,
//     l.opening_balance + COALESCE((
//       SELECT SUM(vle.amount)
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       WHERE vle.ledger_name = l.name
//         AND v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date <= ?
//     ), 0) as closing_balance,
//     COALESCE((
//       SELECT COUNT(DISTINCT v.voucher_guid)
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       WHERE vle.ledger_name = l.name
//         AND v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date <= ?
//     ), 0) as voucher_count
//   FROM ledgers l
//   WHERE l.company_guid = ?
//     AND l.name = ?
//     AND l.is_deleted = 0
// ''', [
//   widget.companyGuid, widget.toDate,  // transaction_sum
//   widget.companyGuid, widget.toDate,  // closing_balance
//   widget.companyGuid, widget.toDate,  // voucher_count
//   widget.companyGuid, ledgerName
// ]);

final balanceResult = await db.rawQuery('''
  WITH 
  ledger_transactions AS (
    SELECT 
      vle.ledger_name,
      SUM(vle.amount) as transaction_sum,
      COUNT(DISTINCT v.voucher_guid) as voucher_count
    FROM voucher_ledger_entries vle
    INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    WHERE v.company_guid = ?
      AND vle.ledger_name = ?
      AND v.is_deleted = 0
      AND v.is_cancelled = 0
      AND v.is_optional = 0
      AND v.date <= ?
  )
  SELECT 
    l.name,
    l.ledger_guid,
    l.opening_balance,
    COALESCE(lt.transaction_sum, 0) as transaction_sum,
    l.opening_balance + COALESCE(lt.transaction_sum, 0) as closing_balance,
    COALESCE(lt.voucher_count, 0) as voucher_count
  FROM ledgers l
  LEFT JOIN ledger_transactions lt ON lt.ledger_name = l.name
  WHERE l.company_guid = ?
    AND l.name = ?
    AND l.is_deleted = 0
''', [
  widget.companyGuid, ledgerName, widget.toDate,  // ledger_transactions CTE
  widget.companyGuid, ledgerName  // ledgers WHERE clause
]);

      
      if (balanceResult.isNotEmpty) {
        final result = balanceResult.first;
        final balance = (result['closing_balance'] as num?)?.toDouble() ?? 0.0;
        
        // print('$ledgerName,  ${result['opening_balance']}, ${result['transaction_sum']}, ${result['voucher_count']}, $balance');        
        if (balance.abs() > 0) {
          items.add({
            'name': ledgerName,
            'type': 'ledger',
            'guid': ledger['guid'],
            'balance': balance,
          });
          total += balance;
        }
      }
    }
    
    print('\n--- SUMMARY ---');
    print('Total Items: ${items.length}');
    print('Total Balance: $total');
    print('=================================\n');
    
    // Sort by balance (descending by absolute value)
    items.sort((a, b) {
      final balanceA = ((a['balance'] as num?)?.toDouble() ?? 0.0).abs();
      final balanceB = ((b['balance'] as num?)?.toDouble() ?? 0.0).abs();
      return balanceB.compareTo(balanceA);
    });

    setState(() {
      _items = items;
      _total = total;
      _loading = false;
    });
  }

  void _navigateToNext(Map<String, dynamic> item) {
    if (item['type'] == 'group') {
      // Navigate to another detail screen for sub-group
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BalanceSheetDetailScreen(
            companyGuid: widget.companyGuid,
            groupName: item['name'] as String,
            title: item['name'] as String,
            fromDate: widget.fromDate,
            toDate: widget.toDate,
            selectedFromDate: widget.selectedFromDate,
            selectedToDate: widget.selectedToDate,
          ),
        ),
      );
    } else {
      // Navigate to ledger transactions with "As At" view
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LedgerTransactionsScreen(
            companyGuid: widget.companyGuid,
            ledgerName: item['name'] as String,
            fromDate: widget.fromDate,
            toDate: widget.toDate,
            selectedFromDate: widget.selectedFromDate,
            selectedToDate: widget.selectedToDate,
            showAsAt: true, // Show balance as at toDate
          ),
        ),
      );
    }
  }

  String _formatAmount(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  return formatter.format(amount);
}

  @override
  Widget build(BuildContext context) {
    syncBrightness(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontSize: 18)),
            Text(
              'As at ${DateFormat('dd MMM yyyy').format(widget.selectedToDate)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Total Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.blue[600]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatAmount(_total),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_items.length} Items',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: AppColors.textSecondary),
                        SizedBox(height: 16),
                        Text(
                          'No items found',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final balance = (item['balance'] as num?)?.toDouble() ?? 0.0;
                      final isGroup = item['type'] == 'group';

                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _navigateToNext(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isGroup ? Colors.orange[50] : Colors.blue[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isGroup ? Icons.folder : Icons.description,
                                    color: isGroup ? Colors.orange[700] : Colors.blue[700],
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] as String,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        isGroup ? 'Group' : 'Ledger',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatAmount(balance),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: balance >= 0 ? Colors.green[700] : Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.chevron_right, color: AppColors.textSecondary),
                              ],
                            ),
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
}

// ============================================================================
// LEDGER TRANSACTIONS SCREEN
// ============================================================================

class LedgerTransactionsScreen extends StatefulWidget {
  final String companyGuid;
  final String ledgerName;
  final String fromDate;
  final String toDate;
  final DateTime selectedFromDate;
  final DateTime selectedToDate;
  final bool showAsAt; // true = show as at toDate, false = show range

  LedgerTransactionsScreen({
    required this.companyGuid,
    required this.ledgerName,
    required this.fromDate,
    required this.toDate,
    required this.selectedFromDate,
    required this.selectedToDate,
    this.showAsAt = false, // default to range view
  });

  @override
  _LedgerTransactionsScreenState createState() => _LedgerTransactionsScreenState();
}

class _LedgerTransactionsScreenState extends State<LedgerTransactionsScreen> {
  final _db = DatabaseHelper.instance;
  
  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];
  double _openingBalance = 0.0;
  double _closingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final db = await _db.database;

    print('\n=== LEDGER TRANSACTIONS DEBUG ===');
    print('Ledger Name: ${widget.ledgerName}');
    print('From Date: ${widget.fromDate}');
    print('To Date: ${widget.toDate}');
    print('Show As At: ${widget.showAsAt}');
    
    if (widget.showAsAt) {
      // "As At" view - show all transactions up to toDate
      print('MODE: Showing balance AS AT ${widget.toDate}');
      
      // Get closing balance (all transactions up to toDate)
      final balanceResult = await db.rawQuery('''
        SELECT 
          l.ledger_guid,
          l.opening_balance,
          COALESCE(SUM(vle.amount), 0) as transaction_sum,
          l.opening_balance + COALESCE(SUM(vle.amount), 0) as closing_balance,
          COUNT(DISTINCT v.voucher_guid) as voucher_count
        FROM ledgers l
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
          AND v.date <= ?
        WHERE l.company_guid = ?
          AND l.name = ?
          AND l.is_deleted = 0
        GROUP BY l.ledger_guid, l.name, l.opening_balance
      ''', [widget.toDate, widget.companyGuid, widget.ledgerName]);

      if (balanceResult.isEmpty) {
        print('ERROR: Ledger not found!');
        setState(() {
          _loading = false;
        });
        return;
      }
      
      _openingBalance = (balanceResult.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
      _closingBalance = (balanceResult.first['closing_balance'] as num?)?.toDouble() ?? 0.0;
      
      print('Opening Balance: $_openingBalance');
      print('Transaction Sum: ${balanceResult.first['transaction_sum']}');
      print('Voucher Count: ${balanceResult.first['voucher_count']}');
      print('Closing Balance: $_closingBalance');
      
      // Get all transactions up to toDate
      final transactions = await db.rawQuery('''
        SELECT 
          v.voucher_guid,
          v.date,
          v.voucher_type,
          v.voucher_number,
          v.narration,
          vle.amount
        FROM voucher_ledger_entries vle
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ?
          AND vle.ledger_name = ?
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
          AND v.date <= ?
        ORDER BY v.date ASC, v.voucher_number ASC
      ''', [widget.companyGuid, widget.ledgerName, widget.toDate]);
      
      print('Total Transactions: ${transactions.length}');
      
      // Calculate running balance
      double runningBalance = _openingBalance;
      final transactionsWithBalance = transactions.map((txn) {
        final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
        runningBalance += amount;

        print('${txn['voucher_guid']}, ${txn['date']}, ${txn['voucher_type']}, ${txn['voucher_number']}, ${txn['amount']}');
        return {
          ...txn,
          'running_balance': runningBalance,
        };
      }).toList();

      setState(() {
        _transactions = transactionsWithBalance;
        _loading = false;
      });
      
    } else {
      // Range view - show transactions between fromDate and toDate
      print('MODE: Showing transactions FROM ${widget.fromDate} TO ${widget.toDate}');
      
      // Get opening balance (including all transactions before start date)
      final openingResult = await db.rawQuery('''
        SELECT 
          l.opening_balance +
          COALESCE(SUM(CASE WHEN v.date < ? THEN vle.amount ELSE 0 END), 0) as opening_balance
        FROM ledgers l
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
        WHERE l.company_guid = ?
          AND l.name = ?
          AND l.is_deleted = 0
        GROUP BY l.ledger_guid, l.name, l.opening_balance
      ''', [widget.fromDate, widget.companyGuid, widget.ledgerName]);
      
      _openingBalance = (openingResult.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
      
      print('Opening Balance (before fromDate): $_openingBalance');
      
      // Get transactions
      final transactions = await db.rawQuery('''
        SELECT 
          v.voucher_guid,
          v.date,
          v.voucher_type,
          v.voucher_number,
          v.narration,
          vle.amount
        FROM voucher_ledger_entries vle
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ?
          AND vle.ledger_name = ?
          AND v.is_deleted = 0
          AND v.is_cancelled = 0
          AND v.is_optional = 0
          AND v.date >= ?
          AND v.date <= ?
        ORDER BY v.date ASC, v.voucher_number ASC
      ''', [widget.companyGuid, widget.ledgerName, widget.fromDate, widget.toDate]);
      
      print('Transactions in Range: ${transactions.length}');
      
      // Calculate running balance
      double runningBalance = _openingBalance;
      final transactionsWithBalance = transactions.map((txn) {
        final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
        runningBalance += amount;
        return {
          ...txn,
          'running_balance': runningBalance,
        };
      }).toList();

      setState(() {
        _transactions = transactionsWithBalance;
        _closingBalance = runningBalance;
        _loading = false;
      });
    }

    print('=================================\n');
  }

  String _formatAmount(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  return formatter.format(amount);
}

  String _parseTallyDate(String tallyDate) {
    if (tallyDate.length != 8) return '-';
    final year = tallyDate.substring(0, 4);
    final month = tallyDate.substring(4, 6);
    final day = tallyDate.substring(6, 8);
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    syncBrightness(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ledgerName, style: TextStyle(fontSize: 18)),
            Text(
              widget.showAsAt
                  ? 'As at ${DateFormat('dd MMM yyyy').format(widget.selectedToDate)}'
                  : '${DateFormat('dd MMM yyyy').format(widget.selectedFromDate)} - ${DateFormat('dd MMM yyyy').format(widget.selectedToDate)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Balance Summary
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: AppShadows.cardBorder,
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Opening',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatAmount(_openingBalance),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Closing',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatAmount(_closingBalance),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _closingBalance >= 0 ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_transactions.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: AppColors.textSecondary),
                        SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final txn = _transactions[index];
                      final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
                      final runningBalance = (txn['running_balance'] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          txn['voucher_type'] as String,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${txn['voucher_number']} • ${_parseTallyDate(txn['date'] as String)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        amount >= 0 ? 'Cr' : 'Dr',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        _formatAmount(amount),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: amount >= 0 ? Colors.green[700] : Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (txn['narration'] != null && (txn['narration'] as String).isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    txn['narration'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Balance: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatAmount(runningBalance),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: runningBalance >= 0 ? Colors.green[700] : Colors.red[700],
                                    ),
                                  ),
                                ],
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
}