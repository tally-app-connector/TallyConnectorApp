// import 'package:postgres/postgres.dart';
// import 'package:sqflite/sqflite.dart';
// import '../config/api_config.dart';

// /// Syncs data FROM AWS Aurora cloud database TO local SQLite
// /// Supports both full sync and incremental sync
// class CloudToLocalSyncService {
//   static final CloudToLocalSyncService instance =
//       CloudToLocalSyncService._init();
//   Connection? _connection;
//   bool _isConnecting = false;

//   CloudToLocalSyncService._init();

//   // ============================================================
//   // CONNECTION MANAGEMENT
//   // ============================================================

//   Future<void> _ensureConnection() async {
//     if (_isConnecting) {
//       while (_isConnecting) {
//         await Future.delayed(const Duration(milliseconds: 100));
//       }
//       if (_connection != null) return;
//     }

//     if (_connection != null) {
//       try {
//         await _connection!.execute('SELECT 1');
//         return;
//       } catch (_) {
//         await _closeConnection();
//       }
//     }

//     _isConnecting = true;
//     try {
//       _connection = await Connection.open(
//         Endpoint(
//           host: AwsAuroraConfig.host,
//           port: AwsAuroraConfig.port,
//           database: AwsAuroraConfig.database,
//           username: AwsAuroraConfig.username,
//           password: AwsAuroraConfig.password,
//         ),
//         settings: ConnectionSettings(
//           sslMode: SslMode.require,
//           connectTimeout: const Duration(seconds: 30),
//           queryTimeout: const Duration(seconds: 120),
//         ),
//       );
//       print('✅ Cloud connection established');
//     } finally {
//       _isConnecting = false;
//     }
//   }

//   Future<void> _closeConnection() async {
//     try {
//       await _connection?.close();
//     } catch (_) {}
//     _connection = null;
//   }

//   Future<void> dispose() async {
//     await _closeConnection();
//   }

//   String _getSchemaName(String companyGuid) {
//     return 'company_${companyGuid.replaceAll('-', '_')}';
//   }

//   // ============================================================
//   // SYNC STATUS TRACKING
//   // ============================================================

//   /// Get last sync timestamp from local DB
//   Future<String?> _getLastSyncTime(
//       Database localDb, String companyGuid, String tableName) async {
//     try {
//       final result = await localDb.query(
//         'sync_status',
//         where: 'company_guid = ? AND table_name = ?',
//         whereArgs: [companyGuid, tableName],
//       );
//       if (result.isNotEmpty) {
//         return result.first['last_synced_at'] as String?;
//       }
//     } catch (_) {
//       // Table might not exist yet
//     }
//     return null;
//   }

//   /// Update last sync timestamp in local DB
//   Future<void> _updateSyncTime(
//       Database localDb, String companyGuid, String tableName) async {
//     final now = DateTime.now().toIso8601String();
//     await localDb.insert(
//       'sync_status',
//       {
//         'company_guid': companyGuid,
//         'table_name': tableName,
//         'last_synced_at': now,
//       },
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   /// Create sync_status table if not exists
//   Future<void> ensureSyncStatusTable(Database localDb) async {
//     await localDb.execute('''
//       CREATE TABLE IF NOT EXISTS sync_status (
//         company_guid TEXT NOT NULL,
//         table_name TEXT NOT NULL,
//         last_synced_at TEXT NOT NULL,
//         PRIMARY KEY (company_guid, table_name)
//       )
//     ''');
//   }

//   // ============================================================
//   // FULL SYNC — Downloads ALL data from cloud to local
//   // ============================================================

//   /// Full sync: downloads everything for a company
//   Future<SyncResult> fullSync(
//     Database localDb,
//     String companyGuid, {
//     Function(String status, double progress)? onProgress,
//   }) async {
//     await _ensureConnection();
//     await ensureSyncStatusTable(localDb);

//     final result = SyncResult();
//     final schema = _getSchemaName(companyGuid);
//     int step = 0;
//     const totalSteps = 10;

//     try {
//       // Step 1: Sync company info
//       step++;
//       onProgress?.call('Syncing company info...', step / totalSteps);
//       result.companies = await _syncCompanyFromCloud(localDb, companyGuid);

//       // Step 2: Sync groups
//       step++;
//       onProgress?.call('Syncing groups...', step / totalSteps);
//       result.groups = await _syncTableFromCloud(
//         localDb,
//         schema,
//         'groups',
//         'group_guid',
//         companyGuid,
//       );

//       // Step 3: Sync voucher types
//       step++;
//       onProgress?.call('Syncing voucher types...', step / totalSteps);
//       result.voucherTypes = await _syncVoucherTypesFromCloud(
//         localDb,
//         schema,
//         companyGuid,
//       );

//       // Step 4: Sync ledgers
//       step++;
//       onProgress?.call('Syncing ledgers...', step / totalSteps);
//       result.ledgers = await _syncTableFromCloud(
//         localDb,
//         schema,
//         'ledgers',
//         'ledger_guid',
//         companyGuid,
//       );

//       // Step 5: Sync stock items
//       step++;
//       onProgress?.call('Syncing stock items...', step / totalSteps);
//       result.stockItems = await _syncTableFromCloud(
//         localDb,
//         schema,
//         'stock_items',
//         'stock_item_guid',
//         companyGuid,
//       );

//       // Step 6: Sync vouchers
//       step++;
//       onProgress?.call('Syncing vouchers...', step / totalSteps);
//       result.vouchers = await _syncTableFromCloud(
//         localDb,
//         schema,
//         'vouchers',
//         'voucher_guid',
//         companyGuid,
//       );

//       // Step 7: Sync voucher ledger entries
//       step++;
//       onProgress?.call('Syncing ledger entries...', step / totalSteps);
//       result.ledgerEntries = await _syncChildTableFromCloud(
//         localDb,
//         schema,
//         'voucher_ledger_entries',
//         companyGuid,
//       );

//       // Step 8: Sync voucher inventory entries
//       step++;
//       onProgress?.call('Syncing inventory entries...', step / totalSteps);
//       result.inventoryEntries = await _syncChildTableFromCloud(
//         localDb,
//         schema,
//         'voucher_inventory_entries',
//         companyGuid,
//       );

//       // Step 9: Sync voucher batch allocations
//       step++;
//       onProgress?.call('Syncing batch allocations...', step / totalSteps);
//       result.batchAllocations = await _syncChildTableFromCloud(
//         localDb,
//         schema,
//         'voucher_batch_allocations',
//         companyGuid,
//       );

