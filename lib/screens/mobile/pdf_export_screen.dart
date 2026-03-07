import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/company_model.dart';
import '../models/report_data.dart';
import '../service/pdf_export_service.dart';
import '../theme/app_theme.dart';

class PdfExportScreen extends StatelessWidget {
  final Company company;
  final ReportMetric metric;
  final ReportValue reportValue;
  final ReportChartData chartData;
  final DateRangeFilter dateRange;
  final SalesPurchaseChartData? salesPurchaseData;
  final RevenueExpenseProfitData? revExpProfitData;
  final List<Uint8List> cardCaptures;
  final Uint8List? companyLogoBytes;

  const PdfExportScreen({
    super.key,
    required this.company,
    required this.metric,
    required this.reportValue,
    required this.chartData,
    required this.dateRange,
    this.salesPurchaseData,
    this.revExpProfitData,
    this.cardCaptures = const [],
    this.companyLogoBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${metric.displayName} Report',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF',
            onPressed: () => _sharePdf(),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => PdfExportService.generateReportPdf(
          company: company,
          metric: metric,
          reportValue: reportValue,
          chartData: chartData,
          dateRange: dateRange,
          salesPurchaseData: salesPurchaseData,
          revExpProfitData: revExpProfitData,
          cardCaptures: cardCaptures,
          companyLogoBytes: companyLogoBytes,
        ),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowSharing: true,
        allowPrinting: true,
        pdfFileName: '${metric.displayName.toLowerCase()}_report.pdf',
      ),
    );
  }

  Future<void> _sharePdf() async {
    final bytes = await PdfExportService.generateReportPdf(
      company: company,
      metric: metric,
      reportValue: reportValue,
      chartData: chartData,
      dateRange: dateRange,
      salesPurchaseData: salesPurchaseData,
      revExpProfitData: revExpProfitData,
      cardCaptures: cardCaptures,
      companyLogoBytes: companyLogoBytes,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${metric.displayName.toLowerCase()}_report.pdf',
    );
  }
}
