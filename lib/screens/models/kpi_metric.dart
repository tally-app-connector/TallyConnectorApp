import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../icons/app_icons.dart';

class KpiMetric {
  final String id;
  final String name;
  final String category;
  final String icon;
  final Color iconBg;

  const KpiMetric({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.iconBg,
  });
}

class KpiConfig {
  final String metricId;
  final String value;
  final String sub;
  final String badge;
  final bool isPositive;
  final int displayOrder;

  const KpiConfig({
    required this.metricId,
    required this.value,
    this.sub = '',
    this.badge = '',
    this.isPositive = true,
    this.displayOrder = 0,
  });

  KpiConfig copyWith({
    String? metricId,
    String? value,
    String? sub,
    String? badge,
    bool? isPositive,
    int? displayOrder,
  }) {
    return KpiConfig(
      metricId: metricId ?? this.metricId,
      value: value ?? this.value,
      sub: sub ?? this.sub,
      badge: badge ?? this.badge,
      isPositive: isPositive ?? this.isPositive,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'metricId': metricId,
    'value': value,
    'sub': sub,
    'badge': badge,
    'isPositive': isPositive,
    'displayOrder': displayOrder,
  };

  factory KpiConfig.fromJson(Map<String, dynamic> json) => KpiConfig(
    metricId: json['metricId'] ?? '',
    value: json['value'] ?? '',
    sub: json['sub'] ?? '',
    badge: json['badge'] ?? '',
    isPositive: json['isPositive'] ?? true,
    displayOrder: json['displayOrder'] ?? 0,
  );
}

const allKpiMetrics = <KpiMetric>[
  KpiMetric(id: 'sales', name: 'Net Sales', category: 'Revenue', icon: AppIcons.barChart, iconBg: AppColors.iconBgBlue),
  KpiMetric(id: 'purchase', name: 'Net Purchase', category: 'Expenses', icon: AppIcons.receipt, iconBg: AppColors.iconBgAmber),
  KpiMetric(id: 'profit', name: 'Gross Profit', category: 'Revenue', icon: AppIcons.arrowUpCircle, iconBg: AppColors.iconBgGreen),
  KpiMetric(id: 'receivable', name: 'Receivables', category: 'Outstanding', icon: AppIcons.users, iconBg: AppColors.iconBgPurple),
  KpiMetric(id: 'payable', name: 'Payables', category: 'Outstanding', icon: AppIcons.users, iconBg: AppColors.iconBgRed),
  KpiMetric(id: 'receipts', name: 'Receipts', category: 'Cash Flow', icon: AppIcons.trendingUp, iconBg: AppColors.iconBgGreen),
  KpiMetric(id: 'payments', name: 'Payments', category: 'Cash Flow', icon: AppIcons.wallet, iconBg: AppColors.iconBgRed),
  KpiMetric(id: 'stock', name: 'Stock Value', category: 'Inventory', icon: AppIcons.box, iconBg: AppColors.iconBgPurple),
];

KpiMetric? getMetricById(String id) {
  try {
    return allKpiMetrics.firstWhere((m) => m.id == id);
  } catch (_) {
    return null;
  }
}

KpiConfig getMockDataForMetric(String metricId, int order) {
  return KpiConfig(
    metricId: metricId,
    value: '--',
    sub: 'Loading...',
    badge: '',
    isPositive: true,
    displayOrder: order,
  );
}

const defaultKpiConfigs = <KpiConfig>[
  KpiConfig(metricId: 'sales', value: '--', sub: 'YTD', displayOrder: 0),
  KpiConfig(metricId: 'profit', value: '--', sub: 'YTD', displayOrder: 1),
  KpiConfig(metricId: 'receivable', value: '--', sub: 'Total', displayOrder: 2),
];
