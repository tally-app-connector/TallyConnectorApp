// import 'package:flutter/material.dart';
// import '../../models/data_model.dart';
// import '../../database/database_helper.dart';
// import '../../utils/date_utils.dart';
// import 'group_detail_screen.dart';

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
//       SELECT guid, name
//       FROM voucher_types
//       WHERE company_guid = ?
//         AND (name = ? OR reserved_name = ?)
//         AND is_deleted = 0
      
//       UNION ALL
      
//       SELECT vt.guid, vt.name
//       FROM voucher_types vt
//       INNER JOIN voucher_type_tree vtt ON vt.parent_guid = vtt.guid
//       WHERE vt.company_guid = ?
//         AND vt.is_deleted = 0
//         AND vt.guid != vt.parent_guid  -- Prevent self-referencing loop
//     )
//     SELECT name FROM voucher_type_tree ORDER BY name
//   ''', [companyGuid, voucherTypeName, voucherTypeName, companyGuid]);

//   return result.map((row) => row['name'] as String).toList();
// }

// Future<List<StockItemInfo>> fetchAllStockItems(String companyGuid) async {
//   final db = await _db.database;

//   // Fetch stock items that have opening batch allocations or at least one voucher
//   final stockItemResults = await db.rawQuery('''
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

//   Future<Map<String, Map<String, List<StockTransaction>>>> buildStockDirectory(
//     String companyGuid,
//     String endDate,
//     List<StockItemInfo> stockItems
//   ) async {

//     Map<String, Map<String, List<StockTransaction>>> directory = {};

//     for (var item in stockItems) {
//       final transactions = await fetchTransactionsForStockItem(
//         companyGuid,
//         item.stockItemGuid,
//         endDate,
//       );

//       // Organize transactions by godown
//       Map<String, List<StockTransaction>> godownTransactions = {};

//       for (var transaction in transactions) {
//         if (!godownTransactions.containsKey(transaction.godownName)) {
//           godownTransactions[transaction.godownName] = [];
//         }
//         godownTransactions[transaction.godownName]!.add(transaction);
//       }

//       // Add to directory
//       directory[item.stockItemGuid] = godownTransactions;
//     }

//     return directory;
//   }

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

//     // Build directory
//     final directory = await buildStockDirectory(companyGuid, toDate, stockItems);

//     List<AverageCostResult> results = [];

//     for (var stockItem in stockItems) {

//       final godownTransactions = directory[stockItem.stockItemGuid]!;

//       if (stockItem.unit.toLowerCase().contains('not applicable')){
//     final result = await calculateCostWithoutUnit(
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

// Future<AverageCostResult> calculateLifoCost({
//   required StockItemInfo stockItem,
//   required Map<String, List<StockTransaction>> godownTransactions,
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

//   // Per godown tracking
//   Map<String, double> totalInwardQty = {};
//   Map<String, double> totalOutwardQty = {};
//   Map<String, List<StockLot>> stockLots = {};

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
//         type: StockInOutType.inward,
//       ));
//     }
//   }

//   String currentFyStart = '';

//   // Helper function to calculate closing value using LIFO logic
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
//         if (lot.qty == 0){
//         closingValue += lot.amount;
//       }else if (tempOutWardQty <= 0) {
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

//     if (remainingQty > 0){
//       closingValue += remainingQty * lastRate;
//     }

//     if (closingValue == 0 && closingStockQty > 0){
//       final totalQty = lots.fold(0.0, (sum, lot) => sum + lot.qty);
//       final totalValue = lots.fold(0.0, (sum, lot) => sum + lot.amount);

//       closingValue = closingStockQty * (totalValue/ totalQty);
//     }

//     return closingValue;
//   }

//   // Process transactions
//   Set<String> processedVouchers = {};

//   for (var txn in allTransactions) {
//     final voucherGuid = txn.voucherGuid;

//     if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) {
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

//     // Check for FY boundary - reset stock valuation
//     if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
//       // Calculate closing for each godown and reset
//       for (var godown in totalInwardQty.keys) {
//         final inwardQty = totalInwardQty[godown]!;
//         final outwardQty = totalOutwardQty[godown]!;
//         final closingStockQty = inwardQty - outwardQty;

//         if (closingStockQty > 0) {
//           final lots = stockLots[godown]!;
//           final closingValue = calculateLifoClosingValue(lots, closingStockQty);
//           final closingRate = closingValue / closingStockQty;

//           // Reset with closing as new opening
//           totalInwardQty[godown] = closingStockQty;
//           totalOutwardQty[godown] = 0.0;
//           stockLots[godown] = [
//             StockLot(
//               voucherGuid: 'FY_OPENING_$txnFyStart',
//               voucherDate: txnFyStart,
//               voucherNumber: 'FY Opening Balance',
//               voucherType: 'Opening',
//               qty: closingStockQty,
//               amount: closingValue,
//               rate: closingRate,
//               type: StockInOutType.inward,
//             )
//           ];
//         }else if (closingStockQty < 0) {
//           // Negative stock: use Average Cost method
//           final lots = stockLots[godown]!;
//           double totalLotValue = 0.0;
//           double totalLotQty = 0.0;
//           for (var lot in lots) {
//             if (lot.type == StockInOutType.inward) {
//               totalLotValue += lot.amount;
//               totalLotQty += lot.qty;
//             }
//           }
//           final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
//           final closingValue = closingStockQty * closingRate;

//           // Reset with negative opening
//           totalInwardQty[godown] = closingStockQty;
//           totalOutwardQty[godown] = 0.0;
//           stockLots[godown] = [
//             StockLot(
//               voucherGuid: 'FY_OPENING_$txnFyStart',
//               voucherDate: txnFyStart,
//               voucherNumber: 'FY Opening Balance',
//               voucherType: 'Opening',
//               qty: closingStockQty,
//               amount: closingValue,
//               rate: closingRate,
//               type: StockInOutType.inward,
//             )
//           ];
//         } else {
//           // No stock, reset to zero
//           totalInwardQty[godown] = 0.0;
//           totalOutwardQty[godown] = 0.0;
//           stockLots[godown] = [];
//         }
//       }
//     }

//     currentFyStart = txnFyStart;
//     final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
//     final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
//     final isPurchase = purchaseVoucherTypes.contains(voucherType);
//     final isSales = salesVoucherTypes.contains(voucherType);
//     final batches = voucherBatches[voucherGuid]!;

//     if (voucherType == 'Physical Stock') {
//       continue;
//     }

//     for (var batch in batches) {
//       final godown = batch.godownName;
//       final amount = batch.amount;
//       final qty = batch.stock;
//       final isInward = batch.isInward;
//       final absAmount = amount.abs();


//       if (batch.trackingNumber.toLowerCase().contains('not applicable') == false && (isPurchase || isSales || isDebitNote || isCreditNote)) continue;

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
//         if (isCreditNote) {
//           totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           stockLots[godown]!.add(StockLot(
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
//             type: StockInOutType.inward,
//           ));
//         }
//       } else {
//         if (isDebitNote) {
//           totalInwardQty[godown] = totalInwardQty[godown]! - qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           stockLots[godown]!.add(StockLot(
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
//             type: StockInOutType.outward,
//           ));        
//         }
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
//       closingValue = calculateLifoClosingValue(lots, closingStockQty);
//     } else if (closingStockQty < 0) {
//       // Negative stock: use Average Cost method
//       double totalLotValue = 0.0;
//       double totalLotQty = 0.0;
//       for (var lot in lots) {
//         totalLotValue += lot.amount;
//         totalLotQty += lot.qty;
//       }
//       final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
//       closingValue = closingStockQty * closingRate;
//     }

