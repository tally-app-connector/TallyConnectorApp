// // import 'package:flutter/material.dart';
// // import '../../models/data_model.dart';
// // import '../../database/database_helper.dart';
// // import '../../utils/date_utils.dart';
// // import 'group_detail_screen.dart';

// // class ProfitLossScreen extends StatefulWidget {
// //   @override
// //   _ProfitLossScreenState createState() => _ProfitLossScreenState();
// // }

// // class _ProfitLossScreenState extends State<ProfitLossScreen> {
// //   final _db = DatabaseHelper.instance;

// //   String? _companyGuid;
// //   String? _companyName;
// //   String _companyStartDate = getCurrentFyStartDate();
// //   bool _loading = true;
// //   bool _isMaintainInventory = true;
// //   List<String> debitNoteVoucherTypes = [];
// //   List<String> creditNoteVoucherTypes = [];
// //   List<String> stockJournalVoucherType = [];
// //   List<String> physicalStockVoucherType = [];
// //   List<String> receiptNoteVoucherTypes = [];
// //   List<String> deliveryNoteVoucherTypes = [];
// //   List<String> purchaseVoucherTypes = [];
// //   List<String> salesVoucherTypes = [];


// //   Map<String, dynamic>? _plData;
// //   DateTime _fromDate = getFyStartDate(DateTime.now());  // Financial year start
// //   DateTime _toDate = getFyEndDate(DateTime.now()); // Financial year end

// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadData();
// //   }

// //   Future<void> _loadData() async {
// //     setState(() => _loading = true);

// //     final company = await _db.getSelectedCompanyByGuid();
// //     if (company == null) {
// //       setState(() => _loading = false);
// //       return;
// //     }



// //     _companyGuid = company['company_guid'] as String;
// //     _companyName = company['company_name'] as String;
// //     _isMaintainInventory = (company['integrate_inventory'] as int) == 1;

// //     _companyStartDate = (company['starting_from'] as String).replaceAll('-', '');


// //     debitNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Debit Note');
// //     creditNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Credit Note');
// //     stockJournalVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Stock Journal');
// //     physicalStockVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Physical Stock');
// //     receiptNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Receipt Note');
// //     deliveryNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Delivery Note');
// //     purchaseVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Purchase');
// //     salesVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Sales');

// //     final plData = await _getProfitLossDetailed(_companyGuid!, _fromDate, _toDate);

// //     setState(() {
// //       _plData = plData;
// //       _loading = false;
// //     });
// //   }

// //   double getTotalClosingValue(List<AverageCostResult> results) {
// //     double totalClosingValue = 0.0;

// //     for (var result in results) {
// //       for (var godown in result.godowns.values) {
// //         totalClosingValue += godown.closingValue;
// //       }
// //     }
// //     print(totalClosingValue);
// //     return totalClosingValue;
// //   }


// // // ============================================================
// // // GET ALL CHILD VOUCHER TYPES FOR CONTRA
// // // ============================================================

// // Future<List<String>> getAllChildVoucherTypes(String companyGuid, String voucherTypeName) async {
// //   final db = await _db.database;

// //   final result = await db.rawQuery('''
// //     WITH RECURSIVE voucher_type_tree AS (
// //       SELECT voucher_type_guid, name
// //       FROM voucher_types
// //       WHERE company_guid = ?
// //         AND (name = ? OR reserved_name = ?)
// //         AND is_deleted = 0
      
// //       UNION ALL
      
// //       SELECT vt.voucher_type_guid, vt.name
// //       FROM voucher_types vt
// //       INNER JOIN voucher_type_tree vtt ON vt.parent_guid = vtt.voucher_type_guid
// //       WHERE vt.company_guid = ?
// //         AND vt.is_deleted = 0
// //         AND vt.voucher_type_guid != vt.parent_guid  -- Prevent self-referencing loop
// //     )
// //     SELECT name FROM voucher_type_tree ORDER BY name
// //   ''', [companyGuid, voucherTypeName, voucherTypeName, companyGuid]);

// //   return result.map((row) => row['name'] as String).toList();
// // }

// // Future<List<StockItemInfo>> fetchAllStockItems(String companyGuid) async {
// //   final db = await _db.database;

// //   // Fetch stock items that have opening batch allocations or at least one voucher
// //     final stockItemResults = await db.rawQuery('''
// //     SELECT 
// //       si.name as item_name,
// //       si.stock_item_guid,
// //       COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
// //       COALESCE(si.base_units, '') as unit,
// //       COALESCE(si.parent, '') as parent_name
// //     FROM stock_items si
// //     WHERE si.company_guid = ?
// //       AND si.is_deleted = 0
// //       AND (
// //         EXISTS (
// //           SELECT 1 FROM stock_item_batch_allocation siba
// //           WHERE siba.stock_item_guid = si.stock_item_guid
// //         )
// //         OR EXISTS (
// //           SELECT 1 FROM voucher_inventory_entries vie
// //           WHERE vie.stock_item_guid = si.stock_item_guid
// //             AND vie.company_guid = si.company_guid
// //         )
// //       )
// //   ''', [companyGuid]);

// //   // Batch allocations only for matched stock items
// //   final batchResults = await db.rawQuery('''
// //     SELECT 
// //       siba.stock_item_guid,
// //       COALESCE(siba.godown_name, '') as godown_name,
// //       COALESCE(siba.batch_name, '') as batch_name,
// //       COALESCE(siba.opening_value, 0) as amount,
// //       COALESCE(siba.opening_balance, '') as actual_qty,
// //       COALESCE(siba.opening_balance, '') as billed_qty,
// //       siba.opening_rate as batch_rate
// //     FROM stock_item_batch_allocation siba
// //     INNER JOIN stock_items si 
// //       ON siba.stock_item_guid = si.stock_item_guid
// //     WHERE si.company_guid = ?
// //       AND si.is_deleted = 0
// //   ''', [companyGuid]);

// //   // Group batch allocations by stock_item_guid
// //   final Map<String, List<BatchAllocation>> batchMap = {};

// //   for (final row in batchResults) {
// //     final stockItemGuid = row['stock_item_guid'] as String;
// //     final batch = BatchAllocation(
// //       godownName: row['godown_name'] as String,
// //       trackingNumber: "Not Applicable",
// //       batchName: row['batch_name'] as String,
// //       amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
// //       actualQty: row['actual_qty']?.toString() ?? '',
// //       billedQty: row['billed_qty']?.toString() ?? '',
// //       batchRate: (row['batch_rate'] as num?)?.toDouble(),
// //     );

// //     batchMap.putIfAbsent(stockItemGuid, () => []).add(batch);
// //   }


// //   return stockItemResults.map((row) {
// //     final stockItemGuid = row['stock_item_guid'] as String;

// //     final stockItem = StockItemInfo(
// //       itemName: row['item_name'] as String,
// //       stockItemGuid: stockItemGuid,
// //       costingMethod: row['costing_method'] as String,
// //       unit: row['unit'] as String,
// //       parentName: row['parent_name'] as String,
// //       closingRate: (row['closing_rate'] as num?)?.toDouble() ?? 0.0,
// //       closingQty: (row['closing_balance'] as num?)?.toDouble() ?? 0.0,
// //       closingValue: (row['closing_value'] as num?)?.toDouble() ?? 0.0,
// //       openingData: batchMap[stockItemGuid] ?? [],
// //     );

// //     print('${stockItem.itemName}, ${stockItem.costingMethod}, ${stockItem.closingRate}, ${stockItem.closingQty}, ${stockItem.closingValue}');

// //     return stockItem;
// //   }).toList();
// // }
// //   Future<List<StockTransaction>> fetchTransactionsForStockItem(
// //     String companyGuid,
// //     String stockItemGuid,
// //     String endDate,
// //   ) async {
// //     final db = await _db.database;

// //     final results = await db.rawQuery('''
// //     SELECT 
// //       v.voucher_guid,
// //       v.voucher_key as voucher_id,
// //       v.date as voucher_date,
// //       v.voucher_number,
// //       vba.godown_name,
// //       v.voucher_type,
// //       vba.actual_qty as stock,
// //       COALESCE(vba.batch_rate, 0) as rate,
// //       vba.amount,
// //       vba.is_deemed_positive as is_inward,
// //       COALESCE(vba.batch_name, '') as batch_name,
// //       COALESCE(vba.destination_godown_name, '') as destination_godown,
// //       COALESCE(vba.tracking_number, 'Not Applicable') as tracking_number
// //     FROM vouchers v
// //     INNER JOIN voucher_batch_allocations vba 
// //       ON vba.voucher_guid = v.voucher_guid
// //     WHERE vba.stock_item_guid = ?
// //       AND v.company_guid = ?
// //       AND v.date <= ?
// //       AND v.is_deleted = 0
// //       AND v.is_cancelled = 0
// //       AND v.is_optional = 0
// //     ORDER BY v.date, v.master_id
// //   ''', [stockItemGuid, companyGuid, endDate]);

// //     return results.map((row) {
// //       // Parse quantity from "960.000 Kgs" format
// //       String stockStr = (row['stock'] as String?) ?? '0';
// //       double stock = 0.0;
// //       if (stockStr.isNotEmpty) {
// //         final parts = stockStr.split(' ');
// //         if (parts.isNotEmpty) {
// //           stock = double.tryParse(parts[0]) ?? 0.0;
// //         }
// //       }

// //       return StockTransaction(
// //         voucherGuid: row['voucher_guid'] as String,
// //         voucherId: (row['voucher_id'] as int?) ?? 0,
// //         voucherDate: row['voucher_date'] as String,
// //         voucherNumber: row['voucher_number'] as String,
// //         godownName: (row['godown_name'] as String?) ?? 'Primary',
// //         voucherType: row['voucher_type'] as String,
// //         stock: stock,
// //         rate: (row['rate'] as num?)?.toDouble() ?? 0.0,
// //         amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
// //         isInward: (row['is_inward'] as int) == 1,
// //         batchName: row['batch_name'] as String,
// //         destinationGodown: row['destination_godown'] as String,
// //         trackingNumber: row['tracking_number'] as String,
// //       );
// //     }).toList();
// //   }


// //   Future<Map<String, Map<String, Map<String, List<StockTransaction>>>>>
// //     buildStockDirectoryWithBatch(
// //   String companyGuid,
// //   String endDate,
// //   List<StockItemInfo> stockItems,
// // ) async {

// //   Map<String, Map<String, Map<String, List<StockTransaction>>>> directory = {};

// //   for (var item in stockItems) {
// //     final transactions = await fetchTransactionsForStockItem(
// //       companyGuid,
// //       item.stockItemGuid,
// //       endDate,
// //     );

// //     // Godown -> Batch -> Transactions
// //     Map<String, Map<String, List<StockTransaction>>> godownTransactions = {};

// //     for (var transaction in transactions) {

// //       final godown = transaction.godownName;
// //       final batch = transaction.batchName;

// //       // Ensure godown exists
// //       godownTransactions.putIfAbsent(godown, () => {});

// //       // Ensure batch exists inside godown
// //       godownTransactions[godown]!
// //           .putIfAbsent(batch, () => []);

// //       // Add transaction
// //       godownTransactions[godown]![batch]!
// //           .add(transaction);
// //     }

// //     directory[item.stockItemGuid] = godownTransactions;
// //   }

// //   return directory;
// // }

// // // ============================================
// // // CALCULATE FOR ALL ITEMS
// // // ============================================

// //   Future<List<AverageCostResult>> calculateAllAverageCost({
// //     required String companyGuid,
// //     required String fromDate,
// //     required String toDate,
// //   }) async {
// //     // Fetch all stock items
// //     final stockItems = await fetchAllStockItems(companyGuid);

// //     final directory = await buildStockDirectoryWithBatch(companyGuid, toDate, stockItems);

// //     List<AverageCostResult> results = [];

// //     for (var stockItem in stockItems) {

// //       final godownTransactions = directory[stockItem.stockItemGuid]!;

// //       if (stockItem.unit.toLowerCase().contains('not applicable')){
// //       final result = await calculateCostWithoutUnit(
// //               stockItem: stockItem,
// //               godownTransactions: godownTransactions,
// //               fromDate: fromDate,
// //               toDate: toDate,
// //               companyGuid: companyGuid);

// //           for (final entry in result.godowns.entries) {
// //             print(
// //                 '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
// //           }
// //           results.add(result);

// //       }else if (stockItem.costingMethod.toLowerCase().contains('zero')){
// //         final result = AverageCostResult(itemName: stockItem.itemName, stockItemGuid: stockItem.stockItemGuid, godowns: {});
// //             print('${result.itemName}= ${stockItem.costingMethod}, godownName, 0, 0, 0');
// //           results.add(result);
// //       }else if (stockItem.costingMethod.toLowerCase().contains('fifo')){
// //         final result = await calculateFifoCost(
// //               stockItem: stockItem,
// //               godownTransactions: godownTransactions,
// //               fromDate: fromDate,
// //               toDate: toDate,
// //               companyGuid: companyGuid);

// //           for (final entry in result.godowns.entries) {
// //             print(
// //                 '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
// //           }
// //           results.add(result);
// //       }else if (stockItem.costingMethod.toLowerCase().contains('lifo')){
// //         final result = await calculateLifoCost(
// //               stockItem: stockItem,
// //               godownTransactions: godownTransactions,
// //               fromDate: fromDate,
// //               toDate: toDate,
// //               companyGuid: companyGuid);

// //           for (final entry in result.godowns.entries) {
// //             print(
// //                 '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
// //           }
// //           results.add(result);
// //       }else{
// //         final result = await calculateAvgCost(
// //                     stockItem: stockItem,
// //                     godownTransactions: godownTransactions,
// //                     fromDate: fromDate,
// //                     toDate: toDate,
// //                     companyGuid: companyGuid);

// //           for (final entry in result.godowns.entries) {
// //             print(
// //                 '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
// //           }
// //           results.add(result);
// //       }

// //     }

// //     return results;
// //   }

// //   Future<AverageCostResult> calculateLifoCost({
// //   required StockItemInfo stockItem,
// //   required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
// //   required String fromDate,
// //   required String toDate,
// //   required String companyGuid,
// // }) async {
// //   Map<String, GodownAverageCost> godownResults = {};

// //   const financialYearStartMonth = 4;
// //   const financialYearStartDay = 1;

// //   String getFinancialYearStartDate(String dateStr) {
// //     final year = int.parse(dateStr.substring(0, 4));
// //     final month = int.parse(dateStr.substring(4, 6));

// //     if (month < financialYearStartMonth) {
// //       return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
// //     } else {
// //       return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
// //     }
// //   }

// //   // 🔹 Godown → Batch → Lot tracking
// //   Map<String, Map<String, double>> godownBatchInwardQty = {};
// //   Map<String, Map<String, double>> godownBatchOutwardQty = {};
// //   Map<String, Map<String, List<StockLot>>> godownBatchLots = {};

// //   // Flatten all transactions and sort by voucherId
// //   List<StockTransaction> allTransactions = [];
// //   for (var godownMap in godownTransactions.values) {
// //     for (var batchList in godownMap.values) {
// //       allTransactions.addAll(batchList);
// //     }
// //   }
// //   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

// //   // Group transactions by voucher_guid
// //   Map<String, List<StockTransaction>> voucherBatches = {};
// //   for (var txn in allTransactions) {
// //     voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
// //     voucherBatches[txn.voucherGuid]!.add(txn);
// //   }

// //   // 🔹 Opening Stock → Batch Level
// //   for (final godownOpeningData in stockItem.openingData) {
// //     String godownName = godownOpeningData.godownName;
// //     if (godownName.isEmpty) {
// //       godownName = 'Main Location';
// //     }

// //     final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
// //     final openingAmount = godownOpeningData.amount;
// //     final batchName = godownOpeningData.batchName;

// //     godownBatchInwardQty.putIfAbsent(godownName, () => {});
// //     godownBatchOutwardQty.putIfAbsent(godownName, () => {});
// //     godownBatchLots.putIfAbsent(godownName, () => {});

// //     godownBatchInwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
// //     godownBatchOutwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
// //     godownBatchLots[godownName]!.putIfAbsent(batchName, () => []);

// //     godownBatchInwardQty[godownName]![batchName] =
// //         godownBatchInwardQty[godownName]![batchName]! + openingQty;

// //     if (openingQty > 0) {
// //       final openingRate = openingAmount / openingQty;
// //       godownBatchLots[godownName]![batchName]!.add(StockLot(
// //         voucherGuid: 'OPENING_STOCK',
// //         voucherDate: fromDate,
// //         voucherNumber: 'Opening Balance',
// //         voucherType: 'Opening',
// //         qty: openingQty,
// //         amount: openingAmount,
// //         rate: openingRate,
// //         type: StockInOutType.inward,
// //       ));
// //     }
// //   }

// //   String currentFyStart = '';

// //   // LIFO closing value helper
// //   double calculateLifoClosingValue(List<StockLot> lots, double closingStockQty) {
// //     if (closingStockQty <= 0 || lots.isEmpty) {
// //       if (lots.isNotEmpty) {
// //         return closingStockQty * lots.last.rate;
// //       }
// //       return 0.0;
// //     }

// //     double closingValue = 0.0;
// //     double remainingQty = closingStockQty;
// //     double tempOutWardQty = 0.0;
// //     double lastRate = 0.0;

// //     for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
// //       final lot = lots[i];
// //       lastRate = lot.rate;
// //       if (lot.type == StockInOutType.outward) {
// //         tempOutWardQty += lot.qty;
// //       } else {
// //         if (lot.qty == 0) {
// //           closingValue += lot.amount;
// //         } else if (tempOutWardQty <= 0) {
// //           if (lot.qty <= remainingQty) {
// //             closingValue += lot.amount;
// //             remainingQty -= lot.qty;
// //           } else {
// //             closingValue += remainingQty * lot.rate;
// //             remainingQty = 0;
// //           }
// //         } else {
// //           if (lot.qty <= tempOutWardQty) {
// //             tempOutWardQty -= lot.qty;
// //           } else {
// //             final tempLotQty = lot.qty - tempOutWardQty;
// //             tempOutWardQty = 0;

// //             if (tempLotQty <= remainingQty) {
// //               closingValue += (tempLotQty * lot.rate);
// //               remainingQty -= tempLotQty;
// //             } else {
// //               closingValue += remainingQty * lot.rate;
// //               remainingQty = 0;
// //             }
// //           }
// //         }
// //       }
// //     }

// //     if (remainingQty > 0) {
// //       closingValue += remainingQty * lastRate;
// //     }

// //     if (closingValue == 0 && closingStockQty > 0) {
// //       final totalQty = lots.fold(0.0, (sum, lot) => sum + lot.qty);
// //       final totalValue = lots.fold(0.0, (sum, lot) => sum + lot.amount);
// //       if (totalQty > 0) {
// //         closingValue = closingStockQty * (totalValue / totalQty);
// //       }
// //     }

// //     return closingValue;
// //   }

// //   Set<String> processedVouchers = {};

// //   for (var txn in allTransactions) {
// //     final voucherGuid = txn.voucherGuid;

// //     if (processedVouchers.contains(voucherGuid) ||
// //         txn.voucherType.toLowerCase().contains('purchase order') ||
// //         txn.voucherType.toLowerCase().contains('sales order')) {
// //       continue;
// //     }

// //     processedVouchers.add(voucherGuid);

// //     final dateStr = txn.voucherDate;
// //     final voucherType = txn.voucherType;
// //     final voucherNumber = txn.voucherNumber;

// //     if (dateStr.compareTo(toDate) > 0) {
// //       break;
// //     }

// //     final txnFyStart = getFinancialYearStartDate(dateStr);

// //     // 🔹 FY Boundary Reset (Batch Wise)
// //     if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
// //       for (var godown in godownBatchInwardQty.keys) {
// //         final batchKeys = godownBatchInwardQty[godown]!.keys.toList();
// //         for (var batchName in batchKeys) {
// //           final inwardQty = godownBatchInwardQty[godown]![batchName]!;
// //           final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
// //           final closingStockQty = inwardQty - outwardQty;
// //           final lots = godownBatchLots[godown]![batchName] ?? [];

// //           if (closingStockQty > 0) {
// //             final closingValue = calculateLifoClosingValue(lots, closingStockQty);
// //             final closingRate = closingValue / closingStockQty;

// //             godownBatchInwardQty[godown]![batchName] = closingStockQty;
// //             godownBatchOutwardQty[godown]![batchName] = 0.0;
// //             godownBatchLots[godown]![batchName] = [
// //               StockLot(
// //                 voucherGuid: 'FY_OPENING_$txnFyStart',
// //                 voucherDate: txnFyStart,
// //                 voucherNumber: 'FY Opening Balance',
// //                 voucherType: 'Opening',
// //                 qty: closingStockQty,
// //                 amount: closingValue,
// //                 rate: closingRate,
// //                 type: StockInOutType.inward,
// //               )
// //             ];
// //           } else if (closingStockQty < 0) {
// //             // Negative stock: fallback to Average Cost
// //             double totalLotValue = 0.0;
// //             double totalLotQty = 0.0;
// //             for (var lot in lots) {
// //               if (lot.type == StockInOutType.inward) {
// //                 totalLotValue += lot.amount;
// //                 totalLotQty += lot.qty;
// //               }
// //             }
// //             final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
// //             final closingValue = closingStockQty * closingRate;

// //             godownBatchInwardQty[godown]![batchName] = closingStockQty;
// //             godownBatchOutwardQty[godown]![batchName] = 0.0;
// //             godownBatchLots[godown]![batchName] = [
// //               StockLot(
// //                 voucherGuid: 'FY_OPENING_$txnFyStart',
// //                 voucherDate: txnFyStart,
// //                 voucherNumber: 'FY Opening Balance',
// //                 voucherType: 'Opening',
// //                 qty: closingStockQty,
// //                 amount: closingValue,
// //                 rate: closingRate,
// //                 type: StockInOutType.inward,
// //               )
// //             ];
// //           } else {
// //             godownBatchInwardQty[godown]![batchName] = 0.0;
// //             godownBatchOutwardQty[godown]![batchName] = 0.0;
// //             godownBatchLots[godown]![batchName] = [];
// //           }
// //         }
// //       }
// //     }

// //     currentFyStart = txnFyStart;

// //     final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
// //     final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
// //     final isPurchase = purchaseVoucherTypes.contains(voucherType);
// //     final isSales = salesVoucherTypes.contains(voucherType);

// //     if (voucherType == 'Physical Stock') continue;

// //     final batches = voucherBatches[voucherGuid]!;

// //     for (var batchTxn in batches) {
// //       final godown = batchTxn.godownName;
// //       final batchName = batchTxn.batchName;
// //       final amount = batchTxn.amount;
// //       final qty = batchTxn.stock;
// //       final isInward = batchTxn.isInward;
// //       final absAmount = amount.abs();

// //       if (batchTxn.trackingNumber.toLowerCase().contains('not applicable') == false &&
// //           (isPurchase || isSales || isDebitNote || isCreditNote)) {
// //         continue;
// //       }

// //       if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
// //         continue;
// //       }

// //       // Initialize batch if not exists
// //       godownBatchInwardQty.putIfAbsent(godown, () => {});
// //       godownBatchOutwardQty.putIfAbsent(godown, () => {});
// //       godownBatchLots.putIfAbsent(godown, () => {});

// //       godownBatchInwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
// //       godownBatchOutwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
// //       godownBatchLots[godown]!.putIfAbsent(batchName, () => []);

// //       if (isInward) {
// //         if (isCreditNote) {
// //           godownBatchOutwardQty[godown]![batchName] =
// //               godownBatchOutwardQty[godown]![batchName]! - qty;

// //           final rate = qty > 0 ? absAmount / qty : 0.0;
// //           godownBatchLots[godown]![batchName]!.add(StockLot(
// //             voucherGuid: voucherGuid,
// //             voucherDate: dateStr,
// //             voucherNumber: voucherNumber,
// //             voucherType: voucherType,
// //             qty: qty * -1,
// //             amount: amount * -1,
// //             rate: rate,
// //             type: StockInOutType.outward,
// //           ));
// //         } else {
// //           godownBatchInwardQty[godown]![batchName] =
// //               godownBatchInwardQty[godown]![batchName]! + qty;

// //           final rate = qty > 0 ? absAmount / qty : 0.0;
// //           godownBatchLots[godown]![batchName]!.add(StockLot(
// //             voucherGuid: voucherGuid,
// //             voucherDate: dateStr,
// //             voucherNumber: voucherNumber,
// //             voucherType: voucherType,
// //             qty: qty,
// //             amount: absAmount,
// //             rate: rate,
// //             type: StockInOutType.inward,
// //           ));
// //         }
// //       } else {
// //         if (isDebitNote) {
// //           godownBatchInwardQty[godown]![batchName] =
// //               godownBatchInwardQty[godown]![batchName]! - qty;

// //           final rate = qty > 0 ? absAmount / qty : 0.0;
// //           godownBatchLots[godown]![batchName]!.add(StockLot(
// //             voucherGuid: voucherGuid,
// //             voucherDate: dateStr,
// //             voucherNumber: voucherNumber,
// //             voucherType: voucherType,
// //             qty: qty * -1,
// //             amount: amount * -1,
// //             rate: rate,
// //             type: StockInOutType.inward,
// //           ));
// //         } else {
// //           godownBatchOutwardQty[godown]![batchName] =
// //               godownBatchOutwardQty[godown]![batchName]! + qty;

// //           final rate = qty > 0 ? absAmount / qty : 0.0;
// //           godownBatchLots[godown]![batchName]!.add(StockLot(
// //             voucherGuid: voucherGuid,
// //             voucherDate: dateStr,
// //             voucherNumber: voucherNumber,
// //             voucherType: voucherType,
// //             qty: qty,
// //             amount: absAmount,
// //             rate: rate,
// //             type: StockInOutType.outward,
// //           ));
// //         }
// //       }
// //     }
// //   }

// //   // 🔹 Final: Batch → Godown Merge (LIFO closing per batch, then sum)
// //   for (var godown in godownBatchInwardQty.keys) {
// //     double totalClosingQty = 0.0;
// //     double totalClosingValue = 0.0;

// //     final batchKeys = godownBatchInwardQty[godown]!.keys;
// //     for (var batchName in batchKeys) {
// //       final inwardQty = godownBatchInwardQty[godown]![batchName]!;
// //       final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
// //       final closingStockQty = inwardQty - outwardQty;
// //       final lots = godownBatchLots[godown]![batchName] ?? [];

// //       double batchClosingValue = 0.0;

// //       if (closingStockQty > 0) {
// //         batchClosingValue = calculateLifoClosingValue(lots, closingStockQty);
// //       } else if (closingStockQty < 0) {
// //         // Negative stock: Average Cost fallback
// //         double totalLotValue = 0.0;
// //         double totalLotQty = 0.0;
// //         for (var lot in lots) {
// //           if (lot.type == StockInOutType.inward) {
// //             totalLotValue += lot.amount;
// //             totalLotQty += lot.qty;
// //           }
// //         }
// //         final closingRate = totalLotQty == 0 ? 0.0 : totalLotValue / totalLotQty ;
// //         batchClosingValue = closingStockQty * closingRate;
// //       }

// //       totalClosingQty += closingStockQty;
// //       totalClosingValue += batchClosingValue;
// //     }

// //     godownResults[godown] = GodownAverageCost(
// //       godownName: godown,
// //       totalInwardQty: 0,
// //       totalInwardValue: 0,
// //       currentStockQty: totalClosingQty,
// //       averageRate: totalClosingQty > 0 ? totalClosingValue / totalClosingQty : 0.0,
// //       closingValue: totalClosingValue,
// //     );
// //   }

// //   return AverageCostResult(
// //     stockItemGuid: stockItem.stockItemGuid,
// //     itemName: stockItem.itemName,
// //     godowns: godownResults,
// //   );
// // }

// //   Future<AverageCostResult> calculateFifoCost({
// //   required StockItemInfo stockItem,
// //   required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
// //   required String fromDate,
// //   required String toDate,
// //   required String companyGuid,
// // }) async {
// //   Map<String, GodownAverageCost> godownResults = {};

// //   const financialYearStartMonth = 4;
// //   const financialYearStartDay = 1;

// //   String getFinancialYearStartDate(String dateStr) {
// //     final year = int.parse(dateStr.substring(0, 4));
// //     final month = int.parse(dateStr.substring(4, 6));

// //     if (month < financialYearStartMonth) {
// //       return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
// //     } else {
// //       return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
// //     }
// //   }

// //   // 🔹 Godown → Batch → Lot tracking
// //   Map<String, Map<String, double>> godownBatchInwardQty = {};
// //   Map<String, Map<String, double>> godownBatchOutwardQty = {};
// //   Map<String, Map<String, List<StockLot>>> godownBatchLots = {};

// //   // Flatten all transactions and sort by voucherId
// //   List<StockTransaction> allTransactions = [];
// //   for (var godownMap in godownTransactions.values) {
// //     for (var batchList in godownMap.values) {
// //       allTransactions.addAll(batchList);
// //     }
// //   }
// //   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

// //   // Group transactions by voucher_guid
// //   Map<String, List<StockTransaction>> voucherBatches = {};
// //   for (var txn in allTransactions) {
// //     voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
// //     voucherBatches[txn.voucherGuid]!.add(txn);
// //   }

// //   // 🔹 Opening Stock → Batch Level
// //   for (final godownOpeningData in stockItem.openingData) {
// //     String godownName = godownOpeningData.godownName;
// //     if (godownName.isEmpty) {
// //       godownName = 'Main Location';
// //     }

// //     final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
// //     final openingAmount = godownOpeningData.amount;
// //     final batchName = godownOpeningData.batchName;

// //     godownBatchInwardQty.putIfAbsent(godownName, () => {});
// //     godownBatchOutwardQty.putIfAbsent(godownName, () => {});
// //     godownBatchLots.putIfAbsent(godownName, () => {});

// //     godownBatchInwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
// //     godownBatchOutwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
// //     godownBatchLots[godownName]!.putIfAbsent(batchName, () => []);

// //     godownBatchInwardQty[godownName]![batchName] =
// //         godownBatchInwardQty[godownName]![batchName]! + openingQty;

// //     // if (openingQty > 0) {
// //       final openingRate = openingAmount / openingQty;
// //       godownBatchLots[godownName]![batchName]!.add(StockLot(
// //         voucherGuid: 'OPENING_STOCK',
// //         voucherDate: fromDate,
// //         voucherNumber: 'Opening Balance',
// //         voucherType: 'Opening',
// //         qty: openingQty,
// //         amount: openingAmount,
// //         rate: openingRate,
// //         type: StockInOutType.inward,
// //       ));
// //     // }
// //   }

// //   String currentFyStart = '';

// //   // FIFO closing value helper (backwards from last lot = newest first)
// //   double calculateFifoClosingValue(List<StockLot> lots, double closingStockQty) {
// //     if (closingStockQty <= 0 || lots.isEmpty) {
// //       return 0.0;
// //     }

// //     double closingValue = 0.0;
// //     double remainingQty = closingStockQty;
// //     double lastRate = 0.0;

// //     for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
// //       final lot = lots[i];
// //       lastRate = lot.rate;

// //       if (lot.qty == 0) {
// //         closingValue += lot.amount;
// //       } else if (lot.qty <= remainingQty) {
// //         closingValue += lot.amount;
// //         remainingQty -= lot.qty;
// //       } else {
// //         closingValue += remainingQty * lot.rate;
// //         remainingQty = 0;
// //       }
// //     }

// //     if (remainingQty > 0) {
// //       closingValue += remainingQty * lastRate;
// //     }

// //     if (closingValue == 0 && closingStockQty > 0) {
// //       final totalQty = lots.fold(0.0, (sum, lot) => sum + lot.qty);
// //       final totalValue = lots.fold(0.0, (sum, lot) => sum + lot.amount);
// //       if (totalQty > 0) {
// //         closingValue = closingStockQty * (totalValue / totalQty);
// //       }
// //     }

// //     return closingValue;
// //   }

// //   Set<String> processedVouchers = {};

// //   for (var txn in allTransactions) {
// //     final voucherGuid = txn.voucherGuid;

// //     if (processedVouchers.contains(voucherGuid) ||
// //         txn.voucherType.toLowerCase().contains('purchase order') ||
// //         txn.voucherType.toLowerCase().contains('sales order')) {
// //       continue;
// //     }

