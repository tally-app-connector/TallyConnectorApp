// import 'package:flutter/material.dart';
// import 'package:tally_connector/services/sync_service.dart';
// import '../../database/database_helper.dart';
// import '../../utils/secure_storage.dart';

// class DesktopSettingsScreen extends StatefulWidget {
//   const DesktopSettingsScreen({super.key});

//   @override
//   State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
// }

// class _DesktopSettingsScreenState extends State<DesktopSettingsScreen> {
//   final DatabaseHelper _db = DatabaseHelper.instance;
//   final SyncService _syncService = SyncService();

//   List<Map<String, dynamic>> _companies = [];
//   Map<String, dynamic>? _selectedCompany;
//   String _selectedCompanyID = '';
//   bool _loading = true;
//   bool _deletingData = false;
//   bool _fetchingData = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     setState(() => _loading = true);

//     try {
//       // Load all companies
//       final companies = await _db.getAllCompanies();

//       // Load selected company from preferences
//       _selectedCompanyID = await SecureStorage.getSelectedCompanyGuid() ?? '';

//       Map<String, dynamic>? selectedCompany;
//       if (_selectedCompanyID.isNotEmpty) {
//         selectedCompany = companies.firstWhere(
//           (c) => c['company_guid'] == _selectedCompanyID,
//           orElse: () => companies.isNotEmpty ? companies.first : {},
//         );
//       } else if (companies.isNotEmpty) {
//         selectedCompany = companies.first;
//       }

//       setState(() {
//         _companies = companies;
//         _selectedCompany = selectedCompany;
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() => _loading = false);
//     }
//   }

//   Future<void> _selectCompany(Map<String, dynamic> company) async {
//     try {
//       await SecureStorage.saveCompanyGuid(company['company_guid']);

//       setState(() => _selectedCompany = company);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('✅ Selected: ${company['company_name']}'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('❌ Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   Future<void> _fetchAllComapanies() async {
//     _fetchingData = true;
//     await _syncService.syncCompany(neonSync:true);
//     await _loadData();
//     _fetchingData = false;
//   }

//   Future<void> _clearAllData() async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Row(
//           children: [
//             Icon(Icons.warning, color: Colors.red),
//             SizedBox(width: 12),
//             Text('Clear All Data?'),
//           ],
//         ),
//         content: const Text(
//           'This will delete ALL data from the local database of current company'
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: TextButton.styleFrom(foregroundColor: Colors.red),
//             child: const Text('Delete All'),
//           ),
//         ],
//       ),
//     );

//     if (confirmed != true) return;

//     setState(() => _deletingData = true);

