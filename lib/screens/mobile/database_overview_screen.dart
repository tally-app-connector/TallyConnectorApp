import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

// ============================================================
// THEME
// ============================================================
class _T {
  static const bg         = Color(0xFF0A0E1A);
  static const surface    = Color(0xFF111827);
  static const card       = Color(0xFF1A2235);
  static const cardHover  = Color(0xFF1E2A40);
  static const border     = Color(0xFF1F2D45);
  static const borderGlow = Color(0xFF2D4A7A);

  static const cyan       = Color(0xFF00D4FF);
  static const cyanDim    = Color(0xFF0099BB);
  static const blue       = Color(0xFF3B82F6);
  static const purple     = Color(0xFF8B5CF6);
  static const green      = Color(0xFF10B981);
  static const orange     = Color(0xFFF59E0B);
  static const red        = Color(0xFFEF4444);
  static const pink       = Color(0xFFEC4899);

  static const textPrimary   = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF475569);
  static const textCode      = Color(0xFF00D4FF);

  static const List<Color> tableColors = [
    Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFEC4899),
    Color(0xFF00D4FF), Color(0xFF6366F1), Color(0xFF14B8A6),
    Color(0xFFF97316), Color(0xFFA855F7), Color(0xFF22C55E),
  ];
}

// ============================================================
// MODELS
// ============================================================
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

// ============================================================
// MAIN SCREEN
// ============================================================
class DatabaseOverviewScreen extends StatefulWidget {
  const DatabaseOverviewScreen({super.key});

