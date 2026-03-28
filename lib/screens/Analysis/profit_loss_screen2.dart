import 'package:flutter/material.dart';
import '../../models/data_model.dart';
import '../../database/database_helper.dart';
import '../../utils/date_utils.dart';
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
  static const Color _bg        = Color(0xFFF4F6FB);
  static const Color _cardBg    = Colors.white;
  static const Color _textDark  = Color(0xFF1A2340);
  static const Color _textMuted = Color(0xFF8A94A6);
  static const Color _debitCol  = Color(0xFFD32F2F);
  static const Color _creditCol = Color(0xFF1B8A5A);
  static const Color _grossBg   = Color(0xFFFFF8E1);
  static const Color _grossC    = Color(0xFFB45309);
  static const Color _netBg     = Color(0xFFE8F5EE);
  static const Color _netC      = Color(0xFF1B8A5A);
  static const Color _netLossBg = Color(0xFFFFEBEB);
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
                    const Text('Select Period', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
                  ]),
                  const SizedBox(height: 20),

                  // Quick filter chips
                  const Text('Quick Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMuted, letterSpacing: 0.4)),
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
                  const Text('Custom Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMuted, letterSpacing: 0.4)),
                  const SizedBox(height: 10),

                  // From date
                  _datePickerTile('From', tempFrom, () async {
                    final p = await showDatePicker(context: ctx,
                      initialDate: tempFrom, firstDate: DateTime(2000), lastDate: DateTime(2100),
                      builder: (c,child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: _textDark)), child: child!));
                    if (p != null) setDs(() => tempFrom = p);
                  }),
                  const SizedBox(height: 10),

                  // To date
                  _datePickerTile('To', tempTo, () async {
                    final p = await showDatePicker(context: ctx,
                      initialDate: tempTo, firstDate: DateTime(2000), lastDate: DateTime(2100),
                      builder: (c,child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: _textDark)), child: child!));
                    if (p != null) setDs(() => tempTo = p);
                  }),

                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(foregroundColor: _textMuted,
                        side: BorderSide(color: Colors.grey.shade200),
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
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 16, color: _primary),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: _textMuted)),
            const SizedBox(height: 2),
            Text(_displayDate(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
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
    if (_loading) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    final netProfit   = (_plData?['net_profit'] ?? 0.0) as double;
    final grossProfit = (_plData?['gross_profit'] ?? 0.0) as double;
    final isProfit    = netProfit >= 0;

    return Scaffold(
      backgroundColor: _bg,
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
      backgroundColor: _cardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Profit & Loss A/c',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
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
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark, letterSpacing: -0.2)),
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
        color: _cardBg,
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
            Container(width: 1, color: Colors.grey.shade100),
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
        color: const Color(0xFFF0F3FA),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 0.5)),
    );
  }

  Widget _plRow(String label, double amount, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _textDark))),
          if (onTap != null) Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey.shade300),
          const SizedBox(width: 4),
          Text(_fmt(amount),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark))),
            Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 16, color: _textMuted),
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
                style: const TextStyle(fontSize: 11, color: _textMuted),
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