import '../models/report_data.dart';

const int _maxBars = 12;

// ─────────────────────────────────────────────
//  SHARED LABEL FORMATTER
// ─────────────────────────────────────────────
/// Format chart axis label: "202504" → "Apr'25", truncate long text.
String formatChartLabel(String label) {
  if (label.length == 6 && int.tryParse(label) != null) {
    final year = label.substring(2, 4);
    final monthNum = int.tryParse(label.substring(4, 6)) ?? 1;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${months[monthNum - 1]}'$year";
  }
  // Truncate long labels for chart axis display
  if (label.length > 16) return '${label.substring(0, 14)}..';
  return label;
}

// ─────────────────────────────────────────────
//  AUTO SELECT PERIOD
// ─────────────────────────────────────────────
ChartPeriod autoSelectPeriod(int dataPointCount) {
  if (dataPointCount > 48) return ChartPeriod.yearly;
  if (dataPointCount > 16) return ChartPeriod.quarterly;
  return ChartPeriod.monthly;
}

// ─────────────────────────────────────────────
//  AGGREGATE REPORT CHART DATA
// ─────────────────────────────────────────────
ReportChartData aggregateChartData(ReportChartData data, ChartPeriod period) {
  if (data.dataPoints.isEmpty) return data;

  List<ChartDataPoint> grouped;
  switch (period) {
    case ChartPeriod.monthly:
      grouped = data.dataPoints;
      break;
    case ChartPeriod.quarterly:
      grouped = _groupChartByQuarter(data.dataPoints);
      break;
    case ChartPeriod.yearly:
      grouped = _groupChartByYear(data.dataPoints);
      break;
  }

  grouped = _mergeChartToFit(grouped);

  return ReportChartData(
    dataPoints: grouped,
    chartType: data.chartType,
    title: data.title,
    legends: data.legends,
  );
}

// ─────────────────────────────────────────────
//  AGGREGATE SALES PURCHASE DATA
// ─────────────────────────────────────────────
SalesPurchaseChartData aggregateSalesPurchaseData(
    SalesPurchaseChartData data, ChartPeriod period) {
  if (data.dataPoints.isEmpty) return data;

  List<SalesPurchaseDataPoint> grouped;
  switch (period) {
    case ChartPeriod.monthly:
      grouped = data.dataPoints;
      break;
    case ChartPeriod.quarterly:
      grouped = _groupComboByQuarter(data.dataPoints);
      break;
    case ChartPeriod.yearly:
      grouped = _groupComboByYear(data.dataPoints);
      break;
  }

  grouped = _mergeComboToFit(grouped);

  return SalesPurchaseChartData(
    dataPoints: grouped,
    title: data.title,
  );
}

// ─────────────────────────────────────────────
//  FISCAL YEAR HELPERS (Indian FY: Apr-Mar)
// ─────────────────────────────────────────────
int _fiscalYear(int year, int month) {
  return month >= 4 ? year : year - 1;
}

int _fiscalQuarter(int month) {
  if (month >= 4 && month <= 6) return 1;
  if (month >= 7 && month <= 9) return 2;
  if (month >= 10 && month <= 12) return 3;
  return 4; // Jan-Mar
}

String _fyShort(int fyStartYear) {
  return '${(fyStartYear % 100).toString().padLeft(2, '0')}';
}

String _fyLabel(int fyStartYear) {
  return 'FY${_fyShort(fyStartYear)}';
}

/// Parse "YYYYMM" → (year, month). Returns null if invalid.
(int, int)? _parseYYYYMM(String label) {
  if (label.length < 6) return null;
  final y = int.tryParse(label.substring(0, 4));
  final m = int.tryParse(label.substring(4, 6));
  if (y == null || m == null || m < 1 || m > 12) return null;
  return (y, m);
}

// ─────────────────────────────────────────────
//  GROUP CHART DATA BY QUARTER
// ─────────────────────────────────────────────
List<ChartDataPoint> _groupChartByQuarter(List<ChartDataPoint> points) {
  final Map<String, double> buckets = {};
  final Map<String, String> labels = {};

  for (final dp in points) {
    final parsed = _parseYYYYMM(dp.label);
    if (parsed == null) continue;
    final (year, month) = parsed;
    final fy = _fiscalYear(year, month);
    final q = _fiscalQuarter(month);
    final key = '${fy}Q$q';
    buckets[key] = (buckets[key] ?? 0) + dp.value;
    labels[key] = 'Q$q\'${_fyShort(fy)}';
  }

  return buckets.entries.map((e) {
    return ChartDataPoint(label: labels[e.key]!, value: e.value);
  }).toList();
}

// ─────────────────────────────────────────────
//  GROUP CHART DATA BY YEAR
// ─────────────────────────────────────────────
List<ChartDataPoint> _groupChartByYear(List<ChartDataPoint> points) {
  final Map<int, double> buckets = {};

  for (final dp in points) {
    final parsed = _parseYYYYMM(dp.label);
    if (parsed == null) continue;
    final (year, month) = parsed;
    final fy = _fiscalYear(year, month);
    buckets[fy] = (buckets[fy] ?? 0) + dp.value;
  }

  final sorted = buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return sorted.map((e) {
    return ChartDataPoint(label: _fyLabel(e.key), value: e.value);
  }).toList();
}

