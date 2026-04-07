import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/desktop_responsive_wrapper.dart';
import '../theme/app_theme.dart';
import '../icons/app_icons.dart';
import '../../models/kpi_metric.dart';
import '../../widgets/kpi_widgets.dart';
import '../../widgets/detail_widgets.dart';

class KpiManagerScreen extends StatefulWidget {
  final List<KpiConfig> currentConfigs;
  final Function(List<KpiConfig>) onSave;

  const KpiManagerScreen({
    super.key,
    required this.currentConfigs,
    required this.onSave,
  });

  @override
  State<KpiManagerScreen> createState() => _KpiManagerScreenState();
}

class _KpiManagerScreenState extends State<KpiManagerScreen> {
  late List<KpiConfig> _activeConfigs;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _activeConfigs = List.from(widget.currentConfigs);
  }

  Set<String> get _activeMetricIds =>
      _activeConfigs.map((c) => c.metricId).toSet();

  List<KpiMetric> get _availableMetrics => allKpiMetrics
      .where((m) => !_activeMetricIds.contains(m.id))
      .toList();

  void _addKpi(KpiMetric metric) {
    setState(() {
      final newConfig = getMockDataForMetric(metric.id, _activeConfigs.length);
      _activeConfigs.add(newConfig);
      _hasChanges = true;
    });
  }

  void _removeKpi(int index) {
    setState(() {
      _activeConfigs.removeAt(index);
      // Re-order remaining items
      for (var i = 0; i < _activeConfigs.length; i++) {
        _activeConfigs[i] = _activeConfigs[i].copyWith(displayOrder: i);
      }
      _hasChanges = true;
    });
  }

  void _saveAndClose() {
    widget.onSave(_activeConfigs);
    Navigator.of(context).pop();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final metricsByCategory = <String, List<KpiMetric>>{};
    for (final metric in _availableMetrics) {
      metricsByCategory.putIfAbsent(metric.category, () => []).add(metric);
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // Header
              SafeArea(
                bottom: false,
                child: _buildHeader(),
              ),

              // Content
              Expanded(
                child: DesktopResponsiveWrapper(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active KPIs Section
                      KpiSectionHeader(
                        title: 'YOUR KPIS',
                        subtitle: '(${_activeConfigs.length} selected)',
                      ),
                      _buildActiveKpisList(),

                      // Available KPIs Section
                      if (_availableMetrics.isNotEmpty) ...[
                        KpiSectionHeader(
                          title: 'ADD MORE KPIS',
                          subtitle: '(${_availableMetrics.length} available)',
                        ),
                        ...metricsByCategory.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              KpiCategoryHeader(category: entry.key),
                              _buildAvailableKpisGrid(entry.value),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () async {
              if (await _onWillPop()) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: SvgPicture.string(
                  AppIcons.arrowBack,
                  width: 22,
                  height: 22,
                ),
              ),
            ),
          ),

          // Title
          Expanded(
            child: Text(
              'Manage KPIs',
              style: AppTypography.pageTitle,
            ),
          ),

          // Save button
          KpiSaveButton(onTap: _saveAndClose),
        ],
      ),
    );
  }

  Widget _buildActiveKpisList() {
    if (_activeConfigs.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: const EmptyKpiState(),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _activeConfigs.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _activeConfigs.removeAt(oldIndex);
            _activeConfigs.insert(newIndex, item);
            // Update display orders
            for (var i = 0; i < _activeConfigs.length; i++) {
              _activeConfigs[i] = _activeConfigs[i].copyWith(displayOrder: i);
            }
            _hasChanges = true;
          });
        },
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: child,
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final config = _activeConfigs[index];
          final metric = getMetricById(config.metricId);
          if (metric == null) return const SizedBox.shrink(key: ValueKey('empty'));

          return ActiveKpiItem(
            key: ValueKey(config.metricId),
            metric: metric,
            onRemove: () => _removeKpi(index),
            showDivider: index < _activeConfigs.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildAvailableKpisGrid(List<KpiMetric> metrics) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: metrics.map((metric) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width -
                    AppSpacing.pagePadding * 2 -
                    12) /
                2,
            child: AvailableKpiCard(
              metric: metric,
              onAdd: () => _addKpi(metric),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
///  KPI CONFIG PERSISTENCE HELPER
/// ─────────────────────────────────────────────
class KpiConfigStorage {
  static const String _key = 'kpi_configs';

  static Future<void> save(List<KpiConfig> configs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = configs.map((c) => c.toJson()).toList();
      await prefs.setString(_key, jsonEncode(jsonList));
    } catch (_) {
      // Platform channel may not be ready (e.g. during hot restart)
    }
  }

  static Future<List<KpiConfig>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null) return List.from(defaultKpiConfigs);

      final List<dynamic> jsonList = jsonDecode(json);
      final configs = jsonList
          .map((j) => KpiConfig.fromJson(j as Map<String, dynamic>))
          .toList();
      // Clear stale mock data (e.g. hardcoded "Umbrella") from previous versions
      final hasMock = configs.any((c) => c.value == 'Umbrella' || c.value == '1.12 Cr' || c.value == '87.2 L');
      if (hasMock) {
        await prefs.remove(_key);
        return List.from(defaultKpiConfigs);
      }
      return configs;
    } catch (_) {
      return List.from(defaultKpiConfigs);
    }
  }
}
