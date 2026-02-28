// screens/profit_loss_screen.dart

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/data_model.dart';
import '../../services/analytics_service.dart';
import '../../database/database_helper.dart';
import '../../utils/date_utils.dart';
import 'group_detail_screen.dart';
import 'ledger_detail_screen.dart';

class ProfitLossScreen extends StatefulWidget {
  @override
  _ProfitLossScreenState createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  final _analytics = AnalyticsService();
  final _db = DatabaseHelper.instance;

  String? _companyGuid;
  String? _companyName;
  String _companyStartDate = getCurrentFyStartDate();
  bool _loading = true;
  bool _isMaintainInventory = true;
  List<String> debitNoteVoucherTypes = [];
  List<String> creditNoteVoucherTypes = [];
  List<String> stockJournalVoucherType = [];
  List<String> physicalStockVoucherType = [];

  Map<String, dynamic>? _plData;
  DateTime _fromDate = getFyStartDate(DateTime.now());  // Financial year start
  DateTime _toDate = getFyEndDate(DateTime.now()); // Financial year end

  // Get all Contra child voucher types

  // DateTime _selectedFromDate = getCurrentFyStartDate();  
  // DateTime _selectedToDate = getCurrentFyEndDate();

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
    _isMaintainInventory = (company['integrate_inventory'] as int) == 1;

    _companyStartDate = (company['starting_from'] as String).replaceAll('-', '');

    // // Only set initial dates if not already set by user
    // if (_selectedFromDate == null || _selectedToDate == null) {
    //   _fromDate = company['starting_from'] as String? ?? _fromDate;
    //   _toDate = company['ending_at'] as String? ?? _toDate;
    //   _selectedFromDate = _parseTallyDate(_fromDate);
    //   _selectedToDate = _parseTallyDate(_toDate);
    // }
    debitNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Debit Note');
    creditNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Credit Note');
    stockJournalVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Stock Journal');
    physicalStockVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Physical Stock');
    final plData = await _getProfitLossDetailed(_companyGuid!, _fromDate, _toDate);
    // await calculateJAcidFIFO_Fixed(_companyGuid!, _fromDate, _toDate);
    // final stockItemData = await debugStockItem(_companyGuid!,"J.ACID", _fromDate, _toDate);

// await checkBatchRatesDetail(_companyGuid!);
// await verifyAllTransactions(_companyGuid!);
// await checkDuplicateBatchEntries(_companyGuid!);

    // final stockData = await calculateStockValues( _companyGuid!, _fromDate, _toDate);
    // Build complete directory
    // Map<String, Map<String, List<StockTransaction>>> directory =
    //   await buildStockDirectory(_companyGuid!, _toDate);

    setState(() {
      _plData = plData;
      _loading = false;
    });
  }

  double getTotalClosingValue(List<AverageCostResult> results) {
    double totalClosingValue = 0.0;

    for (var result in results) {
      for (var godown in result.godowns.values) {
        totalClosingValue += godown.closingValue;
      }
    }
    print(totalClosingValue);
    return totalClosingValue;
  }

  DateTime _parseTallyDate(String tallyDate) {
    if (tallyDate.length != 8) return DateTime.now();
    final year = int.parse(tallyDate.substring(0, 4));
    final month = int.parse(tallyDate.substring(4, 6));
    final day = int.parse(tallyDate.substring(6, 8));
    return DateTime(year, month, day);
  }

  String _toTallyDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

// ============================================================
// GET ALL CHILD VOUCHER TYPES FOR CONTRA
// ============================================================

Future<List<String>> getAllChildVoucherTypes(String companyGuid, String voucherTypeName) async {
  final db = await _db.database;

  final result = await db.rawQuery('''
    WITH RECURSIVE voucher_type_tree AS (
      SELECT guid, name
      FROM voucher_types
      WHERE company_guid = ?
        AND (name = ? OR reserved_name = ?)
        AND is_deleted = 0
      
      UNION ALL
      
      SELECT vt.guid, vt.name
      FROM voucher_types vt
      INNER JOIN voucher_type_tree vtt ON vt.parent_guid = vtt.guid
      WHERE vt.company_guid = ?
        AND vt.is_deleted = 0
        AND vt.guid != vt.parent_guid  -- Prevent self-referencing loop
    )
    SELECT name FROM voucher_type_tree ORDER BY name
  ''', [companyGuid, voucherTypeName, voucherTypeName, companyGuid]);

  return result.map((row) => row['name'] as String).toList();
}

// ============================================================
// USAGE
// ============================================================



// Output example:
// 📋 Contra Voucher Types:
//    - Contra
//    - Bank Transfer
//    - Cash Deposit
//    - Cash Withdrawal

  // Future<List<StockItemInfo>> fetchAllStockItems(String companyGuid) async {
  //   final db = await _db.database;

  //   // First, fetch all stock items
  //   final stockItemResults = await db.rawQuery('''
  //   SELECT 
  //     si.name as item_name,
  //     si.stock_item_guid,
  //     COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
  //     COALESCE(si.base_units, '') as unit,
  //     COALESCE(si.parent, '') as parent_name
  //   FROM stock_items si
  //   WHERE si.company_guid = ?
  //     AND si.is_deleted = 0
  // ''', [companyGuid]);

  //   // Then fetch all batch allocations for opening stock
  //   final batchResults = await db.rawQuery('''
  //   SELECT 
  //     siba.stock_item_guid,
  //     COALESCE(siba.godown_name, '') as godown_name,
  //     COALESCE(siba.batch_name, '') as batch_name,
  //     COALESCE(siba.opening_value, 0) as amount,
  //     COALESCE(siba.opening_balance, '') as actual_qty,
  //     COALESCE(siba.opening_balance, '') as billed_qty,
  //     siba.opening_rate as batch_rate
  //   FROM stock_item_batch_allocation siba
  //   INNER JOIN stock_items si 
  //     ON siba.stock_item_guid = si.stock_item_guid
  //   WHERE si.company_guid = ?
  //     AND si.is_deleted = 0
  // ''', [companyGuid]);

  //   // Group batch allocations by stock_item_guid
  //   final Map<String, List<BatchAllocation>> batchMap = {};

  //   for (final row in batchResults) {
  //     final stockItemGuid = row['stock_item_guid'] as String;
  //     final batch = BatchAllocation(
  //       godownName: row['godown_name'] as String,
  //       batchName: row['batch_name'] as String,
  //       amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
  //       actualQty: row['actual_qty']?.toString() ?? '',
  //       billedQty: row['billed_qty']?.toString() ?? '',
  //       batchRate: (row['batch_rate'] as num?)?.toDouble(),
  //     );

  //     batchMap.putIfAbsent(stockItemGuid, () => []).add(batch);
  //   }

  //   // Build final list with batch allocations
  //   return stockItemResults.map((row) {
  //     final stockItemGuid = row['stock_item_guid'] as String;

  //     return StockItemInfo(
  //       itemName: row['item_name'] as String,
  //       stockItemGuid: stockItemGuid,
  //       costingMethod: row['costing_method'] as String,
  //       unit: row['unit'] as String,
  //       parentName: row['parent_name'] as String,
  //       openingData: batchMap[stockItemGuid] ?? [],
  //     );
  //   }).toList();
  // }

Future<List<StockItemInfo>> fetchAllStockItems(String companyGuid) async {
  final db = await _db.database;

  // Fetch stock items that have opening batch allocations or at least one voucher
  final stockItemResults = await db.rawQuery('''
    SELECT 
      si.name as item_name,
      si.stock_item_guid,
      COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
      COALESCE(si.base_units, '') as unit,
      COALESCE(si.parent, '') as parent_name
    FROM stock_items si
    WHERE si.company_guid = ?
      AND si.is_deleted = 0
      AND (
        EXISTS (
          SELECT 1 FROM stock_item_batch_allocation siba
          WHERE siba.stock_item_guid = si.stock_item_guid
        )
        OR EXISTS (
          SELECT 1 FROM voucher_inventory_entries vie
          WHERE vie.stock_item_guid = si.stock_item_guid
            AND vie.company_guid = si.company_guid
        )
      )
  ''', [companyGuid]);

  // Batch allocations only for matched stock items
  final batchResults = await db.rawQuery('''
    SELECT 
      siba.stock_item_guid,
      COALESCE(siba.godown_name, '') as godown_name,
      COALESCE(siba.tracking_number, '') as tracking_number,
      COALESCE(siba.batch_name, '') as batch_name,
      COALESCE(siba.opening_value, 0) as amount,
      COALESCE(siba.opening_balance, '') as actual_qty,
      COALESCE(siba.opening_balance, '') as billed_qty,
      siba.opening_rate as batch_rate
    FROM stock_item_batch_allocation siba
    INNER JOIN stock_items si 
      ON siba.stock_item_guid = si.stock_item_guid
    WHERE si.company_guid = ?
      AND si.is_deleted = 0
  ''', [companyGuid]);

  // Group batch allocations by stock_item_guid
  final Map<String, List<BatchAllocation>> batchMap = {};

  for (final row in batchResults) {
    final stockItemGuid = row['stock_item_guid'] as String;
    final batch = BatchAllocation(
      godownName: row['godown_name'] as String,
      trackingNumber: row['tracking_number'] as String,
      batchName: row['batch_name'] as String,
      amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
      actualQty: row['actual_qty']?.toString() ?? '',
      billedQty: row['billed_qty']?.toString() ?? '',
      batchRate: (row['batch_rate'] as num?)?.toDouble(),
    );

    batchMap.putIfAbsent(stockItemGuid, () => []).add(batch);
  }

  return stockItemResults.map((row) {
    final stockItemGuid = row['stock_item_guid'] as String;

    return StockItemInfo(
      itemName: row['item_name'] as String,
      stockItemGuid: stockItemGuid,
      costingMethod: row['costing_method'] as String,
      unit: row['unit'] as String,
      parentName: row['parent_name'] as String,
      openingData: batchMap[stockItemGuid] ?? [],
    );
  }).toList();
}
  Future<List<StockTransaction>> fetchTransactionsForStockItem(
    String companyGuid,
    String stockItemGuid,
    String endDate,
  ) async {
    final db = await _db.database;

    final results = await db.rawQuery('''
    SELECT 
      v.voucher_guid,
      v.voucher_key as voucher_id,
      v.date as voucher_date,
      v.voucher_number,
      vba.godown_name,
      v.voucher_type,
      vba.actual_qty as stock,
      COALESCE(vba.batch_rate, 0) as rate,
      vba.amount,
      vba.is_deemed_positive as is_inward,
      COALESCE(vba.batch_name, '') as batch_name,
      COALESCE(vba.destination_godown_name, '') as destination_godown,
      COALESCE(vba.tracking_number, 'Not Applicable') as tracking_number,
      
    FROM vouchers v
    INNER JOIN voucher_batch_allocations vba 
      ON vba.voucher_guid = v.voucher_guid
    WHERE vba.stock_item_guid = ?
      AND v.company_guid = ?
      AND v.date <= ?
      AND v.is_deleted = 0
      AND v.is_cancelled = 0
      AND v.is_optional = 0
    ORDER BY v.date, v.master_id
  ''', [stockItemGuid, companyGuid, endDate]);

    return results.map((row) {
      // Parse quantity from "960.000 Kgs" format
      String stockStr = (row['stock'] as String?) ?? '0';
      double stock = 0.0;
      if (stockStr.isNotEmpty) {
        final parts = stockStr.split(' ');
        if (parts.isNotEmpty) {
          stock = double.tryParse(parts[0]) ?? 0.0;
        }
      }

      return StockTransaction(
        voucherGuid: row['voucher_guid'] as String,
        voucherId: (row['voucher_id'] as int?) ?? 0,
        voucherDate: row['voucher_date'] as String,
        voucherNumber: row['voucher_number'] as String,
        godownName: (row['godown_name'] as String?) ?? 'Primary',
        voucherType: row['voucher_type'] as String,
        stock: stock,
        rate: (row['rate'] as num?)?.toDouble() ?? 0.0,
        amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
        isInward: (row['is_inward'] as int) == 1,
        batchName: row['batch_name'] as String,
        destinationGodown: row['destination_godown'] as String,
        trackingNumber: row['tracking_number'] as String
      );
    }).toList();
  }

  Future<Map<String, Map<String, List<StockTransaction>>>> buildStockDirectory(
    String companyGuid,
    String endDate,
    List<StockItemInfo> stockItems
  ) async {
    // Fetch all stock items
    // final stockItems = await fetchAllStockItems(companyGuid);

    // Initialize directory
    Map<String, Map<String, List<StockTransaction>>> directory = {};

    // For each stock item, fetch transactions and organize by godown
    for (var item in stockItems) {
      // if (item.itemName != "5 LT./KG. CAPACITY PLASTIC BUCKET"){
      //   continue;
      // }
      // if (item.itemName !='Import Item'){
      //   continue;
      // }
      final transactions = await fetchTransactionsForStockItem(
        companyGuid,
        item.stockItemGuid,
        endDate,
      );

      // Organize transactions by godown
      Map<String, List<StockTransaction>> godownTransactions = {};

      for (var transaction in transactions) {
          // print('${item.itemName}, ${transaction.voucherId}, ${transaction.amount}, ${transaction.voucherType}, ${transaction.godownName}');
        if (!godownTransactions.containsKey(transaction.godownName)) {
          godownTransactions[transaction.godownName] = [];
        }
        godownTransactions[transaction.godownName]!.add(transaction);
      }

      // Add to directory
      directory[item.stockItemGuid] = godownTransactions;
    }

    return directory;
  }