// //     processedVouchers.add(voucherGuid);

// //     final dateStr = txn.voucherDate;
// //     final voucherType = txn.voucherType;
// //     final voucherNumber = txn.voucherNumber;

// //     if (dateStr.compareTo(toDate) > 0) {
// //       break;
// //     }

// //     final txnFyStart = getFinancialYearStartDate(dateStr);

// //     // 🔹 FY Boundary Reset (Batch Wise)
// //     if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
// //       for (var godown in godownBatchInwardQty.keys) {
// //         final batchKeys = godownBatchInwardQty[godown]!.keys.toList();
// //         for (var batchName in batchKeys) {
// //           final inwardQty = godownBatchInwardQty[godown]![batchName]!;
// //           final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
// //           final closingStockQty = inwardQty - outwardQty;
// //           final lots = godownBatchLots[godown]![batchName] ?? [];

// //           if (closingStockQty > 0) {
// //             final closingValue = calculateFifoClosingValue(lots, closingStockQty);
// //             final closingRate = closingValue / closingStockQty;

// //             godownBatchInwardQty[godown]![batchName] = closingStockQty;
// //             godownBatchOutwardQty[godown]![batchName] = 0.0;
// //             godownBatchLots[godown]![batchName] = [
// //               StockLot(
// //                 voucherGuid: 'FY_OPENING_$txnFyStart',
// //                 voucherDate: txnFyStart,
// //                 voucherNumber: 'FY Opening Balance',
// //                 voucherType: 'Opening',
// //                 qty: closingStockQty,
// //                 amount: closingValue,
// //                 rate: closingRate,
// //                 type: StockInOutType.inward,
// //               )
// //             ];
// //           } else if (closingStockQty < 0) {
// //             // Negative stock: fallback to Average Cost
// //             double totalLotValue = 0.0;
// //             double totalLotQty = 0.0;
// //             for (var lot in lots) {
// //               totalLotValue += lot.amount;
// //               totalLotQty += lot.qty;
// //             }
// //             final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
// //             final closingValue = closingStockQty * closingRate;

// //             godownBatchInwardQty[godown]![batchName] = closingStockQty;
// //             godownBatchOutwardQty[godown]![batchName] = 0.0;
// //             godownBatchLots[godown]![batchName] = [
// //               StockLot(
// //                 voucherGuid: 'FY_OPENING_$txnFyStart',
// //                 voucherDate: txnFyStart,
// //                 voucherNumber: 'FY Opening Balance',
// //                 voucherType: 'Opening',
// //                 qty: closingStockQty,
// //                 amount: closingValue,
// //                 rate: closingRate,
// //                 type: StockInOutType.inward,
// //               )
// //             ];
// //           } else {
// //             godownBatchInwardQty[godown]![batchName] = 0.0;
// //             godownBatchOutwardQty[godown]![batchName] = 0.0;
// //             godownBatchLots[godown]![batchName] = [];
// //           }
// //         }
// //       }
// //     }

// //     currentFyStart = txnFyStart;

// //     final isPurchase = purchaseVoucherTypes.contains(voucherType);
// //     final isSales = salesVoucherTypes.contains(voucherType);
// //     final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
// //     final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

// //     if (voucherType == 'Physical Stock') continue;

// //     final batches = voucherBatches[voucherGuid]!;

// //     for (var batchTxn in batches) {
// //       final godown = batchTxn.godownName;
// //       final batchName = batchTxn.batchName;
// //       final amount = batchTxn.amount;
// //       final qty = batchTxn.stock;
// //       final isInward = batchTxn.isInward;
// //       final absAmount = amount.abs();

// //       if (batchTxn.trackingNumber.toLowerCase().contains('not applicable') == false &&
// //           (isPurchase || isSales || isDebitNote || isCreditNote)) {
// //         continue;
// //       }

// //       if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
// //         continue;
// //       }

// //       // Initialize batch if not exists
// //       godownBatchInwardQty.putIfAbsent(godown, () => {});
// //       godownBatchOutwardQty.putIfAbsent(godown, () => {});
// //       godownBatchLots.putIfAbsent(godown, () => {});

// //       godownBatchInwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
// //       godownBatchOutwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
// //       godownBatchLots[godown]!.putIfAbsent(batchName, () => []);

// //       if (isInward) {
// //         if (isCreditNote) {
// //           godownBatchOutwardQty[godown]![batchName] =
// //               godownBatchOutwardQty[godown]![batchName]! - qty;
// //         } else {
// //           godownBatchInwardQty[godown]![batchName] =
// //               godownBatchInwardQty[godown]![batchName]! + qty;

// //           final rate = qty > 0 ? absAmount / qty : 0.0;
// //           godownBatchLots[godown]![batchName]!.add(StockLot(
// //             voucherGuid: voucherGuid,
// //             voucherDate: dateStr,
// //             voucherNumber: voucherNumber,
// //             voucherType: voucherType,
// //             qty: qty,
// //             amount: absAmount,
// //             rate: rate,
// //             type: StockInOutType.inward,
// //           ));
// //         }
// //       } else {
// //         if (isDebitNote) {
// //           godownBatchInwardQty[godown]![batchName] =
// //               godownBatchInwardQty[godown]![batchName]! - qty;

// //           final rate = qty > 0 ? absAmount / qty : 0.0;
// //           godownBatchLots[godown]![batchName]!.add(StockLot(
// //             voucherGuid: voucherGuid,
// //             voucherDate: dateStr,
// //             voucherNumber: voucherNumber,
// //             voucherType: voucherType,
// //             qty: qty * -1,
// //             amount: amount * -1,
// //             rate: rate,
// //             type: StockInOutType.inward,
// //           ));
// //         } else {
// //           godownBatchOutwardQty[godown]![batchName] =
// //               godownBatchOutwardQty[godown]![batchName]! + qty;
// //         }
// //       }
// //     }
// //   }

// //   // 🔹 Final: Batch → Godown Merge (FIFO closing per batch, then sum)
// //   for (var godown in godownBatchInwardQty.keys) {
// //     double totalClosingQty = 0.0;
// //     double totalClosingValue = 0.0;

// //     final batchKeys = godownBatchInwardQty[godown]!.keys;
// //     for (var batchName in batchKeys) {
// //       final inwardQty = godownBatchInwardQty[godown]![batchName]!;
// //       final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
// //       final closingStockQty = inwardQty - outwardQty;
// //       final lots = godownBatchLots[godown]![batchName] ?? [];

// //       double batchClosingValue = 0.0;

// //       if (closingStockQty > 0) {
// //         batchClosingValue = calculateFifoClosingValue(lots, closingStockQty);
// //       } else if (closingStockQty < 0) {
// //         // Negative stock: Average Cost fallback
// //         double totalLotValue = 0.0;
// //         double totalLotQty = 0.0;
// //         for (var lot in lots) {
// //           totalLotValue += lot.amount;
// //           totalLotQty += lot.qty;
// //         }
// //         final closingRate = totalLotQty == 0 ? 0.0 : totalLotValue / totalLotQty;
// //         batchClosingValue = closingStockQty * closingRate;
// //       }

// //       totalClosingQty += closingStockQty;
// //       totalClosingValue += batchClosingValue;
// //     }

// //     godownResults[godown] = GodownAverageCost(
// //       godownName: godown,
// //       totalInwardQty: 0,
// //       totalInwardValue: 0,
// //       currentStockQty: totalClosingQty,
// //       averageRate: totalClosingQty > 0 ? totalClosingValue / totalClosingQty : 0.0,
// //       closingValue: totalClosingValue,
// //     );
// //   }

// //   return AverageCostResult(
// //     stockItemGuid: stockItem.stockItemGuid,
// //     itemName: stockItem.itemName,
// //     godowns: godownResults,
// //   );
// // }

// // Future<AverageCostResult> calculateAvgCost({
// //   required StockItemInfo stockItem,
// //   required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
// //   required String fromDate,
// //   required String toDate,
// //   required String companyGuid,
// // }) async {

// //   Map<String, GodownAverageCost> godownResults = {};

// //   // 🔹 NEW: Godown → Batch → Accumulator
// //   Map<String, Map<String, BatchAccumulator>> godownBatchData = {};

// //   const financialYearStartMonth = 4;
// //   const financialYearStartDay = 1;

// //   String getFinancialYearStartDate(String dateStr) {
// //     final year = int.parse(dateStr.substring(0, 4));
// //     final month = int.parse(dateStr.substring(4, 6));

// //     if (month < financialYearStartMonth) {
// //       return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
// //     } else {
// //       return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
// //     }
// //   }

// //   // 🔹 Flatten all transactions
// //   List<StockTransaction> allTransactions = [];
// //   for (var godownMap in godownTransactions.values) {
// //     for (var batchList in godownMap.values) {
// //       allTransactions.addAll(batchList);
// //     }
// //   }

// //   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

// //   // 🔹 Group by voucher_guid
// //   Map<String, List<StockTransaction>> voucherBatches = {};
// //   for (var txn in allTransactions) {
// //     voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
// //     voucherBatches[txn.voucherGuid]!.add(txn);
// //   }


// //   // 🔹 Opening Stock → Batch Level
// //   for (final godownOpeningData in stockItem.openingData) {

// //     String godownName = godownOpeningData.godownName;
// //     if (godownName.isEmpty) {
// //       godownName = 'Main Location';
// //     }

// //     final openingQty =
// //         double.tryParse(godownOpeningData.actualQty) ?? 0.0;
// //     final openingAmount = godownOpeningData.amount;
// //     final batchName =
// //         godownOpeningData.batchName;

// //     godownBatchData.putIfAbsent(godownName, () => {});
// //     godownBatchData[godownName]!
// //         .putIfAbsent(batchName, () => BatchAccumulator());

// //     final batch = godownBatchData[godownName]![batchName]!;

// //     batch.inwardQty += openingQty;
// //     batch.inwardValue += openingAmount;
// //   }

// //   String currentFyStart = '';
// //   Set<String> processedVouchers = {};

// //   // 🔹 Process Transactions
// //   for (var txn in allTransactions) {

// //     final voucherGuid = txn.voucherGuid;

// //     if (processedVouchers.contains(voucherGuid) ||
// //         txn.voucherType.toLowerCase().contains('purchase order') ||
// //         txn.voucherType.toLowerCase().contains('sales order')) {
// //       continue;
// //     }

// //     processedVouchers.add(voucherGuid);

// //     final dateStr = txn.voucherDate;
// //     final voucherType = txn.voucherType;

// //     if (dateStr.compareTo(toDate) > 0) {
// //       break;
// //     }

// //     final txnFyStart = getFinancialYearStartDate(dateStr);

// //     // 🔹 FY Boundary Reset (Batch Wise)
// //     if (txnFyStart != currentFyStart &&
// //         currentFyStart.isNotEmpty) {

// //       for (var godown in godownBatchData.keys) {
// //         for (var batchData
// //             in godownBatchData[godown]!.values) {

// //           final inwardQty = batchData.inwardQty;
// //           final inwardValue = batchData.inwardValue;
// //           final outwardQty = batchData.outwardQty;

// //           final closingQty = inwardQty - outwardQty;
// //           final closingRate =
// //               inwardQty > 0 ? inwardValue / inwardQty : 0.0;
// //           final closingValue = closingQty * closingRate;

// //           batchData.inwardQty = closingQty;
// //           batchData.inwardValue = closingValue;
// //           batchData.outwardQty = 0.0;
// //         }
// //       }
// //     }

// //     currentFyStart = txnFyStart;

// //     final isPurchase =
// //         purchaseVoucherTypes.contains(voucherType);
// //     final isSales =
// //         salesVoucherTypes.contains(voucherType);
// //     final isCreditNote =
// //         creditNoteVoucherTypes.contains(voucherType);
// //     final isDebitNote =
// //         debitNoteVoucherTypes.contains(voucherType);

// //     if (voucherType == 'Physical Stock') continue;

// //     final batches = voucherBatches[voucherGuid]!;

// //     for (var batchTxn in batches) {

// //       final godown = batchTxn.godownName;
// //       final batchName =
// //           batchTxn.batchName;

// //       final amount = batchTxn.amount;
// //       final qty = batchTxn.stock;
// //       final isInward = batchTxn.isInward;
// //       final absAmount = amount.abs();

// //       if (batchTxn.trackingNumber
// //               .toLowerCase()
// //               .contains('not applicable') ==
// //           false &&
// //           (isPurchase ||
// //               isSales ||
// //               isDebitNote ||
// //               isCreditNote)) {continue;}

// //       if ((isCreditNote || isDebitNote) &&
// //           qty == 0 &&
// //           amount == 0) {
// //         continue;
// //       }

// //       godownBatchData.putIfAbsent(godown, () => {});
// //       godownBatchData[godown]!
// //           .putIfAbsent(batchName, () => BatchAccumulator());

// //       final batchData =
// //           godownBatchData[godown]![batchName]!;

// //       if (isInward) {
// //         if (isCreditNote) {
// //           batchData.outwardQty -= qty;
// //         } else {
// //           batchData.inwardQty += qty;
// //           batchData.inwardValue += absAmount;
// //         }
// //       } else {
// //         if (isDebitNote) {
// //           batchData.inwardQty -= qty;
// //           batchData.inwardValue -= absAmount;
// //         } else {
// //           batchData.outwardQty += qty;
// //         }
// //       }
// //     }
// //   }

// //   // 🔹 Final: Batch → Godown Merge
// //   for (var godown in godownBatchData.keys) {

// //     final batches = godownBatchData[godown]!;

// //     double closingQty = 0.0;
// //     double closingValue = 0.0;

// //     for (var batchData in batches.values) {
// //       closingQty += (batchData.inwardQty - batchData.outwardQty);

// //       final batchRate = batchData.inwardQty != 0
// //     ? batchData.inwardValue / batchData.inwardQty
// //     : 0.0;
// //       closingValue += (batchData.inwardQty - batchData.outwardQty) * batchRate;

  
// //     }

// //     godownResults[godown] = GodownAverageCost(
// //       godownName: godown,
// //       totalInwardQty: 0,
// //       totalInwardValue: 0,
// //       currentStockQty: closingQty,
// //       averageRate: 0,
// //       closingValue: closingValue,
// //     );
// //   }

// //   return AverageCostResult(
// //     stockItemGuid: stockItem.stockItemGuid,
// //     itemName: stockItem.itemName,
// //     godowns: godownResults,
// //   );
// // }


// //   Future<AverageCostResult> calculateCostWithoutUnit({
// //   required StockItemInfo stockItem,
// //   required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
// //   required String fromDate,
// //   required String toDate,
// //   required String companyGuid,
// // }) async {
// //   Map<String, GodownAverageCost> godownResults = {};

// //   // 🔹 Godown → Batch → Value tracking
// //   Map<String, Map<String, double>> godownBatchInwardValue = {};
// //   Map<String, Map<String, double>> godownBatchOutwardValue = {};

// //   // Flatten all transactions and sort by voucherId
// //   List<StockTransaction> allTransactions = [];
// //   for (var godownMap in godownTransactions.values) {
// //     for (var batchList in godownMap.values) {
// //       allTransactions.addAll(batchList);
// //     }
// //   }
// //   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

// //   // Group transactions by voucher_guid
// //   Map<String, List<StockTransaction>> voucherBatches = {};
// //   for (var txn in allTransactions) {
// //     voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
// //     voucherBatches[txn.voucherGuid]!.add(txn);
// //   }

// //   // 🔹 Opening Stock → Batch Level
// //   for (final godownOpeningData in stockItem.openingData) {
// //     String godownName = godownOpeningData.godownName;
// //     if (godownName.isEmpty) {
// //       godownName = 'Main Location';
// //     }

// //     final openingAmount = godownOpeningData.amount;
// //     final batchName = godownOpeningData.batchName;

// //     godownBatchInwardValue.putIfAbsent(godownName, () => {});
// //     godownBatchOutwardValue.putIfAbsent(godownName, () => {});

// //     godownBatchInwardValue[godownName]!.putIfAbsent(batchName, () => 0.0);
// //     godownBatchOutwardValue[godownName]!.putIfAbsent(batchName, () => 0.0);

// //     godownBatchInwardValue[godownName]![batchName] =
// //         godownBatchInwardValue[godownName]![batchName]! + openingAmount;
// //   }

// //   // Process transactions
// //   Set<String> processedVouchers = {};

// //   for (var txn in allTransactions) {
// //     final voucherGuid = txn.voucherGuid;

// //     if (processedVouchers.contains(voucherGuid) ||
// //         txn.voucherType.toLowerCase().contains('purchase order') ||
// //         txn.voucherType.toLowerCase().contains('sales order')) {
// //       continue;
// //     }
// //     processedVouchers.add(voucherGuid);

// //     final dateStr = txn.voucherDate;
// //     final voucherType = txn.voucherType;

// //     if (dateStr.compareTo(toDate) > 0) {
// //       break;
// //     }

// //     if (voucherType == 'Physical Stock') {
// //       continue;
// //     }

// //     final batches = voucherBatches[voucherGuid]!;

// //     for (var batchTxn in batches) {
// //       final godown = batchTxn.godownName;
// //       final batchName = batchTxn.batchName;
// //       final amount = batchTxn.amount;
// //       final isInward = batchTxn.isInward;
// //       final absAmount = amount.abs();

// //       final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
// //       final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

// //       // Initialize batch if not exists
// //       godownBatchInwardValue.putIfAbsent(godown, () => {});
// //       godownBatchOutwardValue.putIfAbsent(godown, () => {});

// //       godownBatchInwardValue[godown]!.putIfAbsent(batchName, () => 0.0);
// //       godownBatchOutwardValue[godown]!.putIfAbsent(batchName, () => 0.0);

// //       if (isInward) {
// //         if (isCreditNote) {
// //           godownBatchOutwardValue[godown]![batchName] =
// //               godownBatchOutwardValue[godown]![batchName]! - absAmount;
// //         } else {
// //           godownBatchInwardValue[godown]![batchName] =
// //               godownBatchInwardValue[godown]![batchName]! + absAmount;
// //         }
// //       } else {
// //         if (isDebitNote) {
// //           godownBatchInwardValue[godown]![batchName] =
// //               godownBatchInwardValue[godown]![batchName]! - absAmount;
// //         } else {
// //           godownBatchOutwardValue[godown]![batchName] =
// //               godownBatchOutwardValue[godown]![batchName]! + absAmount;
// //         }
// //       }
// //     }
// //   }

// //   // 🔹 Final: Batch → Godown Merge
// //   for (var godown in godownBatchInwardValue.keys) {
// //     double totalInward = 0.0;
// //     double totalOutward = 0.0;

// //     final batchKeys = godownBatchInwardValue[godown]!.keys;
// //     for (var batchName in batchKeys) {
// //       totalInward += godownBatchInwardValue[godown]![batchName] ?? 0.0;
// //       totalOutward += godownBatchOutwardValue[godown]![batchName] ?? 0.0;
// //     }

// //     godownResults[godown] = GodownAverageCost(
// //       godownName: godown,
// //       totalInwardQty: 0,
// //       totalInwardValue: totalInward,
// //       currentStockQty: 0,
// //       averageRate: 0.0,
// //       closingValue: totalInward - totalOutward,
// //     );
// //   }

// //   return AverageCostResult(
// //     stockItemGuid: stockItem.stockItemGuid,
// //     itemName: stockItem.itemName,
// //     godowns: godownResults,
// //   );
// // }

// //   Future<Map<String, dynamic>> _getProfitLossDetailed(
// //     String companyGuid,
// //     DateTime fromDate,
// //     DateTime toDate,
// //   ) async {
// //     final db = await _db.database;

// //     String fromDateStr = dateToString(fromDate);
// //     String toDateStr = dateToString(toDate);

// //     final purchaseResult = await db.rawQuery('''
// //       WITH RECURSIVE group_tree AS (
// //         SELECT group_guid, name
// //         FROM groups
// //         WHERE company_guid = ?
// //           AND reserved_name = 'Purchase Accounts'
// //           AND is_deleted = 0
        
// //         UNION ALL
        
// //         SELECT g.group_guid, g.name
// //         FROM groups g
// //         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
// //         WHERE g.company_guid = ?
// //           AND g.is_deleted = 0
// //       )
// //       SELECT 
// //         COUNT(*) as vouchers,
// //         SUM(debit_amount) as debit_total,
// //         SUM(credit_amount) as credit_total,
// //         SUM(net_amount) as net_purchase
// //       FROM (
// //         SELECT
// //           SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
// //           SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_amount,
// //           (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - 
// //            SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
// //         FROM vouchers v
// //         INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
// //         INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
// //         INNER JOIN group_tree gt ON l.parent = gt.name
// //         WHERE v.company_guid = ?
// //           AND v.is_deleted = 0
// //           AND v.is_cancelled = 0
// //           AND v.is_optional = 0
// //           AND v.date >= ?
// //           AND v.date <= ?
// //         GROUP BY v.voucher_guid
// //       ) voucher_totals
// //     ''', [companyGuid, companyGuid, companyGuid, fromDateStr, toDateStr]);

// //     final debitTotal =
// //         (purchaseResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
// //     final creditTotal =
// //         (purchaseResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
// //     final netPurchase =
// //         (purchaseResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;
// //     final purchaseVouchers = purchaseResult.first['vouchers'] as int? ?? 0;

// //     final salesResult = await db.rawQuery('''
// //       WITH RECURSIVE group_tree AS (
// //         SELECT group_guid, name
// //         FROM groups
// //         WHERE company_guid = ?
// //           AND reserved_name = 'Sales Accounts'
// //           AND is_deleted = 0
        
// //         UNION ALL
        
// //         SELECT g.group_guid, g.name
// //         FROM groups g
// //         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
// //         WHERE g.company_guid = ?
// //           AND g.is_deleted = 0
// //       )
// //       SELECT 
// //     -- Credit = deemed positive side (normal sales)
// //     SUM(CASE WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount) ELSE 0 END) as credit_total,
    
// //     -- Debit = deemed negative side (sales returns)
// //     SUM(CASE WHEN vle.is_deemed_positive = 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
    
// //     -- Net = credit - debit
// //     SUM(CASE 
// //       WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount)
// //       ELSE -ABS(vle.amount)
// //     END) as net_sales,
    
// //     COUNT(DISTINCT v.voucher_guid) as vouchers
// //       FROM voucher_ledger_entries vle
// //       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
// //       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
// //       INNER JOIN group_tree gt ON l.parent_guid = gt.group_guid
// //       WHERE v.company_guid = ?
// //         AND v.is_deleted = 0
// //         AND v.is_cancelled = 0
// //         AND v.is_optional = 0
// //         AND v.date >= ?
// //         AND v.date <= ?
// //     ''', [companyGuid, companyGuid, companyGuid, fromDateStr, toDateStr]);

// //     final salesCredit =
// //         (salesResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
// //     final salesDebit =
// //         (salesResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
// //     final netSales =
// //         (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;
// //     final salesVouchers = salesResult.first['vouchers'] as int? ?? 0;



// //     final directExpenses = await db.rawQuery('''
// //   WITH RECURSIVE group_tree AS (
// //     SELECT group_guid, name
// //     FROM groups
// //     WHERE company_guid = ?
// //       AND name = 'Direct Expenses'
// //       AND is_deleted = 0
    
// //     UNION ALL
    
// //     SELECT g.group_guid, g.name
// //     FROM groups g
// //     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
// //     WHERE g.company_guid = ?
// //       AND g.is_deleted = 0
// //   )
// //   SELECT 
// //     l.name as ledger_name,
// //     l.opening_balance,
// //     COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
// //     COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
// //     (l.opening_balance + 
// //      COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
// //      COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
// //   FROM ledgers l
// //   INNER JOIN group_tree gt ON l.parent = gt.name
// //   INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
// //   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
// //     AND v.company_guid = l.company_guid
// //     AND v.is_deleted = 0
// //     AND v.is_cancelled = 0
// //     AND v.is_optional = 0
// //     AND v.date >= ?
// //     AND v.date <= ?
// //   WHERE l.company_guid = ?
// //     AND l.is_deleted = 0
// //   GROUP BY l.name, l.opening_balance
// //   ORDER BY closing_balance DESC
// // ''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

// //     double totalDirectExpenses = 0.0;
// //     for (final expense in directExpenses) {
// //       final closingBalance =
// //           (expense['closing_balance'] as num?)?.toDouble() ?? 0.0;
// //       totalDirectExpenses += closingBalance; // ← Now includes opening balance
// //     }

// //     final indirectExpenses = await db.rawQuery('''
// //   WITH RECURSIVE group_tree AS (
// //     SELECT group_guid, name
// //     FROM groups
// //     WHERE company_guid = ?
// //       AND name = 'Indirect Expenses'
// //       AND is_deleted = 0
    
// //     UNION ALL
    
// //     SELECT g.group_guid, g.name
// //     FROM groups g
// //     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
// //     WHERE g.company_guid = ?
// //       AND g.is_deleted = 0
// //   )
// //   SELECT 
// //     l.name as ledger_name,
// //     l.opening_balance,
// //     COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
// //     COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
// //     (l.opening_balance + 
// //      COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
// //      COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
// //   FROM ledgers l
// //   INNER JOIN group_tree gt ON l.parent = gt.name
// //   INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
// //   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
// //     AND v.company_guid = l.company_guid
// //     AND v.is_deleted = 0
// //     AND v.is_cancelled = 0
// //     AND v.is_optional = 0
// //     AND v.date >= ?
// //     AND v.date <= ?
// //   WHERE l.company_guid = ?
// //     AND l.is_deleted = 0
// //   GROUP BY l.name, l.opening_balance
// //   ORDER BY closing_balance DESC
// // ''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

// //     double totalIndirectExpenses = 0.0;
// //     for (final expense in indirectExpenses) {
// //       final closingBalance =
// //           (expense['closing_balance'] as num?)?.toDouble() ?? 0.0;
// //       totalIndirectExpenses += closingBalance;
// //     }

// //     final indirectIncomes = await db.rawQuery('''
// //   WITH RECURSIVE group_tree AS (
// //     SELECT group_guid, name
// //     FROM groups
// //     WHERE company_guid = ?
// //       AND name = 'Indirect Incomes'
// //       AND is_deleted = 0
    
// //     UNION ALL
    
// //     SELECT g.group_guid, g.name
// //     FROM groups g
// //     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
// //     WHERE g.company_guid = ?
// //       AND g.is_deleted = 0
// //   )
// //   SELECT 
// //     l.name as ledger_name,
// //     l.opening_balance,
// //     COALESCE(SUM(CASE 
// //       WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
// //       THEN vle.amount 
// //       ELSE 0 
// //     END), 0) as credit_total,
// //     COALESCE(SUM(CASE 
// //       WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
// //       THEN ABS(vle.amount) 
// //       ELSE 0 
// //     END), 0) as debit_total,
// //     (l.opening_balance + 
// //      COALESCE(SUM(CASE 
// //        WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
// //        THEN vle.amount 
// //        ELSE 0 
// //      END), 0) - 
// //      COALESCE(SUM(CASE 
// //        WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
// //        THEN ABS(vle.amount) 
// //        ELSE 0 
// //      END), 0)) as closing_balance
// //   FROM ledgers l
// //   INNER JOIN group_tree gt ON l.parent = gt.name
// //   INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
// //   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
// //     AND v.company_guid = l.company_guid
// //     AND v.is_deleted = 0
// //     AND v.is_cancelled = 0
// //     AND v.is_optional = 0
// //     AND v.date >= ?
// //     AND v.date <= ?
// //   WHERE l.company_guid = ?
// //     AND l.is_deleted = 0
// //   GROUP BY l.name, l.opening_balance
// //   HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
// //   ORDER BY closing_balance DESC
// // ''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

// //     double totalIndirectIncomes = 0.0;
// //     for (final income in indirectIncomes) {
// //       final closing = (income['closing_balance'] as num?)?.toDouble() ?? 0.0;
// //       totalIndirectIncomes += closing;
// //     }

// //     final directIncomes = await db.rawQuery('''
// //   WITH RECURSIVE group_tree AS (
// //     SELECT group_guid, name
// //     FROM groups
// //     WHERE company_guid = ?
// //       AND name = 'Direct Incomes'
// //       AND is_deleted = 0
    
// //     UNION ALL
    
// //     SELECT g.group_guid, g.name
// //     FROM groups g
// //     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
// //     WHERE g.company_guid = ?
// //       AND g.is_deleted = 0
// //   )
// //   SELECT 
// //     l.name as ledger_name,
// //     l.opening_balance,
// //     COALESCE(SUM(CASE 
// //       WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
// //       THEN vle.amount 
// //       ELSE 0 
// //     END), 0) as credit_total,
// //     COALESCE(SUM(CASE 
// //       WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
// //       THEN ABS(vle.amount) 
// //       ELSE 0 
// //     END), 0) as debit_total,
// //     (l.opening_balance + 
// //      COALESCE(SUM(CASE 
// //        WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
// //        THEN vle.amount 
// //        ELSE 0 
// //      END), 0) - 
// //      COALESCE(SUM(CASE 
// //        WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
// //        THEN ABS(vle.amount) 
// //        ELSE 0 
// //      END), 0)) as closing_balance
// //   FROM ledgers l
// //   INNER JOIN group_tree gt ON l.parent = gt.name
// //   INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
// //   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
// //     AND v.company_guid = l.company_guid
// //     AND v.is_deleted = 0
// //     AND v.is_cancelled = 0
// //     AND v.is_optional = 0
// //     AND v.date >= ?
// //     AND v.date <= ?
// //   WHERE l.company_guid = ?
// //     AND l.is_deleted = 0
// //   GROUP BY l.name, l.opening_balance
// //   HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
// //   ORDER BY closing_balance DESC
// // ''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

// //     double totalDirectIncomes = 0.0;
// //     for (final income in directIncomes) {
// //       final closing = (income['closing_balance'] as num?)?.toDouble() ?? 0.0;
// //       totalDirectIncomes += closing;
// //     }    

// //     double totalClosingStock = 0.0;
// //     double totalOpeningStock = 0.0;

// // if (_isMaintainInventory){
// //     // final allItemClosings = await calculateAllAverageCost(companyGuid: _companyGuid!, fromDate: fromDateStr, toDate: toDateStr);

// //     // totalClosingStock = getTotalClosingValue(allItemClosings);

// //     // final previousDay = dateToString(fromDate).compareTo(_companyStartDate) <= 0 ? fromDateStr : getPreviousDate(fromDateStr);

// //     // final allItemOpening = await calculateAllAverageCost(companyGuid: _companyGuid!,fromDate: previousDay,toDate: previousDay);

// //     // totalOpeningStock = getTotalClosingValue(allItemOpening);

// // }else{

// //   final closingStockResult = await db.rawQuery('''
// //   WITH RECURSIVE stock_groups AS (
// //     SELECT group_guid, name
// //     FROM groups
// //     WHERE company_guid = ?
// //       AND (reserved_name = 'Stock-in-Hand' OR name = 'Stock-in-Hand')
// //       AND is_deleted = 0
    
// //     UNION ALL
    
// //     SELECT g.group_guid, g.name
// //     FROM groups g
// //     INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
// //     WHERE g.company_guid = ?
// //       AND g.is_deleted = 0
// //   ),
// //   latest_balances AS (
// //     SELECT lcb.ledger_guid, lcb.amount * -1 as closing_amount,
// //            ROW_NUMBER() OVER (PARTITION BY lcb.ledger_guid ORDER BY lcb.closing_date DESC) as rn
// //     FROM ledger_closing_balances lcb
// //     INNER JOIN ledgers l ON l.ledger_guid = lcb.ledger_guid
// //     INNER JOIN stock_groups sg ON l.parent = sg.name
// //     WHERE lcb.company_guid = ?
// //       AND lcb.closing_date <= ?
// //       AND l.is_deleted = 0
// //   )
// //   SELECT COALESCE(SUM(closing_amount), 0) as total_closing_stock
// //   FROM latest_balances
// //   WHERE rn = 1
// // ''', [companyGuid, companyGuid, companyGuid, toDateStr]);

// //   totalClosingStock = closingStockResult.isNotEmpty 
// //       ? (closingStockResult.first['total_closing_stock'] as num?)?.toDouble() ?? 0.0
// //       : 0.0;

