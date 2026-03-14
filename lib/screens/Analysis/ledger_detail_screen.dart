// // screens/ledger_detail_screen.dart

// import 'package:flutter/material.dart';
// import '../../database/database_helper.dart';
// import 'voucher_detail_screen.dart';

// class LedgerDetailScreen extends StatefulWidget {
//   final String companyGuid;
//   final String companyName;
//   final String ledgerName;
//   final String fromDate;
//   final String toDate;

//   const LedgerDetailScreen({
//     Key? key,
//     required this.companyGuid,
//     required this.companyName,
//     required this.ledgerName,
//     required this.fromDate,
//     required this.toDate,
//   }) : super(key: key);

//   @override
//   _LedgerDetailScreenState createState() => _LedgerDetailScreenState();
// }

// class _LedgerDetailScreenState extends State<LedgerDetailScreen> {
//   final _db = DatabaseHelper.instance;
//   bool _loading = true;
//   List<Map<String, dynamic>> _vouchers = [];
//   double _openingBalance = 0.0;
//   double _runningBalance = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     _loadVouchers();
//   }

//   Future<void> _loadVouchers() async {
//     setState(() => _loading = true);

//     final db = await _db.database;

//     // Get opening balance
//     final ledgerResult = await db.rawQuery('''
//       SELECT opening_balance
//       FROM ledgers
//       WHERE company_guid = ?
//         AND name = ?
//         AND is_deleted = 0
//       LIMIT 1
//     ''', [widget.companyGuid, widget.ledgerName]);

//     if (ledgerResult.isNotEmpty) {
//       _openingBalance = (ledgerResult.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
//       _runningBalance = _openingBalance;
//     }

//     // Get all vouchers affecting this ledger
//     final voucherResult = await db.rawQuery('''
//       SELECT 
//         v.voucher_guid,
//         v.date,
//         v.voucher_type,
//         v.voucher_number,
//         v.narration,
//         vle.amount,
//         CASE 
//           WHEN vle.amount < 0 THEN ABS(vle.amount)
//           ELSE 0 
//         END as debit,
//         CASE 
//           WHEN vle.amount > 0 THEN vle.amount
//           ELSE 0 
//         END as credit
//       FROM vouchers v
//       INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
//       WHERE v.company_guid = ?
//         AND vle.ledger_name = ?
//         AND v.is_deleted = 0
//         AND v.is_cancelled = 0
//         AND v.is_optional = 0
//         AND v.date >= ?
//         AND v.date <= ?
//       ORDER BY v.date ASC, v.voucher_number ASC
//     ''', [widget.companyGuid, widget.ledgerName, widget.fromDate, widget.toDate]);

//     // Calculate running balance for each voucher
//     List<Map<String, dynamic>> vouchersWithBalance = [];
//     double balance = _openingBalance;

//     for (final voucher in voucherResult) {
//       print(voucher);
//       final credit = (voucher['credit'] as num?)?.toDouble() ?? 0.0;
//       final debit = (voucher['debit'] as num?)?.toDouble() ?? 0.0;
//       balance = balance + credit - debit;

//       vouchersWithBalance.add({
//         ...voucher,
//         'balance': balance,
//       });
//     }

//     setState(() {
//       _vouchers = vouchersWithBalance;
//       _loading = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(widget.ledgerName, style: TextStyle(fontSize: 18)),
//             Text(
//               '${_formatDate(widget.fromDate)} to ${_formatDate(widget.toDate)}',
//               style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadVouchers,
//           ),
//         ],
//       ),
//       body: _loading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 // Header
//                 Container(
//                   width: double.infinity,
//                   color: Colors.blue[50],
//                   padding: EdgeInsets.all(16),
//                   child: Column(
//                     children: [
//                       Text(
//                         widget.companyName,
//                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                         textAlign: TextAlign.center,
//                       ),
//                       SizedBox(height: 8),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             'Opening Balance: ',
//                             style: TextStyle(fontSize: 14),
//                           ),
//                           Text(
//                             _formatAmount(_openingBalance),
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                               color: _openingBalance >= 0
//                                   ? Colors.green[700]
//                                   : Colors.red[700],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),

