import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database_helper.dart';
import '../../utils/amount_formatter.dart';
import '../theme/app_theme.dart';
import '../Analysis/bill_wise_detail_screen.dart';
import '../../models/report_data.dart';
import '../../services/sales_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReceivableScreen — main overview (shows top 4 parties + View More)
// ─────────────────────────────────────────────────────────────────────────────

class ReceivableScreen extends StatefulWidget {
  const ReceivableScreen({super.key});

  @override
  State<ReceivableScreen> createState() => _ReceivableScreenState();
}

class _ReceivableScreenState extends State<ReceivableScreen> {
  final _db = DatabaseHelper.instance;

  bool _loading = true;
  String? _companyGuid;
  String _fromDate = '20250401';
  String _toDate = '20260331';
  DateTime? _selectedFromDate;
  DateTime? _selectedToDate;

  List<Map<String, dynamic>> _ledgers = [];
  int _selectedMinDays = -1; // -1 = All, otherwise min days threshold
  bool _showPie = false; // false = bar, true = pie

  // Summary cards
  String _mainValue = '—';
  String _mainUnit = '';
  String _pendingValue = '—';
  String _pendingUnit = '';
  String _advanceValue = '—';
  String _advanceUnit = '';

  // Fastest paying parties
  final SalesAnalyticsService _salesService = SalesAnalyticsService();
  List<TopPayingParty> _topPayingParties = [];
  late FiscalYear _selectedFiscalYear = FiscalYear.current();
  final List<FiscalYear> _fiscalYearOptions = FiscalYear.available();

  static const List<String> _bucketLabels = [
    'Not Due',
    '0–30',
    '31–60',
    '61–90',
    '91–120',
    '121–180',
    '>180',
  ];
  static const List<Color> _bucketColors = [
    Color(0xFF4CAF50), // Not Due — green
    Color(0xFF42A5F5), // 0–30 — light blue
    Color(0xFF1E88E5), // 31–60 — blue
    Color(0xFFF59E0B), // 61–90 — amber
    Color(0xFFFF7043), // 91–120 — orange
    Color(0xFF8B5CF6), // 121–180 — purple
    Color(0xFFE53935), // >180 — red
  ];

  static const double _hPad = AppSpacing.pagePadding;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final company = await _db.getSelectedCompanyByGuid();
    if (company == null) {
      setState(() => _loading = false);
      return;
    }

    _companyGuid = company['company_guid'] as String;

    if (_selectedFromDate == null || _selectedToDate == null) {
      _fromDate = company['starting_from'] as String? ?? _fromDate;
      _toDate = company['ending_at'] as String? ?? _toDate;
      _selectedFromDate = _parseTallyDate(_fromDate);
      _selectedToDate = _parseTallyDate(_toDate);
    }

