import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../models/report_data.dart';
import '../../utils/amount_formatter.dart';
import '../../services/sales_service.dart';
import '../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GroupOutstandingDetailScreen — Shows parties within a specific outstanding
// group (e.g., "Sundry Debtors") when user taps on a group row.
// ─────────────────────────────────────────────────────────────────────────────

class GroupOutstandingDetailScreen extends StatefulWidget {
  final GroupOutstanding group;
  final bool isReceivable;

  const GroupOutstandingDetailScreen({
    super.key,
    required this.group,
    required this.isReceivable,
  });

  @override
  State<GroupOutstandingDetailScreen> createState() =>
      _GroupOutstandingDetailScreenState();
}

class _GroupOutstandingDetailScreenState
    extends State<GroupOutstandingDetailScreen> {
  final SalesAnalyticsService _salesService = SalesAnalyticsService();
  List<_GroupParty> _parties = [];
  bool _isLoading = true;

  GroupOutstanding get group => widget.group;
  bool get isReceivable => widget.isReceivable;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    final companyGuid = AppState.selectedCompany?.guid;
    if (companyGuid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final rows = await _salesService.getPartiesInGroup(
        companyGuid: companyGuid,
        groupName: group.groupName,
      );
      if (mounted) {
        setState(() {
          _parties = rows
              .map((r) => _GroupParty(
                    name: r['name'] as String,
                    amount: (r['amount'] as num).toDouble(),
                    days: (r['days'] as num).toInt(),
                  ))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _buildTotalCard(),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                              ),
                              child: _buildPartiesCard(context, _parties),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, AppSpacing.pagePadding, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              group.groupName,
              style: AppTypography.pageTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOTAL OUTSTANDING CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTotalCard() {
    final formatted = AmountFormatter.format(group.amount);
    final accentColor = isReceivable ? AppColors.purple : AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Outstanding',
                  style: AppTypography.cardLabel.copyWith(
                    fontSize: 15,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${formatted['value']}',
                      style: TextStyle(
                        fontFamily: AppTypography.fontSerif,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatted['unit']!,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${group.partyCount} parties',
              style: AppTypography.itemTitle.copyWith(
                fontSize: 12,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PARTIES LIST CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPartiesCard(BuildContext context, List<_GroupParty> parties) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parties in ${group.groupName.toUpperCase()}',
            style: AppTypography.cardLabel.copyWith(
              fontSize: 15,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < parties.length; i++) ...[
            _buildPartyRow(parties[i]),
            if (i < parties.length - 1)
              SizedBox(
                height: 1,
                child: OverflowBox(
                  maxWidth: MediaQuery.of(context).size.width,
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.divider,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartyRow(_GroupParty party) {
    final accentColor = isReceivable ? AppColors.purple : AppColors.red;
    final daysColor = party.days >= 90
        ? AppColors.red
        : party.days >= 60
            ? const Color(0xFFE67E22)
            : party.days >= 30
                ? AppColors.amber
                : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                party.name.isNotEmpty ? party.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name & group
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  party.name,
                  style: AppTypography.itemTitle.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  group.groupName,
                  style: AppTypography.itemSubtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Amount & days badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${AmountFormatter.shortSpaced(party.amount)}',
                style: AppTypography.itemTitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: daysColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${party.days}d',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: daysColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
//  Simple data class for parties within a group
// ─────────────────────────────────────────────────────────────────────────────

class _GroupParty {
  final String name;
  final double amount;
  final int days;

  const _GroupParty({
    required this.name,
    required this.amount,
    required this.days,
  });
}
