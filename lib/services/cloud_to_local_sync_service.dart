import 'package:postgres/postgres.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tally_connector/database/database_helper.dart';
import '../config/api_config.dart';

class _ExecResult {
  final Result rows;
  final Connection conn;
  _ExecResult(this.rows, this.conn);
}

class _ParentSyncResult {
  final int totalSynced;
  final int maxAlterIdSeen;
  final List<String> updatedGuids;
  _ParentSyncResult({
    required this.totalSynced,
    required this.maxAlterIdSeen,
    required this.updatedGuids,
  });
}

class CloudToLocalSyncService {
  static final CloudToLocalSyncService instance =
      CloudToLocalSyncService._init();
  CloudToLocalSyncService._init();

  static const int _recycleEveryChunks = 10;
  static const int _fetchSize = 2000;

  // Tables where cloud has SERIAL id but local does NOT use it as PK
  // → must remove 'id' before inserting locally
  static const _tablesWithSerialId = {
    'groups',
    'voucher_types',
    'ledgers',
    'stock_items',
    'vouchers',
    // sub-tables have id as PK on BOTH sides → keep id
  };

  // Mapping: table name → companies column name
  static const _cursorColumns = {
    'ledgers': 0,
    'stock_items': 0,
    'vouchers': 0,
    'groups': 0,
    'voucher_types': 0,
  };

  // ============================================================
  // CONNECTION
  // ============================================================

  Future<Connection> _openConnection() async {
    return await Connection.open(
      Endpoint(
        host: AwsAuroraConfig.host,
        port: AwsAuroraConfig.port,
        database: AwsAuroraConfig.database,
        username: AwsAuroraConfig.username,
        password: AwsAuroraConfig.password,
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.require,
        connectTimeout: const Duration(seconds: 30),
        queryTimeout: const Duration(seconds: 300),
      ),
    );
  }

  Future<_ExecResult> _executeWithRetry(
    Connection conn,
    String sql, {
    int maxRetries = 3,
  }) async {
    Connection current = conn;
    int attempt = 0;
    while (true) {
      try {
        final rows = await current.execute(sql);
        return _ExecResult(rows, current);
      } catch (e) {
        final msg = e.toString();
        final isRetryable = msg.contains('TlsException') ||
            msg.contains('Socket') ||
            msg.contains('SocketException') ||
            msg.contains('Failed host lookup') ||
            msg.contains('No address associated') ||
            msg.contains('BAD_DECRYPT') ||
            msg.contains('DECRYPTION_FAILED') ||
            msg.contains('not open') ||
            msg.contains('StreamSink is closed') ||
            msg.contains('Connection');
        if (isRetryable && attempt < maxRetries) {
          attempt++;
          print('  ⚠️ Network drop, retry $attempt/$maxRetries...');
          try { await current.close(); } catch (_) {}
          await Future.delayed(Duration(seconds: attempt * 2));
          current = await _openConnection();
          continue;
        }
        rethrow;
      }
    }
  }

  // ============================================================
  // MAP HELPER — strips cloud SERIAL id for main tables
  // ============================================================

  Map<String, dynamic> _resultRowToMap(
    ResultRow row,
    ResultSchema schema, {
    String? tableName,
  }) {
    final map = <String, dynamic>{};
    for (int i = 0; i < schema.columns.length; i++) {
      final colName = schema.columns[i].columnName;
      var value = row[i];
      if (value is DateTime) value = value.toIso8601String();
      map[colName ?? 'col_$i'] = value;
    }
    // Remove cloud SERIAL id for main tables (local uses guid as PK)
    if (tableName != null && _tablesWithSerialId.contains(tableName)) {
      map.remove('id');
    }
    return map;
  }

  // ============================================================
  // PUBLIC API
  // ============================================================

  Future<void> upsertCompanyLocal(
    Database localDb,
    Map<String, dynamic> cloudRow,
  ) async {
    await _fullSyncCompanyFromMap(localDb, cloudRow);
  }

  String _getSchemaName(String companyGuid) =>
      'company_${companyGuid.replaceAll('-', '_')}';

  // ============================================================
  // CURSOR READ/WRITE
  // ============================================================

  
  // ============================================================
  // FULL SYNC
  // ============================================================

  Future<SyncResult> fullSync(
    Database localDb,
    String companyGuid, {
    Function(String status, double progress)? onProgress,
  }) async {
    await _fullSyncCompany(localDb, companyGuid);
    return _runSync(localDb, companyGuid,
        onProgress: onProgress, skipCompanySync: true);
  }

  Future<SyncResult> incrementalSync(
    Database localDb,
    String companyGuid, {
    Function(String status, double progress)? onProgress,
  }) async {
    return _runSync(localDb, companyGuid, onProgress: onProgress);
  }

  // ============================================================
  // SHARED SYNC RUNNER
  // ============================================================

