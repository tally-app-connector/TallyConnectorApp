// import 'package:flutter/material.dart';
// import 'dart:math';
// import 'dart:convert';
// import '../database/database_helper.dart';
// import '../services/cloud_to_local_sync_service.dart';
// import '../utils/secure_storage.dart';
// import '../models/user_model.dart';

// // ============================================
// // LIGHT MODE COLOR PALETTE
// // ============================================
// class _Colors {
//   static const background     = Color(0xFFF5F7FA);
//   static const surface        = Color(0xFFFFFFFF);
//   static const surfaceElevated= Color(0xFFF0F4FF);
//   static const border         = Color(0xFFE2E8F0);
//   static const borderAccent   = Color(0xFFBFD0F0);

//   static const primary        = Color(0xFF2563EB);
//   static const primaryLight   = Color(0xFFEFF6FF);
//   static const primaryMid     = Color(0xFFBFDBFE);
//   static const accent         = Color(0xFF7C3AED);
//   static const accentLight    = Color(0xFFF5F3FF);

//   static const success        = Color(0xFF16A34A);
//   static const successLight   = Color(0xFFF0FDF4);
//   static const successMid     = Color(0xFFBBF7D0);

//   static const warning        = Color(0xFFD97706);
//   static const warningLight   = Color(0xFFFFFBEB);

//   static const error          = Color(0xFFDC2626);
//   static const errorLight     = Color(0xFFFEF2F2);

//   static const textPrimary    = Color(0xFF0F172A);
//   static const textSecondary  = Color(0xFF475569);
//   static const textMuted      = Color(0xFF94A3B8);
//   static const textDisabled   = Color(0xFFCBD5E1);
// }

// class SyncScreen extends StatefulWidget {
//   const SyncScreen({super.key});

//   @override
//   State<SyncScreen> createState() => _SyncScreenState();
// }

// class _SyncScreenState extends State<SyncScreen> with TickerProviderStateMixin {
//   String _phase = 'select';
//   String _syncType = 'full';

//   List<CompanyItem> _companies = [];
//   bool _loadingCompanies = true;
//   String? _loadError;

//   double _syncProgress = 0;
//   String _syncStatus = '';
//   List<SyncStep> _syncSteps = [];
//   int _currentStep = -1;
//   SyncResult? _syncResult;
//   String _syncTime = '';

//   late AnimationController _pulseController;
//   late AnimationController _progressController;

//   @override
//   void initState() {
//     super.initState();
//     _pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1500),
//     )..repeat(reverse: true);
//     _progressController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 300),
//     );
//     _loadCompanies();
//   }

//   @override
//   void dispose() {
//     _pulseController.dispose();
//     _progressController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadCompanies() async {
//     setState(() { _loadingCompanies = true; _loadError = null; });
//     try {
//       String? userId;
//       final userData = await SecureStorage.getUser();
//       if (userData != null) {
//         final user = User.fromJson(jsonDecode(userData));
//         userId = user.email;
//       }
//       final companies = await CloudToLocalSyncService.instance.fetchCompaniesFromCloud(userId: userId);
//       setState(() {
//         _companies = companies.map((c) => CompanyItem(
//           guid: c['company_guid'] ?? '',
//           name: c['company_name'] ?? '',
//           gstin: c['gsttin'] ?? '',
//           state: c['state'] ?? '',
//           city: c['city'] ?? '',
//         )).toList();
//         _loadingCompanies = false;
//       });
//     } catch (e) {
//       setState(() { _loadError = e.toString(); _loadingCompanies = false; });
//     }
//   }

//   Future<void> _startSync() async {
//     final selected = _companies.where((c) => c.selected).toList();
//     if (selected.isEmpty) return;
//     setState(() {
//       _phase = 'syncing';
//       _syncProgress = 0;
//       _currentStep = -1;
//       _syncSteps = _buildSyncSteps();
//     });
//     final stopwatch = Stopwatch()..start();
//     final localDb = await DatabaseHelper.instance.database;
//     for (final company in selected) {
//       try {
//         if (_syncType == 'full') {
//           final result = await CloudToLocalSyncService.instance.fullSync(
//             localDb, company.guid,
//             onProgress: (status, progress) {
//               setState(() { _syncStatus = status; _syncProgress = progress; _updateStepFromProgress(progress); });
//             },
//           );
//           _syncResult = result;
//         } else {
//           final result = await CloudToLocalSyncService.instance.incrementalSync(
//             localDb, company.guid,
//             onProgress: (status, progress) {
//               setState(() { _syncStatus = status; _syncProgress = progress; _updateStepFromProgress(progress); });
//             },
//           );
//           _syncResult = result;
//         }
//       } catch (e) {
//         setState(() { _phase = 'error'; _syncStatus = 'Error: $e'; });
//         return;
//       }
//     }
//     stopwatch.stop();
//     final currentGuid = await SecureStorage.getSelectedCompanyGuid();
//     if ((currentGuid == null || currentGuid.isEmpty) && selected.isNotEmpty) {
//       await SecureStorage.saveCompanyGuid(selected.first.guid);
//     }
//     setState(() {
//       _syncTime = '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
//       _phase = 'complete';
//     });
//   }

//   void _updateStepFromProgress(double progress) {
//     final stepIndex = (progress * _syncSteps.length).floor().clamp(0, _syncSteps.length - 1);
//     for (int i = 0; i < _syncSteps.length; i++) {
//       if (i < stepIndex) {
//         _syncSteps[i].status = StepStatus.done;
//       } else if (i == stepIndex) {
//         _syncSteps[i].status = StepStatus.syncing;
//         _currentStep = i;
//       } else {
//         _syncSteps[i].status = StepStatus.pending;
//       }
//     }
//   }

//   List<SyncStep> _buildSyncSteps() {
//     return [
//       SyncStep(name: 'Company Info',       icon: Icons.business_outlined,                  table: 'companies'),
//       SyncStep(name: 'Account Groups',     icon: Icons.folder_outlined,                    table: 'groups'),
//       SyncStep(name: 'Voucher Types',      icon: Icons.receipt_long_outlined,              table: 'voucher_types'),
//       SyncStep(name: 'Ledgers',            icon: Icons.menu_book_outlined,                 table: 'ledgers'),
//       SyncStep(name: 'Stock Items',        icon: Icons.inventory_2_outlined,               table: 'stock_items'),
//       SyncStep(name: 'Vouchers',           icon: Icons.description_outlined,               table: 'vouchers'),
//       SyncStep(name: 'Ledger Entries',     icon: Icons.account_balance_wallet_outlined,    table: 'ledger_entries'),
//       SyncStep(name: 'Inventory Entries',  icon: Icons.bar_chart_outlined,                 table: 'inventory_entries'),
//       SyncStep(name: 'Batch Allocations',  icon: Icons.label_outlined,                     table: 'batch_allocs'),
//       SyncStep(name: 'Closing Balances',   icon: Icons.trending_up_outlined,               table: 'closing_balances'),
//     ];
//   }

