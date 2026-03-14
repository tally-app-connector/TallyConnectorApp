// import 'package:flutter/material.dart';
// import '../theme/app_theme.dart';
// import '../models/report_data.dart';
// import '../widgets/report_overview_widgets.dart';
// import '../widgets/detail_widgets.dart';
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
import '../models/report_data.dart';
import '../widgets/report_overview_widgets.dart';
import '../widgets/detail_widgets.dart';
import '../service/sales/sales_service.dart';
import '../main.dart';
import 'metric_detail_screen.dart';
import 'outstanding_detail_screen.dart';

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
    _searchController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadCompanyAndData() async {
    if (mounted) setState(() { _isLoading = true; _loadedMetrics.clear(); });

    _companyGuid = AppState.selectedCompany?.guid;

    if (_companyGuid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Load each metric individually so cards appear progressively
      for (final metric in ReportMetric.values) {
        final value = await _salesService.getReportValueForMetric(
          metric,
          companyGuid: _companyGuid!,
        );
        if (!mounted) return;
        setState(() {
          _metricValues[metric] = value;
          _loadedMetrics.add(metric);
          // Clear the full-screen loader once first card is ready
          if (_isLoading) _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading report overview data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward(from: 0);
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
    final isOutstanding = metric == ReportMetric.receivable ||
        metric == ReportMetric.payable;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => isOutstanding
          ? OutstandingDetailScreen(metric: metric)
          : MetricDetailScreen(metric: metric),
    ));
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
                      child: const Icon(Icons.refresh_rounded,
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              color: AppColors.blue, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Loading reports…',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary)),
        ],
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
              const Text('No reports found',
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