// //   final previousDay = fromDateStr.compareTo(_companyStartDate) <= 0 
// //       ? _companyStartDate 
// //       : getPreviousDate(fromDateStr);

// // final openingStockResult = await db.rawQuery('''
// //   WITH RECURSIVE stock_groups AS (
// //     SELECT group_guid, name
// //     FROM groups
// //     WHERE company_guid = ?
// //       AND (reserved_name = 'Stock-in-Hand' OR name = 'Stock-in-Hand')
// //       AND is_deleted = 0
    
// //     UNION ALL
    
// //     SELECT g.group_guid, g.name
// //     FROM groups g
// //     INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
// //     WHERE g.company_guid = ?
// //       AND g.is_deleted = 0
// //   ),
// //   latest_balances AS (
// //     SELECT l.ledger_guid,
// //            COALESCE(lcb.amount, l.opening_balance) * -1 as opening_amount,
// //            ROW_NUMBER() OVER (
// //              PARTITION BY l.ledger_guid 
// //              ORDER BY lcb.closing_date DESC NULLS LAST
// //            ) as rn
// //     FROM ledgers l
// //     INNER JOIN stock_groups sg ON l.parent = sg.name
// //     LEFT JOIN ledger_closing_balances lcb ON lcb.ledger_guid = l.ledger_guid
// //       AND lcb.company_guid = ?
// //       AND lcb.closing_date <= ?
// //     WHERE l.company_guid = ?
// //       AND l.is_deleted = 0
// //   )
// //   SELECT COALESCE(SUM(opening_amount), 0) as total_opening_stock
// //   FROM latest_balances
// //   WHERE rn = 1
// // ''', [companyGuid, companyGuid, companyGuid, previousDay, companyGuid]);

// //   totalOpeningStock = openingStockResult.isNotEmpty
// //       ? (openingStockResult.first['total_opening_stock'] as num?)?.toDouble() ?? 0.0
// //       : 0.0;
// // }
    

// //     final grossProfit = (netSales + totalDirectIncomes + totalClosingStock) -
// //         (totalOpeningStock + netPurchase + totalDirectExpenses.abs());
// //     final netProfit =
// //         grossProfit + totalIndirectIncomes - totalIndirectExpenses.abs();

// //     print('opening_stock : ${totalOpeningStock}');
// //     print('closing_stock : ${totalClosingStock}');

// //     return {
// //       'opening_stock': totalOpeningStock,
// //       'purchase': netPurchase,
// //       'direct_expenses': directExpenses,
// //       'direct_expenses_total': totalDirectExpenses.abs(),
// //       'gross_profit': grossProfit,
// //       'closing_stock': totalClosingStock,
// //       'sales': netSales,
// //       'indirect_expenses': indirectExpenses,
// //       'indirect_expenses_total': totalIndirectExpenses.abs(),
// //       'indirect_incomes': indirectIncomes,
// //       'indirect_incomes_total': totalIndirectIncomes,
// //       'direct_incomes': directIncomes,
// //       'direct_incomes_total': totalDirectIncomes,
// //       'net_profit': netProfit,
// //     };
// //   }

// //   void _navigateToGroup(String groupName) {
// //     if (_companyGuid == null || _companyName == null) return;

// //     Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (context) => GroupDetailScreen(
// //           companyGuid: _companyGuid!,
// //           companyName: _companyName!,
// //           groupName: groupName,
// //           fromDate: dateToString(_fromDate),
// //           toDate: dateToString(_toDate),
// //         ),
// //       ),
// //     );
// //   }


// //   @override
// //   Widget build(BuildContext context) {
// //     if (_loading) {
// //       return Scaffold(
// //         appBar: AppBar(title: Text('Profit & Loss A/c')),
// //         body: Center(child: CircularProgressIndicator()),
// //       );
// //     }

// //     return Scaffold(
// //       backgroundColor: Colors.white,
// //       appBar: AppBar(
// //         title: Text('Profit & Loss A/c'),
// //         actions: [
// //           IconButton(
// //             icon: Icon(Icons.calendar_today),
// //             onPressed: _selectDateRange,
// //           ),
// //           IconButton(
// //             icon: Icon(Icons.refresh),
// //             onPressed: _loadData,
// //           ),
// //         ],
// //       ),
// //       body: SingleChildScrollView(
// //         child: Column(
// //           children: [
// //             // Header
// //             Container(
// //               width: double.infinity,
// //               color: Colors.blue[50],
// //               padding: EdgeInsets.all(16),
// //               child: Column(
// //                 children: [
// //                   Text(
// //                     _companyName ?? '',
// //                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
// //                   ),
// //                   SizedBox(height: 4),
// //                   Text(
// //                     '${_formatDate(dateToString(_fromDate))} to ${_formatDate(dateToString(_toDate))}',
// //                     style: TextStyle(fontSize: 14, color: Colors.grey[700]),
// //                   ),
// //                 ],
// //               ),
// //             ),

// //             // Main Content
// //             Row(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 // Left Side - Expenses
// //                 Expanded(
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       _buildSectionHeader('Particulars'),
// //                       _buildLeftItem(
// //                         'Opening Stock',
// //                         _plData?['opening_stock'] ?? 0.0,
// //                         onTap: () => _navigateToGroup('Purchase Accounts'),
// //                       ),
// //                       _buildLeftItem(
// //                         'Purchase Accounts',
// //                         _plData?['purchase'] ?? 0.0,
// //                         onTap: () => _navigateToGroup('Purchase Accounts'),
// //                       ),
// //                       _buildLeftItem(
// //                         'Direct Expenses',
// //                         _plData?['direct_expenses_total'] ?? 0.0,
// //                         onTap: () => _navigateToGroup('Direct Expenses'),
// //                       ),
// //                       _buildGrossProfitRow(
// //                         'Gross Profit c/o',
// //                         _plData?['gross_profit'] ?? 0.0,
// //                       ),
// //                       Divider(thickness: 2),
// //                       _buildLeftItem(
// //                         'Indirect Expenses',
// //                         _plData?['indirect_expenses_total'] ?? 0.0,
// //                         onTap: () => _navigateToGroup('Indirect Expenses'),
// //                       ),
// //                       _buildNetProfitRow(
// //                         'Net Profit',
// //                         _plData?['net_profit'] ?? 0.0,
// //                       ),
// //                     ],
// //                   ),
// //                 ),

// //                 VerticalDivider(width: 1),

// //                 // Right Side - Incomes
// //                 Expanded(
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       _buildSectionHeader('Particulars'),
// //                       _buildRightItem(
// //                         'Sales Accounts',
// //                         _plData?['sales'] ?? 0.0,
// //                         onTap: () => _navigateToGroup('Sales Accounts'),
// //                       ),
// //                       _buildRightItem(
// //                         'Closing Stock',
// //                         _plData?['closing_stock'] ?? 0.0,
// //                         onTap: () => _navigateToGroup('Sales Accounts'),
// //                       ),
// //                       _buildRightItem(
// //                         'Direct Incomes',
// //                         _plData?['direct_incomes_total'] ?? 0.0,
// //                         onTap: () => _navigateToGroup('Direct Incomes'),
// //                       ),
// //                       SizedBox(height: 20),
// //                       _buildGrossProfitRow(
// //                         'Gross Profit b/f',
// //                         _plData?['gross_profit'] ?? 0.0,
// //                       ),
// //                       Divider(thickness: 2),
// //                       _buildRightItem(
// //                         'Indirect Incomes',
// //                         _plData?['indirect_incomes_total'] ?? 0.0,
// //                         onTap: () => _navigateToGroup('Indirect Incomes'),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ],
// //             ),

// //             // Footer - Total
// //             Container(
// //               width: double.infinity,
// //               color: Colors.grey[200],
// //               padding: EdgeInsets.all(16),
// //               child: Row(
// //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                 children: [
// //                   Text(
// //                     'Total',
// //                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //                   ),
// //                   Text(
// //                     _formatAmount(_calculateTotal()),
// //                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //                   ),
// //                   Text(
// //                     'Total',
// //                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //                   ),
// //                   Text(
// //                     _formatAmount(_calculateTotal()),
// //                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildSectionHeader(String title) {
// //     return Container(
// //       width: double.infinity,
// //       color: Colors.grey[100],
// //       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
// //       child: Text(
// //         title,
// //         style: TextStyle(fontWeight: FontWeight.bold),
// //       ),
// //     );
// //   }

// //   Widget _buildLeftItem(String label, double amount, {VoidCallback? onTap}) {
// //     return InkWell(
// //       onTap: onTap,
// //       child: Container(
// //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
// //         child: Row(
// //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //           children: [
// //             Row(
// //               children: [
// //                 Text(label),
// //                 if (onTap != null) ...[
// //                   SizedBox(width: 8),
// //                   Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
// //                 ],
// //               ],
// //             ),
// //             Text(_formatAmount(amount)),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildRightItem(String label, double amount, {VoidCallback? onTap}) {
// //     return InkWell(
// //       onTap: onTap,
// //       child: Container(
// //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
// //         child: Row(
// //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //           children: [
// //             Row(
// //               children: [
// //                 Text(label),
// //                 if (onTap != null) ...[
// //                   SizedBox(width: 8),
// //                   Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
// //                 ],
// //               ],
// //             ),
// //             Text(_formatAmount(amount)),
// //           ],
// //         ),
// //       ),
// //     );
// //   }


// //   Widget _buildGrossProfitRow(String label, double amount) {
// //     return Container(
// //       color: Colors.amber[100],
// //       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //       child: Row(
// //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //         children: [
// //           Text(
// //             label,
// //             style: TextStyle(fontWeight: FontWeight.bold),
// //           ),
// //           Text(
// //             _formatAmount(amount),
// //             style: TextStyle(fontWeight: FontWeight.bold),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildNetProfitRow(String label, double amount) {
// //     return Container(
// //       color: Colors.green[100],
// //       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //       child: Row(
// //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //         children: [
// //           Text(
// //             label,
// //             style: TextStyle(fontWeight: FontWeight.bold),
// //           ),
// //           Text(
// //             _formatAmount(amount),
// //             style: TextStyle(fontWeight: FontWeight.bold),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   double _calculateTotal() {
// //     final opening = _plData?['opening_stock'] ?? 0.0;
// //     final purchase = _plData?['purchase'] ?? 0.0;
// //     final directExp = _plData?['direct_expenses_total'] ?? 0.0;
// //     final indirectExp = _plData?['indirect_expenses_total'] ?? 0.0;
// //     final netProfit = _plData?['net_profit'] ?? 0.0;

// //     return opening + purchase + directExp + indirectExp + netProfit;
// //   }

// //   String _formatAmount(double amount) {
// //     return amount.toStringAsFixed(2).replaceAllMapped(
// //           RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
// //           (Match m) => '${m[1]},',
// //         );
// //   }

// //   String _formatDate(String tallyDate) {
// //     if (tallyDate.length != 8) return tallyDate;
// //     final year = tallyDate.substring(0, 4);
// //     final month = tallyDate.substring(4, 6);
// //     final day = tallyDate.substring(6, 8);
// //     return '$day-$month-$year';
// //   }

// //   Future<void> _selectDateRange() async {
// //     final DateTimeRange? picked = await showDateRangePicker(
// //       context: context,
// //       firstDate: DateTime(2000),
// //       lastDate: DateTime(2100),
// //       initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
// //       builder: (context, child) {
// //         return Theme(
// //           data: ThemeData.light().copyWith(
// //             colorScheme: const ColorScheme.light(
// //               primary: Colors.blue,
// //               onPrimary: Colors.white,
// //               surface: Colors.white,
// //               onSurface: Colors.black,
// //             ),
// //             dialogBackgroundColor: Colors.white,
// //           ),
// //           child: child!,
// //         );
// //       },
// //     );

// //     if (picked != null) {
// //       setState(() {
// //         // _selectedFromDate = picked.start;
// //         // _selectedToDate = picked.end;
// //         _fromDate = picked.start;
// //         _toDate = picked.end;
// //       });

// //       await _loadData();
// //     }
// //   }
// // }


// import 'package:flutter/material.dart';
// import '../../models/data_model.dart';
// import '../../database/database_helper.dart';
// import '../../utils/date_utils.dart';
// import 'group_detail_screen.dart';

// class ProfitLossScreen extends StatefulWidget {
//   @override
//   _ProfitLossScreenState createState() => _ProfitLossScreenState();
// }

// class _ProfitLossScreenState extends State<ProfitLossScreen>
//     with SingleTickerProviderStateMixin {
//   final _db = DatabaseHelper.instance;

//   String? _companyGuid;
//   String? _companyName;
//   String _companyStartDate = getCurrentFyStartDate();
//   bool _loading = true;
//   bool _isMaintainInventory = true;

//   List<String> debitNoteVoucherTypes    = [];
//   List<String> creditNoteVoucherTypes   = [];
//   List<String> stockJournalVoucherType  = [];
//   List<String> physicalStockVoucherType = [];
//   List<String> receiptNoteVoucherTypes  = [];
//   List<String> deliveryNoteVoucherTypes = [];
//   List<String> purchaseVoucherTypes     = [];
//   List<String> salesVoucherTypes        = [];

//   Map<String, dynamic>? _plData;
//   DateTime _fromDate = getFyStartDate(DateTime.now());
//   DateTime _toDate   = getFyEndDate(DateTime.now());

//   // Expand/collapse state for each section
//   bool _showDirectExpDetail    = false;
//   bool _showIndirectExpDetail  = false;
//   bool _showDirectIncDetail    = false;
//   bool _showIndirectIncDetail  = false;

//   late AnimationController _fadeCtrl;
//   late Animation<double>   _fadeAnim;

//   // ── Design tokens ──────────────────────────────────────────────────────────
//   static const Color _primary   = Color(0xFF1A6FD8);
//   static const Color _accent    = Color(0xFF00C9A7);
//   static const Color _bg        = Color(0xFFF4F6FB);
//   static const Color AppColors.surface    = Colors.white;
//   static const Color AppColors.textPrimary  = Color(0xFF1A2340);
//   static const Color AppColors.textSecondary = Color(0xFF8A94A6);
//   static const Color _debitCol  = Color(0xFFD32F2F);
//   static const Color _creditCol = Color(0xFF1B8A5A);
//   static const Color _grossBg   = Color(0xFFFFF8E1);
//   static const Color _grossC    = Color(0xFFB45309);
//   static const Color _netBg     = Color(0xFFE8F5EE);
//   static const Color _netC      = Color(0xFF1B8A5A);
//   static const Color _netLossBg = Color(0xFFFFEBEB);
//   static const Color _netLossC  = Color(0xFFD32F2F);

//   @override
//   void initState() {
//     super.initState();
//     _fadeCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 600));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _loadData();
//   }

//   @override
//   void dispose() {
//     _fadeCtrl.dispose();
//     super.dispose();
//   }

//   // ── Data loading (unchanged logic) ─────────────────────────────────────────

//   Future<void> _loadData() async {
//     setState(() => _loading = true);

//     final company = await _db.getSelectedCompanyByGuid();
//     if (company == null) {
//       setState(() => _loading = false);
//       return;
//     }

//     _companyGuid         = company['company_guid'] as String;
//     _companyName         = company['company_name'] as String;
//     _isMaintainInventory = (company['integrate_inventory'] as int) == 1;
//     _companyStartDate    =
//         (company['starting_from'] as String).replaceAll('-', '');

//     debitNoteVoucherTypes    = await getAllChildVoucherTypes(_companyGuid!, 'Debit Note');
//     creditNoteVoucherTypes   = await getAllChildVoucherTypes(_companyGuid!, 'Credit Note');
//     stockJournalVoucherType  = await getAllChildVoucherTypes(_companyGuid!, 'Stock Journal');
//     physicalStockVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Physical Stock');
//     receiptNoteVoucherTypes  = await getAllChildVoucherTypes(_companyGuid!, 'Receipt Note');
//     deliveryNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Delivery Note');
//     purchaseVoucherTypes     = await getAllChildVoucherTypes(_companyGuid!, 'Purchase');
//     salesVoucherTypes        = await getAllChildVoucherTypes(_companyGuid!, 'Sales');

//     final plData =
//         await _getProfitLossDetailed(_companyGuid!, _fromDate, _toDate);

//     setState(() {
//       _plData  = plData;
//       _loading = false;
//     });
//     _fadeCtrl.forward(from: 0);
//   }

//   double getTotalClosingValue(List<AverageCostResult> results) {
//     double total = 0.0;
//     for (var r in results) {
//       for (var g in r.godowns.values) total += g.closingValue;
//     }
//     return total;
//   }

//   // ── Voucher type helpers (unchanged) ───────────────────────────────────────

//   Future<List<String>> getAllChildVoucherTypes(
//       String companyGuid, String voucherTypeName) async {
//     final db = await _db.database;
//     final result = await db.rawQuery('''
//       WITH RECURSIVE voucher_type_tree AS (
//         SELECT voucher_type_guid, name
//         FROM voucher_types
//         WHERE company_guid = ?
//           AND (name = ? OR reserved_name = ?)
//           AND is_deleted = 0
//         UNION ALL
//         SELECT vt.voucher_type_guid, vt.name
//         FROM voucher_types vt
//         INNER JOIN voucher_type_tree vtt ON vt.parent_guid = vtt.voucher_type_guid
//         WHERE vt.company_guid = ?
//           AND vt.is_deleted = 0
//           AND vt.voucher_type_guid != vt.parent_guid
//       )
//       SELECT name FROM voucher_type_tree ORDER BY name
//     ''', [companyGuid, voucherTypeName, voucherTypeName, companyGuid]);
//     return result.map((r) => r['name'] as String).toList();
//   }

//   Future<List<StockItemInfo>> fetchAllStockItems(String companyGuid) async {
//     final db = await _db.database;
//     final stockItemResults = await db.rawQuery('''
//       SELECT si.name as item_name, si.stock_item_guid,
//         COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
//         COALESCE(si.base_units, '') as unit,
//         COALESCE(si.parent, '') as parent_name
//       FROM stock_items si
//       WHERE si.company_guid = ? AND si.is_deleted = 0
//         AND (
//           EXISTS (SELECT 1 FROM stock_item_batch_allocation siba WHERE siba.stock_item_guid = si.stock_item_guid)
//           OR EXISTS (SELECT 1 FROM voucher_inventory_entries vie WHERE vie.stock_item_guid = si.stock_item_guid AND vie.company_guid = si.company_guid)
//         )
//     ''', [companyGuid]);

//     final batchResults = await db.rawQuery('''
//       SELECT siba.stock_item_guid, COALESCE(siba.godown_name, '') as godown_name,
//         COALESCE(siba.batch_name, '') as batch_name,
//         COALESCE(siba.opening_value, 0) as amount,
//         COALESCE(siba.opening_balance, '') as actual_qty,
//         siba.opening_rate as batch_rate
//       FROM stock_item_batch_allocation siba
//       INNER JOIN stock_items si ON siba.stock_item_guid = si.stock_item_guid
//       WHERE si.company_guid = ? AND si.is_deleted = 0
//     ''', [companyGuid]);

//     final Map<String, List<BatchAllocation>> batchMap = {};
//     for (final row in batchResults) {
//       final guid = row['stock_item_guid'] as String;
//       batchMap.putIfAbsent(guid, () => []).add(BatchAllocation(
//         godownName: row['godown_name'] as String,
//         trackingNumber: 'Not Applicable',
//         batchName: row['batch_name'] as String,
//         amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
//         actualQty: row['actual_qty']?.toString() ?? '',
//         billedQty: row['actual_qty']?.toString() ?? '',
//         batchRate: (row['batch_rate'] as num?)?.toDouble(),
//       ));
//     }

//     return stockItemResults.map((row) {
//       final guid = row['stock_item_guid'] as String;
//       return StockItemInfo(
//         itemName: row['item_name'] as String,
//         stockItemGuid: guid,
//         costingMethod: row['costing_method'] as String,
//         unit: row['unit'] as String,
//         parentName: row['parent_name'] as String,
//         closingRate: 0.0, closingQty: 0.0, closingValue: 0.0,
//         openingData: batchMap[guid] ?? [],
//       );
//     }).toList();
//   }

//   Future<List<StockTransaction>> fetchTransactionsForStockItem(
//       String companyGuid, String stockItemGuid, String endDate) async {
//     final db = await _db.database;
//     final results = await db.rawQuery('''
//       SELECT v.voucher_guid, v.voucher_key as voucher_id, v.date as voucher_date,
//         v.voucher_number, vba.godown_name, v.voucher_type,
//         vba.actual_qty as stock, COALESCE(vba.batch_rate, 0) as rate,
//         vba.amount, vba.is_deemed_positive as is_inward,
//         COALESCE(vba.batch_name, '') as batch_name,
//         COALESCE(vba.destination_godown_name, '') as destination_godown,
//         COALESCE(vba.tracking_number, 'Not Applicable') as tracking_number
//       FROM vouchers v
//       INNER JOIN voucher_batch_allocations vba ON vba.voucher_guid = v.voucher_guid
//       WHERE vba.stock_item_guid = ? AND v.company_guid = ?
//         AND v.date <= ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
//       ORDER BY v.date, v.master_id
//     ''', [stockItemGuid, companyGuid, endDate]);

//     return results.map((row) {
//       final stockStr = (row['stock'] as String?) ?? '0';
//       final parts    = stockStr.split(' ');
//       final stock    = double.tryParse(parts[0]) ?? 0.0;
//       return StockTransaction(
//         voucherGuid: row['voucher_guid'] as String,
//         voucherId: (row['voucher_id'] as int?) ?? 0,
//         voucherDate: row['voucher_date'] as String,
//         voucherNumber: row['voucher_number'] as String,
//         godownName: (row['godown_name'] as String?) ?? 'Primary',
//         voucherType: row['voucher_type'] as String,
//         stock: stock,
//         rate: (row['rate'] as num?)?.toDouble() ?? 0.0,
//         amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
//         isInward: (row['is_inward'] as int) == 1,
//         batchName: row['batch_name'] as String,
//         destinationGodown: row['destination_godown'] as String,
//         trackingNumber: row['tracking_number'] as String,
//       );
//     }).toList();
//   }

//   Future<Map<String, Map<String, Map<String, List<StockTransaction>>>>>
//       buildStockDirectoryWithBatch(
//           String companyGuid, String endDate, List<StockItemInfo> stockItems) async {
//     Map<String, Map<String, Map<String, List<StockTransaction>>>> directory = {};
//     for (var item in stockItems) {
//       final txns = await fetchTransactionsForStockItem(companyGuid, item.stockItemGuid, endDate);
//       Map<String, Map<String, List<StockTransaction>>> godownTxns = {};
//       for (var t in txns) {
//         godownTxns.putIfAbsent(t.godownName, () => {});
//         godownTxns[t.godownName]!.putIfAbsent(t.batchName, () => []).add(t);
//       }
//       directory[item.stockItemGuid] = godownTxns;
//     }
//     return directory;
//   }

//   // ── All cost calculations preserved verbatim (avgCost, fifo, lifo, noUnit) ─
//   // [All calculateAvgCost, calculateFifoCost, calculateLifoCost,
//   //  calculateCostWithoutUnit, calculateAllAverageCost methods are identical
//   //  to the original — they contain pure business logic with no UI impact.
//   //  They are included here unchanged.]

//   Future<List<AverageCostResult>> calculateAllAverageCost({
//     required String companyGuid,
//     required String fromDate,
//     required String toDate,
//   }) async {
//     final stockItems = await fetchAllStockItems(companyGuid);
//     final directory  = await buildStockDirectoryWithBatch(companyGuid, toDate, stockItems);
//     List<AverageCostResult> results = [];
//     for (var stockItem in stockItems) {
//       final godownTxns = directory[stockItem.stockItemGuid]!;
//       if (stockItem.unit.toLowerCase().contains('not applicable')) {
//         results.add(await calculateCostWithoutUnit(stockItem: stockItem, godownTransactions: godownTxns, fromDate: fromDate, toDate: toDate, companyGuid: companyGuid));
//       } else if (stockItem.costingMethod.toLowerCase().contains('zero')) {
//         results.add(AverageCostResult(itemName: stockItem.itemName, stockItemGuid: stockItem.stockItemGuid, godowns: {}));
//       } else if (stockItem.costingMethod.toLowerCase().contains('fifo')) {
//         results.add(await calculateFifoCost(stockItem: stockItem, godownTransactions: godownTxns, fromDate: fromDate, toDate: toDate, companyGuid: companyGuid));
//       } else if (stockItem.costingMethod.toLowerCase().contains('lifo')) {
//         results.add(await calculateLifoCost(stockItem: stockItem, godownTransactions: godownTxns, fromDate: fromDate, toDate: toDate, companyGuid: companyGuid));
//       } else {
//         results.add(await calculateAvgCost(stockItem: stockItem, godownTransactions: godownTxns, fromDate: fromDate, toDate: toDate, companyGuid: companyGuid));
//       }
//     }
//     return results;
//   }

//   Future<AverageCostResult> calculateAvgCost({required StockItemInfo stockItem, required Map<String, Map<String, List<StockTransaction>>> godownTransactions, required String fromDate, required String toDate, required String companyGuid}) async {
//     Map<String, GodownAverageCost> godownResults = {};
//     Map<String, Map<String, BatchAccumulator>> godownBatchData = {};
//     const fyStartMonth = 4, fyStartDay = 1;
//     String getFyStart(String d) { final y = int.parse(d.substring(0,4)); final m = int.parse(d.substring(4,6)); return m < fyStartMonth ? '${y-1}${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}' : '$y${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}'; }
//     List<StockTransaction> all = [];
//     for (var gm in godownTransactions.values) for (var bl in gm.values) all.addAll(bl);
//     all.sort((a,b) => a.voucherId.compareTo(b.voucherId));
//     Map<String, List<StockTransaction>> vb = {};
//     for (var t in all) vb.putIfAbsent(t.voucherGuid, () => []).add(t);
//     for (final od in stockItem.openingData) {
//       String gn = od.godownName.isEmpty ? 'Main Location' : od.godownName;
//       godownBatchData.putIfAbsent(gn, () => {});
//       final acc = godownBatchData[gn]!.putIfAbsent(od.batchName, () => BatchAccumulator());
//       acc.inwardQty += double.tryParse(od.actualQty) ?? 0.0;
//       acc.inwardValue += od.amount;
//     }
//     String curFy = ''; Set<String> processed = {};
//     for (var txn in all) {
//       final vg = txn.voucherGuid;
//       if (processed.contains(vg) || txn.voucherType.toLowerCase().contains('purchase order') || txn.voucherType.toLowerCase().contains('sales order')) continue;
//       processed.add(vg);
//       final d = txn.voucherDate; final vt = txn.voucherType;
//       if (d.compareTo(toDate) > 0) break;
//       final fyS = getFyStart(d);
//       if (fyS != curFy && curFy.isNotEmpty) {
//         for (var g in godownBatchData.keys) for (var bd in godownBatchData[g]!.values) {
//           final cq = bd.inwardQty - bd.outwardQty; final cr = bd.inwardQty > 0 ? bd.inwardValue / bd.inwardQty : 0.0;
//           bd.inwardQty = cq; bd.inwardValue = cq * cr; bd.outwardQty = 0.0;
//         }
//       }
//       curFy = fyS;
//       final isP = purchaseVoucherTypes.contains(vt); final isS = salesVoucherTypes.contains(vt);
//       final isCN = creditNoteVoucherTypes.contains(vt); final isDN = debitNoteVoucherTypes.contains(vt);
//       if (vt == 'Physical Stock') continue;
//       for (var bt in vb[vg]!) {
//         final g = bt.godownName; final bn = bt.batchName; final amt = bt.amount; final qty = bt.stock; final isIn = bt.isInward; final absA = amt.abs();
//         if (!bt.trackingNumber.toLowerCase().contains('not applicable') && (isP || isS || isDN || isCN)) continue;
//         if ((isCN || isDN) && qty == 0 && amt == 0) continue;
//         godownBatchData.putIfAbsent(g, () => {});
//         final bd = godownBatchData[g]!.putIfAbsent(bn, () => BatchAccumulator());
//         if (isIn) { if (isCN) bd.outwardQty -= qty; else { bd.inwardQty += qty; bd.inwardValue += absA; } }
//         else { if (isDN) { bd.inwardQty -= qty; bd.inwardValue -= absA; } else bd.outwardQty += qty; }
//       }
//     }
//     for (var g in godownBatchData.keys) {
//       double cq = 0, cv = 0;
//       for (var bd in godownBatchData[g]!.values) {
//         final q = bd.inwardQty - bd.outwardQty; final r = bd.inwardQty != 0 ? bd.inwardValue / bd.inwardQty : 0.0;
//         cq += q; cv += q * r;
//       }
//       godownResults[g] = GodownAverageCost(godownName: g, totalInwardQty: 0, totalInwardValue: 0, currentStockQty: cq, averageRate: 0, closingValue: cv);
//     }
//     return AverageCostResult(stockItemGuid: stockItem.stockItemGuid, itemName: stockItem.itemName, godowns: godownResults);
//   }

