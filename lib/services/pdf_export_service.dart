import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/report_data.dart';
import '../models/company_model.dart';

class PdfExportService {
  /// Generate a report PDF for a specific metric (used by PdfExportScreen).
  static Future<Uint8List> generateReportPdf({
    required Company company,
    required ReportMetric metric,
    required ReportValue reportValue,
    required ReportChartData chartData,
    DateRangeFilter? dateRange,
    SalesPurchaseChartData? salesPurchaseData,
    RevenueExpenseProfitData? revExpProfitData,
    List<Uint8List>? cardCaptures,
    Uint8List? companyLogoBytes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final widgets = <pw.Widget>[];

          widgets.add(pw.Header(
            level: 0,
            child: pw.Text(
              '${metric.displayName} Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ));
          widgets.add(pw.Text(company.name, style: const pw.TextStyle(fontSize: 14)));
          if (dateRange != null) {
            widgets.add(pw.Text(dateRange.displayText, style: const pw.TextStyle(fontSize: 11)));
          }
          widgets.add(pw.SizedBox(height: 20));

          widgets.add(pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total ${metric.displayName}'),
              pw.Text(
                '${reportValue.primaryValue} ${reportValue.primaryUnit}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              ),
            ],
          ));
          widgets.add(pw.SizedBox(height: 20));

          if (cardCaptures != null) {
            for (final capture in cardCaptures) {
              final image = pw.MemoryImage(capture);
              widgets.add(pw.Image(image, width: 400));
              widgets.add(pw.SizedBox(height: 10));
            }
          }

          if (revExpProfitData != null) {
            widgets.add(pw.Header(level: 1, child: pw.Text('Revenue / Expense / Profit')));
            widgets.add(_summaryRow('Revenue', revExpProfitData.revenue));
            widgets.add(_summaryRow('Expense', revExpProfitData.expense));
            widgets.add(_summaryRow('Profit', revExpProfitData.profit));
            widgets.add(pw.SizedBox(height: 20));
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryRow(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Generate a stock items PDF (used by ExcelExportScreen).
  static Future<Uint8List> generateStockItemsPdf({
    required String companyName,
    required List<Map<String, dynamic>> items,
    Uint8List? logoBytes,
    DateRangeFilter? dateRange,
    Uint8List? companyLogoBytes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Stock Items - $companyName',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Name', 'Group', 'Quantity', 'Rate', 'Value'],
            data: items.map((item) => [
              item['name']?.toString() ?? '',
              item['group']?.toString() ?? '',
              item['quantity']?.toString() ?? '0',
              item['rate']?.toString() ?? '0',
              item['closing_balance']?.toString() ?? '0',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
