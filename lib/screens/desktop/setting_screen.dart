import 'package:flutter/material.dart';
import 'package:tally_connector/services/sync_service.dart';
import '../../database/database_helper.dart';
import '../../utils/secure_storage.dart';

class DesktopSettingsScreen extends StatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SyncService _syncService = SyncService();

  List<Map<String, dynamic>> _companies = [];
  Map<String, dynamic>? _selectedCompany;
  String _selectedCompanyID = '';
  bool _loading = true;
  bool _deletingData = false;
  bool _fetchingData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      // Load all companies
      final companies = await _db.getAllCompanies();

      // Load selected company from preferences
      _selectedCompanyID = await SecureStorage.getSelectedCompanyGuid() ?? '';

      Map<String, dynamic>? selectedCompany;
      if (_selectedCompanyID.isNotEmpty) {
        selectedCompany = companies.firstWhere(
          (c) => c['company_guid'] == _selectedCompanyID,
          orElse: () => companies.isNotEmpty ? companies.first : {},
        );
      } else if (companies.isNotEmpty) {
        selectedCompany = companies.first;
      }

      setState(() {
        _companies = companies;
        _selectedCompany = selectedCompany;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectCompany(Map<String, dynamic> company) async {
    try {
      await SecureStorage.saveCompanyGuid(company['company_guid']);

      setState(() => _selectedCompany = company);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Selected: ${company['company_name']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchAllComapanies() async {
    _fetchingData = true;
    await _syncService.syncCompany(neonSync:true);
    await _loadData();
    _fetchingData = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Selection Section
                  _buildSectionHeader('🏢 Company Selection', Colors.blue),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Company',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_companies.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No companies available. Please sync from Tally.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            company['company_name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (company['company_address'] != null &&
                                              company['company_address']
                                                  .toString()
                                                  .isNotEmpty)
                                            Text(
                                              company['company_address'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
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
                          if (_selectedCompany != null && _selectedCompany?['company_guid'] != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                    'GUID',
                                    _selectedCompany?['company_guid'],
                                  ),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(
                                    'Last Sync',
                                    _formatDate(_selectedCompany?['last_sync_timestamp']),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(
                                    'Alter ID',
                                    '${_selectedCompany?['last_synced_alter_id'] ?? 0}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                          ListTile(
                            leading: _fetchingData
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_forever,
                                    color: Colors.red),
                            title: const Text(
                              'Fetch All Companies',
                              style: TextStyle(color: Colors.red),
                            ),
                            subtitle:
                                const Text('Delete all local database data'),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.red),
                            onTap: _deletingData ? null : _fetchAllComapanies,
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Danger Zone Section
                  _buildSectionHeader('⚠️ Danger Zone', Colors.red),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    color: Colors.red.shade50,
                    child: Column(
                      children: [
                        ListTile(
                          leading: _deletingData
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_forever,
                                  color: Colors.red),
                          title: const Text(
                            'Clear Local Data',
                            style: TextStyle(color: Colors.red),
                          ),
                          subtitle:
                              const Text('Delete all local database data'),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.red),
                          onTap: _deletingData ? null : _clearAllData,
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(Icons.cloud_off, color: Colors.red),
                          title: Text(
                            'Clear Neon Data',
                            style: TextStyle(color: Colors.red),
                          ),
                          subtitle: Text('Delete all cloud database data'),
                          trailing:
                              Icon(Icons.chevron_right, color: Colors.red),
                          // onTap: _clearNeonData,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // About Section
                  _buildSectionHeader('ℹ️ About', Colors.grey),
                  const SizedBox(height: 12),
                  const Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.info, color: Colors.grey),
                          title: Text('Version'),
                          subtitle: Text('1.0.0'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.code, color: Colors.grey),
                          title: Text('Built with'),
                          subtitle: Text(
                              'Flutter ${String.fromEnvironment('FLUTTER_VERSION', defaultValue: '3.x')}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          color: color,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Never';

    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
