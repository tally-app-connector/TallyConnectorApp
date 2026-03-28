// import 'package:flutter/material.dart';
// import '../../services/auth_service.dart';
// import '../../database/database_helper.dart';
// import '../../utils/secure_storage.dart';
// import '../../utils/message_helper.dart';
// import '../../models/user_model.dart';
// import '../auth/login_screen.dart';
// import '../auth/email_verification_screen.dart';
// import '../sync_screen.dart';
// import 'dart:convert';

// import 'database_overview_screen.dart';

// class MobileProfileTab extends StatefulWidget {
//   const MobileProfileTab({Key? key}) : super(key: key);

//   @override
//   State<MobileProfileTab> createState() => _MobileProfileTabState();
// }

// class _MobileProfileTabState extends State<MobileProfileTab> {
//   final DatabaseHelper _db = DatabaseHelper.instance;
//   User? _currentUser;
//   bool _isLoading = true;
//   List<Map<String, dynamic>> _companies = [];
//   Map<String, dynamic>? _selectedCompany;
//   String _selectedCompanyID = '';
//   bool _deletingData = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     final userData = await SecureStorage.getUser();
//     _selectedCompanyID = await SecureStorage.getSelectedCompanyGuid() ?? '';
//     if (userData != null) {
//       _currentUser = User.fromJson(jsonDecode(userData));
//     }
//     await _loadCompanies();
//     setState(() => _isLoading = false);
//   }

//   Future<void> _loadCompanies() async {
//     final companies = await _db.getAllCompanies();
//     final selectedGuid = await SecureStorage.getSelectedCompanyGuid() ?? '';

//     Map<String, dynamic>? selected;
//     if (selectedGuid.isNotEmpty) {
//       selected = companies.firstWhere(
//         (c) => c['company_guid'] == selectedGuid,
//         orElse: () => companies.isNotEmpty ? companies.first : {},
//       );
//       if (selected.isEmpty) selected = null;
//     } else if (companies.isNotEmpty) {
//       selected = companies.first;
//     }

//     setState(() {
//       _companies = companies;
//       _selectedCompany = selected;
//     });
//   }

//   Future<void> _selectCompany(Map<String, dynamic> company) async {
//     await SecureStorage.saveCompanyGuid(company['company_guid']);
//     setState(() => _selectedCompany = company);
//     if (mounted) {
//       MessageHelper.showSuccess(context, 'Selected: ${company['company_name']}');
//     }
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

//   Future<void> _handleLogout() async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Logout'),
//         content: const Text('Are you sure you want to logout?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Logout'),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       await AuthService.logout();
//       MessageHelper.showSuccess(context, "Logged out successfully");

//       if (mounted) {
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (_) => const LoginScreen()),
//           (route) => false,
//         );
//       }
//     }
//   }

