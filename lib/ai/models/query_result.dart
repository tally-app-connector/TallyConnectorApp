/// Query Result Model
/// Contains results from executing SQL queries locally
class QueryResult {
  final List<Map<String, dynamic>> data;
  final int rowCount;
  final int executionTimeMs;
  final String? error;

  QueryResult({
    required this.data,
    required this.rowCount,
    required this.executionTimeMs,
    this.error,
  });

  bool get hasError => error != null;
  bool get isEmpty => data.isEmpty;
  bool get isNotEmpty => data.isNotEmpty;

  /// Get column names from first row
  List<String> get columnNames {
    if (data.isEmpty) return [];
    return data.first.keys.toList();
  }

  /// Format execution time
  String get formattedExecutionTime {
    if (executionTimeMs < 1000) {
      return '${executionTimeMs}ms';
    } else {
      return '${(executionTimeMs / 1000).toStringAsFixed(2)}s';
    }
  }
}