//     godownResults[godown] = GodownAverageCost(
//       godownName: godown,
//       totalInwardQty: inwardQty,
//       totalInwardValue: 0,
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

// Future<AverageCostResult> calculateFifoCost({
//   required StockItemInfo stockItem,
//   required Map<String, List<StockTransaction>> godownTransactions,
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




//   // Per godown tracking
//   Map<String, double> totalInwardQty = {};
//   Map<String, double> totalOutwardQty = {};
//   Map<String, List<StockLot>> inwardLots = {}; // Only inward lots

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
//     inwardLots[godownName] = [];

//     if (openingQty > 0) {
//       final openingRate = openingAmount / openingQty;
//       inwardLots[godownName]!.add(StockLot(
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

//   // Helper function to calculate closing value using FIFO logic (backwards from last)
//   double calculateFifoClosingValue(List<StockLot> lots, double closingStockQty) {
   
//     if (closingStockQty <= 0 || lots.isEmpty) {
//       return 0.0;
//     }

//     double closingValue = 0.0;
//     double remainingQty = closingStockQty;
//     double lastRate = 0.0;

//     // FIFO: Go backwards from LAST inward lot (newest first)
//     for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
//       final lot = lots[i];
//       lastRate = lot.rate;

//       if (lot.qty == 0){
//         closingValue += lot.amount;
//       }else if (lot.qty <= remainingQty) {
//         // Take entire lot
//         closingValue += lot.amount;
//         remainingQty -= lot.qty;
//       } else {
//         // Take partial lot
//         closingValue += remainingQty * lot.rate;
//         remainingQty = 0;
//       }
//     }

//     if (remainingQty > 0){
//       closingValue += remainingQty * lastRate;
//     }

//     if (closingValue == 0 && closingStockQty > 0){
//       final totalQty = lots.fold(0.0, (sum, lot) => sum + lot.qty);
//       final totalValue = lots.fold(0.0, (sum, lot) => sum + lot.amount);

//       closingValue = closingStockQty * (totalValue/ totalQty);
//     }

//     return closingValue;
//   }

//   // Process transactions
//   Set<String> processedVouchers = {};

//   for (var txn in allTransactions) {

//     final voucherGuid = txn.voucherGuid;

//     if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) {
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

//     // Check for FY boundary - reset stock valuation
//     if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
//       // Calculate closing for each godown and reset
//       for (var godown in totalInwardQty.keys) {
//         final inwardQty = totalInwardQty[godown]!;
//         final outwardQty = totalOutwardQty[godown]!;
//         final closingStockQty = inwardQty - outwardQty;

//         if (closingStockQty > 0) {
//           final lots = inwardLots[godown]!;
//           final closingValue = calculateFifoClosingValue(lots, closingStockQty);
//           final closingRate = closingValue / closingStockQty;

//           // Reset with closing as new opening
//           totalInwardQty[godown] = closingStockQty;
//           totalOutwardQty[godown] = 0.0;
//           inwardLots[godown] = [
//             StockLot(
//               voucherGuid: 'FY_OPENING_$txnFyStart',
//               voucherDate: txnFyStart,
//               voucherNumber: 'FY Opening Balance',
//               voucherType: 'Opening',
//               qty: closingStockQty,
//               amount: closingValue,
//               rate: closingRate,
//               type: StockInOutType.inward,
//             )
//           ];
//         }else if (closingStockQty < 0) {
//           // Negative stock: use Average Cost method
//           final lots = inwardLots[godown]!;
//           double totalLotValue = 0.0;
//           double totalLotQty = 0.0;
//           for (var lot in lots) {
//             totalLotValue += lot.amount;
//             totalLotQty += lot.qty;
//           }
//           final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
//           final closingValue = closingStockQty * closingRate;

//           // Reset with negative opening
//           totalInwardQty[godown] = closingStockQty;
//           totalOutwardQty[godown] = 0.0;
//           inwardLots[godown] = [
//             StockLot(
//               voucherGuid: 'FY_OPENING_$txnFyStart',
//               voucherDate: txnFyStart,
//               voucherNumber: 'FY Opening Balance',
//               voucherType: 'Opening',
//               qty: closingStockQty,
//               amount: closingValue,
//               rate: closingRate,
//               type: StockInOutType.inward,
//             )
//           ];
//         } else {
//           // No stock, reset to zero
//           totalInwardQty[godown] = 0.0;
//           totalOutwardQty[godown] = 0.0;
//           inwardLots[godown] = [];
//         }
//       }
//     }

//     currentFyStart = txnFyStart;

//     final isPurchase = purchaseVoucherTypes.contains(voucherType);
//     final isSales = salesVoucherTypes.contains(voucherType);
//     final batches = voucherBatches[voucherGuid]!;
//     final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
//     final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

//     if (voucherType == 'Physical Stock') {
//       continue;
//     }

//     for (var batch in batches) {
//       final godown = batch.godownName;
//       final amount = batch.amount;
//       final qty = batch.stock;
//       final isInward = batch.isInward;
//       final absAmount = amount.abs();
          
//       if (batch.trackingNumber.toLowerCase().contains('not applicable') == false && (isPurchase || isSales || isDebitNote || isCreditNote)) continue;

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

//       if (!inwardLots.containsKey(godown)) {
//         inwardLots[godown] = [];
//       }

//       if (isInward) {
//         if (isCreditNote) {
//           totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
//         } else {
//           // Add to inward qty and store lot
//           totalInwardQty[godown] = totalInwardQty[godown]! + qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           inwardLots[godown]!.add(StockLot(
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
//           totalInwardQty[godown] = totalInwardQty[godown]! - qty;

//           final rate = qty > 0 ? absAmount / qty : 0.0;
//           inwardLots[godown]!.add(StockLot(
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
//           // Just track outward qty, no need to store lot
//           totalOutwardQty[godown] = totalOutwardQty[godown]! + qty;
//         }
//       }
//     }
//   }

//   // Calculate closing stock and value for each godown
//   for (var godown in totalInwardQty.keys) {
//     final inwardQty = totalInwardQty[godown]!;
//     final outwardQty = totalOutwardQty[godown]!;
//     final closingStockQty = inwardQty - outwardQty;

//     double closingValue = 0.0;
//     final lots = inwardLots[godown]!;

//     if (closingStockQty > 0) {
//       closingValue = calculateFifoClosingValue(lots, closingStockQty);
//     }else if (closingStockQty < 0) {
//       // Negative stock: use Average Cost method
//       double totalLotValue = 0.0;
//       double totalLotQty = 0.0;
//       for (var lot in lots) {
//         totalLotValue += lot.amount;
//         totalLotQty += lot.qty;
//       }
//       final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
//       closingValue = closingStockQty * closingRate;
//     }

//     godownResults[godown] = GodownAverageCost(
//       godownName: godown,
//       totalInwardQty: inwardQty,
//       totalInwardValue: 0,
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

//   Future<AverageCostResult> calculateAvgCost({
//     required StockItemInfo stockItem,
//     required Map<String, List<StockTransaction>> godownTransactions,
//     required String fromDate,
//     required String toDate,
//     required String companyGuid,
//   }) async {
//     Map<String, GodownAverageCost> godownResults = {};

//     Map<String, double> totalInwardQty = {};
//     Map<String, double> totalInwardValue = {};
//     Map<String, double> totalOutwardQty = {};