//   Future<AverageCostResult> calculateFifoCost({required StockItemInfo stockItem, required Map<String, Map<String, List<StockTransaction>>> godownTransactions, required String fromDate, required String toDate, required String companyGuid}) async {
//     // Full FIFO logic preserved — same as original
//     Map<String, GodownAverageCost> godownResults = {};
//     const fyStartMonth = 4, fyStartDay = 1;
//     String getFyStart(String d) { final y = int.parse(d.substring(0,4)); final m = int.parse(d.substring(4,6)); return m < fyStartMonth ? '${y-1}${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}' : '$y${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}'; }
//     Map<String, Map<String, double>> gbIQ = {}, gbOQ = {};
//     Map<String, Map<String, List<StockLot>>> gbL = {};
//     List<StockTransaction> all = [];
//     for (var gm in godownTransactions.values) for (var bl in gm.values) all.addAll(bl);
//     all.sort((a,b) => a.voucherId.compareTo(b.voucherId));
//     Map<String, List<StockTransaction>> vb = {};
//     for (var t in all) vb.putIfAbsent(t.voucherGuid, () => []).add(t);
//     for (final od in stockItem.openingData) {
//       String gn = od.godownName.isEmpty ? 'Main Location' : od.godownName;
//       final oq = double.tryParse(od.actualQty) ?? 0.0; final bn = od.batchName;
//       gbIQ.putIfAbsent(gn, () => {}); gbOQ.putIfAbsent(gn, () => {}); gbL.putIfAbsent(gn, () => {});
//       gbIQ[gn]!.putIfAbsent(bn, () => 0.0); gbOQ[gn]!.putIfAbsent(bn, () => 0.0); gbL[gn]!.putIfAbsent(bn, () => []);
//       gbIQ[gn]![bn] = gbIQ[gn]![bn]! + oq;
//       final r = od.amount / oq;
//       gbL[gn]![bn]!.add(StockLot(voucherGuid: 'OPENING_STOCK', voucherDate: fromDate, voucherNumber: 'Opening Balance', voucherType: 'Opening', qty: oq, amount: od.amount, rate: r, type: StockInOutType.inward));
//     }
//     double calcFifo(List<StockLot> lots, double cq) {
//       if (cq <= 0 || lots.isEmpty) return 0.0;
//       double cv = 0, rem = cq, lr = 0;
//       for (int i = lots.length - 1; i >= 0 && rem > 0; i--) {
//         final l = lots[i]; lr = l.rate;
//         if (l.qty == 0) cv += l.amount;
//         else if (l.qty <= rem) { cv += l.amount; rem -= l.qty; }
//         else { cv += rem * l.rate; rem = 0; }
//       }
//       if (rem > 0) cv += rem * lr;
//       if (cv == 0 && cq > 0) { final tq = lots.fold(0.0,(s,l)=>s+l.qty); final tv = lots.fold(0.0,(s,l)=>s+l.amount); if (tq>0) cv = cq*(tv/tq); }
//       return cv;
//     }
//     String curFy = ''; Set<String> processed = {};
//     for (var txn in all) {
//       final vg = txn.voucherGuid;
//       if (processed.contains(vg) || txn.voucherType.toLowerCase().contains('purchase order') || txn.voucherType.toLowerCase().contains('sales order')) continue;
//       processed.add(vg);
//       final d = txn.voucherDate; final vt = txn.voucherType;
//       if (d.compareTo(toDate) > 0) break;
//       final fyS = getFyStart(d);
//       if (fyS != curFy && curFy.isNotEmpty) {
//         for (var g in gbIQ.keys) {
//           for (var bn in gbIQ[g]!.keys.toList()) {
//             final iq = gbIQ[g]![bn]!; final oq = gbOQ[g]![bn] ?? 0.0; final csq = iq - oq; final lots = gbL[g]![bn] ?? [];
//             if (csq > 0) { final cv = calcFifo(lots, csq); gbIQ[g]![bn] = csq; gbOQ[g]![bn] = 0.0; gbL[g]![bn] = [StockLot(voucherGuid: 'FY_OPENING_$fyS', voucherDate: fyS, voucherNumber: 'FY Opening Balance', voucherType: 'Opening', qty: csq, amount: cv, rate: cv/csq, type: StockInOutType.inward)]; }
//             else if (csq < 0) { final tq = lots.fold(0.0,(s,l)=>s+l.qty); final tv = lots.fold(0.0,(s,l)=>s+l.amount); final cr = tq > 0 ? tv/tq : 0.0; gbIQ[g]![bn] = csq; gbOQ[g]![bn] = 0.0; gbL[g]![bn] = [StockLot(voucherGuid: 'FY_OPENING_$fyS', voucherDate: fyS, voucherNumber: 'FY Opening Balance', voucherType: 'Opening', qty: csq, amount: csq*cr, rate: cr, type: StockInOutType.inward)]; }
//             else { gbIQ[g]![bn] = 0.0; gbOQ[g]![bn] = 0.0; gbL[g]![bn] = []; }
//           }
//         }
//       }
//       curFy = fyS;
//       final isP = purchaseVoucherTypes.contains(vt); final isS = salesVoucherTypes.contains(vt);
//       final isCN = creditNoteVoucherTypes.contains(vt); final isDN = debitNoteVoucherTypes.contains(vt);
//       if (vt == 'Physical Stock') continue;
//       for (var bt in vb[vg]!) {
//         final g = bt.godownName; final bn = bt.batchName; final amt = bt.amount; final qty = bt.stock; final isIn = bt.isInward; final absA = amt.abs();
//         if (!bt.trackingNumber.toLowerCase().contains('not applicable') && (isP || isS || isDN || isCN)) continue;
//         if ((isCN || isDN) && qty == 0 && amt == 0) continue;
//         gbIQ.putIfAbsent(g, () => {}); gbOQ.putIfAbsent(g, () => {}); gbL.putIfAbsent(g, () => {});
//         gbIQ[g]!.putIfAbsent(bn, () => 0.0); gbOQ[g]!.putIfAbsent(bn, () => 0.0); gbL[g]!.putIfAbsent(bn, () => []);
//         if (isIn) { if (isCN) gbOQ[g]![bn] = gbOQ[g]![bn]! - qty; else { gbIQ[g]![bn] = gbIQ[g]![bn]! + qty; final r = qty > 0 ? absA/qty : 0.0; gbL[g]![bn]!.add(StockLot(voucherGuid: vg, voucherDate: d, voucherNumber: txn.voucherNumber, voucherType: vt, qty: qty, amount: absA, rate: r, type: StockInOutType.inward)); } }
//         else { if (isDN) { gbIQ[g]![bn] = gbIQ[g]![bn]! - qty; final r = qty > 0 ? absA/qty : 0.0; gbL[g]![bn]!.add(StockLot(voucherGuid: vg, voucherDate: d, voucherNumber: txn.voucherNumber, voucherType: vt, qty: qty*-1, amount: amt*-1, rate: r, type: StockInOutType.inward)); } else gbOQ[g]![bn] = gbOQ[g]![bn]! + qty; }
//       }
//     }
//     for (var g in gbIQ.keys) {
//       double tcq = 0, tcv = 0;
//       for (var bn in gbIQ[g]!.keys) {
//         final iq = gbIQ[g]![bn]!; final oq = gbOQ[g]![bn] ?? 0.0; final csq = iq - oq; final lots = gbL[g]![bn] ?? [];
//         double bcv = 0;
//         if (csq > 0) bcv = calcFifo(lots, csq);
//         else if (csq < 0) { final tq = lots.fold(0.0,(s,l)=>s+l.qty); final tv = lots.fold(0.0,(s,l)=>s+l.amount); final cr = tq==0?0.0:tv/tq; bcv = csq*cr; }
//         tcq += csq; tcv += bcv;
//       }
//       godownResults[g] = GodownAverageCost(godownName: g, totalInwardQty: 0, totalInwardValue: 0, currentStockQty: tcq, averageRate: tcq>0?tcv/tcq:0.0, closingValue: tcv);
//     }
//     return AverageCostResult(stockItemGuid: stockItem.stockItemGuid, itemName: stockItem.itemName, godowns: godownResults);
//   }

//   Future<AverageCostResult> calculateLifoCost({required StockItemInfo stockItem, required Map<String, Map<String, List<StockTransaction>>> godownTransactions, required String fromDate, required String toDate, required String companyGuid}) async {
//     // Same as calculateFifoCost but with LIFO traversal — preserved from original
//     Map<String, GodownAverageCost> godownResults = {};
//     const fyStartMonth = 4, fyStartDay = 1;
//     String getFyStart(String d) { final y = int.parse(d.substring(0,4)); final m = int.parse(d.substring(4,6)); return m < fyStartMonth ? '${y-1}${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}' : '$y${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}'; }
//     Map<String, Map<String, double>> gbIQ = {}, gbOQ = {};
//     Map<String, Map<String, List<StockLot>>> gbL = {};
//     List<StockTransaction> all = [];
//     for (var gm in godownTransactions.values) for (var bl in gm.values) all.addAll(bl);
//     all.sort((a,b) => a.voucherId.compareTo(b.voucherId));
//     Map<String, List<StockTransaction>> vb = {};
//     for (var t in all) vb.putIfAbsent(t.voucherGuid, () => []).add(t);
//     for (final od in stockItem.openingData) {
//       String gn = od.godownName.isEmpty ? 'Main Location' : od.godownName;
//       final oq = double.tryParse(od.actualQty) ?? 0.0; final bn = od.batchName;
//       gbIQ.putIfAbsent(gn, () => {}); gbOQ.putIfAbsent(gn, () => {}); gbL.putIfAbsent(gn, () => {});
//       gbIQ[gn]!.putIfAbsent(bn, () => 0.0); gbOQ[gn]!.putIfAbsent(bn, () => 0.0); gbL[gn]!.putIfAbsent(bn, () => []);
//       gbIQ[gn]![bn] = gbIQ[gn]![bn]! + oq;
//       if (oq > 0) gbL[gn]![bn]!.add(StockLot(voucherGuid: 'OPENING_STOCK', voucherDate: fromDate, voucherNumber: 'Opening Balance', voucherType: 'Opening', qty: oq, amount: od.amount, rate: od.amount/oq, type: StockInOutType.inward));
//     }
//     double calcLifo(List<StockLot> lots, double cq) {
//       if (cq <= 0 || lots.isEmpty) { if (lots.isNotEmpty) return cq * lots.last.rate; return 0.0; }
//       double cv = 0, rem = cq, tempOut = 0, lr = 0;
//       for (int i = lots.length - 1; i >= 0 && rem > 0; i--) {
//         final l = lots[i]; lr = l.rate;
//         if (l.type == StockInOutType.outward) { tempOut += l.qty; }
//         else { if (l.qty == 0) { cv += l.amount; } else if (tempOut <= 0) { if (l.qty <= rem) { cv += l.amount; rem -= l.qty; } else { cv += rem*l.rate; rem=0; } } else { if (l.qty <= tempOut) { tempOut -= l.qty; } else { final tq = l.qty - tempOut; tempOut = 0; if (tq <= rem) { cv += tq*l.rate; rem -= tq; } else { cv += rem*l.rate; rem=0; } } } }
//       }
//       if (rem > 0) cv += rem * lr;
//       if (cv == 0 && cq > 0) { final tq = lots.fold(0.0,(s,l)=>s+l.qty); final tv = lots.fold(0.0,(s,l)=>s+l.amount); if (tq>0) cv = cq*(tv/tq); }
//       return cv;
//     }
//     String curFy = ''; Set<String> processed = {};
//     for (var txn in all) {
//       final vg = txn.voucherGuid;
//       if (processed.contains(vg) || txn.voucherType.toLowerCase().contains('purchase order') || txn.voucherType.toLowerCase().contains('sales order')) continue;
//       processed.add(vg);
//       final d = txn.voucherDate; final vt = txn.voucherType;
//       if (d.compareTo(toDate) > 0) break;
//       final fyS = getFyStart(d);
//       if (fyS != curFy && curFy.isNotEmpty) {
//         for (var g in gbIQ.keys) for (var bn in gbIQ[g]!.keys.toList()) {
//           final iq=gbIQ[g]![bn]!; final oq=gbOQ[g]![bn]??0.0; final csq=iq-oq; final lots=gbL[g]![bn]??[];
//           if (csq>0) { final cv=calcLifo(lots,csq); gbIQ[g]![bn]=csq; gbOQ[g]![bn]=0.0; gbL[g]![bn]=[StockLot(voucherGuid:'FY_OPENING_$fyS',voucherDate:fyS,voucherNumber:'FY Opening Balance',voucherType:'Opening',qty:csq,amount:cv,rate:cv/csq,type:StockInOutType.inward)]; }
//           else if (csq<0) { double tv=0,tq=0; for(var l in lots){if(l.type==StockInOutType.inward){tv+=l.amount;tq+=l.qty;}} final cr=tq>0?tv/tq:0.0; gbIQ[g]![bn]=csq; gbOQ[g]![bn]=0.0; gbL[g]![bn]=[StockLot(voucherGuid:'FY_OPENING_$fyS',voucherDate:fyS,voucherNumber:'FY Opening Balance',voucherType:'Opening',qty:csq,amount:csq*cr,rate:cr,type:StockInOutType.inward)]; }
//           else { gbIQ[g]![bn]=0.0; gbOQ[g]![bn]=0.0; gbL[g]![bn]=[]; }
//         }
//       }
//       curFy = fyS;
//       final isCN=creditNoteVoucherTypes.contains(vt); final isDN=debitNoteVoucherTypes.contains(vt);
//       final isP=purchaseVoucherTypes.contains(vt); final isS=salesVoucherTypes.contains(vt);
//       if (vt=='Physical Stock') continue;
//       for (var bt in vb[vg]!) {
//         final g=bt.godownName; final bn=bt.batchName; final amt=bt.amount; final qty=bt.stock; final isIn=bt.isInward; final absA=amt.abs();
//         if (!bt.trackingNumber.toLowerCase().contains('not applicable') && (isP||isS||isDN||isCN)) continue;
//         if ((isCN||isDN)&&qty==0&&amt==0) continue;
//         gbIQ.putIfAbsent(g,()=>{}); gbOQ.putIfAbsent(g,()=>{}); gbL.putIfAbsent(g,()=>{});
//         gbIQ[g]!.putIfAbsent(bn,()=>0.0); gbOQ[g]!.putIfAbsent(bn,()=>0.0); gbL[g]!.putIfAbsent(bn,()=>[]);
//         if (isIn) { if (isCN) { gbOQ[g]![bn]=gbOQ[g]![bn]!-qty; final r=qty>0?absA/qty:0.0; gbL[g]![bn]!.add(StockLot(voucherGuid:vg,voucherDate:d,voucherNumber:txn.voucherNumber,voucherType:vt,qty:qty*-1,amount:amt*-1,rate:r,type:StockInOutType.outward)); } else { gbIQ[g]![bn]=gbIQ[g]![bn]!+qty; final r=qty>0?absA/qty:0.0; gbL[g]![bn]!.add(StockLot(voucherGuid:vg,voucherDate:d,voucherNumber:txn.voucherNumber,voucherType:vt,qty:qty,amount:absA,rate:r,type:StockInOutType.inward)); } }
//         else { if (isDN) { gbIQ[g]![bn]=gbIQ[g]![bn]!-qty; final r=qty>0?absA/qty:0.0; gbL[g]![bn]!.add(StockLot(voucherGuid:vg,voucherDate:d,voucherNumber:txn.voucherNumber,voucherType:vt,qty:qty*-1,amount:amt*-1,rate:r,type:StockInOutType.inward)); } else { gbOQ[g]![bn]=gbOQ[g]![bn]!+qty; final r=qty>0?absA/qty:0.0; gbL[g]![bn]!.add(StockLot(voucherGuid:vg,voucherDate:d,voucherNumber:txn.voucherNumber,voucherType:vt,qty:qty,amount:absA,rate:r,type:StockInOutType.outward)); } }
//       }
//     }
//     for (var g in gbIQ.keys) {
//       double tcq=0, tcv=0;
//       for (var bn in gbIQ[g]!.keys) {
//         final iq=gbIQ[g]![bn]!; final oq=gbOQ[g]![bn]??0.0; final csq=iq-oq; final lots=gbL[g]![bn]??[];
//         double bcv=0;
//         if (csq>0) bcv=calcLifo(lots,csq);
//         else if (csq<0) { double tv=0,tq=0; for(var l in lots){if(l.type==StockInOutType.inward){tv+=l.amount;tq+=l.qty;}} final cr=tq==0?0.0:tv/tq; bcv=csq*cr; }
//         tcq+=csq; tcv+=bcv;
//       }
//       godownResults[g]=GodownAverageCost(godownName:g,totalInwardQty:0,totalInwardValue:0,currentStockQty:tcq,averageRate:tcq>0?tcv/tcq:0.0,closingValue:tcv);
//     }
//     return AverageCostResult(stockItemGuid:stockItem.stockItemGuid,itemName:stockItem.itemName,godowns:godownResults);
//   }

//   Future<AverageCostResult> calculateCostWithoutUnit({required StockItemInfo stockItem, required Map<String, Map<String, List<StockTransaction>>> godownTransactions, required String fromDate, required String toDate, required String companyGuid}) async {
//     Map<String, GodownAverageCost> godownResults = {};
//     Map<String, Map<String, double>> gbIV = {}, gbOV = {};
//     List<StockTransaction> all = [];
//     for (var gm in godownTransactions.values) for (var bl in gm.values) all.addAll(bl);
//     all.sort((a,b) => a.voucherId.compareTo(b.voucherId));
//     Map<String, List<StockTransaction>> vb = {};
//     for (var t in all) vb.putIfAbsent(t.voucherGuid, () => []).add(t);
//     for (final od in stockItem.openingData) {
//       String gn = od.godownName.isEmpty ? 'Main Location' : od.godownName;
//       gbIV.putIfAbsent(gn, () => {}); gbOV.putIfAbsent(gn, () => {});
//       gbIV[gn]!.putIfAbsent(od.batchName, () => 0.0); gbOV[gn]!.putIfAbsent(od.batchName, () => 0.0);
//       gbIV[gn]![od.batchName] = gbIV[gn]![od.batchName]! + od.amount;
//     }
//     Set<String> processed = {};
//     for (var txn in all) {
//       final vg = txn.voucherGuid;
//       if (processed.contains(vg) || txn.voucherType.toLowerCase().contains('purchase order') || txn.voucherType.toLowerCase().contains('sales order')) continue;
//       processed.add(vg);
//       final d = txn.voucherDate; final vt = txn.voucherType;
//       if (d.compareTo(toDate) > 0) break;
//       if (vt == 'Physical Stock') continue;
//       final isCN = creditNoteVoucherTypes.contains(vt); final isDN = debitNoteVoucherTypes.contains(vt);
//       for (var bt in vb[vg]!) {
//         final g = bt.godownName; final bn = bt.batchName; final absA = bt.amount.abs(); final isIn = bt.isInward;
//         gbIV.putIfAbsent(g, () => {}); gbOV.putIfAbsent(g, () => {});
//         gbIV[g]!.putIfAbsent(bn, () => 0.0); gbOV[g]!.putIfAbsent(bn, () => 0.0);
//         if (isIn) { if (isCN) gbOV[g]![bn] = gbOV[g]![bn]! - absA; else gbIV[g]![bn] = gbIV[g]![bn]! + absA; }
//         else { if (isDN) gbIV[g]![bn] = gbIV[g]![bn]! - absA; else gbOV[g]![bn] = gbOV[g]![bn]! + absA; }
//       }
//     }
//     for (var g in gbIV.keys) {
//       double ti = 0, to = 0;
//       for (var bn in gbIV[g]!.keys) { ti += gbIV[g]![bn] ?? 0.0; to += gbOV[g]![bn] ?? 0.0; }
//       godownResults[g] = GodownAverageCost(godownName: g, totalInwardQty: 0, totalInwardValue: ti, currentStockQty: 0, averageRate: 0.0, closingValue: ti - to);
//     }
//     return AverageCostResult(stockItemGuid: stockItem.stockItemGuid, itemName: stockItem.itemName, godowns: godownResults);
//   }

//   // ── P&L query (unchanged logic) ────────────────────────────────────────────

//   Future<Map<String, dynamic>> _getProfitLossDetailed(
//       String companyGuid, DateTime fromDate, DateTime toDate) async {
//     final db = await _db.database;
//     final fromStr = dateToString(fromDate);
//     final toStr   = dateToString(toDate);

//     String groupTree(String seedField, String seedValue) => '''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name FROM groups
//         WHERE company_guid = ? AND $seedField = '$seedValue' AND is_deleted = 0
//         UNION ALL
//         SELECT g.group_guid, g.name FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ? AND g.is_deleted = 0
//       )
//     ''';

//     // Purchase
//     final purchResult = await db.rawQuery('''
//       ${groupTree('reserved_name','Purchase Accounts')}
//       SELECT SUM(debit_amount) as debit_total, SUM(credit_total2) as credit_total, SUM(net_amount) as net_purchase
//       FROM (
//         SELECT SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
//                SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total2,
//                (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
//         FROM vouchers v INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
//         INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//         INNER JOIN group_tree gt ON l.parent = gt.name
//         WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
//           AND v.date >= ? AND v.date <= ?
//         GROUP BY v.voucher_guid
//       ) t
//     ''', [companyGuid, companyGuid, companyGuid, fromStr, toStr]);

//     final netPurchase = (purchResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;

//     // Sales
//     final salesResult = await db.rawQuery('''
//       ${groupTree('reserved_name','Sales Accounts')}
//       SELECT SUM(CASE WHEN vle.is_deemed_positive=1 THEN ABS(vle.amount) ELSE 0 END) as credit_total,
//              SUM(CASE WHEN vle.is_deemed_positive=0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
//              SUM(CASE WHEN vle.is_deemed_positive=1 THEN ABS(vle.amount) ELSE -ABS(vle.amount) END) as net_sales
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent_guid = gt.group_guid
//       WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
//         AND v.date >= ? AND v.date <= ?
//     ''', [companyGuid, companyGuid, companyGuid, fromStr, toStr]);

//     final netSales = (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;

//     // Helper to fetch ledger group totals
//     Future<List<Map<String, dynamic>>> fetchGroup(String groupName) => db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name FROM groups
//         WHERE company_guid = ? AND name = '$groupName' AND is_deleted = 0
//         UNION ALL
//         SELECT g.group_guid, g.name FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ? AND g.is_deleted = 0
//       )
//       SELECT l.name as ledger_name, l.opening_balance,
//         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
//         COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
//         (l.opening_balance + COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
//          COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
//       FROM ledgers l INNER JOIN group_tree gt ON l.parent = gt.name
//       INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid AND v.company_guid = l.company_guid
//         AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
//         AND v.date >= ? AND v.date <= ?
//       WHERE l.company_guid = ? AND l.is_deleted = 0
//       GROUP BY l.name, l.opening_balance ORDER BY closing_balance DESC
//     ''', [companyGuid, companyGuid, fromStr, toStr, companyGuid]);

//     Future<List<Map<String, dynamic>>> fetchIncomeGroup(String groupName) => db.rawQuery('''
//       WITH RECURSIVE group_tree AS (
//         SELECT group_guid, name FROM groups
//         WHERE company_guid = ? AND name = '$groupName' AND is_deleted = 0
//         UNION ALL
//         SELECT g.group_guid, g.name FROM groups g
//         INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//         WHERE g.company_guid = ? AND g.is_deleted = 0
//       )
//       SELECT l.name as ledger_name, l.opening_balance,
//         COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
//         COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
//         (l.opening_balance +
//          COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
//          COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
//       FROM ledgers l INNER JOIN group_tree gt ON l.parent = gt.name
//       INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid AND v.company_guid = l.company_guid
//         AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
//         AND v.date >= ? AND v.date <= ?
//       WHERE l.company_guid = ? AND l.is_deleted = 0
//       GROUP BY l.name, l.opening_balance
//       HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
//       ORDER BY closing_balance DESC
//     ''', [companyGuid, companyGuid, fromStr, toStr, companyGuid]);

//     final directExpenses   = await fetchGroup('Direct Expenses');
//     final indirectExpenses = await fetchGroup('Indirect Expenses');
//     final directIncomes    = await fetchIncomeGroup('Direct Incomes');
//     final indirectIncomes  = await fetchIncomeGroup('Indirect Incomes');

//     double sum(List<Map<String, dynamic>> rows) =>
//         rows.fold(0.0, (s, r) => s + ((r['closing_balance'] as num?)?.toDouble() ?? 0.0));

//     final totalDE  = sum(directExpenses).abs();
//     final totalIE  = sum(indirectExpenses).abs();
//     final totalDI  = sum(directIncomes);
//     final totalII  = sum(indirectIncomes);

//     double totalClosingStock = 0.0;
//     double totalOpeningStock = 0.0;

//     if (!_isMaintainInventory) {
//       final closingResult = await db.rawQuery('''
//         WITH RECURSIVE stock_groups AS (
//           SELECT group_guid, name FROM groups
//           WHERE company_guid = ? AND (reserved_name='Stock-in-Hand' OR name='Stock-in-Hand') AND is_deleted=0
//           UNION ALL
//           SELECT g.group_guid, g.name FROM groups g
//           INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
//           WHERE g.company_guid = ? AND g.is_deleted = 0
//         ),
//         latest_balances AS (
//           SELECT lcb.ledger_guid, lcb.amount * -1 as closing_amount,
//                  ROW_NUMBER() OVER (PARTITION BY lcb.ledger_guid ORDER BY lcb.closing_date DESC) as rn
//           FROM ledger_closing_balances lcb
//           INNER JOIN ledgers l ON l.ledger_guid = lcb.ledger_guid
//           INNER JOIN stock_groups sg ON l.parent = sg.name
//           WHERE lcb.company_guid = ? AND lcb.closing_date <= ? AND l.is_deleted = 0
//         )
//         SELECT COALESCE(SUM(closing_amount), 0) as total_closing_stock FROM latest_balances WHERE rn = 1
//       ''', [companyGuid, companyGuid, companyGuid, toStr]);
//       totalClosingStock = (closingResult.first['total_closing_stock'] as num?)?.toDouble() ?? 0.0;

//       final prevDay = fromStr.compareTo(_companyStartDate) <= 0 ? _companyStartDate : getPreviousDate(fromStr);
//       final openingResult = await db.rawQuery('''
//         WITH RECURSIVE stock_groups AS (
//           SELECT group_guid, name FROM groups
//           WHERE company_guid = ? AND (reserved_name='Stock-in-Hand' OR name='Stock-in-Hand') AND is_deleted=0
//           UNION ALL
//           SELECT g.group_guid, g.name FROM groups g
//           INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
//           WHERE g.company_guid = ? AND g.is_deleted = 0
//         ),
//         latest_balances AS (
//           SELECT l.ledger_guid, COALESCE(lcb.amount, l.opening_balance) * -1 as opening_amount,
//                  ROW_NUMBER() OVER (PARTITION BY l.ledger_guid ORDER BY lcb.closing_date DESC NULLS LAST) as rn
//           FROM ledgers l INNER JOIN stock_groups sg ON l.parent = sg.name
//           LEFT JOIN ledger_closing_balances lcb ON lcb.ledger_guid = l.ledger_guid
//             AND lcb.company_guid = ? AND lcb.closing_date <= ?
//           WHERE l.company_guid = ? AND l.is_deleted = 0
//         )
//         SELECT COALESCE(SUM(opening_amount), 0) as total_opening_stock FROM latest_balances WHERE rn = 1
//       ''', [companyGuid, companyGuid, companyGuid, prevDay, companyGuid]);
//       totalOpeningStock = (openingResult.first['total_opening_stock'] as num?)?.toDouble() ?? 0.0;
//     }

//     final grossProfit = (netSales + totalDI + totalClosingStock) -
//         (totalOpeningStock + netPurchase + totalDE);
//     final netProfit = grossProfit + totalII - totalIE;

//     return {
//       'opening_stock': totalOpeningStock,
//       'purchase': netPurchase,
//       'direct_expenses': directExpenses,
//       'direct_expenses_total': totalDE,
//       'gross_profit': grossProfit,
//       'closing_stock': totalClosingStock,
//       'sales': netSales,
//       'indirect_expenses': indirectExpenses,
//       'indirect_expenses_total': totalIE,
//       'indirect_incomes': indirectIncomes,
//       'indirect_incomes_total': totalII,
//       'direct_incomes': directIncomes,
//       'direct_incomes_total': totalDI,
//       'net_profit': netProfit,
//     };
//   }

//   // ── Navigation ─────────────────────────────────────────────────────────────

//   void _navigateToGroup(String groupName) {
//     if (_companyGuid == null || _companyName == null) return;
//     Navigator.push(context, MaterialPageRoute(
//       builder: (_) => GroupDetailScreen(
//         companyGuid: _companyGuid!,
//         companyName: _companyName!,
//         groupName: groupName,
//         fromDate: dateToString(_fromDate),
//         toDate: dateToString(_toDate),
//       ),
//     ));
//   }

//   // ── Date selection ─────────────────────────────────────────────────────────

//   Future<void> _selectDateRange() async {
//     DateTime tempFrom = _fromDate;
//     DateTime tempTo   = _toDate;

//     await showDialog(
//       context: context,
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setDs) => Dialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//           child: Padding(
//             padding: const EdgeInsets.all(24),
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Title
//                   Row(children: [
//                     Container(padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
//                       child: const Icon(Icons.date_range_rounded, color: _primary, size: 20)),
//                     const SizedBox(width: 12),
//                     const Text('Select Period', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
//                   ]),
//                   const SizedBox(height: 20),

//                   // Quick filter chips
//                   const Text('Quick Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
//                   const SizedBox(height: 10),
//                   Wrap(spacing: 8, runSpacing: 8, children: [
//                     _qChip('This Month', () { final n = DateTime.now(); setDs(() { tempFrom = DateTime(n.year, n.month, 1); tempTo = DateTime(n.year, n.month+1, 0); }); }),
//                     _qChip('Last Month', () { final n = DateTime.now(); setDs(() { tempFrom = DateTime(n.year, n.month-1, 1); tempTo = DateTime(n.year, n.month, 0); }); }),
//                     _qChip('Q1', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 4, 1); tempTo = DateTime(y, 6, 30); }); }),
//                     _qChip('Q2', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 7, 1); tempTo = DateTime(y, 9, 30); }); }),
//                     _qChip('Q3', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 10, 1); tempTo = DateTime(y, 12, 31); }); }),
//                     _qChip('Q4', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y+1, 1, 1); tempTo = DateTime(y+1, 3, 31); }); }),
//                     _qChip('Full FY', () { setDs(() { tempFrom = getFyStartDate(DateTime.now()); tempTo = getFyEndDate(DateTime.now()); }); }),
//                   ]),

//                   const SizedBox(height: 22),
//                   const Text('Custom Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
//                   const SizedBox(height: 10),

//                   // From date
//                   _datePickerTile('From', tempFrom, () async {
//                     final p = await showDatePicker(context: ctx,
//                       initialDate: tempFrom, firstDate: DateTime(2000), lastDate: DateTime(2100),
//                       builder: (c,child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary)), child: child!));
//                     if (p != null) setDs(() => tempFrom = p);
//                   }),
//                   const SizedBox(height: 10),

//                   // To date
//                   _datePickerTile('To', tempTo, () async {
//                     final p = await showDatePicker(context: ctx,
//                       initialDate: tempTo, firstDate: DateTime(2000), lastDate: DateTime(2100),
//                       builder: (c,child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary)), child: child!));
//                     if (p != null) setDs(() => tempTo = p);
//                   }),

//                   const SizedBox(height: 22),
//                   Row(children: [
//                     Expanded(child: OutlinedButton(
//                       onPressed: () => Navigator.pop(ctx),
//                       style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary,
//                         side: BorderSide(color: Colors.grey.shade200),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
//                       child: const Text('Cancel'))),
//                     const SizedBox(width: 12),
//                     Expanded(child: ElevatedButton(
//                       onPressed: () {
//                         if (tempFrom.isAfter(tempTo)) {
//                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                             behavior: SnackBarBehavior.floating,
//                             backgroundColor: _debitCol,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                             content: const Text('From date must be before To date')));
//                           return;
//                         }
//                         setState(() { _fromDate = tempFrom; _toDate = tempTo; });
//                         Navigator.pop(ctx);
//                         _loadData();
//                       },
//                       style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
//                       child: const Text('Apply'))),
//                   ]),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _qChip(String label, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           color: _primary.withOpacity(0.07),
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: _primary.withOpacity(0.2)),
//         ),
//         child: Text(label,
//             style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
//       ),
//     );
//   }

//   Widget _datePickerTile(String label, DateTime date, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//         decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10),
//           border: Border.all(color: Colors.grey.shade200)),
//         child: Row(children: [
//           const Icon(Icons.calendar_today_rounded, size: 16, color: _primary),
//           const SizedBox(width: 10),
//           Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
//             const SizedBox(height: 2),
//             Text(_displayDate(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
//           ]),
//         ]),
//       ),
//     );
//   }

//   // ── Helpers ────────────────────────────────────────────────────────────────

//   String _displayDate(DateTime d) =>
//       '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';

//   String _formatDate(String d) {
//     if (d.length != 8) return d;
//     return '${d.substring(6)}-${d.substring(4,6)}-${d.substring(0,4)}';
//   }

//   String _fmt(double amount) {
//     final neg = amount < 0;
//     final f = amount.abs().toStringAsFixed(2).replaceAllMapped(
//         RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
//     return '${neg ? '-' : ''}₹$f';
//   }

//   double _calculateTotal() {
//     return (_plData?['opening_stock'] ?? 0.0) +
//         (_plData?['purchase'] ?? 0.0) +
//         (_plData?['direct_expenses_total'] ?? 0.0) +
//         (_plData?['indirect_expenses_total'] ?? 0.0) +
//         (_plData?['net_profit'] ?? 0.0);
//   }

//   // ── Build ──────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return Scaffold(
//         backgroundColor: _bg,
//         appBar: _buildAppBar(),
//         body: const Center(child: CircularProgressIndicator(color: _primary)),
//       );
//     }

//     final netProfit   = (_plData?['net_profit'] ?? 0.0) as double;
//     final grossProfit = (_plData?['gross_profit'] ?? 0.0) as double;
//     final isProfit    = netProfit >= 0;

//     return Scaffold(
//       backgroundColor: _bg,
//       appBar: _buildAppBar(),
//       body: FadeTransition(
//         opacity: _fadeAnim,
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
//           child: Column(
//             children: [
//               _buildHeaderBanner(netProfit, grossProfit, isProfit),
//               const SizedBox(height: 16),