// ============================================
// CALCULATE FOR ALL ITEMS
// ============================================

  Future<List<AverageCostResult>> calculateAllAverageCost({
    required String companyGuid,
    required String fromDate,
    required String toDate,
  }) async {
    // Fetch all stock items
    final stockItems = await fetchAllStockItems(companyGuid);

    // Build directory
    final directory = await buildStockDirectory(companyGuid, toDate, stockItems);

    List<AverageCostResult> results = [];

    for (var stockItem in stockItems) {
      // Only process items with Average Cost method

      // if (stockItem.itemName != "5 LT./KG. CAPACITY PLASTIC BUCKET"){
      //   continue;
      // }

      // if (stockItem.itemName !='Import Item'){
      //   continue;
      // }

      final godownTransactions = directory[stockItem.stockItemGuid]!;

      // if (godownTransactions.isEmpty) continue;

      if (stockItem.unit.toLowerCase().contains('not applicable')){
    final result = await calculateCostWithoutUnit(
              stockItem: stockItem,
              godownTransactions: godownTransactions,
              fromDate: fromDate,
              toDate: toDate,
              companyGuid: companyGuid);

          for (final entry in result.godowns.entries) {
            print(
                '${result.itemName}, ${stockItem.costingMethod}, ${entry.value.godownName}, ${entry.value.currentStockQty}, ${entry.value.averageRate}, ${entry.value.closingValue}');
          }
          results.add(result);

      }else if (stockItem.costingMethod.toLowerCase().contains('zero')){
        final result = AverageCostResult(itemName: stockItem.itemName, stockItemGuid: stockItem.stockItemGuid, godowns: {});

          // for (final entry in result.godowns.entries) {
            print(
                '${result.itemName}, ${stockItem.costingMethod}, godownName, 0, 0, 0');
          // }
          results.add(result);
      }else if (stockItem.costingMethod.toLowerCase().contains('fifo')){
        final result = await calculateFifoCost(
              stockItem: stockItem,
              godownTransactions: godownTransactions,
              fromDate: fromDate,
              toDate: toDate,
              companyGuid: companyGuid);

          for (final entry in result.godowns.entries) {
            print(
                '${result.itemName}, ${stockItem.costingMethod}, ${entry.value.godownName}, ${entry.value.currentStockQty}, ${entry.value.averageRate}, ${entry.value.closingValue}');
          }
          results.add(result);
      }else if (stockItem.costingMethod.toLowerCase().contains('lifo')){
        final result = await calculateLifoCost(
              stockItem: stockItem,
              godownTransactions: godownTransactions,
              fromDate: fromDate,
              toDate: toDate,
              companyGuid: companyGuid);

          for (final entry in result.godowns.entries) {
            print(
                '${result.itemName}, ${stockItem.costingMethod}, ${entry.value.godownName}, ${entry.value.currentStockQty}, ${entry.value.averageRate}, ${entry.value.closingValue}');
          }
          results.add(result);
      }else{
        final result = await calculateAvgCost(
                    stockItem: stockItem,
                    godownTransactions: godownTransactions,
                    fromDate: fromDate,
                    toDate: toDate,
                    companyGuid: companyGuid);

          for (final entry in result.godowns.entries) {
            print(
                '${result.itemName}, ${stockItem.costingMethod}, ${entry.value.godownName}, ${entry.value.currentStockQty}, ${entry.value.averageRate}, ${entry.value.closingValue}');
          }
          results.add(result);
      }
    }

    return results;
  }

  // Future<AverageCostResult> calculateLifoCost({
  //   required StockItemInfo stockItem,
  //   required Map<String, List<StockTransaction>> godownTransactions,
  //   required String fromDate,
  //   required String toDate,
  //   required String companyGuid,
  // }) async {
  //   Map<String, GodownAverageCost> godownResults = {};

  //   // Per godown tracking
  //   Map<String, double> totalInwardQty = {};
  //   Map<String, double> totalOutwardQty = {};
  //   Map<String, List<StockLot>>stockLots = {}; // All inward vouchers in order

  //   // Flatten all transactions and sort by date
  //   List<StockTransaction> allTransactions = [];
  //   for (var godownTxns in godownTransactions.values) {
  //     allTransactions.addAll(godownTxns);
  //   }
  //   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

  //   // Group transactions by voucher_guid
  //   Map<String, List<StockTransaction>> voucherBatches = {};
  //   for (var txn in allTransactions) {
  //     if (!voucherBatches.containsKey(txn.voucherGuid)) {
  //       voucherBatches[txn.voucherGuid] = [];
  //     }
  //     voucherBatches[txn.voucherGuid]!.add(txn);
  //   }

  //   // Initialize with opening stock
  //   for (final godownOpeningData in stockItem.openingData) {
  //     String godownName = godownOpeningData.godownName;
  //     if (godownName.isEmpty) {
  //       godownName = 'Main Location';
  //     }

  //     final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
  //     final openingAmount = godownOpeningData.amount.abs();

  //     totalInwardQty[godownName] = openingQty.abs();
  //     totalOutwardQty[godownName] = 0.0;
  //     stockLots[godownName] = [];

  //     if (openingQty > 0) {
  //       final openingRate = openingAmount / openingQty;
  //       stockLots[godownName]!.add(StockLot(
  //         voucherGuid: 'OPENING_STOCK',
  //         voucherDate: fromDate,
  //         voucherNumber: 'Opening Balance',
  //         voucherType: 'Opening',
  //         qty: openingQty,
  //         amount: openingAmount,
  //         rate: openingRate,
  //         type: StockInOutType.inward
  //       ));
  //     }
  //   }

  //   // Process transactions
  //   Set<String> processedVouchers = {};

  //   for (var txn in allTransactions) {
  //     final voucherGuid = txn.voucherGuid;

  //     if (processedVouchers.contains(voucherGuid)) {
  //       continue;
  //     }
  //     processedVouchers.add(voucherGuid);

  //     final dateStr = txn.voucherDate;
  //     final voucherType = txn.voucherType;
  //     final voucherNumber = txn.voucherNumber;

  //     if (dateStr.compareTo(toDate) > 0) {
  //       break;
  //     }

  //     // Skip Delivery Notes that have corresponding GST TAX INVOICE
  //     final isDeliveryNote = voucherType.toLowerCase().contains('delivery note');

  //     if (isDeliveryNote) {
  //       bool hasInvoice = false;
  //       for (var otherTxn in allTransactions) {
  //         if (otherTxn.voucherType.toLowerCase().contains('gst tax invoice') &&
  //             otherTxn.voucherDate == dateStr &&
  //             otherTxn.voucherNumber == voucherNumber) {
  //           hasInvoice = true;
  //           break;
  //         }
  //       }
  //       if (hasInvoice) continue;
  //     }

  //     final batches = voucherBatches[voucherGuid]!;

  //     final isCreditNote = voucherType.toLowerCase().contains('credit') ||
  //         voucherType == 'Credit Note';
  //     final isDebitNote = voucherType.toLowerCase().contains('debit') ||
  //         voucherType == 'Debit Note';
  //     final isStockJournal = voucherType == 'Stock Journal';

  //     if (voucherType == 'Physical Stock') {
  //       continue;
  //     }

  //     for (var batch in batches) {
  //       final godown = batch.godownName;
  //       final amount = batch.amount;
  //       final qty = batch.stock;
  //       final isInward = batch.isInward;
  //       final absAmount = amount.abs();

  //       if (amount == 0 && !isStockJournal) {
  //         continue;
  //       }

  //       if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
  //         continue;
  //       }

  //       // Initialize godown if not exists
  //       if (!totalOutwardQty.containsKey(godown)) {
  //         totalOutwardQty[godown] = 0.0;
  //       }

  //       if (!totalInwardQty.containsKey(godown)) {
  //         totalInwardQty[godown] = 0.0;
  //       }

  //       if (!stockLots.containsKey(godown)) {
  //         stockLots[godown] = [];
  //       }

  //       if (isInward) {
  //         // INWARD: Add to total inward qty and store lot
  //         if (isCreditNote) {
  //           totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
  //         } else {
  //           totalInwardQty[godown] = totalInwardQty[godown]! + qty;

  //           final rate = qty > 0 ? absAmount / qty : 0.0;
  //           stockLots[godown]!.add(StockLot(
  //             voucherGuid: voucherGuid,
  //             voucherDate: dateStr,
  //             voucherNumber: voucherNumber,
  //             voucherType: voucherType,
  //             qty: qty,
  //             amount: absAmount,
  //             rate: rate,
  //             type: StockInOutType.inward
  //           ));
  //         }
  //       } else {
  //         if (isDebitNote) {
  //           totalInwardQty[godown] = totalInwardQty[godown]! + qty;
  //         } else {
  //           totalOutwardQty[godown] = totalOutwardQty[godown]! + qty;
  //           final rate = qty > 0 ? absAmount / qty : 0.0;
  //           stockLots[godown]!.add(StockLot(
  //             voucherGuid: voucherGuid,
  //             voucherDate: dateStr,
  //             voucherNumber: voucherNumber,
  //             voucherType: voucherType,
  //             qty: qty,
  //             amount: absAmount,
  //             rate: rate,
  //             type: StockInOutType.outward
  //           ));
  //         }
  //         // OUTWARD: Add to total outward qty
  //       }
  //     }
  //   }

  //   // Calculate closing stock and value for each godown
  //   for (var godown in totalInwardQty.keys) {
  //     final inwardQty = totalInwardQty[godown]!;
  //     final outwardQty = totalOutwardQty[godown]!;
  //     final closingStockQty = inwardQty - outwardQty;

  //     double closingValue = 0.0;
  //     final lots = stockLots[godown]!;

  //     if (closingStockQty > 0) {
  //       // Go backwards from last inward voucher
  //       double remainingQty = closingStockQty;

  //       double tempOutWardQty = 0.0;


  //       // Iterate from last to first
  //       for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
  //         final lot = lots[i];
  //         if (lot.type == StockInOutType.outward){
  //             tempOutWardQty += lot.qty;
  //         }else{
  //             if (tempOutWardQty <= 0){
  //               if (lot.qty <= remainingQty) {
  //                 // Take entire lot
  //                 closingValue += lot.amount;
  //                 remainingQty -= lot.qty;
  //               } else {
  //                 closingValue += remainingQty * lot.rate;
  //                 remainingQty = 0;
  //               }
  //             }else{
  //               if (lot.qty <= tempOutWardQty) {
  //                 tempOutWardQty -= lot.qty;
  //               } else {

  //                 final tempLotQty = lot.qty - tempOutWardQty;

  //                 if (tempLotQty <= remainingQty) {
  //                 // Take entire lot
  //                 closingValue += (tempLotQty * lot.rate);
  //                 remainingQty -= tempLotQty;
  //               } else {
  //                 closingValue += remainingQty * lot.rate;
  //                 remainingQty = 0;
  //               }
                 
  //               }
  //             }
  //         }        
  //       }
  //     } else {
  //       final lastStockLot = lots.last;

  //       closingValue = closingStockQty * lastStockLot.rate;
  //     }

  //     godownResults[godown] = GodownAverageCost(
  //       godownName: godown,
  //       totalInwardQty: inwardQty,
  //       totalInwardValue: outwardQty,
  //       currentStockQty: closingStockQty,
  //       averageRate: closingStockQty > 0 ? closingValue / closingStockQty : 0.0,
  //       closingValue: closingValue,
  //     );
  //   }

  //   return AverageCostResult(
  //     stockItemGuid: stockItem.stockItemGuid,
  //     itemName: stockItem.itemName,
  //     godowns: godownResults,
  //   );
  // }