//     const financialYearStartMonth = 4;
//     const financialYearStartDay = 1;

//     String getFinancialYearStartDate(String dateStr) {
//       final year = int.parse(dateStr.substring(0, 4));
//       final month = int.parse(dateStr.substring(4, 6));

//       if (month < financialYearStartMonth) {
//         return '${year - 1}${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
//       } else {
//         return '$year${financialYearStartMonth.toString().padLeft(2, '0')}${financialYearStartDay.toString().padLeft(2, '0')}';
//       }
//     }

//     // Flatten all transactions and sort by date
//     List<StockTransaction> allTransactions = [];
//     for (var godownTxns in godownTransactions.values) {
//       allTransactions.addAll(godownTxns);
//     }
//     allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

//     // Group transactions by voucher_guid
//     Map<String, List<StockTransaction>> voucherBatches = {};
//     for (var txn in allTransactions) {
//       if (!voucherBatches.containsKey(txn.voucherGuid)) {
//         voucherBatches[txn.voucherGuid] = [];
//       }
//       voucherBatches[txn.voucherGuid]!.add(txn);
//     }

//     // Initialize with opening stock
//     for (final godownOpeningData in stockItem.openingData) {

//       String godownName = godownOpeningData.godownName;
//       if (godownName.isEmpty) {
//         godownName = 'Main Location';
//       }

//       final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
//       final openingAmount = godownOpeningData.amount;

//       if (!totalInwardQty.containsKey(godownName)) {
//           totalInwardQty[godownName] = 0.0;
//           totalInwardValue[godownName] = 0.0;
//         }

//       totalInwardQty[godownName] = totalInwardQty[godownName]! + openingQty;
//       totalInwardValue[godownName] = totalInwardValue[godownName]! + openingAmount;
//       totalOutwardQty[godownName] = 0.0;
//     }

//     String currentFyStart = '';

//     // Process transactions
//     Set<String> processedVouchers = {};

//     for (var txn in allTransactions) {
//       final voucherGuid = txn.voucherGuid;

//       if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) {
//         continue;
//       }
//       processedVouchers.add(voucherGuid);

//       final dateStr = txn.voucherDate;
//       final voucherType = txn.voucherType;

//       if (dateStr.compareTo(toDate) > 0) {
//         break;
//       }

//       final txnFyStart = getFinancialYearStartDate(dateStr);

//       // Check for FY boundary - reset rate
//       if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
//         // Calculate closing for previous FY and reset as opening for new FY
//         for (var godown in totalInwardQty.keys) {
//           final inwardQty = totalInwardQty[godown]!;
//           final inwardValue = totalInwardValue[godown]!;
//           final outwardQty = totalOutwardQty[godown]!;
//           final closingQty = inwardQty - outwardQty;

//           final closingRate = inwardQty > 0 ? inwardValue / inwardQty : 0.0;
//           final closingValue = closingQty * closingRate;

//           // Reset: closing becomes new opening
//           totalInwardQty[godown] = closingQty;
//           totalInwardValue[godown] = closingValue;
//           totalOutwardQty[godown] = 0.0;
//         }
//       }

//       currentFyStart = txnFyStart;

//     final isPurchase = purchaseVoucherTypes.contains(voucherType);
//     final isSales = salesVoucherTypes.contains(voucherType);
//     final batches = voucherBatches[voucherGuid]!;
//     final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
//     final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

//       if (voucherType == 'Physical Stock') {
//         continue;
//       }

//       for (var batch in batches) {
//         final godown = batch.godownName;
//         final amount = batch.amount;
//         final qty = batch.stock;
//         final isInward = batch.isInward;
//         final absAmount = amount.abs();

//         if (batch.trackingNumber.toLowerCase().contains('not applicable') == false && (isPurchase || isSales || isDebitNote || isCreditNote)) continue;

//         if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
//           continue;
//         }

//         // Initialize godown if not exists
//         if (!totalInwardQty.containsKey(godown)) {
//           totalInwardQty[godown] = 0.0;
//           totalInwardValue[godown] = 0.0;
//         }

//         if (!totalOutwardQty.containsKey(godown)) {
//           totalOutwardQty[godown] = 0.0;
//         }

//         if (isInward) {
//           if (isCreditNote) {
//             totalOutwardQty[godown] = totalOutwardQty[godown]! - qty;
//           } else {
//             totalInwardQty[godown] = totalInwardQty[godown]! + qty;
//             totalInwardValue[godown] = totalInwardValue[godown]! + absAmount;
//           }
//         } else {
//           // OUTWARD: Add to total outward qty
//           if (isDebitNote) {
//             totalInwardQty[godown] = totalInwardQty[godown]! - qty;
//             totalInwardValue[godown] = totalInwardValue[godown]! - absAmount;
//           } else {
//             totalOutwardQty[godown] = totalOutwardQty[godown]! + qty;
//           }
//         }
//       }
//     }

//     // Calculate closing stock and value for each godown
//     for (var godown in totalInwardQty.keys) {
//       final inwardQty = totalInwardQty[godown]!;
//       final inwardValue = totalInwardValue[godown]!;
//       final outwardQty = totalOutwardQty[godown]!;
//       final closingStockQty = inwardQty - outwardQty;
//       final closingRate = inwardQty > 0 ? inwardValue / inwardQty : 0.0;

//       godownResults[godown] = GodownAverageCost(
//         godownName: godown,
//         totalInwardQty: inwardQty,
//         totalInwardValue: 0,
//         currentStockQty: closingStockQty,
//         averageRate: closingRate > 0 ? closingRate : 0.0,
//         closingValue: closingStockQty * closingRate,
//       );
//     }

//     return AverageCostResult(
//       stockItemGuid: stockItem.stockItemGuid,
//       itemName: stockItem.itemName,
//       godowns: godownResults,
//     );
//   }

//   Future<AverageCostResult> calculateCostWithoutUnit({
//     required StockItemInfo stockItem,
//     required Map<String, List<StockTransaction>> godownTransactions,
//     required String fromDate,
//     required String toDate,
//     required String companyGuid,
//   }) async {
//     Map<String, GodownAverageCost> godownResults = {};

//     Map<String, double> totalInwardValue = {};
//     Map<String, double> totalOutwardValue = {};


//     // Flatten all transactions and sort by date
//     List<StockTransaction> allTransactions = [];
//     for (var godownTxns in godownTransactions.values) {
//       allTransactions.addAll(godownTxns);
//     }
//     allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

//     // Group transactions by voucher_guid
//     Map<String, List<StockTransaction>> voucherBatches = {};
//     for (var txn in allTransactions) {
//       if (!voucherBatches.containsKey(txn.voucherGuid)) {
//         voucherBatches[txn.voucherGuid] = [];
//       }
//       voucherBatches[txn.voucherGuid]!.add(txn);
//     }

//     // Initialize with opening stock
//     for (final godownOpeningData in stockItem.openingData) {
//       String godownName = godownOpeningData.godownName;
//       if (godownName.isEmpty) {
//         godownName = 'Main Location';
//       }

//       final openingAmount = godownOpeningData.amount;

//       totalInwardValue[godownName] = openingAmount;
//     }


//     // Process transactions
//     Set<String> processedVouchers = {};

//     for (var txn in allTransactions) {
//       final voucherGuid = txn.voucherGuid;

//       if (processedVouchers.contains(voucherGuid) || txn.voucherType.toLowerCase().contains('purchase order')  || txn.voucherType.toLowerCase().contains('sales order')) {
//         continue;
//       }
//       processedVouchers.add(voucherGuid);

