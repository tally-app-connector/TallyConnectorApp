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
  List<String> _availableMonths = []; // e.g. ['20260228', '20260131', ...]
  String? _selectedMonth;             // currently selected closing_date

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

    // Load available months first
    await _loadAvailableMonths();

    // Load stock items for selected month
    final stockItems = await fetchAllStockItems(_companyGuid!, _selectedMonth);

    setState(() {
      _stockItems = stockItems;
      _loading = false;
    });
  }

  // ── Load distinct months from DB ─────────────────────────────
  Future<void> _loadAvailableMonths() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT closing_date
      FROM stock_item_closing_balance
      WHERE company_guid = ?
      ORDER BY closing_date DESC
    ''', [_companyGuid]);

    _availableMonths = rows.map((r) => r['closing_date'] as String).toList();

    // Default to latest month
    if (_selectedMonth == null && _availableMonths.isNotEmpty) {
      _selectedMonth = _availableMonths.first;
    }
  }

  // ── Fetch stock items for a specific month ───────────────────
  // Future<List<StockItemInfo>> fetchAllStockItems(
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
  //       COALESCE(cb.closing_date, '') as closing_date,
  //       COALESCE(si.parent, '') as parent_name
  //     FROM stock_items si
  //     LEFT JOIN stock_item_closing_balance cb
  //       ON cb.stock_item_guid = si.stock_item_guid
  //       AND cb.company_guid = ?
  //       AND cb.closing_date = ?
  //     WHERE si.company_guid = ?
  //       AND si.is_deleted = 0
  //       AND (
  //         EXISTS (SELECT 1 FROM stock_item_batch_allocation siba WHERE siba.stock_item_guid = si.stock_item_guid)
  //         OR EXISTS (SELECT 1 FROM voucher_inventory_entries vie WHERE vie.stock_item_guid = si.stock_item_guid AND vie.company_guid = si.company_guid)
  //       )
  //     ORDER BY si.name ASC
  //   ''', [companyGuid, closingDate ?? '', companyGuid]);

  //   return stockItemResults.map((row) {
  //     return StockItemInfo(
  //       itemName: row['item_name'] as String,
  //       stockItemGuid: row['stock_item_guid'] as String,
  //       costingMethod: row['costing_method'] as String,
  //       unit: row['unit'] as String,
  //       parentName: row['parent_name'] as String,
  //       closingRate: (row['closing_rate'] as num?)?.toDouble() ?? 0.0,
  //       closingQty: (row['closing_balance'] as num?)?.toDouble() ?? 0.0,
  //       closingValue: (row['closing_value'] as num?)?.toDouble() ?? 0.0,
  //       openingData: [],
  //     );
  //   }).toList();
  // }

  Future<List<StockItemInfo>> fetchAllStockItems(
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

  // ── On month chip tap ────────────────────────────────────────
  Future<void> _onMonthSelected(String closingDate) async {
    if (_selectedMonth == closingDate) return;
    setState(() {
      _selectedMonth = closingDate;
      _loading = true;
    });
    final items = await fetchAllStockItems(_companyGuid!, closingDate);
    setState(() {
      _stockItems = items;
      _loading = false;
    });
  }

  // ── Show month picker bottom sheet ───────────────────────────
  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        // Group months by FY
        final Map<String, List<String>> fyGroups = {};
        for (final date in _availableMonths) {
          final fy = _getFYLabel(date);
          fyGroups.putIfAbsent(fy, () => []).add(date);
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select Month',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: fyGroups.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // FY label
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          // Month chips
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value.map((date) {
                                final isSelected = date == _selectedMonth;
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _onMonthSelected(date);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue[700]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue[700]!
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      _formatMonthLabel(date),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  double get _totalClosingValue =>
      _stockItems.fold(0.0, (sum, item) => sum + item.closingValue);

  String _formatAmount(double amount) {
    final formatted = amount.abs().toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return amount < 0 ? '-$formatted' : formatted;
  }

  // "20250331" → "Mar 2025"
  String _formatMonthLabel(String tallyDate) {
    if (tallyDate.length != 8) return tallyDate;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final year = int.tryParse(tallyDate.substring(0, 4)) ?? 0;
    final month = int.tryParse(tallyDate.substring(4, 6)) ?? 0;
    return '${months[month]} $year';
  }

  // "20250331" → "FY 2024-25"
  String _getFYLabel(String tallyDate) {
    if (tallyDate.length != 8) return '';
    final year = int.tryParse(tallyDate.substring(0, 4)) ?? 0;
    final month = int.tryParse(tallyDate.substring(4, 6)) ?? 0;
    final fyStart = month >= 4 ? year : year - 1;
    return 'FY $fyStart-${(fyStart + 1).toString().substring(2)}';
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
            icon: const Icon(Icons.refresh_outlined, size: 20),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Company + Month Selector Header ──────────────────
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
                const SizedBox(height: 8),
                // Month selector pill
                GestureDetector(
                  onTap: _showMonthPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 15, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          _selectedMonth != null
                              ? 'Closing: ${_formatMonthLabel(_selectedMonth!)}'
                              : 'Select Month',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: Colors.blue[700]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // ── Table Header ──────────────────────────────────────
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

          // ── Table Rows ────────────────────────────────────────
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

          // ── Total Footer ──────────────────────────────────────
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Closing Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (_selectedMonth != null)
                        Text(
                          'As of ${_formatMonthLabel(_selectedMonth!)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                    ],
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