Future<AverageCostResult> calculateLifoCost({
  required StockItemInfo stockItem,
  required Map<String, List<StockTransaction>> godownTransactions,
  required String fromDate,
  required String toDate,
  required String companyGuid,
}) async {
  Map<String, GodownAverageCost> godownResults = {};

  const financialYearStartMonth = 4;
  const financialYearStartDay = 1;

  String getFinancialYearStartDate(String dateStr) {
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));

    if (month < financialYearStartMonth) {
      return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
    } else {
      return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
    }
  }

  // Per godown tracking
  Map<String, double> totalInwardQty = {};
  Map<String, double> totalOutwardQty = {};
  Map<String, List<StockLot>> stockLots = {};

  // Flatten all transactions and sort by date
  List<StockTransaction> allTransactions = [];
  for (var godownTxns in godownTransactions.values) {
    allTransactions.addAll(godownTxns);
  }
  allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

  // Group transactions by voucher_guid
  Map<String, List<StockTransaction>> voucherBatches = {};
  for (var txn in allTransactions) {
    if (!voucherBatches.containsKey(txn.voucherGuid)) {
      voucherBatches[txn.voucherGuid] = [];
    }
    voucherBatches[txn.voucherGuid]!.add(txn);
  }

  // Initialize with opening stock
  for (final godownOpeningData in stockItem.openingData) {
    String godownName = godownOpeningData.godownName;
    if (godownName.isEmpty) {
      godownName = 'Main Location';
    }

    final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
    final openingAmount = godownOpeningData.amount.abs();

    totalInwardQty[godownName] = openingQty.abs();
    totalOutwardQty[godownName] = 0.0;
    stockLots[godownName] = [];

    if (openingQty > 0) {
      final openingRate = openingAmount / openingQty;
      stockLots[godownName]!.add(StockLot(
        voucherGuid: 'OPENING_STOCK',
        voucherDate: fromDate,
        voucherNumber: 'Opening Balance',
        voucherType: 'Opening',
        qty: openingQty,
        amount: openingAmount,
        rate: openingRate,
        type: StockInOutType.inward,
      ));
    }
  }

  String currentFyStart = '';

  // Helper function to calculate closing value using LIFO logic
  double calculateLifoClosingValue(List<StockLot> lots, double closingStockQty) {
    if (closingStockQty <= 0 || lots.isEmpty) {
      if (lots.isNotEmpty) {
        return closingStockQty * lots.last.rate;
      }
      return 0.0;
    }

    double closingValue = 0.0;
    double remainingQty = closingStockQty;
    double tempOutWardQty = 0.0;

    for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
      final lot = lots[i];
      if (lot.qty == 0) continue;
      if (lot.type == StockInOutType.outward) {
        tempOutWardQty += lot.qty;
      } else {
        if (tempOutWardQty <= 0) {
          if (lot.qty <= remainingQty) {
            closingValue += lot.amount;
            remainingQty -= lot.qty;
          } else {
            closingValue += remainingQty * lot.rate;
            remainingQty = 0;
          }
        } else {
          if (lot.qty <= tempOutWardQty) {
            tempOutWardQty -= lot.qty;
          } else {
            final tempLotQty = lot.qty - tempOutWardQty;
            tempOutWardQty = 0;

            if (tempLotQty <= remainingQty) {
              closingValue += (tempLotQty * lot.rate);
              remainingQty -= tempLotQty;
            } else {
              closingValue += remainingQty * lot.rate;
              remainingQty = 0;
            }
          }
        }
      }
    }

    return closingValue;
  }

  // Process transactions
  Set<String> processedVouchers = {};

  for (var txn in allTransactions) {
    final voucherGuid = txn.voucherGuid;

    if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) {
      continue;
    }
    processedVouchers.add(voucherGuid);

    final dateStr = txn.voucherDate;
    final voucherType = txn.voucherType;
    final voucherNumber = txn.voucherNumber;

    if (dateStr.compareTo(toDate) > 0) {
      break;
    }

    final txnFyStart = getFinancialYearStartDate(dateStr);

    // Check for FY boundary - reset stock valuation
    if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
      // Calculate closing for each godown and reset
      for (var godown in totalInwardQty.keys) {
        final inwardQty = totalInwardQty[godown]!;
        final outwardQty = totalOutwardQty[godown]!;
        final closingStockQty = inwardQty - outwardQty;

        if (closingStockQty > 0) {
          final lots = stockLots[godown]!;
          final closingValue = calculateLifoClosingValue(lots, closingStockQty);
          final closingRate = closingValue / closingStockQty;

          // Reset with closing as new opening
          totalInwardQty[godown] = closingStockQty;
          totalOutwardQty[godown] = 0.0;
          stockLots[godown] = [
            StockLot(
              voucherGuid: 'FY_OPENING_$txnFyStart',
              voucherDate: txnFyStart,
              voucherNumber: 'FY Opening Balance',
              voucherType: 'Opening',
              qty: closingStockQty,
              amount: closingValue,
              rate: closingRate,
              type: StockInOutType.inward,
            )
          ];
        }else if (closingStockQty < 0) {
          // Negative stock: use Average Cost method
          final lots = stockLots[godown]!;
          double totalLotValue = 0.0;
          double totalLotQty = 0.0;
          for (var lot in lots) {
            if (lot.type == StockInOutType.inward) {
              totalLotValue += lot.amount;
              totalLotQty += lot.qty;
            }
          }
          final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
          final closingValue = closingStockQty * closingRate;

          // Reset with negative opening
          totalInwardQty[godown] = closingStockQty;
          totalOutwardQty[godown] = 0.0;
          stockLots[godown] = [
            StockLot(
              voucherGuid: 'FY_OPENING_$txnFyStart',
              voucherDate: txnFyStart,
              voucherNumber: 'FY Opening Balance',
              voucherType: 'Opening',
              qty: closingStockQty,
              amount: closingValue,
              rate: closingRate,
              type: StockInOutType.inward,
            )
          ];
        } else {
          // No stock, reset to zero
          totalInwardQty[godown] = 0.0;
          totalOutwardQty[godown] = 0.0;
          stockLots[godown] = [];
        }
      }
    }

    currentFyStart = txnFyStart;

    // Skip Delivery Notes that have corresponding GST TAX INVOICE
    final isDeliveryNote = voucherType.toLowerCase().contains('delivery note');
    final isReceiptNote = voucherType.toLowerCase().contains('receipt note');

    if (isDeliveryNote) {
      bool hasInvoice = false;
      for (var otherTxn in allTransactions) {
        if (otherTxn.voucherDate == dateStr &&
            otherTxn.voucherNumber == voucherNumber) {
          hasInvoice = true;
          break;
        }
      }
      if (hasInvoice){
                // print("Delivery Note With Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
                continue;
            }else{
                // print("Delivery Note Without Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
            }    
      }

    if (isReceiptNote) {
      bool hasInvoice = false;
      for (var otherTxn in allTransactions) {
        if (otherTxn.voucherDate == dateStr &&
            otherTxn.voucherNumber == voucherNumber) {
          hasInvoice = true;
          break;
        }
      }
      if (hasInvoice){
          // print("Receipt Note With Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
          continue;
      }else{
          // print("Receipt Note Without Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
      }
    }

    final batches = voucherBatches[voucherGuid]!;

    final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
    final isStockJournal = stockJournalVoucherType.contains(voucherType);

    // final isCreditNote = voucherType.toLowerCase().contains('cr') || voucherType == 'Credit Note';
    // final isDebitNote = voucherType.toLowerCase().contains('debit') || voucherType == 'Debit Note';
    // final isStockJournal = voucherType.toLowerCase().contains('sttp') || voucherType.toLowerCase().contains('stock journal') || voucherType == 'Stock Journal';

    if (voucherType == 'Physical Stock') {
      continue;
    }

    for (var batch in batches) {
      final godown = batch.godownName;
      final amount = batch.amount;
      final qty = batch.stock;
      final isInward = batch.isInward;
      final absAmount = amount.abs();

      if (amount == 0 && !isStockJournal) {
        continue;
      }

      if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
        continue;
      }

      // Initialize godown if not exists
      if (!totalOutwardQty.containsKey(godown)) {
        totalOutwardQty[godown] = 0.0;
      }

      if (!totalInwardQty.containsKey(godown)) {
        totalInwardQty[godown] = 0.0;
      }

      if (!stockLots.containsKey(godown)) {
        stockLots[godown] = [];
      }

      if (isInward) {
        if (isCreditNote) {
          totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
        } else {
          totalInwardQty[godown] = totalInwardQty[godown]! + qty;

          final rate = qty > 0 ? absAmount / qty : 0.0;
          stockLots[godown]!.add(StockLot(
            voucherGuid: voucherGuid,
            voucherDate: dateStr,
            voucherNumber: voucherNumber,
            voucherType: voucherType,
            qty: qty,
            amount: absAmount,
            rate: rate,
            type: StockInOutType.inward,
          ));
        }
      } else {
        if (isDebitNote) {
          totalInwardQty[godown] = totalInwardQty[godown]! + qty;
        } else {
          totalOutwardQty[godown] = totalOutwardQty[godown]! + qty;
          final rate = qty > 0 ? absAmount / qty : 0.0;
          stockLots[godown]!.add(StockLot(
            voucherGuid: voucherGuid,
            voucherDate: dateStr,
            voucherNumber: voucherNumber,
            voucherType: voucherType,
            qty: qty,
            amount: absAmount,
            rate: rate,
            type: StockInOutType.outward,
          ));
        }
      }
    }
  }

  // Calculate closing stock and value for each godown
  for (var godown in totalInwardQty.keys) {
    final inwardQty = totalInwardQty[godown]!;
    final outwardQty = totalOutwardQty[godown]!;
    final closingStockQty = inwardQty - outwardQty;

    double closingValue = 0.0;
    final lots = stockLots[godown]!;

    if (closingStockQty > 0) {
      closingValue = calculateLifoClosingValue(lots, closingStockQty);
    } else if (closingStockQty < 0) {
      // Negative stock: use Average Cost method
      double totalLotValue = 0.0;
      double totalLotQty = 0.0;
      for (var lot in lots) {
        totalLotValue += lot.amount;
        totalLotQty += lot.qty;
      }
      final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
      closingValue = closingStockQty * closingRate;
    }

    godownResults[godown] = GodownAverageCost(
      godownName: godown,
      totalInwardQty: inwardQty,
      totalInwardValue: outwardQty,
      currentStockQty: closingStockQty,
      averageRate: closingStockQty > 0 ? closingValue / closingStockQty : 0.0,
      closingValue: closingValue,
    );
  }

  return AverageCostResult(
    stockItemGuid: stockItem.stockItemGuid,
    itemName: stockItem.itemName,
    godowns: godownResults,
  );
}

