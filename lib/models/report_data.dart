import 'package:flutter/material.dart';
import '../screens/theme/app_theme.dart';
import '../screens/icons/app_icons.dart';

// ─────────────────────────────────────────────
//  REPORT METRIC ENUM
// ─────────────────────────────────────────────
enum ReportMetric {
  sales,
  purchase,
  profit,
  receivable,
  payable,
  receipts,
  payments,
  gst,
  stock;

  String get displayName {
    switch (this) {
      case ReportMetric.sales: return 'Net Sales';
      case ReportMetric.purchase: return 'Net Purchase';
      case ReportMetric.profit: return 'Gross Profit';
      case ReportMetric.receivable: return 'Receivables';
      case ReportMetric.payable: return 'Payables';
      case ReportMetric.receipts: return 'Receipts';
      case ReportMetric.payments: return 'Payments';
      case ReportMetric.gst: return 'GST';
      case ReportMetric.stock: return 'Stock';
    }
  }

  String get icon {
    switch (this) {
      case ReportMetric.sales: return AppIcons.barChart;
      case ReportMetric.purchase: return AppIcons.receipt;
      case ReportMetric.profit: return AppIcons.arrowUpCircle;
      case ReportMetric.receivable: return AppIcons.users;
      case ReportMetric.payable: return AppIcons.users;
      case ReportMetric.receipts: return AppIcons.trendingUp;
      case ReportMetric.payments: return AppIcons.wallet;
      case ReportMetric.gst: return AppIcons.receipt;
      case ReportMetric.stock: return AppIcons.box;
    }
  }

  Color get iconBgColor {
    switch (this) {
      case ReportMetric.sales: return AppColors.iconBgBlue;
      case ReportMetric.purchase: return AppColors.iconBgAmber;
      case ReportMetric.profit: return AppColors.iconBgGreen;
      case ReportMetric.receivable: return AppColors.iconBgPurple;
      case ReportMetric.payable: return AppColors.iconBgRed;
      case ReportMetric.receipts: return AppColors.iconBgGreen;
      case ReportMetric.payments: return AppColors.iconBgRed;
      case ReportMetric.gst: return AppColors.iconBgAmber;
      case ReportMetric.stock: return AppColors.iconBgPurple;
    }
  }

  Color get accentColor {
    switch (this) {
      case ReportMetric.sales: return AppColors.blue;
      case ReportMetric.purchase: return AppColors.amber;
      case ReportMetric.profit: return AppColors.green;
      case ReportMetric.receivable: return AppColors.purple;
      case ReportMetric.payable: return AppColors.red;
      case ReportMetric.receipts: return AppColors.green;
      case ReportMetric.payments: return AppColors.red;
      case ReportMetric.gst: return AppColors.amber;
      case ReportMetric.stock: return AppColors.purple;
    }
  }

  ReportChartType get defaultChartType => ReportChartType.bar;

  List<ReportChartType> get applicableChartTypes => ReportChartType.values;

  String get topItemsTitle {
    switch (this) {
      case ReportMetric.sales: return 'Top Selling Items';
      case ReportMetric.purchase: return 'Top Purchased Items';
      case ReportMetric.stock: return 'Top Stock Items';
      default: return 'Top Items';
    }
  }
}

// ─────────────────────────────────────────────
//  REPORT VALUE
// ─────────────────────────────────────────────
class ReportValue {
  final String primaryValue;
  final String primaryUnit;
  final String primaryLabel;
  final String changePercent;
  final bool isPositiveChange;
  final DateTime periodStart;
  final DateTime periodEnd;

  const ReportValue({
    required this.primaryValue,
    required this.primaryUnit,
    this.primaryLabel = '',
    required this.changePercent,
    required this.isPositiveChange,
    required this.periodStart,
    required this.periodEnd,
  });
}

// ─────────────────────────────────────────────
//  CHART TYPES
// ─────────────────────────────────────────────
enum ReportChartType { bar, line, area, pie, horizontalBar }

// ─────────────────────────────────────────────
//  CHART DATA
// ─────────────────────────────────────────────
class ReportChartData {
  final List<ChartDataPoint> dataPoints;
  final ReportChartType chartType;
  final String title;
  final List<ChartLegendItem> legends;

  const ReportChartData({
    required this.dataPoints,
    required this.chartType,
    required this.title,
    this.legends = const [],
  });
}

class ChartDataPoint {
  final String label;
  final double value;
  final double? secondaryValue;

  const ChartDataPoint({
    required this.label,
    required this.value,
    this.secondaryValue,
  });
}

class ChartLegendItem {
  final String label;
  final Color color;

  const ChartLegendItem({required this.label, required this.color});
}

// ─────────────────────────────────────────────
//  DATE RANGE FILTER
// ─────────────────────────────────────────────
enum DateRangeType { mom, ytd, quarter, custom }

class DateRangeFilter {
  final DateRangeType type;
  final DateTime startDate;
  final DateTime endDate;

