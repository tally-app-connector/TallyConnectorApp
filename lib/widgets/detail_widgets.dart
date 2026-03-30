import 'package:flutter/material.dart';
import '../screens/theme/app_theme.dart';
import '../models/report_data.dart';

// ─────────────────────────────────────────────
//  DETAIL PAGE HEADER
// ─────────────────────────────────────────────
class DetailPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final List<Widget>? actions;

  const DetailPageHeader({
    Key? key,
    required this.title,
    required this.onBack,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios, size: 20),
        ),
        Expanded(
          child: Text(title, style: AppTypography.pageTitle),
        ),
        if (actions != null) ...actions!,
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  DETAIL SEARCH BAR
// ─────────────────────────────────────────────
class DetailSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  const DetailSearchBar({
    Key? key,
    this.controller,
    this.placeholder = 'Search...',
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EXPANDABLE CARD
// ─────────────────────────────────────────────
class ExpandableCard extends StatefulWidget {
  final String title;
  final int initialVisibleCount;
  final int loadMoreCount;
  final List<Widget> children;

  const ExpandableCard({
    Key? key,
    required this.title,
    this.initialVisibleCount = 5,
    this.loadMoreCount = 5,
    required this.children,
  }) : super(key: key);

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.initialVisibleCount;
  }

  @override
  Widget build(BuildContext context) {
    final canLoadMore = _visibleCount < widget.children.length;
    final visible = widget.children.take(_visibleCount).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(widget.title, style: AppTypography.cardLabel),
          ),
          ...visible,
          if (canLoadMore)
            TextButton(
              onPressed: () => setState(() => _visibleCount += widget.loadMoreCount),
              child: Center(
                child: Text('Show more', style: TextStyle(fontSize: 13, color: AppColors.blue)),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOP SELLING ITEM ROW
// ─────────────────────────────────────────────
class TopSellingItemRow extends StatelessWidget {
  final int rank;
  final String name;
  final String units;
  final String revenue;
  final String change;
  final bool isPositive;
  final bool showDivider;

  const TopSellingItemRow({
    Key? key,
    required this.rank,
    required this.name,
    required this.units,
    required this.revenue,
    required this.change,
    this.isPositive = true,
    this.showDivider = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.itemTitle, overflow: TextOverflow.ellipsis),
                    Text(units, style: AppTypography.itemSubtitle),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(revenue, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: (isPositive ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      change,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? AppColors.green : AppColors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, indent: 52, color: AppColors.divider),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  CHART PERIOD SELECTOR
// ─────────────────────────────────────────────
class ChartPeriodSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  const ChartPeriodSelector({
    Key? key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels = const ['Monthly', 'Quarterly', 'YoY'],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(labels.length, (i) {
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
//  DATE RANGE SELECTOR
// ─────────────────────────────────────────────
class DateRangeSelector extends StatelessWidget {
  final DateRangeFilter selected;
  final ValueChanged<DateRangeFilter> onChanged;
  final VoidCallback? onCustomTap;

  const DateRangeSelector({
    Key? key,
    required this.selected,
    required this.onChanged,
    this.onCustomTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final options = [
      ('MoM', DateRangeType.mom),
      ('YTD', DateRangeType.ytd),
      ('QTD', DateRangeType.quarter),
      ('Custom', DateRangeType.custom),
    ];
    return Row(
      children: options.map((opt) {
        final isSelected = opt.$2 == selected.type;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              if (opt.$2 == DateRangeType.custom) {
                onCustomTap?.call();
              } else {
                switch (opt.$2) {
                  case DateRangeType.mom:
                    onChanged(DateRangeFilter.mom());
                    break;
                  case DateRangeType.ytd:
                    onChanged(DateRangeFilter.ytd());
                    break;
                  case DateRangeType.quarter:
                    onChanged(DateRangeFilter.quarter());
                    break;
                  default:
                    break;
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.blue : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: AppColors.divider),
              ),
              child: Text(
                opt.$1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