//               // ── Trading Account (Gross Profit) ─────────────────────────
//               _buildSectionTitle('Trading Account'),
//               const SizedBox(height: 8),
//               _buildTwoColumnCard(
//                 leftChildren: [
//                   _plRow('Opening Stock', _plData?['opening_stock'] ?? 0.0,
//                       onTap: () => _navigateToGroup('Stock-in-Hand')),
//                   _plRow('Purchase Accounts', _plData?['purchase'] ?? 0.0,
//                       onTap: () => _navigateToGroup('Purchase Accounts')),
//                   _expandableGroup(
//                     label: 'Direct Expenses',
//                     total: _plData?['direct_expenses_total'] ?? 0.0,
//                     rows: _plData?['direct_expenses'] as List<Map<String,dynamic>>? ?? [],
//                     expanded: _showDirectExpDetail,
//                     onToggle: () => setState(() => _showDirectExpDetail = !_showDirectExpDetail),
//                     onGroupTap: () => _navigateToGroup('Direct Expenses'),
//                     isExpense: true,
//                   ),
//                 ],
//                 rightChildren: [
//                   _plRow('Sales Accounts', _plData?['sales'] ?? 0.0,
//                       onTap: () => _navigateToGroup('Sales Accounts')),
//                   _plRow('Closing Stock', _plData?['closing_stock'] ?? 0.0),
//                   _expandableGroup(
//                     label: 'Direct Incomes',
//                     total: _plData?['direct_incomes_total'] ?? 0.0,
//                     rows: _plData?['direct_incomes'] as List<Map<String,dynamic>>? ?? [],
//                     expanded: _showDirectIncDetail,
//                     onToggle: () => setState(() => _showDirectIncDetail = !_showDirectIncDetail),
//                     onGroupTap: () => _navigateToGroup('Direct Incomes'),
//                     isExpense: false,
//                   ),
//                 ],
//                 summaryLabel: 'Gross',
//                 summaryValue: grossProfit,
//               ),

//               const SizedBox(height: 16),

//               // ── P&L Account (Net Profit) ───────────────────────────────
//               _buildSectionTitle('Profit & Loss Account'),
//               const SizedBox(height: 8),
//               _buildTwoColumnCard(
//                 leftChildren: [
//                   _expandableGroup(
//                     label: 'Indirect Expenses',
//                     total: _plData?['indirect_expenses_total'] ?? 0.0,
//                     rows: _plData?['indirect_expenses'] as List<Map<String,dynamic>>? ?? [],
//                     expanded: _showIndirectExpDetail,
//                     onToggle: () => setState(() => _showIndirectExpDetail = !_showIndirectExpDetail),
//                     onGroupTap: () => _navigateToGroup('Indirect Expenses'),
//                     isExpense: true,
//                   ),
//                   _netProfitRow(netProfit, isProfit),
//                 ],
//                 rightChildren: [
//                   _grossTransferRow(grossProfit),
//                   _expandableGroup(
//                     label: 'Indirect Incomes',
//                     total: _plData?['indirect_incomes_total'] ?? 0.0,
//                     rows: _plData?['indirect_incomes'] as List<Map<String,dynamic>>? ?? [],
//                     expanded: _showIndirectIncDetail,
//                     onToggle: () => setState(() => _showIndirectIncDetail = !_showIndirectIncDetail),
//                     onGroupTap: () => _navigateToGroup('Indirect Incomes'),
//                     isExpense: false,
//                   ),
//                 ],
//                 summaryLabel: 'Net',
//                 summaryValue: netProfit,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   AppBar _buildAppBar() {
//     return AppBar(
//       backgroundColor: AppColors.surface,
//       elevation: 0,
//       surfaceTintColor: Colors.transparent,
//       leading: IconButton(
//         icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
//         onPressed: () => Navigator.pop(context),
//       ),
//       title: const Text('Profit & Loss A/c',
//           style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
//       actions: [
//         // Period pill — tap to change
//         GestureDetector(
//           onTap: _selectDateRange,
//           child: Container(
//             margin: const EdgeInsets.only(right: 8),
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             decoration: BoxDecoration(
//               color: _primary.withOpacity(0.08),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: _primary.withOpacity(0.2)),
//             ),
//             child: Row(children: [
//               const Icon(Icons.date_range_rounded, size: 14, color: _primary),
//               const SizedBox(width: 5),
//               Text(
//                 '${_displayDate(_fromDate)} → ${_displayDate(_toDate)}',
//                 style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primary),
//               ),
//             ]),
//           ),
//         ),
//         IconButton(
//           icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
//           onPressed: _loadData,
//         ),
//       ],
//       bottom: PreferredSize(
//         preferredSize: const Size.fromHeight(1),
//         child: Container(height: 1, color: Colors.grey.shade100),
//       ),
//     );
//   }

//   Widget _buildHeaderBanner(double netProfit, double grossProfit, bool isProfit) {
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: isProfit
//               ? [const Color(0xFF1B8A5A), const Color(0xFF0D5C3A)]
//               : [const Color(0xFFD32F2F), const Color(0xFF8B0000)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//       ),
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               Text(_companyName ?? '',
//                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
//               const SizedBox(height: 4),
//               Text(
//                 '${_formatDate(dateToString(_fromDate))} → ${_formatDate(dateToString(_toDate))}',
//                 style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
//               ),
//               const SizedBox(height: 12),
//               Row(children: [
//                 _bannerPill('Sales', _plData?['sales'] ?? 0.0, Colors.white.withOpacity(0.2)),
//                 const SizedBox(width: 8),
//                 _bannerPill('Purchase', _plData?['purchase'] ?? 0.0, Colors.white.withOpacity(0.2)),
//               ]),
//             ]),
//           ),
//           const SizedBox(width: 16),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(color: Colors.white.withOpacity(0.3)),
//             ),
//             child: Column(children: [
//               Text(isProfit ? 'Net Profit' : 'Net Loss',
//                   style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75))),
//               const SizedBox(height: 4),
//               Text(_fmt(netProfit.abs()),
//                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
//             ]),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _bannerPill(String label, double amount, Color bg) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
//       child: Text('$label: ${_fmt(amount)}',
//           style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Row(children: [
//         Container(width: 4, height: 18,
//           decoration: BoxDecoration(
//             gradient: const LinearGradient(colors: [_primary, _accent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
//             borderRadius: BorderRadius.circular(2)),
//         ),
//         const SizedBox(width: 10),
//         Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.2)),
//       ]),
//     );
//   }

//   Widget _buildTwoColumnCard({
//     required List<Widget> leftChildren,
//     required List<Widget> rightChildren,
//     required String summaryLabel,
//     required double summaryValue,
//   }) {
//     final isPos = summaryValue >= 0;
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,3))],
//       ),
//       child: Column(children: [
//         IntrinsicHeight(
//           child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
//             // Left
//             Expanded(child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 _colHeader('Debit Side'),
//                 ...leftChildren,
//               ],
//             )),
//             // Vertical divider
//             Container(width: 1, color: Colors.grey.shade100),
//             // Right
//             Expanded(child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 _colHeader('Credit Side'),
//                 ...rightChildren,
//               ],
//             )),
//           ]),
//         ),
//         // Summary footer
//         Container(
//           decoration: BoxDecoration(
//             color: isPos ? _netBg : _netLossBg,
//             borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
//             border: Border(top: BorderSide(color: (isPos ? _netC : _netLossC).withOpacity(0.2))),
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//             Text('$summaryLabel ${isPos ? 'Profit' : 'Loss'}',
//                 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
//                     color: isPos ? _netC : _netLossC)),
//             Text(_fmt(summaryValue.abs()),
//                 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
//                     color: isPos ? _netC : _netLossC)),
//           ]),
//         ),
//       ]),
//     );
//   }

//   Widget _colHeader(String label) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF0F3FA),
//         borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
//       ),
//       child: Text(label,
//           style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5)),
//     );
//   }

//   Widget _plRow(String label, double amount, {VoidCallback? onTap}) {
//     return InkWell(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//         child: Row(children: [
//           Expanded(child: Text(label,
//               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
//           if (onTap != null) Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey.shade300),
//           const SizedBox(width: 4),
//           Text(_fmt(amount),
//               style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
//         ]),
//       ),
//     );
//   }

//   Widget _expandableGroup({
//     required String label,
//     required double total,
//     required List<Map<String, dynamic>> rows,
//     required bool expanded,
//     required VoidCallback onToggle,
//     required VoidCallback onGroupTap,
//     required bool isExpense,
//   }) {
//     return Column(children: [
//       InkWell(
//         onTap: onToggle,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//           child: Row(children: [
//             GestureDetector(
//               onTap: onGroupTap,
//               child: const Icon(Icons.open_in_new_rounded, size: 13, color: _primary),
//             ),
//             const SizedBox(width: 6),
//             Expanded(child: Text(label,
//                 style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
//             Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
//                 size: 16, color: AppColors.textSecondary),
//             const SizedBox(width: 4),
//             Text(_fmt(total),
//                 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
//                     color: isExpense ? _debitCol : _creditCol)),
//           ]),
//         ),
//       ),
//       if (expanded) ...rows.map((r) {
//         final closing = (r['closing_balance'] as num?)?.toDouble() ?? 0.0;
//         return Padding(
//           padding: const EdgeInsets.only(left: 28, right: 12, bottom: 6),
//           child: Row(children: [
//             Expanded(child: Text(r['ledger_name'] as String? ?? '',
//                 style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
//                 maxLines: 1, overflow: TextOverflow.ellipsis)),
//             Text(_fmt(closing.abs()),
//                 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
//                     color: isExpense ? _debitCol : _creditCol)),
//           ]),
//         );
//       }).toList(),
//     ]);
//   }

//   Widget _grossTransferRow(double amount) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: _grossBg,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: _grossC.withOpacity(0.2)),
//       ),
//       child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//         Text('Gross Profit b/f',
//             style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grossC)),
//         Text(_fmt(amount),
//             style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grossC)),
//       ]),
//     );
//   }

//   Widget _netProfitRow(double amount, bool isProfit) {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: isProfit ? _netBg : _netLossBg,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: (isProfit ? _netC : _netLossC).withOpacity(0.2)),
//       ),
//       child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//         Text(isProfit ? 'Net Profit' : 'Net Loss',
//             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
//                 color: isProfit ? _netC : _netLossC)),
//         Text(_fmt(amount.abs()),
//             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
//                 color: isProfit ? _netC : _netLossC)),
//       ]),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import '../../models/data_model.dart';
// import '../../database/database_helper.dart';
// import '../../utils/date_utils.dart';
// import 'group_detail_screen.dart';
// import 'stock_summary_screen.dart';

// class ProfitLossScreen extends StatefulWidget {
//   @override
//   _ProfitLossScreenState createState() => _ProfitLossScreenState();
// }

// class _ProfitLossScreenState extends State<ProfitLossScreen> {
//   final _db = DatabaseHelper.instance;

//   String? _companyGuid;
//   String? _companyName;
//   String _companyStartDate = getCurrentFyStartDate();
//   bool _loading = true;
//   bool _isMaintainInventory = true;
//   List<String> debitNoteVoucherTypes = [];
//   List<String> creditNoteVoucherTypes = [];
//   List<String> stockJournalVoucherType = [];
//   List<String> physicalStockVoucherType = [];
//   List<String> receiptNoteVoucherTypes = [];
//   List<String> deliveryNoteVoucherTypes = [];
//   List<String> purchaseVoucherTypes = [];
//   List<String> salesVoucherTypes = [];


//   Map<String, dynamic>? _plData;
//   DateTime _fromDate = getFyStartDate(DateTime.now());  // Financial year start
//   DateTime _toDate = getFyEndDate(DateTime.now()); // Financial year end

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
//     _isMaintainInventory = (company['integrate_inventory'] as int) == 1;

//     _companyStartDate = (company['starting_from'] as String).replaceAll('-', '');


//     debitNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Debit Note');
//     creditNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Credit Note');
//     stockJournalVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Stock Journal');
//     physicalStockVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Physical Stock');
//     receiptNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Receipt Note');
//     deliveryNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Delivery Note');
//     purchaseVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Purchase');
//     salesVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Sales');

//     final plData = await _getProfitLossDetailed(_companyGuid!, _fromDate, _toDate);

//     setState(() {
//       _plData = plData;
//       _loading = false;
//     });
//   }

//   double getTotalClosingValue(List<AverageCostResult> results) {
//     double totalClosingValue = 0.0;

//     for (var result in results) {
//       for (var godown in result.godowns.values) {
//         totalClosingValue += godown.closingValue;
//       }
//     }
//     print(totalClosingValue);
//     return totalClosingValue;
//   }


// // ============================================================
// // GET ALL CHILD VOUCHER TYPES FOR CONTRA
// // ============================================================

// Future<List<String>> getAllChildVoucherTypes(String companyGuid, String voucherTypeName) async {
//   final db = await _db.database;

//   final result = await db.rawQuery('''
//     WITH RECURSIVE voucher_type_tree AS (
//       SELECT voucher_type_guid, name
//       FROM voucher_types
//       WHERE company_guid = ?
//         AND (name = ? OR reserved_name = ?)
//         AND is_deleted = 0
      
//       UNION ALL
      
//       SELECT vt.voucher_type_guid, vt.name
//       FROM voucher_types vt
//       INNER JOIN voucher_type_tree vtt ON vt.parent_guid = vtt.voucher_type_guid
//       WHERE vt.company_guid = ?
//         AND vt.is_deleted = 0
//         AND vt.voucher_type_guid != vt.parent_guid  -- Prevent self-referencing loop
//     )
//     SELECT name FROM voucher_type_tree ORDER BY name
//   ''', [companyGuid, voucherTypeName, voucherTypeName, companyGuid]);

//   return result.map((row) => row['name'] as String).toList();
// }

// Future<List<StockItemInfo>> fetchAllStockItems(String companyGuid) async {
//   final db = await _db.database;

//   // Fetch stock items that have opening batch allocations or at least one voucher
//     final stockItemResults = await db.rawQuery('''
//     SELECT 
//       si.name as item_name,
//       si.stock_item_guid,
//       COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
//       COALESCE(si.base_units, '') as unit,
//       COALESCE(si.parent, '') as parent_name
//     FROM stock_items si
//     WHERE si.company_guid = ?
//       AND si.is_deleted = 0
//       AND (
//         EXISTS (
//           SELECT 1 FROM stock_item_batch_allocation siba
//           WHERE siba.stock_item_guid = si.stock_item_guid
//         )
//         OR EXISTS (
//           SELECT 1 FROM voucher_inventory_entries vie
//           WHERE vie.stock_item_guid = si.stock_item_guid
//             AND vie.company_guid = si.company_guid
//         )
//       )
//   ''', [companyGuid]);

//   // Batch allocations only for matched stock items
//   final batchResults = await db.rawQuery('''
//     SELECT 
//       siba.stock_item_guid,
//       COALESCE(siba.godown_name, '') as godown_name,
//       COALESCE(siba.batch_name, '') as batch_name,
//       COALESCE(siba.opening_value, 0) as amount,
//       COALESCE(siba.opening_balance, '') as actual_qty,
//       COALESCE(siba.opening_balance, '') as billed_qty,
//       siba.opening_rate as batch_rate
//     FROM stock_item_batch_allocation siba
//     INNER JOIN stock_items si 
//       ON siba.stock_item_guid = si.stock_item_guid
//     WHERE si.company_guid = ?
//       AND si.is_deleted = 0
//   ''', [companyGuid]);

//   // Group batch allocations by stock_item_guid
//   final Map<String, List<BatchAllocation>> batchMap = {};

//   for (final row in batchResults) {
//     final stockItemGuid = row['stock_item_guid'] as String;
//     final batch = BatchAllocation(
//       godownName: row['godown_name'] as String,
//       trackingNumber: "Not Applicable",
//       batchName: row['batch_name'] as String,
//       amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
//       actualQty: row['actual_qty']?.toString() ?? '',
//       billedQty: row['billed_qty']?.toString() ?? '',
//       batchRate: (row['batch_rate'] as num?)?.toDouble(),
//     );

//     batchMap.putIfAbsent(stockItemGuid, () => []).add(batch);
//   }


//   return stockItemResults.map((row) {
//     final stockItemGuid = row['stock_item_guid'] as String;

//     final stockItem = StockItemInfo(
//       itemName: row['item_name'] as String,
//       stockItemGuid: stockItemGuid,
//       costingMethod: row['costing_method'] as String,
//       unit: row['unit'] as String,
//       parentName: row['parent_name'] as String,
//       closingRate: (row['closing_rate'] as num?)?.toDouble() ?? 0.0,
//       closingQty: (row['closing_balance'] as num?)?.toDouble() ?? 0.0,
//       closingValue: (row['closing_value'] as num?)?.toDouble() ?? 0.0,
//       openingData: batchMap[stockItemGuid] ?? [],
//     );

//     print('${stockItem.itemName}, ${stockItem.costingMethod}, ${stockItem.closingRate}, ${stockItem.closingQty}, ${stockItem.closingValue}');

//     return stockItem;
//   }).toList();
// }
//   Future<List<StockTransaction>> fetchTransactionsForStockItem(
//     String companyGuid,
//     String stockItemGuid,
//     String endDate,
//   ) async {
//     final db = await _db.database;

//     final results = await db.rawQuery('''
//     SELECT 
//       v.voucher_guid,
//       v.voucher_key as voucher_id,
//       v.date as voucher_date,
//       v.voucher_number,
//       vba.godown_name,
//       v.voucher_type,
//       vba.actual_qty as stock,
//       COALESCE(vba.batch_rate, 0) as rate,
//       vba.amount,
//       vba.is_deemed_positive as is_inward,
//       COALESCE(vba.batch_name, '') as batch_name,
//       COALESCE(vba.destination_godown_name, '') as destination_godown,
//       COALESCE(vba.tracking_number, 'Not Applicable') as tracking_number
//     FROM vouchers v
//     INNER JOIN voucher_batch_allocations vba 
//       ON vba.voucher_guid = v.voucher_guid
//     WHERE vba.stock_item_guid = ?
//       AND v.company_guid = ?
//       AND v.date <= ?
//       AND v.is_deleted = 0
//       AND v.is_cancelled = 0
//       AND v.is_optional = 0
//     ORDER BY v.date, v.master_id
//   ''', [stockItemGuid, companyGuid, endDate]);

//     return results.map((row) {
//       // Parse quantity from "960.000 Kgs" format
//       String stockStr = (row['stock'] as String?) ?? '0';
//       double stock = 0.0;
//       if (stockStr.isNotEmpty) {
//         final parts = stockStr.split(' ');
//         if (parts.isNotEmpty) {
//           stock = double.tryParse(parts[0]) ?? 0.0;
//         }
//       }

//       return StockTransaction(
//         voucherGuid: row['voucher_guid'] as String,
//         voucherId: (row['voucher_id'] as int?) ?? 0,
//         voucherDate: row['voucher_date'] as String,
//         voucherNumber: row['voucher_number'] as String,
//         godownName: (row['godown_name'] as String?) ?? 'Primary',
//         voucherType: row['voucher_type'] as String,
//         stock: stock,
//         rate: (row['rate'] as num?)?.toDouble() ?? 0.0,
//         amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
//         isInward: (row['is_inward'] as int) == 1,
//         batchName: row['batch_name'] as String,
//         destinationGodown: row['destination_godown'] as String,
//         trackingNumber: row['tracking_number'] as String,
//       );
//     }).toList();
//   }


//   Future<Map<String, Map<String, Map<String, List<StockTransaction>>>>>
//     buildStockDirectoryWithBatch(
//   String companyGuid,
//   String endDate,
//   List<StockItemInfo> stockItems,
// ) async {

//   Map<String, Map<String, Map<String, List<StockTransaction>>>> directory = {};

//   for (var item in stockItems) {
//     final transactions = await fetchTransactionsForStockItem(
//       companyGuid,
//       item.stockItemGuid,
//       endDate,
//     );

//     // Godown -> Batch -> Transactions
//     Map<String, Map<String, List<StockTransaction>>> godownTransactions = {};

//     for (var transaction in transactions) {

//       final godown = transaction.godownName;
//       final batch = transaction.batchName;

//       // Ensure godown exists
//       godownTransactions.putIfAbsent(godown, () => {});

//       // Ensure batch exists inside godown
//       godownTransactions[godown]!
//           .putIfAbsent(batch, () => []);

//       // Add transaction
//       godownTransactions[godown]![batch]!
//           .add(transaction);
//     }

//     directory[item.stockItemGuid] = godownTransactions;
//   }

//   return directory;
// }

// // ============================================
// // CALCULATE FOR ALL ITEMS
// // ============================================

//   Future<List<AverageCostResult>> calculateAllAverageCost({
//     required String companyGuid,
//     required String fromDate,
//     required String toDate,
//   }) async {
//     // Fetch all stock items
//     final stockItems = await fetchAllStockItems(companyGuid);

//     final directory = await buildStockDirectoryWithBatch(companyGuid, toDate, stockItems);

//     List<AverageCostResult> results = [];

//     for (var stockItem in stockItems) {

//       final godownTransactions = directory[stockItem.stockItemGuid]!;

//       if (stockItem.unit.toLowerCase().contains('not applicable')){
//       final result = await calculateCostWithoutUnit(
//               stockItem: stockItem,
//               godownTransactions: godownTransactions,
//               fromDate: fromDate,
//               toDate: toDate,
//               companyGuid: companyGuid);

//           for (final entry in result.godowns.entries) {
//             print(
//                 '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
//           }
//           results.add(result);

//       }else if (stockItem.costingMethod.toLowerCase().contains('zero')){
//         final result = AverageCostResult(itemName: stockItem.itemName, stockItemGuid: stockItem.stockItemGuid, godowns: {});
//             print('${result.itemName}= ${stockItem.costingMethod}, godownName, 0, 0, 0');
//           results.add(result);
//       }else if (stockItem.costingMethod.toLowerCase().contains('fifo')){
//         final result = await calculateFifoCost(
//               stockItem: stockItem,
//               godownTransactions: godownTransactions,
//               fromDate: fromDate,
//               toDate: toDate,
//               companyGuid: companyGuid);

//           for (final entry in result.godowns.entries) {
//             print(
//                 '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
//           }
//           results.add(result);
//       }else if (stockItem.costingMethod.toLowerCase().contains('lifo')){
//         final result = await calculateLifoCost(
//               stockItem: stockItem,
//               godownTransactions: godownTransactions,
//               fromDate: fromDate,
//               toDate: toDate,
//               companyGuid: companyGuid);

//           for (final entry in result.godowns.entries) {
//             print(
//                 '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
//           }
//           results.add(result);
//       }else{
//         final result = await calculateAvgCost(
//                     stockItem: stockItem,
//                     godownTransactions: godownTransactions,
//                     fromDate: fromDate,
//                     toDate: toDate,
//                     companyGuid: companyGuid);

//           for (final entry in result.godowns.entries) {
//             print(
//                 '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
//           }
//           results.add(result);
//       }

//     }

//     return results;
//   }

//   Future<AverageCostResult> calculateLifoCost({
//   required StockItemInfo stockItem,
//   required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
//   required String fromDate,
//   required String toDate,
//   required String companyGuid,
// }) async {
//   Map<String, GodownAverageCost> godownResults = {};

//   const financialYearStartMonth = 4;
//   const financialYearStartDay = 1;

//   String getFinancialYearStartDate(String dateStr) {
//     final year = int.parse(dateStr.substring(0, 4));
//     final month = int.parse(dateStr.substring(4, 6));

//     if (month < financialYearStartMonth) {
//       return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
//     } else {
//       return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
//     }
//   }

//   // 🔹 Godown → Batch → Lot tracking
//   Map<String, Map<String, double>> godownBatchInwardQty = {};
//   Map<String, Map<String, double>> godownBatchOutwardQty = {};
//   Map<String, Map<String, List<StockLot>>> godownBatchLots = {};

//   // Flatten all transactions and sort by voucherId
//   List<StockTransaction> allTransactions = [];
//   for (var godownMap in godownTransactions.values) {
//     for (var batchList in godownMap.values) {
//       allTransactions.addAll(batchList);
//     }
//   }
//   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

//   // Group transactions by voucher_guid
//   Map<String, List<StockTransaction>> voucherBatches = {};
//   for (var txn in allTransactions) {
//     voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
//     voucherBatches[txn.voucherGuid]!.add(txn);
//   }

//   // 🔹 Opening Stock → Batch Level
//   for (final godownOpeningData in stockItem.openingData) {
//     String godownName = godownOpeningData.godownName;
//     if (godownName.isEmpty) {
//       godownName = 'Main Location';
//     }

//     final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
//     final openingAmount = godownOpeningData.amount;
//     final batchName = godownOpeningData.batchName;

//     godownBatchInwardQty.putIfAbsent(godownName, () => {});
//     godownBatchOutwardQty.putIfAbsent(godownName, () => {});
//     godownBatchLots.putIfAbsent(godownName, () => {});

//     godownBatchInwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
//     godownBatchOutwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
//     godownBatchLots[godownName]!.putIfAbsent(batchName, () => []);

//     godownBatchInwardQty[godownName]![batchName] =
//         godownBatchInwardQty[godownName]![batchName]! + openingQty;

//     if (openingQty > 0) {
//       final openingRate = openingAmount / openingQty;
//       godownBatchLots[godownName]![batchName]!.add(StockLot(
//         voucherGuid: 'OPENING_STOCK',
//         voucherDate: fromDate,
//         voucherNumber: 'Opening Balance',
//         voucherType: 'Opening',
//         qty: openingQty,
//         amount: openingAmount,
//         rate: openingRate,
//         type: StockInOutType.inward,
//       ));
//     }
//   }

//   String currentFyStart = '';

//   // LIFO closing value helper
//   double calculateLifoClosingValue(List<StockLot> lots, double closingStockQty) {
//     if (closingStockQty <= 0 || lots.isEmpty) {
//       if (lots.isNotEmpty) {
//         return closingStockQty * lots.last.rate;
//       }
//       return 0.0;
//     }

//     double closingValue = 0.0;
//     double remainingQty = closingStockQty;
//     double tempOutWardQty = 0.0;
//     double lastRate = 0.0;

//     for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
//       final lot = lots[i];
//       lastRate = lot.rate;
//       if (lot.type == StockInOutType.outward) {
//         tempOutWardQty += lot.qty;
//       } else {
//         if (lot.qty == 0) {
//           closingValue += lot.amount;
//         } else if (tempOutWardQty <= 0) {
//           if (lot.qty <= remainingQty) {
//             closingValue += lot.amount;
//             remainingQty -= lot.qty;
//           } else {
//             closingValue += remainingQty * lot.rate;
//             remainingQty = 0;
//           }
//         } else {
//           if (lot.qty <= tempOutWardQty) {
//             tempOutWardQty -= lot.qty;
//           } else {
//             final tempLotQty = lot.qty - tempOutWardQty;
//             tempOutWardQty = 0;

//             if (tempLotQty <= remainingQty) {
//               closingValue += (tempLotQty * lot.rate);
//               remainingQty -= tempLotQty;
//             } else {
//               closingValue += remainingQty * lot.rate;
//               remainingQty = 0;
//             }
//           }
//         }
//       }
//     }

//     if (remainingQty > 0) {
//       closingValue += remainingQty * lastRate;
//     }

//     if (closingValue == 0 && closingStockQty > 0) {
//       final totalQty = lots.fold(0.0, (sum, lot) => sum + lot.qty);
//       final totalValue = lots.fold(0.0, (sum, lot) => sum + lot.amount);
//       if (totalQty > 0) {
//         closingValue = closingStockQty * (totalValue / totalQty);
//       }
//     }

//     return closingValue;
//   }

//   Set<String> processedVouchers = {};

//   for (var txn in allTransactions) {
//     final voucherGuid = txn.voucherGuid;

//     if (processedVouchers.contains(voucherGuid) ||
//         txn.voucherType.toLowerCase().contains('purchase order') ||
//         txn.voucherType.toLowerCase().contains('sales order')) {
//       continue;
//     }

//     processedVouchers.add(voucherGuid);

//     final dateStr = txn.voucherDate;
//     final voucherType = txn.voucherType;
//     final voucherNumber = txn.voucherNumber;

//     if (dateStr.compareTo(toDate) > 0) {
//       break;
//     }

//     final txnFyStart = getFinancialYearStartDate(dateStr);

//     // 🔹 FY Boundary Reset (Batch Wise)
//     if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
//       for (var godown in godownBatchInwardQty.keys) {
//         final batchKeys = godownBatchInwardQty[godown]!.keys.toList();
//         for (var batchName in batchKeys) {
//           final inwardQty = godownBatchInwardQty[godown]![batchName]!;
//           final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
//           final closingStockQty = inwardQty - outwardQty;
//           final lots = godownBatchLots[godown]![batchName] ?? [];

//           if (closingStockQty > 0) {
//             final closingValue = calculateLifoClosingValue(lots, closingStockQty);
//             final closingRate = closingValue / closingStockQty;

//             godownBatchInwardQty[godown]![batchName] = closingStockQty;
//             godownBatchOutwardQty[godown]![batchName] = 0.0;
//             godownBatchLots[godown]![batchName] = [
//               StockLot(
//                 voucherGuid: 'FY_OPENING_$txnFyStart',
//                 voucherDate: txnFyStart,
//                 voucherNumber: 'FY Opening Balance',
//                 voucherType: 'Opening',
//                 qty: closingStockQty,
//                 amount: closingValue,
//                 rate: closingRate,
//                 type: StockInOutType.inward,
//               )
//             ];
//           } else if (closingStockQty < 0) {
//             // Negative stock: fallback to Average Cost
//             double totalLotValue = 0.0;
//             double totalLotQty = 0.0;
//             for (var lot in lots) {
//               if (lot.type == StockInOutType.inward) {
//                 totalLotValue += lot.amount;
//                 totalLotQty += lot.qty;
//               }
//             }
//             final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
//             final closingValue = closingStockQty * closingRate;

//             godownBatchInwardQty[godown]![batchName] = closingStockQty;
//             godownBatchOutwardQty[godown]![batchName] = 0.0;
//             godownBatchLots[godown]![batchName] = [
//               StockLot(
//                 voucherGuid: 'FY_OPENING_$txnFyStart',
//                 voucherDate: txnFyStart,
//                 voucherNumber: 'FY Opening Balance',
//                 voucherType: 'Opening',
//                 qty: closingStockQty,
//                 amount: closingValue,
//                 rate: closingRate,
//                 type: StockInOutType.inward,
//               )
//             ];
//           } else {
//             godownBatchInwardQty[godown]![batchName] = 0.0;
//             godownBatchOutwardQty[godown]![batchName] = 0.0;
//             godownBatchLots[godown]![batchName] = [];
//           }
//         }
//       }
//     }

//     currentFyStart = txnFyStart;

//     final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
//     final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
//     final isPurchase = purchaseVoucherTypes.contains(voucherType);
//     final isSales = salesVoucherTypes.contains(voucherType);

//     if (voucherType == 'Physical Stock') continue;

//     final batches = voucherBatches[voucherGuid]!;

//     for (var batchTxn in batches) {
//       final godown = batchTxn.godownName;
//       final batchName = batchTxn.batchName;
//       final amount = batchTxn.amount;
//       final qty = batchTxn.stock;
//       final isInward = batchTxn.isInward;
//       final absAmount = amount.abs();

//       if (batchTxn.trackingNumber.toLowerCase().contains('not applicable') == false &&
//           (isPurchase || isSales || isDebitNote || isCreditNote)) {
//         continue;
//       }

//       if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
//         continue;
//       }

//       // Initialize batch if not exists
//       godownBatchInwardQty.putIfAbsent(godown, () => {});
//       godownBatchOutwardQty.putIfAbsent(godown, () => {});
//       godownBatchLots.putIfAbsent(godown, () => {});

//       godownBatchInwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
//       godownBatchOutwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
//       godownBatchLots[godown]!.putIfAbsent(batchName, () => []);

