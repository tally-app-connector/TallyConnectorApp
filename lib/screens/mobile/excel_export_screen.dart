import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/report_data.dart';
import '../service/pdf_export_service.dart';
import '../service/xml_export_service.dart';
import '../theme/app_theme.dart';

class ExcelExportScreen extends StatelessWidget {
  final String companyName;
  final String fileName;
  final Uint8List? excelBytes;
  final List<Map<String, dynamic>> items;
  final DateRangeFilter? dateRange;
  final Uint8List? companyLogoBytes;

  const ExcelExportScreen({
    super.key,
    required this.companyName,
    required this.fileName,
    required this.excelBytes,
    required this.items,
    this.dateRange,
    this.companyLogoBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          companyName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'No stock items found',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Company Logo + Name + Date Range Header (Outside Table) ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Company Logo
                        if (companyLogoBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              companyLogoBytes!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D8BE0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials(companyName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        // Company Name
                        Text(
                          companyName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Report Title
                        const Text(
                          'Stock Items Report',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        // Date Range
                        if (dateRange != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F7FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              _dateRangeText(dateRange!),
                              style: const TextStyle(
                                color: Color(0xFF2D8BE0),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // ─── Data Table ───
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF2D8BE0),
                  ),
                  headingTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  dataTextStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  border: TableBorder.all(
                    color: AppColors.divider,
                    width: 1,
                  ),
                  columns: const [
                    DataColumn(label: Text('Sr No')),
                    DataColumn(label: Text('Item Name')),
                    DataColumn(label: Text('Parent Group')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('HSN Code')),
                    DataColumn(label: Text('GST %')),
                    DataColumn(label: Text('CGST %'), numeric: true),
                    DataColumn(label: Text('SGST %'), numeric: true),
                    DataColumn(label: Text('IGST %'), numeric: true),
                    DataColumn(label: Text('Opening Bal'), numeric: true),
                    DataColumn(label: Text('Opening Value (₹)'), numeric: true),
                    DataColumn(label: Text('MRP (₹)'), numeric: true),
                    DataColumn(label: Text('Total Sales (₹)'), numeric: true),
                    DataColumn(label: Text('Total Purchase (₹)'), numeric: true),
                    DataColumn(label: Text('Profit (₹)'), numeric: true),
                  ],
                  rows: List.generate(items.length, (i) {
                    final item = items[i];
                    final totalSales =
                        (item['total_sales'] as num?)?.toDouble() ?? 0.0;
                    final totalPurchase =
                        (item['total_purchase'] as num?)?.toDouble() ?? 0.0;
                    final profit = totalSales - totalPurchase;
                    final gstRate = item['gst_rate'] as String? ?? '';
                    final cgstRate = (item['cgst_rate'] as num?)?.toDouble() ?? 0.0;
                    final sgstRate = (item['sgst_rate'] as num?)?.toDouble() ?? 0.0;
                    final igstRate = (item['igst_rate'] as num?)?.toDouble() ?? 0.0;
                    final openingBal = (item['opening_balance'] as num?)?.toDouble() ?? 0.0;
                    final openingVal = (item['opening_value'] as num?)?.toDouble() ?? 0.0;
                    final mrpRate = (item['mrp_rate'] as num?)?.toDouble() ?? 0.0;

                    return DataRow(
                      color: WidgetStateProperty.resolveWith((states) {
                        return i.isEven
                            ? Colors.white
                            : const Color(0xFFF9FAFB);
                      }),
                      cells: [
                        DataCell(Text('${i + 1}',
                            textAlign: TextAlign.center)),
                        DataCell(Text(item['name'] as String? ?? '')),
                        DataCell(Text(item['parent'] as String? ?? '')),
                        DataCell(Text(item['category'] as String? ?? '')),
                        DataCell(Text(item['base_units'] as String? ?? '',
                            textAlign: TextAlign.center)),
                        DataCell(Text(
                            item['latest_hsn_code'] as String? ?? '',
                            textAlign: TextAlign.center)),
                        DataCell(Text(
                            gstRate.isNotEmpty ? '$gstRate%' : '',
                            textAlign: TextAlign.center)),
                        DataCell(Text(
                          _formatAmount(cgstRate),
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          _formatAmount(sgstRate),
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          _formatAmount(igstRate),
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          _formatAmount(openingBal),
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          _formatAmount(openingVal),
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          _formatAmount(mrpRate),
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          _formatAmount(totalSales),
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          _formatAmount(totalPurchase),
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          _formatAmount(profit),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: profit >= 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        )),
                      ],
                    );
                  }),
                ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: excelBytes == null ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Row 1: PDF & XML ───
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _exportAsPdf(context),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Save as PDF', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _exportAsXml(context),
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('Save as XML', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ─── Row 2: Save Excel & Share ───
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveFile(context),
                      icon: const Icon(Icons.save_alt, size: 18),
                      label: const Text('Save Excel', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareFile(context),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share Excel', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'S';
  }

  String _dateRangeText(DateRangeFilter range) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final now = DateTime.now();
    final effectiveEnd = range.endDate.isAfter(now) ? now : range.endDate;
    return '${dateFormat.format(range.startDate)} - ${dateFormat.format(effectiveEnd)}';
  }

  String _formatAmount(double amount) {
    final isNegative = amount < 0;
    final abs = amount.abs();
    final parts = abs.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    // Indian numbering format
    String formatted = '';
    if (intPart.length <= 3) {
      formatted = intPart;
    } else {
      formatted = intPart.substring(intPart.length - 3);
      var remaining = intPart.substring(0, intPart.length - 3);
      while (remaining.length > 2) {
        formatted = '${remaining.substring(remaining.length - 2)},$formatted';
        remaining = remaining.substring(0, remaining.length - 2);
      }
      if (remaining.isNotEmpty) {
        formatted = '$remaining,$formatted';
      }
    }
    return '${isNegative ? '-' : ''}$formatted.$decPart';
  }

  Future<void> _saveFile(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(excelBytes!);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${file.path}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      // Open share sheet so user can save to Files app
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _exportAsXml(BuildContext context) async {
    try {
      final xmlBytes = XmlExportService.generateStockItemsXml(
        companyName: companyName,
        items: items,
        dateRange: dateRange,
      );

      final dir = await getTemporaryDirectory();
      final xmlFileName =
          '${companyName.replaceAll(' ', '_')}_stock_items.xml';
      final file = File('${dir.path}/$xmlFileName');
      await file.writeAsBytes(xmlBytes);

      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate XML: $e')),
      );
    }
  }

  Future<void> _exportAsPdf(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
      );

      final pdfBytes = await PdfExportService.generateStockItemsPdf(
        companyName: companyName,
        items: items,
        dateRange: dateRange,
        companyLogoBytes: companyLogoBytes,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading

      final pdfFileName =
          '${companyName.replaceAll(' ', '_')}_stock_items.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: pdfFileName);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(excelBytes!);

      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }
}