//   void _resetSync() {
//     setState(() {
//       _phase = 'select';
//       _syncProgress = 0;
//       _syncStatus = '';
//       _syncSteps = [];
//       _currentStep = -1;
//       _syncResult = null;
//     });
//   }

//   int get _selectedCount => _companies.where((c) => c.selected).length;

//   void _toggleCompany(int index) {
//     setState(() { _companies[index].selected = !_companies[index].selected; });
//   }

//   void _selectAll() {
//     final allSelected = _companies.every((c) => c.selected);
//     setState(() { for (var c in _companies) { c.selected = !allSelected; } });
//   }

//   // ============================================
//   // BUILD
//   // ============================================
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _Colors.background,
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildHeader(),
//             Expanded(
//               child: SingleChildScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 child: _buildPhaseContent(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ============================================
//   // HEADER
//   // ============================================
//   Widget _buildHeader() {
//     String title;
//     Color titleColor;
//     switch (_phase) {
//       case 'syncing':  title = 'Syncing Data'; titleColor = _Colors.primary;        break;
//       case 'complete': title = 'All Done!';    titleColor = _Colors.success;        break;
//       case 'error':    title = 'Sync Failed';  titleColor = _Colors.error;          break;
//       default:         title = 'Sync Data';    titleColor = _Colors.textPrimary;    break;
//     }

//     return Container(
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
//       decoration: BoxDecoration(
//         color: _Colors.surface,
//         border: Border(bottom: BorderSide(color: _Colors.border, width: 1)),
//         boxShadow: [
//           BoxShadow(
//             color: _Colors.primary.withOpacity(0.04),
//             blurRadius: 12,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Back button
//           GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: Container(
//               width: 40,
//               height: 40,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(10),
//                 color: _Colors.background,
//                 border: Border.all(color: _Colors.border),
//               ),
//               child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _Colors.textSecondary),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'TALLY CLOUD SYNC',
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w700,
//                     letterSpacing: 2,
//                     color: _Colors.primary,
//                   ),
//                 ),
//                 const SizedBox(height: 3),
//                 Text(
//                   title,
//                   style: TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.w700,
//                     color: titleColor,
//                     letterSpacing: -0.3,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Logo badge
//           Container(
//             width: 44,
//             height: 44,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12),
//               gradient: LinearGradient(
//                 colors: [_Colors.primary, _Colors.accent],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               boxShadow: [
//                 BoxShadow(color: _Colors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
//               ],
//             ),
//             child: const Center(
//               child: Icon(Icons.cloud_sync_outlined, size: 22, color: Colors.white),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ============================================
//   // PHASE ROUTER
//   // ============================================
//   Widget _buildPhaseContent() {
//     switch (_phase) {
//       case 'syncing':  return _buildSyncingPhase();
//       case 'complete': return _buildCompletePhase();
//       case 'error':    return _buildErrorPhase();
//       default:         return _buildSelectPhase();
//     }
//   }

//   // ============================================
//   // PHASE 1: COMPANY SELECTION
//   // ============================================
//   Widget _buildSelectPhase() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 20),
//         _buildSyncTypeToggle(),
//         const SizedBox(height: 12),
//         _buildInfoBanner(),
//         const SizedBox(height: 24),
//         if (_loadingCompanies)
//           _buildLoadingState()
//         else if (_loadError != null)
//           _buildErrorState()
//         else ...[
//           _buildCompanyListHeader(),
//           const SizedBox(height: 10),
//           ..._companies.asMap().entries.map((e) =>
//             Padding(
//               padding: const EdgeInsets.only(bottom: 10),
//               child: _buildCompanyCard(e.key, e.value),
//             ),
//           ),
//         ],
//         const SizedBox(height: 24),
//         _buildSyncButton(),
//         const SizedBox(height: 32),
//       ],
//     );
//   }

//   Widget _buildSyncTypeToggle() {
//     return Container(
//       padding: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: _Colors.background,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _Colors.border),
//       ),
//       child: Row(
//         children: [
//           _buildToggleOption('full', Icons.sync_rounded, 'Full Sync'),
//           _buildToggleOption('incremental', Icons.bolt_rounded, 'Incremental'),
//         ],
//       ),
//     );
//   }