  DateRangeFilter({
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  factory DateRangeFilter.ytd() {
    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
    return DateRangeFilter(type: DateRangeType.ytd, startDate: fyStart, endDate: now);
  }

  factory DateRangeFilter.mom() {
    final now = DateTime.now();
    return DateRangeFilter(
      type: DateRangeType.mom,
      startDate: DateTime(now.year, now.month, 1),
      endDate: now,
    );
  }

  factory DateRangeFilter.quarter() {
    final now = DateTime.now();
    final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    return DateRangeFilter(
      type: DateRangeType.quarter,
      startDate: DateTime(now.year, qMonth, 1),
      endDate: now,
    );
  }

  factory DateRangeFilter.custom(DateTime start, DateTime end) {
    return DateRangeFilter(type: DateRangeType.custom, startDate: start, endDate: end);
  }

  String get displayText {
    switch (type) {
      case DateRangeType.mom:
        return 'Month to Date';
      case DateRangeType.ytd:
        return 'Year to Date';
      case DateRangeType.quarter:
        return 'Quarter to Date';
      case DateRangeType.custom:
        return '${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}';
    }
  }
}

// ─────────────────────────────────────────────
//  SALES PURCHASE COMBO DATA
// ─────────────────────────────────────────────
class SalesPurchaseChartData {
  final List<SalesPurchaseDataPoint> dataPoints;
  final String title;

  const SalesPurchaseChartData({
    required this.dataPoints,
    required this.title,
  });
}

class SalesPurchaseDataPoint {
  final String label;
  final double salesValue;
  final double purchaseValue;

  const SalesPurchaseDataPoint({
    required this.label,
    required this.salesValue,
    required this.purchaseValue,
  });
}

// ─────────────────────────────────────────────
//  REVENUE EXPENSE PROFIT DATA
// ─────────────────────────────────────────────
class RevenueExpenseProfitData {
  final double revenue;
  final double expense;
  final double profit;

  const RevenueExpenseProfitData({
    required this.revenue,
    required this.expense,
    required this.profit,
  });
}

// ─────────────────────────────────────────────
//  TOP SELLING ITEM
// ─────────────────────────────────────────────
class TopSellingItem {
  final int rank;
  final String name;
  final String category;
  final int unitsSold;
  final double revenue;
  final double changePercent;
  final bool isPositive;

  const TopSellingItem({
    required this.rank,
    required this.name,
    this.category = '',
    required this.unitsSold,
    required this.revenue,
    required this.changePercent,
    required this.isPositive,
  });
}

// ─────────────────────────────────────────────
//  GROUP OUTSTANDING
// ─────────────────────────────────────────────
class GroupOutstanding {
  final String groupName;
  final double amount;
  final int partyCount;
  final double percentage;

  const GroupOutstanding({
    required this.groupName,
    required this.amount,
    required this.partyCount,
    this.percentage = 0,
  });
}

// ─────────────────────────────────────────────
//  CREDIT LIMIT PARTY
// ─────────────────────────────────────────────
class CreditLimitParty {
  final String name;
  final double currentOutstanding;
  final double creditLimit;
  final int daysOverLimit;

  const CreditLimitParty({
    required this.name,
    required this.currentOutstanding,
    required this.creditLimit,
    this.daysOverLimit = 0,
  });
}

// ─────────────────────────────────────────────
//  PAYMENT DUE PARTY
// ─────────────────────────────────────────────
class PaymentDueParty {
  final String name;
  final double amountDue;
  final int daysOverdue;
  final DateTime? dueDate;

  const PaymentDueParty({
    required this.name,
    required this.amountDue,
    this.daysOverdue = 0,
    this.dueDate,
  });
}

// ─────────────────────────────────────────────
//  FISCAL YEAR
// ─────────────────────────────────────────────
class FiscalYear {
  final int startYear;
  final int endYear;
  final DateTime startDate;
  final DateTime endDate;

  FiscalYear({
    required this.startYear,
    required this.endYear,
    required this.startDate,
    required this.endDate,
  });

  factory FiscalYear.current() {
    final now = DateTime.now();
    final sy = now.month >= 4 ? now.year : now.year - 1;
    return FiscalYear(
      startYear: sy,
      endYear: sy + 1,
      startDate: DateTime(sy, 4, 1),
      endDate: DateTime(sy + 1, 3, 31),
    );
  }

  static List<FiscalYear> available() {
    final current = FiscalYear.current();
    return [
      current,
      FiscalYear(
        startYear: current.startYear - 1,
        endYear: current.endYear - 1,
        startDate: DateTime(current.startYear - 1, 4, 1),
        endDate: DateTime(current.startYear, 3, 31),
      ),
      FiscalYear(
        startYear: current.startYear - 2,
        endYear: current.endYear - 2,
        startDate: DateTime(current.startYear - 2, 4, 1),
        endDate: DateTime(current.startYear - 1, 3, 31),
      ),
    ];
  }

  String get displayText => 'FY $startYear-${endYear.toString().substring(2)}';

  @override
  String toString() => displayText;
}

// ─────────────────────────────────────────────
//  TOP PAYING PARTY
// ─────────────────────────────────────────────
class TopPayingParty {
  final String name;
  final double amount;
  final double percentage;

  const TopPayingParty({
    required this.name,
    required this.amount,
    this.percentage = 0,
  });
}

// ─────────────────────────────────────────────
//  TOP VENDOR PARTY
// ─────────────────────────────────────────────
class TopVendorParty {
  final String name;
  final double amount;
  final double percentage;

  const TopVendorParty({
    required this.name,
    required this.amount,
    this.percentage = 0,
  });
}

// ─────────────────────────────────────────────
//  CHART PERIOD
// ─────────────────────────────────────────────
enum ChartPeriod { monthly, quarterly, yearly }

extension ChartPeriodExtension on ChartPeriod {
  static ChartPeriod fromIndex(int index) {
    switch (index) {
      case 0: return ChartPeriod.monthly;
      case 1: return ChartPeriod.quarterly;
      case 2: return ChartPeriod.yearly;
      default: return ChartPeriod.monthly;
    }
  }
}
