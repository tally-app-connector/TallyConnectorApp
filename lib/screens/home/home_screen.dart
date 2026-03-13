import 'package:flutter/material.dart';
import 'package:tally_connector/screens/desktop/database_viewer_screen.dart';
import 'package:tally_connector/screens/home/analytics_dashboard.dart';
import 'package:tally_connector/screens/mobile/database_overview_screen.dart';
import '../../services/auth_service.dart';
import '../../utils/secure_storage.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../auth/email_verification_screen.dart';
import 'dart:convert';
import '../../utils/message_helper.dart';
import '../desktop/setting_screen.dart';
import '../../services/sync_service.dart';
import '../Analysis/analysis_home_screen.dart';
import '../sync_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? _currentUser;
  bool _isLoading = true;
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userData = await SecureStorage.getUser();
    if (userData != null) {
      setState(() {
        _currentUser = User.fromJson(jsonDecode(userData));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();      
      MessageHelper.showSuccess(context, "Logged out successfully");

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

 Future<void> _openSettingScreen() async {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const DesktopSettingsScreen(),
    ),
  );

  
}
Future<void> _openDatabaseViewerScreen() async {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const DatabaseOverviewScreen(),
    ),
  );
}

Future<void> _openAnalysisScreen() async {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AnalyticsDashboard(),
    ),
  );
}

Future<void> _syncAllData() async {
  await _syncService.syncAllData(neonSync: true);

    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('✅ All data Sync successfully'),
      backgroundColor: Colors.green,
    ),
  );
}

Future<void> _removeDeletedVoucherData() async {
  await _syncService.detectAndDeleteMissingVouchers();

    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('✅ All data Sync successfully'),
      backgroundColor: Colors.green,
    ),
  );
}

Future<void> _syncIncrementalData() async {
  await _syncService.syncIncrementalData(neonSync: true);

    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('✅ All data Sync successfully'),
      backgroundColor: Colors.green,
    ),
  );
}


Future<void> _openHomeAnalysisScreen() async {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AnalysisHomeScreen(),
    ),
  );
}

Future<void> _openSyncServiceScreen() async {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SyncScreen(),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tally Connector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettingScreen,
            tooltip: 'Setting',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openDatabaseViewerScreen,
            tooltip: 'Setting',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openAnalysisScreen,
            tooltip: 'Setting',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openHomeAnalysisScreen,
            tooltip: 'Setting',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSyncServiceScreen,
            tooltip: 'Setting',
          ),

        ],
      ),
      body: Column(
        children: [
          // Verification Banner
          if (_currentUser != null && !_currentUser!.isVerified)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Not Verified',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Please verify your email to access all features',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmailVerificationScreen(
                            email: _currentUser!.email,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade900,
                    ),
                    child: const Text('Verify'),
                  ),
                ],
              ),
            ),

          // Main Content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Profile Picture
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        _currentUser?.fullName[0].toUpperCase() ?? 'U',
                        style: TextStyle(
                          fontSize: 40,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Welcome Message
                    Text(
                      'Welcome, ${_currentUser?.fullName ?? 'User'}!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Email
                    Text(
                      _currentUser?.email ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Phone
                    if (_currentUser?.phone != null)
                      Text(
                        _currentUser!.phone!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Account Info Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.verified_user,
                              label: 'Account Status',
                              value: _currentUser?.isVerified == true
                                  ? 'Verified ✅'
                                  : 'Not Verified ⚠️',
                              valueColor: _currentUser?.isVerified == true
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              icon: Icons.calendar_today,
                              label: 'Member Since',
                              value: _formatDate(_currentUser?.createdAt),
                            ),
                            if (_currentUser?.lastLogin != null) ...[
                              const Divider(height: 24),
                              _buildInfoRow(
                                icon: Icons.access_time,
                                label: 'Last Login',
                                value: _formatDate(_currentUser?.lastLogin),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Feature Cards
                    _buildFeatureCard(
                      icon: Icons.business,
                      title: 'Companies',
                      description: 'Manage your Tally companies',
                      color: Colors.blue,
                      onTap: () {
                        MessageHelper.showInfo(context, 'Companies feature coming soon!');
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      icon: Icons.sync,
                      title: 'Sync Incremental Data',
                      description: 'Sync your Tally data',
                      color: Colors.green,
                      onTap: () {
                        
                       _syncIncrementalData();
                      },
                    ),
                    const SizedBox(height: 16),_buildFeatureCard(
                      icon: Icons.sync,
                      title: 'Sync Data',
                      description: 'Sync your Tally data',
                      color: Colors.green,
                      onTap: () {
                       _syncAllData();
                      },
                    ),
                    const SizedBox(height: 16),_buildFeatureCard(
                      icon: Icons.sync,
                      title: 'Remove deleted voucher',
                      description: 'Remove Deleted Voucher',
                      color: Colors.green,
                      onTap: () {
                       _removeDeletedVoucherData();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      icon: Icons.analytics,
                      title: 'Reports',
                      description: 'View analytics and reports',
                      color: Colors.purple,
                      onTap: () {
                        
                        MessageHelper.showInfo(context, 'Reports feature coming soon!');
                      },
                    ),
                    const SizedBox(height: 32),

                    // Info Text
                    Text(
                      'Your companies will appear here once you sync from Windows app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
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
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}