import 'package:sqflite/sqflite.dart';

// Mirror types for stock valuation (avoids circular dependency with main app)

class AiStockValuationResult {
  final double openingStockValue;
  final double closingStockValue;
  final int itemCount;
  final List<AiStockItemResult> detailedResults;

  AiStockValuationResult({
    required this.openingStockValue,
    required this.closingStockValue,
    required this.itemCount,
    required this.detailedResults,
  });
}

class AiStockItemResult {
  final String itemName;
  final String stockGroup;
  final String unit;
  final Map<String, AiGodownCost> godowns;

  AiStockItemResult({
    required this.itemName,
    this.stockGroup = '',
    this.unit = '',
    required this.godowns,
  });
}

class AiGodownCost {
  final String godownName;
  final double currentStockQty;
  final double closingValue;
  final double totalInwardQty;
  final double totalOutwardQty;
  final double averageRate;

  AiGodownCost({
    this.godownName = '',
    required this.currentStockQty,
    required this.closingValue,
    this.totalInwardQty = 0.0,
    this.totalOutwardQty = 0.0,
    this.averageRate = 0.0,
  });
}

/// Dependency injection for ai_queries package.
/// Must be initialized by the host app before using AI features.
class AiDependencies {
  static Future<Database> Function()? databaseProvider;
  static String? apiBaseUrl;
  static Future<AiStockValuationResult> Function({
    required String companyGuid,
    required String fromDate,
    required String toDate,
  })? stockValuationCalculator;
  static String Function(String dateStr)? fyStartDateGetter;

  /// API keys for direct AI provider access (no backend needed)
  static String claudeApiKey = '';
  static String huggingFaceApiKey = '';
  static String openRouterApiKey = '';
  static String glm5ApiKey = '';

  static bool get isInitialized =>
      databaseProvider != null;
}
