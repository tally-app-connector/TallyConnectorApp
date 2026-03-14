

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'ledger_detail_screen.dart';

// ── Mode enum ──────────────────────────────────────────────────────────────────

enum LedgerListMode { allLedgers, partyLedger }

// ── Widget ─────────────────────────────────────────────────────────────────────

class LedgerListScreen extends StatefulWidget {
  final LedgerListMode mode;

  /// Only used when [mode] == [LedgerListMode.partyLedger].
  /// Pass 'Sundry Debtors' or 'Sundry Creditors'.
  final String? groupName;

  /// Only used when [mode] == [LedgerListMode.partyLedger].
  final bool isReceivable;

  const LedgerListScreen({
    Key? key,
    this.mode = LedgerListMode.allLedgers,
    this.groupName,
    this.isReceivable = true,
  }) : super(key: key);

  @override
  State<LedgerListScreen> createState() => _LedgerListScreenState();
}

// ── State ──────────────────────────────────────────────────────────────────────

class _LedgerListScreenState extends State<LedgerListScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  // Company info
  String? _companyGuid;
  String? _companyName;
  String? _fromDate;
  String? _toDate;

  // UI state
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  // Filters — only relevant for allLedgers mode
  String _searchQuery = '';
  String? _selectedGroup;
  List<String> _groups = [];

  // Animation
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Design tokens ────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF1A6FD8);
  static const Color _accent     = Color(0xFF00C9A7);
  static const Color _bg         = Color(0xFFF4F6FB);
  static const Color _cardBg     = Colors.white;
  static const Color _textDark   = Color(0xFF1A2340);
  static const Color _textMuted  = Color(0xFF8A94A6);
  static const Color _positiveC  = Color(0xFF1B8A5A);
  static const Color _negativeC  = Color(0xFFD32F2F);
  static const Color _positiveBg = Color(0xFFE8F5EE);
  static const Color _negativeBg = Color(0xFFFFEBEB);
  static const Color _tableBg    = Color(0xFFF0F3FA);

  // ── Convenience getters ──────────────────────────────────────────────────────

  bool get _isPartyMode => widget.mode == LedgerListMode.partyLedger;

  String get _screenTitle {
    if (_isPartyMode) return widget.groupName ?? 'Party Ledger';
    return 'Ledger Reports';
  }

  String get _balanceColumnLabel => _isPartyMode ? 'Outstanding' : 'Closing';

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final company = await _db.getSelectedCompanyByGuid();
    if (company == null) {
      setState(() => _loading = false);
      return;
    }

    _companyGuid = company['company_guid'] as String;
    _companyName = company['company_name'] as String;
    _fromDate    = company['starting_from'] as String? ?? '20250401';
    _toDate      = company['ending_at']     as String? ?? '20260331';

    if (_isPartyMode) {
      await _fetchParties();
    } else {
      await _fetchLedgers();
      await _fetchGroups();
    }

    setState(() => _loading = false);
    _fadeCtrl.forward(from: 0);
  }

  // ── All-ledgers query (was LedgerReportsScreen) ───────────────────────────

  Future<void> _fetchLedgers() async {
    final db = await _db.database;

    String where = 'l.company_guid = ? AND l.is_deleted = 0';
    final params = <dynamic>[_companyGuid];

    if (_selectedGroup != null) {
      where += ' AND l.parent = ?';
      params.add(_selectedGroup);
    }
    if (_searchQuery.isNotEmpty) {
      where += ' AND l.name LIKE ?';
      params.add('%$_searchQuery%');
    }

    final result = await db.rawQuery('''
      SELECT 
        l.name          AS ledger_name,
        l.parent        AS group_name,
        l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) AS debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount           ELSE 0 END), 0) AS credit_total,
        (l.opening_balance +
         COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount           ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)
        ) AS closing_balance,
        COUNT(DISTINCT v.voucher_guid) AS voucher_count
      FROM ledgers l
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v
        ON  v.voucher_guid   = vle.voucher_guid
        AND v.company_guid   = l.company_guid
        AND v.is_deleted     = 0
        AND v.is_cancelled   = 0
        AND v.is_optional    = 0
        AND v.date >= ?
        AND v.date <= ?
      WHERE $where
      GROUP BY l.name, l.parent, l.opening_balance
      ORDER BY l.name
    ''', [_fromDate, _toDate, ...params]);

    setState(() => _rows = result);
  }

  Future<void> _fetchGroups() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT parent AS group_name
      FROM ledgers
      WHERE company_guid = ? AND is_deleted = 0 AND parent IS NOT NULL
      ORDER BY parent
    ''', [_companyGuid]);
    setState(() {
      _groups = result.map((r) => r['group_name'] as String).toList();
    });
  }

  // ── Party-ledger query (was PartyLedgerDetailScreen) ─────────────────────

  Future<void> _fetchParties() async {
    final db = await _db.database;
    final isDebtors = widget.groupName == 'Sundry Debtors';
    final treeName  = isDebtors ? 'debtor_tree' : 'creditor_tree';
    final seedName  = isDebtors ? 'Sundry Debtors' : 'Sundry Creditors';
    final reservedN = isDebtors ? 'Sundry Debtors' : 'Sundry Creditors';

    final query = '''
      WITH RECURSIVE $treeName AS (
        SELECT group_guid, name
        FROM groups
        WHERE company_guid = ?
          AND (name = '$seedName' OR reserved_name = '$reservedN')
          AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name
        FROM groups g
        INNER JOIN $treeName t ON g.parent_guid = t.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT
        l.name          AS ledger_name,
        l.parent        AS group_name,
        l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) AS debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount           ELSE 0 END), 0) AS credit_total,
        (l.opening_balance +
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount           ELSE 0 END), 0)
        ) AS closing_balance,
        COUNT(DISTINCT v.voucher_guid) AS voucher_count
      FROM ledgers l
      INNER JOIN $treeName t ON l.parent = t.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v
        ON  v.voucher_guid   = vle.voucher_guid
        AND v.company_guid   = l.company_guid
        AND v.is_deleted     = 0
        AND v.is_cancelled   = 0
        AND v.is_optional    = 0
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.parent, l.opening_balance
      ORDER BY ABS(closing_balance) DESC
    ''';

    final result = await db.rawQuery(
        query, [_companyGuid, _companyGuid, _companyGuid]);

    setState(() {
      _rows = result.where((row) {
        final bal = (row['closing_balance'] as num?)?.toDouble() ?? 0.0;
        return widget.isReceivable ? bal > 0.01 : bal < -0.01;
      }).toList();
    });
  }

  // ── Computed values ───────────────────────────────────────────────────────

  double _totalOutstanding() => _rows.fold(0.0, (sum, r) {
        final bal = (r['closing_balance'] as num?)?.toDouble() ?? 0.0;
        return sum + bal.abs();
      });

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _clearFilters() {
    setState(() {
      _selectedGroup = null;
      _searchQuery   = '';
    });
    _fetchLedgers();
  }

  String _formatAmount(double amount) {
    final isNeg = amount < 0;
    final formatted = amount.abs().toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${isNeg ? '-' : ''}₹$formatted';
  }

  String _formatDate(String d) {
    if (d.length != 8) return d;
    return '${d.substring(6)}-${d.substring(4, 6)}-${d.substring(0, 4)}';
  }

  void _openDetail(Map<String, dynamic> row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LedgerDetailScreen(
          companyGuid: _companyGuid!,
          companyName: _companyName!,
          ledgerName:  row['ledger_name'] as String,
          fromDate:    _fromDate!,
          toDate:      _toDate!,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildHeaderBanner(),
                  if (!_isPartyMode) _buildFilters(),
                  _buildResultsBar(),
                  _buildTableHeader(),
                  Expanded(child: _buildList()),
                  _buildFooter(),
                ],
              ),
            ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_screenTitle,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
          if (_isPartyMode)
            Text(
              widget.isReceivable ? 'Receivables' : 'Payables',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.isReceivable ? _positiveC : _negativeC),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textMuted, size: 20),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade100),
      ),
    );
  }

  // ── Header banner ─────────────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, Color(0xFF0D4DA0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companyName ?? '',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPartyMode
                      ? widget.isReceivable
                          ? 'Amounts receivable from parties'
                          : 'Amounts payable to parties'
                      : '${_formatDate(_fromDate ?? '')}  →  ${_formatDate(_toDate ?? '')}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withOpacity(0.75)),
                ),
              ],
            ),
          ),
          // Summary pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(
                  _formatAmount(_totalOutstanding()),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_rows.length} ${_isPartyMode ? 'parties' : 'ledgers'}',
                  style: TextStyle(
                      fontSize: 10, color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filters (allLedgers only) ─────────────────────────────────────────────

  Widget _buildFilters() {
    return Container(
      color: _cardBg,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          // Search
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search ledgers…',
                  hintStyle: const TextStyle(fontSize: 13, color: _textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textMuted),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _primary),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _fetchLedgers();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Group filter
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('All Groups',
                        style: TextStyle(fontSize: 12, color: _textMuted)),
                    value: _selectedGroup,
                    icon: const Icon(Icons.unfold_more_rounded,
                        size: 16, color: _textMuted),
                    style: const TextStyle(fontSize: 12, color: _textDark),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Groups')),
                      ..._groups.map((g) =>
                          DropdownMenuItem(value: g, child: Text(g))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedGroup = v);
                      _fetchLedgers();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Results bar ───────────────────────────────────────────────────────────

  Widget _buildResultsBar() {
    final hasFilters = _selectedGroup != null || _searchQuery.isNotEmpty;
    return Container(
      color: _cardBg,
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_rows.length} ${_isPartyMode ? 'part${_rows.length == 1 ? 'y' : 'ies'}' : 'ledger${_rows.length == 1 ? '' : 's'}'}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
            ),
          ),
          const Spacer(),
          if (!_isPartyMode && hasFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.close_rounded, size: 14),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: _textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
        ],
      ),
    );
  }

  // ── Table header ──────────────────────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      color: _tableBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Name col
          Expanded(
            flex: 3,
            child: _headerCell('Name'),
          ),
          // Group col (all-ledgers only)
          if (!_isPartyMode)
            Expanded(flex: 2, child: _headerCell('Group')),
          // Entries
          _headerCell('Entries', flex: 1, align: TextAlign.center),
          // Balance
          _headerCell(_balanceColumnLabel, flex: 2, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _headerCell(String label,
      {int flex = 0, TextAlign align = TextAlign.left}) {
    final text = Text(label,
        textAlign: align,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _textMuted,
            letterSpacing: 0.4));
    if (flex == 0) return text;
    return Expanded(flex: flex, child: text);
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              _isPartyMode ? 'No parties found' : 'No ledgers found',
              style: const TextStyle(fontSize: 15, color: _textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (context, i) => _buildRow(_rows[i], i),
    );
  }

  Widget _buildRow(Map<String, dynamic> row, int index) {
    final closing = (row['closing_balance'] as num?)?.toDouble() ?? 0.0;
    final displayBalance = _isPartyMode ? closing.abs() : closing;
    final count = (row['voucher_count'] as num?)?.toInt() ?? 0;
    final isPos = _isPartyMode ? widget.isReceivable : closing >= 0;

    return InkWell(
      onTap: () => _openDetail(row),
      child: Container(
        decoration: BoxDecoration(
          color: index.isEven ? _cardBg : _bg,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 0.8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // Name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['ledger_name'] as String,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_isPartyMode &&
                      (row['group_name'] as String? ?? '').isNotEmpty)
                    Text(
                      row['group_name'] as String,
                      style: const TextStyle(fontSize: 11, color: _textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Group col (wide layout — allLedgers only) hidden on mobile
            // (we already show group as subtitle above)

            // Entries badge
            SizedBox(
              width: 48,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Balance
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      _formatAmount(displayBalance),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isPos ? _positiveC : _negativeC),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final total = _totalOutstanding();
    final isPos = _isPartyMode ? widget.isReceivable : total >= 0;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_rows.length} ${_isPartyMode ? 'parties' : 'ledgers'}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _textMuted),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total $_balanceColumnLabel',
                style: const TextStyle(fontSize: 11, color: _textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                _formatAmount(total),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isPos ? _positiveC : _negativeC),
              ),
            ],
          ),
        ],
      ),
    );
  }
}