//       // Step 10: Sync closing balances
//       step++;
//       onProgress?.call('Syncing closing balances...', step / totalSteps);
//       result.closingBalances = await _syncChildTableFromCloud(
//         localDb,
//         schema,
//         'ledger_closing_balances',
//         companyGuid,
//       );
//       result.stockClosingBalances = await _syncChildTableFromCloud(
//         localDb,
//         schema,
//         'stock_item_closing_balance',
//         companyGuid,
//       );

//       result.success = true;
//       onProgress?.call('Sync complete!', 1.0);
//       print('✅ Full sync complete: ${result.totalRecords} records');
//     } catch (e) {
//       result.success = false;
//       result.error = e.toString();
//       print('❌ Full sync failed: $e');
//     }

//     return result;
//   }

//   // ============================================================
//   // INCREMENTAL SYNC — Only downloads changed data
//   // ============================================================

//   /// Incremental sync: only fetches records updated after last sync
//   Future<SyncResult> incrementalSync(
//     Database localDb,
//     String companyGuid, {
//     Function(String status, double progress)? onProgress,
//   }) async {
//     await _ensureConnection();
//     await ensureSyncStatusTable(localDb);

//     final result = SyncResult();
//     final schema = _getSchemaName(companyGuid);
//     int step = 0;
//     const totalSteps = 7;

//     try {
//       // Step 1: Sync company info (always full)
//       step++;
//       onProgress?.call('Checking company updates...', step / totalSteps);
//       result.companies = await _syncCompanyFromCloud(localDb, companyGuid);

//       // Step 2: Incremental groups
//       step++;
//       onProgress?.call('Syncing updated groups...', step / totalSteps);
//       final lastGroupSync =
//           await _getLastSyncTime(localDb, companyGuid, 'groups');
//       result.groups = await _syncTableFromCloud(
//         localDb,
//         schema,
//         'groups',
//         'group_guid',
//         companyGuid,
//         updatedAfter: lastGroupSync,
//       );
//       await _updateSyncTime(localDb, companyGuid, 'groups');

//       // Step 3: Incremental ledgers
//       step++;
//       onProgress?.call('Syncing updated ledgers...', step / totalSteps);
//       final lastLedgerSync =
//           await _getLastSyncTime(localDb, companyGuid, 'ledgers');
//       result.ledgers = await _syncTableFromCloud(
//         localDb,
//         schema,
//         'ledgers',
//         'ledger_guid',
//         companyGuid,
//         updatedAfter: lastLedgerSync,
//       );
//       await _updateSyncTime(localDb, companyGuid, 'ledgers');

//       // Step 4: Incremental stock items
//       step++;
//       onProgress?.call('Syncing updated stock items...', step / totalSteps);
//       final lastStockSync =
//           await _getLastSyncTime(localDb, companyGuid, 'stock_items');
//       result.stockItems = await _syncTableFromCloud(
//         localDb,
//         schema,
//         'stock_items',
//         'stock_item_guid',
//         companyGuid,
//         updatedAfter: lastStockSync,
//       );
//       await _updateSyncTime(localDb, companyGuid, 'stock_items');

//       // Step 5: Incremental vouchers
//       step++;
//       onProgress?.call('Syncing updated vouchers...', step / totalSteps);
//       final lastVoucherSync =
//           await _getLastSyncTime(localDb, companyGuid, 'vouchers');
//       result.vouchers = await _syncTableFromCloud(
//         localDb,
//         schema,
//         'vouchers',
//         'voucher_guid',
//         companyGuid,
//         updatedAfter: lastVoucherSync,
//       );
//       await _updateSyncTime(localDb, companyGuid, 'vouchers');

//       // Step 6: Re-sync child entries for updated vouchers
//       step++;
//       onProgress?.call('Syncing voucher entries...', step / totalSteps);
//       if (result.vouchers > 0) {
//         // If vouchers changed, re-sync their child entries
//         result.ledgerEntries = await _syncChildTableFromCloud(
//           localDb,
//           schema,
//           'voucher_ledger_entries',
//           companyGuid,
//           updatedAfter: lastVoucherSync,
//         );
//         result.inventoryEntries = await _syncChildTableFromCloud(
//           localDb,
//           schema,
//           'voucher_inventory_entries',
//           companyGuid,
//           updatedAfter: lastVoucherSync,
//         );
//         result.batchAllocations = await _syncChildTableFromCloud(
//           localDb,
//           schema,
//           'voucher_batch_allocations',
//           companyGuid,
//           updatedAfter: lastVoucherSync,
//         );
//       }

//       // Step 7: Sync closing balances (always full — small dataset)
//       step++;
//       onProgress?.call('Syncing closing balances...', step / totalSteps);
//       result.closingBalances = await _syncChildTableFromCloud(
//         localDb,
//         schema,
//         'ledger_closing_balances',
//         companyGuid,
//       );
//       result.stockClosingBalances = await _syncChildTableFromCloud(
//         localDb,
//         schema,
//         'stock_item_closing_balance',
//         companyGuid,
//       );

//       result.success = true;
//       onProgress?.call('Sync complete!', 1.0);
//       print(
//           '✅ Incremental sync complete: ${result.totalRecords} updated records');
//     } catch (e) {
//       result.success = false;
//       result.error = e.toString();
//       print('❌ Incremental sync failed: $e');
//     }

//     return result;
//   }

//   // ============================================================
//   // CORE SYNC METHODS
//   // ============================================================

//   /// Sync company info from cloud to local
//   // Future<int> _syncCompanyFromCloud(Database localDb, String companyGuid) async {
//   //   final rows = await _connection!.execute(
//   //     'SELECT * FROM user_data.companies WHERE company_guid = \$1',
//   //     parameters: [companyGuid],
//   //   );

//   //   if (rows.isEmpty) return 0;

//   //   for (final row in rows) {
//   //     final map = _resultRowToMap(row, rows.schema);
//   //     await localDb.insert('companies', map, conflictAlgorithm: ConflictAlgorithm.replace);
//   //   }

//   //   return rows.length;
//   // }

//   Future<int> _syncCompanyFromCloud(
//       Database localDb, String companyGuid) async {
//     await _closeConnection();
//     await _ensureConnection();

//     final rows = await _connection!.execute(
//       'SELECT * FROM user_data.companies WHERE company_guid = \$1',
//       parameters: [companyGuid],
//     );

