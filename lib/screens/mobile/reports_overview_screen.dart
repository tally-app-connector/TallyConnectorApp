// import 'package:flutter/material.dart';
// import '../theme/app_theme.dart';
// import '../../models/report_data.dart';
// import '../../widgets/report_overview_widgets.dart';
// import '../../widgets/detail_widgets.dart';
// import '../service/sales/sales_service.dart';
// import '../main.dart';
// import 'metric_detail_screen.dart';
// import 'outstanding_detail_screen.dart';

// class ReportsOverviewScreen extends StatefulWidget {
//   const ReportsOverviewScreen({super.key});

//   @override
//   State<ReportsOverviewScreen> createState() => _ReportsOverviewScreenState();
// }

// class _ReportsOverviewScreenState extends State<ReportsOverviewScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   List<ReportMetric> _filteredMetrics = ReportMetric.values.toList();

//   final SalesAnalyticsService _salesService = SalesAnalyticsService();
//   String? _companyGuid;
//   final Map<ReportMetric, ReportValue> _metricValues = {};
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadCompanyAndData();
//   }

//   Future<void> _loadCompanyAndData() async {
//     _companyGuid = AppState.selectedCompany?.guid;

//     if (_companyGuid == null) {
//       if (mounted) setState(() => _isLoading = false);
//       return;
//     }

//     final now = DateTime.now();
//     // Use company's actual FY start from DB, fallback to April 1
//     final company = AppState.selectedCompany;
//     DateTime start;
//     final fyStr = company?.startingFrom;
//     if (fyStr != null && fyStr.isNotEmpty) {
//       final parsed = fyStr.contains('-')
//           ? DateTime.tryParse(fyStr)
//           : (fyStr.length == 8
//               ? DateTime.tryParse(
//                   '${fyStr.substring(0, 4)}-${fyStr.substring(4, 6)}-${fyStr.substring(6, 8)}')
//               : null);
//       start = parsed ?? (now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1));
//     } else {
//       start = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
//     }
//     final end = now;

//     try {
//       for (final metric in ReportMetric.values) {
//         final value = await _salesService.getReportValueForMetric(
//           metric,
//           companyGuid: _companyGuid!,
//         );
//         _metricValues[metric] = value;
//       }
//     } catch (e) {
//       debugPrint('Error loading report overview data: $e');
//     }

//     if (mounted) setState(() => _isLoading = false);
//   }

//   void _onSearchChanged(String query) {
//     setState(() {
//       if (query.isEmpty) {
//         _filteredMetrics = ReportMetric.values.toList();
//       } else {
//         _filteredMetrics = ReportMetric.values
//             .where((m) =>
//                 m.displayName.toLowerCase().contains(query.toLowerCase()))
//             .toList();
//       }
//     });
//   }

//   void _navigateToMetric(ReportMetric metric) {
//     final isOutstanding =
//         metric == ReportMetric.receivable || metric == ReportMetric.payable;
//     Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) => isOutstanding
//             ? OutstandingDetailScreen(metric: metric)
//             : MetricDetailScreen(metric: metric),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           Padding(
//             padding: EdgeInsets.fromLTRB(
//               AppSpacing.pagePadding,
//               16,
//               AppSpacing.pagePadding,
//               0,
//             ),
//             child: Text(
//               'Reports',
//               style: AppTypography.pageTitle,
//             ),
//           ),
//           const SizedBox(height: 16),

//           // Search bar
//           Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: AppSpacing.pagePadding,
//             ),
//             child: DetailSearchBar(
//               controller: _searchController,
//               placeholder: 'Search reports...',
//               onChanged: _onSearchChanged,
//             ),
//           ),
//           const SizedBox(height: AppSpacing.pagePadding),

//           // Metric cards grid
//           Expanded(
//             child: _isLoading
//                 ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
//                 : SingleChildScrollView(
//                     physics: const BouncingScrollPhysics(),
//                     padding: const EdgeInsets.only(
//                       left: AppSpacing.pagePadding,
//                       right: AppSpacing.pagePadding,
//                       bottom: 90,
//                     ),
//                     child: _buildMetricGrid(),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMetricGrid() {
//     if (_filteredMetrics.isEmpty) {
//       return const SizedBox(
//         height: 350,
//         child: Center(
//           child: Text(
//             'No reports found',
//             style: TextStyle(
//               color: AppColors.textSecondary,
//               fontSize: 14,
//             ),
//           ),
//         ),
//       );
//     }