  Future<SyncResult> _runSync(
    Database localDb,
    String companyGuid, {
    Function(String status, double progress)? onProgress,
    bool skipCompanySync = false,
  }) async {
    final result = SyncResult();
    final schema = _getSchemaName(companyGuid);

    try {
      onProgress?.call('Syncing company info...', 0.05);
      if (!skipCompanySync) {
        result.companies = await _fullSyncCompany(localDb, companyGuid);
      } else {
        result.companies = 1;
      }

      onProgress?.call('Syncing groups...', 0.10);
      result.groups = await _fullSyncSimple(localDb, schema, 'groups', companyGuid);

      onProgress?.call('Syncing voucher types...', 0.18);
      result.voucherTypes = await _fullSyncSimple(localDb, schema, 'voucher_types', companyGuid);

      onProgress?.call('Syncing ledgers & stock items...', 0.28);
      final masterResults = await Future.wait([
        _syncLedgerGroup(localDb, schema, companyGuid),
        _syncStockItemGroup(localDb, schema, companyGuid),
      ]);

      result.ledgers                = masterResults[0]['ledgers']!;
      result.ledgerClosingBalances  = masterResults[0]['ledger_closing_balances']!;
      result.ledgerContacts         = masterResults[0]['ledger_contacts']!;
      result.ledgerMailingDetails   = masterResults[0]['ledger_mailing_details']!;
      result.ledgerGstRegistrations = masterResults[0]['ledger_gst_registrations']!;

      result.stockItems             = masterResults[1]['stock_items']!;
      result.stockClosingBalances   = masterResults[1]['stock_item_closing_balance']!;
      result.stockHsnHistory        = masterResults[1]['stock_item_hsn_history']!;
      result.stockBatchAllocation   = masterResults[1]['stock_item_batch_allocation']!;
      result.stockGstHistory        = masterResults[1]['stock_item_gst_history']!;

      onProgress?.call('Syncing vouchers...', 0.70);
      final voucherCounts = await _syncVoucherGroup(localDb, schema, companyGuid);

      result.vouchers         = voucherCounts['vouchers']!;
      result.ledgerEntries    = voucherCounts['voucher_ledger_entries']!;
      result.inventoryEntries = voucherCounts['voucher_inventory_entries']!;
      result.batchAllocations = voucherCounts['voucher_batch_allocations']!;

      result.success = true;
      onProgress?.call('Sync complete!', 1.0);
      print('✅ Sync complete: ${result.totalRecords} records\n$result');
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      print('❌ Sync failed: $e');
    }

    return result;
  }

  // ============================================================
  // STEP 1: COMPANY
  // ============================================================

  Future<int> _fullSyncCompany(Database localDb, String companyGuid) async {
    final conn = await _openConnection();
    try {
      final exec = await _executeWithRetry(conn, '''
        SELECT * FROM user_data.companies
        WHERE company_guid = '$companyGuid'
      ''');
      if (!identical(conn, exec.conn)) {
        try { await exec.conn.close(); } catch (_) {}
      }
      if (exec.rows.isEmpty) {
        print('  ⚠️ companies: not found in cloud for guid $companyGuid');
        return 0;
      }

      for (final row in exec.rows) {
        final cloudMap = _resultRowToMap(row, exec.rows.schema);
        final localMap = <String, dynamic>{
          'company_guid':                   cloudMap['company_guid'],
          'master_id':                      cloudMap['master_id'] ?? 0,
          'alter_id':                       cloudMap['alter_id'],
          'company_name':                   cloudMap['company_name'] ?? '',
          'reserved_name':                  cloudMap['reserved_name'],
          'starting_from':                  cloudMap['starting_from'] ?? '',
          'ending_at':                      cloudMap['ending_at'] ?? '',
          'books_from':                     cloudMap['books_from'],
          'books_beginning_from':           cloudMap['books_beginning_from'],
          'gst_applicable_date':            cloudMap['gst_applicable_date'],
          'email':                          cloudMap['email'],
          'phone_number':                   cloudMap['phone_number'],
          'fax_number':                     cloudMap['fax_number'],
          'website':                        cloudMap['website'],
          'address':                        cloudMap['address'],
          'city':                           cloudMap['city'],
          'pincode':                        cloudMap['pincode'],
          'state':                          cloudMap['state'],
          'country':                        cloudMap['country'],
          'income_tax_number':              cloudMap['income_tax_number'],
          'pan':                            cloudMap['pan'],
          'gsttin':                         cloudMap['gsttin'],
          'currency_name':                  cloudMap['currency_name'],
          'base_currency_name':             cloudMap['base_currency_name'],
          'maintain_accounts':              cloudMap['maintain_accounts'] ?? 0,
          'maintain_bill_wise':             cloudMap['maintain_bill_wise'] ?? 0,
          'enable_cost_centres':            cloudMap['enable_cost_centres'] ?? 0,
          'enable_interest_calc':           cloudMap['enable_interest_calc'] ?? 0,
          'maintain_inventory':             cloudMap['maintain_inventory'] ?? 0,
          'integrate_inventory':            cloudMap['integrate_inventory'] ?? 0,
          'multi_price_level':              cloudMap['multi_price_level'] ?? 0,
          'enable_batches':                 cloudMap['enable_batches'] ?? 0,
          'maintain_expiry_date':           cloudMap['maintain_expiry_date'] ?? 0,
          'enable_job_order_processing':    cloudMap['enable_job_order_processing'] ?? 0,
          'enable_cost_tracking':           cloudMap['enable_cost_tracking'] ?? 0,
          'enable_job_costing':             cloudMap['enable_job_costing'] ?? 0,
          'use_discount_column':            cloudMap['use_discount_column'] ?? 0,
          'use_separate_actual_billed_qty': cloudMap['use_separate_actual_billed_qty'] ?? 0,
          'is_gst_applicable':              cloudMap['is_gst_applicable'] ?? 0,
          'set_alter_company_gst_rate':     cloudMap['set_alter_company_gst_rate'] ?? 0,
          'is_tds_applicable':              cloudMap['is_tds_applicable'] ?? 0,
          'is_tcs_applicable':              cloudMap['is_tcs_applicable'] ?? 0,
          'is_vat_applicable':              cloudMap['is_vat_applicable'] ?? 0,
          'is_excise_applicable':           cloudMap['is_excise_applicable'] ?? 0,
          'is_service_tax_applicable':      cloudMap['is_service_tax_applicable'] ?? 0,
          'enable_browser_reports':         cloudMap['enable_browser_reports'] ?? 0,
          'enable_tally_net':               cloudMap['enable_tally_net'] ?? 0,
          'is_payroll_enabled':             cloudMap['is_payroll_enabled'] ?? 0,
          'enable_payroll_statutory':       cloudMap['enable_payroll_statutory'] ?? 0,
          'enable_payment_link_qr':         cloudMap['enable_payment_link_qr'] ?? 0,
          'enable_multi_address':           cloudMap['enable_multi_address'] ?? 0,
          'mark_modified_vouchers':         cloudMap['mark_modified_vouchers'] ?? 0,
          'is_deleted':                     cloudMap['is_deleted'] ?? 0,
          'is_audited':                     cloudMap['is_audited'] ?? 0,
          'is_security_enabled':            cloudMap['is_security_enabled'] ?? 0,
          'is_book_in_use':                 cloudMap['is_book_in_use'] ?? 0,
          'created_at': cloudMap['created_at'] is DateTime
              ? (cloudMap['created_at'] as DateTime).toIso8601String()
              : cloudMap['created_at']?.toString(),
          'updated_at': cloudMap['updated_at'] is DateTime
              ? (cloudMap['updated_at'] as DateTime).toIso8601String()
              : cloudMap['updated_at']?.toString(),
        };

        final existing = await localDb.query(
          'companies',
          columns: ['company_guid'],
          where: 'company_guid = ?',
          whereArgs: [companyGuid],
        );

        if (existing.isEmpty) {
          localMap['is_selected'] = 0;
          await localDb.insert('companies', localMap);
          print('  ✅ companies: inserted new row for $companyGuid');
        } else {
          await localDb.update('companies', localMap,
              where: 'company_guid = ?', whereArgs: [companyGuid]);
          print('  ✅ companies: updated existing row for $companyGuid');
        }
      }

      return exec.rows.length;
    } finally {
      try { await conn.close(); } catch (_) {}
    }
  }

