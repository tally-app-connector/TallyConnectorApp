class SalesDataPoint {
  final String label;
  final double value;
  final double? previousValue;

  const SalesDataPoint({
    required this.label,
    required this.value,
    this.previousValue,
  });
}

enum ChartPeriod { monthly, quarterly, yoy }
