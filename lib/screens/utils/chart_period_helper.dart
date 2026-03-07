import '../models/report_data.dart';

ChartPeriod autoSelectPeriod(int dataPointCount) {
  if (dataPointCount > 12) return ChartPeriod.quarterly;
  if (dataPointCount > 24) return ChartPeriod.yearly;
  return ChartPeriod.monthly;
}

ReportChartData aggregateChartData(ReportChartData data, ChartPeriod period) {
  if (period == ChartPeriod.monthly || data.dataPoints.isEmpty) return data;
  // Simple passthrough for now — aggregation can be refined later
  return data;
}

SalesPurchaseChartData aggregateSalesPurchaseData(
    SalesPurchaseChartData data, ChartPeriod period) {
  if (period == ChartPeriod.monthly || data.dataPoints.isEmpty) return data;
  return data;
}