// ─────────────────────────────────────────────
//  GROUP COMBO DATA BY QUARTER
// ─────────────────────────────────────────────
List<SalesPurchaseDataPoint> _groupComboByQuarter(
    List<SalesPurchaseDataPoint> points) {
  final Map<String, double> sales = {};
  final Map<String, double> purchase = {};
  final Map<String, String> labels = {};

  for (final dp in points) {
    final parsed = _parseYYYYMM(dp.label);
    if (parsed == null) continue;
    final (year, month) = parsed;
    final fy = _fiscalYear(year, month);
    final q = _fiscalQuarter(month);
    final key = '${fy}Q$q';
    sales[key] = (sales[key] ?? 0) + dp.salesValue;
    purchase[key] = (purchase[key] ?? 0) + dp.purchaseValue;
    labels[key] = 'Q$q\'${_fyShort(fy)}';
  }

  return sales.keys.map((key) {
    return SalesPurchaseDataPoint(
      label: labels[key]!,
      salesValue: sales[key]!,
      purchaseValue: purchase[key]!,
    );
  }).toList();
}

// ─────────────────────────────────────────────
//  GROUP COMBO DATA BY YEAR
// ─────────────────────────────────────────────
List<SalesPurchaseDataPoint> _groupComboByYear(
    List<SalesPurchaseDataPoint> points) {
  final Map<int, double> sales = {};
  final Map<int, double> purchase = {};

  for (final dp in points) {
    final parsed = _parseYYYYMM(dp.label);
    if (parsed == null) continue;
    final (year, month) = parsed;
    final fy = _fiscalYear(year, month);
    sales[fy] = (sales[fy] ?? 0) + dp.salesValue;
    purchase[fy] = (purchase[fy] ?? 0) + dp.purchaseValue;
  }

  final sorted = sales.keys.toList()..sort();
  return sorted.map((fy) {
    return SalesPurchaseDataPoint(
      label: _fyLabel(fy),
      salesValue: sales[fy]!,
      purchaseValue: purchase[fy]!,
    );
  }).toList();
}

// ─────────────────────────────────────────────
//  MERGE TO FIT (max 12 bars)
// ─────────────────────────────────────────────
List<ChartDataPoint> _mergeChartToFit(List<ChartDataPoint> points) {
  if (points.length <= _maxBars) return points;

  final mergeSize = (points.length / _maxBars).ceil();
  final List<ChartDataPoint> merged = [];

  for (int i = 0; i < points.length; i += mergeSize) {
    final chunk = points.sublist(i, (i + mergeSize).clamp(0, points.length));
    final sum = chunk.fold<double>(0, (s, dp) => s + dp.value);
    final label = chunk.length == 1
        ? chunk.first.label
        : '${chunk.first.label}-${chunk.last.label}';
    merged.add(ChartDataPoint(label: _shortenMergedLabel(label), value: sum));
  }

  return merged;
}

List<SalesPurchaseDataPoint> _mergeComboToFit(
    List<SalesPurchaseDataPoint> points) {
  if (points.length <= _maxBars) return points;

  final mergeSize = (points.length / _maxBars).ceil();
  final List<SalesPurchaseDataPoint> merged = [];

  for (int i = 0; i < points.length; i += mergeSize) {
    final chunk = points.sublist(i, (i + mergeSize).clamp(0, points.length));
    final salesSum = chunk.fold<double>(0, (s, dp) => s + dp.salesValue);
    final purchaseSum = chunk.fold<double>(0, (s, dp) => s + dp.purchaseValue);
    final label = chunk.length == 1
        ? chunk.first.label
        : '${chunk.first.label}-${chunk.last.label}';
    merged.add(SalesPurchaseDataPoint(
      label: _shortenMergedLabel(label),
      salesValue: salesSum,
      purchaseValue: purchaseSum,
    ));
  }

  return merged;
}

/// Shorten merged labels:
/// "FY01-FY03" → "FY01-03"
/// "Q1'25-Q2'25" → "Q1-Q2'25"
/// "Q1'25-Q4'26" → "Q1'25-Q4'26" (different FY, keep as-is)
String _shortenMergedLabel(String label) {
  if (!label.contains('-')) return label;

  // Split on first '-' only
  final idx = label.indexOf('-');
  final first = label.substring(0, idx).trim();
  final second = label.substring(idx + 1).trim();

  // "FY01-FY03" → "FY01-03"
  if (first.startsWith('FY') && second.startsWith('FY')) {
    return '$first-${second.substring(2)}';
  }

  // "Q1'25-Q2'25" → "Q1-Q2'25" (same year suffix)
  final qReg = RegExp(r"^Q(\d)'(\d+)$");
  final m1 = qReg.firstMatch(first);
  final m2 = qReg.firstMatch(second);
  if (m1 != null && m2 != null && m1.group(2) == m2.group(2)) {
    return 'Q${m1.group(1)}-Q${m2.group(1)}\'${m2.group(2)}';
  }

  return label;
}
