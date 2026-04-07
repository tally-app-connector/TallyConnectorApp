// import 'package:flutter/material.dart';
// import 'package:tally_connector/screens/desktop/database_viewer_screen.dart';
// import 'package:tally_connector/screens/home/analytics_dashboard.dart';
// import 'package:tally_connector/screens/mobile/database_overview_screen.dart';
// import '../../services/auth_service.dart';
// import '../../utils/secure_storage.dart';
// import '../../models/user_model.dart';
// import '../auth/login_screen.dart';
// import '../auth/email_verification_screen.dart';
// import 'dart:convert';
// import '../../utils/message_helper.dart';
// import '../desktop/setting_screen.dart';
// import '../../services/sync_service.dart';
// import '../Analysis/analysis_home_screen.dart';
// import '../sync_screen.dart';


// class HomeScreen extends StatefulWidget {
//   const HomeScreen({Key? key}) : super(key: key);

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   User? _currentUser;
//   bool _isLoading = true;
//   final SyncService _syncService = SyncService();

//   @override
//   void initState() {
//     super.initState();
//     _loadUser();
//   }

//   Future<void> _loadUser() async {
//     final userData = await SecureStorage.getUser();
//     if (userData != null) {
//       setState(() {
//         _currentUser = User.fromJson(jsonDecode(userData));
//         _isLoading = false;
//       });
//     } else {
//       setState(() => _isLoading = false);
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
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//             ),
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

//  Future<void> _openSettingScreen() async {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => const DesktopSettingsScreen(),
//     ),
//   );

  
// }
// Future<void> _openDatabaseViewerScreen() async {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => const DatabaseOverviewScreen(),
//     ),
//   );
// }

// Future<void> _openAnalysisScreen() async {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => AnalyticsDashboard(),
//     ),
//   );
// }

// Future<void> _syncAllData() async {
//   await _syncService.syncAllData(neonSync: true);

//     ScaffoldMessenger.of(context).showSnackBar(
//     const SnackBar(
//       content: Text('✅ All data Sync successfully'),
//       backgroundColor: Colors.green,
//     ),
//   );
// }

// Future<void> _removeDeletedVoucherData() async {
//   await _syncService.detectAndDeleteMissingVouchers();

//     ScaffoldMessenger.of(context).showSnackBar(
//     const SnackBar(
//       content: Text('✅ All data Sync successfully'),
//       backgroundColor: Colors.green,
//     ),
//   );
// }

// Future<void> _syncIncrementalData() async {
//   await _syncService.syncIncrementalData(neonSync: true);

//     ScaffoldMessenger.of(context).showSnackBar(
//     const SnackBar(
//       content: Text('✅ All data Sync successfully'),
//       backgroundColor: Colors.green,
//     ),
//   );
// }


// Future<void> _openHomeAnalysisScreen() async {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => AnalysisHomeScreen(),
//     ),
//   );
// }

// Future<void> _openSyncServiceScreen() async {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => SyncScreen(),
//     ),
//   );
// }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Tally Connector'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: _handleLogout,
//             tooltip: 'Logout',
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: _openSettingScreen,
//             tooltip: 'Setting',
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: _openDatabaseViewerScreen,
//             tooltip: 'Setting',
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: _openAnalysisScreen,
//             tooltip: 'Setting',
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: _openHomeAnalysisScreen,
//             tooltip: 'Setting',
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: _openSyncServiceScreen,
//             tooltip: 'Setting',
//           ),