//   Widget _buildToggleOption(String type, IconData icon, String label) {
//     final isActive = _syncType == type;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => setState(() => _syncType = type),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           padding: const EdgeInsets.symmetric(vertical: 10),
//           decoration: BoxDecoration(
//             color: isActive ? _Colors.surface : Colors.transparent,
//             borderRadius: BorderRadius.circular(9),
//             boxShadow: isActive
//                 ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]
//                 : null,
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 15, color: isActive ? _Colors.primary : _Colors.textMuted),
//               const SizedBox(width: 6),
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
//                   color: isActive ? _Colors.primary : _Colors.textMuted,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoBanner() {
//     final isFull = _syncType == 'full';
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//       decoration: BoxDecoration(
//         color: isFull ? _Colors.warningLight : _Colors.successLight,
//         border: Border.all(
//           color: isFull
//               ? _Colors.warning.withOpacity(0.25)
//               : _Colors.success.withOpacity(0.25),
//         ),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(
//             isFull ? Icons.info_outline_rounded : Icons.flash_on_rounded,
//             size: 16,
//             color: isFull ? _Colors.warning : _Colors.success,
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               isFull
//                   ? 'Downloads all data fresh. Use for first sync or to fix data issues.'
//                   : 'Only downloads changes since last sync. Much faster for regular updates.',
//               style: TextStyle(
//                 fontSize: 12,
//                 height: 1.5,
//                 color: isFull ? _Colors.warning : _Colors.success,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingState() {
//     return const Padding(
//       padding: EdgeInsets.symmetric(vertical: 60),
//       child: Center(
//         child: Column(
//           children: [
//             CircularProgressIndicator(color: _Colors.primary, strokeWidth: 2.5),
//             SizedBox(height: 16),
//             Text(
//               'Loading companies from cloud...',
//               style: TextStyle(color: _Colors.textMuted, fontSize: 13),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorState() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 40),
//       child: Center(
//         child: Column(
//           children: [
//             Container(
//               width: 64,
//               height: 64,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: _Colors.errorLight,
//                 border: Border.all(color: _Colors.error.withOpacity(0.2)),
//               ),
//               child: const Icon(Icons.cloud_off_outlined, size: 28, color: _Colors.error),
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Failed to load companies',
//               style: TextStyle(color: _Colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               _loadError ?? '',
//               style: const TextStyle(color: _Colors.textMuted, fontSize: 12),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 20),
//             TextButton.icon(
//               onPressed: _loadCompanies,
//               icon: const Icon(Icons.refresh_rounded, size: 16),
//               label: const Text('Retry'),
//               style: TextButton.styleFrom(
//                 foregroundColor: _Colors.primary,
//                 backgroundColor: _Colors.primaryLight,
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCompanyListHeader() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Row(
//           children: [
//             const Text(
//               'COMPANIES',
//               style: TextStyle(
//                 fontSize: 11,
//                 fontWeight: FontWeight.w700,
//                 color: _Colors.textMuted,
//                 letterSpacing: 1,
//               ),
//             ),
//             const SizedBox(width: 8),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//               decoration: BoxDecoration(
//                 color: _Colors.primary.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(
//                 '$_selectedCount/${_companies.length}',
//                 style: const TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w700,
//                   color: _Colors.primary,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         GestureDetector(
//           onTap: _selectAll,
//           child: Text(
//             _companies.every((c) => c.selected) ? 'Deselect All' : 'Select All',
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: _Colors.primary,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildCompanyCard(int index, CompanyItem company) {
//     return GestureDetector(
//       onTap: () => _toggleCompany(index),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: company.selected ? _Colors.primaryLight : _Colors.surface,
//           border: Border.all(
//             color: company.selected ? _Colors.primary.withOpacity(0.4) : _Colors.border,
//             width: company.selected ? 1.5 : 1,
//           ),
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: [
//             BoxShadow(
//               color: company.selected
//                   ? _Colors.primary.withOpacity(0.08)
//                   : Colors.black.withOpacity(0.03),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Checkbox
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 200),
//               width: 22,
//               height: 22,
//               margin: const EdgeInsets.only(top: 2),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(6),
//                 gradient: company.selected
//                     ? LinearGradient(colors: [_Colors.primary, _Colors.accent])
//                     : null,
//                 color: company.selected ? null : _Colors.background,
//                 border: company.selected
//                     ? null
//                     : Border.all(color: _Colors.border, width: 1.5),
//                 boxShadow: company.selected
//                     ? [BoxShadow(color: _Colors.primary.withOpacity(0.3), blurRadius: 6)]
//                     : null,
//               ),
//               child: company.selected
//                   ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
//                   : null,
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     company.name,
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                       color: company.selected ? _Colors.primary : _Colors.textPrimary,
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Wrap(
//                     spacing: 6,
//                     runSpacing: 4,
//                     children: [
//                       if (company.gstin.isNotEmpty)
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: _Colors.accentLight,
//                             borderRadius: BorderRadius.circular(5),
//                             border: Border.all(color: _Colors.accent.withOpacity(0.2)),
//                           ),
//                           child: Text(
//                             company.gstin,
//                             style: const TextStyle(
//                               fontSize: 10,
//                               color: _Colors.accent,
//                               fontFamily: 'monospace',
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       if (company.city.isNotEmpty)
//                         Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             const Icon(Icons.location_on_outlined, size: 11, color: _Colors.textMuted),
//                             const SizedBox(width: 2),
//                             Text(
//                               '${company.city}, ${company.state}',
//                               style: const TextStyle(fontSize: 11, color: _Colors.textMuted),
//                             ),
//                           ],
//                         ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSyncButton() {
//     final enabled = _selectedCount > 0;
//     return GestureDetector(
//       onTap: enabled ? _startSync : null,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 16),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(14),
//           gradient: enabled
//               ? LinearGradient(
//                   colors: [_Colors.primary, _Colors.accent],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 )
//               : null,
//           color: enabled ? null : _Colors.border,
//           boxShadow: enabled
//               ? [BoxShadow(color: _Colors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))]
//               : null,
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.cloud_sync_rounded,
//               size: 18,
//               color: enabled ? Colors.white : _Colors.textMuted,
//             ),
//             const SizedBox(width: 8),
//             Text(
//               enabled
//                   ? 'Sync $_selectedCount ${_selectedCount == 1 ? "Company" : "Companies"}'
//                   : 'Select companies to sync',
//               style: TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w700,
//                 color: enabled ? Colors.white : _Colors.textMuted,
//                 letterSpacing: 0.2,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ============================================
//   // PHASE 2: SYNCING PROGRESS
//   // ============================================
//   Widget _buildSyncingPhase() {
//     return Column(
//       children: [
//         const SizedBox(height: 28),
//         _buildCircularProgress(),
//         const SizedBox(height: 20),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//           decoration: BoxDecoration(
//             color: _Colors.primaryLight,
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Text(
//             _syncStatus,
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//               color: _Colors.primary,
//             ),
//           ),
//         ),
//         const SizedBox(height: 24),
//         _buildSyncStepsList(),
//         const SizedBox(height: 32),
//       ],
//     );
//   }

//   Widget _buildCircularProgress() {
//     return SizedBox(
//       width: 160,
//       height: 160,
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           CustomPaint(
//             size: const Size(160, 160),
//             painter: _CircleProgressPainter(
//               progress: _syncProgress,
//               bgColor: _Colors.border,
//               gradientColors: [_Colors.primary, _Colors.accent],
//               strokeWidth: 10,
//             ),
//           ),
//           Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 '${(_syncProgress * 100).round()}',
//                 style: const TextStyle(
//                   fontSize: 40,
//                   fontWeight: FontWeight.w800,
//                   color: _Colors.textPrimary,
//                   fontFamily: 'monospace',
//                 ),
//               ),
//               const Text(
//                 'PERCENT',
//                 style: TextStyle(
//                   fontSize: 9,
//                   fontWeight: FontWeight.w700,
//                   color: _Colors.textMuted,
//                   letterSpacing: 1.5,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSyncStepsList() {
//     return Container(
//       decoration: BoxDecoration(
//         color: _Colors.surface,
//         border: Border.all(color: _Colors.border),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
//         ],
//       ),
//       child: Column(
//         children: _syncSteps.asMap().entries.map((e) {
//           final i = e.key;
//           final step = e.value;
//           return Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             decoration: BoxDecoration(
//               color: step.status == StepStatus.syncing
//                   ? _Colors.primaryLight
//                   : Colors.transparent,
//               border: i < _syncSteps.length - 1
//                   ? Border(bottom: BorderSide(color: _Colors.border))
//                   : null,
//               borderRadius: BorderRadius.only(
//                 topLeft:    i == 0                          ? const Radius.circular(16) : Radius.zero,
//                 topRight:   i == 0                          ? const Radius.circular(16) : Radius.zero,
//                 bottomLeft: i == _syncSteps.length - 1     ? const Radius.circular(16) : Radius.zero,
//                 bottomRight:i == _syncSteps.length - 1     ? const Radius.circular(16) : Radius.zero,
//               ),
//             ),
//             child: Row(
//               children: [
//                 // Status icon
//                 Container(
//                   width: 32,
//                   height: 32,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(8),
//                     color: step.status == StepStatus.done
//                         ? _Colors.successLight
//                         : step.status == StepStatus.syncing
//                             ? _Colors.primaryLight
//                             : _Colors.background,
//                     border: Border.all(
//                       color: step.status == StepStatus.done
//                           ? _Colors.success.withOpacity(0.3)
//                           : step.status == StepStatus.syncing
//                               ? _Colors.primary.withOpacity(0.3)
//                               : _Colors.border,
//                     ),
//                   ),
//                   child: Center(
//                     child: step.status == StepStatus.done
//                         ? const Icon(Icons.check_rounded, size: 16, color: _Colors.success)
//                         : step.status == StepStatus.syncing
//                             ? SizedBox(
//                                 width: 14,
//                                 height: 14,
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                   color: _Colors.primary,
//                                 ),
//                               )
//                             : Icon(step.icon, size: 15, color: _Colors.textDisabled),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     step.name,
//                     style: TextStyle(
//                       fontSize: 13,
//                       fontWeight: step.status == StepStatus.syncing ? FontWeight.w600 : FontWeight.w500,
//                       color: step.status == StepStatus.done
//                           ? _Colors.success
//                           : step.status == StepStatus.syncing
//                               ? _Colors.primary
//                               : _Colors.textMuted,
//                     ),
//                   ),
//                 ),
//                 if (step.status == StepStatus.done && step.count > 0)
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                     decoration: BoxDecoration(
//                       color: _Colors.successLight,
//                       borderRadius: BorderRadius.circular(6),
//                       border: Border.all(color: _Colors.success.withOpacity(0.2)),
//                     ),
//                     child: Text(
//                       _formatNumber(step.count),
//                       style: const TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w700,
//                         color: _Colors.success,
//                         fontFamily: 'monospace',
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   // ============================================
//   // PHASE 3: COMPLETE
//   // ============================================
//   Widget _buildCompletePhase() {
//     final total = _syncResult?.totalRecords ?? 0;
//     final companyCount = _companies.where((c) => c.selected).length;
//     return Column(
//       children: [
//         const SizedBox(height: 32),
//         // Success icon
//         Container(
//           width: 96,
//           height: 96,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: _Colors.successLight,
//             border: Border.all(color: _Colors.success.withOpacity(0.3), width: 2),
//             boxShadow: [
//               BoxShadow(color: _Colors.success.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 4)),
//             ],
//           ),
//           child: const Icon(Icons.cloud_done_rounded, size: 42, color: _Colors.success),
//         ),
//         const SizedBox(height: 20),
//         const Text(
//           'Sync Complete!',
//           style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _Colors.textPrimary),
//         ),
//         const SizedBox(height: 6),
//         const Text(
//           'All data has been downloaded to your device',
//           style: TextStyle(fontSize: 13, color: _Colors.textMuted),
//         ),
//         const SizedBox(height: 28),
//         _buildStatsGrid(total, companyCount),
//         const SizedBox(height: 16),
//         _buildBreakdown(),
//         const SizedBox(height: 24),
//         _buildActionButtons(),
//         const SizedBox(height: 32),
//       ],
//     );
//   }

//   Widget _buildStatsGrid(int total, int companyCount) {
//     final stats = [
//       _StatItem(Icons.dataset_outlined,      _formatNumber(total),  'Total Records', _Colors.primary),
//       _StatItem(Icons.business_outlined,     '$companyCount',        'Companies',     _Colors.accent),
//       _StatItem(Icons.timer_outlined,        _syncTime,              'Sync Time',     _Colors.warning),
//       _StatItem(Icons.check_circle_outline,  'Success',              'Status',        _Colors.success),
//     ];
//     return GridView.count(
//       crossAxisCount: 2,
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       mainAxisSpacing: 10,
//       crossAxisSpacing: 10,
//       childAspectRatio: 1.7,
//       children: stats.map((stat) => Container(
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: _Colors.surface,
//           border: Border.all(color: _Colors.border),
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: [
//             BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               width: 32,
//               height: 32,
//               decoration: BoxDecoration(
//                 color: stat.color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(stat.icon, size: 17, color: stat.color),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               stat.value,
//               style: TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.w800,
//                 color: stat.color,
//                 fontFamily: 'monospace',
//               ),
//             ),
//             Text(
//               stat.label,
//               style: const TextStyle(
//                 fontSize: 11,
//                 color: _Colors.textMuted,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       )).toList(),
//     );
//   }

//   Widget _buildBreakdown() {
//     final doneSteps = _syncSteps.where((s) => s.count > 0).toList();
//     if (doneSteps.isEmpty) return const SizedBox.shrink();
//     return Container(
//       decoration: BoxDecoration(
//         color: _Colors.surface,
//         border: Border.all(color: _Colors.border),
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
//         ],
//       ),
//       child: Column(
//         children: [
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
//             decoration: BoxDecoration(
//               border: Border(bottom: BorderSide(color: _Colors.border)),
//             ),
//             child: const Text(
//               'SYNC BREAKDOWN',
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w700,
//                 color: _Colors.textMuted,
//                 letterSpacing: 1.2,
//               ),
//             ),
//           ),
//           ...doneSteps.map((step) => Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//             decoration: BoxDecoration(
//               border: Border(bottom: BorderSide(color: _Colors.border.withOpacity(0.5))),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Icon(step.icon, size: 14, color: _Colors.textMuted),
//                     const SizedBox(width: 8),
//                     Text(step.name, style: const TextStyle(fontSize: 13, color: _Colors.textSecondary)),
//                   ],
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: _Colors.successLight,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(
//                     _formatNumber(step.count),
//                     style: const TextStyle(
//                       fontSize: 11,
//                       fontWeight: FontWeight.w700,
//                       color: _Colors.success,
//                       fontFamily: 'monospace',
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           )),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionButtons() {
//     return Row(
//       children: [
//         Expanded(
//           child: GestureDetector(
//             onTap: _resetSync,
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 14),
//               decoration: BoxDecoration(
//                 color: _Colors.surface,
//                 border: Border.all(color: _Colors.border, width: 1.5),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Text(
//                 'Sync Again',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w700,
//                   color: _Colors.textSecondary,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         Expanded(
//           flex: 2,
//           child: GestureDetector(
//             onTap: () {
//               // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen()));
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 14),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 gradient: LinearGradient(
//                   colors: [_Colors.primary, _Colors.accent],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ),
//                 boxShadow: [
//                   BoxShadow(color: _Colors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4)),
//                 ],
//               ),
//               child: const Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     'Open Dashboard',
//                     style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
//                   ),
//                   SizedBox(width: 4),
//                   Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // ============================================
//   // ERROR PHASE
//   // ============================================
//   Widget _buildErrorPhase() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 60),
//       child: Column(
//         children: [
//           Container(
//             width: 88,
//             height: 88,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: _Colors.errorLight,
//               border: Border.all(color: _Colors.error.withOpacity(0.3), width: 2),
//               boxShadow: [
//                 BoxShadow(color: _Colors.error.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4)),
//               ],
//             ),
//             child: const Icon(Icons.cloud_off_rounded, size: 38, color: _Colors.error),
//           ),
//           const SizedBox(height: 20),
//           const Text(
//             'Sync Failed',
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _Colors.textPrimary),
//           ),
//           const SizedBox(height: 8),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24),
//             child: Text(
//               _syncStatus,
//               style: const TextStyle(fontSize: 13, color: _Colors.textMuted, height: 1.5),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           const SizedBox(height: 28),
//           GestureDetector(
//             onTap: _resetSync,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 gradient: LinearGradient(
//                   colors: [_Colors.primary, _Colors.accent],
//                 ),
//                 boxShadow: [
//                   BoxShadow(color: _Colors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 3)),
//                 ],
//               ),
//               child: const Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
//                   SizedBox(width: 6),
//                   Text(
//                     'Try Again',
//                     style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatNumber(int n) {
//     if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
//     return n.toString();
//   }
// }

// // ============================================
// // CIRCULAR PROGRESS PAINTER
// // ============================================
// class _CircleProgressPainter extends CustomPainter {
//   final double progress;
//   final Color bgColor;
//   final List<Color> gradientColors;
//   final double strokeWidth;

//   _CircleProgressPainter({
//     required this.progress,
//     required this.bgColor,
//     required this.gradientColors,
//     required this.strokeWidth,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = (size.width - strokeWidth) / 2;

//     // Background track
//     canvas.drawCircle(
//       center,
//       radius,
//       Paint()
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = strokeWidth
//         ..color = bgColor,
//     );

//     // Progress arc
//     if (progress > 0) {
//       final rect = Rect.fromCircle(center: center, radius: radius);
//       final gradient = SweepGradient(
//         startAngle: -pi / 2,
//         endAngle: 3 * pi / 2,
//         colors: gradientColors,
//       );
//       canvas.drawArc(
//         rect,
//         -pi / 2,
//         2 * pi * progress,
//         false,
//         Paint()
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = strokeWidth
//           ..strokeCap = StrokeCap.round
//           ..shader = gradient.createShader(rect),
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _CircleProgressPainter old) =>
//       old.progress != progress;
// }

// // ============================================
// // DATA MODELS
// // ============================================
// class CompanyItem {
//   final String guid;
//   final String name;
//   final String gstin;
//   final String state;
//   final String city;
//   bool selected;

//   CompanyItem({
//     required this.guid,
//     required this.name,
//     this.gstin = '',
//     this.state = '',
//     this.city = '',
//     this.selected = false,
//   });
// }

// enum StepStatus { pending, syncing, done }

// class SyncStep {
//   final String name;
//   final IconData icon;
//   final String table;
//   StepStatus status;
//   int count;

//   SyncStep({
//     required this.name,
//     required this.icon,
//     required this.table,
//     this.status = StepStatus.pending,
//     this.count = 0,
//   });
// }

// class _StatItem {
//   final IconData icon;
//   final String value;
//   final String label;
//   final Color color;

//   _StatItem(this.icon, this.value, this.label, this.color);
// }

import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import '../database/database_helper.dart';
import '../services/cloud_to_local_sync_service.dart';
import '../utils/secure_storage.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import 'main.dart';
import 'theme/app_theme.dart';

// ============================================
// LIGHT MODE COLOR PALETTE
// ============================================
class _Colors {
  static Color get background      => AppColors.background;
  static Color get surface         => AppColors.surface;
  static Color get surfaceElevated => AppColors.iconBgBlue;
  static Color get border          => AppColors.divider;
  static const borderAccent = Color(0xFFBFD0F0);
  static const primary = Color(0xFF2563EB);
  static Color get primaryLight    => AppColors.iconBgBlue;
  static const primaryMid = Color(0xFFBFDBFE);
  static const accent = Color(0xFF7C3AED);
  static Color get accentLight     => AppColors.iconBgPurple;
  static const success = Color(0xFF16A34A);
  static Color get successLight    => AppColors.iconBgGreen;
  static const successMid = Color(0xFFBBF7D0);
  static const warning = Color(0xFFD97706);
  static Color get warningLight    => AppColors.iconBgAmber;
  static const error = Color(0xFFDC2626);
  static Color get errorLight      => AppColors.iconBgRed;
  static Color get textPrimary     => AppColors.textPrimary;
  static Color get textSecondary   => AppColors.textSecondary;
  static Color get textMuted       => AppColors.textSecondary;
  static Color get textDisabled    => AppColors.divider;
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with TickerProviderStateMixin {
  String _phase = 'select';
  String _syncType = 'full';

  List<CompanyItem> _companies = [];
  bool _loadingCompanies = true;
  String? _loadError;

  double _syncProgress = 0;
  String _syncStatus = '';
  List<SyncStep> _syncSteps = [];
  int _currentStep = -1;
  SyncResult? _syncResult;
  String _syncTime = '';

  // ── Quick company sync state ──
  bool _quickSyncing = false;
  String? _quickSyncError;
  String? _currentActiveGuid;
  List<CompanyItem> _localCompanies = [];
  bool _loadingLocalCompanies = false;

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
    _loadLocalCompanies();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // ============================================
  // LOAD CLOUD COMPANIES (for full/incremental sync)
  // ============================================
  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _loadError = null;
    });
    try {
      String? userId;
      final userData = await SecureStorage.getUser();
      if (userData != null) {
        final user = User.fromJson(jsonDecode(userData));
        userId = user.email;
      }
      final companies = await CloudToLocalSyncService.instance
          .fetchCompaniesFromCloud(userId: userId);
      setState(() {
        _companies = companies
            .map((c) => CompanyItem(
                  guid: c['company_guid'] ?? '',
                  name: c['company_name'] ?? '',
                  gstin: c['gsttin'] ?? '',
                  state: c['state'] ?? '',
                  city: c['city'] ?? '',
                ))
            .toList();
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
  // LOAD LOCAL COMPANIES (already saved in SQLite)
  // ============================================
  Future<void> _loadLocalCompanies() async {
    setState(() {
      _loadingLocalCompanies = true;
    });
    try {
      _currentActiveGuid = await SecureStorage.getSelectedCompanyGuid();
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'companies',
        columns: ['company_guid', 'company_name', 'gsttin', 'state', 'city'],
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'company_name ASC',
      );
      setState(() {
        _localCompanies = rows
            .map((r) => CompanyItem(
                  guid: r['company_guid'] as String? ?? '',
                  name: r['company_name'] as String? ?? '',
                  gstin: r['gsttin'] as String? ?? '',
                  state: r['state'] as String? ?? '',
                  city: r['city'] as String? ?? '',
                ))
            .toList();
        _loadingLocalCompanies = false;
      });
    } catch (e) {
      setState(() {
        _loadingLocalCompanies = false;
      });
    }
  }

  // ============================================
  // QUICK COMPANY SYNC
  // Fetches all companies for this user from Aurora
  // and saves/updates them in local SQLite.
  // Does NOT touch any other table.
  // ============================================
  Future<void> _quickSyncCompanies() async {
    setState(() {
      _quickSyncing = true;
      _quickSyncError = null;
    });
    try {
      String? userId;
      final userData = await SecureStorage.getUser();
      if (userData != null) {
        final user = User.fromJson(jsonDecode(userData));
        userId = user.email;
      }

      final db = await DatabaseHelper.instance.database;

      // Fetch all companies for this user from cloud
      final cloudCompanies = await CloudToLocalSyncService.instance
          .fetchCompaniesFromCloud(userId: userId);

      if (cloudCompanies.isEmpty) {
        setState(() {
          _quickSyncing = false;
          _quickSyncError = 'No companies found for your account in cloud.';
        });
        return;
      }

      // Save each company locally using the same safe upsert logic
      for (final c in cloudCompanies) {
        await CloudToLocalSyncService.instance.upsertCompanyLocal(db, c);
      }

      // Reload local list to reflect new data
      await _loadLocalCompanies();

      setState(() {
        _quickSyncing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${cloudCompanies.length} ${cloudCompanies.length == 1 ? "company" : "companies"} synced successfully',
            ),
            backgroundColor: _Colors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _quickSyncing = false;
        _quickSyncError = e.toString();
      });
    }
  }

  // ============================================
  // SET ACTIVE COMPANY
  // ============================================
  Future<void> _setActiveCompany(String guid) async {
    await SecureStorage.saveCompanyGuid(guid);
    setState(() {
      _currentActiveGuid = guid;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Active company updated'),
          backgroundColor: _Colors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ============================================
  // FULL / INCREMENTAL SYNC
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
    final localDb = await DatabaseHelper.instance.database;
    for (final company in selected) {
      try {
        final result = _syncType == 'full'
            ? await CloudToLocalSyncService.instance.fullSync(
                localDb,
                company.guid,
                onProgress: (status, progress) {
                  setState(() {
                    print('$status $progress');
                    _syncStatus = status;
                    _syncProgress = progress;
                    _updateStepFromProgress(progress);
                  });
                },
              )
            : await CloudToLocalSyncService.instance.incrementalSync(
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
      } catch (e) {
        setState(() {
          _phase = 'error';
          _syncStatus = 'Error: $e';
        });
        return;
      }
    }
    stopwatch.stop();
    final currentGuid = await SecureStorage.getSelectedCompanyGuid();
    if ((currentGuid == null || currentGuid.isEmpty) && selected.isNotEmpty) {
      await SecureStorage.saveCompanyGuid(selected.first.guid);
    }

    // Update in-memory AppState so screens don't show "Select Company"
    try {
      final db = await DatabaseHelper.instance.database;
      final companyMaps = await db.query('companies');
      final companies = companyMaps.map((m) => Company.fromMap(m)).toList();
      AppState.companies = companies;

      final savedGuid = await SecureStorage.getSelectedCompanyGuid();
      if (savedGuid != null && savedGuid.isNotEmpty) {
        final match = companies.where((c) => c.guid == savedGuid);
        AppState.selectedCompany = match.isNotEmpty
            ? match.first
            : (companies.isNotEmpty ? companies.first : null);
      } else if (companies.isNotEmpty) {
        AppState.selectedCompany = companies.first;
      }
    } catch (e) {
      debugPrint('Error updating AppState after sync: $e');
    }

    setState(() {
      _syncTime =
          '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
      _phase = 'complete';
    });
  }

  void _updateStepFromProgress(double progress) {
    final stepIndex =
        (progress * _syncSteps.length).floor().clamp(0, _syncSteps.length - 1);
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

  List<SyncStep> _buildSyncSteps() => [
        SyncStep(
            name: 'Company Info',
            icon: Icons.business_outlined,
            table: 'companies'),
        SyncStep(
            name: 'Account Groups',
            icon: Icons.folder_outlined,
            table: 'groups'),
        SyncStep(
            name: 'Voucher Types',
            icon: Icons.receipt_long_outlined,
            table: 'voucher_types'),
        SyncStep(
            name: 'Ledgers', icon: Icons.menu_book_outlined, table: 'ledgers'),
        SyncStep(
            name: 'Stock Items',
            icon: Icons.inventory_2_outlined,
            table: 'stock_items'),
        SyncStep(
            name: 'Vouchers',
            icon: Icons.description_outlined,
            table: 'vouchers'),
        SyncStep(
            name: 'Ledger Entries',
            icon: Icons.account_balance_wallet_outlined,
            table: 'ledger_entries'),
        SyncStep(
            name: 'Inventory Entries',
            icon: Icons.bar_chart_outlined,
            table: 'inventory_entries'),
        SyncStep(
            name: 'Batch Allocations',
            icon: Icons.label_outlined,
            table: 'batch_allocs'),
        SyncStep(
            name: 'Closing Balances',
            icon: Icons.trending_up_outlined,
            table: 'closing_balances'),
      ];

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
  void _toggleCompany(int index) =>
      setState(() => _companies[index].selected = !_companies[index].selected);
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
      backgroundColor: _Colors.background,
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
    Color titleColor;
    switch (_phase) {
      case 'syncing':
        title = 'Syncing Data';
        titleColor = _Colors.primary;
        break;
      case 'complete':
        title = 'All Done!';
        titleColor = _Colors.success;
        break;
      case 'error':
        title = 'Sync Failed';
        titleColor = _Colors.error;
        break;
      default:
        title = 'Sync Data';
        titleColor = _Colors.textPrimary;
        break;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: _Colors.surface,
        border: Border(bottom: BorderSide(color: _Colors.border, width: 1)),
        boxShadow: [
          BoxShadow(
              color: _Colors.primary.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _Colors.background,
                border: Border.all(color: _Colors.border),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  size: 16, color: _Colors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TALLY CLOUD SYNC',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: _Colors.primary),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      letterSpacing: -0.3),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [_Colors.primary, _Colors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: _Colors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const Center(
                child: Icon(Icons.cloud_sync_outlined,
                    size: 22, color: Colors.white)),
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
  // PHASE 1: SELECT
  // ============================================
  Widget _buildSelectPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Quick Company Sync section ─────────────────────────
        _buildQuickSyncSection(),
        const SizedBox(height: 20),

        // ── Divider ───────────────────────────────────────────
        Row(children: [
          Expanded(child: Divider(color: _Colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'FULL / INCREMENTAL SYNC',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _Colors.textMuted),
            ),
          ),
          Expanded(child: Divider(color: _Colors.border)),
        ]),
        const SizedBox(height: 16),

        _buildSyncTypeToggle(),
        const SizedBox(height: 12),
        _buildInfoBanner(),
        const SizedBox(height: 24),
        if (_loadingCompanies)
          _buildLoadingState()
        else if (_loadError != null)
          _buildErrorState()
        else ...[
          _buildCompanyListHeader(),
          const SizedBox(height: 10),
          ..._companies.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCompanyCard(e.key, e.value),
                ),
              ),
        ],
        const SizedBox(height: 24),
        _buildSyncButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  // ============================================
  // QUICK SYNC SECTION
  // ============================================
  Widget _buildQuickSyncSection() {
    return Container(
      decoration: BoxDecoration(
        color: _Colors.surface,
        border: Border.all(color: _Colors.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: _Colors.primaryLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _Colors.primaryMid)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _Colors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_center_outlined,
                      size: 18, color: _Colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Company Sync',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _Colors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Sync only company list — then select active company',
                        style: TextStyle(
                            fontSize: 11, color: _Colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Sync button
                GestureDetector(
                  onTap: _quickSyncing ? null : _quickSyncCompanies,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: _quickSyncing
                          ? null
                          : const LinearGradient(
                              colors: [_Colors.primary, _Colors.accent],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color: _quickSyncing ? _Colors.border : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _quickSyncing
                          ? null
                          : [
                              BoxShadow(
                                  color: _Colors.primary.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ],
                    ),
                    child: _quickSyncing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _Colors.textMuted,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_download_outlined,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Sync',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Error banner
          if (_quickSyncError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              decoration: BoxDecoration(
                color: _Colors.errorLight,
                border: Border.all(color: _Colors.error.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 14, color: _Colors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _quickSyncError!,
                      style:
                          const TextStyle(fontSize: 11, color: _Colors.error),
                    ),
                  ),
                ],
              ),
            ),

          // Local companies list
          if (_loadingLocalCompanies)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _Colors.primary),
                ),
              ),
            )
          else if (_localCompanies.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 32, color: _Colors.textDisabled),
                  const SizedBox(height: 8),
                  Text(
                    'No companies saved locally yet',
                    style: TextStyle(fontSize: 12, color: _Colors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap Sync to download your companies',
                    style: TextStyle(fontSize: 11, color: _Colors.textDisabled),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 2),
                    child: Row(
                      children: [
                        Text(
                          'SELECT ACTIVE COMPANY',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _Colors.textMuted,
                              letterSpacing: 1),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _Colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_localCompanies.length}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _Colors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._localCompanies
                      .map((company) => _buildLocalCompanyRow(company)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================
  // LOCAL COMPANY ROW (tap to set active)
  // ============================================
  Widget _buildLocalCompanyRow(CompanyItem company) {
    final isActive = company.guid == _currentActiveGuid;
    return GestureDetector(
      onTap: () => _setActiveCompany(company.guid),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _Colors.successLight : _Colors.background,
          border: Border.all(
            color: isActive ? _Colors.success.withOpacity(0.4) : _Colors.border,
            width: isActive ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: _Colors.success.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Row(
          children: [
            // Active indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? _Colors.success : Colors.transparent,
                border: Border.all(
                  color: isActive ? _Colors.success : _Colors.border,
                  width: 2,
                ),
              ),
              child: isActive
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),

            // Company info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? _Colors.success : _Colors.textPrimary,
                    ),
                  ),
                  if (company.gstin.isNotEmpty || company.city.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (company.gstin.isNotEmpty) ...[
                          Text(
                            company.gstin,
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive
                                  ? _Colors.success.withOpacity(0.7)
                                  : _Colors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (company.city.isNotEmpty)
                            Text(
                              '  •  ',
                              style: TextStyle(
                                  color: _Colors.textDisabled, fontSize: 10),
                            ),
                        ],
                        if (company.city.isNotEmpty)
                          Text(
                            '${company.city}, ${company.state}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive
                                  ? _Colors.success.withOpacity(0.7)
                                  : _Colors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Active badge
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _Colors.success,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _Colors.background,
                  border: Border.all(color: _Colors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SET ACTIVE',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _Colors.textMuted,
                      letterSpacing: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // REST OF PHASE 1 (unchanged)
  // ============================================
  Widget _buildSyncTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _Colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.border),
      ),
      child: Row(
        children: [
          _buildToggleOption('full', Icons.sync_rounded, 'Full Sync'),
          _buildToggleOption('incremental', Icons.bolt_rounded, 'Incremental'),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String type, IconData icon, String label) {
    final isActive = _syncType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _syncType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _Colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isActive ? _Colors.primary : _Colors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _Colors.primary : _Colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    final isFull = _syncType == 'full';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isFull ? _Colors.warningLight : _Colors.successLight,
        border: Border.all(
          color: isFull
              ? _Colors.warning.withOpacity(0.25)
              : _Colors.success.withOpacity(0.25),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isFull ? Icons.info_outline_rounded : Icons.flash_on_rounded,
            size: 16,
            color: isFull ? _Colors.warning : _Colors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFull
                  ? 'Downloads all data fresh. Use for first sync or to fix data issues.'
                  : 'Only downloads changes since last sync. Much faster for regular updates.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isFull ? _Colors.warning : _Colors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: _Colors.primary, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Loading companies from cloud...',
                style: TextStyle(color: _Colors.textMuted, fontSize: 13)),
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _Colors.errorLight,
                border: Border.all(color: _Colors.error.withOpacity(0.2)),
              ),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 28, color: _Colors.error),
            ),
            const SizedBox(height: 16),
            Text('Failed to load companies',
                style: TextStyle(
                    color: _Colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_loadError ?? '',
                style: TextStyle(color: _Colors.textMuted, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadCompanies,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: _Colors.primary,
                backgroundColor: _Colors.primaryLight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
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
        Row(
          children: [
            Text('COMPANIES',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _Colors.textMuted,
                    letterSpacing: 1)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _Colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$_selectedCount/${_companies.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _Colors.primary)),
            ),
          ],
        ),
        GestureDetector(
          onTap: _selectAll,
          child: Text(
            _companies.every((c) => c.selected) ? 'Deselect All' : 'Select All',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _Colors.primary),
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
          color: company.selected ? _Colors.primaryLight : _Colors.surface,
          border: Border.all(
            color: company.selected
                ? _Colors.primary.withOpacity(0.4)
                : _Colors.border,
            width: company.selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: company.selected
                  ? _Colors.primary.withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: company.selected
                    ? const LinearGradient(
                        colors: [_Colors.primary, _Colors.accent])
                    : null,
                color: company.selected ? null : _Colors.background,
                border: company.selected
                    ? null
                    : Border.all(color: _Colors.border, width: 1.5),
                boxShadow: company.selected
                    ? [
                        BoxShadow(
                            color: _Colors.primary.withOpacity(0.3),
                            blurRadius: 6)
                      ]
                    : null,
              ),
              child: company.selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: company.selected
                          ? _Colors.primary
                          : _Colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (company.gstin.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _Colors.accentLight,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: _Colors.accent.withOpacity(0.2)),
                          ),
                          child: Text(
                            company.gstin,
                            style: const TextStyle(
                                fontSize: 10,
                                color: _Colors.accent,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (company.city.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11, color: _Colors.textMuted),
                            const SizedBox(width: 2),
                            Text('${company.city}, ${company.state}',
                                style: TextStyle(
                                    fontSize: 11, color: _Colors.textMuted)),
                          ],
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
              ? const LinearGradient(
                  colors: [_Colors.primary, _Colors.accent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : _Colors.border,
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: _Colors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_sync_rounded,
                size: 18, color: enabled ? Colors.white : _Colors.textMuted),
            const SizedBox(width: 8),
            Text(
              enabled
                  ? 'Sync $_selectedCount ${_selectedCount == 1 ? "Company" : "Companies"}'
                  : 'Select companies to sync',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: enabled ? Colors.white : _Colors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // PHASE 2: SYNCING (unchanged)
  // ============================================
  Widget _buildSyncingPhase() {
    return Column(
      children: [
        const SizedBox(height: 28),
        _buildCircularProgress(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _Colors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_syncStatus,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _Colors.primary)),
        ),
        const SizedBox(height: 24),
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
          CustomPaint(
            size: const Size(160, 160),
            painter: _CircleProgressPainter(
              progress: _syncProgress,
              bgColor: _Colors.border,
              gradientColors: [_Colors.primary, _Colors.accent],
              strokeWidth: 10,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(_syncProgress * 100).round()}',
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: _Colors.textPrimary,
                    fontFamily: 'monospace'),
              ),
              Text('PERCENT',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _Colors.textMuted,
                      letterSpacing: 1.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStepsList() {
    return Container(
      decoration: BoxDecoration(
        color: _Colors.surface,
        border: Border.all(color: _Colors.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: _syncSteps.asMap().entries.map((e) {
          final i = e.key;
          final step = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: step.status == StepStatus.syncing
                  ? _Colors.primaryLight
                  : Colors.transparent,
              border: i < _syncSteps.length - 1
                  ? Border(bottom: BorderSide(color: _Colors.border))
                  : null,
              borderRadius: BorderRadius.only(
                topLeft: i == 0 ? const Radius.circular(16) : Radius.zero,
                topRight: i == 0 ? const Radius.circular(16) : Radius.zero,
                bottomLeft: i == _syncSteps.length - 1
                    ? const Radius.circular(16)
                    : Radius.zero,
                bottomRight: i == _syncSteps.length - 1
                    ? const Radius.circular(16)
                    : Radius.zero,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: step.status == StepStatus.done
                        ? _Colors.successLight
                        : step.status == StepStatus.syncing
                            ? _Colors.primaryLight
                            : _Colors.background,
                    border: Border.all(
                      color: step.status == StepStatus.done
                          ? _Colors.success.withOpacity(0.3)
                          : step.status == StepStatus.syncing
                              ? _Colors.primary.withOpacity(0.3)
                              : _Colors.border,
                    ),
                  ),
                  child: Center(
                    child: step.status == StepStatus.done
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: _Colors.success)
                        : step.status == StepStatus.syncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _Colors.primary))
                            : Icon(step.icon,
                                size: 15, color: _Colors.textDisabled),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: step.status == StepStatus.syncing
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: step.status == StepStatus.done
                          ? _Colors.success
                          : step.status == StepStatus.syncing
                              ? _Colors.primary
                              : _Colors.textMuted,
                    ),
                  ),
                ),
                if (step.status == StepStatus.done && step.count > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _Colors.successLight,
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: _Colors.success.withOpacity(0.2)),
                    ),
                    child: Text(_formatNumber(step.count),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _Colors.success,
                            fontFamily: 'monospace')),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================
  // PHASE 3: COMPLETE (unchanged)
  // ============================================
  Widget _buildCompletePhase() {
    final total = _syncResult?.totalRecords ?? 0;
    final companyCount = _companies.where((c) => c.selected).length;
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _Colors.successLight,
            border:
                Border.all(color: _Colors.success.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                  color: _Colors.success.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(Icons.cloud_done_rounded,
              size: 42, color: _Colors.success),
        ),
        const SizedBox(height: 20),
        Text('Sync Complete!',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _Colors.textPrimary)),
        const SizedBox(height: 6),
        Text('All data has been downloaded to your device',
            style: TextStyle(fontSize: 13, color: _Colors.textMuted)),
        const SizedBox(height: 28),
        _buildStatsGrid(total, companyCount),
        const SizedBox(height: 16),
        _buildBreakdown(),
        const SizedBox(height: 24),
        _buildActionButtons(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatsGrid(int total, int companyCount) {
    final stats = [
      _StatItem(Icons.dataset_outlined, _formatNumber(total), 'Total Records',
          _Colors.primary),
      _StatItem(Icons.business_outlined, '$companyCount', 'Companies',
          _Colors.accent),
      _StatItem(Icons.timer_outlined, _syncTime, 'Sync Time', _Colors.warning),
      _StatItem(
          Icons.check_circle_outline, 'Success', 'Status', _Colors.success),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: stats
          .map((stat) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _Colors.surface,
                  border: Border.all(color: _Colors.border),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: stat.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(stat.icon, size: 17, color: stat.color),
                    ),
                    const SizedBox(height: 8),
                    Text(stat.value,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: stat.color,
                            fontFamily: 'monospace')),
                    Text(stat.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: _Colors.textMuted,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildBreakdown() {
    final doneSteps = _syncSteps.where((s) => s.count > 0).toList();
    if (doneSteps.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: _Colors.surface,
        border: Border.all(color: _Colors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _Colors.border))),
            child: Text('SYNC BREAKDOWN',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _Colors.textMuted,
                    letterSpacing: 1.2)),
          ),
          ...doneSteps.map((step) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: _Colors.border.withOpacity(0.5)))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(step.icon, size: 14, color: _Colors.textMuted),
                        const SizedBox(width: 8),
                        Text(step.name,
                            style: TextStyle(
                                fontSize: 13, color: _Colors.textSecondary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _Colors.successLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(_formatNumber(step.count),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _Colors.success,
                              fontFamily: 'monospace')),
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
                color: _Colors.surface,
                border: Border.all(color: _Colors.border, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Sync Again',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _Colors.textSecondary)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                    colors: [_Colors.primary, _Colors.accent]),
                boxShadow: [
                  BoxShadow(
                      color: _Colors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Open Dashboard',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // ERROR PHASE (unchanged)
  // ============================================
  Widget _buildErrorPhase() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _Colors.errorLight,
              border:
                  Border.all(color: _Colors.error.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                    color: _Colors.error.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.cloud_off_rounded,
                size: 38, color: _Colors.error),
          ),
          const SizedBox(height: 20),
          Text('Sync Failed',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _Colors.textPrimary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_syncStatus,
                style: TextStyle(
                    fontSize: 13, color: _Colors.textMuted, height: 1.5),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _resetSync,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                    colors: [_Colors.primary, _Colors.accent]),
                boxShadow: [
                  BoxShadow(
                      color: _Colors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Try Again',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
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
// CIRCULAR PROGRESS PAINTER (unchanged)
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
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = bgColor);
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -pi / 2,
            endAngle: 3 * pi / 2,
            colors: gradientColors,
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter old) =>
      old.progress != progress;
}

// ============================================
// DATA MODELS (unchanged)
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
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  _StatItem(this.icon, this.value, this.label, this.color);
}
