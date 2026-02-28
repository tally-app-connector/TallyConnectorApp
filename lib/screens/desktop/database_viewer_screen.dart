import 'dart:convert';

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({Key? key}) : super(key: key);

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  
  String _selectedTable = 'companies';
  List<Map<String, dynamic>> _tableData = [];
  List<String> _columnNames = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = '';

  final List<String> _tables = [
    'companies',
    'groups',
    'ledgers',
    'ledger_contacts',
    'ledger_mailing_details',
    'ledger_gst_registrations',
    'ledger_closing_balances',
    'stock_items',
    'stock_item_hsn_history',
    'stock_item_batch_allocation',
    'stock_item_gst_history',
    'voucher_types',
    'vouchers',
    'voucher_ledger_entries',
    'voucher_inventory_entries',
    'voucher_batch_allocations'
  ];

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTableData() async {
    setState(() => _isLoading = true);

    try {
      final db = await _db.database;
      final data = await db.query(_selectedTable);
      // prettyPrint(data);
      setState(() {
        _tableData = data;
        _columnNames = data.isNotEmpty ? data.first.keys.toList() : [];
        _isLoading = false;
        _isSearching = false;
        _searchQuery = '';
      });
    } catch (e) {
      print('Error loading table: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchByGuid(String guid) async {
    if (guid.trim().isEmpty) {
      _loadTableData();
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _searchQuery = guid.trim();
    });

    try {
      final db = await _db.database;
      
      // Search in GUID column (case-insensitive)
      final data = await db.query(
        _selectedTable,
        where: 'is_cancelled = ?',
        whereArgs: [guid],
      );

      // prettyPrint(data);
      
      setState(() {
        _tableData = data;
        _columnNames = data.isNotEmpty ? data.first.keys.toList() : [];
        _isLoading = false;
      });

      // Show snackbar with results
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${data.length} result(s) matching "$guid"'),
            duration: const Duration(seconds: 2),
            backgroundColor: data.isEmpty ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error searching: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _loadTableData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTableData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Table Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Text(
                  'Select Table:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedTable,
                    isExpanded: true,
                    items: _tables.map((table) {
                      return DropdownMenuItem(
                        value: table,
                        child: Text(table),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedTable = value);
                        _searchController.clear();
                        _loadTableData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Chip(
                  label: Text('${_tableData.length} rows'),
                  backgroundColor: Colors.blue[100],
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by GUID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _searchByGuid,
                    onChanged: (value) {
                      setState(() {}); // Update to show/hide clear button
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _searchByGuid(_searchController.text),
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Search Indicator
          if (_isSearching)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Filtering by GUID: "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
            ),

          // Table Data
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tableData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isSearching ? Icons.search_off : Icons.inbox,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isSearching 
                                  ? 'No results found for "$_searchQuery"'
                                  : 'No data available',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            if (_isSearching) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _clearSearch,
                                child: const Text('Clear search and show all'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                            border: TableBorder.all(color: Colors.grey[300]!),
                            columnSpacing: 20,
                            horizontalMargin: 10,
                            columns: _columnNames.map((column) {
                              return DataColumn(
                                label: Row(
                                  children: [
                                    Text(
                                      column,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (column.toLowerCase() == 'guid')
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.search,
                                          size: 14,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            rows: _tableData.map((row) {
                              return DataRow(
                                cells: _columnNames.map((column) {
                                  final value = row[column];
                                  return DataCell(
                                    _buildCellContent(column, value),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),

          // Summary Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total Rows', '${_tableData.length}', Icons.table_rows),
                _buildStatCard('Columns', '${_columnNames.length}', Icons.view_column),
                _buildStatCard('Table', _selectedTable, Icons.table_chart),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(String column, dynamic value) {
    if (value == null) {
      return const Text('NULL', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
    }

    // Highlight GUID matches
    if (column.toLowerCase() == 'guid' && _isSearching) {
      final valueStr = value.toString();
      if (valueStr.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.yellow[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            valueStr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }

    // Format timestamps
    if (column.contains('date') || column.contains('_at')) {
      if (value is int && value > 0) {
        final date = DateTime.fromMillisecondsSinceEpoch(value);
        return Text(
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 12),
        );
      }
    }

    // Format large numbers
    if (value is num && value.abs() > 1000) {
      return Text(
        value.toStringAsFixed(2),
        style: const TextStyle(fontSize: 12),
      );
    }

    // Truncate long strings
    String displayText = value.toString();
    if (displayText.length > 50) {
      displayText = '${displayText.substring(0, 47)}...';
    }

    return Text(
      displayText,
      style: const TextStyle(fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void prettyPrint(dynamic obj) {
  if (obj is Map || obj is List) {
    print(JsonEncoder.withIndent('  ').convert(obj));
  } else {
    // Try to convert to JSON if it has toJson method
    try {
      final json = (obj as dynamic).toJson();
      print(JsonEncoder.withIndent('  ').convert(json));
    } catch (e) {
      print(obj.toString());
    }
  }
}