//     if (rows.isEmpty) return 0;

//     for (final row in rows) {
//       final map = _resultRowToMap(row, rows.schema);
//       map.remove('user_id');
//       await localDb.insert('companies', map,
//           conflictAlgorithm: ConflictAlgorithm.replace);
//     }

//     return rows.length;
//   }

//   Future<int> _syncTableFromCloud(
//     Database localDb,
//     String schema,
//     String tableName,
//     String primaryKey,
//     String companyGuid, {
//     String? updatedAfter,
//   }) async {
//     int totalSynced = 0;
//     int offset = 0;
//     const fetchSize = 500; // smaller chunks for master tables

//     while (true) {
//       await _closeConnection();
//       await _ensureConnection();

//       String sql;

//       if (updatedAfter != null) {
//         sql = '''
//         SELECT * FROM $schema.$tableName
//         WHERE updated_at > '$updatedAfter'
//         ORDER BY updated_at
//         LIMIT $fetchSize OFFSET $offset
//       ''';
//       } else {
//         sql = '''
//         SELECT * FROM $schema.$tableName
//         ORDER BY created_at
//         LIMIT $fetchSize OFFSET $offset
//       ''';
//       }

//       final rows = await _connection!.execute(sql);
//       if (rows.isEmpty) break;

//       final batch = localDb.batch();
//       for (final row in rows) {
//         final map = _resultRowToMap(row, rows.schema);
//         batch.insert(tableName, map,
//             conflictAlgorithm: ConflictAlgorithm.replace);
//       }
//       await batch.commit(noResult: true);

//       totalSynced += rows.length;
//       print('  📥 $tableName: $totalSynced records synced...');

//       if (rows.length < fetchSize) break;
//       offset += fetchSize;
//     }

//     print(
//         '  ✅ $tableName: $totalSynced total records ${updatedAfter != null ? "(incremental)" : "(full)"}');
//     return totalSynced;
//   }

//   /// Sync voucher types from cloud (has SERIAL id, needs special handling)
//   Future<int> _syncVoucherTypesFromCloud(
//     Database localDb,
//     String schema,
//     String companyGuid,
//   ) async {
//     // Delete first before chunked fetch
//     await localDb.delete('voucher_types',
//         where: 'company_guid = ?', whereArgs: [companyGuid]);

//     int totalSynced = 0;
//     int offset = 0;
//     const fetchSize = 500;

//     while (true) {
//       await _closeConnection();
//       await _ensureConnection();

//       final rows = await _connection!.execute('''
//       SELECT * FROM $schema.voucher_types
//       ORDER BY name
//       LIMIT $fetchSize OFFSET $offset
//     ''');

//       if (rows.isEmpty) break;

//       final batch = localDb.batch();
//       for (final row in rows) {
//         final map = _resultRowToMap(row, rows.schema);
//         map.remove('id');
//         batch.insert('voucher_types', map);
//       }
//       await batch.commit(noResult: true);

//       totalSynced += rows.length;
//       print('  📥 voucher_types: $totalSynced records synced...');

//       if (rows.length < fetchSize) break;
//       offset += fetchSize;
//     }

//     print('  ✅ voucher_types: $totalSynced total records');
//     return totalSynced;
//   }

//   // /// Sync child tables (ledger entries, inventory entries, batch allocations)
//   // /// These don't have a primary key, so we delete and re-insert
//   // Future<int> _syncChildTableFromCloud(
//   //   Database localDb,
//   //   String schema,
//   //   String tableName,
//   //   String companyGuid, {
//   //   String? updatedAfter,
//   // }) async {
//   //   String sql;

//   //   if (updatedAfter != null && tableName.startsWith('voucher_')) {
//   //     // For voucher child tables, sync entries belonging to updated vouchers
//   //     sql = '''
//   //       SELECT t.* FROM $schema.$tableName t
//   //       JOIN $schema.vouchers v ON t.voucher_guid = v.voucher_guid
//   //       WHERE v.updated_at > '$updatedAfter'
//   //     ''';
//   //   } else {
//   //     sql = 'SELECT * FROM $schema.$tableName WHERE company_guid = \'$companyGuid\'';
//   //   }

//   //   final rows = await _connection!.execute(sql);

//   //   if (rows.isEmpty) return 0;

//   //   // For child tables: delete existing for this company and re-insert
//   //   if (updatedAfter == null) {
//   //     await localDb.delete(tableName, where: 'company_guid = ?', whereArgs: [companyGuid]);
//   //   }

//   //   // Batch insert
//   //   const batchSize = 500;
//   //   for (int i = 0; i < rows.length; i += batchSize) {
//   //     final batch = localDb.batch();
//   //     final end = (i + batchSize > rows.length) ? rows.length : i + batchSize;

//   //     for (int j = i; j < end; j++) {
//   //       final map = _resultRowToMap(rows[j], rows.schema);
//   //       batch.insert(tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
//   //     }
//   //     await batch.commit(noResult: true);
//   //   }

//   //   print('  📥 $tableName: ${rows.length} records');
//   //   return rows.length;
//   // }

//   Future<int> _syncChildTableFromCloud(
//     Database localDb,
//     String schema,
//     String tableName,
//     String companyGuid, {
//     String? updatedAfter,
//   }) async {
//     const voucherChildTables = {
//       'voucher_ledger_entries',
//       'voucher_inventory_entries',
//       'voucher_batch_allocations',
//     };
//     const closingBalanceTables = {
//       'ledger_closing_balances',
//       'stock_item_closing_balance',
//     };

//     // Delete strategy
//     if (updatedAfter == null) {
//       // Full sync — always delete all for this company
//       await localDb.delete(tableName,
//           where: 'company_guid = ?', whereArgs: [companyGuid]);
//     } else if (voucherChildTables.contains(tableName)) {
//       // Incremental — delete only entries for updated vouchers
//       await localDb.rawDelete('''
//       DELETE FROM $tableName 
//       WHERE voucher_guid IN (
//         SELECT voucher_guid FROM vouchers 
//         WHERE company_guid = ? AND updated_at > ?
//       )
//     ''', [companyGuid, updatedAfter]);
//     } else if (closingBalanceTables.contains(tableName)) {
//       // Closing balances — always full replace (small dataset)
//       await localDb.delete(tableName,
//           where: 'company_guid = ?', whereArgs: [companyGuid]);
//     }

//     int totalSynced = 0;
//     int offset = 0;
//     const fetchSize = 1000;

