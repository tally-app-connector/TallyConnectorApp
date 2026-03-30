import 'dart:typed_data';
import '../models/report_data.dart';
import '../database/database_helper.dart';

class ExcelExportResult {
  final Uint8List bytes;
  final List<Map<String, dynamic>> items;

  const ExcelExportResult({required this.bytes, required this.items});
}

class ExcelExportService {
  static Future<ExcelExportResult> generateStockItemsExcel({
    required String companyGuid,
    required String companyName,
    DateRangeFilter? dateRange,
    Uint8List? companyLogoBytes,
    List<Map<String, dynamic>>? items,
  }) async {
    final stockItems = items ?? await _fetchStockItems(companyGuid);

    final buffer = StringBuffer();
    buffer.writeln('Stock Items Report - $companyName');
    buffer.writeln('');
    buffer.writeln('Name,Group,Quantity,Rate,Value');
    for (final item in stockItems) {
      buffer.writeln([
        _escape(item['name']?.toString() ?? ''),
        _escape(item['stock_group']?.toString() ?? item['group']?.toString() ?? ''),
        item['quantity']?.toString() ?? '0',
        item['rate']?.toString() ?? '0',
        item['closing_balance']?.toString() ?? '0',
      ].join(','));
    }

    return ExcelExportResult(
      bytes: Uint8List.fromList(buffer.toString().codeUnits),
      items: stockItems,
    );
  }

  static Future<List<Map<String, dynamic>>> _fetchStockItems(String companyGuid) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.query(
        'stock_items',
        where: 'company_guid = ?',
        whereArgs: [companyGuid],
      );
    } catch (_) {
      return [];
    }
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