//         ],
//       ),
//       body: Column(
//         children: [
//           // Verification Banner
//           if (_currentUser != null && !_currentUser!.isVerified)
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(16),
//               color: Colors.orange.shade100,
//               child: Row(
//                 children: [
//                   Icon(Icons.warning_amber, color: Colors.orange.shade700),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Email Not Verified',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.orange.shade900,
//                             fontSize: 14,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         const Text(
//                           'Please verify your email to access all features',
//                           style: TextStyle(fontSize: 12),
//                         ),
//                       ],
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => EmailVerificationScreen(
//                             email: _currentUser!.email,
//                           ),
//                         ),
//                       );
//                     },
//                     style: TextButton.styleFrom(
//                       foregroundColor: Colors.orange.shade900,
//                     ),
//                     child: const Text('Verify'),
//                   ),
//                 ],
//               ),
//             ),

//           // Main Content
//           Expanded(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // Profile Picture
//                     CircleAvatar(
//                       radius: 50,
//                       backgroundColor: Colors.blue.shade100,
//                       child: Text(
//                         _currentUser?.fullName[0].toUpperCase() ?? 'U',
//                         style: TextStyle(
//                           fontSize: 40,
//                           color: Colors.blue.shade700,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 24),

//                     // Welcome Message
//                     Text(
//                       'Welcome, ${_currentUser?.fullName ?? 'User'}!',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 8),

//                     // Email
//                     Text(
//                       _currentUser?.email ?? '',
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: Colors.grey.shade600,
//                       ),
//                     ),
//                     const SizedBox(height: 4),

//                     // Phone
//                     if (_currentUser?.phone != null)
//                       Text(
//                         _currentUser!.phone!,
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.grey.shade600,
//                         ),
//                       ),
//                     const SizedBox(height: 32),

//                     // Account Info Card
//                     Card(
//                       elevation: 2,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.all(16),
//                         child: Column(
//                           children: [
//                             _buildInfoRow(
//                               icon: Icons.verified_user,
//                               label: 'Account Status',
//                               value: _currentUser?.isVerified == true
//                                   ? 'Verified ✅'
//                                   : 'Not Verified ⚠️',
//                               valueColor: _currentUser?.isVerified == true
//                                   ? Colors.green
//                                   : Colors.orange,
//                             ),
//                             const Divider(height: 24),
//                             _buildInfoRow(
//                               icon: Icons.calendar_today,
//                               label: 'Member Since',
//                               value: _formatDate(_currentUser?.createdAt),
//                             ),
//                             if (_currentUser?.lastLogin != null) ...[
//                               const Divider(height: 24),
//                               _buildInfoRow(
//                                 icon: Icons.access_time,
//                                 label: 'Last Login',
//                                 value: _formatDate(_currentUser?.lastLogin),
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 32),

//                     // Feature Cards
//                     _buildFeatureCard(
//                       icon: Icons.business,
//                       title: 'Companies',
//                       description: 'Manage your Tally companies',
//                       color: Colors.blue,
//                       onTap: () {
//                         MessageHelper.showInfo(context, 'Companies feature coming soon!');
//                       },
//                     ),
//                     const SizedBox(height: 16),
//                     _buildFeatureCard(
//                       icon: Icons.sync,
//                       title: 'Sync Incremental Data',
//                       description: 'Sync your Tally data',
//                       color: Colors.green,
//                       onTap: () {
                        
//                        _syncIncrementalData();
//                       },
//                     ),
//                     const SizedBox(height: 16),_buildFeatureCard(
//                       icon: Icons.sync,
//                       title: 'Sync Data',
//                       description: 'Sync your Tally data',
//                       color: Colors.green,
//                       onTap: () {
//                        _syncAllData();
//                       },
//                     ),
//                     const SizedBox(height: 16),_buildFeatureCard(
//                       icon: Icons.sync,
//                       title: 'Remove deleted voucher',
//                       description: 'Remove Deleted Voucher',
//                       color: Colors.green,
//                       onTap: () {
//                        _removeDeletedVoucherData();
//                       },
//                     ),
//                     const SizedBox(height: 16),
//                     _buildFeatureCard(
//                       icon: Icons.analytics,
//                       title: 'Reports',
//                       description: 'View analytics and reports',
//                       color: Colors.purple,
//                       onTap: () {
                        
//                         MessageHelper.showInfo(context, 'Reports feature coming soon!');
//                       },
//                     ),
//                     const SizedBox(height: 32),

