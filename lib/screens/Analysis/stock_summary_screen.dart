import 'package:flutter/material.dart';
import '../../models/data_model.dart';
import '../../database/database_helper.dart';
import '../../utils/date_utils.dart';

class StockSummaryScreen extends StatefulWidget {
  @override
  _StockSummaryScreenState createState() => _StockSummaryScreenState();
}

class _StockSummaryScreenState extends State<StockSummaryScreen> {
  final _db = DatabaseHelper.instance;

  String? _companyGuid;
  String? _companyName;
  bool _loading = true;
  bool _isMaintainInventory = true;

  List<StockItemInfo> _stockItems = [];
  DateTime _fromDate = getFyStartDate(DateTime.now());
  DateTime _toDate = getFyEndDate(DateTime.now());

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

    final stockItems = await fetchAllStockItems(_companyGuid!);

    setState(() {
      _stockItems = stockItems;
      _loading = false;
    });
  }

  Future<List<StockItemInfo>> fetchAllStockItems(String companyGuid) async {
    final db = await _db.database;

    final stockItemResults = await db.rawQuery('''
      SELECT 
        si.name as item_name,
        si.stock_item_guid,
        COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
        COALESCE(si.base_units, '') as unit,
        COALESCE(si.closing_balance, '0.0') as closing_balance,
        COALESCE(si.closing_value, '0.0') as closing_value,
        COALESCE(si.closing_rate, '0.0') as closing_rate,
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
      return StockItemInfo(
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
    }).toList();
  }

  double get _totalClosingValue =>
      _stockItems.fold(0.0, (sum, item) => sum + item.closingValue);

  String _formatAmount(double amount) {
    final formatted = amount.abs().toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return amount < 0 ? '-$formatted' : formatted;
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
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stock Summary')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Stock Summary',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Company & Date Header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companyName ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(dateToString(_fromDate))}  →  ${_formatDate(dateToString(_toDate))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Table Header
          Container(
            color: Colors.blue[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Item Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Rate',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'Value',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          Expanded(
            child: _stockItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No stock items found',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _stockItems.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final item = _stockItems[index];
                      final isEven = index % 2 == 0;
                      return Container(
                        color: isEven ? Colors.white : Colors.grey[50],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // Item Name + unit
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.unit.isNotEmpty)
                                    Text(
                                      item.unit,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Closing Qty
                            SizedBox(
                              width: 70,
                              child: Text(
                                _formatAmount(item.closingQty),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: item.closingQty < 0
                                      ? Colors.red[700]
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            // Closing Rate
                            SizedBox(
                              width: 80,
                              child: Text(
                                _formatAmount(item.closingRate),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            // Closing Value
                            SizedBox(
                              width: 90,
                              child: Text(
                                _formatAmount(item.closingValue),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: item.closingValue < 0
                                      ? Colors.red[700]
                                      : Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Total Footer
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[700],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total Closing Stock',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  _formatAmount(_totalClosingValue),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}