Future<AverageCostResult> calculateFifoCost({
  required StockItemInfo stockItem,
  required Map<String, List<StockTransaction>> godownTransactions,
  required String fromDate,
  required String toDate,
  required String companyGuid,
}) async {
  Map<String, GodownAverageCost> godownResults = {};

  const financialYearStartMonth = 4;
  const financialYearStartDay = 1;

  String getFinancialYearStartDate(String dateStr) {
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));

    if (month < financialYearStartMonth) {
      return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
    } else {
      return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
    }
  }




  // Per godown tracking
  Map<String, double> totalInwardQty = {};
  Map<String, double> totalOutwardQty = {};
  Map<String, List<StockLot>> inwardLots = {}; // Only inward lots

  // Flatten all transactions and sort by date
  List<StockTransaction> allTransactions = [];
  for (var godownTxns in godownTransactions.values) {
    allTransactions.addAll(godownTxns);
  }
  allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

  // Group transactions by voucher_guid
  Map<String, List<StockTransaction>> voucherBatches = {};
  for (var txn in allTransactions) {
    if (!voucherBatches.containsKey(txn.voucherGuid)) {
      voucherBatches[txn.voucherGuid] = [];
    }
    voucherBatches[txn.voucherGuid]!.add(txn);
  }

  // Initialize with opening stock
  for (final godownOpeningData in stockItem.openingData) {
    String godownName = godownOpeningData.godownName;
    if (godownName.isEmpty) {
      godownName = 'Main Location';
    }

    final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
    final openingAmount = godownOpeningData.amount.abs();

    totalInwardQty[godownName] = openingQty.abs();
    totalOutwardQty[godownName] = 0.0;
    inwardLots[godownName] = [];

    if (openingQty > 0) {
      final openingRate = openingAmount / openingQty;
      inwardLots[godownName]!.add(StockLot(
        voucherGuid: 'OPENING_STOCK',
        voucherDate: fromDate,
        voucherNumber: 'Opening Balance',
        voucherType: 'Opening',
        qty: openingQty,
        amount: openingAmount,
        rate: openingRate,
        type: StockInOutType.inward,
      ));
    }
  }

  String currentFyStart = '';

  // Helper function to calculate closing value using FIFO logic (backwards from last)
  double calculateFifoClosingValue(List<StockLot> lots, double closingStockQty) {
    if (closingStockQty <= 0 || lots.isEmpty) {
      return 0.0;
    }

    double closingValue = 0.0;
    double remainingQty = closingStockQty;
    double lastRate = 0.0;

    // FIFO: Go backwards from LAST inward lot (newest first)
    for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
      final lot = lots[i];
      lastRate = lot.rate;

      if (lot.qty == 0){
        closingValue += lot.amount;
      }else if (lot.qty <= remainingQty) {
        // Take entire lot
        closingValue += lot.amount;
        remainingQty -= lot.qty;
      } else {
        // Take partial lot
        closingValue += remainingQty * lot.rate;
        remainingQty = 0;
      }
    }

    if (remainingQty > 0){
      closingValue += remainingQty * lastRate;
    }

    return closingValue;
  }

  // Process transactions
  Set<String> processedVouchers = {};

  for (var txn in allTransactions) {

    final voucherGuid = txn.voucherGuid;

    if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) {
      continue;
    }

        // print("${txn.voucherDate}, ${txn.godownName}, ${txn.voucherType}, ${txn.stock}, ${txn.rate}, ${txn.amount}, ${txn.voucherGuid}");

    processedVouchers.add(voucherGuid);

    final dateStr = txn.voucherDate;
    final voucherType = txn.voucherType;
    final voucherNumber = txn.voucherNumber;

    if (dateStr.compareTo(toDate) > 0) {
      break;
    }

    final txnFyStart = getFinancialYearStartDate(dateStr);

    // Check for FY boundary - reset stock valuation
    if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
      // Calculate closing for each godown and reset
      for (var godown in totalInwardQty.keys) {
        final inwardQty = totalInwardQty[godown]!;
        final outwardQty = totalOutwardQty[godown]!;
        final closingStockQty = inwardQty - outwardQty;

        if (closingStockQty > 0) {
          final lots = inwardLots[godown]!;
          final closingValue = calculateFifoClosingValue(lots, closingStockQty);
          final closingRate = closingValue / closingStockQty;

          // Reset with closing as new opening
          totalInwardQty[godown] = closingStockQty;
          totalOutwardQty[godown] = 0.0;
          inwardLots[godown] = [
            StockLot(
              voucherGuid: 'FY_OPENING_$txnFyStart',
              voucherDate: txnFyStart,
              voucherNumber: 'FY Opening Balance',
              voucherType: 'Opening',
              qty: closingStockQty,
              amount: closingValue,
              rate: closingRate,
              type: StockInOutType.inward,
            )
          ];
        }else if (closingStockQty < 0) {
          // Negative stock: use Average Cost method
          final lots = inwardLots[godown]!;
          double totalLotValue = 0.0;
          double totalLotQty = 0.0;
          for (var lot in lots) {
            totalLotValue += lot.amount;
            totalLotQty += lot.qty;
          }
          final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
          final closingValue = closingStockQty * closingRate;

          // Reset with negative opening
          totalInwardQty[godown] = closingStockQty;
          totalOutwardQty[godown] = 0.0;
          inwardLots[godown] = [
            StockLot(
              voucherGuid: 'FY_OPENING_$txnFyStart',
              voucherDate: txnFyStart,
              voucherNumber: 'FY Opening Balance',
              voucherType: 'Opening',
              qty: closingStockQty,
              amount: closingValue,
              rate: closingRate,
              type: StockInOutType.inward,
            )
          ];
        } else {
          // No stock, reset to zero
          totalInwardQty[godown] = 0.0;
          totalOutwardQty[godown] = 0.0;
          inwardLots[godown] = [];
        }
      }
    }

    currentFyStart = txnFyStart;

    // Skip Delivery Notes that have corresponding GST TAX INVOICE
    final isDeliveryNote = voucherType.toLowerCase().contains('delivery note');
    final isReceiptNote = voucherType.toLowerCase().contains('receipt note');

    if (isDeliveryNote) {
      bool hasInvoice = false;
      for (var otherTxn in allTransactions) {
        if (otherTxn.voucherDate == dateStr &&
            otherTxn.voucherNumber == voucherNumber) {
          hasInvoice = true;
          break;
        }
      }
      if (hasInvoice){
                // print("Delivery Note With Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
                continue;
            }else{
                // print("Delivery Note Without Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
            }    
      }

    if (isReceiptNote) {
      bool hasInvoice = false;
      for (var otherTxn in allTransactions) {
        if (otherTxn.voucherDate == dateStr &&
            otherTxn.voucherNumber == voucherNumber) {
          hasInvoice = true;
          break;
        }
      }
      if (hasInvoice){
          // print("Receipt Note With Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
          continue;
      }else{
          // print("Receipt Note Without Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
      }
    }

    final batches = voucherBatches[voucherGuid]!;
    final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
    final isStockJournal = stockJournalVoucherType.contains(voucherType);

    // final isCreditNote = voucherType.toLowerCase().contains('cr') ||
    //     voucherType == 'Credit Note';
    // final isDebitNote = voucherType.toLowerCase().contains('debit') ||
    //     voucherType == 'Debit Note';
    //   final isStockJournal = voucherType.toLowerCase().contains('sttp') || voucherType.toLowerCase().contains('stock journal') || voucherType == 'Stock Journal';

    if (voucherType == 'Physical Stock') {
      continue;
    }

    for (var batch in batches) {
      final godown = batch.godownName;
      final amount = batch.amount;
      final qty = batch.stock;
      final isInward = batch.isInward;
      final absAmount = amount.abs();

      if (amount == 0 && !isStockJournal) {
        continue;
      }

      if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
        continue;
      }

      // Initialize godown if not exists
      if (!totalOutwardQty.containsKey(godown)) {
        totalOutwardQty[godown] = 0.0;
      }

      if (!totalInwardQty.containsKey(godown)) {
        totalInwardQty[godown] = 0.0;
      }

      if (!inwardLots.containsKey(godown)) {
        inwardLots[godown] = [];
      }

      if (isInward) {
        if (isCreditNote) {
          totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
        } else {
          // Add to inward qty and store lot
          totalInwardQty[godown] = totalInwardQty[godown]! + qty;

          final rate = qty > 0 ? absAmount / qty : 0.0;
          inwardLots[godown]!.add(StockLot(
            voucherGuid: voucherGuid,
            voucherDate: dateStr,
            voucherNumber: voucherNumber,
            voucherType: voucherType,
            qty: qty,
            amount: absAmount,
            rate: rate,
            type: StockInOutType.inward,
          ));
        }
      } else {
        if (isDebitNote) {
          totalInwardQty[godown] = totalInwardQty[godown]! - qty;
        } else {
          // Just track outward qty, no need to store lot
          totalOutwardQty[godown] = totalOutwardQty[godown]! + qty;
        }
      }
    }
  }

  // Calculate closing stock and value for each godown
  for (var godown in totalInwardQty.keys) {
    final inwardQty = totalInwardQty[godown]!;
    final outwardQty = totalOutwardQty[godown]!;
    final closingStockQty = inwardQty - outwardQty;

    double closingValue = 0.0;
    final lots = inwardLots[godown]!;

    if (closingStockQty > 0) {
      closingValue = calculateFifoClosingValue(lots, closingStockQty);
    }else if (closingStockQty < 0) {
      // Negative stock: use Average Cost method
      double totalLotValue = 0.0;
      double totalLotQty = 0.0;
      for (var lot in lots) {
        totalLotValue += lot.amount;
        totalLotQty += lot.qty;
      }
      final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
      closingValue = closingStockQty * closingRate;
    }

    godownResults[godown] = GodownAverageCost(
      godownName: godown,
      totalInwardQty: inwardQty,
      totalInwardValue: outwardQty,
      currentStockQty: closingStockQty,
      averageRate: closingStockQty > 0 ? closingValue / closingStockQty : 0.0,
      closingValue: closingValue,
    );
  }

  return AverageCostResult(
    stockItemGuid: stockItem.stockItemGuid,
    itemName: stockItem.itemName,
    godowns: godownResults,
  );
}

  // Future<AverageCostResult> calculateFifoCost({
  //   required StockItemInfo stockItem,
  //   required Map<String, List<StockTransaction>> godownTransactions,
  //   required String fromDate,
  //   required String toDate,
  //   required String companyGuid,
  // }) async {
  //   Map<String, GodownAverageCost> godownResults = {};

  //   // Per godown tracking
  //   Map<String, double> totalInwardQty = {};
  //   Map<String, double> totalOutwardQty = {};
  //   Map<String, List<StockLot>> stockLots = {}; // All inward vouchers in order

  //   // Flatten all transactions and sort by date
  //   List<StockTransaction> allTransactions = [];
  //   for (var godownTxns in godownTransactions.values) {
  //     allTransactions.addAll(godownTxns);
  //   }
  //   allTransactions.sort((a, b) => b.voucherId.compareTo(a.voucherId));

  //   // Group transactions by voucher_guid
  //   Map<String, List<StockTransaction>> voucherBatches = {};
  //   for (var txn in allTransactions) {
  //     if (!voucherBatches.containsKey(txn.voucherGuid)) {
  //       voucherBatches[txn.voucherGuid] = [];
  //     }
  //     voucherBatches[txn.voucherGuid]!.add(txn);
  //   }

  //   // Initialize with opening stock
  //   for (final godownOpeningData in stockItem.openingData) {
  //     String godownName = godownOpeningData.godownName;
  //     if (godownName.isEmpty) {
  //       godownName = 'Main Location';
  //     }

  //     final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
  //     final openingAmount = godownOpeningData.amount.abs();

  //     totalInwardQty[godownName] = openingQty.abs();
  //     totalOutwardQty[godownName] = 0.0;
  //     stockLots[godownName] = [];

  //     if (openingQty > 0) {
  //       final openingRate = openingAmount / openingQty;
  //       stockLots[godownName]!.add(StockLot(
  //         voucherGuid: 'OPENING_STOCK',
  //         voucherDate: fromDate,
  //         voucherNumber: 'Opening Balance',
  //         voucherType: 'Opening',
  //         qty: openingQty,
  //         amount: openingAmount,
  //         rate: openingRate,
  //         type: StockInOutType.inward
  //       ));
  //     }
  //   }

  //   // Process transactions
  //   Set<String> processedVouchers = {};

  //   for (var txn in allTransactions) {
  //     final voucherGuid = txn.voucherGuid;

  //     if (processedVouchers.contains(voucherGuid)) {
  //       continue;
  //     }
  //     processedVouchers.add(voucherGuid);

  //     final dateStr = txn.voucherDate;
  //     final voucherType = txn.voucherType;
  //     final voucherNumber = txn.voucherNumber;

  //     if (dateStr.compareTo(toDate) > 0) {
  //       break;
  //     }

  //     // Skip Delivery Notes that have corresponding GST TAX INVOICE
  //     final isDeliveryNote =
  //         voucherType.toLowerCase().contains('delivery note');

  //     if (isDeliveryNote) {
  //       bool hasInvoice = false;
  //       for (var otherTxn in allTransactions) {
  //         if (otherTxn.voucherType.toLowerCase().contains('gst tax invoice') &&
  //             otherTxn.voucherDate == dateStr &&
  //             otherTxn.voucherNumber == voucherNumber) {
  //           hasInvoice = true;
  //           break;
  //         }
  //       }
  //       if (hasInvoice) continue;
  //     }

  //     final batches = voucherBatches[voucherGuid]!;

  //     final isCreditNote = voucherType.toLowerCase().contains('credit') ||
  //         voucherType == 'Credit Note';
  //     final isDebitNote = voucherType.toLowerCase().contains('debit') ||
  //         voucherType == 'Debit Note';
  //     final isStockJournal = voucherType == 'Stock Journal';

  //     if (voucherType == 'Physical Stock') {
  //       continue;
  //     }

  //     for (var batch in batches) {
  //       final godown = batch.godownName;
  //       final amount = batch.amount;
  //       final qty = batch.stock;
  //       final isInward = batch.isInward;
  //       final absAmount = amount.abs();

  //       if (amount == 0 && !isStockJournal) {
  //         continue;
  //       }
  //       if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
  //         continue;
  //       }

  //       // Initialize godown if not exists
  //       if (!totalInwardQty.containsKey(godown)) {
  //         totalInwardQty[godown] = 0.0;
  //         totalOutwardQty[godown] = 0.0;
  //         stockLots[godown] = [];
  //       }

  //       if (isInward) {
  //         // INWARD: Add to total inward qty and store lot
  //         if (isCreditNote) {
  //           totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
  //         } else {
  //           totalInwardQty[godown] = totalInwardQty[godown]! + qty;

  //           final rate = qty > 0 ? absAmount / qty : 0.0;
  //           stockLots[godown]!.add(StockLot(
  //             voucherGuid: voucherGuid,
  //             voucherDate: dateStr,
  //             voucherNumber: voucherNumber,
  //             voucherType: voucherType,
  //             qty: qty,
  //             amount: absAmount,
  //             rate: rate,
  //             type: StockInOutType.inward
  //           ));
  //         }
  //       } else {
  //         if (isDebitNote) {
  //           totalInwardQty[godown] = totalInwardQty[godown]! + qty;
  //           // final rate = qty > 0 ? absAmount / qty : 0.0;
  //           // stockLots[godown]!.add(StockLot(
  //           //   voucherGuid: voucherGuid,
  //           //   voucherDate: dateStr,
  //           //   voucherNumber: voucherNumber,
  //           //   voucherType: voucherType,
  //           //   qty: qty,
  //           //   amount: absAmount,
  //           //   rate: rate,
  //           //   type: StockInOutType.inward
  //           // ));
  //         } else {
  //           totalOutwardQty[godown] = totalOutwardQty[godown]! + qty;
  //         }
  //         // OUTWARD: Add to total outward qty
  //       }
  //     }
  //   }


  //   // Calculate closing stock and value for each godown
  //   for (var godown in totalInwardQty.keys) {
  //     final inwardQty = totalInwardQty[godown]!;
  //     final outwardQty = totalOutwardQty[godown]!;
  //     final closingStockQty = inwardQty - outwardQty;

  //     double closingValue = 0.0;
  //     List<StockLot> usedLots = [];
  //     final lots = stockLots[godown]!;

  //     if (closingStockQty > 0) {
  //       // Go backwards from last inward voucher
  //       double remainingQty = closingStockQty;

  //       // Iterate from last to first
  //       for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
  //         final lot = lots[i];

  //         if (lot.qty <= remainingQty) {
  //           // Take entire lot
  //           closingValue += lot.amount;
  //           remainingQty -= lot.qty;
  //           usedLots.insert(0, lot); // Insert at beginning to maintain order
  //         } else {
  //           // Take partial lot
  //           closingValue += remainingQty * lot.rate;
  //           usedLots.insert(
  //               0,
  //               StockLot(
  //                 voucherGuid: lot.voucherGuid,
  //                 voucherDate: lot.voucherDate,
  //                 voucherNumber: lot.voucherNumber,
  //                 voucherType: lot.voucherType,
  //                 qty: remainingQty,
  //                 amount: remainingQty * lot.rate,
  //                 rate: lot.rate,
  //                 type: lot.type
  //               ));
  //           remainingQty = 0;
  //         }
  //       }
  //     } else {
  //       final lastStockLot = lots.last;

  //       closingValue = closingStockQty * lastStockLot.rate;
  //     }

  //     // godownResults[godown] = GodownFifoCost(
  //     //   godownName: godown,
  //     //   totalInwardQty: inwardQty,
  //     //   totalOutwardQty: outwardQty,
  //     //   closingStockQty: closingStockQty,
  //     //   closingValue: closingValue,
  //     //   usedLots: usedLots,
  //     // );

  //     godownResults[godown] = GodownAverageCost(
  //       godownName: godown,
  //       totalInwardQty: inwardQty,
  //       totalInwardValue: outwardQty,
  //       currentStockQty: closingStockQty,
  //       averageRate: closingStockQty > 0 ? closingValue / closingStockQty : 0.0,
  //       closingValue: closingValue,
  //     );
  //   }

  //   // return FifoCostResult(
  //   //   stockItemGuid: stockItem.stockItemGuid,
  //   //   itemName: stockItem.itemName,
  //   //   godowns: godownResults,
  //   // );

  //   return AverageCostResult(
  //     stockItemGuid: stockItem.stockItemGuid,
  //     itemName: stockItem.itemName,
  //     godowns: godownResults,
  //   );
  // }

  Future<AverageCostResult> calculateAvgCost({
    required StockItemInfo stockItem,
    required Map<String, List<StockTransaction>> godownTransactions,
    required String fromDate,
    required String toDate,
    required String companyGuid,
  }) async {
    Map<String, GodownAverageCost> godownResults = {};

    Map<String, double> totalInwardQty = {};
    Map<String, double> totalInwardValue = {};
    Map<String, double> totalOutwardQty = {};

    const financialYearStartMonth = 4;
    const financialYearStartDay = 1;

    String getFinancialYearStartDate(String dateStr) {
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));

      if (month < financialYearStartMonth) {
        return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
      } else {
        return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
      }
    }

    // Flatten all transactions and sort by date
    List<StockTransaction> allTransactions = [];
    for (var godownTxns in godownTransactions.values) {
      allTransactions.addAll(godownTxns);
    }
    allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

    // Group transactions by voucher_guid
    Map<String, List<StockTransaction>> voucherBatches = {};
    for (var txn in allTransactions) {
      if (!voucherBatches.containsKey(txn.voucherGuid)) {
        voucherBatches[txn.voucherGuid] = [];
      }
      voucherBatches[txn.voucherGuid]!.add(txn);
    }

    // Initialize with opening stock
    for (final godownOpeningData in stockItem.openingData) {
      String godownName = godownOpeningData.godownName;
      if (godownName.isEmpty) {
        godownName = 'Main Location';
      }

      final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
      final openingAmount = godownOpeningData.amount.abs();

      totalInwardQty[godownName] = openingQty.abs();
      totalInwardValue[godownName] = openingAmount;
      totalOutwardQty[godownName] = 0.0;
    }

    String currentFyStart = '';

    // Process transactions
    Set<String> processedVouchers = {};

    for (var txn in allTransactions) {
      final voucherGuid = txn.voucherGuid;

      if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) {
        continue;
      }
      processedVouchers.add(voucherGuid);

      final dateStr = txn.voucherDate;
      final voucherType = txn.voucherType;
      final voucherNumber = txn.voucherNumber;

      if (dateStr.compareTo(toDate) > 0) {
        break;
      }

      final txnFyStart = getFinancialYearStartDate(dateStr);

      // Check for FY boundary - reset rate
      if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
        // Calculate closing for previous FY and reset as opening for new FY
        for (var godown in totalInwardQty.keys) {
          final inwardQty = totalInwardQty[godown]!;
          final inwardValue = totalInwardValue[godown]!;
          final outwardQty = totalOutwardQty[godown]!;
          final closingQty = inwardQty - outwardQty;

          final closingRate = inwardQty > 0 ? inwardValue / inwardQty : 0.0;
          final closingValue = closingQty * closingRate;

          // Reset: closing becomes new opening
          totalInwardQty[godown] = closingQty;
          totalInwardValue[godown] = closingValue;
          totalOutwardQty[godown] = 0.0;
        }
      }

      currentFyStart = txnFyStart;

      // Skip Delivery Notes that have corresponding GST TAX INVOICE
      final isDeliveryNote = voucherType.toLowerCase().contains('delivery note');
    final isReceiptNote = voucherType.toLowerCase().contains('receipt note');

    if (isDeliveryNote) {
      bool hasInvoice = false;
      for (var otherTxn in allTransactions) {
        if (otherTxn.voucherDate == dateStr &&
            otherTxn.voucherNumber == voucherNumber) {
          hasInvoice = true;
          break;
        }
      }
      if (hasInvoice){
                // print("Delivery Note With Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
                continue;
            }else{
                // print("Delivery Note Without Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
            }    
      }

    if (isReceiptNote) {
      bool hasInvoice = false;
      for (var otherTxn in allTransactions) {
        if (otherTxn.voucherDate == dateStr &&
            otherTxn.voucherNumber == voucherNumber) {
          hasInvoice = true;
          break;
        }
      }
      if (hasInvoice){
          // print("Receipt Note With Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
          continue;
      }else{
          // print("Receipt Note Without Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
      }
    }

      final batches = voucherBatches[voucherGuid]!;
    final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
    final isStockJournal = stockJournalVoucherType.contains(voucherType);

      // final isCreditNote = voucherType.toLowerCase().contains('cr') ||
      //     voucherType == 'Credit Note';
      // final isDebitNote = voucherType.toLowerCase().contains('debit') ||
      //     voucherType == 'Debit Note';
      // final isStockJournal = voucherType.toLowerCase().contains('sttp') || voucherType.toLowerCase().contains('stock journal') || voucherType == 'Stock Journal';

      if (voucherType == 'Physical Stock') {
        continue;
      }

      for (var batch in batches) {
        final godown = batch.godownName;
        final amount = batch.amount;
        final qty = batch.stock;
        final isInward = batch.isInward;
        final absAmount = amount.abs();

        if (amount == 0 && !isStockJournal) {
          continue;
        }
        if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
          continue;
        }

        // Initialize godown if not exists
        if (!totalInwardQty.containsKey(godown)) {
          totalInwardQty[godown] = 0.0;
          totalInwardValue[godown] = 0.0;
        }

        if (!totalOutwardQty.containsKey(godown)) {
          totalOutwardQty[godown] = 0.0;
        }

        if (isInward) {
          if (isCreditNote) {
            totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
          } else {
            totalInwardQty[godown] = totalInwardQty[godown]! + qty;
            totalInwardValue[godown] = totalInwardValue[godown]! + absAmount;
          }
        } else {
          // OUTWARD: Add to total outward qty
          if (isDebitNote) {
            totalInwardQty[godown] = totalInwardQty[godown]! - qty;
            totalInwardValue[godown] = totalInwardValue[godown]! - absAmount;
          } else {
            totalOutwardQty[godown] = totalOutwardQty[godown]! + qty;
          }
        }
      }
    }

    // Calculate closing stock and value for each godown
    for (var godown in totalInwardQty.keys) {
      final inwardQty = totalInwardQty[godown]!;
      final inwardValue = totalInwardValue[godown]!;
      final outwardQty = totalOutwardQty[godown]!;
      final closingStockQty = inwardQty - outwardQty;
      final closingRate = inwardQty > 0 ? inwardValue / inwardQty : 0.0;

      godownResults[godown] = GodownAverageCost(
        godownName: godown,
        totalInwardQty: inwardQty,
        totalInwardValue: outwardQty,
        currentStockQty: closingStockQty,
        averageRate: closingRate > 0 ? closingRate : 0.0,
        closingValue: closingStockQty * closingRate,
      );
    }

    return AverageCostResult(
      stockItemGuid: stockItem.stockItemGuid,
      itemName: stockItem.itemName,
      godowns: godownResults,
    );
  }

  Future<AverageCostResult> calculateCostWithoutUnit({
    required StockItemInfo stockItem,
    required Map<String, List<StockTransaction>> godownTransactions,
    required String fromDate,
    required String toDate,
    required String companyGuid,
  }) async {
    Map<String, GodownAverageCost> godownResults = {};

    Map<String, double> totalInwardValue = {};
    Map<String, double> totalOutwardValue = {};


    // Flatten all transactions and sort by date
    List<StockTransaction> allTransactions = [];
    for (var godownTxns in godownTransactions.values) {
      allTransactions.addAll(godownTxns);
    }
    allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

    // Group transactions by voucher_guid
    Map<String, List<StockTransaction>> voucherBatches = {};
    for (var txn in allTransactions) {
      if (!voucherBatches.containsKey(txn.voucherGuid)) {
        voucherBatches[txn.voucherGuid] = [];
      }
      voucherBatches[txn.voucherGuid]!.add(txn);
    }

    // Initialize with opening stock
    for (final godownOpeningData in stockItem.openingData) {
      String godownName = godownOpeningData.godownName;
      if (godownName.isEmpty) {
        godownName = 'Main Location';
      }

      final openingAmount = godownOpeningData.amount;

      totalInwardValue[godownName] = openingAmount;
    }


    // Process transactions
    Set<String> processedVouchers = {};

    for (var txn in allTransactions) {
      final voucherGuid = txn.voucherGuid;

      if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) {
        continue;
      }
      processedVouchers.add(voucherGuid);

      final dateStr = txn.voucherDate;
      final voucherType = txn.voucherType;
      final voucherNumber = txn.voucherNumber;

      if (dateStr.compareTo(toDate) > 0) {
        break;
      }

      final batches = voucherBatches[voucherGuid]!;
          final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
    final isStockJournal = stockJournalVoucherType.contains(voucherType);


      // final isCreditNote = voucherType.toLowerCase().contains('cr') ||
      //     voucherType == 'Credit Note';
      // final isDebitNote = voucherType.toLowerCase().contains('debit') ||
      //     voucherType == 'Debit Note';
      // final isStockJournal = voucherType.toLowerCase().contains('sttp') || voucherType.toLowerCase().contains('stock journal') || voucherType == 'Stock Journal';

      if (voucherType == 'Physical Stock') {
        continue;
      }

      for (var batch in batches) {
        final godown = batch.godownName;
        final amount = batch.amount;
        final isInward = batch.isInward;
        final absAmount = amount.abs();

          final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

      // final isCreditNote = voucherType.toLowerCase().contains('cr') ||
      //     voucherType == 'Credit Note';
      // final isDebitNote = voucherType.toLowerCase().contains('debit') ||
      //     voucherType == 'Debit Note';

      if (!totalInwardValue.containsKey(godown)) {
          totalInwardValue[godown] = 0.0;
        }

        if (!totalOutwardValue.containsKey(godown)) {
          totalOutwardValue[godown] = 0.0;
        }
    if (isInward) {
          if (isCreditNote) {
            totalOutwardValue[godown] = totalOutwardValue[godown]! - absAmount;
          } else {
            totalInwardValue[godown] = totalInwardValue[godown]! + absAmount;
          }
        } else {
          // OUTWARD: Add to total outward qty
          if (isDebitNote) {
            totalInwardValue[godown] = totalInwardValue[godown]! - absAmount;
          } else {
            totalOutwardValue[godown] = totalOutwardValue[godown]! + absAmount;
          }
        }
      }
      
    }

    // Calculate closing stock and value for each godown
    for (var godown in totalInwardValue.keys) {
      final inwardValue = totalInwardValue[godown] ?? 0.0;
      final outwardValue = totalOutwardValue[godown] ?? 0.0;

      godownResults[godown] = GodownAverageCost(
        godownName: godown,
        totalInwardQty: 0,
        totalInwardValue: inwardValue,
        currentStockQty: 0,
        averageRate: 0.0,
        closingValue: inwardValue - outwardValue,
      );
    }

    return AverageCostResult(
      stockItemGuid: stockItem.stockItemGuid,
      itemName: stockItem.itemName,
      godowns: godownResults,
    );
  }