//     try {
//       await _db.clearAllData(_selectedCompanyID);
//       await SecureStorage.clearAll();
//       setState(() {
//         _selectedCompany = null;
//         _companies = [];
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('✅ All data cleared successfully'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error clearing data: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       setState(() => _deletingData = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Settings'),
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Company Selection Section
//                   _buildSectionHeader('🏢 Company Selection', Colors.blue),
//                   const SizedBox(height: 12),
//                   Card(
//                     elevation: 2,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Active Company',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           if (_companies.isEmpty)
//                             Container(
//                               padding: const EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 color: Colors.grey.shade100,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: const Row(
//                                 children: [
//                                   Icon(Icons.info_outline, color: Colors.grey),
//                                   SizedBox(width: 12),
//                                   Expanded(
//                                     child: Text(
//                                       'No companies available. Please sync from Tally.',
//                                       style: TextStyle(color: Colors.grey),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             )
//                           else
//                             Container(
//                               padding:
//                                   const EdgeInsets.symmetric(horizontal: 12),
//                               decoration: BoxDecoration(
//                                 border: Border.all(color: Colors.grey.shade300),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: DropdownButtonHideUnderline(
//                                 child: DropdownButton<String>(
//                                   isExpanded: true,
//                                   value: _selectedCompany?['company_guid'],
//                                   items: _companies.map((company) {
//                                     return DropdownMenuItem<String>(
//                                       value: company['company_guid'],
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.center,
//                                         children: [
//                                           Text(
//                                             company['company_name'],
//                                             style: const TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                           if (company['company_address'] != null &&
//                                               company['company_address']
//                                                   .toString()
//                                                   .isNotEmpty)
//                                             Text(
//                                               company['company_address'],
//                                               style: TextStyle(
//                                                 fontSize: 12,
//                                                 color: Colors.grey.shade600,
//                                               ),
//                                               maxLines: 1,
//                                               overflow: TextOverflow.ellipsis,
//                                             ),
//                                         ],
//                                       ),
//                                     );
//                                   }).toList(),
//                                   onChanged: (guid) {
//                                     final company = _companies.firstWhere(
//                                       (c) => c['company_guid'] == guid,
//                                     );
//                                     _selectCompany(company);
//                                   },
//                                 ),
//                               ),
//                             ),
//                           if (_selectedCompany != null && _selectedCompany?['company_guid'] != null) ...[
//                             const SizedBox(height: 16),
//                             Container(
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: Colors.blue.shade50,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   _buildInfoRow(
//                                     'GUID',
//                                     _selectedCompany?['company_guid'],
//                                   ),
//                                   const SizedBox(height: 4),
//                                   _buildInfoRow(
//                                     'Last Sync',
//                                     _formatDate(_selectedCompany?['last_sync_timestamp']),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   _buildInfoRow(
//                                     'Alter ID',
//                                     '${_selectedCompany?['last_synced_alter_id'] ?? 0}',
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                           ListTile(
//                             leading: _fetchingData
//                                 ? const SizedBox(
//                                     width: 24,
//                                     height: 24,
//                                     child: CircularProgressIndicator(
//                                         strokeWidth: 2),
//                                   )
//                                 : const Icon(Icons.delete_forever,
//                                     color: Colors.red),
//                             title: const Text(
//                               'Fetch All Companies',
//                               style: TextStyle(color: Colors.red),
//                             ),
//                             subtitle:
//                                 const Text('Delete all local database data'),
//                             trailing: const Icon(Icons.chevron_right,
//                                 color: Colors.red),
//                             onTap: _deletingData ? null : _fetchAllComapanies,
//                           )
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 32),

//                   // Danger Zone Section
//                   _buildSectionHeader('⚠️ Danger Zone', Colors.red),
//                   const SizedBox(height: 12),
//                   Card(
//                     elevation: 2,
//                     color: Colors.red.shade50,
//                     child: Column(
//                       children: [
//                         ListTile(
//                           leading: _deletingData
//                               ? const SizedBox(
//                                   width: 24,
//                                   height: 24,
//                                   child:
//                                       CircularProgressIndicator(strokeWidth: 2),
//                                 )
//                               : const Icon(Icons.delete_forever,
//                                   color: Colors.red),
//                           title: const Text(
//                             'Clear Local Data',
//                             style: TextStyle(color: Colors.red),
//                           ),
//                           subtitle:
//                               const Text('Delete all local database data'),
//                           trailing: const Icon(Icons.chevron_right,
//                               color: Colors.red),
//                           onTap: _deletingData ? null : _clearAllData,
//                         ),
//                         const Divider(height: 1),
//                         const ListTile(
//                           leading: Icon(Icons.cloud_off, color: Colors.red),
//                           title: Text(
//                             'Clear Neon Data',
//                             style: TextStyle(color: Colors.red),
//                           ),
//                           subtitle: Text('Delete all cloud database data'),
//                           trailing:
//                               Icon(Icons.chevron_right, color: Colors.red),
//                           // onTap: _clearNeonData,
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 32),

//                   // About Section
//                   _buildSectionHeader('ℹ️ About', Colors.grey),
//                   const SizedBox(height: 12),
//                   const Card(
//                     elevation: 2,
//                     child: Column(
//                       children: [
//                         ListTile(
//                           leading: Icon(Icons.info, color: Colors.grey),
//                           title: Text('Version'),
//                           subtitle: Text('1.0.0'),
//                         ),
//                         Divider(height: 1),
//                         ListTile(
//                           leading: Icon(Icons.code, color: Colors.grey),
//                           title: Text('Built with'),
//                           subtitle: Text(
//                               'Flutter ${String.fromEnvironment('FLUTTER_VERSION', defaultValue: '3.x')}'),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildSectionHeader(String title, Color color) {
//     return Row(
//       children: [
//         Container(
//           width: 4,
//           height: 24,
//           color: color,
//         ),
//         const SizedBox(width: 12),
//         Text(
//           title,
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildInfoRow(String label, String value) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 80,
//           child: Text(
//             '$label:',
//             style: TextStyle(
//               color: Colors.grey.shade700,
//               fontSize: 12,
//             ),
//           ),
//         ),
//         Expanded(
//           child: Text(
//             value,
//             style: const TextStyle(
//               fontWeight: FontWeight.w500,
//               fontSize: 12,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   String _formatDate(dynamic timestamp) {
//     if (timestamp == null) return 'Never';

//     try {
//       final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
//       return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
//     } catch (e) {
//       return 'Invalid date';
//     }
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tally_connector/services/sync_service.dart';
import '../../database/database_helper.dart';
import '../../utils/secure_storage.dart';

class DesktopSettingsScreen extends StatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SyncService _syncService = SyncService();

  List<Map<String, dynamic>> _companies = [];
  Map<String, dynamic>? _selectedCompany;
  String _selectedCompanyID = '';
  bool _loading = true;
  bool _deletingData = false;
  bool _fetchingData = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Design Tokens ──────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF1A6FD8);
  static const Color _accent    = Color(0xFF00C9A7);
  static const Color _bg        = Color(0xFFF4F6FB);
  static const Color _cardBg    = Colors.white;
  static const Color _textDark  = Color(0xFF1A2340);
  static const Color _textMuted = Color(0xFF8A94A6);
  static const Color _danger    = Color(0xFFE53935);
  static const Color _dangerBg  = Color(0xFFFFF0F0);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final companies = await _db.getAllCompanies();
      _selectedCompanyID = await SecureStorage.getSelectedCompanyGuid() ?? '';

      Map<String, dynamic>? selected;
      if (_selectedCompanyID.isNotEmpty) {
        selected = companies.firstWhere(
          (c) => c['company_guid'] == _selectedCompanyID,
          orElse: () => companies.isNotEmpty ? companies.first : {},
        );
      } else if (companies.isNotEmpty) {
        selected = companies.first;
      }

      setState(() {
        _companies = companies;
        _selectedCompany = selected;
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectCompany(Map<String, dynamic> company) async {
    try {
      await SecureStorage.saveCompanyGuid(company['company_guid']);
      setState(() => _selectedCompany = company);
      _showSnack('Selected: ${company['company_name']}', isError: false);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _fetchAllComapanies() async {
    setState(() => _fetchingData = true);
    await _syncService.syncCompany(neonSync: true);
    await _loadData();
    setState(() => _fetchingData = false);
  }

  Future<void> _clearAllData() async {
    final confirmed = await _showDangerDialog(
      title: 'Clear Local Data?',
      body: 'This will delete ALL data from the local database for the current company. This action cannot be undone.',
      confirmLabel: 'Delete All',
    );
    if (confirmed != true) return;

    setState(() => _deletingData = true);
    try {
      await _db.clearAllData(_selectedCompanyID);
      await SecureStorage.clearAll();
      setState(() {
        _selectedCompany = null;
        _companies = [];
      });
      _showSnack('All local data cleared successfully', isError: false);
    } catch (e) {
      _showSnack('Error clearing data: $e', isError: true);
    } finally {
      setState(() => _deletingData = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isError ? _danger : _accent,
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  Future<bool?> _showDangerDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _dangerBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: _danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
            ),
          ],
        ),
        content: Text(body,
            style: const TextStyle(fontSize: 14, color: _textMuted, height: 1.5)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMuted,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      return '${date.day}/${date.month}/${date.year}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Invalid date';
    }
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Company', Icons.business_center_rounded, _primary),
                    const SizedBox(height: 12),
                    _buildCompanyCard(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Danger Zone', Icons.warning_amber_rounded, _danger),
                    const SizedBox(height: 12),
                    _buildDangerCard(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('About', Icons.info_outline_rounded, _textMuted),
                    const SizedBox(height: 12),
                    _buildAboutCard(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Settings',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: _textDark,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade100),
      ),
    );
  }

  // ── Section Label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── Company Card ───────────────────────────────────────────────────────────

  Widget _buildCompanyCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // Dropdown / empty state
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Company',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark)),
                const SizedBox(height: 10),
                _companies.isEmpty
                    ? _buildEmptyState()
                    : _buildDropdown(),
              ],
            ),
          ),

          // Selected company meta-info
          if (_selectedCompany != null &&
              (_selectedCompany?['company_guid'] ?? '').toString().isNotEmpty)
            _buildCompanyMeta(),

          // Divider
          Divider(height: 1, color: Colors.grey.shade100),

          // Fetch action
          _buildActionTile(
            icon: Icons.cloud_download_rounded,
            label: 'Fetch All Companies',
            sublabel: 'Pull company list from Tally',
            color: _primary,
            loading: _fetchingData,
            onTap: _fetchingData ? null : _fetchAllComapanies,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _textMuted, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No companies found. Sync from Tally to get started.',
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          icon: const Icon(Icons.unfold_more_rounded, color: _textMuted, size: 20),
          value: _selectedCompany?['company_guid'],
          items: _companies.map((company) {
            return DropdownMenuItem<String>(
              value: company['company_guid'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(company['company_name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _textDark)),
                  if ((company['company_address'] ?? '').toString().isNotEmpty)
                    Text(company['company_address'],
                        style: const TextStyle(fontSize: 11, color: _textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          }).toList(),
          onChanged: (guid) {
            final company = _companies.firstWhere((c) => c['company_guid'] == guid);
            _selectCompany(company);
          },
        ),
      ),
    );
  }

  Widget _buildCompanyMeta() {
    final guid = (_selectedCompany?['company_guid'] ?? '') as String;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primary.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          _metaRow(
            label: 'GUID',
            value: guid,
            trailingWidget: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: guid));
                _showSnack('GUID copied', isError: false);
              },
              child: const Icon(Icons.copy_rounded, size: 14, color: _textMuted),
            ),
          ),
          const SizedBox(height: 8),
          _metaRow(
            label: 'Last Sync',
            value: _formatDate(_selectedCompany?['last_sync_timestamp']),
          ),
          const SizedBox(height: 8),
          _metaRow(
            label: 'Alter ID',
            value: '${_selectedCompany?['last_synced_alter_id'] ?? 0}',
          ),
        ],
      ),
    );
  }

  Widget _metaRow({
    required String label,
    required String value,
    Widget? trailingWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                  letterSpacing: 0.2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textDark)),
        ),
        if (trailingWidget != null) ...[
          const SizedBox(width: 8),
          trailingWidget,
        ],
      ],
    );
  }

  // ── Danger Card ────────────────────────────────────────────────────────────

  Widget _buildDangerCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _danger.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
              color: _danger.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Clear Local Data',
            sublabel: 'Delete all local database records',
            color: _danger,
            loading: _deletingData,
            onTap: _deletingData ? null : _clearAllData,
          ),
          Divider(height: 1, color: _danger.withOpacity(0.1)),
          _buildActionTile(
            icon: Icons.cloud_off_rounded,
            label: 'Clear Neon Data',
            sublabel: 'Delete all cloud database records',
            color: _danger,
            loading: false,
            onTap: null, // reserved
            disabled: true,
          ),
        ],
      ),
    );
  }

  // ── About Card ─────────────────────────────────────────────────────────────

  Widget _buildAboutCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.tag_rounded,
            label: 'Version',
            value: '1.0.0',
            color: _textMuted,
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildInfoTile(
            icon: Icons.code_rounded,
            label: 'Built with',
            value: 'Flutter ${const String.fromEnvironment('FLUTTER_VERSION', defaultValue: '3.x')}',
            color: _textMuted,
          ),
        ],
      ),
    );
  }

  // ── Reusable tile widgets ──────────────────────────────────────────────────

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required bool loading,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(disabled ? 0.05 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(icon,
                      color: disabled
                          ? color.withOpacity(0.35)
                          : color,
                      size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: disabled
                              ? _textMuted.withOpacity(0.5)
                              : color)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: const TextStyle(fontSize: 12, color: _textMuted)),
                ],
              ),
            ),
            if (disabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Soon',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _textMuted)),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: _textMuted.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textDark)),
          ),
          Text(value,
              style: const TextStyle(fontSize: 13, color: _textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}