//       if (isInward) {
//         if (isCreditNote) {
//           godownBatchOutwardQty[godown]![batchName] =
//               godownBatchOutwardQty[godown]![batchName]! - qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           godownBatchLots[godown]![batchName]!.add(StockLot(
//             voucherGuid: voucherGuid,
//             voucherDate: dateStr,
//             voucherNumber: voucherNumber,
//             voucherType: voucherType,
//             qty: qty * -1,
//             amount: amount * -1,
//             rate: rate,
//             type: StockInOutType.outward,
//           ));
//         } else {
//           godownBatchInwardQty[godown]![batchName] =
//               godownBatchInwardQty[godown]![batchName]! + qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           godownBatchLots[godown]![batchName]!.add(StockLot(
//             voucherGuid: voucherGuid,
//             voucherDate: dateStr,
//             voucherNumber: voucherNumber,
//             voucherType: voucherType,
//             qty: qty,
//             amount: absAmount,
//             rate: rate,
//             type: StockInOutType.inward,
//           ));
//         }
//       } else {
//         if (isDebitNote) {
//           godownBatchInwardQty[godown]![batchName] =
//               godownBatchInwardQty[godown]![batchName]! - qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           godownBatchLots[godown]![batchName]!.add(StockLot(
//             voucherGuid: voucherGuid,
//             voucherDate: dateStr,
//             voucherNumber: voucherNumber,
//             voucherType: voucherType,
//             qty: qty * -1,
//             amount: amount * -1,
//             rate: rate,
//             type: StockInOutType.inward,
//           ));
//         } else {
//           godownBatchOutwardQty[godown]![batchName] =
//               godownBatchOutwardQty[godown]![batchName]! + qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           godownBatchLots[godown]![batchName]!.add(StockLot(
//             voucherGuid: voucherGuid,
//             voucherDate: dateStr,
//             voucherNumber: voucherNumber,
//             voucherType: voucherType,
//             qty: qty,
//             amount: absAmount,
//             rate: rate,
//             type: StockInOutType.outward,
//           ));
//         }
//       }
//     }
//   }

//   // 🔹 Final: Batch → Godown Merge (LIFO closing per batch, then sum)
//   for (var godown in godownBatchInwardQty.keys) {
//     double totalClosingQty = 0.0;
//     double totalClosingValue = 0.0;

//     final batchKeys = godownBatchInwardQty[godown]!.keys;
//     for (var batchName in batchKeys) {
//       final inwardQty = godownBatchInwardQty[godown]![batchName]!;
//       final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
//       final closingStockQty = inwardQty - outwardQty;
//       final lots = godownBatchLots[godown]![batchName] ?? [];

//       double batchClosingValue = 0.0;

//       if (closingStockQty > 0) {
//         batchClosingValue = calculateLifoClosingValue(lots, closingStockQty);
//       } else if (closingStockQty < 0) {
//         // Negative stock: Average Cost fallback
//         double totalLotValue = 0.0;
//         double totalLotQty = 0.0;
//         for (var lot in lots) {
//           if (lot.type == StockInOutType.inward) {
//             totalLotValue += lot.amount;
//             totalLotQty += lot.qty;
//           }
//         }
//         final closingRate = totalLotQty == 0 ? 0.0 : totalLotValue / totalLotQty ;
//         batchClosingValue = closingStockQty * closingRate;
//       }

//       totalClosingQty += closingStockQty;
//       totalClosingValue += batchClosingValue;
//     }

//     godownResults[godown] = GodownAverageCost(
//       godownName: godown,
//       totalInwardQty: 0,
//       totalInwardValue: 0,
//       currentStockQty: totalClosingQty,
//       averageRate: totalClosingQty > 0 ? totalClosingValue / totalClosingQty : 0.0,
//       closingValue: totalClosingValue,
//     );
//   }

//   return AverageCostResult(
//     stockItemGuid: stockItem.stockItemGuid,
//     itemName: stockItem.itemName,
//     godowns: godownResults,
//   );
// }

//   Future<AverageCostResult> calculateFifoCost({
//   required StockItemInfo stockItem,
//   required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
//   required String fromDate,
//   required String toDate,
//   required String companyGuid,
// }) async {
//   Map<String, GodownAverageCost> godownResults = {};

//   const financialYearStartMonth = 4;
//   const financialYearStartDay = 1;

//   String getFinancialYearStartDate(String dateStr) {
//     final year = int.parse(dateStr.substring(0, 4));
//     final month = int.parse(dateStr.substring(4, 6));

//     if (month < financialYearStartMonth) {
//       return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
//     } else {
//       return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
//     }
//   }

//   // 🔹 Godown → Batch → Lot tracking
//   Map<String, Map<String, double>> godownBatchInwardQty = {};
//   Map<String, Map<String, double>> godownBatchOutwardQty = {};
//   Map<String, Map<String, List<StockLot>>> godownBatchLots = {};

//   // Flatten all transactions and sort by voucherId
//   List<StockTransaction> allTransactions = [];
//   for (var godownMap in godownTransactions.values) {
//     for (var batchList in godownMap.values) {
//       allTransactions.addAll(batchList);
//     }
//   }
//   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

//   // Group transactions by voucher_guid
//   Map<String, List<StockTransaction>> voucherBatches = {};
//   for (var txn in allTransactions) {
//     voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
//     voucherBatches[txn.voucherGuid]!.add(txn);
//   }

//   // 🔹 Opening Stock → Batch Level
//   for (final godownOpeningData in stockItem.openingData) {
//     String godownName = godownOpeningData.godownName;
//     if (godownName.isEmpty) {
//       godownName = 'Main Location';
//     }

//     final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
//     final openingAmount = godownOpeningData.amount;
//     final batchName = godownOpeningData.batchName;

//     godownBatchInwardQty.putIfAbsent(godownName, () => {});
//     godownBatchOutwardQty.putIfAbsent(godownName, () => {});
//     godownBatchLots.putIfAbsent(godownName, () => {});

//     godownBatchInwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
//     godownBatchOutwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
//     godownBatchLots[godownName]!.putIfAbsent(batchName, () => []);

//     godownBatchInwardQty[godownName]![batchName] =
//         godownBatchInwardQty[godownName]![batchName]! + openingQty;

//     // if (openingQty > 0) {
//       final openingRate = openingAmount / openingQty;
//       godownBatchLots[godownName]![batchName]!.add(StockLot(
//         voucherGuid: 'OPENING_STOCK',
//         voucherDate: fromDate,
//         voucherNumber: 'Opening Balance',
//         voucherType: 'Opening',
//         qty: openingQty,
//         amount: openingAmount,
//         rate: openingRate,
//         type: StockInOutType.inward,
//       ));
//     // }
//   }

//   String currentFyStart = '';

//   // FIFO closing value helper (backwards from last lot = newest first)
//   double calculateFifoClosingValue(List<StockLot> lots, double closingStockQty) {
//     if (closingStockQty <= 0 || lots.isEmpty) {
//       return 0.0;
//     }

//     double closingValue = 0.0;
//     double remainingQty = closingStockQty;
//     double lastRate = 0.0;

//     for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
//       final lot = lots[i];
//       lastRate = lot.rate;

//       if (lot.qty == 0) {
//         closingValue += lot.amount;
//       } else if (lot.qty <= remainingQty) {
//         closingValue += lot.amount;
//         remainingQty -= lot.qty;
//       } else {
//         closingValue += remainingQty * lot.rate;
//         remainingQty = 0;
//       }
//     }

//     if (remainingQty > 0) {
//       closingValue += remainingQty * lastRate;
//     }

//     if (closingValue == 0 && closingStockQty > 0) {
//       final totalQty = lots.fold(0.0, (sum, lot) => sum + lot.qty);
//       final totalValue = lots.fold(0.0, (sum, lot) => sum + lot.amount);
//       if (totalQty > 0) {
//         closingValue = closingStockQty * (totalValue / totalQty);
//       }
//     }

//     return closingValue;
//   }

//   Set<String> processedVouchers = {};

//   for (var txn in allTransactions) {
//     final voucherGuid = txn.voucherGuid;

//     if (processedVouchers.contains(voucherGuid) ||
//         txn.voucherType.toLowerCase().contains('purchase order') ||
//         txn.voucherType.toLowerCase().contains('sales order')) {
//       continue;
//     }

//     processedVouchers.add(voucherGuid);

//     final dateStr = txn.voucherDate;
//     final voucherType = txn.voucherType;
//     final voucherNumber = txn.voucherNumber;

//     if (dateStr.compareTo(toDate) > 0) {
//       break;
//     }

//     final txnFyStart = getFinancialYearStartDate(dateStr);

//     // 🔹 FY Boundary Reset (Batch Wise)
//     if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
//       for (var godown in godownBatchInwardQty.keys) {
//         final batchKeys = godownBatchInwardQty[godown]!.keys.toList();
//         for (var batchName in batchKeys) {
//           final inwardQty = godownBatchInwardQty[godown]![batchName]!;
//           final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
//           final closingStockQty = inwardQty - outwardQty;
//           final lots = godownBatchLots[godown]![batchName] ?? [];

//           if (closingStockQty > 0) {
//             final closingValue = calculateFifoClosingValue(lots, closingStockQty);
//             final closingRate = closingValue / closingStockQty;

//             godownBatchInwardQty[godown]![batchName] = closingStockQty;
//             godownBatchOutwardQty[godown]![batchName] = 0.0;
//             godownBatchLots[godown]![batchName] = [
//               StockLot(
//                 voucherGuid: 'FY_OPENING_$txnFyStart',
//                 voucherDate: txnFyStart,
//                 voucherNumber: 'FY Opening Balance',
//                 voucherType: 'Opening',
//                 qty: closingStockQty,
//                 amount: closingValue,
//                 rate: closingRate,
//                 type: StockInOutType.inward,
//               )
//             ];
//           } else if (closingStockQty < 0) {
//             // Negative stock: fallback to Average Cost
//             double totalLotValue = 0.0;
//             double totalLotQty = 0.0;
//             for (var lot in lots) {
//               totalLotValue += lot.amount;
//               totalLotQty += lot.qty;
//             }
//             final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
//             final closingValue = closingStockQty * closingRate;

//             godownBatchInwardQty[godown]![batchName] = closingStockQty;
//             godownBatchOutwardQty[godown]![batchName] = 0.0;
//             godownBatchLots[godown]![batchName] = [
//               StockLot(
//                 voucherGuid: 'FY_OPENING_$txnFyStart',
//                 voucherDate: txnFyStart,
//                 voucherNumber: 'FY Opening Balance',
//                 voucherType: 'Opening',
//                 qty: closingStockQty,
//                 amount: closingValue,
//                 rate: closingRate,
//                 type: StockInOutType.inward,
//               )
//             ];
//           } else {
//             godownBatchInwardQty[godown]![batchName] = 0.0;
//             godownBatchOutwardQty[godown]![batchName] = 0.0;
//             godownBatchLots[godown]![batchName] = [];
//           }
//         }
//       }
//     }

//     currentFyStart = txnFyStart;

//     final isPurchase = purchaseVoucherTypes.contains(voucherType);
//     final isSales = salesVoucherTypes.contains(voucherType);
//     final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
//     final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

//     if (voucherType == 'Physical Stock') continue;

//     final batches = voucherBatches[voucherGuid]!;

//     for (var batchTxn in batches) {
//       final godown = batchTxn.godownName;
//       final batchName = batchTxn.batchName;
//       final amount = batchTxn.amount;
//       final qty = batchTxn.stock;
//       final isInward = batchTxn.isInward;
//       final absAmount = amount.abs();

//       if (batchTxn.trackingNumber.toLowerCase().contains('not applicable') == false &&
//           (isPurchase || isSales || isDebitNote || isCreditNote)) {
//         continue;
//       }

//       if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
//         continue;
//       }

//       // Initialize batch if not exists
//       godownBatchInwardQty.putIfAbsent(godown, () => {});
//       godownBatchOutwardQty.putIfAbsent(godown, () => {});
//       godownBatchLots.putIfAbsent(godown, () => {});

//       godownBatchInwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
//       godownBatchOutwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
//       godownBatchLots[godown]!.putIfAbsent(batchName, () => []);

//       if (isInward) {
//         if (isCreditNote) {
//           godownBatchOutwardQty[godown]![batchName] =
//               godownBatchOutwardQty[godown]![batchName]! - qty;
//         } else {
//           godownBatchInwardQty[godown]![batchName] =
//               godownBatchInwardQty[godown]![batchName]! + qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           godownBatchLots[godown]![batchName]!.add(StockLot(
//             voucherGuid: voucherGuid,
//             voucherDate: dateStr,
//             voucherNumber: voucherNumber,
//             voucherType: voucherType,
//             qty: qty,
//             amount: absAmount,
//             rate: rate,
//             type: StockInOutType.inward,
//           ));
//         }
//       } else {
//         if (isDebitNote) {
//           godownBatchInwardQty[godown]![batchName] =
//               godownBatchInwardQty[godown]![batchName]! - qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           godownBatchLots[godown]![batchName]!.add(StockLot(
//             voucherGuid: voucherGuid,
//             voucherDate: dateStr,
//             voucherNumber: voucherNumber,
//             voucherType: voucherType,
//             qty: qty * -1,
//             amount: amount * -1,
//             rate: rate,
//             type: StockInOutType.inward,
//           ));
//         } else {
//           godownBatchOutwardQty[godown]![batchName] =
//               godownBatchOutwardQty[godown]![batchName]! + qty;
//         }
//       }
//     }
//   }

//   // 🔹 Final: Batch → Godown Merge (FIFO closing per batch, then sum)
//   for (var godown in godownBatchInwardQty.keys) {
//     double totalClosingQty = 0.0;
//     double totalClosingValue = 0.0;

//     final batchKeys = godownBatchInwardQty[godown]!.keys;
//     for (var batchName in batchKeys) {
//       final inwardQty = godownBatchInwardQty[godown]![batchName]!;
//       final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
//       final closingStockQty = inwardQty - outwardQty;
//       final lots = godownBatchLots[godown]![batchName] ?? [];

//       double batchClosingValue = 0.0;

//       if (closingStockQty > 0) {
//         batchClosingValue = calculateFifoClosingValue(lots, closingStockQty);
//       } else if (closingStockQty < 0) {
//         // Negative stock: Average Cost fallback
//         double totalLotValue = 0.0;
//         double totalLotQty = 0.0;
//         for (var lot in lots) {
//           totalLotValue += lot.amount;
//           totalLotQty += lot.qty;
//         }
//         final closingRate = totalLotQty == 0 ? 0.0 : totalLotValue / totalLotQty;
//         batchClosingValue = closingStockQty * closingRate;
//       }

//       totalClosingQty += closingStockQty;
//       totalClosingValue += batchClosingValue;
//     }

//     godownResults[godown] = GodownAverageCost(
//       godownName: godown,
//       totalInwardQty: 0,
//       totalInwardValue: 0,
//       currentStockQty: totalClosingQty,
//       averageRate: totalClosingQty > 0 ? totalClosingValue / totalClosingQty : 0.0,
//       closingValue: totalClosingValue,
//     );
//   }

//   return AverageCostResult(
//     stockItemGuid: stockItem.stockItemGuid,
//     itemName: stockItem.itemName,
//     godowns: godownResults,
//   );
// }

// Future<AverageCostResult> calculateAvgCost({
//   required StockItemInfo stockItem,
//   required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
//   required String fromDate,
//   required String toDate,
//   required String companyGuid,
// }) async {

//   Map<String, GodownAverageCost> godownResults = {};

//   // 🔹 NEW: Godown → Batch → Accumulator
//   Map<String, Map<String, BatchAccumulator>> godownBatchData = {};

//   const financialYearStartMonth = 4;
//   const financialYearStartDay = 1;

//   String getFinancialYearStartDate(String dateStr) {
//     final year = int.parse(dateStr.substring(0, 4));
//     final month = int.parse(dateStr.substring(4, 6));

//     if (month < financialYearStartMonth) {
//       return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
//     } else {
//       return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
//     }
//   }

//   // 🔹 Flatten all transactions
//   List<StockTransaction> allTransactions = [];
//   for (var godownMap in godownTransactions.values) {
//     for (var batchList in godownMap.values) {
//       allTransactions.addAll(batchList);
//     }
//   }

//   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

//   // 🔹 Group by voucher_guid
//   Map<String, List<StockTransaction>> voucherBatches = {};
//   for (var txn in allTransactions) {
//     voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
//     voucherBatches[txn.voucherGuid]!.add(txn);
//   }


//   // 🔹 Opening Stock → Batch Level
//   for (final godownOpeningData in stockItem.openingData) {

//     String godownName = godownOpeningData.godownName;
//     if (godownName.isEmpty) {
//       godownName = 'Main Location';
//     }

//     final openingQty =
//         double.tryParse(godownOpeningData.actualQty) ?? 0.0;
//     final openingAmount = godownOpeningData.amount;
//     final batchName =
//         godownOpeningData.batchName;

//     godownBatchData.putIfAbsent(godownName, () => {});
//     godownBatchData[godownName]!
//         .putIfAbsent(batchName, () => BatchAccumulator());

//     final batch = godownBatchData[godownName]![batchName]!;

//     batch.inwardQty += openingQty;
//     batch.inwardValue += openingAmount;
//   }

//   String currentFyStart = '';
//   Set<String> processedVouchers = {};

//   // 🔹 Process Transactions
//   for (var txn in allTransactions) {

//     final voucherGuid = txn.voucherGuid;

//     if (processedVouchers.contains(voucherGuid) ||
//         txn.voucherType.toLowerCase().contains('purchase order') ||
//         txn.voucherType.toLowerCase().contains('sales order')) {
//       continue;
//     }

//     processedVouchers.add(voucherGuid);

//     final dateStr = txn.voucherDate;
//     final voucherType = txn.voucherType;

//     if (dateStr.compareTo(toDate) > 0) {
//       break;
//     }

//     final txnFyStart = getFinancialYearStartDate(dateStr);

//     // 🔹 FY Boundary Reset (Batch Wise)
//     if (txnFyStart != currentFyStart &&
//         currentFyStart.isNotEmpty) {

//       for (var godown in godownBatchData.keys) {
//         for (var batchData
//             in godownBatchData[godown]!.values) {

//           final inwardQty = batchData.inwardQty;
//           final inwardValue = batchData.inwardValue;
//           final outwardQty = batchData.outwardQty;

//           final closingQty = inwardQty - outwardQty;
//           final closingRate =
//               inwardQty > 0 ? inwardValue / inwardQty : 0.0;
//           final closingValue = closingQty * closingRate;

//           batchData.inwardQty = closingQty;
//           batchData.inwardValue = closingValue;
//           batchData.outwardQty = 0.0;
//         }
//       }
//     }

//     currentFyStart = txnFyStart;

//     final isPurchase =
//         purchaseVoucherTypes.contains(voucherType);
//     final isSales =
//         salesVoucherTypes.contains(voucherType);
//     final isCreditNote =
//         creditNoteVoucherTypes.contains(voucherType);
//     final isDebitNote =
//         debitNoteVoucherTypes.contains(voucherType);

//     if (voucherType == 'Physical Stock') continue;

//     final batches = voucherBatches[voucherGuid]!;

//     for (var batchTxn in batches) {

//       final godown = batchTxn.godownName;
//       final batchName =
//           batchTxn.batchName;

//       final amount = batchTxn.amount;
//       final qty = batchTxn.stock;
//       final isInward = batchTxn.isInward;
//       final absAmount = amount.abs();

//       if (batchTxn.trackingNumber
//               .toLowerCase()
//               .contains('not applicable') ==
//           false &&
//           (isPurchase ||
//               isSales ||
//               isDebitNote ||
//               isCreditNote)) {continue;}

//       if ((isCreditNote || isDebitNote) &&
//           qty == 0 &&
//           amount == 0) {
//         continue;
//       }

//       godownBatchData.putIfAbsent(godown, () => {});
//       godownBatchData[godown]!
//           .putIfAbsent(batchName, () => BatchAccumulator());

//       final batchData =
//           godownBatchData[godown]![batchName]!;

//       if (isInward) {
//         if (isCreditNote) {
//           batchData.outwardQty -= qty;
//         } else {
//           batchData.inwardQty += qty;
//           batchData.inwardValue += absAmount;
//         }
//       } else {
//         if (isDebitNote) {
//           batchData.inwardQty -= qty;
//           batchData.inwardValue -= absAmount;
//         } else {
//           batchData.outwardQty += qty;
//         }
//       }
//     }
//   }

//   // 🔹 Final: Batch → Godown Merge
//   for (var godown in godownBatchData.keys) {

//     final batches = godownBatchData[godown]!;

//     double closingQty = 0.0;
//     double closingValue = 0.0;

//     for (var batchData in batches.values) {
//       closingQty += (batchData.inwardQty - batchData.outwardQty);

//       final batchRate = batchData.inwardQty != 0
//     ? batchData.inwardValue / batchData.inwardQty
//     : 0.0;
//       closingValue += (batchData.inwardQty - batchData.outwardQty) * batchRate;

  
//     }

//     godownResults[godown] = GodownAverageCost(
//       godownName: godown,
//       totalInwardQty: 0,
//       totalInwardValue: 0,
//       currentStockQty: closingQty,
//       averageRate: 0,
//       closingValue: closingValue,
//     );
//   }

//   return AverageCostResult(
//     stockItemGuid: stockItem.stockItemGuid,
//     itemName: stockItem.itemName,
//     godowns: godownResults,
//   );
// }


//   Future<AverageCostResult> calculateCostWithoutUnit({
//   required StockItemInfo stockItem,
//   required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
//   required String fromDate,
//   required String toDate,
//   required String companyGuid,
// }) async {
//   Map<String, GodownAverageCost> godownResults = {};

//   // 🔹 Godown → Batch → Value tracking
//   Map<String, Map<String, double>> godownBatchInwardValue = {};
//   Map<String, Map<String, double>> godownBatchOutwardValue = {};

//   // Flatten all transactions and sort by voucherId
//   List<StockTransaction> allTransactions = [];
//   for (var godownMap in godownTransactions.values) {
//     for (var batchList in godownMap.values) {
//       allTransactions.addAll(batchList);
//     }
//   }
//   allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

//   // Group transactions by voucher_guid
//   Map<String, List<StockTransaction>> voucherBatches = {};
//   for (var txn in allTransactions) {
//     voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
//     voucherBatches[txn.voucherGuid]!.add(txn);
//   }

//   // 🔹 Opening Stock → Batch Level
//   for (final godownOpeningData in stockItem.openingData) {
//     String godownName = godownOpeningData.godownName;
//     if (godownName.isEmpty) {
//       godownName = 'Main Location';
//     }

//     final openingAmount = godownOpeningData.amount;
//     final batchName = godownOpeningData.batchName;

//     godownBatchInwardValue.putIfAbsent(godownName, () => {});
//     godownBatchOutwardValue.putIfAbsent(godownName, () => {});

//     godownBatchInwardValue[godownName]!.putIfAbsent(batchName, () => 0.0);
//     godownBatchOutwardValue[godownName]!.putIfAbsent(batchName, () => 0.0);

//     godownBatchInwardValue[godownName]![batchName] =
//         godownBatchInwardValue[godownName]![batchName]! + openingAmount;
//   }

//   // Process transactions
//   Set<String> processedVouchers = {};

//   for (var txn in allTransactions) {
//     final voucherGuid = txn.voucherGuid;

//     if (processedVouchers.contains(voucherGuid) ||
//         txn.voucherType.toLowerCase().contains('purchase order') ||
//         txn.voucherType.toLowerCase().contains('sales order')) {
//       continue;
//     }
//     processedVouchers.add(voucherGuid);

//     final dateStr = txn.voucherDate;
//     final voucherType = txn.voucherType;

//     if (dateStr.compareTo(toDate) > 0) {
//       break;
//     }

//     if (voucherType == 'Physical Stock') {
//       continue;
//     }

//     final batches = voucherBatches[voucherGuid]!;

//     for (var batchTxn in batches) {
//       final godown = batchTxn.godownName;
//       final batchName = batchTxn.batchName;
//       final amount = batchTxn.amount;
//       final isInward = batchTxn.isInward;
//       final absAmount = amount.abs();

//       final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
//       final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

//       // Initialize batch if not exists
//       godownBatchInwardValue.putIfAbsent(godown, () => {});
//       godownBatchOutwardValue.putIfAbsent(godown, () => {});

//       godownBatchInwardValue[godown]!.putIfAbsent(batchName, () => 0.0);
//       godownBatchOutwardValue[godown]!.putIfAbsent(batchName, () => 0.0);

//       if (isInward) {
//         if (isCreditNote) {
//           godownBatchOutwardValue[godown]![batchName] =
//               godownBatchOutwardValue[godown]![batchName]! - absAmount;
//         } else {
//           godownBatchInwardValue[godown]![batchName] =
//               godownBatchInwardValue[godown]![batchName]! + absAmount;
//         }
//       } else {
//         if (isDebitNote) {
//           godownBatchInwardValue[godown]![batchName] =
//               godownBatchInwardValue[godown]![batchName]! - absAmount;
//         } else {
//           godownBatchOutwardValue[godown]![batchName] =
//               godownBatchOutwardValue[godown]![batchName]! + absAmount;
//         }
//       }
//     }
//   }

//   // 🔹 Final: Batch → Godown Merge
//   for (var godown in godownBatchInwardValue.keys) {
//     double totalInward = 0.0;
//     double totalOutward = 0.0;

//     final batchKeys = godownBatchInwardValue[godown]!.keys;
//     for (var batchName in batchKeys) {
//       totalInward += godownBatchInwardValue[godown]![batchName] ?? 0.0;
//       totalOutward += godownBatchOutwardValue[godown]![batchName] ?? 0.0;
//     }

//     godownResults[godown] = GodownAverageCost(
//       godownName: godown,
//       totalInwardQty: 0,
//       totalInwardValue: totalInward,
//       currentStockQty: 0,
//       averageRate: 0.0,
//       closingValue: totalInward - totalOutward,
//     );
//   }

//   return AverageCostResult(
//     stockItemGuid: stockItem.stockItemGuid,
//     itemName: stockItem.itemName,
//     godowns: godownResults,
//   );
// }


//   Future<List<StockItemInfo>> fetchAllClosingStock(
//     String companyGuid, String? closingDate) async {
//   final db = await _db.database;

//   final stockItemResults = await db.rawQuery('''
//     SELECT 
//       si.name as item_name,
//       si.stock_item_guid,
//       COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
//       COALESCE(si.base_units, '') as unit,
//       COALESCE(cb.closing_balance, 0.0) as closing_balance,
//       COALESCE(cb.closing_value, 0.0) as closing_value,
//       COALESCE(cb.closing_rate, 0.0) as closing_rate,
//       COALESCE(si.parent, '') as parent_name
//     FROM stock_items si
//     INNER JOIN (
//       SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
//       UNION
//       SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = ?
//     ) active ON active.stock_item_guid = si.stock_item_guid
//     LEFT JOIN stock_item_closing_balance cb
//       ON cb.stock_item_guid = si.stock_item_guid
//       AND cb.company_guid = ?
//       AND cb.closing_date = ?
//     WHERE si.company_guid = ?
//       AND si.is_deleted = 0
//     ORDER BY si.name ASC
//   ''', [companyGuid, companyGuid, closingDate ?? '', companyGuid]);

//   return stockItemResults.map((row) => StockItemInfo(
//     itemName: row['item_name'] as String,
//     stockItemGuid: row['stock_item_guid'] as String,
//     costingMethod: row['costing_method'] as String,
//     unit: row['unit'] as String,
//     parentName: row['parent_name'] as String,
//     closingRate: (row['closing_rate'] as num?)?.toDouble() ?? 0.0,
//     closingQty: (row['closing_balance'] as num?)?.toDouble() ?? 0.0,
//     closingValue: (row['closing_value'] as num?)?.toDouble() ?? 0.0,
//     openingData: [],
//   )).toList();
// }


//   Future<Map<String, dynamic>> _getProfitLossDetailed(
//     String companyGuid,
//     DateTime fromDate,
//     DateTime toDate,
//   ) async {
//     final db = await _db.database;

//     String fromDateStr = dateToString(fromDate);
//     String toDateStr = dateToString(toDate);

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
//     ''', [companyGuid, companyGuid, companyGuid, fromDateStr, toDateStr]);

//     final debitTotal =
//         (purchaseResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
//     final creditTotal =
//         (purchaseResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
//     final netPurchase =
//         (purchaseResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;
//     final purchaseVouchers = purchaseResult.first['vouchers'] as int? ?? 0;

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
//     -- Credit = deemed positive side (normal sales)
//     SUM(CASE WHEN vle.is_deemed_positive = 1 THEN ABS(vle.amount) ELSE 0 END) as credit_total,
    
//     -- Debit = deemed negative side (sales returns)
//     SUM(CASE WHEN vle.is_deemed_positive = 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
    
//     -- Net = credit - debit
//     SUM(ABS(vle.amount)) as net_sales,
    
//     COUNT(DISTINCT v.voucher_guid) as vouchers
//       FROM voucher_ledger_entries vle
//       INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
//       INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
//       INNER JOIN group_tree gt ON l.parent_guid = gt.group_guid
//       WHERE v.company_guid = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//     ''', [companyGuid, companyGuid, companyGuid, fromDateStr, toDateStr]);

//     final salesCredit =
//         (salesResult.first['credit_total'] as num?)?.toDouble() ?? 0.0;
//     final salesDebit =
//         (salesResult.first['debit_total'] as num?)?.toDouble() ?? 0.0;
//     final netSales =
//         (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;
//     final salesVouchers = salesResult.first['vouchers'] as int? ?? 0;



//     final directExpenses = await db.rawQuery('''
//   WITH RECURSIVE group_tree AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND name = 'Direct Expenses'
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   )
//   SELECT 
//     l.name as ledger_name,
//     l.opening_balance,
//     COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
//     COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
//     (l.opening_balance + 
//      COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
//      COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
//   FROM ledgers l
//   INNER JOIN group_tree gt ON l.parent = gt.name
//   INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
//     AND v.company_guid = l.company_guid
//     AND v.is_deleted = 0
//     AND v.is_cancelled = 0
//     AND v.is_optional = 0
//     AND v.date >= ?
//     AND v.date <= ?
//   WHERE l.company_guid = ?
//     AND l.is_deleted = 0
//   GROUP BY l.name, l.opening_balance
//   ORDER BY closing_balance DESC
// ''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

//     double totalDirectExpenses = 0.0;
//     for (final expense in directExpenses) {
//       final closingBalance =
//           (expense['closing_balance'] as num?)?.toDouble() ?? 0.0;
//       totalDirectExpenses += closingBalance; // ← Now includes opening balance
//     }

//     final indirectExpenses = await db.rawQuery('''
//   WITH RECURSIVE group_tree AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND name = 'Indirect Expenses'
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   )
//   SELECT 
//     l.name as ledger_name,
//     l.opening_balance,
//     COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
//     COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
//     (l.opening_balance + 
//      COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) - 
//      COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
//   FROM ledgers l
//   INNER JOIN group_tree gt ON l.parent = gt.name
//   INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
//     AND v.company_guid = l.company_guid
//     AND v.is_deleted = 0
//     AND v.is_cancelled = 0
//     AND v.is_optional = 0
//     AND v.date >= ?
//     AND v.date <= ?
//   WHERE l.company_guid = ?
//     AND l.is_deleted = 0
//   GROUP BY l.name, l.opening_balance
//   ORDER BY closing_balance DESC
// ''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

//     double totalIndirectExpenses = 0.0;
//     for (final expense in indirectExpenses) {
//       final closingBalance =
//           (expense['closing_balance'] as num?)?.toDouble() ?? 0.0;
//       totalIndirectExpenses += closingBalance;
//     }

//     final indirectIncomes = await db.rawQuery('''
//   WITH RECURSIVE group_tree AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND name = 'Indirect Incomes'
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   )
//   SELECT 
//     l.name as ledger_name,
//     l.opening_balance,
//     COALESCE(SUM(CASE 
//       WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
//       THEN vle.amount 
//       ELSE 0 
//     END), 0) as credit_total,
//     COALESCE(SUM(CASE 
//       WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
//       THEN ABS(vle.amount) 
//       ELSE 0 
//     END), 0) as debit_total,
//     (l.opening_balance + 
//      COALESCE(SUM(CASE 
//        WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
//        THEN vle.amount 
//        ELSE 0 
//      END), 0) - 
//      COALESCE(SUM(CASE 
//        WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
//        THEN ABS(vle.amount) 
//        ELSE 0 
//      END), 0)) as closing_balance
//   FROM ledgers l
//   INNER JOIN group_tree gt ON l.parent = gt.name
//   INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
//     AND v.company_guid = l.company_guid
//     AND v.is_deleted = 0
//     AND v.is_cancelled = 0
//     AND v.is_optional = 0
//     AND v.date >= ?
//     AND v.date <= ?
//   WHERE l.company_guid = ?
//     AND l.is_deleted = 0
//   GROUP BY l.name, l.opening_balance
//   HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
//   ORDER BY closing_balance DESC
// ''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