//     while (true) {
//       await _closeConnection();
//       await _ensureConnection();

//       String sql;

//       if (voucherChildTables.contains(tableName)) {
//         if (updatedAfter != null) {
//           sql = '''
//           SELECT t.* FROM $schema.$tableName t
//           JOIN $schema.vouchers v ON t.voucher_guid = v.voucher_guid
//           WHERE v.updated_at > '$updatedAfter'
//           ORDER BY t.voucher_guid
//           LIMIT $fetchSize OFFSET $offset
//         ''';
//         } else {
//           sql = '''
//           SELECT * FROM $schema.$tableName
//           WHERE company_guid = '$companyGuid'
//           ORDER BY voucher_guid
//           LIMIT $fetchSize OFFSET $offset
//         ''';
//         }
//       } else if (tableName == 'stock_item_closing_balance') {
//         sql = '''
//         SELECT * FROM $schema.$tableName
//         WHERE company_guid = '$companyGuid'
//         ORDER BY stock_item_guid, closing_date
//         LIMIT $fetchSize OFFSET $offset
//       ''';
//       } else if (tableName == 'ledger_closing_balances') {
//         sql = '''
//         SELECT * FROM $schema.$tableName
//         WHERE company_guid = '$companyGuid'
//         ORDER BY ledger_guid, closing_date
//         LIMIT $fetchSize OFFSET $offset
//       ''';
//       } else {
//         sql = '''
//         SELECT * FROM $schema.$tableName
//         WHERE company_guid = '$companyGuid'
//         LIMIT $fetchSize OFFSET $offset
//       ''';
//       }

//       final rows = await _connection!.execute(sql);
//       if (rows.isEmpty) break;

//       const batchSize = 500;
//       for (int i = 0; i < rows.length; i += batchSize) {
//         final batch = localDb.batch();
//         final end = (i + batchSize > rows.length) ? rows.length : i + batchSize;
//         for (int j = i; j < end; j++) {
//           final map = _resultRowToMap(rows[j], rows.schema);
//           batch.insert(tableName, map,
//               conflictAlgorithm: ConflictAlgorithm.replace);
//         }
//         await batch.commit(noResult: true);
//       }

//       totalSynced += rows.length;
//       print('  📥 $tableName: $totalSynced records synced...');

//       if (rows.length < fetchSize) break;
//       offset += fetchSize;
//     }

//     print('  ✅ $tableName: $totalSynced total records');
//     return totalSynced;
//   }

//   // ============================================================
//   // FETCH COMPANIES LIST (without saving locally)
//   // ============================================================

//   /// Fetch list of companies from cloud (for company selection screen)
//   Future<List<Map<String, dynamic>>> fetchCompaniesFromCloud(
//       {String? userId}) async {
//     await _ensureConnection();

//     if (userId != null) {
//       final rows = await _connection!.execute(
//         'SELECT company_guid, company_name, gsttin, pan, state, city, starting_from, ending_at, currency_name, maintain_inventory, is_gst_applicable, created_at, updated_at FROM user_data.companies WHERE is_deleted = 0 AND user_id = \$1 ORDER BY company_name',
//         parameters: [userId],
//       );
//       return rows.map((row) => _resultRowToMap(row, rows.schema)).toList();
//     }

//     final rows = await _connection!.execute('''
//       SELECT company_guid, company_name, gsttin, pan, state, city,
//              starting_from, ending_at, currency_name,
//              maintain_inventory, is_gst_applicable,
//              created_at, updated_at
//       FROM user_data.companies
//       WHERE is_deleted = 0
//       ORDER BY company_name
//     ''');

//     return rows.map((row) => _resultRowToMap(row, rows.schema)).toList();
//   }

//   // ============================================================
//   // FETCH SINGLE TABLE DATA (without saving locally)
//   // ============================================================

//   /// Fetch vouchers from cloud for a company
//   Future<List<Map<String, dynamic>>> fetchVouchersFromCloud(
//     String companyGuid, {
//     String? voucherType,
//     String? dateFrom,
//     String? dateTo,
//     int limit = 50,
//     int offset = 0,
//   }) async {
//     await _ensureConnection();
//     final schema = _getSchemaName(companyGuid);

//     final whereParts = <String>['is_deleted = 0'];
//     if (voucherType != null) whereParts.add("voucher_type = '$voucherType'");
//     if (dateFrom != null) whereParts.add("date >= '$dateFrom'");
//     if (dateTo != null) whereParts.add("date <= '$dateTo'");

//     final where = whereParts.join(' AND ');

//     final rows = await _connection!.execute('''
//       SELECT voucher_guid, voucher_number, date, voucher_type,
//              party_ledger_name, amount, total_amount, narration
//       FROM $schema.vouchers
//       WHERE $where
//       ORDER BY date DESC
//       LIMIT $limit OFFSET $offset
//     ''');

//     return rows.map((row) => _resultRowToMap(row, rows.schema)).toList();
//   }

//   /// Fetch dashboard summary from cloud
//   Future<Map<String, dynamic>> fetchDashboardFromCloud(
//       String companyGuid) async {
//     await _ensureConnection();
//     final schema = _getSchemaName(companyGuid);

//     final voucherCount = (await _connection!.execute(
//       'SELECT COUNT(*) as cnt FROM $schema.vouchers WHERE is_deleted = 0',
//     ))
//         .first[0] as int;

//     final ledgerCount = (await _connection!.execute(
//       'SELECT COUNT(*) as cnt FROM $schema.ledgers WHERE is_deleted = 0',
//     ))
//         .first[0] as int;

//     final stockCount = (await _connection!.execute(
//       'SELECT COUNT(*) as cnt FROM $schema.stock_items WHERE is_deleted = 0',
//     ))
//         .first[0] as int;

//     final groupCount = (await _connection!.execute(
//       'SELECT COUNT(*) as cnt FROM $schema.groups WHERE is_deleted = 0',
//     ))
//         .first[0] as int;

//     // Voucher type breakdown
//     final typeRows = await _connection!.execute('''
//       SELECT voucher_type, COUNT(*) as count, 
//              COALESCE(SUM(ABS(amount)), 0) as total_amount
//       FROM $schema.vouchers WHERE is_deleted = 0
//       GROUP BY voucher_type ORDER BY count DESC
//     ''');

//     // Recent 10 vouchers
//     final recentRows = await _connection!.execute('''
//       SELECT voucher_number, date, voucher_type, party_ledger_name, amount
//       FROM $schema.vouchers WHERE is_deleted = 0
//       ORDER BY date DESC LIMIT 10
//     ''');

