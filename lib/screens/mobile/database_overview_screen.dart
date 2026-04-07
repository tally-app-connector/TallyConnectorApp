import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../database/database_helper.dart';
import '../theme/app_theme.dart';

// ── App-consistent design tokens (now using AppColors for dark mode support) ──
// old: all values were hardcoded light-only colors
class _T {
  // Surfaces — now theme-aware
  static Color get bg       => AppColors.background;   // old: Color(0xFFF4F6FB)
  static Color get cardBg   => AppColors.surface;      // old: Colors.white
  static Color get surface  => AppColors.pillBg;       // old: Color(0xFFF0F3FA)
  static Color get border   => AppColors.divider;      // old: Color(0xFFE2E8F4)

  // Brand
  static Color get primary  => AppColors.blue;         // old: Color(0xFF1A6FD8)
  static const accent   = Color(0xFF00C9A7);           // teal — no AppColors equivalent

  // Semantics
  static Color get positive => AppColors.green;        // old: Color(0xFF1B8A5A)
  static Color get negative => AppColors.red;          // old: Color(0xFFD32F2F)
  static Color get amber    => AppColors.amber;        // old: Color(0xFFB45309)
  static Color get purple   => AppColors.purple;       // old: Color(0xFF7B2FBE)
  static const teal     = Color(0xFF0891B2);           // no AppColors equivalent

  // Text — now theme-aware
  static Color get textDark  => AppColors.textPrimary;  // old: Color(0xFF1A2340)
  static Color get textMuted => AppColors.textSecondary; // old: Color(0xFF8A94A6)
  static Color get textLight => AppColors.divider;       // old: Color(0xFFB0BBCC)

  // Table accent colors (same palette, softer)
  static const List<Color> tableColors = [
    Color(0xFF1A6FD8), Color(0xFF7B2FBE), Color(0xFF1B8A5A),
    Color(0xFFB45309), Color(0xFFD32F2F), Color(0xFF0891B2),
    Color(0xFF00C9A7), Color(0xFF6366F1), Color(0xFF14B8A6),
    Color(0xFFF97316), Color(0xFFA855F7), Color(0xFF22C55E),
  ];
}

// ── Models (unchanged) ─────────────────────────────────────────────────────────

class TableInfo {
  final String name;
  final int rowCount;
  final List<ColumnInfo> columns;
  final int colorIndex;

  TableInfo({
    required this.name,
    required this.rowCount,
    required this.columns,
    required this.colorIndex,
  });

  Color get color => _T.tableColors[colorIndex % _T.tableColors.length];
  int get columnCount => columns.length;
}

class ColumnInfo {
  final String name;
  final String type;
  final bool notNull;
  final bool isPk;

  ColumnInfo({
    required this.name,
    required this.type,
    required this.notNull,
    required this.isPk,
  });
}

class _StatItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  _StatItem(this.label, this.value, this.color, this.icon);
}

// ── Main screen ────────────────────────────────────────────────────────────────

class DatabaseOverviewScreen extends StatefulWidget {
  const DatabaseOverviewScreen({super.key});

  @override
  State<DatabaseOverviewScreen> createState() =>
      _DatabaseOverviewScreenState();
}