// Future<AverageCostResult> calculateAvgCost({
//   required StockItemInfo stockItem,
//   required Map<String, List<StockTransaction>> godownTransactions,
//   required String fromDate,
//   required String toDate,
//   required String companyGuid,
// }) async {
//   Map<String, GodownAverageCost> godownResults = {};
//   //  if (stockItem.itemName == 'Finaslip E'){
//   //   print("a");
//   // }
//   // Per godown tracking
//   Map<String, double> totalInwardQty = {};
//   Map<String, double> totalInwardValue = {};
//   Map<String, double> totalOutwardQty = {};

//   // Flatten all transactions and sort by date
//   List<StockTransaction> allTransactions = [];
//   for (var godownTxns in godownTransactions.values) {
//     allTransactions.addAll(godownTxns);
//   }
//   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

//   // Group transactions by voucher_guid
//   Map<String, List<StockTransaction>> voucherBatches = {};
//   for (var txn in allTransactions) {
//     if (!voucherBatches.containsKey(txn.voucherGuid)) {
//       voucherBatches[txn.voucherGuid] = [];
//     }
//     voucherBatches[txn.voucherGuid]!.add(txn);
//   }

//   // Initialize with opening stock
//   for (final godownOpeningData in stockItem.openingData) {
//     String godownName = godownOpeningData.godownName;
//     if (godownName.isEmpty) {
//       godownName = 'Main Location';
//     }

//     final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
//     final openingAmount = godownOpeningData.amount.abs();

//     totalInwardQty[godownName] = openingQty.abs();
//     totalInwardValue[godownName] = openingAmount;
//     totalOutwardQty[godownName] = 0.0;

//   }

//   // Process transactions
//   Set<String> processedVouchers = {};

//   for (var txn in allTransactions) {
//     final voucherGuid = txn.voucherGuid;

//     if (processedVouchers.contains(voucherGuid)) {
//       continue;
//     }
//     processedVouchers.add(voucherGuid);

//     final dateStr = txn.voucherDate;
//     final voucherType = txn.voucherType;
//     final voucherNumber = txn.voucherNumber;

//     if (dateStr.compareTo(toDate) > 0) {
//       break;
//     }

//     // Skip Delivery Notes that have corresponding GST TAX INVOICE
//     final isDeliveryNote = voucherType.toLowerCase().contains('delivery note');

//     if (isDeliveryNote) {
//       bool hasInvoice = false;
//       for (var otherTxn in allTransactions) {
//         if (otherTxn.voucherType.toLowerCase().contains('gst tax invoice') &&
//             otherTxn.voucherDate == dateStr &&
//             otherTxn.voucherNumber == voucherNumber) {
//           hasInvoice = true;
//           break;
//         }
//       }
//       if (hasInvoice) continue;
//     }

//     final batches = voucherBatches[voucherGuid]!;

//     final isCreditNote = voucherType.toLowerCase().contains('credit') ||
//                          voucherType == 'Credit Note';
//     final isDebitNote = voucherType.toLowerCase().contains('debit') ||
//                         voucherType == 'Debit Note';
//     final isStockJournal = voucherType == 'Stock Journal';

//     if (voucherType == 'Physical Stock') {
//       continue;
//     }

