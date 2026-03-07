import 'package:postgres/postgres.dart';
import 'package:sqflite/sqflite.dart';
import '../config/api_config.dart';

/// Syncs data FROM AWS Aurora cloud database TO local SQLite
/// Supports both full sync and incremental sync
class CloudToLocalSyncService {
  static final CloudToLocalSyncService instance = CloudToLocalSyncService._init();
  Connection? _connection;
  bool _isConnecting = false;

  CloudToLocalSyncService._init();

  // ============================================================
  // CONNECTION MANAGEMENT
  // ============================================================

  Future<void> _ensureConnection() async {
    if (_isConnecting) {
      while (_isConnecting) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_connection != null) return;
    }

    if (_connection != null) {
      try {
        await _connection!.execute('SELECT 1');
        return;
      } catch (_) {
        await _closeConnection();
      }
    }

    _isConnecting = true;
    try {
      _connection = await Connection.open(
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
          queryTimeout: const Duration(seconds: 120),
        ),
      );
      print('✅ Cloud connection established');
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _closeConnection() async {
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
  }

  Future<void> dispose() async {
    await _closeConnection();
  }

  String _getSchemaName(String companyGuid) {
    return 'company_${companyGuid.replaceAll('-', '_')}';
  }

  // ============================================================
  // SYNC STATUS TRACKING
  // ============================================================

  /// Get last sync timestamp from local DB
  Future<String?> _getLastSyncTime(Database localDb, String companyGuid, String tableName) async {
    try {
      final result = await localDb.query(
        'sync_status',
        where: 'company_guid = ? AND table_name = ?',
        whereArgs: [companyGuid, tableName],
      );
      if (result.isNotEmpty) {
        return result.first['last_synced_at'] as String?;
      }
    } catch (_) {
      // Table might not exist yet
    }
    return null;
  }