class _DatabaseOverviewScreenState extends State<DatabaseOverviewScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<TableInfo> _tables = [];
  TableInfo? _selectedTable;
  List<Map<String, dynamic>> _tableRows = [];
  bool _loadingRows = false;
  String _searchQuery = '';
  String _view = 'overview'; // 'overview' | 'table' | 'data'

  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _queryCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadDatabase();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  // ── Data loading (unchanged logic) ─────────────────────────────────────────

  Future<void> _loadDatabase() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = await DatabaseHelper.instance.database;
      final tableList = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' ORDER BY name");

      final tables = <TableInfo>[];
      for (int i = 0; i < tableList.length; i++) {
        final name = tableList[i]['name'] as String;
        final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM "$name"');
        final rowCount = countResult.first['cnt'] as int? ?? 0;
        final pragma = await db.rawQuery('PRAGMA table_info("$name")');
        final columns = pragma.map((col) => ColumnInfo(
          name:    col['name'] as String? ?? '',
          type:    col['type'] as String? ?? 'TEXT',
          notNull: (col['notnull'] as int? ?? 0) == 1,
          isPk:    (col['pk'] as int? ?? 0) > 0,
        )).toList();
        tables.add(TableInfo(name: name, rowCount: rowCount, columns: columns, colorIndex: i));
      }

      setState(() { _tables = tables; _loading = false; });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadTableData(TableInfo table, {int limit = 50}) async {
    setState(() => _loadingRows = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('SELECT * FROM "${table.name}" LIMIT $limit');
      setState(() { _tableRows = rows; _loadingRows = false; });
    } catch (_) {
      setState(() => _loadingRows = false);
    }
  }

  Future<void> _runCustomQuery(String sql) async {
    if (sql.trim().isEmpty) return;
    setState(() => _loadingRows = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(sql);
      setState(() { _tableRows = rows; _loadingRows = false; _view = 'data'; });
    } catch (e) {
      setState(() => _loadingRows = false);
      if (mounted) _showSnack('Query error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: isError ? _T.negative : _T.accent,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<TableInfo> get _filteredTables {
    if (_searchQuery.isEmpty) return _tables;
    return _tables
        .where((t) => t.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get _totalRows => _tables.fold(0, (s, t) => s + t.rowCount);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    syncBrightness(context);
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? _buildLoader()
                : _error != null
                    ? _buildError()
                    : FadeTransition(opacity: _fadeAnim, child: _buildContent()),
          ),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _T.cardBg,
        border: Border(bottom: BorderSide(color: _T.border)),
        boxShadow: AppShadows.card,
      ),
      child: Row(children: [
        // Back button (only in sub-views)
        if (_view != 'overview') ...[
          _iconBtn(Icons.arrow_back_ios_new_rounded, () {
            setState(() {
              _view = _view == 'data' ? 'table' : 'overview';
              _fadeCtrl.reset();
              _fadeCtrl.forward();
            });
          }),
          const SizedBox(width: 12),
        ],

        // Title
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _T.accent
                            .withOpacity(0.5 + 0.5 * _pulseCtrl.value),
                        boxShadow: [
                          BoxShadow(
                            color: _T.accent
                                .withOpacity(0.4 * _pulseCtrl.value),
                            blurRadius: 6, spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _view == 'overview'
                        ? 'Database Explorer'
                        : _view == 'table'
                            ? _selectedTable?.name ?? ''
                            : 'Query Result',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _T.textDark,
                        letterSpacing: -0.3),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  _view == 'overview'
                      ? '${_tables.length} tables · $_totalRows rows'
                      : _view == 'table'
                          ? '${_selectedTable?.columnCount ?? 0} columns · ${_selectedTable?.rowCount ?? 0} rows'
                          : '${_tableRows.length} results',
                  style: TextStyle(fontSize: 11, color: _T.textMuted),
                ),
              ]),
        ),

        // Refresh
        _iconBtn(Icons.refresh_rounded, _loadDatabase),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Icon(icon, size: 16, color: _T.textMuted),
      ),
    );
  }

  // ── Content router ─────────────────────────────────────────────────────────

  Widget _buildContent() {
    switch (_view) {
      case 'table': return _buildTableView();
      case 'data':  return _buildDataView();
      default:      return _buildOverview();
    }
  }

  // ── Overview ───────────────────────────────────────────────────────────────

  Widget _buildOverview() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildStatsRow(),
        const SizedBox(height: 14),
        _buildStorageBar(),
        const SizedBox(height: 20),
        _buildSearchBar(),
        const SizedBox(height: 18),
        _sectionLabel('Tables', badge: '${_filteredTables.length}'),
        const SizedBox(height: 10),
        ..._filteredTables.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildTableCard(t))),
        const SizedBox(height: 18),
        _buildQuickQueryPanel(),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      _StatItem('Tables',  '${_tables.length}',   _T.primary,  Icons.table_chart_outlined),
      _StatItem('Rows',    '$_totalRows',          _T.positive, Icons.storage_outlined),
      _StatItem('Columns', '${_tables.fold(0, (s, t) => s + t.columnCount)}',
          _T.purple, Icons.view_column_outlined),
    ];
    return Row(
      children: stats
          .map<Widget>((s) => Expanded(child: _statCard(s)))
          .expand((w) => [w, const SizedBox(width: 10)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _statCard(_StatItem s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
              color: s.color.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: s.color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(s.icon, size: 16, color: s.color),
        ),
        const SizedBox(height: 10),
        Text(s.value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: s.color)),
        const SizedBox(height: 2),
        Text(s.label,
            style: TextStyle(fontSize: 11, color: _T.textMuted)),
      ]),
    );
  }

  Widget _buildStorageBar() {
    final maxRows = _tables.isEmpty
        ? 1
        : _tables.map((t) => t.rowCount).reduce(math.max).clamp(1, 999999999);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Row Distribution'),
        const SizedBox(height: 14),
        ..._tables.take(8).map((t) {
          final frac = (t.rowCount / maxRows).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                width: 100,
                child: Text(
                  t.name.length > 13 ? '${t.name.substring(0, 12)}…' : t.name,
                  style: TextStyle(
                      fontSize: 11,
                      color: _T.textMuted,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(children: [
                  Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: _T.surface,
                          borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: t.color,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                                color: t.color.withOpacity(0.3),
                                blurRadius: 4)
                          ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                child: Text(t.rowCount.toString(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.color),
                    textAlign: TextAlign.right),
              ),
            ]),
          );
        }),
        if (_tables.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('+ ${_tables.length - 8} more tables',
                style: TextStyle(fontSize: 11, color: _T.textMuted)),
          ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(fontSize: 13, color: _T.textDark),
        decoration: InputDecoration(
          hintText: 'Search tables…',
          hintStyle:
              TextStyle(color: _T.textMuted, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              size: 18, color: _T.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(Icons.close_rounded,
                      size: 16, color: _T.textMuted),
                )
              : null,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildTableCard(TableInfo table) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTable = table;
          _view = 'table';
          _fadeCtrl.reset();
          _fadeCtrl.forward();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _T.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.border),
          boxShadow: AppShadows.headerIcon,
        ),
        child: Row(children: [
          // Color bar
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(
              color: table.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Icon
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: table.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: table.color.withOpacity(0.25)),
            ),
            child: Icon(Icons.table_rows_rounded,
                size: 17, color: table.color),
          ),
          const SizedBox(width: 12),

          // Name + col count
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(table.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _T.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${table.columnCount} columns',
                      style: TextStyle(
                          fontSize: 11, color: _T.textMuted)),
                ]),
          ),

          // Row count badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: table.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: table.color.withOpacity(0.2)),
            ),
            child: Text(table.rowCount.toString(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: table.color)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: _T.textLight),
        ]),
      ),
    );
  }

  // ── Quick Query Panel ──────────────────────────────────────────────────────

  Widget _buildQuickQueryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _T.border))),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: _T.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.terminal_rounded,
                  size: 15, color: _T.purple),
            ),
            const SizedBox(width: 10),
            Text('SQL Query',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _T.textDark)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            // Input
            Container(
              decoration: BoxDecoration(
                color: _T.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _T.border),
              ),
              child: TextField(
                controller: _queryCtrl,
                maxLines: 4,
                style: TextStyle(
                    fontSize: 12,
                    color: _T.primary,
                    fontFamily: 'monospace',
                    height: 1.6),
                decoration: InputDecoration(
                  hintText: 'SELECT * FROM companies LIMIT 10',
                  hintStyle: TextStyle(
                      color: _T.textMuted,
                      fontSize: 12,
                      fontFamily: 'monospace'),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(children: [
              // Quick table chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tables.take(4).map((t) {
                      return GestureDetector(
                        onTap: () {
                          _queryCtrl.text =
                              'SELECT * FROM ${t.name} LIMIT 20';
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: t.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: t.color.withOpacity(0.25)),
                          ),
                          child: Text(t.name,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: t.color,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Run button
              GestureDetector(
                onTap: () => _runCustomQuery(_queryCtrl.text),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_T.primary, const Color(0xFF4898F0)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: _T.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 16, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Run',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Table detail view ──────────────────────────────────────────────────────

  Widget _buildTableView() {
    final table = _selectedTable ??
        TableInfo(name: '', rowCount: 0, columns: [], colorIndex: 0);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Table header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _T.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: table.color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: table.color.withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: table.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: table.color.withOpacity(0.3)),
              ),
              child: Icon(Icons.table_chart_rounded,
                  size: 22, color: table.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(table.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _T.textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(children: [
                      _chip('${table.rowCount} rows', _T.positive),
                      const SizedBox(width: 6),
                      _chip('${table.columnCount} cols', _T.primary),
                    ]),
                  ]),
            ),
            // View data button
            GestureDetector(
              onTap: () async {
                await _loadTableData(table);
                setState(() {
                  _view = 'data';
                  _fadeCtrl.reset();
                  _fadeCtrl.forward();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: table.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: table.color.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.grid_on_rounded,
                      size: 14, color: table.color),
                  const SizedBox(width: 5),
                  Text('Data',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: table.color)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        _sectionLabel('Schema'),
        const SizedBox(height: 10),

        // Columns list
        Container(
          decoration: BoxDecoration(
            color: _T.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.border),
          ),
          child: Column(
            children: table.columns.asMap().entries.map((e) {
              final i      = e.key;
              final col    = e.value;
              final isLast = i == table.columns.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                              color: _T.border, width: 0.8)),
                ),
                child: Row(children: [
                  // PK indicator
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: col.isPk
                          ? _T.amber.withOpacity(0.12)
                          : _T.surface,
                    ),
                    child: Icon(
                      col.isPk
                          ? Icons.key_rounded
                          : Icons.circle_outlined,
                      size: col.isPk ? 12 : 8,
                      color: col.isPk
                          ? _T.amber
                          : _T.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    flex: 3,
                    child: Text(col.name,
                        style: TextStyle(
                            fontSize: 13,
                            color: _T.textDark,
                            fontWeight: FontWeight.w500)),
                  ),

                  _typeBadge(col.type),
                  const SizedBox(width: 6),

                  if (col.notNull)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _T.negative.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _T.negative.withOpacity(0.2)),
                      ),
                      child: Text('NN',
                          style: TextStyle(
                              fontSize: 9,
                              color: _T.negative,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),
        _buildTableQuickActions(table),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildTableQuickActions(TableInfo table) {
    final queries = [
      ('Select All', 'SELECT * FROM ${table.name} LIMIT 50'),
      ('Count',      'SELECT COUNT(*) as total FROM ${table.name}'),
      ('Schema',     'PRAGMA table_info(${table.name})'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Quick Queries'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: queries.map((q) => GestureDetector(
          onTap: () => _runCustomQuery(q.$2),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _T.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: table.color.withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow_rounded,
                  size: 14, color: table.color),
              const SizedBox(width: 5),
              Text(q.$1,
                  style: TextStyle(
                      fontSize: 12,
                      color: table.color,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        )).toList(),
      ),
    ]);
  }

  // ── Data view ──────────────────────────────────────────────────────────────

  Widget _buildDataView() {
    if (_loadingRows) {
      return Center(
          child: CircularProgressIndicator(color: _T.primary, strokeWidth: 2));
    }
    if (_tableRows.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 48, color: _T.textLight),
          const SizedBox(height: 14),
          Text('No rows found',
              style: TextStyle(color: _T.textMuted, fontSize: 15)),
        ]),
      );
    }

    final columns = _tableRows.first.keys.toList();
    return Column(children: [
      // Banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
            color: _T.cardBg,
            border: Border(
                bottom: BorderSide(color: _T.border))),
        child: Text(
          '${_tableRows.length} rows · ${columns.length} columns · scroll →',
          style: TextStyle(
              fontSize: 11, color: _T.textMuted),
        ),
      ),

      Expanded(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Container(
                    decoration: BoxDecoration(
                      color: _T.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      _headerCell('#', 40),
                      ...columns.map(
                          (c) => _headerCell(c, _colWidth(c))),
                    ]),
                  ),
                  const SizedBox(height: 4),

                  // Data rows
                  ...(_tableRows.asMap().entries.map((e) {
                    final idx = e.key;
                    final row = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: idx.isEven
                            ? _T.cardBg
                            : _T.surface,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: _T.border, width: 0.5),
                      ),
                      child: Row(children: [
                        _dataCell('${idx + 1}', 40, _T.textMuted),
                        ...columns.map((c) {
                          final val  = row[c];
                          final disp = val == null
                              ? 'NULL'
                              : val.toString();
                          final color = val == null
                              ? _T.textMuted
                              : _T.textDark;
                          return _dataCell(
                            disp.length > 40
                                ? '${disp.substring(0, 38)}…'
                                : disp,
                            _colWidth(c),
                            color,
                          );
                        }),
                      ]),
                    );
                  })),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _headerCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white),
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _dataCell(String text, double width, Color color) {
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        _showSnack('Copied to clipboard');
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 9),
        child: Text(text,
            style: TextStyle(fontSize: 11, color: color),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  // ── Loader / Error ─────────────────────────────────────────────────────────

  Widget _buildLoader() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _T.primary.withOpacity(
                    0.3 + 0.7 * _pulseCtrl.value),
                width: 2,
              ),
            ),
            child: Icon(Icons.storage_rounded,
                color: _T.primary, size: 26),
          ),
        ),
        const SizedBox(height: 16),
        Text('Loading database…',
            style: TextStyle(color: _T.textMuted, fontSize: 13)),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded,
              color: _T.negative, size: 44),
          const SizedBox(height: 16),
          Text(_error ?? 'Unknown error',
              style: TextStyle(
                  color: _T.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadDatabase,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: _T.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String title, {String? badge}) {
    return Row(children: [
      Container(
        width: 4, height: 16,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_T.primary, _T.accent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _T.textDark)),
      if (badge != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: _T.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: _T.primary.withOpacity(0.2)),
          ),
          child: Text(badge,
              style: TextStyle(
                  fontSize: 11,
                  color: _T.primary,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ]);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _typeBadge(String type) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        type.isEmpty ? 'TEXT' : type.toUpperCase(),
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color),
      ),
    );
  }

  Color _typeColor(String type) {
    final t = type.toUpperCase();
    if (t.contains('INT'))   return _T.primary;
    if (t.contains('TEXT') || t.contains('CHAR')) return _T.positive;
    if (t.contains('REAL') || t.contains('FLOAT') || t.contains('DOUBLE')) return _T.amber;
    if (t.contains('BLOB'))  return _T.purple;
    if (t.contains('BOOL'))  return _T.teal;
    return _T.textMuted;
  }

  double _colWidth(String colName) {
    if (colName.contains('guid') || colName.contains('address') ||
        colName.contains('narration'))   return 200;
    if (colName.contains('name') || colName.contains('date')) return 140;
    if (colName.contains('amount') || colName.contains('balance')) return 120;
    if (colName.length <= 4) return 70;
    return 110;
  }
}