//     return {
//       'counts': {
//         'vouchers': voucherCount,
//         'ledgers': ledgerCount,
//         'stock_items': stockCount,
//         'groups': groupCount,
//       },
//       'voucher_types':
//           typeRows.map((r) => _resultRowToMap(r, typeRows.schema)).toList(),
//       'recent_vouchers':
//           recentRows.map((r) => _resultRowToMap(r, recentRows.schema)).toList(),
//     };
//   }

//   // ============================================================
//   // HELPER: Convert postgres ResultRow to Map
//   // ============================================================

//   Map<String, dynamic> _resultRowToMap(ResultRow row, ResultSchema schema) {
//     final map = <String, dynamic>{};
//     for (int i = 0; i < schema.columns.length; i++) {
//       final colName = schema.columns[i].columnName;
//       var value = row[i];

//       // Convert DateTime to ISO string for SQLite compatibility
//       if (value is DateTime) {
//         value = value.toIso8601String();
//       }

//       map[colName ?? 'col_$i'] = value;
//     }
//     return map;
//   }
// }

// // ============================================================
// // SYNC RESULT
// // ============================================================
// class SyncResult {
//   bool success = false;
//   String? error;

//   int companies = 0;
//   int groups = 0;
//   int voucherTypes = 0;
//   int ledgers = 0;
//   int stockItems = 0;
//   int vouchers = 0;
//   int ledgerEntries = 0;
//   int inventoryEntries = 0;
//   int batchAllocations = 0;
//   int closingBalances = 0;
//   int stockClosingBalances = 0;

//   int get totalRecords =>
//       companies +
//       groups +
//       voucherTypes +
//       ledgers +
//       stockItems +
//       vouchers +
//       ledgerEntries +
//       inventoryEntries +
//       batchAllocations +
//       closingBalances +
//       stockClosingBalances;

//   @override
//   String toString() {
//     return '''
// SyncResult {
//   success: $success
//   ${error != null ? 'error: $error' : ''}
//   companies: $companies
//   groups: $groups
//   voucherTypes: $voucherTypes
//   ledgers: $ledgers
//   stockItems: $stockItems
//   vouchers: $vouchers
//   ledgerEntries: $ledgerEntries
//   inventoryEntries: $inventoryEntries
//   batchAllocations: $batchAllocations
//   closingBalances: $closingBalances
//   stockClosingBalances: $stockClosingBalances
//   total: $totalRecords
// }''';
//   }
// }

import 'package:postgres/postgres.dart';
import 'package:sqflite/sqflite.dart';
import '../config/api_config.dart';

// ============================================================
// HELPER: Carries query result + possibly-refreshed connection
// ============================================================

class _ExecResult {
  final Result rows;
  final Connection conn;
  _ExecResult(this.rows, this.conn);
}

/// Syncs data FROM AWS Aurora cloud database TO local SQLite.
///
/// Design principles:
/// - Each table gets its OWN dedicated [Connection] — no sharing.
/// - [_executeWithRetry] reopens a fresh connection on TLS/socket drops.
/// - Connections are RECYCLED every [_recycleEveryChunks] chunks to prevent
///   "StreamSink is closed" when Aurora closes long-lived streams.
/// - Chunked fetching (LIMIT/OFFSET) keeps individual queries short.
class CloudToLocalSyncService {
  static final CloudToLocalSyncService instance =
      CloudToLocalSyncService._init();

  CloudToLocalSyncService._init();

  /// Recycle connection every N chunks (~N*1000 rows) to prevent Aurora
  /// from closing the stream after too many sequential queries.
  static const int _recycleEveryChunks = 10;

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

  /// Executes [sql] with automatic retry on TLS/socket/stream errors.
  /// Returns [_ExecResult] with the (possibly refreshed) connection so callers
  /// can continue using it for subsequent chunks.
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
            msg.contains('BAD_DECRYPT') ||
            msg.contains('DECRYPTION_FAILED') ||
            msg.contains('not open') ||
            msg.contains('StreamSink is closed') ||
            msg.contains('Connection');