//     for (var batch in batches) {
//       final godown = batch.godownName;
//       final amount = batch.amount;
//       final qty = batch.stock;
//       final isInward = batch.isInward;
//       final absAmount = amount.abs();

//       if (amount == 0 && !isStockJournal) {
//         continue;
//       }
//       if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
//         continue;
//       }

//       // Initialize godown if not exists
//       if (!totalInwardQty.containsKey(godown)) {
//         totalInwardQty[godown] = 0.0;
//         totalInwardValue[godown] = 0.0;
//       }

//       if (!totalOutwardQty.containsKey(godown)) {
//         totalOutwardQty[godown] = 0.0;
//       }

//       if (isInward) {

//         if (isCreditNote){
//                       totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;

//             // totalInwardQty[godown] = totalInwardQty[godown]! - qty;
//             // totalInwardValue[godown] = totalInwardValue[godown]! - absAmount;
//         }else{
//           totalInwardQty[godown] = totalInwardQty[godown]! + qty;
//           totalInwardValue[godown] = totalInwardValue[godown]! + absAmount;
//         }
//         // INWARD: Add to total inward qty and store lot

//         // if (stockItem.itemName == 'Finaslip E'){
//         //   print("Finaslip E inward : ${qty} kg => ${amount} rs ");
//         // }
//       } else {
//         // OUTWARD: Add to total outward qty
//         if (isDebitNote){
//             totalInwardQty[godown] = totalInwardQty[godown]! - qty;
//             totalInwardValue[godown] = totalInwardValue[godown]! - absAmount;
//             // totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
//         }else{
//             totalOutwardQty[godown] = totalOutwardQty[godown]! + qty;
//         }
//       }
//     }
//   }

//   if (stockItem.itemName == 'Finaslip E'){
//     print("a");
//   }

//   // Calculate closing stock and value for each godown
//   for (var godown in totalInwardQty.keys) {
//     final inwardQty = totalInwardQty[godown]!;
//     final inwardValue = totalInwardValue[godown]!;
//     final outwardQty = totalOutwardQty[godown]!;
//     final closingStockQty = inwardQty - outwardQty;
//     final closingRate =  inwardValue/inwardQty;

//     godownResults[godown] = GodownAverageCost(
//       godownName: godown,
//       totalInwardQty: inwardQty,
//       totalInwardValue: outwardQty,
//       currentStockQty: closingStockQty,
//       averageRate: closingRate > 0 ? closingRate : 0.0,
//       closingValue: closingStockQty > 0 ? closingStockQty * closingRate : 0.0,
//     );
//   }

//   // return FifoCostResult(
//   //   stockItemGuid: stockItem.stockItemGuid,
//   //   itemName: stockItem.itemName,
//   //   godowns: godownResults,
//   // );

//   return AverageCostResult(
//     stockItemGuid: stockItem.stockItemGuid,
//     itemName: stockItem.itemName,
//     godowns: godownResults,
//   );
// }

  Future<AverageCostResult> calculateAverageCost({
    required StockItemInfo stockItem,
    required Map<String, List<StockTransaction>> godownTransactions,
    required String fromDate,
    required String toDate,
    required String companyGuid,
  }) async {
    Map<String, GodownAverageCost> godownResults = {};

    // if (stockItem.itemName != 'Finaslip E') {
    //       return  AverageCostResult(
    //       stockItemGuid: '',
    //       itemName: '',
    //       godowns: godownResults,
    //     );
    // }

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

    // Flatten all transactions from all godowns and sort by date
    List<StockTransaction> allTransactions = [];
    for (var godownTxns in godownTransactions.values) {
      allTransactions.addAll(godownTxns);
    }
    allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

    // Group transactions by voucher_guid to detect multi-batch vouchers
    Map<String, List<StockTransaction>> voucherBatches = {};
    for (var txn in allTransactions) {
      if (!voucherBatches.containsKey(txn.voucherGuid)) {
        voucherBatches[txn.voucherGuid] = [];
      }
      voucherBatches[txn.voucherGuid]!.add(txn);
    }

    // Initialize with opening stock
    Map<String, Map<String, double>> fyStock = {};

    for (final godownOpeningData in stockItem.openingData) {
      String godownName = godownOpeningData.godownName;
      if (godownName.isEmpty) {
        godownName = 'Main Location';
      }

      final openingStock = double.tryParse(godownOpeningData.actualQty) ?? 0.0;

      fyStock[godownName] = {
        'total_inward_qty': openingStock.abs(),
        'total_inward_value': godownOpeningData.amount.abs(),
        'current_stock_qty': openingStock,
      };
    }

    // Find primary godown from transaction data (most active godown)
    // String primaryGodown = stockItem.openingGodownName;
    // // int maxTransactions = 0;

    // // for (var entry in godownTransactions.entries) {
    // //   if (entry.value.length > maxTransactions) {
    // //     maxTransactions = entry.value.length;
    // //     primaryGodown = entry.key;
    // //   }
    // // }

    // // If no transactions yet, use a default godown
    // if (primaryGodown.isEmpty) {
    //   primaryGodown = 'Main Location';
    // }

    // // Initialize with opening (even if 0)
    // fyStock[primaryGodown] = {
    //   'total_inward_qty': stockItem.openingStock.abs(),
    //   'total_inward_value': stockItem.openingBalance.abs(),
    //   'current_stock_qty': stockItem.openingStock,
    // };

    String currentFyStart = '';

    // Get unique voucher GUIDs in order
    Set<String> processedVouchers = {};

    for (var txn in allTransactions) {
      final voucherGuid = txn.voucherGuid;

      // if (txn.godownName != 'Narol') continue;

      // Skip if already processed this voucher
      if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) continue;
      processedVouchers.add(voucherGuid);

      final dateStr = txn.voucherDate;
      final voucherType = txn.voucherType;
      final voucherNumber = txn.voucherNumber;

      if (dateStr.compareTo(toDate) > 0) break;

      // Skip Delivery Notes that have corresponding GST TAX INVOICE
      final isDeliveryNote = voucherType.toLowerCase().contains('delivery note');
    final isReceiptNote = voucherType.toLowerCase().contains('receipt note');

    if (isDeliveryNote) {
      bool hasInvoice = false;
      for (var otherTxn in allTransactions) {
        if (otherTxn.voucherDate == dateStr &&
            otherTxn.voucherNumber == voucherNumber) {
          hasInvoice = true;
          break;
        }
      }
      if (hasInvoice){
                // print("Delivery Note With Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
                continue;
            }else{
                // print("Delivery Note Without Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
            }    
      }

    if (isReceiptNote) {
      bool hasInvoice = false;
      for (var otherTxn in allTransactions) {
        if (otherTxn.voucherDate == dateStr &&
            otherTxn.voucherNumber == voucherNumber) {
          hasInvoice = true;
          break;
        }
      }
      if (hasInvoice){
          // print("Receipt Note With Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
          continue;
      }else{
          // print("Receipt Note Without Invoice => ${stockItem.itemName}, ${voucherType}, ${txn.voucherDate}, ${txn.stock}, ${txn.rate}, ${txn.amount}");
      }
    }

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

      // Get all batches for this voucher
      final batches = voucherBatches[voucherGuid]!;
          final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
    final isStockJournal = stockJournalVoucherType.contains(voucherType);


      // Determine voucher type
      // final isCreditNote = voucherType.toLowerCase().contains('cr') ||
      //     voucherType == 'Credit Note';

      // final isDebitNote = voucherType.toLowerCase().contains('debit') ||
      //     voucherType == 'Debit Note';

      // final isStockJournal = voucherType.toLowerCase().contains('sttp') || voucherType.toLowerCase().contains('stock journal') || voucherType == 'Stock Journal';

      if (voucherType == 'Physical Stock') {
        continue;
      }

      // For Stock Journals, determine if it's a transfer or addition
//     bool isStockJournalTransfer = false;
// if (isStockJournal) {
//   bool hasInward = false;
//   bool hasOutward = false;

//   for (var batch in batches) {
//     // USE isInward flag instead of amount!
//     if (batch.isInward) hasInward = true;
//     if (!batch.isInward) hasOutward = true;
//   }

//   isStockJournalTransfer = hasInward && hasOutward;

//   if (!isStockJournalTransfer) {
//     isStockJournal = false;
//   }
// }

      // Process batches
      for (var batch in batches) {
        final godown = batch.godownName;
        final amount = batch.amount;
        var qty = batch.stock;
        final isInward = batch.isInward;
        final absAmount = amount.abs();

        // SKIP batches with amount=0 if there are multiple batches (delivery+invoice case)
        if (amount == 0 && !isStockJournal) {
          continue;
        }

        // UPDATED: Only skip if BOTH qty and amount are 0
        if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
          continue;
        }

        if (!fyStock.containsKey(godown)) {
          fyStock[godown] = {
            'total_inward_qty': 0.0,
            'total_inward_value': 0.0,
            'current_stock_qty': 0.0,
          };
        }

        if (isStockJournal) {
          // STOCK JOURNAL TRANSFER
          if (isInward) {
            // Destination godown - receiving stock
            // If destination has no inward tracking, copy from source
            if (fyStock[godown]!['total_inward_qty']! == 0) {
              // Find the source godown from this voucher
              //   double sourceRate = 0.0;

              // for (var sourceBatch in batches) {
              //   final sourceGodown = sourceBatch.godownName;

              //   // Use isInward flag instead of checking amount
              //   if (!sourceBatch.isInward && fyStock.containsKey(sourceGodown)) {
              //     final sourceData = fyStock[sourceGodown]!;
              //     if (sourceData['total_inward_qty']! > 0) {
              //       sourceRate = sourceData['total_inward_value']! / sourceData['total_inward_qty']!;
              //       break;
              //     }
              //   }
              // }

              // Initialize destination with source rate
              // if (sourceRate > 0) {
              fyStock[godown]!['total_inward_qty'] = qty;
              // fyStock[godown]!['total_inward_value'] = qty * sourceRate;
              // }
            } else {
              // Destination already has stock, add at source rate
              // double sourceRate = 0.0;

              // for (var sourceBatch in batches) {
              //   final sourceGodown = sourceBatch.godownName;
              //   final sourceAmount = sourceBatch.amount;

              //   if (sourceAmount > 0 && fyStock.containsKey(sourceGodown)) {
              //     final sourceData = fyStock[sourceGodown]!;
              //     final totalInwardQty = sourceData['total_inward_qty'];
              //     final totalInwardValue = sourceData['total_inward_value'];

              //     if (totalInwardQty != null && totalInwardValue != null && totalInwardQty > 0) {
              //       sourceRate = totalInwardValue / totalInwardQty;
              //       break;
              //     }
              //   }
              // }

              // Add to existing destination stock
              // if (sourceRate > 0) {
              final currentTotalQty = fyStock[godown]!['total_inward_qty']!;
              // final currentTotalValue = fyStock[godown]!['total_inward_value']!;

              fyStock[godown]!['total_inward_qty'] = currentTotalQty + qty;
              // fyStock[godown]!['total_inward_value'] = currentTotalValue + (qty * sourceRate);
              // }
            }
            final totalInwardValue = fyStock[godown]!['total_inward_value']!;
            // final totalInwardQty = fyStock[godown]!['total_inward_qty']!;
            final currentStockQty = fyStock[godown]!['current_stock_qty']!;

            fyStock[godown]!['current_stock_qty'] = currentStockQty + qty;
            fyStock[godown]!['total_inward_value'] =
                totalInwardValue + absAmount;
            // fyStock[godown]!['total_inward_qty'] = totalInwardQty + qty;
          } else {
            // Source godown - sending stock OUT

            // CRITICAL: Also reduce total_inward when transferring
            // final totalInwardQty = fyStock[godown]!['total_inward_qty']!;
            // final totalInwardValue = fyStock[godown]!['total_inward_value']!;
            final currentStockQty = fyStock[godown]!['current_stock_qty']!;

            // final currentRate = totalInwardQty > 0
            //     ? totalInwardValue / totalInwardQty
            //     : 0.0;

            // fyStock[godown]!['total_inward_qty'] = totalInwardQty - qty;
            // fyStock[godown]!['total_inward_value'] = totalInwardValue - (qty * currentRate);
            fyStock[godown]!['current_stock_qty'] = currentStockQty - qty;
          }
        } else if (isCreditNote) {
          final currentRate = fyStock[godown]!['total_inward_qty']! > 0
              ? fyStock[godown]!['total_inward_value']! /
                  fyStock[godown]!['total_inward_qty']!
              : 0.0;
          final costValue = qty * currentRate;

          fyStock[godown]!['total_inward_qty'] =
              fyStock[godown]!['total_inward_qty']! + qty;
          fyStock[godown]!['total_inward_value'] =
              fyStock[godown]!['total_inward_value']! + costValue;
          fyStock[godown]!['current_stock_qty'] =
              fyStock[godown]!['current_stock_qty']! + qty;
        } else if (isDebitNote) {
          // DEBIT NOTE (Purchase Return)

          fyStock[godown]!['total_inward_qty'] =
              fyStock[godown]!['total_inward_qty']! - qty;
          fyStock[godown]!['total_inward_value'] =
              fyStock[godown]!['total_inward_value']! - absAmount;
          fyStock[godown]!['current_stock_qty'] =
              fyStock[godown]!['current_stock_qty']! - qty;
        } else {
          // Regular transactions (Purchase, Sales, or Stock Journal Addition/Removal)
          if (isInward) {
            // Purchase or Stock Journal Addition
            final totalInwardQty = fyStock[godown]!['total_inward_qty']!;
            final totalInwardValue = fyStock[godown]!['total_inward_value']!;
            final currentStockQty = fyStock[godown]!['current_stock_qty']!;

            fyStock[godown]!['total_inward_qty'] = totalInwardQty + qty;
            fyStock[godown]!['total_inward_value'] =
                totalInwardValue + absAmount;
            fyStock[godown]!['current_stock_qty'] = currentStockQty + qty;
          } else {
            // Sales or Stock Journal Removal
            final currentStockQty = fyStock[godown]!['current_stock_qty']!;
            fyStock[godown]!['current_stock_qty'] = currentStockQty - qty;
          }
        }
      }
    }

    for (var godown in fyStock.keys) {
      final data = fyStock[godown]!;
      final totalInwardQty = data['total_inward_qty']!;
      final totalInwardValue = data['total_inward_value']!;
      final currentStockQty = data['current_stock_qty']!;

      final averageRate =
          totalInwardQty > 0 ? totalInwardValue / totalInwardQty : 0.0;

      final closingValue = currentStockQty * averageRate;

      godownResults[godown] = GodownAverageCost(
        godownName: godown,
        totalInwardQty: totalInwardQty,
        totalInwardValue: totalInwardValue,
        currentStockQty: currentStockQty,
        averageRate: averageRate,
        closingValue: closingValue,
      );
    }

    return AverageCostResult(
      stockItemGuid: stockItem.stockItemGuid,
      itemName: stockItem.itemName,
      godowns: godownResults,
    );
  }