//                 // Table Header
//                 Container(
//                   color: Colors.grey[200],
//                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Date',
//                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 3,
//                         child: Text(
//                           'Particulars',
//                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Vch Type',
//                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Vch No.',
//                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Debit',
//                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Credit',
//                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Balance',
//                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // Voucher List
//                 Expanded(
//                   child: _vouchers.isEmpty
//                       ? Center(
//                           child: Text(
//                             'No transactions found',
//                             style: TextStyle(color: Colors.grey[600]),
//                           ),
//                         )
//                       : ListView.separated(
//                           itemCount: _vouchers.length,
//                           separatorBuilder: (context, index) => Divider(height: 1),
//                           itemBuilder: (context, index) {
//                             final voucher = _vouchers[index];
//                             final debit = (voucher['debit'] as num?)?.toDouble() ?? 0.0;
//                             final credit = (voucher['credit'] as num?)?.toDouble() ?? 0.0;
//                             final balance = (voucher['balance'] as num?)?.toDouble() ?? 0.0;

//                             return InkWell(
//                               onTap: () {
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) => VoucherDetailScreen(
//                                       companyGuid: widget.companyGuid,
//                                       companyName: widget.companyName,
//                                       voucherGuid: voucher['voucher_guid'] as String,
//                                     ),
//                                   ),
//                                 );
//                               },
//                               child: Container(
//                                 padding: EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 12,
//                                 ),
//                                 color: index.isEven ? Colors.white : Colors.grey[50],
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       flex: 2,
//                                       child: Text(
//                                         _formatDate(voucher['date'] as String),
//                                         style: TextStyle(fontSize: 12),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       flex: 3,
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             voucher['narration'] as String? ?? '-',
//                                             style: TextStyle(fontSize: 12),
//                                             maxLines: 1,
//                                             overflow: TextOverflow.ellipsis,
//                                           ),
//                                           if ((voucher['narration'] as String?)
//                                                   ?.isNotEmpty ==
//                                               true)
//                                             Icon(
//                                               Icons.chevron_right,
//                                               size: 16,
//                                               color: Colors.grey[600],
//                                             ),
//                                         ],
//                                       ),
//                                     ),
//                                     Expanded(
//                                       flex: 2,
//                                       child: Text(
//                                         voucher['voucher_type'] as String? ?? '-',
//                                         style: TextStyle(fontSize: 11),
//                                         maxLines: 1,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ),
//                                     Expanded(
//                                       flex: 2,
//                                       child: Text(
//                                         voucher['voucher_number']?.toString() ?? '-',
//                                         style: TextStyle(fontSize: 12),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       flex: 2,
//                                       child: Text(
//                                         debit > 0 ? _formatAmount(debit) : '-',
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: debit > 0 ? Colors.red[700] : Colors.grey,
//                                         ),
//                                         textAlign: TextAlign.right,
//                                       ),
//                                     ),
//                                     Expanded(
//                                       flex: 2,
//                                       child: Text(
//                                         credit > 0 ? _formatAmount(credit) : '-',
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: credit > 0 ? Colors.green[700] : Colors.grey,
//                                         ),
//                                         textAlign: TextAlign.right,
//                                       ),
//                                     ),
//                                     Expanded(
//                                       flex: 2,
//                                       child: Text(
//                                         _formatAmount(balance),
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.bold,
//                                           color: balance >= 0
//                                               ? Colors.green[700]
//                                               : Colors.red[700],
//                                         ),
//                                         textAlign: TextAlign.right,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                 ),

//                 // Summary Footer
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     border: Border(
//                       top: BorderSide(color: Colors.grey[400]!, width: 2),
//                     ),
//                   ),
//                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         flex: 10,
//                         child: Text(
//                           'Total (${_vouchers.length} transactions)',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 14,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           _formatAmount(_calculateTotal('debit')),
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.red[700],
//                             fontSize: 13,
//                           ),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           _formatAmount(_calculateTotal('credit')),
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.green[700],
//                             fontSize: 13,
//                           ),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           _formatAmount(_vouchers.isNotEmpty
//                               ? (_vouchers.last['balance'] as num?)?.toDouble() ?? 0.0
//                               : _openingBalance),
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 13,
//                           ),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }

//   double _calculateTotal(String field) {
//     return _vouchers.fold(
//       0.0,
//       (sum, voucher) => sum + ((voucher[field] as num?)?.toDouble() ?? 0.0),
//     );
//   }

//   String _formatAmount(double amount) {
//     return amount.toStringAsFixed(2).replaceAllMapped(
//           RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
//           (Match m) => '${m[1]},',
//         );
//   }

//   String _formatDate(String tallyDate) {
//     if (tallyDate.length != 8) return tallyDate;
//     final year = tallyDate.substring(0, 4);
//     final month = tallyDate.substring(4, 6);
//     final day = tallyDate.substring(6, 8);
//     return '$day-$month-$year';
//   }
// }

// screens/Analysis/ledger_detail_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'voucher_detail_screen.dart';

class LedgerDetailScreen extends StatefulWidget {
  final String companyGuid;
  final String companyName;
  final String ledgerName;
  final String fromDate;
  final String toDate;

  const LedgerDetailScreen({
    Key? key,
    required this.companyGuid,
    required this.companyName,
    required this.ledgerName,
    required this.fromDate,
    required this.toDate,
  }) : super(key: key);

  @override
  State<LedgerDetailScreen> createState() => _LedgerDetailScreenState();
}

class _LedgerDetailScreenState extends State<LedgerDetailScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  bool _loading = true;
  List<Map<String, dynamic>> _vouchers = [];
  double _openingBalance = 0.0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF1A6FD8);
  static const Color _bg        = Color(0xFFF4F6FB);
  static const Color _cardBg    = Colors.white;
  static const Color _textDark  = Color(0xFF1A2340);
  static const Color _textMuted = Color(0xFF8A94A6);
  static const Color _positiveC = Color(0xFF1B8A5A);
  static const Color _negativeC = Color(0xFFD32F2F);
  static const Color _tableBg   = Color(0xFFF0F3FA);
  static const Color _debitC    = Color(0xFFD32F2F);
  static const Color _creditC   = Color(0xFF1B8A5A);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadVouchers();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadVouchers() async {
    setState(() => _loading = true);

    final db = await _db.database;

    final ledgerResult = await db.rawQuery('''
      SELECT opening_balance FROM ledgers
      WHERE company_guid = ? AND name = ? AND is_deleted = 0
      LIMIT 1
    ''', [widget.companyGuid, widget.ledgerName]);

    if (ledgerResult.isNotEmpty) {
      _openingBalance =
          (ledgerResult.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
    }

    final voucherResult = await db.rawQuery('''
      SELECT
        v.voucher_guid,
        v.date,
        v.voucher_type,
        v.voucher_number,
        v.narration,
        vle.amount,
        CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END AS debit,
        CASE WHEN vle.amount > 0 THEN vle.amount           ELSE 0 END AS credit
      FROM vouchers v
      INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
      WHERE v.company_guid   = ?
        AND vle.ledger_name  = ?
        AND v.is_deleted     = 0
        AND v.is_cancelled   = 0
        AND v.is_optional    = 0
        AND v.date >= ?
        AND v.date <= ?
      ORDER BY v.date ASC, v.voucher_number ASC
    ''', [widget.companyGuid, widget.ledgerName, widget.fromDate, widget.toDate]);

    double balance = _openingBalance;
    final withBalance = <Map<String, dynamic>>[];
    for (final v in voucherResult) {
      final credit = (v['credit'] as num?)?.toDouble() ?? 0.0;
      final debit  = (v['debit']  as num?)?.toDouble() ?? 0.0;
      balance = balance + credit - debit;
      withBalance.add({...v, 'balance': balance});
    }

    setState(() {
      _vouchers = withBalance;
      _loading  = false;
    });
    _fadeCtrl.forward(from: 0);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _totalField(String field) => _vouchers.fold(
      0.0, (s, v) => s + ((v[field] as num?)?.toDouble() ?? 0.0));

  String _formatAmount(double amount) {
    final isNeg = amount < 0;
    final f = amount.abs().toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${isNeg ? '-' : ''}₹$f';
  }

  String _formatDate(String d) {
    if (d.length != 8) return d;
    return '${d.substring(6)}-${d.substring(4, 6)}-${d.substring(0, 4)}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
                  _buildHeader(),
                  _buildTableHeader(),
                  Expanded(child: _buildList()),
                  _buildFooter(),
                ],
              ),
            ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: _textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.ledgerName,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(
            '${_formatDate(widget.fromDate)} → ${_formatDate(widget.toDate)}',
            style: const TextStyle(fontSize: 11, color: _textMuted),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textMuted, size: 20),
          onPressed: _loadVouchers,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade100),
      ),
    );
  }

  // ── Header banner ──────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final closingBalance = _vouchers.isNotEmpty
        ? (_vouchers.last['balance'] as num?)?.toDouble() ?? _openingBalance
        : _openingBalance;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A6FD8), Color(0xFF0D4DA0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.companyName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 6),
                _balancePill('Opening', _openingBalance),
              ],
            ),
          ),
          _balanceSummaryBox('Closing', closingBalance),
        ],
      ),
    );
  }

  Widget _balancePill(String label, double amount) {
    final isPos = amount >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: ${_formatAmount(amount)}',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isPos
                ? Colors.greenAccent.shade100
                : Colors.redAccent.shade100),
      ),
    );
  }

  Widget _balanceSummaryBox(String label, double amount) {
    final isPos = amount >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 3),
          Text(_formatAmount(amount),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isPos
                      ? Colors.greenAccent.shade100
                      : Colors.redAccent.shade100)),
        ],
      ),
    );
  }

  // ── Table header ───────────────────────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      color: _tableBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          _hCell('Date',       flex: 2),
          _hCell('Particulars',flex: 3),
          _hCell('Vch Type',   flex: 2),
          _hCell('Vch No.',    flex: 2),
          _hCell('Debit',      flex: 2, align: TextAlign.right),
          _hCell('Credit',     flex: 2, align: TextAlign.right),
          _hCell('Balance',    flex: 2, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _hCell(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _textMuted,
              letterSpacing: 0.3)),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_vouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            const Text('No transactions found',
                style: TextStyle(color: _textMuted, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _vouchers.length,
      itemBuilder: (ctx, i) => _buildVoucherRow(_vouchers[i], i),
    );
  }

  Widget _buildVoucherRow(Map<String, dynamic> v, int index) {
    final debit   = (v['debit']   as num?)?.toDouble() ?? 0.0;
    final credit  = (v['credit']  as num?)?.toDouble() ?? 0.0;
    final balance = (v['balance'] as num?)?.toDouble() ?? 0.0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoucherDetailScreen(
            companyGuid: widget.companyGuid,
            companyName: widget.companyName,
            voucherGuid: v['voucher_guid'] as String,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: index.isEven ? _cardBg : _bg,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 0.8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Date
            Expanded(
              flex: 2,
              child: Text(_formatDate(v['date'] as String),
                  style: const TextStyle(fontSize: 11, color: _textMuted)),
            ),
            // Particulars
            Expanded(
              flex: 3,
              child: Text(
                (v['narration'] as String?)?.isNotEmpty == true
                    ? v['narration'] as String
                    : '-',
                style: const TextStyle(fontSize: 11, color: _textDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Vch type
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  v['voucher_type'] as String? ?? '-',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Vch number
            Expanded(
              flex: 2,
              child: Text(
                v['voucher_number']?.toString() ?? '-',
                style: const TextStyle(fontSize: 11, color: _textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            // Debit
            Expanded(
              flex: 2,
              child: Text(
                debit > 0 ? _formatAmount(debit) : '-',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: debit > 0 ? _debitC : Colors.grey.shade300),
                textAlign: TextAlign.right,
              ),
            ),
            // Credit
            Expanded(
              flex: 2,
              child: Text(
                credit > 0 ? _formatAmount(credit) : '-',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: credit > 0 ? _creditC : Colors.grey.shade300),
                textAlign: TextAlign.right,
              ),
            ),
            // Balance
            Expanded(
              flex: 2,
              child: Text(
                _formatAmount(balance),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: balance >= 0 ? _positiveC : _negativeC),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final totalDebit  = _totalField('debit');
    final totalCredit = _totalField('credit');
    final closing     = _vouchers.isNotEmpty
        ? (_vouchers.last['balance'] as num?)?.toDouble() ?? _openingBalance
        : _openingBalance;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_vouchers.length} txns',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _textMuted),
            ),
          ),
          const Spacer(),
          _footerAmount('Debit', totalDebit,  _debitC),
          const SizedBox(width: 16),
          _footerAmount('Credit', totalCredit, _creditC),
          const SizedBox(width: 16),
          _footerAmount('Balance', closing,
              closing >= 0 ? _positiveC : _negativeC,
              isBold: true),
        ],
      ),
    );
  }

  Widget _footerAmount(String label, double amount, Color color,
      {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: _textMuted)),
        const SizedBox(height: 2),
        Text(
          _formatAmount(amount),
          style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color),
        ),
      ],
    );
  }
}