        if (isRetryable && attempt < maxRetries) {
          attempt++;
          print('  ⚠️ TLS/stream drop, retry $attempt/$maxRetries...');
          try {
            await current.close();
          } catch (_) {}
          await Future.delayed(Duration(seconds: attempt));
          current = await _openConnection();
          continue;
        }
        rethrow;
      }
    }
  }

  String _getSchemaName(String companyGuid) =>
      'company_${companyGuid.replaceAll('-', '_')}';

  // ============================================================
  // SYNC STATUS TRACKING
  // ============================================================

  Future<void> ensureSyncStatusTable(Database localDb) async {
    await localDb.execute('''
      CREATE TABLE IF NOT EXISTS sync_status (
        company_guid   TEXT NOT NULL,
        table_name     TEXT NOT NULL,
        last_synced_at TEXT NOT NULL,
        PRIMARY KEY (company_guid, table_name)
      )
    ''');
  }

  Future<String?> _getLastSyncTime(
      Database localDb, String companyGuid, String tableName) async {
    try {
      final result = await localDb.query(
        'sync_status',
        where: 'company_guid = ? AND table_name = ?',
        whereArgs: [companyGuid, tableName],
      );
      if (result.isNotEmpty) {
        return result.first['last_synced_at'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _updateSyncTime(
      Database localDb, String companyGuid, String tableName) async {
    await localDb.insert(
      'sync_status',
      {
        'company_guid': companyGuid,
        'table_name': tableName,
        'last_synced_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ============================================================
  // FULL SYNC
  // ============================================================

  Future<SyncResult> fullSync(
    Database localDb,
    String companyGuid, {
    Function(String status, double progress)? onProgress,
  }) async {
    await ensureSyncStatusTable(localDb);
    final result = SyncResult();
    final schema = _getSchemaName(companyGuid);

    try {
      // Step 1: Company
      onProgress?.call('Syncing company info...', 0.05);
      result.companies = await _syncCompany(localDb, companyGuid);

      // Step 2: Master tables — each gets its OWN connection (parallel)
      onProgress?.call('Syncing master data...', 0.10);
      final masterResults = await Future.wait([
        _syncTable(localDb, schema, 'groups', companyGuid),
        _syncVoucherTypes(localDb, schema, companyGuid),
        _syncTable(localDb, schema, 'ledgers', companyGuid),
        _syncTable(localDb, schema, 'stock_items', companyGuid),
      ]);
      result.groups = masterResults[0];
      result.voucherTypes = masterResults[1];
      result.ledgers = masterResults[2];
      result.stockItems = masterResults[3];

      // Step 3: Vouchers (must finish before child tables)
      onProgress?.call('Syncing vouchers...', 0.45);
      result.vouchers =
          await _syncTable(localDb, schema, 'vouchers', companyGuid);

      // Step 4: Voucher child tables — each gets its OWN connection (parallel)
      onProgress?.call('Syncing voucher entries...', 0.65);
      final childResults = await Future.wait([
        _syncChildTable(localDb, schema, 'voucher_ledger_entries', companyGuid),
        _syncChildTable(
            localDb, schema, 'voucher_inventory_entries', companyGuid),
        _syncChildTable(
            localDb, schema, 'voucher_batch_allocations', companyGuid),
      ]);
      result.ledgerEntries = childResults[0];
      result.inventoryEntries = childResults[1];
      result.batchAllocations = childResults[2];

      // Step 5: Closing balances — each gets its OWN connection (parallel)
      onProgress?.call('Syncing closing balances...', 0.90);
      final balanceResults = await Future.wait([
        _syncChildTable(
            localDb, schema, 'ledger_closing_balances', companyGuid),
        _syncChildTable(
            localDb, schema, 'stock_item_closing_balance', companyGuid),
      ]);
      result.closingBalances = balanceResults[0];
      result.stockClosingBalances = balanceResults[1];

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
  // INCREMENTAL SYNC
  // ============================================================

  Future<SyncResult> incrementalSync(
    Database localDb,
    String companyGuid, {
    Function(String status, double progress)? onProgress,
  }) async {
    await ensureSyncStatusTable(localDb);
    final result = SyncResult();
    final schema = _getSchemaName(companyGuid);

    try {
      // Step 1: Company (always full)
      onProgress?.call('Checking company updates...', 0.05);
      result.companies = await _syncCompany(localDb, companyGuid);

      // Fetch all last-sync timestamps upfront
      final lastGroupSync =
          await _getLastSyncTime(localDb, companyGuid, 'groups');
      final lastLedgerSync =
          await _getLastSyncTime(localDb, companyGuid, 'ledgers');
      final lastStockSync =
          await _getLastSyncTime(localDb, companyGuid, 'stock_items');
      final lastVoucherSync =
          await _getLastSyncTime(localDb, companyGuid, 'vouchers');

      // Step 2: Master tables in parallel
      onProgress?.call('Syncing updated master data...', 0.15);
      final masterResults = await Future.wait([
        _syncTable(localDb, schema, 'groups', companyGuid,
            updatedAfter: lastGroupSync),
        _syncVoucherTypes(localDb, schema, companyGuid),
        _syncTable(localDb, schema, 'ledgers', companyGuid,
            updatedAfter: lastLedgerSync),
        _syncTable(localDb, schema, 'stock_items', companyGuid,
            updatedAfter: lastStockSync),
      ]);
      result.groups = masterResults[0];
      result.voucherTypes = masterResults[1];
      result.ledgers = masterResults[2];
      result.stockItems = masterResults[3];

      await Future.wait([
        _updateSyncTime(localDb, companyGuid, 'groups'),
        _updateSyncTime(localDb, companyGuid, 'ledgers'),
        _updateSyncTime(localDb, companyGuid, 'stock_items'),
      ]);

      // Step 3: Vouchers
      onProgress?.call('Syncing updated vouchers...', 0.45);
      result.vouchers = await _syncTable(
          localDb, schema, 'vouchers', companyGuid,
          updatedAfter: lastVoucherSync);
      await _updateSyncTime(localDb, companyGuid, 'vouchers');

      // Step 4: Child tables (only if vouchers changed)
      if (result.vouchers > 0) {
        onProgress?.call('Syncing voucher entries...', 0.65);
        final childResults = await Future.wait([
          _syncChildTable(
              localDb, schema, 'voucher_ledger_entries', companyGuid,
              updatedAfter: lastVoucherSync),
          _syncChildTable(
              localDb, schema, 'voucher_inventory_entries', companyGuid,
              updatedAfter: lastVoucherSync),
          _syncChildTable(
              localDb, schema, 'voucher_batch_allocations', companyGuid,
              updatedAfter: lastVoucherSync),
        ]);
        result.ledgerEntries = childResults[0];
        result.inventoryEntries = childResults[1];
        result.batchAllocations = childResults[2];
      }

      // Step 5: Closing balances (always full — small dataset)
      onProgress?.call('Syncing closing balances...', 0.90);
      final balanceResults = await Future.wait([
        _syncChildTable(
            localDb, schema, 'ledger_closing_balances', companyGuid),
        _syncChildTable(
            localDb, schema, 'stock_item_closing_balance', companyGuid),
      ]);
      result.closingBalances = balanceResults[0];
      result.stockClosingBalances = balanceResults[1];

      result.success = true;
      onProgress?.call('Sync complete!', 1.0);
      print(
          '✅ Incremental sync complete: ${result.totalRecords} updated records');
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      print('❌ Incremental sync failed: $e');
    }

    return result;
  }

  // ============================================================
  // CORE: COMPANY
  // ============================================================

  Future<int> _syncCompany(Database localDb, String companyGuid) async {
    final conn = await _openConnection();
    try {
      final exec = await _executeWithRetry(
        conn,
        "SELECT * FROM user_data.companies WHERE company_guid = '$companyGuid'",
      );
      if (exec.rows.isEmpty) return 0;
      for (final row in exec.rows) {
        final map = _resultRowToMap(row, exec.rows.schema);
        map.remove('user_id');
        await localDb.insert('companies', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (!identical(conn, exec.conn)) {
        try { await exec.conn.close(); } catch (_) {}
      }
      print('  ✅ companies: ${exec.rows.length}');
      return exec.rows.length;
    } finally {
      try { await conn.close(); } catch (_) {}
    }
  }

  // ============================================================
  // CORE: MASTER TABLES
  // Opens its own connection and recycles every _recycleEveryChunks chunks.
  // ============================================================

  Future<int> _syncTable(
    Database localDb,
    String schema,
    String tableName,
    String companyGuid, {
    String? updatedAfter,
  }) async {
    int totalSynced = 0;
    int offset = 0;
    const fetchSize = 2000;
    int chunkCount = 0;

    Connection current = await _openConnection();
    try {
      while (true) {
        // Proactively recycle every N chunks to prevent StreamSink close
        if (chunkCount > 0 && chunkCount % _recycleEveryChunks == 0) {
          try { await current.close(); } catch (_) {}
          current = await _openConnection();
        }

        final String sql;
        if (updatedAfter != null) {
          sql = '''
            SELECT * FROM $schema.$tableName
            WHERE updated_at > '$updatedAfter'
            ORDER BY updated_at
            LIMIT $fetchSize OFFSET $offset
          ''';
        } else {
          sql = '''
            SELECT * FROM $schema.$tableName
            ORDER BY created_at
            LIMIT $fetchSize OFFSET $offset
          ''';
        }

        final exec = await _executeWithRetry(current, sql);
        current = exec.conn; // use refreshed conn if TLS retry occurred
        if (exec.rows.isEmpty) break;

        final batch = localDb.batch();
        for (final row in exec.rows) {
          batch.insert(
            tableName,
            _resultRowToMap(row, exec.rows.schema),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);

        totalSynced += exec.rows.length;
        chunkCount++;
        if (exec.rows.length < fetchSize) break;
        offset += fetchSize;
      }
    } finally {
      try { await current.close(); } catch (_) {}
    }

    print(
        '  ✅ $tableName: $totalSynced ${updatedAfter != null ? "(incremental)" : "(full)"}');
    return totalSynced;
  }

  // ============================================================
  // CORE: VOUCHER TYPES
  // ============================================================

  Future<int> _syncVoucherTypes(
    Database localDb,
    String schema,
    String companyGuid,
  ) async {
    await localDb.delete('voucher_types',
        where: 'company_guid = ?', whereArgs: [companyGuid]);

    int totalSynced = 0;
    int offset = 0;
    const fetchSize = 2000;
    int chunkCount = 0;

    Connection current = await _openConnection();
    try {
      while (true) {
        if (chunkCount > 0 && chunkCount % _recycleEveryChunks == 0) {
          try { await current.close(); } catch (_) {}
          current = await _openConnection();
        }

        final exec = await _executeWithRetry(current, '''
          SELECT * FROM $schema.voucher_types
          ORDER BY name
          LIMIT $fetchSize OFFSET $offset
        ''');
        current = exec.conn;
        if (exec.rows.isEmpty) break;

        final batch = localDb.batch();
        for (final row in exec.rows) {
          final map = _resultRowToMap(row, exec.rows.schema);
          map.remove('id'); // Remove SERIAL id — let SQLite auto-generate
          batch.insert('voucher_types', map);
        }
        await batch.commit(noResult: true);

        totalSynced += exec.rows.length;
        chunkCount++;
        if (exec.rows.length < fetchSize) break;
        offset += fetchSize;
      }
    } finally {
      try { await current.close(); } catch (_) {}
    }

    print('  ✅ voucher_types: $totalSynced');
    return totalSynced;
  }

  // ============================================================
  // CORE: CHILD TABLES
  // Opens its own connection and recycles every _recycleEveryChunks chunks.
  // ============================================================

  Future<int> _syncChildTable(
    Database localDb,
    String schema,
    String tableName,
    String companyGuid, {
    String? updatedAfter,
  }) async {
    const voucherChildTables = {
      'voucher_ledger_entries',
      'voucher_inventory_entries',
      'voucher_batch_allocations',
    };
    const closingBalanceTables = {
      'ledger_closing_balances',
      'stock_item_closing_balance',
    };

    // ── Delete strategy ────────────────────────────────────────
    if (updatedAfter == null) {
      // Full sync — wipe all rows for this company
      await localDb.delete(tableName,
          where: 'company_guid = ?', whereArgs: [companyGuid]);
    } else if (voucherChildTables.contains(tableName)) {
      // Incremental — only remove entries for vouchers being re-synced
      await localDb.rawDelete('''
        DELETE FROM $tableName
        WHERE voucher_guid IN (
          SELECT voucher_guid FROM vouchers
          WHERE company_guid = ? AND updated_at > ?
        )
      ''', [companyGuid, updatedAfter]);
    } else if (closingBalanceTables.contains(tableName)) {
      // Closing balances — always full replace
      await localDb.delete(tableName,
          where: 'company_guid = ?', whereArgs: [companyGuid]);
    }

    // ── Chunked fetch with proactive recycling + per-chunk retry ──
    int totalSynced = 0;
    int offset = 0;
    const fetchSize = 1000; // 1000-row chunks → shorter queries → less TLS risk
    int chunkCount = 0;

    Connection current = await _openConnection();
    try {
      while (true) {
        // Proactively recycle every N chunks to prevent StreamSink close
        if (chunkCount > 0 && chunkCount % _recycleEveryChunks == 0) {
          print(
              '  🔄 $tableName: recycling connection at $totalSynced rows...');
          try { await current.close(); } catch (_) {}
          current = await _openConnection();
        }

        final sql = _buildChildSql(
          schema: schema,
          tableName: tableName,
          companyGuid: companyGuid,
          updatedAfter: updatedAfter,
          fetchSize: fetchSize,
          offset: offset,
          isVoucherChild: voucherChildTables.contains(tableName),
        );

        final exec = await _executeWithRetry(current, sql);
        current = exec.conn; // use refreshed conn if TLS retry occurred
        if (exec.rows.isEmpty) break;

        // Write to SQLite in 500-row sub-batches to keep memory bounded
        const batchSize = 500;
        for (int i = 0; i < exec.rows.length; i += batchSize) {
          final batch = localDb.batch();
          final end = (i + batchSize > exec.rows.length)
              ? exec.rows.length
              : i + batchSize;
          for (int j = i; j < end; j++) {
            batch.insert(
              tableName,
              _resultRowToMap(exec.rows[j], exec.rows.schema),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }

        totalSynced += exec.rows.length;
        chunkCount++;
        print('  📥 $tableName: $totalSynced...');
        if (exec.rows.length < fetchSize) break;
        offset += fetchSize;
      }
    } finally {
      // Always close the connection we opened
      try { await current.close(); } catch (_) {}
    }

    print('  ✅ $tableName: $totalSynced total');
    return totalSynced;
  }

  // ============================================================
  // SQL BUILDER FOR CHILD TABLES
  // ============================================================

  String _buildChildSql({
    required String schema,
    required String tableName,
    required String companyGuid,
    required String? updatedAfter,
    required int fetchSize,
    required int offset,
    required bool isVoucherChild,
  }) {
    if (isVoucherChild) {
      if (updatedAfter != null) {
        return '''
          SELECT t.* FROM $schema.$tableName t
          JOIN $schema.vouchers v ON t.voucher_guid = v.voucher_guid
          WHERE v.updated_at > '$updatedAfter'
          ORDER BY t.voucher_guid
          LIMIT $fetchSize OFFSET $offset
        ''';
      }
      return '''
        SELECT * FROM $schema.$tableName
        WHERE company_guid = '$companyGuid'
        ORDER BY voucher_guid
        LIMIT $fetchSize OFFSET $offset
      ''';
    }

    // Latest closing balance per stock item only — not full history.
    // DISTINCT ON is PostgreSQL/Aurora specific.
    if (tableName == 'stock_item_closing_balance') {
      return '''
        SELECT DISTINCT ON (stock_item_guid)
          company_guid, stock_item_guid,
          closing_balance, closing_value, closing_rate, closing_date
        FROM $schema.$tableName
        WHERE company_guid = '$companyGuid'
        ORDER BY stock_item_guid, closing_date DESC
        LIMIT $fetchSize OFFSET $offset
      ''';
    }

    // Latest closing balance per ledger only — not full history.
    if (tableName == 'ledger_closing_balances') {
      return '''
        SELECT DISTINCT ON (ledger_guid)
          company_guid, ledger_guid, closing_date, amount
        FROM $schema.$tableName
        WHERE company_guid = '$companyGuid'
        ORDER BY ledger_guid, closing_date DESC
        LIMIT $fetchSize OFFSET $offset
      ''';
    }

    return '''
      SELECT * FROM $schema.$tableName
      WHERE company_guid = '$companyGuid'
      LIMIT $fetchSize OFFSET $offset
    ''';
  }

  // ============================================================
  // FETCH COMPANIES (without saving locally)
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

  // ============================================================
  // FETCH VOUCHERS (without saving locally)
  // ============================================================

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
      final whereParts = <String>['is_deleted = 0'];
      if (voucherType != null) whereParts.add("voucher_type = '$voucherType'");
      if (dateFrom != null) whereParts.add("date >= '$dateFrom'");
      if (dateTo != null) whereParts.add("date <= '$dateTo'");

      final exec = await _executeWithRetry(conn, '''
        SELECT voucher_guid, voucher_number, date, voucher_type,
               party_ledger_name, amount, total_amount, narration
        FROM $schema.vouchers
        WHERE ${whereParts.join(' AND ')}
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

  // ============================================================
  // FETCH DASHBOARD SUMMARY (without saving locally)
  // ============================================================

  Future<Map<String, dynamic>> fetchDashboardFromCloud(
      String companyGuid) async {
    final schema = _getSchemaName(companyGuid);
    final conn = await _openConnection();
    try {
      Connection current = conn;
      _ExecResult exec;

      exec = await _executeWithRetry(current,
          'SELECT COUNT(*) FROM $schema.vouchers WHERE is_deleted = 0');
      current = exec.conn;
      final voucherCount = exec.rows.first[0] as int;

      exec = await _executeWithRetry(current,
          'SELECT COUNT(*) FROM $schema.ledgers WHERE is_deleted = 0');
      current = exec.conn;
      final ledgerCount = exec.rows.first[0] as int;

      exec = await _executeWithRetry(current,
          'SELECT COUNT(*) FROM $schema.stock_items WHERE is_deleted = 0');
      current = exec.conn;
      final stockCount = exec.rows.first[0] as int;

      exec = await _executeWithRetry(current,
          'SELECT COUNT(*) FROM $schema.groups WHERE is_deleted = 0');
      current = exec.conn;
      final groupCount = exec.rows.first[0] as int;

      exec = await _executeWithRetry(current, '''
        SELECT voucher_type,
               COUNT(*) as count,
               COALESCE(SUM(ABS(amount)), 0) as total_amount
        FROM $schema.vouchers
        WHERE is_deleted = 0
        GROUP BY voucher_type
        ORDER BY count DESC
      ''');
      current = exec.conn;
      final typeRows = exec.rows;
      final typeSchema = exec.rows.schema;

      exec = await _executeWithRetry(current, '''
        SELECT voucher_number, date, voucher_type, party_ledger_name, amount
        FROM $schema.vouchers
        WHERE is_deleted = 0
        ORDER BY date DESC
        LIMIT 10
      ''');
      current = exec.conn;
      final recentRows = exec.rows;
      final recentSchema = exec.rows.schema;

      if (!identical(conn, current)) {
        try { await current.close(); } catch (_) {}
      }

      return {
        'counts': {
          'vouchers': voucherCount,
          'ledgers': ledgerCount,
          'stock_items': stockCount,
          'groups': groupCount,
        },
        'voucher_types':
            typeRows.map((r) => _resultRowToMap(r, typeSchema)).toList(),
        'recent_vouchers':
            recentRows.map((r) => _resultRowToMap(r, recentSchema)).toList(),
      };
    } finally {
      try { await conn.close(); } catch (_) {}
    }
  }

  // ============================================================
  // HELPER: Convert postgres ResultRow → Map<String, dynamic>
  // ============================================================

  Map<String, dynamic> _resultRowToMap(ResultRow row, ResultSchema schema) {
    final map = <String, dynamic>{};
    for (int i = 0; i < schema.columns.length; i++) {
      final colName = schema.columns[i].columnName;
      var value = row[i];
      if (value is DateTime) value = value.toIso8601String();
      map[colName ?? 'col_$i'] = value;
    }
    return map;
  }

  Future<void> dispose() async {}
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
      companies +
      groups +
      voucherTypes +
      ledgers +
      stockItems +
      vouchers +
      ledgerEntries +
      inventoryEntries +
      batchAllocations +
      closingBalances +
      stockClosingBalances;

  @override
  String toString() => '''
SyncResult {
  success: $success${error != null ? '\n  error: $error' : ''}
  companies:            $companies
  groups:               $groups
  voucherTypes:         $voucherTypes
  ledgers:              $ledgers
  stockItems:           $stockItems
  vouchers:             $vouchers
  ledgerEntries:        $ledgerEntries
  inventoryEntries:     $inventoryEntries
  batchAllocations:     $batchAllocations
  closingBalances:      $closingBalances
  stockClosingBalances: $stockClosingBalances
  ──────────────────────────────────────────
  total:                $totalRecords
}''';
}