// // Function to calculate stock opening and closing for P&L
  Future<Map<String, double>> calculateStockValues(
      String companyGuid, String fromDate, String toDate,
      {bool debug = true} // Optional debug parameter
      ) async {
    final db = await _db.database;

    if (debug) {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('STOCK CALCULATION - TALLY METHOD (FY-WISE)');
      print('Period: $fromDate to $toDate');
      print('═══════════════════════════════════════════════════════════');
      print('');
    }

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

    if (debug) {
      print('Total Stock Items: ${allStockItemNames.length}');
      print('');
    }

    Map<String, Map<String, Map<String, double>>> itemGodownOpening = {};
    Map<String, Map<String, Map<String, double>>> itemGodownClosing = {};

    int totalDeliveryNotesSkipped = 0;
    int itemsProcessed = 0;

    for (var itemRow in allStockItemNames) {
      final itemName = itemRow['name'] as String;

      itemGodownOpening[itemName] = {};
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
        v.voucher_type,
        v.voucher_number
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

      // if (debug) {
      //   itemsProcessed++;
      //   print('─────────────────────────────────────────────────────────────');
      //   print('[$itemsProcessed] ITEM: $itemName');
      //   print('─────────────────────────────────────────────────────────────');
      // }

      // Initialize with original opening from database
      Map<String, Map<String, double>> fyStock = {};

      for (var allocation in openingAllocations) {
        final godown = (allocation['godown_name'] as String?) ?? 'Primary';
        final openingQty =
            (allocation['opening_balance'] as num?)?.toDouble() ?? 0.0;
        final openingValue =
            (allocation['opening_value'] as num?)?.toDouble() ?? 0.0;

        if (openingQty != 0) {
          fyStock[godown] = {
            'total_inward_qty': openingQty.abs(),
            'total_inward_value': openingValue.abs(),
            'current_stock_qty': openingQty,
          };

          // if (debug) {
          //   print('Database Opening - $godown: Qty=${openingQty.toStringAsFixed(2)}, Value=₹${openingValue.toStringAsFixed(2)}');
          // }
        }
      }

      String currentFyStart = '';
      bool hasSetPeriodOpening = false;
      int deliveryNotesSkipped = 0;
      int transactionsInPeriod = 0;

      // Process transactions FY by FY
      for (int txnIndex = 0; txnIndex < transactions.length; txnIndex++) {
        var txn = transactions[txnIndex];
        final voucherGuid = txn['voucher_guid'] as String;
        final dateStr = txn['date'].toString();
        final voucherType = txn['voucher_type'] as String?;
        final voucherNumber = txn['voucher_number'];

        if (dateStr.compareTo(toDate) > 0) break;

        // Skip Delivery Notes that have corresponding GST TAX INVOICE
        final isDeliveryNote = voucherType != null &&
            voucherType.toLowerCase().contains('delivery note');

        if (isDeliveryNote) {
          // Check if there's a corresponding GST TAX INVOICE
          bool hasInvoice = false;
          for (var otherTxn in transactions) {
            final otherDate = otherTxn['date'].toString();
            final otherVoucherType = otherTxn['voucher_type'] as String?;
            final otherVoucherNumber = otherTxn['voucher_number'];

            if (otherVoucherType != null &&
                otherVoucherType.toLowerCase().contains('gst tax invoice') &&
                otherDate == dateStr &&
                otherVoucherNumber == voucherNumber) {
              hasInvoice = true;
              break;
            }
          }

          if (hasInvoice) {
            if (dateStr.compareTo(fromDate) >= 0 &&
                dateStr.compareTo(toDate) <= 0) {
              deliveryNotesSkipped++;
              totalDeliveryNotesSkipped++;
              if (debug) {
                // print('⊘ SKIPPED: Delivery Note #$voucherNumber on $dateStr (has GST TAX INVOICE)');
              }
            }
            continue; // Skip this Delivery Note
          }
        }

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

        // Capture opening at fromDate
        if (!hasSetPeriodOpening && dateStr.compareTo(fromDate) >= 0) {
          for (var godown in fyStock.keys) {
            itemGodownOpening[itemName]![godown] = {
              'total_inward_qty': fyStock[godown]!['total_inward_qty']!,
              'total_inward_value': fyStock[godown]!['total_inward_value']!,
              'current_stock_qty': fyStock[godown]!['current_stock_qty']!,
            };
          }
          hasSetPeriodOpening = true;
        }

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

        if (dateStr.compareTo(fromDate) >= 0 &&
            dateStr.compareTo(toDate) <= 0) {
          transactionsInPeriod++;
        }

    final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
    bool isStockJournal = stockJournalVoucherType.contains(voucherType);

        // Determine voucher type
        // final isCreditNote = voucherType != null &&
        //     (voucherType.toLowerCase().contains('cr') ||
        //         voucherType == 'Credit Note');

        // final isDebitNote = voucherType != null &&
        //     (voucherType.toLowerCase().contains('debit') ||
        //         voucherType == 'Debit Note');

        // bool isStockJournal =
        //     voucherType != null && (voucherType.toLowerCase().contains('sttp') || voucherType.toLowerCase().contains('stock journal') || voucherType == 'Stock Journal');

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

          // SKIP Credit/Debit Notes with zero quantity
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
            // STOCK JOURNAL TRANSFER
            if (isInward) {
              // Destination godown - receiving stock
              // If destination has no inward tracking, copy from source
              if (fyStock[godown]!['total_inward_qty']! == 0) {
                // Find the source godown from this voucher
                double sourceRate = 0.0;

                for (var sourceBatch in voucherBatches) {
                  final sourceGodown =
                      (sourceBatch['godown_name'] as String?) ?? 'Primary';
                  final sourceAmount =
                      (sourceBatch['amount'] as num).toDouble();

                  if (sourceAmount > 0 && fyStock.containsKey(sourceGodown)) {
                    final sourceData = fyStock[sourceGodown]!;
                    if (sourceData['total_inward_qty']! > 0) {
                      sourceRate = sourceData['total_inward_value']! /
                          sourceData['total_inward_qty']!;
                      break;
                    }
                  }
                }

                // Initialize destination with source rate
                if (sourceRate > 0) {
                  fyStock[godown]!['total_inward_qty'] = qty;
                  fyStock[godown]!['total_inward_value'] = qty * sourceRate;
                }
              }

              fyStock[godown]!['current_stock_qty'] =
                  fyStock[godown]!['current_stock_qty']! + qty;
            } else {
              // Source godown - sending stock OUT
              fyStock[godown]!['current_stock_qty'] =
                  fyStock[godown]!['current_stock_qty']! - qty;
            }
          } else if (isCreditNote) {
            // CREDIT NOTE (Sales Return)
            final currentRate = fyStock[godown]!['total_inward_qty']! > 0
                ? fyStock[godown]!['total_inward_value']! /
                    fyStock[godown]!['total_inward_qty']!
                : 0.0;
            final costValue = qty * currentRate;

            fyStock[godown]!['total_inward_qty'] =
                fyStock[godown]!['total_inward_qty']! + qty;
            fyStock[godown]!['total_inward_value'] =
                fyStock[godown]!['total_inward_value']! + costValue;
            fyStock[godown]!['current_stock_qty'] =
                fyStock[godown]!['current_stock_qty']! + qty;
          } else if (isDebitNote) {
            // DEBIT NOTE (Purchase Return)
            fyStock[godown]!['total_inward_qty'] =
                fyStock[godown]!['total_inward_qty']! - qty;
            fyStock[godown]!['total_inward_value'] =
                fyStock[godown]!['total_inward_value']! - absAmount;
            fyStock[godown]!['current_stock_qty'] =
                fyStock[godown]!['current_stock_qty']! - qty;
          } else {
            // Regular transactions (Purchase, Sales, or Stock Journal Addition/Removal)
            if (isInward) {
              // Purchase or Stock Journal Addition
              fyStock[godown]!['total_inward_qty'] =
                  fyStock[godown]!['total_inward_qty']! + qty;
              fyStock[godown]!['total_inward_value'] =
                  fyStock[godown]!['total_inward_value']! + absAmount;
              fyStock[godown]!['current_stock_qty'] =
                  fyStock[godown]!['current_stock_qty']! + qty;
            } else {
              // Sales or Stock Journal Removal
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

      // If no opening set, use current
      if (!hasSetPeriodOpening) {
        for (var godown in fyStock.keys) {
          itemGodownOpening[itemName]![godown] = {
            'total_inward_qty': fyStock[godown]!['total_inward_qty']!,
            'total_inward_value': fyStock[godown]!['total_inward_value']!,
            'current_stock_qty': fyStock[godown]!['current_stock_qty']!,
          };
        }
      }

      // Print item summary
      if (debug) {
        // print('Transactions in period: $transactionsInPeriod');
        // if (deliveryNotesSkipped > 0) {
        //   print('Delivery Notes skipped: $deliveryNotesSkipped');
        // }

        // Print opening
        // double itemOpeningValue = 0.0;
        // print('');
        // print('OPENING:');
        // for (var godown in itemGodownOpening[itemName]!.keys) {
        //   final data = itemGodownOpening[itemName]![godown]!;
        //   final rate = data['total_inward_qty']! > 0
        //       ? data['total_inward_value']! / data['total_inward_qty']!
        //       : 0.0;
        //   final value = data['current_stock_qty']! * rate;
        //   itemOpeningValue += value;
        //   print('  $godown: Qty=${data['current_stock_qty']!.toStringAsFixed(2)} × Rate=₹${rate.toStringAsFixed(4)} = ₹${value.toStringAsFixed(2)}');
        // }
        // if (itemGodownOpening[itemName]!.isNotEmpty) {
        //   print('  Total Opening: ₹${itemOpeningValue.toStringAsFixed(2)}');
        // }

        // Print closing
        double itemClosingValue = 0.0;
        // print('');
        // print('CLOSING:');
        for (var godown in itemGodownClosing[itemName]!.keys) {
          final data = itemGodownClosing[itemName]![godown]!;
          final rate = data['total_inward_qty']! > 0
              ? data['total_inward_value']! / data['total_inward_qty']!
              : 0.0;
          final value = data['current_stock_qty']! * rate;
          itemClosingValue += value;
          print(
              ' $itemName, ${data['current_stock_qty']!.toStringAsFixed(2)}, ${data['total_inward_qty']!.toStringAsFixed(2)}, ${data['total_inward_value']!.toStringAsFixed(2)}, ${rate.toStringAsFixed(4)}, ${value.toStringAsFixed(2)}');
        }
        // if (itemGodownClosing[itemName]!.isNotEmpty) {
        //   print('  Total Closing: ₹${itemClosingValue.toStringAsFixed(2)}');
        // }
        // print('');
      }
    }

    // if (debug) {
    //   print('═══════════════════════════════════════════════════════════');
    //   print('Total items processed: $itemsProcessed');
    //   print('Total Delivery Notes skipped: $totalDeliveryNotesSkipped');
    //   print('═══════════════════════════════════════════════════════════');
    //   print('');
    // }

    // Calculate totals
    double totalOpeningStock = 0.0;
    double totalClosingStock = 0.0;

    for (var itemName in itemGodownOpening.keys) {
      for (var godown in itemGodownOpening[itemName]!.keys) {
        final data = itemGodownOpening[itemName]![godown]!;
        final totalInwardQty = data['total_inward_qty']!;
        final totalInwardValue = data['total_inward_value']!;
        final currentStockQty = data['current_stock_qty']!;

        if (currentStockQty != 0 && totalInwardQty > 0) {
          final avgRate = totalInwardValue / totalInwardQty;
          final openingStockValue = currentStockQty * avgRate;
          totalOpeningStock += openingStockValue;
        }
      }
    }

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

    if (debug) {
      print('═══════════════════════════════════════════════════════════');
      print('FINAL TOTALS:');
      print('Opening Stock: ₹${totalOpeningStock.toStringAsFixed(2)}');
      print('Closing Stock: ₹${totalClosingStock.toStringAsFixed(2)}');
      print('═══════════════════════════════════════════════════════════');
      print('');
    }

    return {
      'opening_stock': totalOpeningStock,
      'closing_stock': totalClosingStock,
    };
  }

  Future<Map<String, dynamic>> _getProfitLossDetailed(
    String companyGuid,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    final db = await _db.database;

    String fromDateStr = dateToString(fromDate);
    String toDateStr = dateToString(toDate);

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
    ''', [companyGuid, companyGuid, companyGuid, fromDateStr, toDateStr]);

    final debitTotal =
        (purchaseResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
    final creditTotal =
        (purchaseResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
    final netPurchase =
        (purchaseResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;
    final purchaseVouchers = purchaseResult.first['vouchers'] as int? ?? 0;

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
    ''', [companyGuid, companyGuid, companyGuid, fromDateStr, toDateStr]);

    final salesCredit =
        (salesResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
    final salesDebit =
        (salesResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
    final netSales =
        (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;
    final salesVouchers = salesResult.first['vouchers'] as int? ?? 0;

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
    l.name as ledger_name,
    l.opening_balance,
    COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
    COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
    (l.opening_balance + 
     COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
     COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
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
''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

    double totalDirectExpenses = 0.0;
    for (final expense in directExpenses) {
      final closingBalance =
          (expense['closing_balance'] as num?)?.toDouble() ?? 0.0;
      totalDirectExpenses += closingBalance; // ← Now includes opening balance
    }

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
    l.name as ledger_name,
    l.opening_balance,
    COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
    COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
    (l.opening_balance + 
     COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
     COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
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
''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

    double totalIndirectExpenses = 0.0;
    for (final expense in indirectExpenses) {
      final closingBalance =
          (expense['closing_balance'] as num?)?.toDouble() ?? 0.0;
      totalIndirectExpenses += closingBalance;
    }

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
    COALESCE(SUM(CASE 
      WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
      THEN vle.amount 
      ELSE 0 
    END), 0) as credit_total,
    COALESCE(SUM(CASE 
      WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
      THEN ABS(vle.amount) 
      ELSE 0 
    END), 0) as debit_total,
    (l.opening_balance + 
     COALESCE(SUM(CASE 
       WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
       THEN vle.amount 
       ELSE 0 
     END), 0) - 
     COALESCE(SUM(CASE 
       WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
       THEN ABS(vle.amount) 
       ELSE 0 
     END), 0)) as closing_balance
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
  HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
  ORDER BY closing_balance DESC
''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

    double totalIndirectIncomes = 0.0;
    for (final income in indirectIncomes) {
      final closing = (income['closing_balance'] as num?)?.toDouble() ?? 0.0;
      totalIndirectIncomes += closing;
    }

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
    COALESCE(SUM(CASE 
      WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
      THEN vle.amount 
      ELSE 0 
    END), 0) as credit_total,
    COALESCE(SUM(CASE 
      WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
      THEN ABS(vle.amount) 
      ELSE 0 
    END), 0) as debit_total,
    (l.opening_balance + 
     COALESCE(SUM(CASE 
       WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
       THEN vle.amount 
       ELSE 0 
     END), 0) - 
     COALESCE(SUM(CASE 
       WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
       THEN ABS(vle.amount) 
       ELSE 0 
     END), 0)) as closing_balance
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
  HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
  ORDER BY closing_balance DESC
''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

    double totalDirectIncomes = 0.0;
    for (final income in directIncomes) {
      final closing = (income['closing_balance'] as num?)?.toDouble() ?? 0.0;
      totalDirectIncomes += closing;
    }    

    double totalClosingStock = 0.0;
    double totalOpeningStock = 0.0;

if (_isMaintainInventory == false){
    final allItemClosings = await calculateAllAverageCost(companyGuid: _companyGuid!, fromDate: fromDateStr, toDate: toDateStr);

    totalClosingStock = getTotalClosingValue(allItemClosings);

    final previousDay = dateToString(fromDate).compareTo(_companyStartDate) <= 0 ? fromDateStr : getPreviousDate(fromDateStr);

    final allItemOpening = await calculateAllAverageCost(companyGuid: _companyGuid!,fromDate: previousDay,toDate: previousDay);

    totalOpeningStock = getTotalClosingValue(allItemOpening);

}else{

  final closingStockResult = await db.rawQuery('''
  WITH RECURSIVE stock_groups AS (
    SELECT group_guid, name
    FROM groups
    WHERE company_guid = ?
      AND (reserved_name = 'Stock-in-Hand' OR name = 'Stock-in-Hand')
      AND is_deleted = 0
    
    UNION ALL
    
    SELECT g.group_guid, g.name
    FROM groups g
    INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
    WHERE g.company_guid = ?
      AND g.is_deleted = 0
  ),
  latest_balances AS (
    SELECT lcb.ledger_guid, lcb.amount * -1 as closing_amount,
           ROW_NUMBER() OVER (PARTITION BY lcb.ledger_guid ORDER BY lcb.closing_date DESC) as rn
    FROM ledger_closing_balances lcb
    INNER JOIN ledgers l ON l.ledger_guid = lcb.ledger_guid
    INNER JOIN stock_groups sg ON l.parent = sg.name
    WHERE lcb.company_guid = ?
      AND lcb.closing_date <= ?
      AND l.is_deleted = 0
  )
  SELECT COALESCE(SUM(closing_amount), 0) as total_closing_stock
  FROM latest_balances
  WHERE rn = 1
''', [companyGuid, companyGuid, companyGuid, toDateStr]);

  totalClosingStock = closingStockResult.isNotEmpty 
      ? (closingStockResult.first['total_closing_stock'] as num?)?.toDouble() ?? 0.0
      : 0.0;

  final previousDay = fromDateStr.compareTo(_companyStartDate) <= 0 
      ? _companyStartDate 
      : getPreviousDate(fromDateStr);

final openingStockResult = await db.rawQuery('''
  WITH RECURSIVE stock_groups AS (
    SELECT group_guid, name
    FROM groups
    WHERE company_guid = ?
      AND (reserved_name = 'Stock-in-Hand' OR name = 'Stock-in-Hand')
      AND is_deleted = 0
    
    UNION ALL
    
    SELECT g.group_guid, g.name
    FROM groups g
    INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
    WHERE g.company_guid = ?
      AND g.is_deleted = 0
  ),
  latest_balances AS (
    SELECT l.ledger_guid,
           COALESCE(lcb.amount, l.opening_balance) * -1 as opening_amount,
           ROW_NUMBER() OVER (
             PARTITION BY l.ledger_guid 
             ORDER BY lcb.closing_date DESC NULLS LAST
           ) as rn
    FROM ledgers l
    INNER JOIN stock_groups sg ON l.parent = sg.name
    LEFT JOIN ledger_closing_balances lcb ON lcb.ledger_guid = l.ledger_guid
      AND lcb.company_guid = ?
      AND lcb.closing_date <= ?
    WHERE l.company_guid = ?
      AND l.is_deleted = 0
  )
  SELECT COALESCE(SUM(opening_amount), 0) as total_opening_stock
  FROM latest_balances
  WHERE rn = 1
''', [companyGuid, companyGuid, companyGuid, previousDay, companyGuid]);

  totalOpeningStock = openingStockResult.isNotEmpty
      ? (openingStockResult.first['total_opening_stock'] as num?)?.toDouble() ?? 0.0
      : 0.0;
}
    

    final grossProfit = (netSales + totalDirectIncomes + totalClosingStock) -
        (totalOpeningStock + netPurchase + totalDirectExpenses.abs());
    final netProfit =
        grossProfit + totalIndirectIncomes - totalIndirectExpenses.abs();

    print('opening_stock : ${totalOpeningStock}');
    print('closing_stock : ${totalClosingStock}');

    return {
      'opening_stock': totalOpeningStock,
      'purchase': netPurchase,
      'direct_expenses': directExpenses,
      'direct_expenses_total': totalDirectExpenses.abs(),
      'gross_profit': grossProfit,
      'closing_stock': totalClosingStock,
      'sales': netSales,
      'indirect_expenses': indirectExpenses,
      'indirect_expenses_total': totalIndirectExpenses.abs(),
      'indirect_incomes': indirectIncomes,
      'indirect_incomes_total': totalIndirectIncomes,
      'direct_incomes': directIncomes,
      'direct_incomes_total': totalDirectIncomes,
      'net_profit': netProfit,
    };
  }

  void _navigateToGroup(String groupName) {
    if (_companyGuid == null || _companyName == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(
          companyGuid: _companyGuid!,
          companyName: _companyName!,
          groupName: groupName,
          fromDate: dateToString(_fromDate),
          toDate: dateToString(_toDate),
        ),
      ),
    );
  }

  void _navigateToLedger(String ledgerName) {
    if (_companyGuid == null || _companyName == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LedgerDetailScreen(
          companyGuid: _companyGuid!,
          companyName: _companyName!,
          ledgerName: ledgerName,
          fromDate: dateToString(_fromDate),
          toDate: dateToString(_toDate),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Profit & Loss A/c')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Profit & Loss A/c'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
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
                    '${_formatDate(dateToString(_fromDate))} to ${_formatDate(dateToString(_toDate))}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),

            // Main Content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side - Expenses
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Particulars'),
                      _buildLeftItem(
                        'Opening Stock',
                        _plData?['opening_stock'] ?? 0.0,
                        onTap: () => _navigateToGroup('Purchase Accounts'),
                      ),
                      _buildLeftItem(
                        'Purchase Accounts',
                        _plData?['purchase'] ?? 0.0,
                        onTap: () => _navigateToGroup('Purchase Accounts'),
                      ),
                      _buildLeftItem(
                        'Direct Expenses',
                        _plData?['direct_expenses_total'] ?? 0.0,
                        onTap: () => _navigateToGroup('Direct Expenses'),
                      ),
                      _buildGrossProfitRow(
                        'Gross Profit c/o',
                        _plData?['gross_profit'] ?? 0.0,
                      ),
                      Divider(thickness: 2),
                      _buildLeftItem(
                        'Indirect Expenses',
                        _plData?['indirect_expenses_total'] ?? 0.0,
                        onTap: () => _navigateToGroup('Indirect Expenses'),
                      ),
                      _buildNetProfitRow(
                        'Net Profit',
                        _plData?['net_profit'] ?? 0.0,
                      ),
                    ],
                  ),
                ),

                VerticalDivider(width: 1),

                // Right Side - Incomes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Particulars'),
                      _buildRightItem(
                        'Sales Accounts',
                        _plData?['sales'] ?? 0.0,
                        onTap: () => _navigateToGroup('Sales Accounts'),
                      ),
                      _buildRightItem(
                        'Closing Stock',
                        _plData?['closing_stock'] ?? 0.0,
                        onTap: () => _navigateToGroup('Sales Accounts'),
                      ),
                      _buildRightItem(
                        'Direct Incomes',
                        _plData?['direct_incomes_total'] ?? 0.0,
                        onTap: () => _navigateToGroup('Direct Incomes'),
                      ),
                      SizedBox(height: 20),
                      _buildGrossProfitRow(
                        'Gross Profit b/f',
                        _plData?['gross_profit'] ?? 0.0,
                      ),
                      Divider(thickness: 2),
                      _buildRightItem(
                        'Indirect Incomes',
                        _plData?['indirect_incomes_total'] ?? 0.0,
                        onTap: () => _navigateToGroup('Indirect Incomes'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Footer - Total
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatAmount(_calculateTotal()),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatAmount(_calculateTotal()),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      color: Colors.grey[100],
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLeftItem(String label, double amount, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label),
                if (onTap != null) ...[
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
                ],
              ],
            ),
            Text(_formatAmount(amount)),
          ],
        ),
      ),
    );
  }

  Widget _buildRightItem(String label, double amount, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label),
                if (onTap != null) ...[
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
                ],
              ],
            ),
            Text(_formatAmount(amount)),
          ],
        ),
      ),
    );
  }

  // Widget _buildSubItems(List<dynamic> items) {
  //   if (items.isEmpty) return SizedBox.shrink();

  //   return Column(
  //     children: items.map((item) {
  //       final ledgerName = item['ledger_name'] as String? ?? '';
  //       final netAmount = (item['net_amount'] as num?)?.toDouble() ??
  //                        (item['closing_balance'] as num?)?.toDouble() ?? 0.0;

  //       return InkWell(
  //         onTap: () => _navigateToLedger(ledgerName),
  //         child: Padding(
  //           padding: EdgeInsets.only(left: 32, right: 16, top: 4, bottom: 4),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Expanded(
  //                 child: Row(
  //                   children: [
  //                     Expanded(
  //                       child: Text(
  //                         ledgerName,
  //                         style: TextStyle(fontSize: 12, color: Colors.grey[700]),
  //                       ),
  //                     ),
  //                     Icon(Icons.chevron_right, size: 14, color: Colors.grey[500]),
  //                   ],
  //                 ),
  //               ),
  //               SizedBox(width: 8),
  //               Text(
  //                 _formatAmount(netAmount),
  //                 style: TextStyle(fontSize: 12, color: Colors.grey[700]),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     }).toList(),
  //   );
  // }

  Widget _buildGrossProfitRow(String label, double amount) {
    return Container(
      color: Colors.amber[100],
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            _formatAmount(amount),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNetProfitRow(String label, double amount) {
    return Container(
      color: Colors.green[100],
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            _formatAmount(amount),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  double _calculateTotal() {
    final opening = _plData?['opening_stock'] ?? 0.0;
    final purchase = _plData?['purchase'] ?? 0.0;
    final directExp = _plData?['direct_expenses_total'] ?? 0.0;
    final indirectExp = _plData?['indirect_expenses_total'] ?? 0.0;
    final netProfit = _plData?['net_profit'] ?? 0.0;

    return opening + purchase + directExp + indirectExp + netProfit;
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // _selectedFromDate = picked.start;
        // _selectedToDate = picked.end;
        _fromDate = picked.start;
        _toDate = picked.end;
      });

      await _loadData();
    }
  }
}