  /// Update last sync timestamp in local DB
  Future<void> _updateSyncTime(Database localDb, String companyGuid, String tableName) async {
    final now = DateTime.now().toIso8601String();
    await localDb.insert(
      'sync_status',
      {
        'company_guid': companyGuid,
        'table_name': tableName,
        'last_synced_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Create sync_status table if not exists
  Future<void> ensureSyncStatusTable(Database localDb) async {
    await localDb.execute('''
      CREATE TABLE IF NOT EXISTS sync_status (
        company_guid TEXT NOT NULL,
        table_name TEXT NOT NULL,
        last_synced_at TEXT NOT NULL,
        PRIMARY KEY (company_guid, table_name)
      )
    ''');
  }

  // ============================================================
  // FULL SYNC — Downloads ALL data from cloud to local
  // ============================================================

  /// Full sync: downloads everything for a company
  Future<SyncResult> fullSync(Database localDb, String companyGuid, {
    Function(String status, double progress)? onProgress,
  }) async {
    await _ensureConnection();
    await ensureSyncStatusTable(localDb);

    final result = SyncResult();
    final schema = _getSchemaName(companyGuid);
    int step = 0;
    const totalSteps = 10;

    try {
      // Step 1: Sync company info
      step++;
      onProgress?.call('Syncing company info...', step / totalSteps);
      result.companies = await _syncCompanyFromCloud(localDb, companyGuid);

      // Step 2: Sync groups
      step++;
      onProgress?.call('Syncing groups...', step / totalSteps);
      result.groups = await _syncTableFromCloud(
        localDb, schema, 'groups', 'group_guid', companyGuid,
      );

      // Step 3: Sync voucher types
      step++;
      onProgress?.call('Syncing voucher types...', step / totalSteps);
      result.voucherTypes = await _syncVoucherTypesFromCloud(
        localDb, schema, companyGuid,
      );

      // Step 4: Sync ledgers
      step++;
      onProgress?.call('Syncing ledgers...', step / totalSteps);
      result.ledgers = await _syncTableFromCloud(
        localDb, schema, 'ledgers', 'ledger_guid', companyGuid,
      );

      // Step 5: Sync stock items
      step++;
      onProgress?.call('Syncing stock items...', step / totalSteps);
      result.stockItems = await _syncTableFromCloud(
        localDb, schema, 'stock_items', 'stock_item_guid', companyGuid,
      );

      // Step 6: Sync vouchers
      step++;
      onProgress?.call('Syncing vouchers...', step / totalSteps);
      result.vouchers = await _syncTableFromCloud(
        localDb, schema, 'vouchers', 'voucher_guid', companyGuid,
      );

      // Step 7: Sync voucher ledger entries
      step++;
      onProgress?.call('Syncing ledger entries...', step / totalSteps);
      result.ledgerEntries = await _syncChildTableFromCloud(
        localDb, schema, 'voucher_ledger_entries', companyGuid,
      );

      // Step 8: Sync voucher inventory entries
      step++;
      onProgress?.call('Syncing inventory entries...', step / totalSteps);
      result.inventoryEntries = await _syncChildTableFromCloud(
        localDb, schema, 'voucher_inventory_entries', companyGuid,
      );

      // Step 9: Sync voucher batch allocations
      step++;
      onProgress?.call('Syncing batch allocations...', step / totalSteps);
      result.batchAllocations = await _syncChildTableFromCloud(
        localDb, schema, 'voucher_batch_allocations', companyGuid,
      );

      // Step 10: Sync closing balances
      step++;
      onProgress?.call('Syncing closing balances...', step / totalSteps);
      result.closingBalances = await _syncChildTableFromCloud(
        localDb, schema, 'ledger_closing_balances', companyGuid,
      );
      result.stockClosingBalances = await _syncChildTableFromCloud(
        localDb, schema, 'stock_item_closing_balance', companyGuid,
      );

      result.success = true;
      onProgress?.call('Sync complete!', 1.0);
      print('✅ Full sync complete: ${result.totalRecords} records');
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      print('❌ Full sync failed: $e');
    }

    return result;
  }

  // ============================================================
  // INCREMENTAL SYNC — Only downloads changed data
  // ============================================================

  /// Incremental sync: only fetches records updated after last sync
  Future<SyncResult> incrementalSync(Database localDb, String companyGuid, {
    Function(String status, double progress)? onProgress,
  }) async {
    await _ensureConnection();
    await ensureSyncStatusTable(localDb);

    final result = SyncResult();
    final schema = _getSchemaName(companyGuid);
    int step = 0;
    const totalSteps = 7;

    try {
      // Step 1: Sync company info (always full)
      step++;
      onProgress?.call('Checking company updates...', step / totalSteps);
      result.companies = await _syncCompanyFromCloud(localDb, companyGuid);

      // Step 2: Incremental groups
      step++;
      onProgress?.call('Syncing updated groups...', step / totalSteps);
      final lastGroupSync = await _getLastSyncTime(localDb, companyGuid, 'groups');
      result.groups = await _syncTableFromCloud(
        localDb, schema, 'groups', 'group_guid', companyGuid,
        updatedAfter: lastGroupSync,
      );
      await _updateSyncTime(localDb, companyGuid, 'groups');

      // Step 3: Incremental ledgers
      step++;
      onProgress?.call('Syncing updated ledgers...', step / totalSteps);
      final lastLedgerSync = await _getLastSyncTime(localDb, companyGuid, 'ledgers');
      result.ledgers = await _syncTableFromCloud(
        localDb, schema, 'ledgers', 'ledger_guid', companyGuid,
        updatedAfter: lastLedgerSync,
      );
      await _updateSyncTime(localDb, companyGuid, 'ledgers');

      // Step 4: Incremental stock items
      step++;
      onProgress?.call('Syncing updated stock items...', step / totalSteps);
      final lastStockSync = await _getLastSyncTime(localDb, companyGuid, 'stock_items');
      result.stockItems = await _syncTableFromCloud(
        localDb, schema, 'stock_items', 'stock_item_guid', companyGuid,
        updatedAfter: lastStockSync,
      );
      await _updateSyncTime(localDb, companyGuid, 'stock_items');

      // Step 5: Incremental vouchers
      step++;
      onProgress?.call('Syncing updated vouchers...', step / totalSteps);
      final lastVoucherSync = await _getLastSyncTime(localDb, companyGuid, 'vouchers');
      result.vouchers = await _syncTableFromCloud(
        localDb, schema, 'vouchers', 'voucher_guid', companyGuid,
        updatedAfter: lastVoucherSync,
      );
      await _updateSyncTime(localDb, companyGuid, 'vouchers');

      // Step 6: Re-sync child entries for updated vouchers
      step++;
      onProgress?.call('Syncing voucher entries...', step / totalSteps);
      if (result.vouchers > 0) {
        // If vouchers changed, re-sync their child entries
        result.ledgerEntries = await _syncChildTableFromCloud(
          localDb, schema, 'voucher_ledger_entries', companyGuid,
          updatedAfter: lastVoucherSync,
        );
        result.inventoryEntries = await _syncChildTableFromCloud(
          localDb, schema, 'voucher_inventory_entries', companyGuid,
          updatedAfter: lastVoucherSync,
        );
        result.batchAllocations = await _syncChildTableFromCloud(
          localDb, schema, 'voucher_batch_allocations', companyGuid,
          updatedAfter: lastVoucherSync,
        );
      }

      // Step 7: Sync closing balances (always full — small dataset)
      step++;
      onProgress?.call('Syncing closing balances...', step / totalSteps);
      result.closingBalances = await _syncChildTableFromCloud(
        localDb, schema, 'ledger_closing_balances', companyGuid,
      );
      result.stockClosingBalances = await _syncChildTableFromCloud(
        localDb, schema, 'stock_item_closing_balance', companyGuid,
      );

      result.success = true;
      onProgress?.call('Sync complete!', 1.0);
      print('✅ Incremental sync complete: ${result.totalRecords} updated records');
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      print('❌ Incremental sync failed: $e');
    }

    return result;
  }

  // ============================================================
  // CORE SYNC METHODS
  // ============================================================

  /// Sync company info from cloud to local
  // Future<int> _syncCompanyFromCloud(Database localDb, String companyGuid) async {
  //   final rows = await _connection!.execute(
  //     'SELECT * FROM user_data.companies WHERE company_guid = \$1',
  //     parameters: [companyGuid],
  //   );

  //   if (rows.isEmpty) return 0;

  //   for (final row in rows) {
  //     final map = _resultRowToMap(row, rows.schema);
  //     await localDb.insert('companies', map, conflictAlgorithm: ConflictAlgorithm.replace);
  //   }

  //   return rows.length;
  // }

  Future<int> _syncCompanyFromCloud(Database localDb, String companyGuid) async {
    final rows = await _connection!.execute(
      'SELECT * FROM user_data.companies WHERE company_guid = \$1',
      parameters: [companyGuid],
    );

    if (rows.isEmpty) return 0;

    for (final row in rows) {
      final map = _resultRowToMap(row, rows.schema);
      map.remove('user_id');  // ← ADD THIS LINE
      await localDb.insert('companies', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    return rows.length;
  }

  /// Sync a master table (groups, ledgers, stock_items, vouchers) from cloud
  Future<int> _syncTableFromCloud(
    Database localDb,
    String schema,
    String tableName,
    String primaryKey,
    String companyGuid, {
    String? updatedAfter,
  }) async {
    String sql;
    List<dynamic> params = [];

    if (updatedAfter != null) {
      sql = 'SELECT * FROM $schema.$tableName WHERE updated_at > \$1 ORDER BY updated_at';
      params = [updatedAfter];
    } else {
      sql = 'SELECT * FROM $schema.$tableName ORDER BY created_at';
    }

    final rows = await _connection!.execute(
      Sql.named(sql.replaceAll('\$1', '@p1')),
      parameters: params.isNotEmpty ? {'p1': params[0]} : {},
    );

    if (rows.isEmpty) return 0;

    // Batch insert/update locally
    final batch = localDb.batch();
    for (final row in rows) {
      final map = _resultRowToMap(row, rows.schema);
      batch.insert(tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    print('  📥 $tableName: ${rows.length} records ${updatedAfter != null ? "(incremental)" : "(full)"}');
    return rows.length;
  }

  /// Sync voucher types from cloud (has SERIAL id, needs special handling)
  Future<int> _syncVoucherTypesFromCloud(
    Database localDb,
    String schema,
    String companyGuid,
  ) async {
    final rows = await _connection!.execute(
      'SELECT * FROM $schema.voucher_types ORDER BY name',
    );

    if (rows.isEmpty) return 0;

    // Delete existing and re-insert (voucher types don't have a simple PK for upsert)
    await localDb.delete('voucher_types', where: 'company_guid = ?', whereArgs: [companyGuid]);

    final batch = localDb.batch();
    for (final row in rows) {
      final map = _resultRowToMap(row, rows.schema);
      map.remove('id'); // Remove SERIAL id, let SQLite auto-generate
      batch.insert('voucher_types', map);
    }
    await batch.commit(noResult: true);

    print('  📥 voucher_types: ${rows.length} records');
    return rows.length;
  }

  /// Sync child tables (ledger entries, inventory entries, batch allocations)
  /// These don't have a primary key, so we delete and re-insert
  Future<int> _syncChildTableFromCloud(
    Database localDb,
    String schema,
    String tableName,
    String companyGuid, {
    String? updatedAfter,
  }) async {
    String sql;

    if (updatedAfter != null && tableName.startsWith('voucher_')) {
      // For voucher child tables, sync entries belonging to updated vouchers
      sql = '''
        SELECT t.* FROM $schema.$tableName t
        JOIN $schema.vouchers v ON t.voucher_guid = v.voucher_guid
        WHERE v.updated_at > '$updatedAfter'
      ''';
    } else {
      sql = 'SELECT * FROM $schema.$tableName WHERE company_guid = \'$companyGuid\'';
    }

    final rows = await _connection!.execute(sql);

    if (rows.isEmpty) return 0;

    // For child tables: delete existing for this company and re-insert
    if (updatedAfter == null) {
      await localDb.delete(tableName, where: 'company_guid = ?', whereArgs: [companyGuid]);
    }

    // Batch insert
    const batchSize = 500;
    for (int i = 0; i < rows.length; i += batchSize) {
      final batch = localDb.batch();
      final end = (i + batchSize > rows.length) ? rows.length : i + batchSize;

      for (int j = i; j < end; j++) {
        final map = _resultRowToMap(rows[j], rows.schema);
        batch.insert(tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }

    print('  📥 $tableName: ${rows.length} records');
    return rows.length;
  }

  // ============================================================
  // FETCH COMPANIES LIST (without saving locally)
  // ============================================================

  /// Fetch list of companies from cloud (for company selection screen)
  Future<List<Map<String, dynamic>>> fetchCompaniesFromCloud({String? userId}) async {
    await _ensureConnection();

    if (userId != null) {
      final rows = await _connection!.execute(
        'SELECT company_guid, company_name, gsttin, pan, state, city, starting_from, ending_at, currency_name, maintain_inventory, is_gst_applicable, created_at, updated_at FROM user_data.companies WHERE is_deleted = 0 AND user_id = \$1 ORDER BY company_name',
        parameters: [userId],
      );
      return rows.map((row) => _resultRowToMap(row, rows.schema)).toList();
    }

    final rows = await _connection!.execute('''
      SELECT company_guid, company_name, gsttin, pan, state, city,
             starting_from, ending_at, currency_name,
             maintain_inventory, is_gst_applicable,
             created_at, updated_at
      FROM user_data.companies
      WHERE is_deleted = 0
      ORDER BY company_name
    ''');

    return rows.map((row) => _resultRowToMap(row, rows.schema)).toList();
  }

  // ============================================================
  // FETCH SINGLE TABLE DATA (without saving locally)
  // ============================================================

  /// Fetch vouchers from cloud for a company
  Future<List<Map<String, dynamic>>> fetchVouchersFromCloud(
    String companyGuid, {
    String? voucherType,
    String? dateFrom,
    String? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    await _ensureConnection();
    final schema = _getSchemaName(companyGuid);

    final whereParts = <String>['is_deleted = 0'];
    if (voucherType != null) whereParts.add("voucher_type = '$voucherType'");
    if (dateFrom != null) whereParts.add("date >= '$dateFrom'");
    if (dateTo != null) whereParts.add("date <= '$dateTo'");

    final where = whereParts.join(' AND ');

    final rows = await _connection!.execute('''
      SELECT voucher_guid, voucher_number, date, voucher_type,
             party_ledger_name, amount, total_amount, narration
      FROM $schema.vouchers
      WHERE $where
      ORDER BY date DESC
      LIMIT $limit OFFSET $offset
    ''');

    return rows.map((row) => _resultRowToMap(row, rows.schema)).toList();
  }

  /// Fetch dashboard summary from cloud
  Future<Map<String, dynamic>> fetchDashboardFromCloud(String companyGuid) async {
    await _ensureConnection();
    final schema = _getSchemaName(companyGuid);

    final voucherCount = (await _connection!.execute(
      'SELECT COUNT(*) as cnt FROM $schema.vouchers WHERE is_deleted = 0',
    )).first[0] as int;

    final ledgerCount = (await _connection!.execute(
      'SELECT COUNT(*) as cnt FROM $schema.ledgers WHERE is_deleted = 0',
    )).first[0] as int;

    final stockCount = (await _connection!.execute(
      'SELECT COUNT(*) as cnt FROM $schema.stock_items WHERE is_deleted = 0',
    )).first[0] as int;

    final groupCount = (await _connection!.execute(
      'SELECT COUNT(*) as cnt FROM $schema.groups WHERE is_deleted = 0',
    )).first[0] as int;

    // Voucher type breakdown
    final typeRows = await _connection!.execute('''
      SELECT voucher_type, COUNT(*) as count, 
             COALESCE(SUM(ABS(amount)), 0) as total_amount
      FROM $schema.vouchers WHERE is_deleted = 0
      GROUP BY voucher_type ORDER BY count DESC
    ''');

    // Recent 10 vouchers
    final recentRows = await _connection!.execute('''
      SELECT voucher_number, date, voucher_type, party_ledger_name, amount
      FROM $schema.vouchers WHERE is_deleted = 0
      ORDER BY date DESC LIMIT 10
    ''');

    return {
      'counts': {
        'vouchers': voucherCount,
        'ledgers': ledgerCount,
        'stock_items': stockCount,
        'groups': groupCount,
      },
      'voucher_types': typeRows.map((r) => _resultRowToMap(r, typeRows.schema)).toList(),
      'recent_vouchers': recentRows.map((r) => _resultRowToMap(r, recentRows.schema)).toList(),
    };
  }

  // ============================================================
  // HELPER: Convert postgres ResultRow to Map
  // ============================================================

  Map<String, dynamic> _resultRowToMap(ResultRow row, ResultSchema schema) {
    final map = <String, dynamic>{};
    for (int i = 0; i < schema.columns.length; i++) {
      final colName = schema.columns[i].columnName;
      var value = row[i];

      // Convert DateTime to ISO string for SQLite compatibility
      if (value is DateTime) {
        value = value.toIso8601String();
      }

      map[colName ?? 'col_$i'] = value;
    }
    return map;
  }
}

// ============================================================
// SYNC RESULT
// ============================================================
class SyncResult {
  bool success = false;
  String? error;

  int companies = 0;
  int groups = 0;
  int voucherTypes = 0;
  int ledgers = 0;
  int stockItems = 0;
  int vouchers = 0;
  int ledgerEntries = 0;
  int inventoryEntries = 0;
  int batchAllocations = 0;
  int closingBalances = 0;
  int stockClosingBalances = 0;

  int get totalRecords =>
      companies + groups + voucherTypes + ledgers + stockItems +
      vouchers + ledgerEntries + inventoryEntries + batchAllocations +
      closingBalances + stockClosingBalances;

  @override
  String toString() {
    return '''
SyncResult {
  success: $success
  ${error != null ? 'error: $error' : ''}
  companies: $companies
  groups: $groups
  voucherTypes: $voucherTypes
  ledgers: $ledgers
  stockItems: $stockItems
  vouchers: $vouchers
  ledgerEntries: $ledgerEntries
  inventoryEntries: $inventoryEntries
  batchAllocations: $batchAllocations
  closingBalances: $closingBalances
  stockClosingBalances: $stockClosingBalances
  total: $totalRecords
}''';
  }
}