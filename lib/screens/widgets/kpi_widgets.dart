import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../models/kpi_metric.dart';

// ─────────────────────────────────────────────
//  KPI SECTION HEADER
// ─────────────────────────────────────────────
class KpiSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const KpiSectionHeader({
    Key? key,
    required this.title,
    this.subtitle = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, 20, AppSpacing.pagePadding, 8),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.1,
              )),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  KPI CATEGORY HEADER
// ─────────────────────────────────────────────
class KpiCategoryHeader extends StatelessWidget {
  final String category;

  const KpiCategoryHeader({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, 12, AppSpacing.pagePadding, 8),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  KPI SAVE BUTTON
// ─────────────────────────────────────────────
class KpiSaveButton extends StatelessWidget {
  final VoidCallback onTap;

  const KpiSaveButton({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Save & Close',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EMPTY KPI STATE
// ─────────────────────────────────────────────
class EmptyKpiState extends StatelessWidget {
  const EmptyKpiState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.dashboard_customize_outlined,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'No KPIs selected',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Add More KPIs" below to customize your dashboard',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ACTIVE KPI ITEM (reorderable row)
// ─────────────────────────────────────────────
class ActiveKpiItem extends StatelessWidget {
  final KpiMetric? metric;
  final VoidCallback onRemove;
  final bool showDivider;

  const ActiveKpiItem({
    Key? key,
    required this.metric,
    required this.onRemove,
    this.showDivider = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (metric == null) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.drag_handle, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: metric!.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: SvgPicture.string(metric!.icon, width: 18, height: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(metric!.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.remove_circle_outline, size: 20, color: AppColors.red),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, indent: 64, color: AppColors.divider),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  AVAILABLE KPI CARD (grid item)
// ─────────────────────────────────────────────
class AvailableKpiCard extends StatelessWidget {
  final KpiMetric metric;
  final VoidCallback onAdd;

  const AvailableKpiCard({
    Key? key,
    required this.metric,
    required this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: metric.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: SvgPicture.string(metric.icon, width: 20, height: 20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              metric.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Icon(Icons.add_circle_outline, size: 18, color: AppColors.blue),
          ],
        ),
      ),
    );
  }
}