//     double totalIndirectIncomes = 0.0;
//     for (final income in indirectIncomes) {
//       final closing = (income['closing_balance'] as num?)?.toDouble() ?? 0.0;
//       totalIndirectIncomes += closing;
//     }

//     final directIncomes = await db.rawQuery('''
//   WITH RECURSIVE group_tree AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND name = 'Direct Incomes'
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   )
//   SELECT 
//     l.name as ledger_name,
//     l.opening_balance,
//     COALESCE(SUM(CASE 
//       WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
//       THEN vle.amount 
//       ELSE 0 
//     END), 0) as credit_total,
//     COALESCE(SUM(CASE 
//       WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
//       THEN ABS(vle.amount) 
//       ELSE 0 
//     END), 0) as debit_total,
//     (l.opening_balance + 
//      COALESCE(SUM(CASE 
//        WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 
//        THEN vle.amount 
//        ELSE 0 
//      END), 0) - 
//      COALESCE(SUM(CASE 
//        WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 
//        THEN ABS(vle.amount) 
//        ELSE 0 
//      END), 0)) as closing_balance
//   FROM ledgers l
//   INNER JOIN group_tree gt ON l.parent = gt.name
//   INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
//   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid 
//     AND v.company_guid = l.company_guid
//     AND v.is_deleted = 0
//     AND v.is_cancelled = 0
//     AND v.is_optional = 0
//     AND v.date >= ?
//     AND v.date <= ?
//   WHERE l.company_guid = ?
//     AND l.is_deleted = 0
//   GROUP BY l.name, l.opening_balance
//   HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
//   ORDER BY closing_balance DESC
// ''', [companyGuid, companyGuid, fromDateStr, toDateStr, companyGuid]);

//     double totalDirectIncomes = 0.0;
//     for (final income in directIncomes) {
//       final closing = (income['closing_balance'] as num?)?.toDouble() ?? 0.0;
//       totalDirectIncomes += closing;
//     }    

//     double totalClosingStock = 0.0;
//     double totalOpeningStock = 0.0;

// if (_isMaintainInventory){

//       final allItemClosings = await fetchAllClosingStock(_companyGuid!,  toDateStr);

//       totalClosingStock = allItemClosings.fold(0.0, (sum, item) => sum + item.closingValue);

//       final previousDay = dateToString(fromDate).compareTo(_companyStartDate) <= 0 ? fromDateStr : getPreviousDate(fromDateStr);


//       final allItemOpening = await fetchAllClosingStock(_companyGuid!,  previousDay);

//       totalOpeningStock = allItemOpening.fold(0.0, (sum, item) => sum + item.closingValue);


//     // final allItemClosings = await calculateAllAverageCost(companyGuid: _companyGuid!, fromDate: fromDateStr, toDate: toDateStr);

//     // totalClosingStock = getTotalClosingValue(allItemClosings);

//     // final previousDay = dateToString(fromDate).compareTo(_companyStartDate) <= 0 ? fromDateStr : getPreviousDate(fromDateStr);

//     // final allItemOpening = await calculateAllAverageCost(companyGuid: _companyGuid!,fromDate: previousDay,toDate: previousDay);

//     // totalOpeningStock = getTotalClosingValue(allItemOpening);

// }else{

//   final closingStockResult = await db.rawQuery('''
//   WITH RECURSIVE stock_groups AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND (reserved_name = 'Stock-in-Hand' OR name = 'Stock-in-Hand')
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   ),
//   latest_balances AS (
//     SELECT lcb.ledger_guid, lcb.amount * -1 as closing_amount,
//            ROW_NUMBER() OVER (PARTITION BY lcb.ledger_guid ORDER BY lcb.closing_date DESC) as rn
//     FROM ledger_closing_balances lcb
//     INNER JOIN ledgers l ON l.ledger_guid = lcb.ledger_guid
//     INNER JOIN stock_groups sg ON l.parent = sg.name
//     WHERE lcb.company_guid = ?
//       AND lcb.closing_date <= ?
//       AND l.is_deleted = 0
//   )
//   SELECT COALESCE(SUM(closing_amount), 0) as total_closing_stock
//   FROM latest_balances
//   WHERE rn = 1
// ''', [companyGuid, companyGuid, companyGuid, toDateStr]);

//   totalClosingStock = closingStockResult.isNotEmpty 
//       ? (closingStockResult.first['total_closing_stock'] as num?)?.toDouble() ?? 0.0
//       : 0.0;

//   final previousDay = fromDateStr.compareTo(_companyStartDate) <= 0 
//       ? _companyStartDate 
//       : getPreviousDate(fromDateStr);

// final openingStockResult = await db.rawQuery('''
//   WITH RECURSIVE stock_groups AS (
//     SELECT group_guid, name
//     FROM groups
//     WHERE company_guid = ?
//       AND (reserved_name = 'Stock-in-Hand' OR name = 'Stock-in-Hand')
//       AND is_deleted = 0
    
//     UNION ALL
    
//     SELECT g.group_guid, g.name
//     FROM groups g
//     INNER JOIN stock_groups sg ON g.parent_guid = sg.group_guid
//     WHERE g.company_guid = ?
//       AND g.is_deleted = 0
//   ),
//   latest_balances AS (
//     SELECT l.ledger_guid,
//            COALESCE(lcb.amount, l.opening_balance) * -1 as opening_amount,
//            ROW_NUMBER() OVER (
//              PARTITION BY l.ledger_guid 
//              ORDER BY lcb.closing_date DESC NULLS LAST
//            ) as rn
//     FROM ledgers l
//     INNER JOIN stock_groups sg ON l.parent = sg.name
//     LEFT JOIN ledger_closing_balances lcb ON lcb.ledger_guid = l.ledger_guid
//       AND lcb.company_guid = ?
//       AND lcb.closing_date <= ?
//     WHERE l.company_guid = ?
//       AND l.is_deleted = 0
//   )
//   SELECT COALESCE(SUM(opening_amount), 0) as total_opening_stock
//   FROM latest_balances
//   WHERE rn = 1
// ''', [companyGuid, companyGuid, companyGuid, previousDay, companyGuid]);

//   totalOpeningStock = openingStockResult.isNotEmpty
//       ? (openingStockResult.first['total_opening_stock'] as num?)?.toDouble() ?? 0.0
//       : 0.0;
// }
    

//     final grossProfit = (netSales + totalDirectIncomes + totalClosingStock) -
//         (totalOpeningStock + netPurchase + totalDirectExpenses.abs());
//     final netProfit =
//         grossProfit + totalIndirectIncomes - totalIndirectExpenses.abs();

//     print('opening_stock : ${totalOpeningStock}');
//     print('closing_stock : ${totalClosingStock}');

//     return {
//       'opening_stock': totalOpeningStock,
//       'purchase': netPurchase,
//       'direct_expenses': directExpenses,
//       'direct_expenses_total': totalDirectExpenses.abs(),
//       'gross_profit': grossProfit,
//       'closing_stock': totalClosingStock,
//       'sales': netSales,
//       'indirect_expenses': indirectExpenses,
//       'indirect_expenses_total': totalIndirectExpenses.abs(),
//       'indirect_incomes': indirectIncomes,
//       'indirect_incomes_total': totalIndirectIncomes,
//       'direct_incomes': directIncomes,
//       'direct_incomes_total': totalDirectIncomes,
//       'net_profit': netProfit,
//     };
//   }

