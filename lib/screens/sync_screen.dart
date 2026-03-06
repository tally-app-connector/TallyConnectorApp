import 'package:flutter/material.dart';
import 'dart:math';
import '../database/database_helper.dart';
import '../services/cloud_to_local_sync_service.dart';
// import '../database/database_helper.dart'; // Your local DB helper

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with TickerProviderStateMixin {
  // Phase: select | syncing | complete | error
  String _phase = 'select';
  String _syncType = 'full'; // full | incremental

  List<CompanyItem> _companies = [];
  bool _loadingCompanies = true;
  String? _loadError;

  // Sync state
  double _syncProgress = 0;
  String _syncStatus = '';
  List<SyncStep> _syncSteps = [];
  int _currentStep = -1;
  SyncResult? _syncResult;
  String _syncTime = '';

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _loadCompanies();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // ============================================
  // LOAD COMPANIES FROM CLOUD
  // ============================================
  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _loadError = null;
    });

    try {
      final companies = await CloudToLocalSyncService.instance.fetchCompaniesFromCloud();
      setState(() {
        _companies = companies.map((c) => CompanyItem(
          guid: c['company_guid'] ?? '',
          name: c['company_name'] ?? '',
          gstin: c['gsttin'] ?? '',
          state: c['state'] ?? '',
          city: c['city'] ?? '',
        )).toList();
        _loadingCompanies = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _loadingCompanies = false;
      });
    }
  }

  // ============================================
  // START SYNC
  // ============================================
  Future<void> _startSync() async {
    final selected = _companies.where((c) => c.selected).toList();
    if (selected.isEmpty) return;

    setState(() {
      _phase = 'syncing';
      _syncProgress = 0;
      _currentStep = -1;
      _syncSteps = _buildSyncSteps();
    });

    final stopwatch = Stopwatch()..start();

    // TODO: Replace with your actual local database instance

    final localDb = await DatabaseHelper.instance.database;

    for (final company in selected) {
      try {
        if (_syncType == 'full') {
          final result = await CloudToLocalSyncService.instance.fullSync(
            localDb,
            company.guid,
            onProgress: (status, progress) {
              setState(() {
                _syncStatus = status;
                _syncProgress = progress;
                _updateStepFromProgress(progress);
              });
            },
          );
          _syncResult = result;

        } else {
          final result = await CloudToLocalSyncService.instance.incrementalSync(
            localDb,
            company.guid,
            onProgress: (status, progress) {
              setState(() {
                _syncStatus = status;
                _syncProgress = progress;
                _updateStepFromProgress(progress);
              });
            },
          );
          _syncResult = result;

        }
      } catch (e) {
        setState(() {
          _phase = 'error';
          _syncStatus = 'Error: $e';
        });
        return;
      }
    }

    stopwatch.stop();
    setState(() {
      _syncTime = '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
      _phase = 'complete';
    });
  }