//     return Wrap(
//       spacing: AppSpacing.cardGap,
//       runSpacing: AppSpacing.cardGap,
//       children: _filteredMetrics.map((metric) {
//         final value = _metricValues[metric];
//         return SizedBox(
//           width: (MediaQuery.of(context).size.width -
//                   AppSpacing.pagePadding * 2 -
//                   AppSpacing.cardGap) /
//               2,
//           child: ReportMetricCard(
//             iconBgColor: metric.iconBgColor,
//             svgIcon: metric.icon,
//             label: metric.displayName,
//             value: value?.primaryValue ?? '—',
//             unit: value?.primaryUnit ?? '',
//             change: value?.changePercent ?? '',
//             isPositive: value?.isPositiveChange ?? true,
//             onTap: () => _navigateToMetric(metric),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }


import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../models/report_data.dart';
import '../../widgets/report_overview_widgets.dart';
import '../../widgets/detail_widgets.dart';
import '../../services/sales_service.dart';
import '../main.dart';
import 'metric_detail_screen.dart';
import 'outstanding_detail_screen.dart';
import 'Recevaible_screen.dart';

class ReportsOverviewScreen extends StatefulWidget {
  const ReportsOverviewScreen({super.key});

  @override
  State<ReportsOverviewScreen> createState() => _ReportsOverviewScreenState();
}