  Future<void> _fullSyncCompanyFromMap(
    Database localDb,
    Map<String, dynamic> cloudMap,
  ) async {
    final companyGuid = cloudMap['company_guid'] as String? ?? '';
    if (companyGuid.isEmpty) return;

    final localMap = <String, dynamic>{
      'company_guid':  companyGuid,
      'master_id':     cloudMap['master_id'] ?? 0,
      'alter_id':      cloudMap['alter_id'],
      'company_name':  cloudMap['company_name'] ?? '',
      'reserved_name': cloudMap['reserved_name'],
      'starting_from': cloudMap['starting_from'] ?? '',
      'ending_at':     cloudMap['ending_at'] ?? '',
      'books_from':               cloudMap['books_from'],
      'books_beginning_from':     cloudMap['books_beginning_from'],
      'gst_applicable_date':      cloudMap['gst_applicable_date'],
      'email':                    cloudMap['email'],
      'phone_number':             cloudMap['phone_number'],
      'fax_number':               cloudMap['fax_number'],
      'website':                  cloudMap['website'],
      'address':                  cloudMap['address'],
      'city':                     cloudMap['city'],
      'pincode':                  cloudMap['pincode'],
      'state':                    cloudMap['state'],
      'country':                  cloudMap['country'],
      'income_tax_number':        cloudMap['income_tax_number'],
      'pan':                      cloudMap['pan'],
      'gsttin':                   cloudMap['gsttin'],
      'currency_name':            cloudMap['currency_name'],
      'base_currency_name':       cloudMap['base_currency_name'],
      'maintain_accounts':        cloudMap['maintain_accounts'] ?? 0,
      'maintain_bill_wise':       cloudMap['maintain_bill_wise'] ?? 0,
      'enable_cost_centres':      cloudMap['enable_cost_centres'] ?? 0,
      'enable_interest_calc':     cloudMap['enable_interest_calc'] ?? 0,
      'maintain_inventory':       cloudMap['maintain_inventory'] ?? 0,
      'integrate_inventory':      cloudMap['integrate_inventory'] ?? 0,
      'multi_price_level':        cloudMap['multi_price_level'] ?? 0,
      'enable_batches':           cloudMap['enable_batches'] ?? 0,
      'maintain_expiry_date':     cloudMap['maintain_expiry_date'] ?? 0,
      'enable_job_order_processing': cloudMap['enable_job_order_processing'] ?? 0,
      'enable_cost_tracking':     cloudMap['enable_cost_tracking'] ?? 0,
      'enable_job_costing':       cloudMap['enable_job_costing'] ?? 0,
      'use_discount_column':      cloudMap['use_discount_column'] ?? 0,
      'use_separate_actual_billed_qty': cloudMap['use_separate_actual_billed_qty'] ?? 0,
      'is_gst_applicable':        cloudMap['is_gst_applicable'] ?? 0,
      'set_alter_company_gst_rate': cloudMap['set_alter_company_gst_rate'] ?? 0,
      'is_tds_applicable':        cloudMap['is_tds_applicable'] ?? 0,
      'is_tcs_applicable':        cloudMap['is_tcs_applicable'] ?? 0,
      'is_vat_applicable':        cloudMap['is_vat_applicable'] ?? 0,
      'is_excise_applicable':     cloudMap['is_excise_applicable'] ?? 0,
      'is_service_tax_applicable': cloudMap['is_service_tax_applicable'] ?? 0,
      'enable_browser_reports':   cloudMap['enable_browser_reports'] ?? 0,
      'enable_tally_net':         cloudMap['enable_tally_net'] ?? 0,
      'is_payroll_enabled':       cloudMap['is_payroll_enabled'] ?? 0,
      'enable_payroll_statutory': cloudMap['enable_payroll_statutory'] ?? 0,
      'enable_payment_link_qr':   cloudMap['enable_payment_link_qr'] ?? 0,
      'enable_multi_address':     cloudMap['enable_multi_address'] ?? 0,
      'mark_modified_vouchers':   cloudMap['mark_modified_vouchers'] ?? 0,
      'is_deleted':               cloudMap['is_deleted'] ?? 0,
      'is_audited':               cloudMap['is_audited'] ?? 0,
      'is_security_enabled':      cloudMap['is_security_enabled'] ?? 0,
      'is_book_in_use':           cloudMap['is_book_in_use'] ?? 0,
      'created_at': cloudMap['created_at'] is DateTime
          ? (cloudMap['created_at'] as DateTime).toIso8601String()
          : cloudMap['created_at']?.toString(),
      'updated_at': cloudMap['updated_at'] is DateTime
          ? (cloudMap['updated_at'] as DateTime).toIso8601String()
          : cloudMap['updated_at']?.toString(),
    };

    final existing = await localDb.query(
      'companies',
      columns: ['company_guid'],
      where: 'company_guid = ?',
      whereArgs: [companyGuid],
    );

    if (existing.isEmpty) {
      localMap['is_selected']                        = 0;
      await localDb.insert('companies', localMap);
    } else {
      await localDb.update('companies', localMap,
          where: 'company_guid = ?', whereArgs: [companyGuid]);
    }
  }