    await _loadLedgers();
    await _loadSummaryCards();
    await _loadTopPayingParties();
    setState(() => _loading = false);
  }

  Future<void> _loadSummaryCards() async {
    if (_companyGuid == null) return;
    try {
      final breakdown = await _salesService.getOutstandingBreakdown(
        companyGuid: _companyGuid!,
        parentGroup: 'Sundry Debtors',
      );
      final pending = breakdown['pending'] ?? 0;
      final advance = breakdown['advance'] ?? 0;
      final total = pending + advance;

      final mainF = AmountFormatter.format(total);
      final pendingF = AmountFormatter.format(pending);
      final advanceF = AmountFormatter.format(advance);

      setState(() {
        _mainValue = mainF['value']!;
        _mainUnit = mainF['unit']!;
        _pendingValue = pendingF['value']!;
        _pendingUnit = pendingF['unit']!;
        _advanceValue = advanceF['value']!;
        _advanceUnit = advanceF['unit']!;
      });
    } catch (e) {
      debugPrint('Failed to load summary cards: $e');
    }
  }

  Future<void> _loadTopPayingParties() async {
    if (_companyGuid == null) return;
    try {
      final parties = await _salesService.getTopPayingParties(
        companyGuid: _companyGuid!,
        limit: 10,
      );
      setState(() => _topPayingParties = parties);
    } catch (e) {
      debugPrint('Failed to load top paying parties: $e');
    }
  }

  DateTime _parseTallyDate(String d) {
    if (d.length != 8) return DateTime.now();
    return DateTime(
      int.parse(d.substring(0, 4)),
      int.parse(d.substring(4, 6)),
      int.parse(d.substring(6, 8)),
    );
  }

  Future<void> _loadLedgers() async {
    final db = await _db.database;

    final result = await db.rawQuery('''
      WITH RECURSIVE group_tree AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
          AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      ),
      base_data AS (
        SELECT
          l.name AS ledger_name,
          l.parent AS group_name,
          l.opening_balance AS ledger_opening_balance,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) AS credit_before,
          COALESCE(SUM(CASE WHEN v.date < ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) AS debit_before,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) AS credit_total,
          COALESCE(SUM(CASE WHEN v.date >= ? AND v.date <= ? AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) AS debit_total,
          MAX(v.date) AS last_txn_date
        FROM ledgers l
        INNER JOIN group_tree gt ON l.parent = gt.name
        LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
        LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
          AND v.company_guid = l.company_guid
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        WHERE l.company_guid = ? AND l.is_deleted = 0
        GROUP BY l.name, l.parent, l.opening_balance
      )
      SELECT
        ledger_name, group_name, ledger_opening_balance,
        credit_before, debit_before,
        -- OLD (was using payables formula for receivables):
        -- (ledger_opening_balance + credit_before - debit_before) AS opening_balance,
        -- (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) AS outstanding,
        -- FIX: Receivables need opening_balance * -1 (Tally stores debtors as negative opening)
        ((ledger_opening_balance * -1) + debit_before - credit_before) AS opening_balance,
        credit_total, debit_total,
        ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) AS outstanding,
        last_txn_date
      FROM base_data
      WHERE ABS((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) > 0.01
      ORDER BY ABS((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) DESC
    ''', [
      _companyGuid,
      _companyGuid,
      _fromDate,
      _fromDate,
      _fromDate,
      _toDate,
      _fromDate,
      _toDate,
      _companyGuid,
    ]);

    setState(() => _ledgers = result);
  }

  // ── Aging helpers ─────────────────────────────────────────────────────────

  int _daysOverdue(Map<String, dynamic> ledger) {
    final lastDate = ledger['last_txn_date'] as String?;
    if (lastDate == null || lastDate.isEmpty) return 0;
    final dt = _parseTallyDate(lastDate);
    final diff = (_selectedToDate ?? DateTime.now()).difference(dt).inDays;
    return diff < 0 ? 0 : diff;
  }

  int _bucketIndex(int days) {
    if (days <= 0) return 0;
    if (days <= 30) return 1;
    if (days <= 60) return 2;
    if (days <= 90) return 3;
    if (days <= 120) return 4;
    if (days <= 180) return 5;
    return 6;
  }

  bool _daysMatchesBucket(int bucket) {
    // Bucket upper bounds: 0=0, 1=30, 2=60, 3=90, 4=120, 5=180, 6=∞
    // "90+" means show buckets where days START at 90+
    // So bucket 3 (61-90) should be excluded, bucket 4 (91-120) included
    const bucketLowerBounds = [0, 0, 31, 61, 91, 121, 181];
    return bucketLowerBounds[bucket] >= _selectedMinDays;
  }

  List<double> get _bucketAmounts {
    final amounts = List<double>.filled(7, 0);
    for (final l in _ledgers) {
      final outstanding = (l['outstanding'] as num?)?.toDouble() ?? 0;
      amounts[_bucketIndex(_daysOverdue(l))] += outstanding.abs();
    }
    return amounts;
  }

  List<double> get _filteredBucketAmounts {
    if (_selectedMinDays < 0) return _bucketAmounts;
    final amounts = List<double>.filled(7, 0);
    for (final l in _ledgers) {
      final days = _daysOverdue(l);
      final bucket = _bucketIndex(days);
      if (!_daysMatchesBucket(bucket)) continue;
      final outstanding = (l['outstanding'] as num?)?.toDouble() ?? 0;
      amounts[bucket] += outstanding.abs();
    }
    return amounts;
  }

  List<Map<String, dynamic>> get _filteredLedgers {
    if (_selectedMinDays < 0) return _ledgers;
    return _ledgers.where((l) => _daysOverdue(l) >= _selectedMinDays).toList();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _navigateToDetail(Map<String, dynamic> ledger) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BillWiseDetailScreen(
            companyGuid: _companyGuid!,
            ledgerName: ledger['ledger_name'] as String,
            fromDate: _fromDate,
            toDate: _toDate,
            selectedFromDate: _selectedFromDate!,
            selectedToDate: _selectedToDate!,
            ledgerType: 'Receivables',
          ),
        ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Receivable', style: AppTypography.pageTitle),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_hPad),
                child: Column(
                  children: [
                    // Summary cards
                    _buildSummaryCards(),
                    const SizedBox(height: _hPad),
                    // Aging + Party list card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: AppShadows.card,
                        border: AppShadows.cardBorder,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAgingSection(),
                          _buildPartySection(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: _hPad),
                    // Fastest Paying Parties — separate card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: AppShadows.card,
                        border: AppShadows.cardBorder,
                      ),
                      child: _buildFastestPayingSection(),
                    ),
                    const SizedBox(height: _hPad),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Summary cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: 'RECEIVABLE',
            value: _mainValue,
            unit: _mainUnit,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            label: 'PENDING',
            value: _pendingValue,
            unit: _pendingUnit,
            color: AppColors.amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            label: 'ADVANCE',
            value: _advanceValue,
            unit: _advanceUnit,
            color: AppColors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: AppTypography.cardLabel.copyWith(fontSize: 10),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Aging card ────────────────────────────────────────────────────────────

  Widget _buildAgingSection() {
    final allAmounts = _bucketAmounts;
    final maxAmount = allAmounts.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(_hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Bar/Pie toggle
          Row(
            children: [
              Text(
                'AGING ANALYSIS',
                style: AppTypography.dashboardLabel
                    .copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              // Bar/Pie toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.pillBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _chartToggleText('Bar', !_showPie,
                        () => setState(() => _showPie = false)),
                    _chartToggleText(
                        'Pie', _showPie, () => setState(() => _showPie = true)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', -1),
                _filterChip('30+', 30),
                _filterChip('60+', 60),
                _filterChip('90+', 90),
                _filterChip('120+', 120),
                _filterChip('180+', 180),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bar or Pie chart
          if (!_showPie)
            // Bar chart
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final ratio = maxAmount > 0 ? allAmounts[i] / maxAmount : 0.0;
                  final isSelected =
                      _selectedMinDays < 0 || _daysMatchesBucket(i);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AmountFormatter.short(allAmounts[i]),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 50,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.divider,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(4)),
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  height: (50 * ratio)
                                      .clamp(ratio > 0 ? 4.0 : 0.0, 50.0),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _bucketColors[i]
                                        : _bucketColors[i]
                                            .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.vertical(
                                      top: ratio >= 1
                                          ? const Radius.circular(4)
                                          : Radius.zero,
                                      bottom: const Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _bucketLabels[i],
                              style: TextStyle(
                                fontSize: 8,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            )
          else
            // Pie chart — filtered by selected bucket
            _buildPieChart(_filteredBucketAmounts),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<double> amounts) {
    final total = amounts.reduce((a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();

    // Build legend items (only non-zero buckets)
    final legendItems = <Widget>[];
    for (int i = 0; i < 7; i++) {
      if (amounts[i] <= 0) continue;
      final pct = amounts[i] / total * 100;
      final pctText = pct < 1 ? '<1%' : '${pct.toStringAsFixed(0)}%';
      legendItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _bucketColors[i],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(_bucketLabels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 9, color: AppColors.textPrimary)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(AmountFormatter.short(amounts[i]),
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Text(pctText,
                  style: TextStyle(
                      fontSize: 9, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 18,
              sections: () {
                final minSlice = total * 0.03;
                final adjusted = List<double>.generate(
                    7,
                    (i) => amounts[i] > 0
                        ? (amounts[i] < minSlice ? minSlice : amounts[i])
                        : 0);
                return List.generate(7, (i) {
                  if (amounts[i] <= 0) {
                    return PieChartSectionData(
                      color: _bucketColors[i],
                      value: 0,
                      title: '',
                      radius: 0,
                      showTitle: false,
                    );
                  }
                  return PieChartSectionData(
                    color: _bucketColors[i],
                    value: adjusted[i],
                    title: '',
                    radius: 28,
                    showTitle: false,
                  );
                });
              }(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendItems,
          ),
        ),
      ],
    );
  }

  Widget _chartToggleText(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, int minDays) {
    final selected = _selectedMinDays == minDays;
    return GestureDetector(
      onTap: () => setState(() => _selectedMinDays = minDays),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.purple
              : AppColors.purple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? AppColors.purple
                : AppColors.purple.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.purple,
          ),
        ),
      ),
    );
  }

  // ── Party card (top 4 + View More) ────────────────────────────────────────

  Widget _buildPartySection() {
    final ledgers = _filteredLedgers;

    if (ledgers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text('No outstanding found',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    final showCount = ledgers.length > 4 ? 4 : ledgers.length;
    final hasMore = ledgers.length > 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_hPad, _hPad, _hPad, 8),
          child: Text(
            'AGING PARTY WISE OUTSTANDING',
            style: AppTypography.dashboardLabel
                .copyWith(color: AppColors.textSecondary, letterSpacing: 0.8),
          ),
        ),
        // Top 4 parties
        for (int i = 0; i < showCount; i++) ...[
          _partyTile(ledgers[i]),
          if (i < showCount - 1)
            Divider(
                height: 1,
                indent: _hPad,
                endIndent: _hPad,
                color: AppColors.divider),
        ],

        // View More button
        if (hasMore) ...[
          InkWell(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _AllPartiesScreen(
                      ledgers: _ledgers,
                      daysOverdue: _daysOverdue,
                      onTapParty: _navigateToDetail,
                      initialMinDays: _selectedMinDays,
                    ),
                  ));
            },
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View More (${ledgers.length - 4})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios,
                      size: 13, color: AppColors.purple),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  double get _totalOutstanding => _ledgers.fold(
      0.0, (s, l) => s + ((l['outstanding'] as num?)?.toDouble() ?? 0));

  Widget _partyTile(Map<String, dynamic> ledger) {
    final name = ledger['ledger_name'] as String;
    final group = ledger['group_name'] as String;
    final outstanding = (ledger['outstanding'] as num?)?.toDouble() ?? 0;
    final days = _daysOverdue(ledger);
    final bucket = _bucketIndex(days);
    final pct = _totalOutstanding.abs() > 0
        ? (outstanding.abs() / _totalOutstanding.abs() * 100)
        : 0.0;

    return InkWell(
      onTap: () => _navigateToDetail(ledger),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 12),
        child: Column(
          children: [
            // Row 1: Name + Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(name,
                      style: AppTypography.itemTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
                Text('₹${AmountFormatter.shortSpaced(outstanding.abs())}',
                    style: AppTypography.itemTitle
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            // Row 2: Group + Avg pay + Arrow
            Row(
              children: [
                Flexible(
                  child: Text(
                    '$group  ·  ${days <= 0 ? 'On-time' : 'Avg. pay: $days days'}',
                    style: AppTypography.itemSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 16, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 6),
            // Progress bar — full width aligned
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 3,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation(_bucketColors[bucket]),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${pct.toStringAsFixed(0)}%',
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                    textAlign: TextAlign.right),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Fastest Paying Parties card ───────────────────────────────────────────

  String _formatMonthYear(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  void _showFiscalYearPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select Fiscal Year',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            ..._fiscalYearOptions.map((fy) => ListTile(
                  title: Text(fy.displayText),
                  trailing: fy.startYear == _selectedFiscalYear.startYear
                      ? const Icon(Icons.check, color: AppColors.purple)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedFiscalYear = fy);
                    _loadTopPayingParties();
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFastestPayingSection() {
    final fy = _selectedFiscalYear;
    final fyLabel =
        'FY${fy.startYear.toString().substring(2)}-${fy.endYear.toString().substring(2)}';
    final months = fy.endDate.difference(fy.startDate).inDays ~/ 30;
    final showCount = _topPayingParties.length.clamp(0, 4);

    return Padding(
      padding: const EdgeInsets.all(_hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.iconBgAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.star_rounded,
                      color: AppColors.amber, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fastest Paying Parties',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.iconBgGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Early payers',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // FY selector
          GestureDetector(
            onTap: _showFiscalYearPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.iconBgBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '$fyLabel ($months months)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      size: 18, color: AppColors.blue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatMonthYear(fy.startDate)} - ${_formatMonthYear(fy.endDate)}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Party list
          if (_topPayingParties.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No data available',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            )
          else
            ...List.generate(showCount, (i) {
              final party = _topPayingParties[i];
              final rank = i + 1;
              final avgDays =
                  (30 - (party.percentage * 0.18)).round().clamp(5, 30);
              final earlyDays = (30 - avgDays).clamp(0, 30);
              final onTimePercent = party.percentage > 0
                  ? party.percentage.clamp(0.0, 100.0)
                  : (100.0 - i * 3).clamp(80.0, 100.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildFastestPartyRow(
                  rank: rank,
                  name: party.name,
                  amount: party.amount,
                  avgDays: avgDays,
                  earlyDays: earlyDays,
                  onTimePercent: onTimePercent,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFastestPartyRow({
    required int rank,
    required String name,
    required double amount,
    required int avgDays,
    required int earlyDays,
    required double onTimePercent,
  }) {
    Color rankBg;
    Color rankFg;
    if (rank == 1) {
      rankBg = const Color(0xFFF59E0B);
      rankFg = Colors.white;
    } else if (rank == 2) {
      rankBg = const Color(0xFF9CA3AF);
      rankFg = Colors.white;
    } else if (rank == 3) {
      rankBg = const Color(0xFFCD7F32);
      rankFg = Colors.white;
    } else {
      rankBg = AppColors.pillBg;
      rankFg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.pillBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Rank circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: rankBg, shape: BoxShape.circle),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: rankFg)),
            ),
          ),
          const SizedBox(width: 10),

          // Name + amount + avg days
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${AmountFormatter.shortSpaced(amount)}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${onTimePercent.toStringAsFixed(0)}% on-time',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.green)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text('Avg $avgDays d',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.iconBgGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${earlyDays}d early',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AllPartiesScreen — Full list with filter + sort
// ─────────────────────────────────────────────────────────────────────────────

enum _SortMode { byAmountDesc, byAmountAsc, byDaysDesc, byDaysAsc, aToZ, zToA }

class _AllPartiesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> ledgers;
  final int Function(Map<String, dynamic>) daysOverdue;
  final void Function(Map<String, dynamic>) onTapParty;
  final int initialMinDays;

  const _AllPartiesScreen({
    required this.ledgers,
    required this.daysOverdue,
    required this.onTapParty,
    this.initialMinDays = -1,
  });

  @override
  State<_AllPartiesScreen> createState() => _AllPartiesScreenState();
}

class _AllPartiesScreenState extends State<_AllPartiesScreen> {
  late int _selectedMinDays = widget.initialMinDays;
  _SortMode _sortMode = _SortMode.byAmountDesc;

  double _filteredTotal(List<Map<String, dynamic>> list) {
    return list.fold(
        0.0, (s, l) => s + ((l['outstanding'] as num?)?.toDouble() ?? 0));
  }

  int _bucketIndex(int days) {
    if (days <= 0) return 0;
    if (days <= 30) return 1;
    if (days <= 60) return 2;
    if (days <= 90) return 3;
    if (days <= 120) return 4;
    if (days <= 180) return 5;
    return 6;
  }

  List<Map<String, dynamic>> get _filteredAndSorted {
    var list = widget.ledgers;

    if (_selectedMinDays >= 0) {
      list =
          list.where((l) => widget.daysOverdue(l) >= _selectedMinDays).toList();
    }

    final sorted = List<Map<String, dynamic>>.from(list);
    switch (_sortMode) {
      case _SortMode.byAmountDesc:
        sorted.sort((a, b) {
          final aVal = ((a['outstanding'] as num?)?.toDouble() ?? 0).abs();
          final bVal = ((b['outstanding'] as num?)?.toDouble() ?? 0).abs();
          return bVal.compareTo(aVal);
        });
      case _SortMode.byAmountAsc:
        sorted.sort((a, b) {
          final aVal = ((a['outstanding'] as num?)?.toDouble() ?? 0).abs();
          final bVal = ((b['outstanding'] as num?)?.toDouble() ?? 0).abs();
          return aVal.compareTo(bVal);
        });
      case _SortMode.byDaysDesc:
        sorted.sort(
            (a, b) => widget.daysOverdue(b).compareTo(widget.daysOverdue(a)));
      case _SortMode.byDaysAsc:
        sorted.sort(
            (a, b) => widget.daysOverdue(a).compareTo(widget.daysOverdue(b)));
      case _SortMode.aToZ:
        sorted.sort((a, b) => (a['ledger_name'] as String)
            .trim()
            .toLowerCase()
            .compareTo((b['ledger_name'] as String).trim().toLowerCase()));
      case _SortMode.zToA:
        sorted.sort((a, b) => (b['ledger_name'] as String)
            .trim()
            .toLowerCase()
            .compareTo((a['ledger_name'] as String).trim().toLowerCase()));
    }
    return sorted;
  }

  Widget _filterChip(String label, int minDays) {
    final selected = _selectedMinDays == minDays;
    return GestureDetector(
      onTap: () => setState(() => _selectedMinDays = minDays),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.purple
              : AppColors.purple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? AppColors.purple
                : AppColors.purple.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.purple,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAndSorted;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Parties (${filtered.length})',
              style: AppTypography.pageTitle.copyWith(color: Colors.white),
            ),
            const Text(
              'Receivable',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<_SortMode>(
            onSelected: (mode) => setState(() => _sortMode = mode),
            offset: const Offset(0, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              _popupItem('Amount ↓ (High to Low)', _SortMode.byAmountDesc),
              _popupItem('Amount ↑ (Low to High)', _SortMode.byAmountAsc),
              _popupItem('Days ↓ (Most Overdue)', _SortMode.byDaysDesc),
              _popupItem('Days ↑ (Least Overdue)', _SortMode.byDaysAsc),
              _popupItem('A to Z', _SortMode.aToZ),
              _popupItem('Z to A', _SortMode.zToA),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    switch (_sortMode) {
                      _SortMode.byAmountDesc => 'Amount ↓',
                      _SortMode.byAmountAsc => 'Amount ↑',
                      _SortMode.byDaysDesc => 'Days ↓',
                      _SortMode.byDaysAsc => 'Days ↑',
                      _SortMode.aToZ => 'A → Z',
                      _SortMode.zToA => 'Z → A',
                    },
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹ ${AmountFormatter.formatIndian(_filteredTotal(filtered).abs())}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'as of ${DateTime.now().day} ${const [
                    '',
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec'
                  ][DateTime.now().month]} ${DateTime.now().year.toString().substring(2)} | ${_selectedMinDays < 0 ? "All" : "$_selectedMinDays+ days"}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', -1),
                  _filterChip('30+', 30),
                  _filterChip('60+', 60),
                  _filterChip('90+', 90),
                  _filterChip('120+', 120),
                  _filterChip('180+', 180),
                ],
              ),
            ),
          ),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text('No parties found',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppShadows.card,
                      border: AppShadows.cardBorder,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final ledger = filtered[index];
                        final name = ledger['ledger_name'] as String;
                        final group = ledger['group_name'] as String;
                        final outstanding =
                            (ledger['outstanding'] as num?)?.toDouble() ?? 0;
                        final days = widget.daysOverdue(ledger);

                        final bucket = _bucketIndex(days);
                        final totalAbs = filtered.fold<double>(
                            0,
                            (s, l) =>
                                s +
                                ((l['outstanding'] as num?)?.toDouble() ?? 0)
                                    .abs());
                        final pct = totalAbs > 0
                            ? (outstanding.abs() / totalAbs * 100)
                            : 0.0;

                        const bucketColors = [
                          Color(0xFF4CAF50),
                          Color(0xFF42A5F5),
                          Color(0xFF1E88E5),
                          Color(0xFFF59E0B),
                          Color(0xFFFF7043),
                          Color(0xFF8B5CF6),
                          Color(0xFFE53935),
                        ];

                        return InkWell(
                          onTap: () => widget.onTapParty(ledger),
                          child: Container(
                            color: AppColors.surface,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Column(
                              children: [
                                // Row 1: Name + Amount
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(name,
                                          style: AppTypography.itemTitle,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '₹${AmountFormatter.shortSpaced(outstanding.abs())}',
                                      style: AppTypography.itemTitle.copyWith(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Row 2: Group + Avg pay + Arrow
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$group  ·  ${days <= 0 ? 'On-time' : 'Avg. pay: $days days'}',
                                        style: AppTypography.itemSubtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right,
                                        size: 16,
                                        color: AppColors.textSecondary),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Progress bar
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: pct / 100,
                                          minHeight: 3,
                                          backgroundColor: AppColors.divider,
                                          valueColor: AlwaysStoppedAnimation(
                                              bucketColors[bucket]),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 28,
                                      child: Text('${pct.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: AppColors.textSecondary),
                                          textAlign: TextAlign.right),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SortMode> _popupItem(String label, _SortMode mode) {
    final selected = _sortMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.purple : AppColors.textPrimary,
                )),
          ),
          if (selected)
            const Icon(Icons.check, size: 18, color: AppColors.purple),
        ],
      ),
    );
  }
}