class _ReportsOverviewScreenState extends State<ReportsOverviewScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<ReportMetric> _filteredMetrics = ReportMetric.values.toList();

  final SalesAnalyticsService _salesService = SalesAnalyticsService();
  String? _companyGuid;
  final Map<ReportMetric, ReportValue> _metricValues = {};
  bool _isLoading = true;
  String? _errorMessage;
  int _loadGeneration = 0; // cancellation token for in-flight loads

  // Which metrics have finished loading individually
  final Set<ReportMetric> _loadedMetrics = {};

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadCompanyAndData();
  }

  @override
  void dispose() {
    _loadGeneration++; // cancel any in-flight loads
    _searchController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadCompanyAndData() async {
    final gen = ++_loadGeneration; // cancel any previous in-flight load

    if (mounted) setState(() { _isLoading = true; _loadedMetrics.clear(); _errorMessage = null; });

    _companyGuid = AppState.selectedCompany?.guid;

    if (_companyGuid == null) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'No company selected. Please sync your data first.'; });
      return;
    }

    try {
      // Load metrics in small batches (3 at a time) to avoid SQLite lock contention
      final metrics = ReportMetric.values.toList();
      const batchSize = 3;

      for (var i = 0; i < metrics.length; i += batchSize) {
        if (!mounted || gen != _loadGeneration) return;

        final batch = metrics.skip(i).take(batchSize);
        final results = <ReportMetric, ReportValue>{};

        await Future.wait(batch.map((metric) async {
          try {
            final value = await _salesService.getReportValueForMetric(
              metric,
              companyGuid: _companyGuid!,
            );
            if (gen == _loadGeneration) results[metric] = value;
          } catch (e) {
            debugPrint('Error loading metric ${metric.name}: $e');
          }
        }));

        if (!mounted || gen != _loadGeneration) return;
        final isFirstBatch = _isLoading;
        setState(() {
          _metricValues.addAll(results);
          _loadedMetrics.addAll(results.keys);
          if (_isLoading) _isLoading = false;
        });
        // Start fade animation as soon as first batch is ready
        if (isFirstBatch && _loadedMetrics.isNotEmpty) {
          _fadeCtrl.forward(from: 0);
        }
      }
    } catch (e) {
      debugPrint('Error loading report overview data: $e');
    }

    if (mounted && gen == _loadGeneration) {
      setState(() {
        _isLoading = false;
        if (_loadedMetrics.isEmpty) {
          _errorMessage = 'Failed to load reports. Tap to retry.';
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredMetrics = query.isEmpty
          ? ReportMetric.values.toList()
          : ReportMetric.values
              .where((m) => m.displayName
                  .toLowerCase()
                  .contains(query.toLowerCase()))
              .toList();
    });
  }

  void _navigateToMetric(ReportMetric metric) {
    // Cancel any in-flight metric loading to free the database for the detail screen
    _loadGeneration++;

    if (metric == ReportMetric.receivable) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ReceivableScreen(),
      )).then((_) {
        if (mounted && _loadedMetrics.length < ReportMetric.values.length) {
          _loadCompanyAndData();
        }
      });
      return;
    }
    final isOutstanding = metric == ReportMetric.payable;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => isOutstanding
          ? OutstandingDetailScreen(metric: metric)
          : MetricDetailScreen(metric: metric),
    )).then((_) {
      // Resume loading remaining metrics when returning from detail screen
      if (mounted && _loadedMetrics.length < ReportMetric.values.length) {
        _loadCompanyAndData();
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding, 16, AppSpacing.pagePadding, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reports', style: AppTypography.pageTitle),
                // Reload button — visible only when not loading
                if (!_isLoading)
                  GestureDetector(
                    onTap: _loadCompanyAndData,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.divider),
                      ),
                      child: Icon(Icons.refresh_rounded,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding),
            child: DetailSearchBar(
              controller: _searchController,
              placeholder: 'Search reports...',
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.pagePadding),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoading && _loadedMetrics.isEmpty
                ? _buildFullLoader()
                : (!_isLoading && _loadedMetrics.isEmpty && _errorMessage != null)
                    ? _buildErrorState()
                    : FadeTransition(
                    opacity: _isLoading
                        ? const AlwaysStoppedAnimation(1.0)
                        : _fadeAnim,
                    child: RefreshIndicator(
                      color: AppColors.blue,
                      onRefresh: _loadCompanyAndData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.only(
                          left: AppSpacing.pagePadding,
                          right: AppSpacing.pagePadding,
                          bottom: 90,
                        ),
                        child: _buildMetricGrid(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Full-screen loader ─────────────────────────────────────────────────────

  Widget _buildFullLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              color: AppColors.blue, strokeWidth: 2),
          const SizedBox(height: 16),
          Text('Loading reports…',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ── Error / no-company state ──────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: GestureDetector(
        onTap: _loadCompanyAndData,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Tap to retry',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Metric grid ────────────────────────────────────────────────────────────

  Widget _buildMetricGrid() {
    if (_filteredMetrics.isEmpty) {
      return SizedBox(
        height: 320,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 44,
                  color: AppColors.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text('No reports found',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    // Use LayoutBuilder to avoid MediaQuery sizing crash
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - AppSpacing.cardGap) / 2;

        return Wrap(
          spacing: AppSpacing.cardGap,
          runSpacing: AppSpacing.cardGap,
          children: _filteredMetrics.map((metric) {
            final value     = _metricValues[metric];
            final isReady   = _loadedMetrics.contains(metric);

            return SizedBox(
              width: cardWidth,
              child: isReady
                  ? ReportMetricCard(
                      iconBgColor: metric.iconBgColor,
                      svgIcon: metric.icon,
                      label: metric.displayName,
                      value: value?.primaryValue ?? '—',
                      unit: value?.primaryUnit ?? '',
                      change: value?.changePercent ?? '',
                      isPositive: value?.isPositiveChange ?? true,
                      onTap: () => _navigateToMetric(metric),
                    )
                  // Skeleton placeholder while this card's data loads
                  : _SkeletonCard(height: _cardHeight(cardWidth)),
            );
          }).toList(),
        );
      },
    );
  }

  /// Approximate card height to match `ReportMetricCard` proportions
  double _cardHeight(double width) => width * 0.85;
}

// ── Skeleton card ──────────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
              AppColors.surface,
              AppColors.divider,
              _anim.value),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon placeholder
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const Spacer(),
            // Value placeholder
            Container(
              width: 80, height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            // Label placeholder
            Container(
              width: 54, height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}