//   String _formatDate(DateTime? date) {
//     if (date == null) return 'N/A';
//     return '${date.day}/${date.month}/${date.year}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         title: const Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // Profile header
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 10,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   CircleAvatar(
//                     radius: 40,
//                     backgroundColor: Colors.blue.shade100,
//                     child: Text(
//                       _currentUser?.fullName[0].toUpperCase() ?? 'U',
//                       style: TextStyle(
//                         fontSize: 32,
//                         color: Colors.blue.shade700,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     _currentUser?.fullName ?? 'User',
//                     style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     _currentUser?.email ?? '',
//                     style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                   ),
//                   if (_currentUser?.phone != null) ...[
//                     const SizedBox(height: 4),
//                     Text(
//                       _currentUser!.phone!,
//                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                     ),
//                   ],
//                   const SizedBox(height: 12),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                       color: _currentUser?.isVerified == true
//                           ? Colors.green.withOpacity(0.1)
//                           : Colors.orange.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Text(
//                       _currentUser?.isVerified == true ? 'Verified' : 'Not Verified',
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                         color: _currentUser?.isVerified == true ? Colors.green : Colors.orange,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Account info
//             Container(
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 10,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   _buildInfoTile(
//                     icon: Icons.calendar_today,
//                     title: 'Member Since',
//                     value: _formatDate(_currentUser?.createdAt),
//                   ),
//                   if (_currentUser?.lastLogin != null)
//                     _buildInfoTile(
//                       icon: Icons.access_time,
//                       title: 'Last Login',
//                       value: _formatDate(_currentUser?.lastLogin),
//                     ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Company selection
//             Container(
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 10,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(Icons.business, size: 20, color: Colors.blue.shade700),
//                         const SizedBox(width: 8),
//                         const Text(
//                           'Active Company',
//                           style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     if (_companies.isEmpty)
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: Colors.grey.shade100,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
//                             const SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'No companies available. Sync data to load companies.',
//                                 style: TextStyle(fontSize: 13, color: Colors.grey[600]),
//                               ),
//                             ),
//                           ],
//                         ),
//                       )
//                     else
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 12),
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey.shade300),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: DropdownButtonHideUnderline(
//                           child: DropdownButton<String>(
//                             isExpanded: true,
//                             value: _selectedCompany?['company_guid'],
//                             items: _companies.map((company) {
//                               return DropdownMenuItem<String>(
//                                 value: company['company_guid'],
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Text(
//                                       company['company_name'] ?? '',
//                                       style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
//                                     ),
//                                     if (company['company_address'] != null &&
//                                         company['company_address'].toString().isNotEmpty)
//                                       Text(
//                                         company['company_address'],
//                                         style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//                                         maxLines: 1,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                   ],
//                                 ),
//                               );
//                             }).toList(),
//                             onChanged: (guid) {
//                               final company = _companies.firstWhere(
//                                 (c) => c['company_guid'] == guid,
//                               );
//                               _selectCompany(company);
//                             },
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Actions
//             Container(
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 10,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   if (_currentUser != null && !_currentUser!.isVerified)
//                     _buildActionTile(
//                       icon: Icons.verified_user,
//                       title: 'Verify Email',
//                       color: Colors.orange,
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) => EmailVerificationScreen(
//                               email: _currentUser!.email,
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   _buildActionTile(
//                     icon: Icons.sync,
//                     title: 'Sync Data',
//                     color: Colors.blue,
//                     onTap: () async {
//                       await Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => SyncScreen()),
//                       );
//                       _loadCompanies();
//                     },
//                   ),
//                    _buildActionTile(
//                     icon: Icons.sync,
//                     title: 'Database Overview',
//                     color: Colors.blue,
//                     onTap: () async {
//                       await Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => DatabaseOverviewScreen()),
//                       );
//                       _loadCompanies();
//                     },
//                   ),
//                   _buildActionTile(
//                     icon: Icons.logout,
//                     title: 'Logout',
//                     color: Colors.red,
//                     onTap: _handleLogout,
//                   ),
//                    _buildActionTile(
//                     icon: Icons.logout,
//                     title: 'Delete All Data',
//                     color: Colors.red,
//                     onTap: _clearAllData,
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 24),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoTile({
//     required IconData icon,
//     required String title,
//     required String value,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Row(
//         children: [
//           Icon(icon, size: 20, color: Colors.grey[600]),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
//                 const SizedBox(height: 2),
//                 Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionTile({
//     required IconData icon,
//     required String title,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         child: Row(
//           children: [
//             Icon(icon, size: 22, color: color),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
//             ),
//             Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../database/database_helper.dart';
import '../../utils/secure_storage.dart';
import '../../utils/message_helper.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../auth/email_verification_screen.dart';
import '../sync_screen.dart';
import 'dart:convert';
import 'database_overview_screen.dart';
import '../theme/app_theme.dart';

class MobileProfileTab extends StatefulWidget {
  const MobileProfileTab({Key? key}) : super(key: key);

  @override
  State<MobileProfileTab> createState() => _MobileProfileTabState();
}

class _MobileProfileTabState extends State<MobileProfileTab>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper.instance;

  User? _currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _companies = [];
  Map<String, dynamic>? _selectedCompany;
  String _selectedCompanyID = '';
  bool _deletingData = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Theme tokens (matches app) ─────────────────────────────────────────────
  static const Color _primary    = Color(0xFF1A6FD8);
  static const Color _accent     = Color(0xFF00C9A7);
  static Color get _bg           => AppColors.background;
  static Color get _cardBg       => AppColors.surface;
  static Color get _textDark     => AppColors.textPrimary;
  static Color get _textMuted    => AppColors.textSecondary;
  static const Color _danger     = Color(0xFFE53935);
  static const Color _warning    = Color(0xFFFFA000);
  static const Color _positive   = Color(0xFF1B8A5A);

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

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final userData = await SecureStorage.getUser();
    _selectedCompanyID = await SecureStorage.getSelectedCompanyGuid() ?? '';
    if (userData != null) {
      _currentUser = User.fromJson(jsonDecode(userData));
    }
    await _loadCompanies();
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> _loadCompanies() async {
    final companies   = await _db.getAllCompanies();
    final selectedGuid = await SecureStorage.getSelectedCompanyGuid() ?? '';

    Map<String, dynamic>? selected;
    if (selectedGuid.isNotEmpty) {
      selected = companies.firstWhere(
        (c) => c['company_guid'] == selectedGuid,
        orElse: () => companies.isNotEmpty ? companies.first : {},
      );
      if ((selected as Map).isEmpty) selected = null;
    } else if (companies.isNotEmpty) {
      selected = companies.first;
    }

    if (mounted) {
      setState(() {
        _companies       = companies;
        _selectedCompany = selected;
      });
    }
  }

  Future<void> _selectCompany(Map<String, dynamic> company) async {
    await SecureStorage.saveCompanyGuid(company['company_guid']);
    if (mounted) {
      setState(() => _selectedCompany = company);
      _showSnack('Selected: ${company['company_name']}', isError: false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await _showDangerDialog(
      title: 'Clear All Data?',
      body: 'This will delete ALL data from the local database for the current company.',
      confirmLabel: 'Delete All',
    );
    if (confirmed != true) return;

    setState(() => _deletingData = true);
    try {
      await _db.clearAllData(_selectedCompanyID);
      await SecureStorage.clearAll();
      if (mounted) {
        setState(() { _selectedCompany = null; _companies = []; });
        _showSnack('All data cleared successfully', isError: false);
      }
    } catch (e) {
      if (mounted) _showSnack('Error clearing data: $e', isError: true);
    } finally {
      if (mounted) setState(() => _deletingData = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await _showDangerDialog(
      title: 'Logout',
      body: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
    );
    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isError ? _danger : _accent,
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      duration: Duration(seconds: isError ? 4 : 3),
    ));
  }

  Future<bool?> _showDangerDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _danger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: _danger, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textDark)),
          ),
        ]),
        content: Text(body,
            style: TextStyle(
                fontSize: 14, color: _textMuted, height: 1.5)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMuted,
              side: BorderSide(color: Colors.grey.shade200),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(
                  children: [
                    // Verification banner
                    if (_currentUser != null && !_currentUser!.isVerified) ...[
                      const SizedBox(height: 16),
                      _buildVerificationBanner(),
                    ],
                    const SizedBox(height: 16),

                    // Account info card
                    _buildAccountInfoCard(),
                    const SizedBox(height: 16),

                    // Company selector card
                    _buildCompanyCard(),
                    const SizedBox(height: 16),

                    // Actions card
                    _buildActionsCard(),
                    const SizedBox(height: 16),

                    // App version
                    Text('Tally Connector  ·  v1.0.0',
                        style: TextStyle(
                            fontSize: 11, color: _textMuted)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sliver AppBar (profile header) ────────────────────────────────────────

  Widget _buildSliverAppBar() {
    final initials = (_currentUser?.fullName.trim().isNotEmpty == true)
        ? _currentUser!.fullName
            .trim()
            .split(' ')
            .map((e) => e[0])
            .take(2)
            .join()
            .toUpperCase()
        : 'U';
    final verified = _currentUser?.isVerified == true;

    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final headerHeight = (240 * textScale).clamp(240.0, 340.0);

    return SliverAppBar(
      expandedHeight: headerHeight,
      pinned: false,
      floating: false,
      elevation: 0,
      backgroundColor: _primary,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6FD8), Color(0xFF0D4DA0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                    child: Center(
                      child: Text(initials,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    _currentUser?.fullName ?? 'User',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.email ?? '',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.72)),
                  ),
                  const SizedBox(height: 12),

                  // Verified badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: verified
                          ? _accent.withOpacity(0.2)
                          : _warning.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: verified ? _accent : _warning, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          verified
                              ? Icons.verified_rounded
                              : Icons.warning_rounded,
                          size: 13,
                          color: verified ? _accent : _warning,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          verified ? 'Verified' : 'Not Verified',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: verified ? _accent : _warning),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Verification banner ────────────────────────────────────────────────────

  Widget _buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warning.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: _warning, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Verify your email to unlock all features',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A4F00)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EmailVerificationScreen(
                    email: _currentUser!.email)),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _warning,
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12),
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
          ),
          child: const Text('Verify →'),
        ),
      ]),
    );
  }

  // ── Account info card ──────────────────────────────────────────────────────

  Widget _buildAccountInfoCard() {
    return _card(
      child: Column(children: [
        _sectionHeader('Account', Icons.person_outline_rounded),
        const SizedBox(height: 4),
        _infoRow(Icons.calendar_today_rounded, 'Member Since',
            _formatDate(_currentUser?.createdAt)),
        if (_currentUser?.lastLogin != null) ...[
          _divider(),
          _infoRow(Icons.access_time_rounded, 'Last Login',
              _formatDate(_currentUser?.lastLogin)),
        ],
        if (_currentUser?.phone != null) ...[
          _divider(),
          _infoRow(Icons.phone_rounded, 'Phone',
              _currentUser!.phone!),
        ],
      ]),
    );
  }

  // ── Company card ───────────────────────────────────────────────────────────

  Widget _buildCompanyCard() {
    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        _sectionHeader('Active Company', Icons.business_center_rounded),
        const SizedBox(height: 14),
        if (_companies.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: _textMuted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No companies found. Sync data first.',
                  style: TextStyle(fontSize: 12, color: _textMuted),
                ),
              ),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                isDense: false,
                icon: Icon(Icons.unfold_more_rounded,
                    size: 18, color: _textMuted),
                value: _selectedCompany?['company_guid'],
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark),
                selectedItemBuilder: (context) {
                  return _companies.map((company) {
                    final name = company['company_name'] ?? '';
                    final addr = (company['company_address'] ?? '').toString();
                    final display = addr.isNotEmpty ? '$name - ($addr)' : name;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        display,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _textDark),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList();
                },
                items: _companies.map((company) {
                  return DropdownMenuItem<String>(
                    value: company['company_guid'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(company['company_name'] ?? '',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _textDark)),
                        if ((company['company_address'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Text(
                            company['company_address'],
                            style: TextStyle(
                                fontSize: 11, color: _textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (guid) {
                  final company = _companies
                      .firstWhere((c) => c['company_guid'] == guid);
                  _selectCompany(company);
                },
              ),
            ),
          ),
      ]),
    );
  }

  // ── Actions card ───────────────────────────────────────────────────────────

  Widget _buildActionsCard() {
    return _card(
      child: Column(children: [
        _sectionHeader('Actions', Icons.settings_rounded),
        const SizedBox(height: 4),

        if (_currentUser != null && !_currentUser!.isVerified) ...[
          _actionRow(
            icon: Icons.verified_user_rounded,
            label: 'Verify Email',
            color: _warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EmailVerificationScreen(
                      email: _currentUser!.email)),
            ),
          ),
          _divider(),
        ],

        _actionRow(
          icon: Icons.text_fields_rounded,
          label: 'Font Size  ·  ${FontScaleNotifier.options.entries.firstWhere((e) => (e.value - fontScaleNotifier.value).abs() < 0.01, orElse: () => const MapEntry('Default', 1.0)).key}',
          color: const Color(0xFF7C3AED),
          onTap: _showFontSizePicker,
        ),
        _divider(),

        _actionRow(
          icon: Icons.dark_mode_rounded,
          label: 'Theme  ·  ${_themeLabel()}',
          color: const Color(0xFF6366F1),
          onTap: _showThemePicker,
        ),
        _divider(),

        _actionRow(
          icon: Icons.sync_alt_rounded,
          label: 'Sync Data',
          color: _primary,
          onTap: () async {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => SyncScreen()));
            _loadCompanies();
          },
        ),
        _divider(),

        _actionRow(
          icon: Icons.storage_rounded,
          label: 'Database Overview',
          color: const Color(0xFF0891B2),
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DatabaseOverviewScreen()));
            _loadCompanies();
          },
        ),
        _divider(),

        _actionRow(
          icon: Icons.delete_sweep_rounded,
          label: 'Delete All Data',
          color: _danger,
          loading: _deletingData,
          onTap: _deletingData ? null : _clearAllData,
        ),
        _divider(),

        _actionRow(
          icon: Icons.logout_rounded,
          label: 'Logout',
          color: _danger,
          onTap: _handleLogout,
        ),
      ]),
    );
  }

  // ── Font size picker ───────────────────────────────────────────────────────

  void _showFontSizePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Font Size',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 16),
                ...FontScaleNotifier.options.entries.map((entry) {
                  final isSelected =
                      (entry.value - fontScaleNotifier.value).abs() < 0.01;
                  return InkWell(
                    onTap: () {
                      fontScaleNotifier.setScale(entry.value);
                      Navigator.pop(context);
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.08)
                            : AppColors.pillBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF7C3AED)
                              : AppColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Aa',
                            style: TextStyle(
                              fontSize: 14 * entry.value,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF7C3AED)
                                  : _textDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF7C3AED)
                                    : _textDark,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 20, color: Color(0xFF7C3AED)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Theme picker ─────────────────────────────────────────────────────────

  String _themeLabel() {
    switch (themeModeNotifier.value) {
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
      case ThemeMode.system: return 'System';
    }
  }

  void _showThemePicker() {
    final options = {
      'Light': ThemeMode.light,
      'Dark': ThemeMode.dark,
      'System': ThemeMode.system,
    };
    final icons = {
      'Light': Icons.light_mode_rounded,
      'Dark': Icons.dark_mode_rounded,
      'System': Icons.settings_suggest_rounded,
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...options.entries.map((entry) {
                  final isSelected = themeModeNotifier.value == entry.value;
                  return InkWell(
                    onTap: () {
                      themeModeNotifier.setMode(entry.value);
                      Navigator.pop(context);
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                            : AppColors.pillBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : AppColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icons[entry.key],
                            size: 22,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Color(0xFF6366F1), size: 22),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Reusable sub-widgets ───────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: _primary),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: 0.1)),
    ]);
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey.shade100);

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        Icon(icon, size: 17, color: _textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: _textMuted)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark)),
          ]),
        ),
      ]),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 4, vertical: 13),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                : Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: Colors.grey.shade300),
        ]),
      ),
    );
  }
}