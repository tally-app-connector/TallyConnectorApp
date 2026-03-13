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

class MobileProfileTab extends StatefulWidget {
  const MobileProfileTab({Key? key}) : super(key: key);

  @override
  State<MobileProfileTab> createState() => _MobileProfileTabState();
}

class _MobileProfileTabState extends State<MobileProfileTab> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  User? _currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _companies = [];
  Map<String, dynamic>? _selectedCompany;
  String _selectedCompanyID = '';
  bool _deletingData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userData = await SecureStorage.getUser();
    _selectedCompanyID = await SecureStorage.getSelectedCompanyGuid() ?? '';
    if (userData != null) {
      _currentUser = User.fromJson(jsonDecode(userData));
    }
    await _loadCompanies();
    setState(() => _isLoading = false);
  }

  Future<void> _loadCompanies() async {
    final companies = await _db.getAllCompanies();
    final selectedGuid = await SecureStorage.getSelectedCompanyGuid() ?? '';

    Map<String, dynamic>? selected;
    if (selectedGuid.isNotEmpty) {
      selected = companies.firstWhere(
        (c) => c['company_guid'] == selectedGuid,
        orElse: () => companies.isNotEmpty ? companies.first : {},
      );
      if (selected.isEmpty) selected = null;
    } else if (companies.isNotEmpty) {
      selected = companies.first;
    }

    setState(() {
      _companies = companies;
      _selectedCompany = selected;
    });
  }

  Future<void> _selectCompany(Map<String, dynamic> company) async {
    await SecureStorage.saveCompanyGuid(company['company_guid']);
    setState(() => _selectedCompany = company);
    if (mounted) {
      MessageHelper.showSuccess(context, 'Selected: ${company['company_name']}');
    }
  }


  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Clear All Data?'),
          ],
        ),
        content: const Text(
          'This will delete ALL data from the local database of current company'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All data cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _deletingData = false);
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      _currentUser?.fullName[0].toUpperCase() ?? 'U',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUser?.fullName ?? 'User',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.email ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (_currentUser?.phone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _currentUser!.phone!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _currentUser?.isVerified == true
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentUser?.isVerified == true ? 'Verified' : 'Not Verified',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _currentUser?.isVerified == true ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Account info
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.calendar_today,
                    title: 'Member Since',
                    value: _formatDate(_currentUser?.createdAt),
                  ),
                  if (_currentUser?.lastLogin != null)
                    _buildInfoTile(
                      icon: Icons.access_time,
                      title: 'Last Login',
                      value: _formatDate(_currentUser?.lastLogin),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Company selection
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Active Company',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_companies.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No companies available. Sync data to load companies.',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedCompany?['company_guid'],
                            items: _companies.map((company) {
                              return DropdownMenuItem<String>(
                                value: company['company_guid'],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      company['company_name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    if (company['company_address'] != null &&
                                        company['company_address'].toString().isNotEmpty)
                                      Text(
                                        company['company_address'],
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (guid) {
                              final company = _companies.firstWhere(
                                (c) => c['company_guid'] == guid,
                              );
                              _selectCompany(company);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_currentUser != null && !_currentUser!.isVerified)
                    _buildActionTile(
                      icon: Icons.verified_user,
                      title: 'Verify Email',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmailVerificationScreen(
                              email: _currentUser!.email,
                            ),
                          ),
                        );
                      },
                    ),
                  _buildActionTile(
                    icon: Icons.sync,
                    title: 'Sync Data',
                    color: Colors.blue,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SyncScreen()),
                      );
                      _loadCompanies();
                    },
                  ),
                   _buildActionTile(
                    icon: Icons.sync,
                    title: 'Database Overview',
                    color: Colors.blue,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DatabaseOverviewScreen()),
                      );
                      _loadCompanies();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    color: Colors.red,
                    onTap: _handleLogout,
                  ),
                   _buildActionTile(
                    icon: Icons.logout,
                    title: 'Delete All Data',
                    color: Colors.red,
                    onTap: _clearAllData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