void _updateStepFromProgress(double progress) {
  final stepIndex = (progress * _syncSteps.length).floor().clamp(0, _syncSteps.length - 1);
  
  for (int i = 0; i < _syncSteps.length; i++) {
    if (i < stepIndex) {
      _syncSteps[i].status = StepStatus.done;
    } else if (i == stepIndex) {
      _syncSteps[i].status = StepStatus.syncing;
      _currentStep = i;
    } else {
      _syncSteps[i].status = StepStatus.pending;
    }
  }
}
  // Demo simulation — remove when integrating real sync
  Future<void> _simulateSync() async {
    final counts = [1, 28, 18, 156, 43, 847, 2341, 1205, 890, 312];
    for (int i = 0; i < _syncSteps.length; i++) {
      setState(() {
        _currentStep = i;
        _syncSteps[i].status = StepStatus.syncing;
        _syncStatus = 'Syncing ${_syncSteps[i].name.toLowerCase()}...';
      });

      await Future.delayed(Duration(milliseconds: 300 + (100 * (i % 3))));

      setState(() {
        _syncSteps[i].status = StepStatus.done;
        _syncSteps[i].count = counts[i];
        _syncProgress = (i + 1) / _syncSteps.length;
      });
    }
    _syncResult = SyncResult()
      ..success = true
      ..companies = 1
      ..groups = 28
      ..voucherTypes = 18
      ..ledgers = 156
      ..stockItems = 43
      ..vouchers = 847
      ..ledgerEntries = 2341
      ..inventoryEntries = 1205
      ..batchAllocations = 890
      ..closingBalances = 312;
  }

  List<SyncStep> _buildSyncSteps() {
    return [
      SyncStep(name: 'Company Info', icon: Icons.business, table: 'companies'),
      SyncStep(name: 'Account Groups', icon: Icons.folder_outlined, table: 'groups'),
      SyncStep(name: 'Voucher Types', icon: Icons.receipt_long_outlined, table: 'voucher_types'),
      SyncStep(name: 'Ledgers', icon: Icons.menu_book_outlined, table: 'ledgers'),
      SyncStep(name: 'Stock Items', icon: Icons.inventory_2_outlined, table: 'stock_items'),
      SyncStep(name: 'Vouchers', icon: Icons.description_outlined, table: 'vouchers'),
      SyncStep(name: 'Ledger Entries', icon: Icons.account_balance_wallet_outlined, table: 'ledger_entries'),
      SyncStep(name: 'Inventory Entries', icon: Icons.bar_chart_outlined, table: 'inventory_entries'),
      SyncStep(name: 'Batch Allocations', icon: Icons.label_outlined, table: 'batch_allocs'),
      SyncStep(name: 'Closing Balances', icon: Icons.trending_up_outlined, table: 'closing_balances'),
    ];
  }

  void _resetSync() {
    setState(() {
      _phase = 'select';
      _syncProgress = 0;
      _syncStatus = '';
      _syncSteps = [];
      _currentStep = -1;
      _syncResult = null;
    });
  }

  int get _selectedCount => _companies.where((c) => c.selected).length;

  void _toggleCompany(int index) {
    setState(() {
      _companies[index].selected = !_companies[index].selected;
    });
  }

  void _selectAll() {
    final allSelected = _companies.every((c) => c.selected);
    setState(() {
      for (var c in _companies) {
        c.selected = !allSelected;
      }
    });
  }

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPhaseContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // HEADER
  // ============================================
  Widget _buildHeader() {
    String title;
    String emoji;
    switch (_phase) {
      case 'syncing':
        title = 'Syncing...';
        emoji = '⚡';
        break;
      case 'complete':
        title = 'All Done!';
        emoji = '✅';
        break;
      case 'error':
        title = 'Sync Failed';
        emoji = '❌';
        break;
      default:
        title = 'Sync Data';
        emoji = '☁️';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TALLY CLOUD SYNC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PHASE ROUTER
  // ============================================
  Widget _buildPhaseContent() {
    switch (_phase) {
      case 'syncing':
        return _buildSyncingPhase();
      case 'complete':
        return _buildCompletePhase();
      case 'error':
        return _buildErrorPhase();
      default:
        return _buildSelectPhase();
    }
  }

  // ============================================
  // PHASE 1: COMPANY SELECTION
  // ============================================
  Widget _buildSelectPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Sync Type Toggle
        _buildSyncTypeToggle(),
        const SizedBox(height: 12),

        // Info Banner
        _buildInfoBanner(),
        const SizedBox(height: 20),

        // Loading / Error / Company List
        if (_loadingCompanies)
          _buildLoadingState()
        else if (_loadError != null)
          _buildErrorState()
        else ...[
          // Company List Header
          _buildCompanyListHeader(),
          const SizedBox(height: 12),

          // Company Cards
          ..._companies.asMap().entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCompanyCard(e.key, e.value),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Sync Button
        _buildSyncButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSyncTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleOption('full', '🔄 Full Sync'),
          _buildToggleOption('incremental', '⚡ Incremental'),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String type, String label) {
    final isActive = _syncType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _syncType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF38BDF8).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    final isFull = _syncType == 'full';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isFull ? const Color(0xFFFBBF24) : const Color(0xFF22C55E)).withOpacity(0.08),
        border: Border.all(
          color: (isFull ? const Color(0xFFFBBF24) : const Color(0xFF22C55E)).withOpacity(0.15),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isFull
            ? '⚠️ Downloads all data fresh. Use for first sync or to fix data issues.'
            : '✨ Only downloads changes since last sync. Much faster for regular updates.',
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: isFull ? const Color(0xFFFBBF24) : const Color(0xFF22C55E),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2.5),
            SizedBox(height: 16),
            Text('Loading companies from cloud...', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text('Failed to load companies', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_loadError ?? '', style: const TextStyle(color: Color(0xFF888888), fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadCompanies,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF38BDF8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'SELECT COMPANIES ($_selectedCount/${_companies.length})',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.5),
        ),
        GestureDetector(
          onTap: _selectAll,
          child: Text(
            _companies.every((c) => c.selected) ? 'Deselect All' : 'Select All',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF38BDF8)),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyCard(int index, CompanyItem company) {
    return GestureDetector(
      onTap: () => _toggleCompany(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: company.selected
              ? const Color(0xFF38BDF8).withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: company.selected
                ? const Color(0xFF38BDF8).withOpacity(0.3)
                : Colors.white.withOpacity(0.06),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: company.selected
                    ? const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8)])
                    : null,
                color: company.selected ? null : Colors.white.withOpacity(0.06),
                border: company.selected ? null : Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
              ),
              child: company.selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Company info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFF0F0F0)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (company.gstin.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA855F7).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            company.gstin,
                            style: const TextStyle(fontSize: 10, color: Color(0xFFA855F7), fontFamily: 'monospace', fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (company.city.isNotEmpty)
                        Text(
                          '📍 ${company.city}, ${company.state}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton() {
    final enabled = _selectedCount > 0;
    return GestureDetector(
      onTap: enabled ? _startSync : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: enabled
              ? const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFA855F7)])
              : null,
          color: enabled ? null : Colors.white.withOpacity(0.06),
          boxShadow: enabled
              ? [BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(
          enabled
              ? 'Sync $_selectedCount ${_selectedCount == 1 ? "Company" : "Companies"}'
              : 'Select companies to sync',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: enabled ? Colors.white : const Color(0xFF444444),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ============================================
  // PHASE 2: SYNCING PROGRESS
  // ============================================
  Widget _buildSyncingPhase() {
    return Column(
      children: [
        const SizedBox(height: 24),

        // Circular progress
        _buildCircularProgress(),
        const SizedBox(height: 20),

        // Status text
        Text(
          _syncStatus,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF38BDF8)),
        ),
        const SizedBox(height: 24),

        // Steps list
        _buildSyncStepsList(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCircularProgress() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CustomPaint(
            size: const Size(160, 160),
            painter: _CircleProgressPainter(
              progress: _syncProgress,
              bgColor: Colors.white.withOpacity(0.05),
              gradientColors: const [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFA855F7)],
              strokeWidth: 8,
            ),
          ),
          // Percentage text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(_syncProgress * 100).round()}',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              const Text(
                'PERCENT',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF666666), letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStepsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _syncSteps.asMap().entries.map((e) {
          final i = e.key;
          final step = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: step.status == StepStatus.syncing
                  ? const Color(0xFF38BDF8).withOpacity(0.05)
                  : Colors.transparent,
              border: i < _syncSteps.length - 1
                  ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04)))
                  : null,
            ),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: step.status == StepStatus.done
                        ? const Color(0xFF22C55E).withOpacity(0.12)
                        : step.status == StepStatus.syncing
                            ? const Color(0xFF38BDF8).withOpacity(0.12)
                            : Colors.white.withOpacity(0.04),
                  ),
                  child: Center(
                    child: step.status == StepStatus.done
                        ? const Icon(Icons.check_circle, size: 16, color: Color(0xFF22C55E))
                        : step.status == StepStatus.syncing
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: const Color(0xFF38BDF8),
                                ),
                              )
                            : Icon(step.icon, size: 15, color: const Color(0xFF555555)),
                  ),
                ),
                const SizedBox(width: 12),

                // Name
                Expanded(
                  child: Text(
                    step.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: step.status == StepStatus.done
                          ? const Color(0xFF22C55E)
                          : step.status == StepStatus.syncing
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF555555),
                    ),
                  ),
                ),

                // Count
                if (step.status == StepStatus.done && step.count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatNumber(step.count),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22C55E),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================
  // PHASE 3: COMPLETE
  // ============================================
  Widget _buildCompletePhase() {
    final total = _syncResult?.totalRecords ?? 0;
    final companyCount = _companies.where((c) => c.selected).length;

    return Column(
      children: [
        const SizedBox(height: 32),

        // Success icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF22C55E).withOpacity(0.15),
                const Color(0xFF22C55E).withOpacity(0.05),
              ],
            ),
            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3), width: 2),
          ),
          child: const Center(
            child: Text('✅', style: TextStyle(fontSize: 44)),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Sync Complete!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'All data has been downloaded to your device',
          style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
        ),
        const SizedBox(height: 28),

        // Stats Grid
        _buildStatsGrid(total, companyCount),
        const SizedBox(height: 20),

        // Breakdown
        _buildBreakdown(),
        const SizedBox(height: 24),

        // Action Buttons
        _buildActionButtons(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatsGrid(int total, int companyCount) {
    final stats = [
      _StatItem('📊', _formatNumber(total), 'Total Records', const Color(0xFF38BDF8)),
      _StatItem('🏢', '$companyCount', 'Companies', const Color(0xFFA855F7)),
      _StatItem('⚡', _syncTime, 'Sync Time', const Color(0xFFFBBF24)),
      _StatItem('✅', 'Success', 'Status', const Color(0xFF22C55E)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: stats.map((stat) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(stat.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              stat.value,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: stat.color, fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF666666), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildBreakdown() {
    final doneSteps = _syncSteps.where((s) => s.count > 0).toList();
    if (doneSteps.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: const Text(
              'SYNC BREAKDOWN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 1),
            ),
          ),
          ...doneSteps.map((step) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(step.icon, size: 14, color: const Color(0xFFAAAAAA)),
                    const SizedBox(width: 8),
                    Text(step.name, style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                  ],
                ),
                Text(
                  _formatNumber(step.count),
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF22C55E), fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _resetSync,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Sync Again',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFAAAAAA)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () {
              // Navigate to dashboard
              // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8)]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: const Text(
                'Open Dashboard →',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // ERROR PHASE
  // ============================================
  Widget _buildErrorPhase() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4444).withOpacity(0.1),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3), width: 2),
            ),
            child: const Center(child: Text('❌', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 20),
          const Text('Sync Failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text(_syncStatus, style: const TextStyle(fontSize: 13, color: Color(0xFF888888)), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _resetSync,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8)]),
              ),
              child: const Text('Try Again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ============================================
// CIRCULAR PROGRESS PAINTER
// ============================================
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final List<Color> gradientColors;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.bgColor,
    required this.gradientColors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = bgColor,
    );

    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: gradientColors,
      );

      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = gradient.createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter old) =>
      old.progress != progress;
}

// ============================================
// DATA MODELS
// ============================================
class CompanyItem {
  final String guid;
  final String name;
  final String gstin;
  final String state;
  final String city;
  bool selected;

  CompanyItem({
    required this.guid,
    required this.name,
    this.gstin = '',
    this.state = '',
    this.city = '',
    this.selected = false,
  });
}

enum StepStatus { pending, syncing, done }

class SyncStep {
  final String name;
  final IconData icon;
  final String table;
  StepStatus status;
  int count;

  SyncStep({
    required this.name,
    required this.icon,
    required this.table,
    this.status = StepStatus.pending,
    this.count = 0,
  });
}

class _StatItem {
  final String icon;
  final String value;
  final String label;
  final Color color;

  _StatItem(this.icon, this.value, this.label, this.color);
}