//       final dateStr = txn.voucherDate;
//       final voucherType = txn.voucherType;

//       if (dateStr.compareTo(toDate) > 0) {
//         break;
//       }

//       final batches = voucherBatches[voucherGuid]!;
          
//       if (voucherType == 'Physical Stock') {
//         continue;
//       }

//       for (var batch in batches) {
//         final godown = batch.godownName;
//         final amount = batch.amount;
//         final isInward = batch.isInward;
//         final absAmount = amount.abs();

//           final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
//           final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
     
//       if (!totalInwardValue.containsKey(godown)) {
//           totalInwardValue[godown] = 0.0;
//         }

//         if (!totalOutwardValue.containsKey(godown)) {
//           totalOutwardValue[godown] = 0.0;
//         }
//     if (isInward) {
//           if (isCreditNote) {
//             totalOutwardValue[godown] = totalOutwardValue[godown]! - absAmount;
//           } else {
//             totalInwardValue[godown] = totalInwardValue[godown]! + absAmount;
//           }
//         } else {
//           // OUTWARD: Add to total outward qty
//           if (isDebitNote) {
//             totalInwardValue[godown] = totalInwardValue[godown]! - absAmount;
//           } else {
//             totalOutwardValue[godown] = totalOutwardValue[godown]! + absAmount;
//           }
//         }
//       }
      
//     }

//     // Calculate closing stock and value for each godown
//     for (var godown in totalInwardValue.keys) {
//       final inwardValue = totalInwardValue[godown] ?? 0.0;
//       final outwardValue = totalOutwardValue[godown] ?? 0.0;

//       godownResults[godown] = GodownAverageCost(
//         godownName: godown,
//         totalInwardQty: 0,
//         totalInwardValue: inwardValue,
//         currentStockQty: 0,
//         averageRate: 0.0,
//         closingValue: inwardValue - outwardValue,
//       );
//     }

//     return AverageCostResult(
//       stockItemGuid: stockItem.stockItemGuid,
//       itemName: stockItem.itemName,
//       godowns: godownResults,
//     );
//   }

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
//     final allItemClosings = await calculateAllAverageCost(companyGuid: _companyGuid!, fromDate: fromDateStr, toDate: toDateStr);

//     totalClosingStock = getTotalClosingValue(allItemClosings);

//     final previousDay = dateToString(fromDate).compareTo(_companyStartDate) <= 0 ? fromDateStr : getPreviousDate(fromDateStr);

//     final allItemOpening = await calculateAllAverageCost(companyGuid: _companyGuid!,fromDate: previousDay,toDate: previousDay);

//     totalOpeningStock = getTotalClosingValue(allItemOpening);

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
//                         onTap: () => _navigateToGroup('Purchase Accounts'),
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
//                         onTap: () => _navigateToGroup('Sales Accounts'),
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

class ProfitLossScreen extends StatefulWidget {
  @override
  _ProfitLossScreenState createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
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
  List<String> receiptNoteVoucherTypes = [];
  List<String> deliveryNoteVoucherTypes = [];
  List<String> purchaseVoucherTypes = [];
  List<String> salesVoucherTypes = [];


  Map<String, dynamic>? _plData;
  DateTime _fromDate = getFyStartDate(DateTime.now());  // Financial year start
  DateTime _toDate = getFyEndDate(DateTime.now()); // Financial year end

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


    debitNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Debit Note');
    creditNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Credit Note');
    stockJournalVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Stock Journal');
    physicalStockVoucherType = await getAllChildVoucherTypes(_companyGuid!, 'Physical Stock');
    receiptNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Receipt Note');
    deliveryNoteVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Delivery Note');
    purchaseVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Purchase');
    salesVoucherTypes = await getAllChildVoucherTypes(_companyGuid!, 'Sales');