  // ============================================================
  // STEP 2+3: SIMPLE FULL SYNC (groups, voucher_types)
  // Uses id-based cursor pagination — no OFFSET, no data loss risk
  // ============================================================

  Future<int> _fullSyncSimple(
    Database localDb,
    String schema,
    String tableName,
    String companyGuid,
  ) async {
    // ✅ Fetch ALL rows from cloud using id-based cursor (no OFFSET)
    final cloudRows = await _fetchAllRowsById(
      schema, tableName,
      whereClause: "company_guid = '$companyGuid'",
      stripTableName: tableName,
    );

    // ✅ Atomic delete+insert only after successful fetch
    await localDb.transaction((txn) async {
      await txn.delete(tableName,
          where: 'company_guid = ?', whereArgs: [companyGuid]);

      const batchSize = 200;
      for (int i = 0; i < cloudRows.length; i += batchSize) {
        final batch = txn.batch();
        final end = (i + batchSize).clamp(0, cloudRows.length);
        for (int j = i; j < end; j++) {
          batch.insert(tableName, cloudRows[j],
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });

    print('  ✅ $tableName: ${cloudRows.length} (full, id-cursor)');
    return cloudRows.length;
  }

  // ============================================================
  // STEP 4: LEDGER GROUP
  // ============================================================

  Future<Map<String, int>> _syncLedgerGroup(
    Database localDb,
    String schema,
    String companyGuid,
  ) async {
    final counts = <String, int>{
      'ledgers': 0,
      'ledger_closing_balances': 0,
      'ledger_contacts': 0,
      'ledger_mailing_details': 0,
      'ledger_gst_registrations': 0,
    };

    final lastAlterId = await DatabaseHelper.instance.getLastAlterId( companyGuid, 'ledgers');
    final isFullSync = lastAlterId == 0;

    final syncResult = await _syncParentByAlterId(
      localDb, schema, 'ledgers', 'ledger_guid', companyGuid, lastAlterId,
    );
    counts['ledgers'] = syncResult.totalSynced;

    if (syncResult.totalSynced == 0 && !isFullSync) {
      print('  ℹ️ ledger group: no changes');
      return counts;
    }

    final childResults = await Future.wait([
      _syncChildByParentGuids(localDb, schema,
          tableName: 'ledger_closing_balances',
          parentGuidCol: 'ledger_guid',
          companyGuid: companyGuid,
          updatedGuids: syncResult.updatedGuids,
          isFullSync: isFullSync,
          orderBy: 'id'),
      _syncChildByParentGuids(localDb, schema,
          tableName: 'ledger_contacts',
          parentGuidCol: 'ledger_guid',
          companyGuid: companyGuid,
          updatedGuids: syncResult.updatedGuids,
          isFullSync: isFullSync,
          orderBy: 'id'),
      _syncChildByParentGuids(localDb, schema,
          tableName: 'ledger_mailing_details',
          parentGuidCol: 'ledger_guid',
          companyGuid: companyGuid,
          updatedGuids: syncResult.updatedGuids,
          isFullSync: isFullSync,
          orderBy: 'id'),
      _syncChildByParentGuids(localDb, schema,
          tableName: 'ledger_gst_registrations',
          parentGuidCol: 'ledger_guid',
          companyGuid: companyGuid,
          updatedGuids: syncResult.updatedGuids,
          isFullSync: isFullSync,
          orderBy: 'id'),
    ]);

    counts['ledger_closing_balances']  = childResults[0];
    counts['ledger_contacts']          = childResults[1];
    counts['ledger_mailing_details']   = childResults[2];
    counts['ledger_gst_registrations'] = childResults[3];


    return counts;
  }

  // ============================================================
  // STEP 5: STOCK ITEM GROUP
  // ============================================================

  Future<Map<String, int>> _syncStockItemGroup(
    Database localDb,
    String schema,
    String companyGuid,
  ) async {
    final counts = <String, int>{
      'stock_items': 0,
      'stock_item_closing_balance': 0,
      'stock_item_hsn_history': 0,
      'stock_item_batch_allocation': 0,
      'stock_item_gst_history': 0,
    };

    final lastAlterId = await DatabaseHelper.instance.getLastAlterId(companyGuid, 'stock_items');
    final isFullSync = lastAlterId == 0;

    final syncResult = await _syncParentByAlterId(
      localDb, schema, 'stock_items', 'stock_item_guid', companyGuid, lastAlterId,
    );
    counts['stock_items'] = syncResult.totalSynced;

    if (syncResult.totalSynced == 0 && !isFullSync) {
      print('  ℹ️ stock item group: no changes');
      return counts;
    }

    final childResults = await Future.wait([
      _syncChildByParentGuids(localDb, schema,
          tableName: 'stock_item_closing_balance',
          parentGuidCol: 'stock_item_guid',
          companyGuid: companyGuid,
          updatedGuids: syncResult.updatedGuids,
          isFullSync: isFullSync,
          orderBy: 'id'),
      _syncChildByParentGuids(localDb, schema,
          tableName: 'stock_item_hsn_history',
          parentGuidCol: 'stock_item_guid',
          companyGuid: companyGuid,
          updatedGuids: syncResult.updatedGuids,
          isFullSync: isFullSync,
          orderBy: 'id'),
      _syncChildByParentGuids(localDb, schema,
          tableName: 'stock_item_batch_allocation',
          parentGuidCol: 'stock_item_guid',
          companyGuid: companyGuid,
          updatedGuids: syncResult.updatedGuids,
          isFullSync: isFullSync,
          orderBy: 'id'),
      _syncChildByParentGuids(localDb, schema,
          tableName: 'stock_item_gst_history',
          parentGuidCol: 'stock_item_guid',
          companyGuid: companyGuid,
          updatedGuids: syncResult.updatedGuids,
          isFullSync: isFullSync,
          orderBy: 'id'),
    ]);

    counts['stock_item_closing_balance']  = childResults[0];
    counts['stock_item_hsn_history']      = childResults[1];
    counts['stock_item_batch_allocation'] = childResults[2];
    counts['stock_item_gst_history']      = childResults[3];

  

    return counts;
  }

  // ============================================================
  // STEP 6: VOUCHER GROUP
  // ============================================================

  Future<Map<String, int>> _syncVoucherGroup(
    Database localDb,
    String schema,
    String companyGuid,
  ) async {
    final counts = <String, int>{
      'vouchers': 0,
      'voucher_ledger_entries': 0,
      'voucher_inventory_entries': 0,
      'voucher_batch_allocations': 0,
    };

    final lastAlterId = await DatabaseHelper.instance.getLastAlterId(companyGuid, 'vouchers');
    final isFullSync = lastAlterId == 0;

    final syncResult = await _syncParentByAlterId(
      localDb, schema, 'vouchers', 'voucher_guid', companyGuid, lastAlterId,
    );
    counts['vouchers'] = syncResult.totalSynced;

    if (syncResult.totalSynced == 0 && !isFullSync) {
      print('  ℹ️ voucher group: no changes');
      return counts;
    }

    final vle = await _syncChildByParentGuids(localDb, schema,
        tableName: 'voucher_ledger_entries',
        parentGuidCol: 'voucher_guid',
        companyGuid: companyGuid,
        updatedGuids: syncResult.updatedGuids,
        isFullSync: isFullSync,
        orderBy: 'id');
    final vie = await _syncChildByParentGuids(localDb, schema,
        tableName: 'voucher_inventory_entries',
        parentGuidCol: 'voucher_guid',
        companyGuid: companyGuid,
        updatedGuids: syncResult.updatedGuids,
        isFullSync: isFullSync,
        orderBy: 'id');
    final vba = await _syncChildByParentGuids(localDb, schema,
        tableName: 'voucher_batch_allocations',
        parentGuidCol: 'voucher_guid',
        companyGuid: companyGuid,
        updatedGuids: syncResult.updatedGuids,
        isFullSync: isFullSync,
        orderBy: 'id');

    

    counts['voucher_ledger_entries']    = vle;
    counts['voucher_inventory_entries'] = vie;
    counts['voucher_batch_allocations'] = vba;

    if (!isFullSync && vie > 0) {
    await _resyncClosingBalancesForAffectedStockItems(
      localDb, schema, companyGuid, syncResult.updatedGuids);
  }

    return counts;
  }

  Future<void> _resyncClosingBalancesForAffectedStockItems(
  Database localDb,
  String schema,
  String companyGuid,
  List<String> voucherGuids,
) async {
  if (voucherGuids.isEmpty) return;

  // Step 1: Get distinct stock_item_guids from local inventory entries
  // for the vouchers we just synced
  final inList = voucherGuids.map((g) => "'$g'").join(',');
  final rows = await localDb.rawQuery('''
    SELECT DISTINCT stock_item_guid
    FROM voucher_inventory_entries
    WHERE voucher_guid IN ($inList)
      AND stock_item_guid IS NOT NULL
      AND stock_item_guid != ''
  ''');

  if (rows.isEmpty) return;

  final stockItemGuids = rows
      .map((r) => r['stock_item_guid'] as String?)
      .whereType<String>()
      .toList();

  print('  🔄 Re-syncing closing balances for ${stockItemGuids.length} stock items...');

  // Step 2: Fetch closing balances from cloud for those stock item guids
  // Process in batches of 500
  int totalSynced = 0;
  for (int i = 0; i < stockItemGuids.length; i += 500) {
    final guidBatch = stockItemGuids.sublist(
        i, (i + 500).clamp(0, stockItemGuids.length));
    final guidInList = guidBatch.map((g) => "'$g'").join(',');

    final cloudRows = await _fetchAllRowsById(
      schema, 'stock_item_closing_balance',
      whereClause: "stock_item_guid IN ($guidInList)",
      stripTableName: null,
    );

    // Step 3: Delete + insert locally
    await localDb.transaction((txn) async {
      await txn.rawDelete('''
        DELETE FROM stock_item_closing_balance
        WHERE stock_item_guid IN ($guidInList)
      ''');

      const batchSize = 200;
      for (int k = 0; k < cloudRows.length; k += batchSize) {
        final batch = txn.batch();
        final end = (k + batchSize).clamp(0, cloudRows.length);
        for (int j = k; j < end; j++) {
          batch.insert('stock_item_closing_balance', cloudRows[j],
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });

    totalSynced += cloudRows.length;
  }

  print('  ✅ stock_item_closing_balance: $totalSynced rows re-synced after voucher update');
}

  // ============================================================
  // CORE: PARENT SYNC BY ALTER_ID
  // Full sync path uses id-based cursor internally via _fetchAllRowsById
  // ============================================================

  Future<_ParentSyncResult> _syncParentByAlterId(
    Database localDb,
    String schema,
    String tableName,
    String guidColumn,
    String companyGuid,
    int lastAlterId,
  ) async {
    final isFullSync = lastAlterId == 0;

    // For full sync: fetch first using id-cursor, then atomic delete+insert
    if (isFullSync) {
      final cloudRows = await _fetchAllRowsById(
        schema, tableName,
        whereClause: "company_guid = '$companyGuid'",
        stripTableName: tableName,
      );

      int maxAlterIdSeen = 0;
      final updatedGuids = <String>[];

      for (final map in cloudRows) {
        final alterId = map['alter_id'];
        if (alterId is int && alterId > maxAlterIdSeen) maxAlterIdSeen = alterId;
        final guid = map[guidColumn];
        if (guid is String) updatedGuids.add(guid);
      }

      await localDb.transaction((txn) async {
        await txn.delete(tableName,
            where: 'company_guid = ?', whereArgs: [companyGuid]);

        const batchSize = 500;
        for (int i = 0; i < cloudRows.length; i += batchSize) {
          final batch = txn.batch();
          final end = (i + batchSize).clamp(0, cloudRows.length);
          for (int j = i; j < end; j++) {
            batch.insert(tableName, cloudRows[j],
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }
      });

      print('  ✅ $tableName: ${cloudRows.length} (full, id-cursor → alter_id cursor $maxAlterIdSeen)');

      return _ParentSyncResult(
        totalSynced: cloudRows.length,
        maxAlterIdSeen: maxAlterIdSeen,
        updatedGuids: updatedGuids,
      );
    }

    // Incremental sync: alter_id based (unchanged)
    int maxAlterIdSeen = lastAlterId;
    int totalSynced    = 0;
    int chunkCount     = 0;
    final updatedGuids = <String>[];

    Connection current = await _openConnection();
    try {
      while (true) {
        if (chunkCount > 0 && chunkCount % _recycleEveryChunks == 0) {
          print('  🔄 $tableName: recycling connection at $totalSynced rows...');
          try { await current.close(); } catch (_) {}
          current = await _openConnection();
        }

        final exec = await _executeWithRetry(current, '''
          SELECT * FROM $schema.$tableName
          WHERE company_guid = '$companyGuid'
            AND alter_id > $maxAlterIdSeen
          ORDER BY alter_id ASC
          LIMIT $_fetchSize
        ''');
        current = exec.conn;
        if (exec.rows.isEmpty) break;

        const batchSize = 500;
        for (int i = 0; i < exec.rows.length; i += batchSize) {
          final batch = localDb.batch();
          final end = (i + batchSize).clamp(0, exec.rows.length);
          for (int j = i; j < end; j++) {
            final map = _resultRowToMap(exec.rows[j], exec.rows.schema,
                tableName: tableName);
            final alterId = map['alter_id'];
            if (alterId is int && alterId > maxAlterIdSeen) maxAlterIdSeen = alterId;
            final guid = map[guidColumn];
            if (guid is String) updatedGuids.add(guid);
            batch.insert(tableName, map,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }

        totalSynced += exec.rows.length;
        chunkCount++;
        print('  📥 $tableName: $totalSynced rows...');
        if (exec.rows.length < _fetchSize) break;
      }
    } finally {
      try { await current.close(); } catch (_) {}
    }

    print('  ✅ $tableName: $totalSynced (incremental from alter_id $lastAlterId → $maxAlterIdSeen)');

    return _ParentSyncResult(
      totalSynced: totalSynced,
      maxAlterIdSeen: maxAlterIdSeen,
      updatedGuids: updatedGuids,
    );
  }

  // ============================================================
  // CORE: CHILD SYNC BY PARENT GUIDS
  // Full sync uses id-based cursor; incremental uses IN list
  // ============================================================

  Future<int> _syncChildByParentGuids(
    Database localDb,
    String schema, {
    required String tableName,
    required String parentGuidCol,
    required String companyGuid,
    required List<String> updatedGuids,
    required bool isFullSync,
    required String orderBy, // now always 'id'
  }) async {
    if (!isFullSync && updatedGuids.isEmpty) return 0;

    int totalSynced = 0;

    if (isFullSync) {
      // ✅ Fetch all using id-cursor (no OFFSET)
      final cloudRows = await _fetchAllRowsById(
        schema, tableName,
        whereClause: "company_guid = '$companyGuid'",
        stripTableName: tableName,
      );

      await localDb.transaction((txn) async {
        await txn.delete(tableName,
            where: 'company_guid = ?', whereArgs: [companyGuid]);

        const batchSize = 200;
        for (int i = 0; i < cloudRows.length; i += batchSize) {
          final batch = txn.batch();
          final end = (i + batchSize).clamp(0, cloudRows.length);
          for (int j = i; j < end; j++) {
            batch.insert(tableName, cloudRows[j],
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }
      });

      totalSynced = cloudRows.length;
    } else {
      // Incremental: process in 500-guid batches
      for (int i = 0; i < updatedGuids.length; i += 500) {
        final guidBatch =
            updatedGuids.sublist(i, (i + 500).clamp(0, updatedGuids.length));
        final inList = guidBatch.map((g) => "'$g'").join(',');

        // Fetch using id-cursor for this batch
        final cloudRows = await _fetchAllRowsById(
          schema, tableName,
          whereClause: "$parentGuidCol IN ($inList)",
          stripTableName: tableName,
        );

        await localDb.transaction((txn) async {
          await txn.rawDelete(
            'DELETE FROM $tableName WHERE $parentGuidCol IN ($inList)',
          );

          const batchSize = 200;
          for (int k = 0; k < cloudRows.length; k += batchSize) {
            final batch = txn.batch();
            final end = (k + batchSize).clamp(0, cloudRows.length);
            for (int j = k; j < end; j++) {
              batch.insert(tableName, cloudRows[j],
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
          }
        });

        totalSynced += cloudRows.length;
      }
    }

    print('  ✅ $tableName: $totalSynced (${isFullSync ? 'full' : 'incremental'})');
    return totalSynced;
  }

  // ============================================================
  // CORE FETCH: ID-BASED CURSOR PAGINATION
  // Much faster than OFFSET — no rows re-scanned on each page
  // ============================================================

  /// Fetches all rows from cloud using id-based cursor pagination.
  /// Much faster than OFFSET — PostgreSQL doesn't re-scan previous pages.
  /// [stripTableName] controls whether cloud SERIAL id is removed before returning.
  Future<List<Map<String, dynamic>>> _fetchAllRowsById(
    String schema,
    String table, {
    required String whereClause,
    String? stripTableName,
  }) async {
    final allRows = <Map<String, dynamic>>[];
    int lastId = 0;
    int chunkCount = 0;

    Connection conn = await _openConnection();
    try {
      while (true) {
        if (chunkCount > 0 && chunkCount % _recycleEveryChunks == 0) {
          print('  🔄 $table: recycling connection at ${allRows.length} rows...');
          try { await conn.close(); } catch (_) {}
          conn = await _openConnection();
        }

        final exec = await _executeWithRetry(conn, '''
          SELECT * FROM $schema.$table
          WHERE ($whereClause) AND id > $lastId
          ORDER BY id ASC
          LIMIT $_fetchSize
        ''');
        conn = exec.conn;
        if (exec.rows.isEmpty) break;

        // Find id column index once per chunk
        final idColIdx = exec.rows.schema.columns
            .indexWhere((c) => c.columnName == 'id');

        for (final row in exec.rows) {
          // Track last id BEFORE stripping
          if (idColIdx >= 0) {
            final rowId = row[idColIdx];
            if (rowId is int && rowId > lastId) lastId = rowId;
          }
          final map = _resultRowToMap(row, exec.rows.schema,
              tableName: stripTableName);
          allRows.add(map);
        }

        chunkCount++;
        if (exec.rows.length < _fetchSize) break;
      }
    } finally {
      try { await conn.close(); } catch (_) {}
    }

    return allRows;
  }

  // ============================================================
  // FETCH HELPERS (UI use — no local save)
  // ============================================================

  Future<List<Map<String, dynamic>>> fetchCompaniesFromCloud(
      {String? userId}) async {
    final conn = await _openConnection();
    try {
      final sql = userId != null
          ? '''
              SELECT company_guid, company_name, gsttin, pan, state, city,
                     starting_from, ending_at, currency_name,
                     maintain_inventory, is_gst_applicable,
                     created_at, updated_at
              FROM user_data.companies
              WHERE is_deleted = 0 AND user_id = '$userId'
              ORDER BY company_name
            '''
          : '''
              SELECT company_guid, company_name, gsttin, pan, state, city,
                     starting_from, ending_at, currency_name,
                     maintain_inventory, is_gst_applicable,
                     created_at, updated_at
              FROM user_data.companies
              WHERE is_deleted = 0
              ORDER BY company_name
            ''';
      final exec = await _executeWithRetry(conn, sql);
      if (!identical(conn, exec.conn)) {
        try { await exec.conn.close(); } catch (_) {}
      }
      return exec.rows
          .map((row) => _resultRowToMap(row, exec.rows.schema))
          .toList();
    } finally {
      try { await conn.close(); } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> fetchVouchersFromCloud(
    String companyGuid, {
    String? voucherType,
    String? dateFrom,
    String? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    final schema = _getSchemaName(companyGuid);
    final conn = await _openConnection();
    try {
      final whereParts = <String>[];
      if (voucherType != null) whereParts.add("voucher_type = '$voucherType'");
      if (dateFrom != null) whereParts.add("date >= '$dateFrom'");
      if (dateTo != null) whereParts.add("date <= '$dateTo'");
      final whereStr = whereParts.isEmpty ? '1=1' : whereParts.join(' AND ');
      final exec = await _executeWithRetry(conn, '''
        SELECT voucher_guid, voucher_number, date, voucher_type,
               party_ledger_name, amount, total_amount, narration
        FROM $schema.vouchers
        WHERE $whereStr
        ORDER BY date DESC
        LIMIT $limit OFFSET $offset
      ''');
      if (!identical(conn, exec.conn)) {
        try { await exec.conn.close(); } catch (_) {}
      }
      return exec.rows
          .map((row) => _resultRowToMap(row, exec.rows.schema))
          .toList();
    } finally {
      try { await conn.close(); } catch (_) {}
    }
  }

  Future<void> dispose() async {}
}

// ============================================================
// SYNC RESULT
// ============================================================

class SyncResult {
  bool success = false;
  String? error;

  int companies              = 0;
  int groups                 = 0;
  int voucherTypes           = 0;
  int ledgers                = 0;
  int ledgerClosingBalances  = 0;
  int ledgerContacts         = 0;
  int ledgerMailingDetails   = 0;
  int ledgerGstRegistrations = 0;
  int stockItems             = 0;
  int stockClosingBalances   = 0;
  int stockHsnHistory        = 0;
  int stockBatchAllocation   = 0;
  int stockGstHistory        = 0;
  int vouchers               = 0;
  int ledgerEntries          = 0;
  int inventoryEntries       = 0;
  int batchAllocations       = 0;

  int get totalRecords =>
      companies + groups + voucherTypes +
      ledgers + ledgerClosingBalances + ledgerContacts +
      ledgerMailingDetails + ledgerGstRegistrations +
      stockItems + stockClosingBalances + stockHsnHistory +
      stockBatchAllocation + stockGstHistory +
      vouchers + ledgerEntries + inventoryEntries + batchAllocations;

  @override
  String toString() => '''
SyncResult {
  success: $success${error != null ? '\n  error: $error' : ''}
  ── Full every run ──────────────────────────
  companies:                  $companies
  groups:                     $groups
  voucherTypes:               $voucherTypes
  ── Ledger group ────────────────────────────
  ledgers:                    $ledgers
  ledgerClosingBalances:      $ledgerClosingBalances
  ledgerContacts:             $ledgerContacts
  ledgerMailingDetails:       $ledgerMailingDetails
  ledgerGstRegistrations:     $ledgerGstRegistrations
  ── Stock item group ────────────────────────
  stockItems:                 $stockItems
  stockClosingBalances:       $stockClosingBalances
  stockHsnHistory:            $stockHsnHistory
  stockBatchAllocation:       $stockBatchAllocation
  stockGstHistory:            $stockGstHistory
  ── Voucher group ───────────────────────────
  vouchers:                   $vouchers
  ledgerEntries:              $ledgerEntries
  inventoryEntries:           $inventoryEntries
  batchAllocations:           $batchAllocations
  ────────────────────────────────────────────
  total:                      $totalRecords
}''';
}