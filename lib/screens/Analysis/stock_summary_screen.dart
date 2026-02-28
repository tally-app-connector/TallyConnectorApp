// screens/stock_summary_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class StockSummaryScreen extends StatefulWidget {
  @override
  _StockSummaryScreenState createState() => _StockSummaryScreenState();
}

class _StockSummaryScreenState extends State<StockSummaryScreen> {
  final _db = DatabaseHelper.instance;
  
  String? _companyGuid;
  String? _companyName;
  bool _loading = true;
  
  List<Map<String, dynamic>> _stockData = [];
  Map<String, List<Map<String, dynamic>>> _groupedStock = {};
  double _totalValue = 0.0;
  
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
    
    await _getStockSummary();
    
    setState(() => _loading = false);
  }
  
  Future<void> _getStockSummary() async {
    final db = await _db.database;
    
    final stockData = await db.rawQuery('''
      SELECT 
        name,
        parent,
        opening_balance as quantity,
        opening_rate as rate,
        opening_value as value,
        base_units
      FROM stock_items
      WHERE company_guid = ?
          AND is_deleted = 0
          AND opening_balance != 0
      ORDER BY parent, name
    ''', [_companyGuid]);
    
    // Group by category/parent
    final grouped = <String, List<Map<String, dynamic>>>{};
    double total = 0.0;
    
    for (final item in stockData) {
      final parent = (item['parent'] as String?) ?? 'Uncategorized';
      if (!grouped.containsKey(parent)) {
        grouped[parent] = [];
      }
      grouped[parent]!.add(item);
      total += (item['value'] as num?)?.toDouble() ?? 0.0;
    }
    
    setState(() {
      _stockData = stockData.cast<Map<String, dynamic>>();
      _groupedStock = grouped;
      _totalValue = total;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Stock Summary')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Stock Summary'),
        actions: [
          IconButton(icon: Icon(Icons.search), onPressed: () {}),
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
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
                  'Closing Balance',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          
          // Column Headers
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Particulars', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Quantity', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Value', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          
          // Stock Items
          Expanded(
            child: ListView.builder(
              itemCount: _groupedStock.keys.length,
              itemBuilder: (context, index) {
                final category = _groupedStock.keys.elementAt(index);
                final items = _groupedStock[category]!;
                final categoryTotal = items.fold<double>(
                  0.0,
                  (sum, item) => sum + ((item['value'] as num?)?.toDouble() ?? 0.0),
                );
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header
                    Container(
                      color: Colors.amber[100],
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            category.toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            _formatAmount(categoryTotal),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    
                    // Items in category
                    ...items.map((item) => _buildStockItem(item)),
                  ],
                );
              },
            ),
          ),
          
          // Grand Total
          Container(
            color: Colors.grey[300],
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_formatAmount(_totalValue), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStockItem(Map<String, dynamic> item) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item['name'] ?? '',
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              '${_formatQuantity(item['quantity'])} ${item['base_units'] ?? ''}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              _formatAmount((item['rate'] as num?)?.toDouble() ?? 0.0),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              _formatAmount((item['value'] as num?)?.toDouble() ?? 0.0),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
  
  String _formatQuantity(dynamic qty) {
    if (qty == null) return '0.0';
    final value = (qty as num).toDouble();
    return value.toStringAsFixed(1);
  }
}