//   void _navigateToGroup(String groupName) {
//     if (_companyGuid == null || _companyName == null) return;

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => GroupDetailScreen(
//           companyGuid: _companyGuid!,
//           companyName: _companyName!,
//           groupName: groupName,
//           fromDate: dateToString(_fromDate),
//           toDate: dateToString(_toDate),
//         ),
//       ),
//     );
//   }

//    void _navigateToStockSummary() {
//     if (_companyGuid == null || _companyName == null) return;

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => StockSummaryScreen(),
//       ),
//     );
//   }


//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Profit & Loss A/c')),
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Text('Profit & Loss A/c'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.calendar_today),
//             onPressed: _selectDateRange,
//           ),
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadData,
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             // Header
//             Container(
//               width: double.infinity,
//               color: Colors.blue[50],
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Text(
//                     _companyName ?? '',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 4),
//                   Text(
//                     '${_formatDate(dateToString(_fromDate))} to ${_formatDate(dateToString(_toDate))}',
//                     style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//                   ),
//                 ],
//               ),
//             ),

//             // Main Content
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Left Side - Expenses
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildSectionHeader('Particulars'),
//                       _buildLeftItem(
//                         'Opening Stock',
//                         _plData?['opening_stock'] ?? 0.0,
//                         onTap: () => _navigateToStockSummary(),
//                       ),
//                       _buildLeftItem(
//                         'Purchase Accounts',
//                         _plData?['purchase'] ?? 0.0,
//                         onTap: () => _navigateToGroup('Purchase Accounts'),
//                       ),
//                       _buildLeftItem(
//                         'Direct Expenses',
//                         _plData?['direct_expenses_total'] ?? 0.0,
//                         onTap: () => _navigateToGroup('Direct Expenses'),
//                       ),
//                       _buildGrossProfitRow(
//                         'Gross Profit c/o',
//                         _plData?['gross_profit'] ?? 0.0,
//                       ),
//                       Divider(thickness: 2),
//                       _buildLeftItem(
//                         'Indirect Expenses',
//                         _plData?['indirect_expenses_total'] ?? 0.0,
//                         onTap: () => _navigateToGroup('Indirect Expenses'),
//                       ),
//                       _buildNetProfitRow(
//                         'Net Profit',
//                         _plData?['net_profit'] ?? 0.0,
//                       ),
//                     ],
//                   ),
//                 ),

//                 VerticalDivider(width: 1),

//                 // Right Side - Incomes
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildSectionHeader('Particulars'),
//                       _buildRightItem(
//                         'Sales Accounts',
//                         _plData?['sales'] ?? 0.0,
//                         onTap: () => _navigateToGroup('Sales Accounts'),
//                       ),
//                       _buildRightItem(
//                         'Closing Stock',
//                         _plData?['closing_stock'] ?? 0.0,
//                         onTap: () => _navigateToStockSummary(),
//                       ),
//                       _buildRightItem(
//                         'Direct Incomes',
//                         _plData?['direct_incomes_total'] ?? 0.0,
//                         onTap: () => _navigateToGroup('Direct Incomes'),
//                       ),
//                       SizedBox(height: 20),
//                       _buildGrossProfitRow(
//                         'Gross Profit b/f',
//                         _plData?['gross_profit'] ?? 0.0,
//                       ),
//                       Divider(thickness: 2),
//                       _buildRightItem(
//                         'Indirect Incomes',
//                         _plData?['indirect_incomes_total'] ?? 0.0,
//                         onTap: () => _navigateToGroup('Indirect Incomes'),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             // Footer - Total
//             Container(
//               width: double.infinity,
//               color: Colors.grey[200],
//               padding: EdgeInsets.all(16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Total',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   Text(
//                     _formatAmount(_calculateTotal()),
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   Text(
//                     'Total',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   Text(
//                     _formatAmount(_calculateTotal()),
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSectionHeader(String title) {
//     return Container(
//       width: double.infinity,
//       color: Colors.grey[100],
//       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Text(
//         title,
//         style: TextStyle(fontWeight: FontWeight.bold),
//       ),
//     );
//   }

//   Widget _buildLeftItem(String label, double amount, {VoidCallback? onTap}) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Row(
//               children: [
//                 Text(label),
//                 if (onTap != null) ...[
//                   SizedBox(width: 8),
//                   Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
//                 ],
//               ],
//             ),
//             Text(_formatAmount(amount)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRightItem(String label, double amount, {VoidCallback? onTap}) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Row(
//               children: [
//                 Text(label),
//                 if (onTap != null) ...[
//                   SizedBox(width: 8),
//                   Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
//                 ],
//               ],
//             ),
//             Text(_formatAmount(amount)),
//           ],
//         ),
//       ),
//     );
//   }


//   Widget _buildGrossProfitRow(String label, double amount) {
//     return Container(
//       color: Colors.amber[100],
//       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           Text(
//             _formatAmount(amount),
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNetProfitRow(String label, double amount) {
//     return Container(
//       color: Colors.green[100],
//       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           Text(
//             _formatAmount(amount),
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }

//   double _calculateTotal() {
//     final opening = _plData?['opening_stock'] ?? 0.0;
//     final purchase = _plData?['purchase'] ?? 0.0;
//     final directExp = _plData?['direct_expenses_total'] ?? 0.0;
//     final indirectExp = _plData?['indirect_expenses_total'] ?? 0.0;
//     final netProfit = _plData?['net_profit'] ?? 0.0;

//     return opening + purchase + directExp + indirectExp + netProfit;
//   }

//   String _formatAmount(double amount) {
//     return amount.toStringAsFixed(2).replaceAllMapped(
//           RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
//           (Match m) => '${m[1]},',
//         );
//   }

//   String _formatDate(String tallyDate) {
//     if (tallyDate.length != 8) return tallyDate;
//     final year = tallyDate.substring(0, 4);
//     final month = tallyDate.substring(4, 6);
//     final day = tallyDate.substring(6, 8);
//     return '$day-$month-$year';
//   }

//   Future<void> _selectDateRange() async {
//     final DateTimeRange? picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//       initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
//       builder: (context, child) {
//         return Theme(
//           data: ThemeData.light().copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: Colors.blue,
//               onPrimary: Colors.white,
//               surface: Colors.white,
//               onSurface: Colors.black,
//             ),
//             dialogBackgroundColor: Colors.white,
//           ),
//           child: child!,
//         );
//       },
//     );

//     if (picked != null) {
//       setState(() {
//         // _selectedFromDate = picked.start;
//         // _selectedToDate = picked.end;
//         _fromDate = picked.start;
//         _toDate = picked.end;
//       });

//       await _loadData();
//     }
//   }
// }


import 'package:flutter/material.dart';
import '../../models/data_model.dart';
import '../../database/database_helper.dart';
import '../../utils/date_utils.dart';
import '../theme/app_theme.dart';
import 'group_detail_screen.dart';
import 'stock_summary_screen.dart';

class ProfitLossScreen extends StatefulWidget {
  @override
  _ProfitLossScreenState createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  String? _companyGuid;
  String? _companyName;
  String _companyStartDate = getCurrentFyStartDate();
  bool _loading = true;
  bool _isMaintainInventory = true;

  List<String> debitNoteVoucherTypes    = [];
  List<String> creditNoteVoucherTypes   = [];
  List<String> stockJournalVoucherType  = [];
  List<String> physicalStockVoucherType = [];
  List<String> receiptNoteVoucherTypes  = [];
  List<String> deliveryNoteVoucherTypes = [];
  List<String> purchaseVoucherTypes     = [];
  List<String> salesVoucherTypes        = [];

  Map<String, dynamic>? _plData;
  DateTime _fromDate = getFyStartDate(DateTime.now());
  DateTime _toDate   = getFyEndDate(DateTime.now());

  // Expand/collapse state for each section
  bool _showDirectExpDetail    = false;
  bool _showIndirectExpDetail  = false;
  bool _showDirectIncDetail    = false;
  bool _showIndirectIncDetail  = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF1A6FD8);
  static const Color _accent    = Color(0xFF00C9A7);
  static const Color _debitCol  = Color(0xFFD32F2F);
  static const Color _creditCol = Color(0xFF1B8A5A);
  static Color get _grossBg   => AppColors.iconBgAmber;
  static const Color _grossC    = Color(0xFFB45309);
  static Color get _netBg     => AppColors.iconBgGreen;
  static const Color _netC      = Color(0xFF1B8A5A);
  static Color get _netLossBg => AppColors.iconBgRed;
  static const Color _netLossC  = Color(0xFFD32F2F);

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

  // ── Data loading (unchanged logic) ─────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final company = await _db.getSelectedCompanyByGuid();
    if (company == null) {
      setState(() => _loading = false);
      return;
    }

    _companyGuid         = company['company_guid'] as String;
    _companyName         = company['company_name'] as String;
    _isMaintainInventory = (company['integrate_inventory'] as int) == 1;
    _companyStartDate    =
        (company['starting_from'] as String).replaceAll('-', '');

    debitNoteVoucherTypes    = await getAllChildVoucherTypes(_companyGuid!, 'Debit Note');
    creditNoteVoucherTypes   = await getAllChildVoucherTypes(_companyGuid!, 'Credit Note');
    stockJournalVoucherType  = await getAllChildVoucherTypes(_companyGuid!, 'Stock Journal');
    physicalStockVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Physical Stock');
    receiptNoteVoucherTypes  = await getAllChildVoucherTypes(_companyGuid!, 'Receipt Note');
    deliveryNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Delivery Note');
    purchaseVoucherTypes     = await getAllChildVoucherTypes(_companyGuid!, 'Purchase');
    salesVoucherTypes        = await getAllChildVoucherTypes(_companyGuid!, 'Sales');

    final plData =
        await _getProfitLossDetailed(_companyGuid!, _fromDate, _toDate);

    setState(() {
      _plData  = plData;
      _loading = false;
    });
    _fadeCtrl.forward(from: 0);
  }

  double getTotalClosingValue(List<AverageCostResult> results) {
    double total = 0.0;
    for (var r in results) {
      for (var g in r.godowns.values) total += g.closingValue;
    }
    return total;
  }

  // ── Voucher type helpers (unchanged) ───────────────────────────────────────

  Future<List<String>> getAllChildVoucherTypes(
      String companyGuid, String voucherTypeName) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      WITH RECURSIVE voucher_type_tree AS (
        SELECT voucher_type_guid, name
        FROM voucher_types
        WHERE company_guid = ?
          AND (name = ? OR reserved_name = ?)
          AND is_deleted = 0
        UNION ALL
        SELECT vt.voucher_type_guid, vt.name
        FROM voucher_types vt
        INNER JOIN voucher_type_tree vtt ON vt.parent_guid = vtt.voucher_type_guid
        WHERE vt.company_guid = ?
          AND vt.is_deleted = 0
          AND vt.voucher_type_guid != vt.parent_guid
      )
      SELECT name FROM voucher_type_tree ORDER BY name
    ''', [companyGuid, voucherTypeName, voucherTypeName, companyGuid]);
    return result.map((r) => r['name'] as String).toList();
  }

  Future<List<StockItemInfo>> fetchAllStockItems(String companyGuid) async {
    final db = await _db.database;
    final stockItemResults = await db.rawQuery('''
      SELECT si.name as item_name, si.stock_item_guid,
        COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
        COALESCE(si.base_units, '') as unit,
        COALESCE(si.parent, '') as parent_name
      FROM stock_items si
      WHERE si.company_guid = ? AND si.is_deleted = 0
        AND (
          EXISTS (SELECT 1 FROM stock_item_batch_allocation siba WHERE siba.stock_item_guid = si.stock_item_guid)
          OR EXISTS (SELECT 1 FROM voucher_inventory_entries vie WHERE vie.stock_item_guid = si.stock_item_guid AND vie.company_guid = si.company_guid)
        )
    ''', [companyGuid]);

    final batchResults = await db.rawQuery('''
      SELECT siba.stock_item_guid, COALESCE(siba.godown_name, '') as godown_name,
        COALESCE(siba.batch_name, '') as batch_name,
        COALESCE(siba.opening_value, 0) as amount,
        COALESCE(siba.opening_balance, '') as actual_qty,
        siba.opening_rate as batch_rate
      FROM stock_item_batch_allocation siba
      INNER JOIN stock_items si ON siba.stock_item_guid = si.stock_item_guid
      WHERE si.company_guid = ? AND si.is_deleted = 0
    ''', [companyGuid]);

    final Map<String, List<BatchAllocation>> batchMap = {};
    for (final row in batchResults) {
      final guid = row['stock_item_guid'] as String;
      batchMap.putIfAbsent(guid, () => []).add(BatchAllocation(
        godownName: row['godown_name'] as String,
        trackingNumber: 'Not Applicable',
        batchName: row['batch_name'] as String,
        amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
        actualQty: row['actual_qty']?.toString() ?? '',
        billedQty: row['actual_qty']?.toString() ?? '',
        batchRate: (row['batch_rate'] as num?)?.toDouble(),
      ));
    }

    return stockItemResults.map((row) {
      final guid = row['stock_item_guid'] as String;
      return StockItemInfo(
        itemName: row['item_name'] as String,
        stockItemGuid: guid,
        costingMethod: row['costing_method'] as String,
        unit: row['unit'] as String,
        parentName: row['parent_name'] as String,
        closingRate: 0.0, closingQty: 0.0, closingValue: 0.0,
        openingData: batchMap[guid] ?? [],
      );
    }).toList();
  }

  Future<List<StockTransaction>> fetchTransactionsForStockItem(
      String companyGuid, String stockItemGuid, String endDate) async {
    final db = await _db.database;
    final results = await db.rawQuery('''
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

    return results.map((row) {
      final stockStr = (row['stock'] as String?) ?? '0';
      final parts    = stockStr.split(' ');
      final stock    = double.tryParse(parts[0]) ?? 0.0;
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
        trackingNumber: row['tracking_number'] as String,
      );
    }).toList();
  }

  Future<Map<String, Map<String, Map<String, List<StockTransaction>>>>>
      buildStockDirectoryWithBatch(
          String companyGuid, String endDate, List<StockItemInfo> stockItems) async {
    Map<String, Map<String, Map<String, List<StockTransaction>>>> directory = {};
    for (var item in stockItems) {
      final txns = await fetchTransactionsForStockItem(companyGuid, item.stockItemGuid, endDate);
      Map<String, Map<String, List<StockTransaction>>> godownTxns = {};
      for (var t in txns) {
        godownTxns.putIfAbsent(t.godownName, () => {});
        godownTxns[t.godownName]!.putIfAbsent(t.batchName, () => []).add(t);
      }
      directory[item.stockItemGuid] = godownTxns;
    }
    return directory;
  }

  // ── All cost calculations preserved verbatim (avgCost, fifo, lifo, noUnit) ─
  // [All calculateAvgCost, calculateFifoCost, calculateLifoCost,
  //  calculateCostWithoutUnit, calculateAllAverageCost methods are identical
  //  to the original — they contain pure business logic with no UI impact.
  //  They are included here unchanged.]

  Future<List<AverageCostResult>> calculateAllAverageCost({
    required String companyGuid,
    required String fromDate,
    required String toDate,
  }) async {
    final stockItems = await fetchAllStockItems(companyGuid);
    final directory  = await buildStockDirectoryWithBatch(companyGuid, toDate, stockItems);
    List<AverageCostResult> results = [];
    for (var stockItem in stockItems) {
      final godownTxns = directory[stockItem.stockItemGuid]!;
      if (stockItem.unit.toLowerCase().contains('not applicable')) {
        results.add(await calculateCostWithoutUnit(stockItem: stockItem, godownTransactions: godownTxns, fromDate: fromDate, toDate: toDate, companyGuid: companyGuid));
      } else if (stockItem.costingMethod.toLowerCase().contains('zero')) {
        results.add(AverageCostResult(itemName: stockItem.itemName, stockItemGuid: stockItem.stockItemGuid, godowns: {}));
      } else if (stockItem.costingMethod.toLowerCase().contains('fifo')) {
        results.add(await calculateFifoCost(stockItem: stockItem, godownTransactions: godownTxns, fromDate: fromDate, toDate: toDate, companyGuid: companyGuid));
      } else if (stockItem.costingMethod.toLowerCase().contains('lifo')) {
        results.add(await calculateLifoCost(stockItem: stockItem, godownTransactions: godownTxns, fromDate: fromDate, toDate: toDate, companyGuid: companyGuid));
      } else {
        results.add(await calculateAvgCost(stockItem: stockItem, godownTransactions: godownTxns, fromDate: fromDate, toDate: toDate, companyGuid: companyGuid));
      }
    }
    return results;
  }

  Future<AverageCostResult> calculateAvgCost({required StockItemInfo stockItem, required Map<String, Map<String, List<StockTransaction>>> godownTransactions, required String fromDate, required String toDate, required String companyGuid}) async {
    Map<String, GodownAverageCost> godownResults = {};
    Map<String, Map<String, BatchAccumulator>> godownBatchData = {};
    const fyStartMonth = 4, fyStartDay = 1;
    String getFyStart(String d) { final y = int.parse(d.substring(0,4)); final m = int.parse(d.substring(4,6)); return m < fyStartMonth ? '${y-1}${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}' : '$y${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}'; }
    List<StockTransaction> all = [];
    for (var gm in godownTransactions.values) for (var bl in gm.values) all.addAll(bl);
    all.sort((a,b) => a.voucherId.compareTo(b.voucherId));
    Map<String, List<StockTransaction>> vb = {};
    for (var t in all) vb.putIfAbsent(t.voucherGuid, () => []).add(t);
    for (final od in stockItem.openingData) {
      String gn = od.godownName.isEmpty ? 'Main Location' : od.godownName;
      godownBatchData.putIfAbsent(gn, () => {});
      final acc = godownBatchData[gn]!.putIfAbsent(od.batchName, () => BatchAccumulator());
      acc.inwardQty += double.tryParse(od.actualQty) ?? 0.0;
      acc.inwardValue += od.amount;
    }
    String curFy = ''; Set<String> processed = {};
    for (var txn in all) {
      final vg = txn.voucherGuid;
      if (processed.contains(vg) || txn.voucherType.toLowerCase().contains('purchase order') || txn.voucherType.toLowerCase().contains('sales order')) continue;
      processed.add(vg);
      final d = txn.voucherDate; final vt = txn.voucherType;
      if (d.compareTo(toDate) > 0) break;
      final fyS = getFyStart(d);
      if (fyS != curFy && curFy.isNotEmpty) {
        for (var g in godownBatchData.keys) for (var bd in godownBatchData[g]!.values) {
          final cq = bd.inwardQty - bd.outwardQty; final cr = bd.inwardQty > 0 ? bd.inwardValue / bd.inwardQty : 0.0;
          bd.inwardQty = cq; bd.inwardValue = cq * cr; bd.outwardQty = 0.0;
        }
      }
      curFy = fyS;
      final isP = purchaseVoucherTypes.contains(vt); final isS = salesVoucherTypes.contains(vt);
      final isCN = creditNoteVoucherTypes.contains(vt); final isDN = debitNoteVoucherTypes.contains(vt);
      if (vt == 'Physical Stock') continue;
      for (var bt in vb[vg]!) {
        final g = bt.godownName; final bn = bt.batchName; final amt = bt.amount; final qty = bt.stock; final isIn = bt.isInward; final absA = amt.abs();
        if (!bt.trackingNumber.toLowerCase().contains('not applicable') && (isP || isS || isDN || isCN)) continue;
        if ((isCN || isDN) && qty == 0 && amt == 0) continue;
        godownBatchData.putIfAbsent(g, () => {});
        final bd = godownBatchData[g]!.putIfAbsent(bn, () => BatchAccumulator());
        if (isIn) { if (isCN) bd.outwardQty -= qty; else { bd.inwardQty += qty; bd.inwardValue += absA; } }
        else { if (isDN) { bd.inwardQty -= qty; bd.inwardValue -= absA; } else bd.outwardQty += qty; }
      }
    }
    for (var g in godownBatchData.keys) {
      double cq = 0, cv = 0;
      for (var bd in godownBatchData[g]!.values) {
        final q = bd.inwardQty - bd.outwardQty; final r = bd.inwardQty != 0 ? bd.inwardValue / bd.inwardQty : 0.0;
        cq += q; cv += q * r;
      }
      godownResults[g] = GodownAverageCost(godownName: g, totalInwardQty: 0, totalInwardValue: 0, currentStockQty: cq, averageRate: 0, closingValue: cv);
    }
    return AverageCostResult(stockItemGuid: stockItem.stockItemGuid, itemName: stockItem.itemName, godowns: godownResults);
  }

  Future<AverageCostResult> calculateFifoCost({required StockItemInfo stockItem, required Map<String, Map<String, List<StockTransaction>>> godownTransactions, required String fromDate, required String toDate, required String companyGuid}) async {
    // Full FIFO logic preserved — same as original
    Map<String, GodownAverageCost> godownResults = {};
    const fyStartMonth = 4, fyStartDay = 1;
    String getFyStart(String d) { final y = int.parse(d.substring(0,4)); final m = int.parse(d.substring(4,6)); return m < fyStartMonth ? '${y-1}${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}' : '$y${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}'; }
    Map<String, Map<String, double>> gbIQ = {}, gbOQ = {};
    Map<String, Map<String, List<StockLot>>> gbL = {};
    List<StockTransaction> all = [];
    for (var gm in godownTransactions.values) for (var bl in gm.values) all.addAll(bl);
    all.sort((a,b) => a.voucherId.compareTo(b.voucherId));
    Map<String, List<StockTransaction>> vb = {};
    for (var t in all) vb.putIfAbsent(t.voucherGuid, () => []).add(t);
    for (final od in stockItem.openingData) {
      String gn = od.godownName.isEmpty ? 'Main Location' : od.godownName;
      final oq = double.tryParse(od.actualQty) ?? 0.0; final bn = od.batchName;
      gbIQ.putIfAbsent(gn, () => {}); gbOQ.putIfAbsent(gn, () => {}); gbL.putIfAbsent(gn, () => {});
      gbIQ[gn]!.putIfAbsent(bn, () => 0.0); gbOQ[gn]!.putIfAbsent(bn, () => 0.0); gbL[gn]!.putIfAbsent(bn, () => []);
      gbIQ[gn]![bn] = gbIQ[gn]![bn]! + oq;
      final r = od.amount / oq;
      gbL[gn]![bn]!.add(StockLot(voucherGuid: 'OPENING_STOCK', voucherDate: fromDate, voucherNumber: 'Opening Balance', voucherType: 'Opening', qty: oq, amount: od.amount, rate: r, type: StockInOutType.inward));
    }
    double calcFifo(List<StockLot> lots, double cq) {
      if (cq <= 0 || lots.isEmpty) return 0.0;
      double cv = 0, rem = cq, lr = 0;
      for (int i = lots.length - 1; i >= 0 && rem > 0; i--) {
        final l = lots[i]; lr = l.rate;
        if (l.qty == 0) cv += l.amount;
        else if (l.qty <= rem) { cv += l.amount; rem -= l.qty; }
        else { cv += rem * l.rate; rem = 0; }
      }
      if (rem > 0) cv += rem * lr;
      if (cv == 0 && cq > 0) { final tq = lots.fold(0.0,(s,l)=>s+l.qty); final tv = lots.fold(0.0,(s,l)=>s+l.amount); if (tq>0) cv = cq*(tv/tq); }
      return cv;
    }
    String curFy = ''; Set<String> processed = {};
    for (var txn in all) {
      final vg = txn.voucherGuid;
      if (processed.contains(vg) || txn.voucherType.toLowerCase().contains('purchase order') || txn.voucherType.toLowerCase().contains('sales order')) continue;
      processed.add(vg);
      final d = txn.voucherDate; final vt = txn.voucherType;
      if (d.compareTo(toDate) > 0) break;
      final fyS = getFyStart(d);
      if (fyS != curFy && curFy.isNotEmpty) {
        for (var g in gbIQ.keys) {
          for (var bn in gbIQ[g]!.keys.toList()) {
            final iq = gbIQ[g]![bn]!; final oq = gbOQ[g]![bn] ?? 0.0; final csq = iq - oq; final lots = gbL[g]![bn] ?? [];
            if (csq > 0) { final cv = calcFifo(lots, csq); gbIQ[g]![bn] = csq; gbOQ[g]![bn] = 0.0; gbL[g]![bn] = [StockLot(voucherGuid: 'FY_OPENING_$fyS', voucherDate: fyS, voucherNumber: 'FY Opening Balance', voucherType: 'Opening', qty: csq, amount: cv, rate: cv/csq, type: StockInOutType.inward)]; }
            else if (csq < 0) { final tq = lots.fold(0.0,(s,l)=>s+l.qty); final tv = lots.fold(0.0,(s,l)=>s+l.amount); final cr = tq > 0 ? tv/tq : 0.0; gbIQ[g]![bn] = csq; gbOQ[g]![bn] = 0.0; gbL[g]![bn] = [StockLot(voucherGuid: 'FY_OPENING_$fyS', voucherDate: fyS, voucherNumber: 'FY Opening Balance', voucherType: 'Opening', qty: csq, amount: csq*cr, rate: cr, type: StockInOutType.inward)]; }
            else { gbIQ[g]![bn] = 0.0; gbOQ[g]![bn] = 0.0; gbL[g]![bn] = []; }
          }
        }
      }
      curFy = fyS;
      final isP = purchaseVoucherTypes.contains(vt); final isS = salesVoucherTypes.contains(vt);
      final isCN = creditNoteVoucherTypes.contains(vt); final isDN = debitNoteVoucherTypes.contains(vt);
      if (vt == 'Physical Stock') continue;
      for (var bt in vb[vg]!) {
        final g = bt.godownName; final bn = bt.batchName; final amt = bt.amount; final qty = bt.stock; final isIn = bt.isInward; final absA = amt.abs();
        if (!bt.trackingNumber.toLowerCase().contains('not applicable') && (isP || isS || isDN || isCN)) continue;
        if ((isCN || isDN) && qty == 0 && amt == 0) continue;
        gbIQ.putIfAbsent(g, () => {}); gbOQ.putIfAbsent(g, () => {}); gbL.putIfAbsent(g, () => {});
        gbIQ[g]!.putIfAbsent(bn, () => 0.0); gbOQ[g]!.putIfAbsent(bn, () => 0.0); gbL[g]!.putIfAbsent(bn, () => []);
        if (isIn) { if (isCN) gbOQ[g]![bn] = gbOQ[g]![bn]! - qty; else { gbIQ[g]![bn] = gbIQ[g]![bn]! + qty; final r = qty > 0 ? absA/qty : 0.0; gbL[g]![bn]!.add(StockLot(voucherGuid: vg, voucherDate: d, voucherNumber: txn.voucherNumber, voucherType: vt, qty: qty, amount: absA, rate: r, type: StockInOutType.inward)); } }
        else { if (isDN) { gbIQ[g]![bn] = gbIQ[g]![bn]! - qty; final r = qty > 0 ? absA/qty : 0.0; gbL[g]![bn]!.add(StockLot(voucherGuid: vg, voucherDate: d, voucherNumber: txn.voucherNumber, voucherType: vt, qty: qty*-1, amount: amt*-1, rate: r, type: StockInOutType.inward)); } else gbOQ[g]![bn] = gbOQ[g]![bn]! + qty; }
      }
    }
    for (var g in gbIQ.keys) {
      double tcq = 0, tcv = 0;
      for (var bn in gbIQ[g]!.keys) {
        final iq = gbIQ[g]![bn]!; final oq = gbOQ[g]![bn] ?? 0.0; final csq = iq - oq; final lots = gbL[g]![bn] ?? [];
        double bcv = 0;
        if (csq > 0) bcv = calcFifo(lots, csq);
        else if (csq < 0) { final tq = lots.fold(0.0,(s,l)=>s+l.qty); final tv = lots.fold(0.0,(s,l)=>s+l.amount); final cr = tq==0?0.0:tv/tq; bcv = csq*cr; }
        tcq += csq; tcv += bcv;
      }
      godownResults[g] = GodownAverageCost(godownName: g, totalInwardQty: 0, totalInwardValue: 0, currentStockQty: tcq, averageRate: tcq>0?tcv/tcq:0.0, closingValue: tcv);
    }
    return AverageCostResult(stockItemGuid: stockItem.stockItemGuid, itemName: stockItem.itemName, godowns: godownResults);
  }

  Future<AverageCostResult> calculateLifoCost({required StockItemInfo stockItem, required Map<String, Map<String, List<StockTransaction>>> godownTransactions, required String fromDate, required String toDate, required String companyGuid}) async {
    // Same as calculateFifoCost but with LIFO traversal — preserved from original
    Map<String, GodownAverageCost> godownResults = {};
    const fyStartMonth = 4, fyStartDay = 1;
    String getFyStart(String d) { final y = int.parse(d.substring(0,4)); final m = int.parse(d.substring(4,6)); return m < fyStartMonth ? '${y-1}${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}' : '$y${fyStartMonth.toString().padLeft(2,'0')}${fyStartDay.toString().padLeft(2,'0')}'; }
    Map<String, Map<String, double>> gbIQ = {}, gbOQ = {};
    Map<String, Map<String, List<StockLot>>> gbL = {};
    List<StockTransaction> all = [];
    for (var gm in godownTransactions.values) for (var bl in gm.values) all.addAll(bl);
    all.sort((a,b) => a.voucherId.compareTo(b.voucherId));
    Map<String, List<StockTransaction>> vb = {};
    for (var t in all) vb.putIfAbsent(t.voucherGuid, () => []).add(t);
    for (final od in stockItem.openingData) {
      String gn = od.godownName.isEmpty ? 'Main Location' : od.godownName;
      final oq = double.tryParse(od.actualQty) ?? 0.0; final bn = od.batchName;
      gbIQ.putIfAbsent(gn, () => {}); gbOQ.putIfAbsent(gn, () => {}); gbL.putIfAbsent(gn, () => {});
      gbIQ[gn]!.putIfAbsent(bn, () => 0.0); gbOQ[gn]!.putIfAbsent(bn, () => 0.0); gbL[gn]!.putIfAbsent(bn, () => []);
      gbIQ[gn]![bn] = gbIQ[gn]![bn]! + oq;
      if (oq > 0) gbL[gn]![bn]!.add(StockLot(voucherGuid: 'OPENING_STOCK', voucherDate: fromDate, voucherNumber: 'Opening Balance', voucherType: 'Opening', qty: oq, amount: od.amount, rate: od.amount/oq, type: StockInOutType.inward));
    }
    double calcLifo(List<StockLot> lots, double cq) {
      if (cq <= 0 || lots.isEmpty) { if (lots.isNotEmpty) return cq * lots.last.rate; return 0.0; }
      double cv = 0, rem = cq, tempOut = 0, lr = 0;
      for (int i = lots.length - 1; i >= 0 && rem > 0; i--) {
        final l = lots[i]; lr = l.rate;
        if (l.type == StockInOutType.outward) { tempOut += l.qty; }
        else { if (l.qty == 0) { cv += l.amount; } else if (tempOut <= 0) { if (l.qty <= rem) { cv += l.amount; rem -= l.qty; } else { cv += rem*l.rate; rem=0; } } else { if (l.qty <= tempOut) { tempOut -= l.qty; } else { final tq = l.qty - tempOut; tempOut = 0; if (tq <= rem) { cv += tq*l.rate; rem -= tq; } else { cv += rem*l.rate; rem=0; } } } }
      }
      if (rem > 0) cv += rem * lr;
      if (cv == 0 && cq > 0) { final tq = lots.fold(0.0,(s,l)=>s+l.qty); final tv = lots.fold(0.0,(s,l)=>s+l.amount); if (tq>0) cv = cq*(tv/tq); }
      return cv;
    }
    String curFy = ''; Set<String> processed = {};
    for (var txn in all) {
      final vg = txn.voucherGuid;
      if (processed.contains(vg) || txn.voucherType.toLowerCase().contains('purchase order') || txn.voucherType.toLowerCase().contains('sales order')) continue;
      processed.add(vg);
      final d = txn.voucherDate; final vt = txn.voucherType;
      if (d.compareTo(toDate) > 0) break;
      final fyS = getFyStart(d);
      if (fyS != curFy && curFy.isNotEmpty) {
        for (var g in gbIQ.keys) for (var bn in gbIQ[g]!.keys.toList()) {
          final iq=gbIQ[g]![bn]!; final oq=gbOQ[g]![bn]??0.0; final csq=iq-oq; final lots=gbL[g]![bn]??[];
          if (csq>0) { final cv=calcLifo(lots,csq); gbIQ[g]![bn]=csq; gbOQ[g]![bn]=0.0; gbL[g]![bn]=[StockLot(voucherGuid:'FY_OPENING_$fyS',voucherDate:fyS,voucherNumber:'FY Opening Balance',voucherType:'Opening',qty:csq,amount:cv,rate:cv/csq,type:StockInOutType.inward)]; }
          else if (csq<0) { double tv=0,tq=0; for(var l in lots){if(l.type==StockInOutType.inward){tv+=l.amount;tq+=l.qty;}} final cr=tq>0?tv/tq:0.0; gbIQ[g]![bn]=csq; gbOQ[g]![bn]=0.0; gbL[g]![bn]=[StockLot(voucherGuid:'FY_OPENING_$fyS',voucherDate:fyS,voucherNumber:'FY Opening Balance',voucherType:'Opening',qty:csq,amount:csq*cr,rate:cr,type:StockInOutType.inward)]; }
          else { gbIQ[g]![bn]=0.0; gbOQ[g]![bn]=0.0; gbL[g]![bn]=[]; }
        }
      }
      curFy = fyS;
      final isCN=creditNoteVoucherTypes.contains(vt); final isDN=debitNoteVoucherTypes.contains(vt);
      final isP=purchaseVoucherTypes.contains(vt); final isS=salesVoucherTypes.contains(vt);
      if (vt=='Physical Stock') continue;
      for (var bt in vb[vg]!) {
        final g=bt.godownName; final bn=bt.batchName; final amt=bt.amount; final qty=bt.stock; final isIn=bt.isInward; final absA=amt.abs();
        if (!bt.trackingNumber.toLowerCase().contains('not applicable') && (isP||isS||isDN||isCN)) continue;
        if ((isCN||isDN)&&qty==0&&amt==0) continue;
        gbIQ.putIfAbsent(g,()=>{}); gbOQ.putIfAbsent(g,()=>{}); gbL.putIfAbsent(g,()=>{});
        gbIQ[g]!.putIfAbsent(bn,()=>0.0); gbOQ[g]!.putIfAbsent(bn,()=>0.0); gbL[g]!.putIfAbsent(bn,()=>[]);
        if (isIn) { if (isCN) { gbOQ[g]![bn]=gbOQ[g]![bn]!-qty; final r=qty>0?absA/qty:0.0; gbL[g]![bn]!.add(StockLot(voucherGuid:vg,voucherDate:d,voucherNumber:txn.voucherNumber,voucherType:vt,qty:qty*-1,amount:amt*-1,rate:r,type:StockInOutType.outward)); } else { gbIQ[g]![bn]=gbIQ[g]![bn]!+qty; final r=qty>0?absA/qty:0.0; gbL[g]![bn]!.add(StockLot(voucherGuid:vg,voucherDate:d,voucherNumber:txn.voucherNumber,voucherType:vt,qty:qty,amount:absA,rate:r,type:StockInOutType.inward)); } }
        else { if (isDN) { gbIQ[g]![bn]=gbIQ[g]![bn]!-qty; final r=qty>0?absA/qty:0.0; gbL[g]![bn]!.add(StockLot(voucherGuid:vg,voucherDate:d,voucherNumber:txn.voucherNumber,voucherType:vt,qty:qty*-1,amount:amt*-1,rate:r,type:StockInOutType.inward)); } else { gbOQ[g]![bn]=gbOQ[g]![bn]!+qty; final r=qty>0?absA/qty:0.0; gbL[g]![bn]!.add(StockLot(voucherGuid:vg,voucherDate:d,voucherNumber:txn.voucherNumber,voucherType:vt,qty:qty,amount:absA,rate:r,type:StockInOutType.outward)); } }
      }
    }
    for (var g in gbIQ.keys) {
      double tcq=0, tcv=0;
      for (var bn in gbIQ[g]!.keys) {
        final iq=gbIQ[g]![bn]!; final oq=gbOQ[g]![bn]??0.0; final csq=iq-oq; final lots=gbL[g]![bn]??[];
        double bcv=0;
        if (csq>0) bcv=calcLifo(lots,csq);
        else if (csq<0) { double tv=0,tq=0; for(var l in lots){if(l.type==StockInOutType.inward){tv+=l.amount;tq+=l.qty;}} final cr=tq==0?0.0:tv/tq; bcv=csq*cr; }
        tcq+=csq; tcv+=bcv;
      }
      godownResults[g]=GodownAverageCost(godownName:g,totalInwardQty:0,totalInwardValue:0,currentStockQty:tcq,averageRate:tcq>0?tcv/tcq:0.0,closingValue:tcv);
    }
    return AverageCostResult(stockItemGuid:stockItem.stockItemGuid,itemName:stockItem.itemName,godowns:godownResults);
  }

  Future<AverageCostResult> calculateCostWithoutUnit({required StockItemInfo stockItem, required Map<String, Map<String, List<StockTransaction>>> godownTransactions, required String fromDate, required String toDate, required String companyGuid}) async {
    Map<String, GodownAverageCost> godownResults = {};
    Map<String, Map<String, double>> gbIV = {}, gbOV = {};
    List<StockTransaction> all = [];
    for (var gm in godownTransactions.values) for (var bl in gm.values) all.addAll(bl);
    all.sort((a,b) => a.voucherId.compareTo(b.voucherId));
    Map<String, List<StockTransaction>> vb = {};
    for (var t in all) vb.putIfAbsent(t.voucherGuid, () => []).add(t);
    for (final od in stockItem.openingData) {
      String gn = od.godownName.isEmpty ? 'Main Location' : od.godownName;
      gbIV.putIfAbsent(gn, () => {}); gbOV.putIfAbsent(gn, () => {});
      gbIV[gn]!.putIfAbsent(od.batchName, () => 0.0); gbOV[gn]!.putIfAbsent(od.batchName, () => 0.0);
      gbIV[gn]![od.batchName] = gbIV[gn]![od.batchName]! + od.amount;
    }
    Set<String> processed = {};
    for (var txn in all) {
      final vg = txn.voucherGuid;
      if (processed.contains(vg) || txn.voucherType.toLowerCase().contains('purchase order') || txn.voucherType.toLowerCase().contains('sales order')) continue;
      processed.add(vg);
      final d = txn.voucherDate; final vt = txn.voucherType;
      if (d.compareTo(toDate) > 0) break;
      if (vt == 'Physical Stock') continue;
      final isCN = creditNoteVoucherTypes.contains(vt); final isDN = debitNoteVoucherTypes.contains(vt);
      for (var bt in vb[vg]!) {
        final g = bt.godownName; final bn = bt.batchName; final absA = bt.amount.abs(); final isIn = bt.isInward;
        gbIV.putIfAbsent(g, () => {}); gbOV.putIfAbsent(g, () => {});
        gbIV[g]!.putIfAbsent(bn, () => 0.0); gbOV[g]!.putIfAbsent(bn, () => 0.0);
        if (isIn) { if (isCN) gbOV[g]![bn] = gbOV[g]![bn]! - absA; else gbIV[g]![bn] = gbIV[g]![bn]! + absA; }
        else { if (isDN) gbIV[g]![bn] = gbIV[g]![bn]! - absA; else gbOV[g]![bn] = gbOV[g]![bn]! + absA; }
      }
    }
    for (var g in gbIV.keys) {
      double ti = 0, to = 0;
      for (var bn in gbIV[g]!.keys) { ti += gbIV[g]![bn] ?? 0.0; to += gbOV[g]![bn] ?? 0.0; }
      godownResults[g] = GodownAverageCost(godownName: g, totalInwardQty: 0, totalInwardValue: ti, currentStockQty: 0, averageRate: 0.0, closingValue: ti - to);
    }
    return AverageCostResult(stockItemGuid: stockItem.stockItemGuid, itemName: stockItem.itemName, godowns: godownResults);
  }
Future<List<StockItemInfo>> fetchAllClosingStock(
    String companyGuid, String? closingDate) async {
  final db = await _db.database;

  final stockItemResults = await db.rawQuery('''
    SELECT 
      si.name as item_name,
      si.stock_item_guid,
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
      ON cb.stock_item_guid = si.stock_item_guid
      AND cb.company_guid = ?
      AND cb.closing_date = ?
    WHERE si.company_guid = ?
      AND si.is_deleted = 0
    ORDER BY si.name ASC
  ''', [companyGuid, companyGuid, closingDate ?? '', companyGuid]);

  return stockItemResults.map((row) => StockItemInfo(
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
  // ── P&L query (unchanged logic) ────────────────────────────────────────────

  Future<Map<String, dynamic>> _getProfitLossDetailed(
      String companyGuid, DateTime fromDate, DateTime toDate) async {
    final db = await _db.database;
    final fromStr = dateToString(fromDate);
    final toStr   = dateToString(toDate);

    String groupTree(String seedField, String seedValue) => '''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND $seedField = '$seedValue' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
    ''';

    // Purchase
    final purchResult = await db.rawQuery('''
      ${groupTree('reserved_name','Purchase Accounts')}
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
    ''', [companyGuid, companyGuid, companyGuid, fromStr, toStr]);

    final netPurchase = (purchResult.first['net_purchase'] as num?)?.toDouble() ?? 0.0;

    // Sales
    final salesResult = await db.rawQuery('''
      ${groupTree('reserved_name','Sales Accounts')}
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
    ''', [companyGuid, companyGuid, companyGuid, fromStr, toStr]);

    final netSales = (salesResult.first['net_sales'] as num?)?.toDouble() ?? 0.0;

    // Helper to fetch ledger group totals
    Future<List<Map<String, dynamic>>> fetchGroup(String groupName) => db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND name = '$groupName' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT l.name as ledger_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
        (l.opening_balance + COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
      FROM ledgers l INNER JOIN group_tree gt ON l.parent = gt.name
      INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid AND v.company_guid = l.company_guid
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.opening_balance ORDER BY closing_balance DESC
    ''', [companyGuid, companyGuid, fromStr, toStr, companyGuid]);

    Future<List<Map<String, dynamic>>> fetchIncomeGroup(String groupName) => db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND name = '$groupName' AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT l.name as ledger_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
        COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
        (l.opening_balance +
         COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
      FROM ledgers l INNER JOIN group_tree gt ON l.parent = gt.name
      INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid AND v.company_guid = l.company_guid
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= ? AND v.date <= ?
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.opening_balance
      HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
      ORDER BY closing_balance DESC
    ''', [companyGuid, companyGuid, fromStr, toStr, companyGuid]);

    final directExpenses   = await fetchGroup('Direct Expenses');
    final indirectExpenses = await fetchGroup('Indirect Expenses');
    final directIncomes    = await fetchIncomeGroup('Direct Incomes');
    final indirectIncomes  = await fetchIncomeGroup('Indirect Incomes');

    double sum(List<Map<String, dynamic>> rows) =>
        rows.fold(0.0, (s, r) => s + ((r['closing_balance'] as num?)?.toDouble() ?? 0.0));

    final totalDE  = sum(directExpenses).abs();
    final totalIE  = sum(indirectExpenses).abs();
    final totalDI  = sum(directIncomes);
    final totalII  = sum(indirectIncomes);

    double totalClosingStock = 0.0;
    double totalOpeningStock = 0.0;

    if (_isMaintainInventory) {
      // ── Inventory mode: use pre-calculated closing balances from stock_item_closing_balance ──
      final allItemClosings = await fetchAllClosingStock(_companyGuid!, toStr);
      totalClosingStock = allItemClosings.fold(0.0, (sum, item) => sum + item.closingValue);

      final prevDay = fromStr.compareTo(_companyStartDate) <= 0
          ? fromStr
          : getPreviousDate(fromStr);

      final allItemOpening = await fetchAllClosingStock(_companyGuid!, prevDay);
      totalOpeningStock = allItemOpening.fold(0.0, (sum, item) => sum + item.closingValue);
    } else {
      // ── Non-inventory mode: derive stock from ledger closing balances ──
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
      ''', [companyGuid, companyGuid, companyGuid, toStr]);
      totalClosingStock = (closingResult.first['total_closing_stock'] as num?)?.toDouble() ?? 0.0;

      final prevDay = fromStr.compareTo(_companyStartDate) <= 0 ? _companyStartDate : getPreviousDate(fromStr);
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

    final grossProfit = (netSales + totalDI + totalClosingStock) -
        (totalOpeningStock + netPurchase + totalDE);
    final netProfit = grossProfit + totalII - totalIE;

    return {
      'opening_stock': totalOpeningStock,
      'purchase': netPurchase,
      'direct_expenses': directExpenses,
      'direct_expenses_total': totalDE,
      'gross_profit': grossProfit,
      'closing_stock': totalClosingStock,
      'sales': netSales,
      'indirect_expenses': indirectExpenses,
      'indirect_expenses_total': totalIE,
      'indirect_incomes': indirectIncomes,
      'indirect_incomes_total': totalII,
      'direct_incomes': directIncomes,
      'direct_incomes_total': totalDI,
      'net_profit': netProfit,
    };
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _navigateToGroup(String groupName) {
    if (_companyGuid == null || _companyName == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GroupDetailScreen(
        companyGuid: _companyGuid!,
        companyName: _companyName!,
        groupName: groupName,
        fromDate: dateToString(_fromDate),
        toDate: dateToString(_toDate),
      ),
    ));
  }

  void _navigateToStockSummary() {
    if (_companyGuid == null) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => StockSummaryScreen()));
  }

  // ── Date selection ─────────────────────────────────────────────────────────

  Future<void> _selectDateRange() async {
    DateTime tempFrom = _fromDate;
    DateTime tempTo   = _toDate;

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
                  // Title
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.date_range_rounded, color: _primary, size: 20)),
                    const SizedBox(width: 12),
                    Text('Select Period', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ]),
                  const SizedBox(height: 20),

                  // Quick filter chips
                  Text('Quick Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _qChip('This Month', () { final n = DateTime.now(); setDs(() { tempFrom = DateTime(n.year, n.month, 1); tempTo = DateTime(n.year, n.month+1, 0); }); }),
                    _qChip('Last Month', () { final n = DateTime.now(); setDs(() { tempFrom = DateTime(n.year, n.month-1, 1); tempTo = DateTime(n.year, n.month, 0); }); }),
                    _qChip('Q1', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 4, 1); tempTo = DateTime(y, 6, 30); }); }),
                    _qChip('Q2', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 7, 1); tempTo = DateTime(y, 9, 30); }); }),
                    _qChip('Q3', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y, 10, 1); tempTo = DateTime(y, 12, 31); }); }),
                    _qChip('Q4', () { final y = DateTime.now().year; setDs(() { tempFrom = DateTime(y+1, 1, 1); tempTo = DateTime(y+1, 3, 31); }); }),
                    _qChip('Full FY', () { setDs(() { tempFrom = getFyStartDate(DateTime.now()); tempTo = getFyEndDate(DateTime.now()); }); }),
                  ]),

                  const SizedBox(height: 22),
                  Text('Custom Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                  const SizedBox(height: 10),

                  // From date
                  _datePickerTile('From', tempFrom, () async {
                    final p = await showDatePicker(context: ctx,
                      initialDate: tempFrom, firstDate: DateTime(2000), lastDate: DateTime(2100),
                      builder: (c,child) { final dk = Theme.of(c).brightness == Brightness.dark; return Theme(data: Theme.of(c).copyWith(colorScheme: dk ? ColorScheme.dark(primary: _primary, onPrimary: Colors.white, surface: AppColors.surface, onSurface: AppColors.textPrimary) : ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary)), child: child!); });
                    if (p != null) setDs(() => tempFrom = p);
                  }),
                  const SizedBox(height: 10),

                  // To date
                  _datePickerTile('To', tempTo, () async {
                    final p = await showDatePicker(context: ctx,
                      initialDate: tempTo, firstDate: DateTime(2000), lastDate: DateTime(2100),
                      builder: (c,child) { final dk = Theme.of(c).brightness == Brightness.dark; return Theme(data: Theme.of(c).copyWith(colorScheme: dk ? ColorScheme.dark(primary: _primary, onPrimary: Colors.white, surface: AppColors.surface, onSurface: AppColors.textPrimary) : ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary)), child: child!); });
                    if (p != null) setDs(() => tempTo = p);
                  }),

                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () {
                        if (tempFrom.isAfter(tempTo)) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: _debitCol,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            content: const Text('From date must be before To date')));
                          return;
                        }
                        setState(() { _fromDate = tempFrom; _toDate = tempTo; });
                        Navigator.pop(ctx);
                        _loadData();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0,
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

  Widget _qChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primary.withOpacity(0.2)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
      ),
    );
  }

  Widget _datePickerTile(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider)),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 16, color: _primary),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(_displayDate(date), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';

  String _formatDate(String d) {
    if (d.length != 8) return d;
    return '${d.substring(6)}-${d.substring(4,6)}-${d.substring(0,4)}';
  }

  String _fmt(double amount) {
    final neg = amount < 0;
    final f = amount.abs().toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${neg ? '-' : ''}₹$f';
  }

  double _calculateTotal() {
    return (_plData?['opening_stock'] ?? 0.0) +
        (_plData?['purchase'] ?? 0.0) +
        (_plData?['direct_expenses_total'] ?? 0.0) +
        (_plData?['indirect_expenses_total'] ?? 0.0) +
        (_plData?['net_profit'] ?? 0.0);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    syncBrightness(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    final netProfit   = (_plData?['net_profit'] ?? 0.0) as double;
    final grossProfit = (_plData?['gross_profit'] ?? 0.0) as double;
    final isProfit    = netProfit >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          child: Column(
            children: [
              _buildHeaderBanner(netProfit, grossProfit, isProfit),
              const SizedBox(height: 16),

              // ── Trading Account (Gross Profit) ─────────────────────────
              _buildSectionTitle('Trading Account'),
              const SizedBox(height: 8),
              _buildTwoColumnCard(
                leftChildren: [
                  _plRow('Opening Stock', _plData?['opening_stock'] ?? 0.0,
                      onTap: () => _navigateToStockSummary()),
                  _plRow('Purchase Accounts', _plData?['purchase'] ?? 0.0,
                      onTap: () => _navigateToGroup('Purchase Accounts')),
                  _expandableGroup(
                    label: 'Direct Expenses',
                    total: _plData?['direct_expenses_total'] ?? 0.0,
                    rows: _plData?['direct_expenses'] as List<Map<String,dynamic>>? ?? [],
                    expanded: _showDirectExpDetail,
                    onToggle: () => setState(() => _showDirectExpDetail = !_showDirectExpDetail),
                    onGroupTap: () => _navigateToGroup('Direct Expenses'),
                    isExpense: true,
                  ),
                ],
                rightChildren: [
                  _plRow('Sales Accounts', _plData?['sales'] ?? 0.0,
                      onTap: () => _navigateToGroup('Sales Accounts')),
                  _plRow('Closing Stock', _plData?['closing_stock'] ?? 0.0,
                      onTap: () => _navigateToStockSummary()),
                  _expandableGroup(
                    label: 'Direct Incomes',
                    total: _plData?['direct_incomes_total'] ?? 0.0,
                    rows: _plData?['direct_incomes'] as List<Map<String,dynamic>>? ?? [],
                    expanded: _showDirectIncDetail,
                    onToggle: () => setState(() => _showDirectIncDetail = !_showDirectIncDetail),
                    onGroupTap: () => _navigateToGroup('Direct Incomes'),
                    isExpense: false,
                  ),
                ],
                summaryLabel: 'Gross',
                summaryValue: grossProfit,
              ),

              const SizedBox(height: 16),

              // ── P&L Account (Net Profit) ───────────────────────────────
              _buildSectionTitle('Profit & Loss Account'),
              const SizedBox(height: 8),
              _buildTwoColumnCard(
                leftChildren: [
                  _expandableGroup(
                    label: 'Indirect Expenses',
                    total: _plData?['indirect_expenses_total'] ?? 0.0,
                    rows: _plData?['indirect_expenses'] as List<Map<String,dynamic>>? ?? [],
                    expanded: _showIndirectExpDetail,
                    onToggle: () => setState(() => _showIndirectExpDetail = !_showIndirectExpDetail),
                    onGroupTap: () => _navigateToGroup('Indirect Expenses'),
                    isExpense: true,
                  ),
                  _netProfitRow(netProfit, isProfit),
                ],
                rightChildren: [
                  _grossTransferRow(grossProfit),
                  _expandableGroup(
                    label: 'Indirect Incomes',
                    total: _plData?['indirect_incomes_total'] ?? 0.0,
                    rows: _plData?['indirect_incomes'] as List<Map<String,dynamic>>? ?? [],
                    expanded: _showIndirectIncDetail,
                    onToggle: () => setState(() => _showIndirectIncDetail = !_showIndirectIncDetail),
                    onGroupTap: () => _navigateToGroup('Indirect Incomes'),
                    isExpense: false,
                  ),
                ],
                summaryLabel: 'Net',
                summaryValue: netProfit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Profit & Loss A/c',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      actions: [
        // Period pill — tap to change
        GestureDetector(
          onTap: _selectDateRange,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.date_range_rounded, size: 14, color: _primary),
              const SizedBox(width: 5),
              Text(
                '${_displayDate(_fromDate)} → ${_displayDate(_toDate)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primary),
              ),
            ]),
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
          onPressed: _loadData,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }

  Widget _buildHeaderBanner(double netProfit, double grossProfit, bool isProfit) {
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
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_companyName ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                '${_formatDate(dateToString(_fromDate))} → ${_formatDate(dateToString(_toDate))}',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _bannerPill('Sales', _plData?['sales'] ?? 0.0, Colors.white.withOpacity(0.2)),
                const SizedBox(width: 8),
                _bannerPill('Purchase', _plData?['purchase'] ?? 0.0, Colors.white.withOpacity(0.2)),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Column(children: [
              Text(isProfit ? 'Net Profit' : 'Net Loss',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75))),
              const SizedBox(height: 4),
              Text(_fmt(netProfit.abs()),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bannerPill(String label, double amount, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text('$label: ${_fmt(amount)}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(width: 4, height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _accent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.2)),
      ]),
    );
  }

  Widget _buildTwoColumnCard({
    required List<Widget> leftChildren,
    required List<Widget> rightChildren,
    required String summaryLabel,
    required double summaryValue,
  }) {
    final isPos = summaryValue >= 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,3))],
      ),
      child: Column(children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _colHeader('Debit Side'),
                ...leftChildren,
              ],
            )),
            // Vertical divider
            Container(width: 1, color: AppColors.divider),
            // Right
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _colHeader('Credit Side'),
                ...rightChildren,
              ],
            )),
          ]),
        ),
        // Summary footer
        Container(
          decoration: BoxDecoration(
            color: isPos ? _netBg : _netLossBg,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            border: Border(top: BorderSide(color: (isPos ? _netC : _netLossC).withOpacity(0.2))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$summaryLabel ${isPos ? 'Profit' : 'Loss'}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: isPos ? _netC : _netLossC)),
            Text(_fmt(summaryValue.abs()),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: isPos ? _netC : _netLossC)),
          ]),
        ),
      ]),
    );
  }

  Widget _colHeader(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pillBg,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _plRow(String label, double amount, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          Expanded(child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          if (onTap != null) Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(_fmt(amount),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ]),
      ),
    );
  }

  Widget _expandableGroup({
    required String label,
    required double total,
    required List<Map<String, dynamic>> rows,
    required bool expanded,
    required VoidCallback onToggle,
    required VoidCallback onGroupTap,
    required bool isExpense,
  }) {
    return Column(children: [
      InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            GestureDetector(
              onTap: onGroupTap,
              child: const Icon(Icons.open_in_new_rounded, size: 13, color: _primary),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(_fmt(total),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isExpense ? _debitCol : _creditCol)),
          ]),
        ),
      ),
      if (expanded) ...rows.map((r) {
        final closing = (r['closing_balance'] as num?)?.toDouble() ?? 0.0;
        return Padding(
          padding: const EdgeInsets.only(left: 28, right: 12, bottom: 6),
          child: Row(children: [
            Expanded(child: Text(r['ledger_name'] as String? ?? '',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(_fmt(closing.abs()),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                    color: isExpense ? _debitCol : _creditCol)),
          ]),
        );
      }).toList(),
    ]);
  }

  Widget _grossTransferRow(double amount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _grossBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _grossC.withOpacity(0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Gross Profit b/f',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grossC)),
        Text(_fmt(amount),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grossC)),
      ]),
    );
  }

  Widget _netProfitRow(double amount, bool isProfit) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isProfit ? _netBg : _netLossBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isProfit ? _netC : _netLossC).withOpacity(0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(isProfit ? 'Net Profit' : 'Net Loss',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: isProfit ? _netC : _netLossC)),
        Text(_fmt(amount.abs()),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: isProfit ? _netC : _netLossC)),
      ]),
    );
  }
}