    final plData = await _getProfitLossDetailed(_companyGuid!, _fromDate, _toDate);

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


// ============================================================
// GET ALL CHILD VOUCHER TYPES FOR CONTRA
// ============================================================

Future<List<String>> getAllChildVoucherTypes(String companyGuid, String voucherTypeName) async {
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
        AND vt.voucher_type_guid != vt.parent_guid  -- Prevent self-referencing loop
    )
    SELECT name FROM voucher_type_tree ORDER BY name
  ''', [companyGuid, voucherTypeName, voucherTypeName, companyGuid]);

  return result.map((row) => row['name'] as String).toList();
}

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
      trackingNumber: "Not Applicable",
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

    final stockItem = StockItemInfo(
      itemName: row['item_name'] as String,
      stockItemGuid: stockItemGuid,
      costingMethod: row['costing_method'] as String,
      unit: row['unit'] as String,
      parentName: row['parent_name'] as String,
      closingRate: (row['closing_rate'] as num?)?.toDouble() ?? 0.0,
      closingQty: (row['closing_balance'] as num?)?.toDouble() ?? 0.0,
      closingValue: (row['closing_value'] as num?)?.toDouble() ?? 0.0,
      openingData: batchMap[stockItemGuid] ?? [],
    );

    print('${stockItem.itemName}, ${stockItem.costingMethod}, ${stockItem.closingRate}, ${stockItem.closingQty}, ${stockItem.closingValue}');

    return stockItem;
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
      COALESCE(vba.tracking_number, 'Not Applicable') as tracking_number
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
        trackingNumber: row['tracking_number'] as String,
      );
    }).toList();
  }


  Future<Map<String, Map<String, Map<String, List<StockTransaction>>>>>
    buildStockDirectoryWithBatch(
  String companyGuid,
  String endDate,
  List<StockItemInfo> stockItems,
) async {

  Map<String, Map<String, Map<String, List<StockTransaction>>>> directory = {};

  for (var item in stockItems) {
    final transactions = await fetchTransactionsForStockItem(
      companyGuid,
      item.stockItemGuid,
      endDate,
    );

    // Godown -> Batch -> Transactions
    Map<String, Map<String, List<StockTransaction>>> godownTransactions = {};

    for (var transaction in transactions) {

      final godown = transaction.godownName;
      final batch = transaction.batchName;

      // Ensure godown exists
      godownTransactions.putIfAbsent(godown, () => {});

      // Ensure batch exists inside godown
      godownTransactions[godown]!
          .putIfAbsent(batch, () => []);

      // Add transaction
      godownTransactions[godown]![batch]!
          .add(transaction);
    }

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

    final directory = await buildStockDirectoryWithBatch(companyGuid, toDate, stockItems);

    List<AverageCostResult> results = [];

    for (var stockItem in stockItems) {

      final godownTransactions = directory[stockItem.stockItemGuid]!;

      if (stockItem.unit.toLowerCase().contains('not applicable')){
      final result = await calculateCostWithoutUnit(
              stockItem: stockItem,
              godownTransactions: godownTransactions,
              fromDate: fromDate,
              toDate: toDate,
              companyGuid: companyGuid);

          for (final entry in result.godowns.entries) {
            print(
                '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
          }
          results.add(result);

      }else if (stockItem.costingMethod.toLowerCase().contains('zero')){
        final result = AverageCostResult(itemName: stockItem.itemName, stockItemGuid: stockItem.stockItemGuid, godowns: {});
            print('${result.itemName}= ${stockItem.costingMethod}, godownName, 0, 0, 0');
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
                '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
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
                '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
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
                '${result.itemName}= ${stockItem.costingMethod}= ${entry.value.godownName}= ${entry.value.currentStockQty}= ${entry.value.averageRate}= ${entry.value.closingValue}');
          }
          results.add(result);
      }

    }

    return results;
  }

  Future<AverageCostResult> calculateLifoCost({
  required StockItemInfo stockItem,
  required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
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

  // 🔹 Godown → Batch → Lot tracking
  Map<String, Map<String, double>> godownBatchInwardQty = {};
  Map<String, Map<String, double>> godownBatchOutwardQty = {};
  Map<String, Map<String, List<StockLot>>> godownBatchLots = {};

  // Flatten all transactions and sort by voucherId
  List<StockTransaction> allTransactions = [];
  for (var godownMap in godownTransactions.values) {
    for (var batchList in godownMap.values) {
      allTransactions.addAll(batchList);
    }
  }
  allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

  // Group transactions by voucher_guid
  Map<String, List<StockTransaction>> voucherBatches = {};
  for (var txn in allTransactions) {
    voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
    voucherBatches[txn.voucherGuid]!.add(txn);
  }

  // 🔹 Opening Stock → Batch Level
  for (final godownOpeningData in stockItem.openingData) {
    String godownName = godownOpeningData.godownName;
    if (godownName.isEmpty) {
      godownName = 'Main Location';
    }

    final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
    final openingAmount = godownOpeningData.amount;
    final batchName = godownOpeningData.batchName;

    godownBatchInwardQty.putIfAbsent(godownName, () => {});
    godownBatchOutwardQty.putIfAbsent(godownName, () => {});
    godownBatchLots.putIfAbsent(godownName, () => {});

    godownBatchInwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
    godownBatchOutwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
    godownBatchLots[godownName]!.putIfAbsent(batchName, () => []);

    godownBatchInwardQty[godownName]![batchName] =
        godownBatchInwardQty[godownName]![batchName]! + openingQty;

    if (openingQty > 0) {
      final openingRate = openingAmount / openingQty;
      godownBatchLots[godownName]![batchName]!.add(StockLot(
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

  // LIFO closing value helper
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
    double lastRate = 0.0;

    for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
      final lot = lots[i];
      lastRate = lot.rate;
      if (lot.type == StockInOutType.outward) {
        tempOutWardQty += lot.qty;
      } else {
        if (lot.qty == 0) {
          closingValue += lot.amount;
        } else if (tempOutWardQty <= 0) {
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

    if (remainingQty > 0) {
      closingValue += remainingQty * lastRate;
    }

    if (closingValue == 0 && closingStockQty > 0) {
      final totalQty = lots.fold(0.0, (sum, lot) => sum + lot.qty);
      final totalValue = lots.fold(0.0, (sum, lot) => sum + lot.amount);
      if (totalQty > 0) {
        closingValue = closingStockQty * (totalValue / totalQty);
      }
    }

    return closingValue;
  }

  Set<String> processedVouchers = {};

  for (var txn in allTransactions) {
    final voucherGuid = txn.voucherGuid;

    if (processedVouchers.contains(voucherGuid) ||
        txn.voucherType.toLowerCase().contains('purchase order') ||
        txn.voucherType.toLowerCase().contains('sales order')) {
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

    // 🔹 FY Boundary Reset (Batch Wise)
    if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
      for (var godown in godownBatchInwardQty.keys) {
        final batchKeys = godownBatchInwardQty[godown]!.keys.toList();
        for (var batchName in batchKeys) {
          final inwardQty = godownBatchInwardQty[godown]![batchName]!;
          final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
          final closingStockQty = inwardQty - outwardQty;
          final lots = godownBatchLots[godown]![batchName] ?? [];

          if (closingStockQty > 0) {
            final closingValue = calculateLifoClosingValue(lots, closingStockQty);
            final closingRate = closingValue / closingStockQty;

            godownBatchInwardQty[godown]![batchName] = closingStockQty;
            godownBatchOutwardQty[godown]![batchName] = 0.0;
            godownBatchLots[godown]![batchName] = [
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
          } else if (closingStockQty < 0) {
            // Negative stock: fallback to Average Cost
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

            godownBatchInwardQty[godown]![batchName] = closingStockQty;
            godownBatchOutwardQty[godown]![batchName] = 0.0;
            godownBatchLots[godown]![batchName] = [
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
            godownBatchInwardQty[godown]![batchName] = 0.0;
            godownBatchOutwardQty[godown]![batchName] = 0.0;
            godownBatchLots[godown]![batchName] = [];
          }
        }
      }
    }

    currentFyStart = txnFyStart;

    final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);
    final isPurchase = purchaseVoucherTypes.contains(voucherType);
    final isSales = salesVoucherTypes.contains(voucherType);

    if (voucherType == 'Physical Stock') continue;

    final batches = voucherBatches[voucherGuid]!;

    for (var batchTxn in batches) {
      final godown = batchTxn.godownName;
      final batchName = batchTxn.batchName;
      final amount = batchTxn.amount;
      final qty = batchTxn.stock;
      final isInward = batchTxn.isInward;
      final absAmount = amount.abs();

      if (batchTxn.trackingNumber.toLowerCase().contains('not applicable') == false &&
          (isPurchase || isSales || isDebitNote || isCreditNote)) {
        continue;
      }

      if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
        continue;
      }

      // Initialize batch if not exists
      godownBatchInwardQty.putIfAbsent(godown, () => {});
      godownBatchOutwardQty.putIfAbsent(godown, () => {});
      godownBatchLots.putIfAbsent(godown, () => {});

      godownBatchInwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
      godownBatchOutwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
      godownBatchLots[godown]!.putIfAbsent(batchName, () => []);

      if (isInward) {
        if (isCreditNote) {
          godownBatchOutwardQty[godown]![batchName] =
              godownBatchOutwardQty[godown]![batchName]! - qty;

          final rate = qty > 0 ? absAmount / qty : 0.0;
          godownBatchLots[godown]![batchName]!.add(StockLot(
            voucherGuid: voucherGuid,
            voucherDate: dateStr,
            voucherNumber: voucherNumber,
            voucherType: voucherType,
            qty: qty * -1,
            amount: amount * -1,
            rate: rate,
            type: StockInOutType.outward,
          ));
        } else {
          godownBatchInwardQty[godown]![batchName] =
              godownBatchInwardQty[godown]![batchName]! + qty;

          final rate = qty > 0 ? absAmount / qty : 0.0;
          godownBatchLots[godown]![batchName]!.add(StockLot(
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
          godownBatchInwardQty[godown]![batchName] =
              godownBatchInwardQty[godown]![batchName]! - qty;

          final rate = qty > 0 ? absAmount / qty : 0.0;
          godownBatchLots[godown]![batchName]!.add(StockLot(
            voucherGuid: voucherGuid,
            voucherDate: dateStr,
            voucherNumber: voucherNumber,
            voucherType: voucherType,
            qty: qty * -1,
            amount: amount * -1,
            rate: rate,
            type: StockInOutType.inward,
          ));
        } else {
          godownBatchOutwardQty[godown]![batchName] =
              godownBatchOutwardQty[godown]![batchName]! + qty;

          final rate = qty > 0 ? absAmount / qty : 0.0;
          godownBatchLots[godown]![batchName]!.add(StockLot(
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

  // 🔹 Final: Batch → Godown Merge (LIFO closing per batch, then sum)
  for (var godown in godownBatchInwardQty.keys) {
    double totalClosingQty = 0.0;
    double totalClosingValue = 0.0;

    final batchKeys = godownBatchInwardQty[godown]!.keys;
    for (var batchName in batchKeys) {
      final inwardQty = godownBatchInwardQty[godown]![batchName]!;
      final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
      final closingStockQty = inwardQty - outwardQty;
      final lots = godownBatchLots[godown]![batchName] ?? [];

      double batchClosingValue = 0.0;

      if (closingStockQty > 0) {
        batchClosingValue = calculateLifoClosingValue(lots, closingStockQty);
      } else if (closingStockQty < 0) {
        // Negative stock: Average Cost fallback
        double totalLotValue = 0.0;
        double totalLotQty = 0.0;
        for (var lot in lots) {
          if (lot.type == StockInOutType.inward) {
            totalLotValue += lot.amount;
            totalLotQty += lot.qty;
          }
        }
        final closingRate = totalLotQty == 0 ? 0.0 : totalLotValue / totalLotQty ;
        batchClosingValue = closingStockQty * closingRate;
      }

      totalClosingQty += closingStockQty;
      totalClosingValue += batchClosingValue;
    }

    godownResults[godown] = GodownAverageCost(
      godownName: godown,
      totalInwardQty: 0,
      totalInwardValue: 0,
      currentStockQty: totalClosingQty,
      averageRate: totalClosingQty > 0 ? totalClosingValue / totalClosingQty : 0.0,
      closingValue: totalClosingValue,
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
  required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
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

  // 🔹 Godown → Batch → Lot tracking
  Map<String, Map<String, double>> godownBatchInwardQty = {};
  Map<String, Map<String, double>> godownBatchOutwardQty = {};
  Map<String, Map<String, List<StockLot>>> godownBatchLots = {};

  // Flatten all transactions and sort by voucherId
  List<StockTransaction> allTransactions = [];
  for (var godownMap in godownTransactions.values) {
    for (var batchList in godownMap.values) {
      allTransactions.addAll(batchList);
    }
  }
  allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

  // Group transactions by voucher_guid
  Map<String, List<StockTransaction>> voucherBatches = {};
  for (var txn in allTransactions) {
    voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
    voucherBatches[txn.voucherGuid]!.add(txn);
  }

  // 🔹 Opening Stock → Batch Level
  for (final godownOpeningData in stockItem.openingData) {
    String godownName = godownOpeningData.godownName;
    if (godownName.isEmpty) {
      godownName = 'Main Location';
    }

    final openingQty = double.tryParse(godownOpeningData.actualQty) ?? 0.0;
    final openingAmount = godownOpeningData.amount;
    final batchName = godownOpeningData.batchName;

    godownBatchInwardQty.putIfAbsent(godownName, () => {});
    godownBatchOutwardQty.putIfAbsent(godownName, () => {});
    godownBatchLots.putIfAbsent(godownName, () => {});

    godownBatchInwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
    godownBatchOutwardQty[godownName]!.putIfAbsent(batchName, () => 0.0);
    godownBatchLots[godownName]!.putIfAbsent(batchName, () => []);

    godownBatchInwardQty[godownName]![batchName] =
        godownBatchInwardQty[godownName]![batchName]! + openingQty;

    // if (openingQty > 0) {
      final openingRate = openingAmount / openingQty;
      godownBatchLots[godownName]![batchName]!.add(StockLot(
        voucherGuid: 'OPENING_STOCK',
        voucherDate: fromDate,
        voucherNumber: 'Opening Balance',
        voucherType: 'Opening',
        qty: openingQty,
        amount: openingAmount,
        rate: openingRate,
        type: StockInOutType.inward,
      ));
    // }
  }

  String currentFyStart = '';

  // FIFO closing value helper (backwards from last lot = newest first)
  double calculateFifoClosingValue(List<StockLot> lots, double closingStockQty) {
    if (closingStockQty <= 0 || lots.isEmpty) {
      return 0.0;
    }

    double closingValue = 0.0;
    double remainingQty = closingStockQty;
    double lastRate = 0.0;

    for (int i = lots.length - 1; i >= 0 && remainingQty > 0; i--) {
      final lot = lots[i];
      lastRate = lot.rate;

      if (lot.qty == 0) {
        closingValue += lot.amount;
      } else if (lot.qty <= remainingQty) {
        closingValue += lot.amount;
        remainingQty -= lot.qty;
      } else {
        closingValue += remainingQty * lot.rate;
        remainingQty = 0;
      }
    }

    if (remainingQty > 0) {
      closingValue += remainingQty * lastRate;
    }

    if (closingValue == 0 && closingStockQty > 0) {
      final totalQty = lots.fold(0.0, (sum, lot) => sum + lot.qty);
      final totalValue = lots.fold(0.0, (sum, lot) => sum + lot.amount);
      if (totalQty > 0) {
        closingValue = closingStockQty * (totalValue / totalQty);
      }
    }

    return closingValue;
  }

  Set<String> processedVouchers = {};

  for (var txn in allTransactions) {
    final voucherGuid = txn.voucherGuid;

    if (processedVouchers.contains(voucherGuid) ||
        txn.voucherType.toLowerCase().contains('purchase order') ||
        txn.voucherType.toLowerCase().contains('sales order')) {
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

    // 🔹 FY Boundary Reset (Batch Wise)
    if (txnFyStart != currentFyStart && currentFyStart.isNotEmpty) {
      for (var godown in godownBatchInwardQty.keys) {
        final batchKeys = godownBatchInwardQty[godown]!.keys.toList();
        for (var batchName in batchKeys) {
          final inwardQty = godownBatchInwardQty[godown]![batchName]!;
          final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
          final closingStockQty = inwardQty - outwardQty;
          final lots = godownBatchLots[godown]![batchName] ?? [];

          if (closingStockQty > 0) {
            final closingValue = calculateFifoClosingValue(lots, closingStockQty);
            final closingRate = closingValue / closingStockQty;

            godownBatchInwardQty[godown]![batchName] = closingStockQty;
            godownBatchOutwardQty[godown]![batchName] = 0.0;
            godownBatchLots[godown]![batchName] = [
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
          } else if (closingStockQty < 0) {
            // Negative stock: fallback to Average Cost
            double totalLotValue = 0.0;
            double totalLotQty = 0.0;
            for (var lot in lots) {
              totalLotValue += lot.amount;
              totalLotQty += lot.qty;
            }
            final closingRate = totalLotQty > 0 ? totalLotValue / totalLotQty : 0.0;
            final closingValue = closingStockQty * closingRate;

            godownBatchInwardQty[godown]![batchName] = closingStockQty;
            godownBatchOutwardQty[godown]![batchName] = 0.0;
            godownBatchLots[godown]![batchName] = [
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
            godownBatchInwardQty[godown]![batchName] = 0.0;
            godownBatchOutwardQty[godown]![batchName] = 0.0;
            godownBatchLots[godown]![batchName] = [];
          }
        }
      }
    }

    currentFyStart = txnFyStart;

    final isPurchase = purchaseVoucherTypes.contains(voucherType);
    final isSales = salesVoucherTypes.contains(voucherType);
    final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

    if (voucherType == 'Physical Stock') continue;

    final batches = voucherBatches[voucherGuid]!;

    for (var batchTxn in batches) {
      final godown = batchTxn.godownName;
      final batchName = batchTxn.batchName;
      final amount = batchTxn.amount;
      final qty = batchTxn.stock;
      final isInward = batchTxn.isInward;
      final absAmount = amount.abs();

      if (batchTxn.trackingNumber.toLowerCase().contains('not applicable') == false &&
          (isPurchase || isSales || isDebitNote || isCreditNote)) {
        continue;
      }

      if ((isCreditNote || isDebitNote) && qty == 0 && amount == 0) {
        continue;
      }

      // Initialize batch if not exists
      godownBatchInwardQty.putIfAbsent(godown, () => {});
      godownBatchOutwardQty.putIfAbsent(godown, () => {});
      godownBatchLots.putIfAbsent(godown, () => {});

      godownBatchInwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
      godownBatchOutwardQty[godown]!.putIfAbsent(batchName, () => 0.0);
      godownBatchLots[godown]!.putIfAbsent(batchName, () => []);

      if (isInward) {
        if (isCreditNote) {
          godownBatchOutwardQty[godown]![batchName] =
              godownBatchOutwardQty[godown]![batchName]! - qty;
        } else {
          godownBatchInwardQty[godown]![batchName] =
              godownBatchInwardQty[godown]![batchName]! + qty;

          final rate = qty > 0 ? absAmount / qty : 0.0;
          godownBatchLots[godown]![batchName]!.add(StockLot(
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
          godownBatchInwardQty[godown]![batchName] =
              godownBatchInwardQty[godown]![batchName]! - qty;

          final rate = qty > 0 ? absAmount / qty : 0.0;
          godownBatchLots[godown]![batchName]!.add(StockLot(
            voucherGuid: voucherGuid,
            voucherDate: dateStr,
            voucherNumber: voucherNumber,
            voucherType: voucherType,
            qty: qty * -1,
            amount: amount * -1,
            rate: rate,
            type: StockInOutType.inward,
          ));
        } else {
          godownBatchOutwardQty[godown]![batchName] =
              godownBatchOutwardQty[godown]![batchName]! + qty;
        }
      }
    }
  }

  // 🔹 Final: Batch → Godown Merge (FIFO closing per batch, then sum)
  for (var godown in godownBatchInwardQty.keys) {
    double totalClosingQty = 0.0;
    double totalClosingValue = 0.0;

    final batchKeys = godownBatchInwardQty[godown]!.keys;
    for (var batchName in batchKeys) {
      final inwardQty = godownBatchInwardQty[godown]![batchName]!;
      final outwardQty = godownBatchOutwardQty[godown]![batchName] ?? 0.0;
      final closingStockQty = inwardQty - outwardQty;
      final lots = godownBatchLots[godown]![batchName] ?? [];

      double batchClosingValue = 0.0;

      if (closingStockQty > 0) {
        batchClosingValue = calculateFifoClosingValue(lots, closingStockQty);
      } else if (closingStockQty < 0) {
        // Negative stock: Average Cost fallback
        double totalLotValue = 0.0;
        double totalLotQty = 0.0;
        for (var lot in lots) {
          totalLotValue += lot.amount;
          totalLotQty += lot.qty;
        }
        final closingRate = totalLotQty == 0 ? 0.0 : totalLotValue / totalLotQty;
        batchClosingValue = closingStockQty * closingRate;
      }

      totalClosingQty += closingStockQty;
      totalClosingValue += batchClosingValue;
    }

    godownResults[godown] = GodownAverageCost(
      godownName: godown,
      totalInwardQty: 0,
      totalInwardValue: 0,
      currentStockQty: totalClosingQty,
      averageRate: totalClosingQty > 0 ? totalClosingValue / totalClosingQty : 0.0,
      closingValue: totalClosingValue,
    );
  }

  return AverageCostResult(
    stockItemGuid: stockItem.stockItemGuid,
    itemName: stockItem.itemName,
    godowns: godownResults,
  );
}

Future<AverageCostResult> calculateAvgCost({
  required StockItemInfo stockItem,
  required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
  required String fromDate,
  required String toDate,
  required String companyGuid,
}) async {

  Map<String, GodownAverageCost> godownResults = {};

  // 🔹 NEW: Godown → Batch → Accumulator
  Map<String, Map<String, BatchAccumulator>> godownBatchData = {};

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

  // 🔹 Flatten all transactions
  List<StockTransaction> allTransactions = [];
  for (var godownMap in godownTransactions.values) {
    for (var batchList in godownMap.values) {
      allTransactions.addAll(batchList);
    }
  }

  allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

  // 🔹 Group by voucher_guid
  Map<String, List<StockTransaction>> voucherBatches = {};
  for (var txn in allTransactions) {
    voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
    voucherBatches[txn.voucherGuid]!.add(txn);
  }


  // 🔹 Opening Stock → Batch Level
  for (final godownOpeningData in stockItem.openingData) {

    String godownName = godownOpeningData.godownName;
    if (godownName.isEmpty) {
      godownName = 'Main Location';
    }

    final openingQty =
        double.tryParse(godownOpeningData.actualQty) ?? 0.0;
    final openingAmount = godownOpeningData.amount;
    final batchName =
        godownOpeningData.batchName;

    godownBatchData.putIfAbsent(godownName, () => {});
    godownBatchData[godownName]!
        .putIfAbsent(batchName, () => BatchAccumulator());

    final batch = godownBatchData[godownName]![batchName]!;

    batch.inwardQty += openingQty;
    batch.inwardValue += openingAmount;
  }

  String currentFyStart = '';
  Set<String> processedVouchers = {};

  // 🔹 Process Transactions
  for (var txn in allTransactions) {

    final voucherGuid = txn.voucherGuid;

    if (processedVouchers.contains(voucherGuid) ||
        txn.voucherType.toLowerCase().contains('purchase order') ||
        txn.voucherType.toLowerCase().contains('sales order')) {
      continue;
    }

    processedVouchers.add(voucherGuid);

    final dateStr = txn.voucherDate;
    final voucherType = txn.voucherType;

    if (dateStr.compareTo(toDate) > 0) {
      break;
    }

    final txnFyStart = getFinancialYearStartDate(dateStr);

    // 🔹 FY Boundary Reset (Batch Wise)
    if (txnFyStart != currentFyStart &&
        currentFyStart.isNotEmpty) {

      for (var godown in godownBatchData.keys) {
        for (var batchData
            in godownBatchData[godown]!.values) {

          final inwardQty = batchData.inwardQty;
          final inwardValue = batchData.inwardValue;
          final outwardQty = batchData.outwardQty;

          final closingQty = inwardQty - outwardQty;
          final closingRate =
              inwardQty > 0 ? inwardValue / inwardQty : 0.0;
          final closingValue = closingQty * closingRate;

          batchData.inwardQty = closingQty;
          batchData.inwardValue = closingValue;
          batchData.outwardQty = 0.0;
        }
      }
    }

    currentFyStart = txnFyStart;

    final isPurchase =
        purchaseVoucherTypes.contains(voucherType);
    final isSales =
        salesVoucherTypes.contains(voucherType);
    final isCreditNote =
        creditNoteVoucherTypes.contains(voucherType);
    final isDebitNote =
        debitNoteVoucherTypes.contains(voucherType);

    if (voucherType == 'Physical Stock') continue;

    final batches = voucherBatches[voucherGuid]!;

    for (var batchTxn in batches) {

      final godown = batchTxn.godownName;
      final batchName =
          batchTxn.batchName;

      final amount = batchTxn.amount;
      final qty = batchTxn.stock;
      final isInward = batchTxn.isInward;
      final absAmount = amount.abs();

      if (batchTxn.trackingNumber
              .toLowerCase()
              .contains('not applicable') ==
          false &&
          (isPurchase ||
              isSales ||
              isDebitNote ||
              isCreditNote)) {continue;}

      if ((isCreditNote || isDebitNote) &&
          qty == 0 &&
          amount == 0) {
        continue;
      }

      godownBatchData.putIfAbsent(godown, () => {});
      godownBatchData[godown]!
          .putIfAbsent(batchName, () => BatchAccumulator());

      final batchData =
          godownBatchData[godown]![batchName]!;

      if (isInward) {
        if (isCreditNote) {
          batchData.outwardQty -= qty;
        } else {
          batchData.inwardQty += qty;
          batchData.inwardValue += absAmount;
        }
      } else {
        if (isDebitNote) {
          batchData.inwardQty -= qty;
          batchData.inwardValue -= absAmount;
        } else {
          batchData.outwardQty += qty;
        }
      }
    }
  }

  // 🔹 Final: Batch → Godown Merge
  for (var godown in godownBatchData.keys) {

    final batches = godownBatchData[godown]!;

    double closingQty = 0.0;
    double closingValue = 0.0;

    for (var batchData in batches.values) {
      closingQty += (batchData.inwardQty - batchData.outwardQty);

      final batchRate = batchData.inwardQty != 0
    ? batchData.inwardValue / batchData.inwardQty
    : 0.0;
      closingValue += (batchData.inwardQty - batchData.outwardQty) * batchRate;

  
    }

    godownResults[godown] = GodownAverageCost(
      godownName: godown,
      totalInwardQty: 0,
      totalInwardValue: 0,
      currentStockQty: closingQty,
      averageRate: 0,
      closingValue: closingValue,
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
  required Map<String, Map<String, List<StockTransaction>>> godownTransactions,
  required String fromDate,
  required String toDate,
  required String companyGuid,
}) async {
  Map<String, GodownAverageCost> godownResults = {};

  // 🔹 Godown → Batch → Value tracking
  Map<String, Map<String, double>> godownBatchInwardValue = {};
  Map<String, Map<String, double>> godownBatchOutwardValue = {};

  // Flatten all transactions and sort by voucherId
  List<StockTransaction> allTransactions = [];
  for (var godownMap in godownTransactions.values) {
    for (var batchList in godownMap.values) {
      allTransactions.addAll(batchList);
    }
  }
  allTransactions.sort((a, b) => a.voucherId.compareTo(b.voucherId));

  // Group transactions by voucher_guid
  Map<String, List<StockTransaction>> voucherBatches = {};
  for (var txn in allTransactions) {
    voucherBatches.putIfAbsent(txn.voucherGuid, () => []);
    voucherBatches[txn.voucherGuid]!.add(txn);
  }

  // 🔹 Opening Stock → Batch Level
  for (final godownOpeningData in stockItem.openingData) {
    String godownName = godownOpeningData.godownName;
    if (godownName.isEmpty) {
      godownName = 'Main Location';
    }

    final openingAmount = godownOpeningData.amount;
    final batchName = godownOpeningData.batchName;

    godownBatchInwardValue.putIfAbsent(godownName, () => {});
    godownBatchOutwardValue.putIfAbsent(godownName, () => {});

    godownBatchInwardValue[godownName]!.putIfAbsent(batchName, () => 0.0);
    godownBatchOutwardValue[godownName]!.putIfAbsent(batchName, () => 0.0);

    godownBatchInwardValue[godownName]![batchName] =
        godownBatchInwardValue[godownName]![batchName]! + openingAmount;
  }

  // Process transactions
  Set<String> processedVouchers = {};

  for (var txn in allTransactions) {
    final voucherGuid = txn.voucherGuid;

    if (processedVouchers.contains(voucherGuid) ||
        txn.voucherType.toLowerCase().contains('purchase order') ||
        txn.voucherType.toLowerCase().contains('sales order')) {
      continue;
    }
    processedVouchers.add(voucherGuid);

    final dateStr = txn.voucherDate;
    final voucherType = txn.voucherType;

    if (dateStr.compareTo(toDate) > 0) {
      break;
    }

    if (voucherType == 'Physical Stock') {
      continue;
    }

    final batches = voucherBatches[voucherGuid]!;

    for (var batchTxn in batches) {
      final godown = batchTxn.godownName;
      final batchName = batchTxn.batchName;
      final amount = batchTxn.amount;
      final isInward = batchTxn.isInward;
      final absAmount = amount.abs();

      final isCreditNote = creditNoteVoucherTypes.contains(voucherType);
      final isDebitNote = debitNoteVoucherTypes.contains(voucherType);

      // Initialize batch if not exists
      godownBatchInwardValue.putIfAbsent(godown, () => {});
      godownBatchOutwardValue.putIfAbsent(godown, () => {});

      godownBatchInwardValue[godown]!.putIfAbsent(batchName, () => 0.0);
      godownBatchOutwardValue[godown]!.putIfAbsent(batchName, () => 0.0);

      if (isInward) {
        if (isCreditNote) {
          godownBatchOutwardValue[godown]![batchName] =
              godownBatchOutwardValue[godown]![batchName]! - absAmount;
        } else {
          godownBatchInwardValue[godown]![batchName] =
              godownBatchInwardValue[godown]![batchName]! + absAmount;
        }
      } else {
        if (isDebitNote) {
          godownBatchInwardValue[godown]![batchName] =
              godownBatchInwardValue[godown]![batchName]! - absAmount;
        } else {
          godownBatchOutwardValue[godown]![batchName] =
              godownBatchOutwardValue[godown]![batchName]! + absAmount;
        }
      }
    }
  }

  // 🔹 Final: Batch → Godown Merge
  for (var godown in godownBatchInwardValue.keys) {
    double totalInward = 0.0;
    double totalOutward = 0.0;

    final batchKeys = godownBatchInwardValue[godown]!.keys;
    for (var batchName in batchKeys) {
      totalInward += godownBatchInwardValue[godown]![batchName] ?? 0.0;
      totalOutward += godownBatchOutwardValue[godown]![batchName] ?? 0.0;
    }

    godownResults[godown] = GodownAverageCost(
      godownName: godown,
      totalInwardQty: 0,
      totalInwardValue: totalInward,
      currentStockQty: 0,
      averageRate: 0.0,
      closingValue: totalInward - totalOutward,
    );
  }

  return AverageCostResult(
    stockItemGuid: stockItem.stockItemGuid,
    itemName: stockItem.itemName,
    godowns: godownResults,
  );
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
      INNER JOIN group_tree gt ON l.parent_guid = gt.group_guid
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

if (_isMaintainInventory){
    // final allItemClosings = await calculateAllAverageCost(companyGuid: _companyGuid!, fromDate: fromDateStr, toDate: toDateStr);

    // totalClosingStock = getTotalClosingValue(allItemClosings);

    // final previousDay = dateToString(fromDate).compareTo(_companyStartDate) <= 0 ? fromDateStr : getPreviousDate(fromDateStr);

    // final allItemOpening = await calculateAllAverageCost(companyGuid: _companyGuid!,fromDate: previousDay,toDate: previousDay);

    // totalOpeningStock = getTotalClosingValue(allItemOpening);

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


  @override
  Widget build(BuildContext context) {
    syncBrightness(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Profit & Loss A/c')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
              color: AppColors.pillBg,
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
      color: AppColors.pillBg,
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
                  Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
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
                  Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                ],
              ],
            ),
            Text(_formatAmount(amount)),
          ],
        ),
      ),
    );
  }


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
        final dk = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: (dk ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: dk
                ? ColorScheme.dark(primary: Colors.blue, onPrimary: Colors.white, surface: AppColors.surface, onSurface: AppColors.textPrimary)
                : const ColorScheme.light(primary: Colors.blue, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
            dialogBackgroundColor: dk ? AppColors.surface : Colors.white,
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