//                     // Info Text
//                     Text(
//                       'Your companies will appear here once you sync from Windows app',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.grey.shade600,
//                         fontStyle: FontStyle.italic,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow({
//     required IconData icon,
//     required String label,
//     required String value,
//     Color? valueColor,
//   }) {
//     return Row(
//       children: [
//         Icon(icon, size: 20, color: Colors.grey.shade600),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey.shade600,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 value,
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: valueColor ?? Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildFeatureCard({
//     required IconData icon,
//     required String title,
//     required String description,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Icon(icon, color: color, size: 28),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       description,
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey.shade600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Icon(
//                 Icons.arrow_forward_ios,
//                 size: 16,
//                 color: Colors.grey.shade400,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   String _formatDate(DateTime? date) {
//     if (date == null) return 'N/A';
//     return '${date.day}/${date.month}/${date.year}';
//   }
// }

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/secure_storage.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../auth/email_verification_screen.dart';
import 'dart:convert';
import '../../utils/message_helper.dart';
import '../../services/sync_service.dart';
import '../../widgets/onboarding_guide_dialog.dart';
import './ai_queries_screen.dart';
import '../theme/app_theme.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  User? _currentUser;
  bool _isLoading = true;
  final SyncService _syncService = SyncService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Design Tokens ──────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF1A6FD8);
  static const Color _accent    = Color(0xFF00C9A7);
  static const Color _danger    = Color(0xFFE53935);
  static const Color _warning   = Color(0xFFFFA000);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadUser();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    final userData = await SecureStorage.getUser();
    if (userData != null) {
      setState(() {
        _currentUser = User.fromJson(jsonDecode(userData));
        _isLoading   = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
    _fadeController.forward();
  }

  // ── Sync Actions ───────────────────────────────────────────────────────────

  Future<void> _syncAllData() async {
    _snack('Syncing all data…', loading: true);
    await _syncService.syncAllData(neonSync: true);
    _snack('All data synced successfully');
  }

  Future<void> _syncIncrementalData() async {
    _snack('Syncing incremental data…', loading: true);
    await _syncService.syncIncrementalData(neonSync: true);
    _snack('Incremental sync complete');
  }

  Future<void> _removeDeletedVoucherData() async {
    _snack('Detecting deleted vouchers…', loading: true);
    await _syncService.detectAndDeleteMissingVouchers();
    _snack('Deleted vouchers removed');
  }
  Future<void> _openAIQueriesScreen() async {
  // Get required data from secure storage
  final companyGuid = await SecureStorage.getSelectedCompanyGuid();
  final token = await SecureStorage.getToken();

  if (!mounted) return;

  if (companyGuid == null || companyGuid.isEmpty) {
    MessageHelper.showError(context, 'Please select a company first from Settings');
    return;
  }

  if (token == null || token.isEmpty) {
    MessageHelper.showError(context, 'Authentication token not found. Please login again.');
    return;
  }

  if (_currentUser == null) {
    MessageHelper.showError(context, 'User data not found. Please login again.');
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AIQueriesScreen(
        companyGuid: companyGuid,
        userId: _currentUser!.userId.toString(),
        token: token,
      ),
    ),
  );
}
  

  void _snack(String msg, {bool loading = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: loading ? _primary : _accent,
        content: Row(children: [
          if (loading)
            const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Text(msg, style: const TextStyle(color: Colors.white)),
        ]),
        duration: Duration(seconds: loading ? 60 : 3),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.logout();
      MessageHelper.showSuccess(context, 'Logged out successfully');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    syncBrightness(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Verification banner
                  if (_currentUser != null && !_currentUser!.isVerified)
                    _buildVerificationBanner(),
                  const SizedBox(height: 12),

                  // Profile card
                  _buildProfileCard(),
                  const SizedBox(height: 28),

                  // Sync controls
                  _buildSectionHeader('Sync Controls'),
                  const SizedBox(height: 14),
                  _buildSyncGrid(),
                  const SizedBox(height: 20),

                  // Setup Guide button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: OutlinedButton.icon(
                      onPressed: () => showOnboardingGuide(context),
                      icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                      label: const Text('Show Setup Guide'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: BorderSide(
                            color: _primary.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                    // AI Queries - New Feature!
                    _buildFeatureCard(
                      icon: Icons.auto_awesome,
                      title: 'ASK ANYTHING TO AI',
                      description: 'Get instant answers about your financial data',
                      color: Colors.teal,
                      onTap: _openAIQueriesScreen,
                    ),
                    const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Companies will appear once you sync from the Windows app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.surface,
      title: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 9),
        Text(
          'Tally Connector',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppColors.textPrimary,
              letterSpacing: -0.3),
        ),
      ]),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Logout'),
            style: TextButton.styleFrom(
              foregroundColor: _danger,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }

  // ── Verification Banner ────────────────────────────────────────────────────

  Widget _buildVerificationBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warning.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: _warning, size: 22),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email Not Verified',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF7A4F00))),
                SizedBox(height: 2),
                Text('Verify your email to unlock all features',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF7A4F00))),
              ]),
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
                fontWeight: FontWeight.w700, fontSize: 13),
          ),
          child: const Text('Verify →'),
        ),
      ]),
    );
  }

  // ── Profile Card ───────────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    final initials =
        (_currentUser?.fullName.trim().isNotEmpty == true)
            ? _currentUser!.fullName
                .trim()
                .split(' ')
                .map((e) => e[0])
                .take(2)
                .join()
                .toUpperCase()
            : 'U';
    final verified = _currentUser?.isVerified == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A6FD8), Color(0xFF0D4DA0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _primary.withOpacity(0.32),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withOpacity(0.5), width: 2),
          ),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1)),
          ),
        ),
        const SizedBox(width: 16),

        // Name / email
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(_currentUser?.fullName ?? 'User',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_currentUser?.email ?? '',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (_currentUser?.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(_currentUser!.phone!,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.62),
                          fontSize: 12)),
                ],
              ]),
        ),

        // Verified badge + dates
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: verified
                  ? _accent.withOpacity(0.25)
                  : _warning.withOpacity(0.28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: verified ? _accent : _warning, width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  verified
                      ? Icons.verified_rounded
                      : Icons.warning_rounded,
                  size: 12,
                  color: verified ? _accent : _warning),
              const SizedBox(width: 4),
              Text(verified ? 'Verified' : 'Unverified',
                  style: TextStyle(
                      color: verified ? _accent : _warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 8),
          if (_currentUser?.createdAt != null)
            Text('Since ${_formatDate(_currentUser!.createdAt)}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.52),
                    fontSize: 10)),
          if (_currentUser?.lastLogin != null) ...[
            const SizedBox(height: 2),
            Text('Login ${_formatDate(_currentUser!.lastLogin)}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 10)),
          ],
        ]),
      ]),
    );
  }

  // ── Section Header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _accent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2)),
      ]),
    );
  }

  // ── Sync Grid ──────────────────────────────────────────────────────────────

  Widget _buildSyncGrid() {
    final items = [
      _SyncCard(
          icon: Icons.sync_rounded,
          label: 'Full Sync',
          sublabel: 'All data',
          color: _accent,
          onTap: _syncAllData),
      _SyncCard(
          icon: Icons.update_rounded,
          label: 'Incremental',
          sublabel: 'New changes only',
          color: _primary,
          onTap: _syncIncrementalData),
      _SyncCard(
          icon: Icons.delete_sweep_rounded,
          label: 'Clean Up',
          sublabel: 'Remove deleted',
          color: _danger,
          onTap: _removeDeletedVoucherData),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items
            .map<Widget>((c) => Expanded(child: _syncCardWidget(c)))
            .expand((w) => [w, const SizedBox(width: 10)])
            .toList()
          ..removeLast(),
      ),
    );
  }


  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _syncCardWidget(_SyncCard c) {
    return GestureDetector(
      onTap: c.onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: c.color.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
          border: Border.all(color: c.color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: c.color.withOpacity(0.12),
                shape: BoxShape.circle),
            child: Icon(c.icon, color: c.color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(c.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(c.sublabel,
              style:
                  TextStyle(fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── Feature Tile ───────────────────────────────────────────────────────────

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
          ),
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
            child: Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textSecondary),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ── Data class ─────────────────────────────────────────────────────────────────

class _SyncCard {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  const _SyncCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });
}