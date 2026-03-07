import 'dart:typed_data';
import '../models/report_data.dart';

class XmlExportService {
  static Uint8List generateStockItemsXml({
    required String companyName,
    required List<Map<String, dynamic>> items,
    DateRangeFilter? dateRange,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<StockReport company="$companyName">');
    for (final item in items) {
      buffer.writeln('  <StockItem>');
      buffer.writeln('    <Name>${_xmlEscape(item['name']?.toString() ?? '')}</Name>');
      buffer.writeln('    <Group>${_xmlEscape(item['group']?.toString() ?? '')}</Group>');
      buffer.writeln('    <Quantity>${item['quantity'] ?? 0}</Quantity>');
      buffer.writeln('    <Rate>${item['rate'] ?? 0}</Rate>');
      buffer.writeln('    <Value>${item['closing_balance'] ?? 0}</Value>');
      buffer.writeln('  </StockItem>');
    }
    buffer.writeln('</StockReport>');
    return Uint8List.fromList(buffer.toString().codeUnits);
  }

  static String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