  @override
  State<DatabaseOverviewScreen> createState() => _DatabaseOverviewScreenState();
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

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _loadDatabase();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================
  Future<void> _loadDatabase() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = await DatabaseHelper.instance.database;
      // Get all tables
      final tableList = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' ORDER BY name"
      );

      final tables = <TableInfo>[];
      for (int i = 0; i < tableList.length; i++) {
        final tableName = tableList[i]['name'] as String;
        // Row count
        final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM "$tableName"');
        final rowCount = countResult.first['cnt'] as int? ?? 0;
        // Column info
        final pragma = await db.rawQuery('PRAGMA table_info("$tableName")');
        final columns = pragma.map((col) => ColumnInfo(
          name:    col['name'] as String? ?? '',
          type:    col['type'] as String? ?? 'TEXT',
          notNull: (col['notnull'] as int? ?? 0) == 1,
          isPk:    (col['pk'] as int? ?? 0) > 0,
        )).toList();

        tables.add(TableInfo(
          name:       tableName,
          rowCount:   rowCount,
          columns:    columns,
          colorIndex: i,
        ));
      }

      setState(() {
        _tables  = tables;
        _loading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadTableData(TableInfo table, {int limit = 50}) async {
    setState(() { _loadingRows = true; });
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
        'SELECT * FROM "${table.name}" LIMIT $limit'
      );
      setState(() {
        _tableRows   = rows;
        _loadingRows = false;
      });
    } catch (e) {
      setState(() { _loadingRows = false; });
    }
  }

  Future<void> _runCustomQuery(String sql) async {
    if (sql.trim().isEmpty) return;
    setState(() { _loadingRows = true; });
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(sql);
      setState(() {
        _tableRows   = rows;
        _loadingRows = false;
        _view        = 'data';
      });
    } catch (e) {
      setState(() { _loadingRows = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Query error: $e'),
            backgroundColor: _T.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<TableInfo> get _filteredTables {
    if (_searchQuery.isEmpty) return _tables;
    return _tables.where((t) =>
      t.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  int get _totalRows => _tables.fold(0, (sum, t) => sum + t.rowCount);

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _T.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? _buildLoader()
                    : _error != null
                        ? _buildError()
                        : FadeTransition(
                            opacity: _fadeAnim,
                            child: _buildContent(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _T.surface,
        border: Border(bottom: BorderSide(color: _T.border, width: 1)),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () {
              if (_view != 'overview') {
                setState(() {
                  _view = _view == 'data' ? 'table' : 'overview';
                  _fadeCtrl.reset();
                  _fadeCtrl.forward();
                });
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _T.border),
                color: _T.card,
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _T.textSecondary),
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _T.green.withOpacity(0.5 + 0.5 * _pulseCtrl.value),
                          boxShadow: [
                            BoxShadow(
                              color: _T.green.withOpacity(0.4 * _pulseCtrl.value),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _view == 'overview'
                          ? 'DATABASE'
                          : _view == 'table'
                              ? _selectedTable?.name.toUpperCase() ?? ''
                              : 'QUERY RESULT',
                      style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: _T.cyan, letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _view == 'overview'
                      ? '${_tables.length} tables · ${_totalRows} rows'
                      : _view == 'table'
                          ? '${_selectedTable?.columnCount ?? 0} columns · ${_selectedTable?.rowCount ?? 0} rows'
                          : '${_tableRows.length} results',
                  style: const TextStyle(fontSize: 11, color: _T.textMuted),
                ),
              ],
            ),
          ),

          // Refresh
          GestureDetector(
            onTap: _loadDatabase,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _T.border),
                color: _T.card,
              ),
              child: const Icon(Icons.refresh_rounded, size: 16, color: _T.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT ROUTER
  // ============================================================
  Widget _buildContent() {
    switch (_view) {
      case 'table': return _buildTableView();
      case 'data':  return _buildDataView();
      default:      return _buildOverview();
    }
  }

  // ============================================================
  // OVERVIEW
  // ============================================================
  Widget _buildOverview() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          _buildStatsRow(),
          const SizedBox(height: 16),

          // Storage bar
          _buildStorageBar(),
          const SizedBox(height: 20),

          // Search
          _buildSearchBar(),
          const SizedBox(height: 16),

          // Table list label
          Row(
            children: [
              const Text('TABLES', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _T.textMuted, letterSpacing: 1.5, fontFamily: 'monospace',
              )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _T.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _T.cyan.withOpacity(0.3)),
                ),
                child: Text(
                  '${_filteredTables.length}',
                  style: const TextStyle(fontSize: 10, color: _T.cyan,
                      fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tables grid
          ..._filteredTables.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildTableCard(t),
          )),

          const SizedBox(height: 16),
          // Quick query
          _buildQuickQueryPanel(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      _StatItem('TABLES',  '${_tables.length}',          _T.cyan,   Icons.table_chart_outlined),
      _StatItem('ROWS',    _totalRows.toString(),        _T.green,  Icons.storage_outlined),
      _StatItem('COLUMNS', '${_tables.fold(0, (s, t) => s + t.columnCount)}', _T.purple, Icons.view_column_outlined),
    ];
    return Row(
      children: stats.map((s) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: s == stats.last ? 0 : 8),
          child: _buildStatCard(s),
        ),
      )).toList(),
    );
  }

  Widget _buildStatCard(_StatItem s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(color: s.color.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(s.icon, size: 14, color: s.color),
          ),
          const SizedBox(height: 8),
          Text(s.value, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800,
            color: s.color, fontFamily: 'monospace',
          )),
          Text(s.label, style: const TextStyle(
            fontSize: 9, color: _T.textMuted,
            letterSpacing: 1, fontFamily: 'monospace',
          )),
        ],
      ),
    );
  }

  Widget _buildStorageBar() {
    final max = _tables.isEmpty ? 1 : _tables.map((t) => t.rowCount).reduce(math.max).clamp(1, 999999999);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ROW DISTRIBUTION', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: _T.textMuted, letterSpacing: 1.5, fontFamily: 'monospace',
          )),
          const SizedBox(height: 12),
          ..._tables.take(8).map((t) {
            final frac = t.rowCount / max;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      t.name.length > 12 ? '${t.name.substring(0, 11)}…' : t.name,
                      style: const TextStyle(fontSize: 10, color: _T.textSecondary, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 6, decoration: BoxDecoration(
                          color: _T.border, borderRadius: BorderRadius.circular(3),
                        )),
                        FractionallySizedBox(
                          widthFactor: frac.clamp(0.0, 1.0),
                          child: Container(height: 6, decoration: BoxDecoration(
                            color: t.color,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [BoxShadow(color: t.color.withOpacity(0.4), blurRadius: 4)],
                          )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      t.rowCount.toString(),
                      style: TextStyle(fontSize: 10, color: t.color, fontFamily: 'monospace'),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_tables.length > 8)
            Text('+ ${_tables.length - 8} more tables',
                style: const TextStyle(fontSize: 10, color: _T.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 13, color: _T.textPrimary, fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: 'Search tables...',
          hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 16, color: _T.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close, size: 14, color: _T.textMuted),
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
          _view          = 'table';
          _fadeCtrl.reset();
          _fadeCtrl.forward();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.border),
        ),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 4, height: 42,
              decoration: BoxDecoration(
                color: table.color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: table.color.withOpacity(0.5), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 12),

            // Table icon
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: table.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: table.color.withOpacity(0.3)),
              ),
              child: Icon(Icons.table_rows_outlined, size: 16, color: table.color),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(table.name, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _T.textPrimary, fontFamily: 'monospace',
                  )),
                  const SizedBox(height: 3),
                  Text(
                    '${table.columnCount} cols',
                    style: const TextStyle(fontSize: 11, color: _T.textMuted),
                  ),
                ],
              ),
            ),

            // Row count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: table.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: table.color.withOpacity(0.3)),
              ),
              child: Text(
                table.rowCount.toString(),
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: table.color, fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: _T.textMuted),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK QUERY PANEL
  // ============================================================
  final _queryCtrl = TextEditingController();

  Widget _buildQuickQueryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _T.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _T.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.terminal, size: 14, color: _T.purple),
                ),
                const SizedBox(width: 10),
                const Text('QUICK QUERY', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _T.textSecondary, letterSpacing: 1,
                )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _T.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _T.border),
                  ),
                  child: TextField(
                    controller: _queryCtrl,
                    maxLines: 4,
                    style: const TextStyle(
                      fontSize: 12, color: _T.textCode,
                      fontFamily: 'monospace', height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'SELECT * FROM companies LIMIT 10',
                      hintStyle: TextStyle(color: _T.textMuted, fontSize: 12, fontFamily: 'monospace'),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Quick suggestions
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _tables.take(4).map((t) =>
                            GestureDetector(
                              onTap: () {
                                _queryCtrl.text = 'SELECT * FROM ${t.name} LIMIT 20';
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: t.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: t.color.withOpacity(0.3)),
                                ),
                                child: Text(t.name,
                                  style: TextStyle(fontSize: 10, color: t.color, fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                          ).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _runCustomQuery(_queryCtrl.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_T.purple, _T.blue],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: _T.purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('RUN', style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: 1,
                            )),
                          ],
                        ),
                      ),
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

  // ============================================================
  // TABLE DETAIL VIEW
  // ============================================================
  Widget _buildTableView() {
    final table = _selectedTable ?? TableInfo(name: '', rowCount: 0, columns: [], colorIndex: 0);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: table.color.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: table.color.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: table.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: table.color.withOpacity(0.4)),
                  ),
                  child: Icon(Icons.table_chart_rounded, size: 22, color: table.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(table.name, style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: _T.textPrimary, fontFamily: 'monospace',
                      )),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _chip(table.rowCount.toString() + ' rows', _T.green),
                          const SizedBox(width: 6),
                          _chip('${table.columnCount} cols', _T.blue),
                        ],
                      ),
                    ],
                  ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: table.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: table.color.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_on_rounded, size: 13, color: table.color),
                        const SizedBox(width: 5),
                        Text('DATA', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: table.color, letterSpacing: 1,
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Columns header
          const Text('SCHEMA', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: _T.textMuted, letterSpacing: 1.5, fontFamily: 'monospace',
          )),
          const SizedBox(height: 10),

          // Column list
          Container(
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _T.border),
            ),
            child: Column(
              children: table.columns.asMap().entries.map((e) {
                final i   = e.key;
                final col = e.value;
                final isLast = i == table.columns.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(bottom: BorderSide(color: _T.border.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      // PK indicator
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: col.isPk
                              ? _T.orange.withOpacity(0.15)
                              : _T.border.withOpacity(0.5),
                        ),
                        child: Icon(
                          col.isPk ? Icons.key_rounded : Icons.circle_outlined,
                          size: col.isPk ? 11 : 8,
                          color: col.isPk ? _T.orange : _T.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Column name
                      Expanded(
                        flex: 3,
                        child: Text(col.name, style: const TextStyle(
                          fontSize: 12, color: _T.textPrimary,
                          fontFamily: 'monospace', fontWeight: FontWeight.w500,
                        )),
                      ),

                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _typeColor(col.type).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _typeColor(col.type).withOpacity(0.3)),
                        ),
                        child: Text(
                          col.type.isEmpty ? 'TEXT' : col.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: _typeColor(col.type), fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // NOT NULL badge
                      if (col.notNull)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _T.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('NN', style: TextStyle(
                            fontSize: 9, color: _T.red,
                            fontWeight: FontWeight.w700, fontFamily: 'monospace',
                          )),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          // Quick queries for this table
          _buildTableQuickActions(table),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTableQuickActions(TableInfo table) {
    final queries = [
      ('SELECT ALL',   'SELECT * FROM ${table.name} LIMIT 50'),
      ('COUNT',        'SELECT COUNT(*) as total FROM ${table.name}'),
      ('SCHEMA',       'PRAGMA table_info(${table.name})'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK QUERIES', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _T.textMuted, letterSpacing: 1.5, fontFamily: 'monospace',
        )),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: queries.map((q) => GestureDetector(
            onTap: () => _runCustomQuery(q.$2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _T.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: table.color.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline, size: 12, color: table.color),
                  const SizedBox(width: 5),
                  Text(q.$1, style: TextStyle(
                    fontSize: 11, color: table.color,
                    fontWeight: FontWeight.w600, fontFamily: 'monospace',
                  )),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // DATA VIEW
  // ============================================================
  Widget _buildDataView() {
    if (_loadingRows) {
      return const Center(child: CircularProgressIndicator(color: _T.cyan, strokeWidth: 2));
    }
    if (_tableRows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: _T.textMuted),
            SizedBox(height: 12),
            Text('No rows found', style: TextStyle(color: _T.textMuted)),
          ],
        ),
      );
    }

    final columns = _tableRows.first.keys.toList();
    return Column(
      children: [
        // Row count banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _T.surface,
          child: Text(
            '${_tableRows.length} rows · ${columns.length} columns · scroll horizontally',
            style: const TextStyle(fontSize: 11, color: _T.textMuted, fontFamily: 'monospace'),
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
                        color: _T.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _T.border),
                      ),
                      child: Row(
                        children: [
                          _headerCell('#', 40),
                          ...columns.map((c) => _headerCell(c, _colWidth(c))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Data rows
                    ...(_tableRows.asMap().entries.map((e) {
                      final idx = e.key;
                      final row = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: idx.isEven ? _T.card : _T.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _T.border.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            _dataCell('${idx + 1}', 40, _T.textMuted),
                            ...columns.map((c) {
                              final val  = row[c];
                              final disp = val == null ? 'NULL' : val.toString();
                              final color = val == null
                                  ? _T.textMuted
                                  : disp.length > 30
                                      ? _T.textSecondary
                                      : _T.textPrimary;
                              return _dataCell(
                                disp.length > 40 ? '${disp.substring(0, 38)}…' : disp,
                                _colWidth(c),
                                color,
                              );
                            }),
                          ],
                        ),
                      );
                    })),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _T.cyan, letterSpacing: 0.5, fontFamily: 'monospace',
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dataCell(String text, double width, Color color) {
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(
          text,
          style: TextStyle(fontSize: 11, color: color, fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ============================================================
  // LOADING / ERROR
  // ============================================================
  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _T.cyan.withOpacity(0.3 + 0.7 * _pulseCtrl.value),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.storage_rounded, color: _T.cyan, size: 26),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Loading database...', style: TextStyle(color: _T.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _T.red, size: 40),
            const SizedBox(height: 16),
            Text(_error ?? 'Unknown error',
                style: const TextStyle(color: _T.textMuted, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadDatabase,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: _T.cyan),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Retry', style: TextStyle(color: _T.cyan)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(
        fontSize: 10, color: color,
        fontWeight: FontWeight.w600, fontFamily: 'monospace',
      )),
    );
  }

  Color _typeColor(String type) {
    final t = type.toUpperCase();
    if (t.contains('INT'))  return _T.blue;
    if (t.contains('TEXT') || t.contains('CHAR')) return _T.green;
    if (t.contains('REAL') || t.contains('FLOAT') || t.contains('DOUBLE')) return _T.orange;
    if (t.contains('BLOB')) return _T.purple;
    if (t.contains('BOOL')) return _T.pink;
    return _T.textSecondary;
  }

  double _colWidth(String colName) {
    if (colName.contains('guid') || colName.contains('address') || colName.contains('narration')) return 200;
    if (colName.contains('name') || colName.contains('date')) return 140;
    if (colName.contains('amount') || colName.contains('balance')) return 120;
    if (colName.length <= 4) return 70;
    return 110;
  }

}

// ============================================================
// MODELS
// ============================================================
class _StatItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  _StatItem(this.label, this.value, this.color, this.icon);
}