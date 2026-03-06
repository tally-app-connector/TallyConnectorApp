// import 'package:postgres/postgres.dart';
// import '../config/api_config.dart';

// class NeonSyncService {
//   static final NeonSyncService instance = NeonSyncService._init();
//   Connection? _connection;

//   NeonSyncService._init();

//   Future<void> initialize() async {
//     if (_connection != null) return;

//     try {
//       _connection = await Connection.open(
//         Endpoint(
//           host: NeonConfig.host,
//           database: NeonConfig.database,
//           username: NeonConfig.username,
//           password: NeonConfig.password,
//         ),
//         settings: const ConnectionSettings(
//           sslMode: SslMode.require,
//           connectTimeout: Duration(seconds: NeonConfig.connectTimeout),
//           queryTimeout: Duration(seconds: NeonConfig.queryTimeout),
//         ),
//       );
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<void> close() async {
//     await _connection?.close();
//     _connection = null;
//   }

//   Future<bool> isConnected() async {
//     if (_connection == null) return false;
//     try {
//       await _connection!.execute('SELECT 1');
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<bool> testConnection() async {
//     try {
//       await initialize();
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<void> createCompanySchema(String schemaName) async {
//     if (_connection == null) await initialize();

//     try {
//       print('🔨 Creating schema for company: $schemaName');

//       // Create schema
//       await _connection!.execute('CREATE SCHEMA IF NOT EXISTS $schemaName');

//       await _createTablesInSchema(schemaName);
//       // Create all tables in this schema
//       print('✅ Schema created: $schemaName');
//     } catch (e) {
//       print('❌ Error creating schema $schemaName: $e');
//       rethrow;
//     }
//   }

//   Future<void> _createTablesInSchema(String schemaName) async {
//     if (_connection == null) await initialize();

//     try {
//       // 1. Groups Table (EXACT match to local SQLite)
//       await _connection!.execute('''
//         CREATE TABLE IF NOT EXISTS $schemaName.groups (
//           group_guid TEXT PRIMARY KEY,
//           group_name TEXT,
//           group_parent_name TEXT,
//           group_alias TEXT,
//           alter_id INTEGER
//         )
//       ''');
//       await _connection!.execute(
//           'CREATE UNIQUE INDEX IF NOT EXISTS idx_groups_guid ON $schemaName.groups(group_guid)');
//       await _connection!.execute(
//           'CREATE INDEX IF NOT EXISTS idx_groups_name ON $schemaName.groups(group_name)');

//       await _connection!.execute('''
//         CREATE TABLE IF NOT EXISTS $schemaName.ledgers (
//           ledger_guid TEXT PRIMARY KEY,
//           ledger_name TEXT,
//           parent_name TEXT,
//           parent_guid TEXT,
//           opening_balance REAL,
//           closing_balance REAL,
//           ledger_gstin TEXT,
//           credit_limit REAL DEFAULT 0,
//           credit_days INTEGER DEFAULT 0,
//           is_debit_ledger TEXT,
//           is_debit_group TEXT,
//           gst_registration_type TEXT,
//           alter_id INTEGER,
//           ledger_pan TEXT,
//           ledger_address TEXT
//         )
//       ''');

//       await _connection!.execute(
//           'CREATE UNIQUE INDEX IF NOT EXISTS idx_ledgers_guid ON $schemaName.ledgers(ledger_guid)');
//       await _connection!.execute(
//           'CREATE INDEX IF NOT EXISTS idx_ledgers_parent_guid ON $schemaName.ledgers(parent_guid)');
//       await _connection!.execute(
//           'CREATE INDEX IF NOT EXISTS idx_ledgers_name ON $schemaName.ledgers(ledger_name)');

//       print('✅ All tables created in schema: $schemaName');
//     } catch (e) {
//       print('❌ Error creating tables in schema $schemaName: $e');
//       rethrow;
//     }
//   }

//   String _getSchemaName(String companyGuid) {
//     final cleanGuid = companyGuid.replaceAll('-', '_');
//     return 'company_$cleanGuid';
//   }

//   Future checkSchemaExists(String schemaName) async {
//     if (_connection == null) await initialize();

//     try {
//       final result = await _connection!.execute('''
//         SELECT EXISTS (
//           SELECT FROM information_schema.schemata 
//           WHERE schema_name = \$1
//         )
//       ''', parameters: [schemaName]);

//       final isSchemaExist = result.first[0] as bool;

//       if (!isSchemaExist) {
//         await createCompanySchema(schemaName);
//       }
//     } catch (e) {
//       print('❌ Error checking schema $schemaName: $e');
//     }
//   }

//   Future<void> syncCompany(Map<String, dynamic> company) async {
//     if (_connection == null) await initialize();

//     try {
//       // 2. Upsert company in public.companies table
//       await _connection!.execute(
//         '''
//         INSERT INTO user_data.companies (
//           company_guid, 
//           user_id, 
//           company_name, 
//           last_sync_timestamp, 
//           last_synced_alter_id, 
//           create_timestamp,
//           company_address
//         )
//         VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)
//         ON CONFLICT (company_guid) 
//         DO UPDATE SET
//           company_name = EXCLUDED.company_name,
//           company_address = EXCLUDED.company_address,
//           last_sync_timestamp = EXCLUDED.last_sync_timestamp,
//           last_synced_alter_id = EXCLUDED.last_synced_alter_id
//         ''',
//         parameters: [
//           company['company_guid'],
//           company['user_id'],
//           company['company_name'],
//           company['last_sync_timestamp'],
//           company['last_synced_alter_id'] ?? 0,
//           company['create_timestamp'],
//           company['company_address'],
//         ],
//       );
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<void> updateCompany(
//       String companyGuid, String keyName, int alterId) async {
//     if (_connection == null) await initialize();

//     try {
//       await _connection!.execute(
//         'UPDATE user_data.companies SET $keyName = \$1, last_sync_timestamp = \$2 WHERE company_guid = \$3',
//         parameters: [
//           alterId,
//           DateTime.now().millisecondsSinceEpoch,
//           companyGuid,
//         ],
//       );

//       print('✅ Updated sync alter_id to: $alterId for company: $companyGuid');
//     } catch (e) {
//       print('❌ Error updating sync timestamp: $e');
//       rethrow;
//     }
//   }

//   Future<void> syncGroups(
//       List<Map<String, dynamic>> groups, String companyGuid) async {
//     if (_connection == null) await initialize();
//     final schemaName = _getSchemaName(companyGuid);
//     await checkSchemaExists(schemaName);
//     int successCount = 0;
//     int errorCount = 0;

//     for (var group in groups) {
//       try {
//         await syncGroup(group, schemaName);
//         successCount++;
//       } catch (e) {
//         errorCount++;
//       }
//     }

//     print(
//         '✅ Synced $successCount groups to company schema (${errorCount > 0 ? '$errorCount errors' : 'no errors'})');
//   }

//   Future<void> syncGroup(Map<String, dynamic> group, String schemaName) async {
//     if (_connection == null) await initialize();

//     try {
//       await _connection!.execute(
//         '''
//         INSERT INTO $schemaName.groups (
//             group_guid,
//             group_name,
//             group_parent_name,
//             group_alias,
//             alter_id
//         )
//         VALUES (\$1, \$2, \$3, \$4, \$5)
//         ON CONFLICT (group_guid)
//         DO UPDATE SET
//           group_name = EXCLUDED.group_name,
//           group_parent_name = EXCLUDED.group_parent_name,
//           group_alias = EXCLUDED.group_alias,
//           alter_id = EXCLUDED.alter_id
//         ''',
//         parameters: [
//           group['group_guid'],
//           group['group_name'],
//           group['group_parent_name'],
//           group['group_alias'],
//           parseInt(group['alter_id'])
//         ],
//       );
//     } catch (e) {
//       print(
//           '❌ Error syncing group ${group['group_name']} to schema $schemaName: $e');
//       rethrow;
//     }
//   }

//   Future<void> syncLedgers(
//       List<Map<String, dynamic>> ledgers, String companyGuid) async {
//     if (_connection == null) await initialize();
//     final schemaName = _getSchemaName(companyGuid);
//     await checkSchemaExists(schemaName);

//     int successCount = 0;
//     int errorCount = 0;
//     const batchSize = 100;

//     // Process in batches of 100
//     for (int i = 0; i < ledgers.length; i += batchSize) {
//       final batch = ledgers.skip(i).take(batchSize).toList();

//       try {
//         await _syncLedgerBatch(batch, schemaName);
//         successCount += batch.length;
//         print('✅ Synced $successCount/${ledgers.length} ledgers...');
//       } catch (e) {
//         errorCount += batch.length;
//         print('❌ Error syncing batch at index $i: $e');
//       }
//     }

//     print(
//         '✅ Synced $successCount ledgers to company schema (${errorCount > 0 ? '$errorCount errors' : 'no errors'})');
//   }

//   Future<void> _syncLedgerBatch(
//       List<Map<String, dynamic>> ledgers, String schemaName) async {
//     if (ledgers.isEmpty) return;

//     // Build VALUES clause with proper parameter indexing
//     final valueClauses = <String>[];
//     final allParameters = <dynamic>[];

//     for (int i = 0; i < ledgers.length; i++) {
//       final ledger = ledgers[i];
//       final baseIndex = i * 15; // 15 parameters per ledger

//       // Create placeholder for this row: ($1, $2, ..., $15), ($16, $17, ..., $30), etc.
//       final placeholders =
//           List.generate(15, (j) => '\$${baseIndex + j + 1}').join(', ');
//       valueClauses.add('($placeholders)');

//       // Add parameters for this ledger
//       allParameters.addAll([
//         ledger['ledger_guid'],
//         ledger['ledger_name'],
//         ledger['parent_name'],
//         ledger['parent_guid'],
//         ledger['opening_balance'],
//         ledger['closing_balance'],
//         ledger['ledger_gstin'],
//         ledger['credit_limit'] ?? 0,
//         ledger['credit_days'] ?? 0,
//         ledger['is_debit_ledger'],
//         ledger['is_debit_group'],
//         ledger['gst_registration_type'],
//         parseInt(ledger['alter_id']),
//         ledger['ledger_pan'],
//         ledger['ledger_address'],
//       ]);
//     }

//     final sql = '''
//     INSERT INTO $schemaName.ledgers (
//       ledger_guid,
//       ledger_name,
//       parent_name,
//       parent_guid,
//       opening_balance,
//       closing_balance,
//       ledger_gstin,
//       credit_limit,
//       credit_days,
//       is_debit_ledger,
//       is_debit_group,
//       gst_registration_type,
//       alter_id,
//       ledger_pan,
//       ledger_address
//     )
//     VALUES ${valueClauses.join(', ')}
//     ON CONFLICT (ledger_guid)
//     DO UPDATE SET
//       ledger_name = EXCLUDED.ledger_name,
//       parent_name = EXCLUDED.parent_name,
//       parent_guid = EXCLUDED.parent_guid,
//       opening_balance = EXCLUDED.opening_balance,
//       closing_balance = EXCLUDED.closing_balance,
//       ledger_gstin = EXCLUDED.ledger_gstin,
//       credit_limit = EXCLUDED.credit_limit,
//       credit_days = EXCLUDED.credit_days,
//       is_debit_ledger = EXCLUDED.is_debit_ledger,
//       is_debit_group = EXCLUDED.is_debit_group,
//       gst_registration_type = EXCLUDED.gst_registration_type,
//       alter_id = EXCLUDED.alter_id,
//       ledger_pan = EXCLUDED.ledger_pan,
//       ledger_address = EXCLUDED.ledger_address
//   ''';

//     await _connection!.execute(sql, parameters: allParameters);
//   }

//   dynamic parseInt(dynamic value) {
//     if (value == 0 || value == '' || value == 'null') return 0;
//     if (value is int) return value;
//     if (value is String) {
//       final parsed = int.tryParse(value);
//       return parsed;
//     }
//     return 0;
//   }
// }

import 'package:postgres/postgres.dart';
import '../config/api_config.dart';

class NeonSyncService {
  static final NeonSyncService instance = NeonSyncService._init();
  Connection? _connection;

  NeonSyncService._init();

  Future<void> initialize() async {
    if (_connection != null) return;

    try {
      _connection = await Connection.open(
        Endpoint(
          host: NeonConfig.host,
          database: NeonConfig.database,
          username: NeonConfig.username,
          password: NeonConfig.password,
        ),
        settings: const ConnectionSettings(
          sslMode: SslMode.require,
          connectTimeout: Duration(seconds: NeonConfig.connectTimeout),
          queryTimeout: Duration(seconds: NeonConfig.queryTimeout),
        ),
      );

      // Ensure companies table exists in user_data schema
      await createCompaniesTable();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }

  Future<bool> isConnected() async {
    if (_connection == null) return false;
    try {
      await _connection!.execute('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> testConnection() async {
    try {
      await initialize();
      return true;
    } catch (e) {
      return false;
    }
  }

  String _getSchemaName(String companyGuid) {
    final cleanGuid = companyGuid.replaceAll('-', '_');
    return 'company_$cleanGuid';
  }

  Future<void> createCompanySchema(String schemaName) async {
    if (_connection == null) await initialize();

    try {
      print('🔨 Creating schema for company: $schemaName');

      // Create schema
      await _connection!.execute('CREATE SCHEMA IF NOT EXISTS $schemaName');

      await _createTablesInSchema(schemaName);
      print('✅ Schema created: $schemaName');
    } catch (e) {
      print('❌ Error creating schema $schemaName: $e');
      rethrow;
    }
  }

  // ============================================
  // CREATE COMPANIES TABLE IN PUBLIC/USER_DATA SCHEMA
  // This is NOT company-specific, it's a global table
  // ============================================
  Future<void> createCompaniesTable() async {
    if (_connection == null) await initialize();

    try {
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS user_data.companies (
          company_guid TEXT PRIMARY KEY,
          master_id INTEGER NOT NULL,
          alter_id INTEGER,
          company_name TEXT NOT NULL,
          reserved_name TEXT,
          starting_from TEXT NOT NULL,
          ending_at TEXT NOT NULL,
          books_from TEXT,
          gst_applicable_date TEXT,
          email TEXT,
          phone_number TEXT,
          fax_number TEXT,
          website TEXT,
          address TEXT,
          city TEXT,
          pincode TEXT,
          state TEXT,
          country TEXT,
          income_tax_number TEXT,
          pan TEXT,
          gsttin TEXT,
          currency_name TEXT,
          maintain_bill_wise INTEGER DEFAULT 0,
          maintain_inventory INTEGER DEFAULT 0,
          integrate_inventory INTEGER DEFAULT 0,
          is_gst_applicable INTEGER DEFAULT 0,
          is_tds_applicable INTEGER DEFAULT 0,
          is_tcs_applicable INTEGER DEFAULT 0,
          is_payroll_enabled INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          is_security_enabled INTEGER DEFAULT 0,
          last_synced_groups_alter_id INTEGER DEFAULT 0,
          last_synced_ledgers_alter_id INTEGER DEFAULT 0,
          last_synced_stock_items_alter_id INTEGER DEFAULT 0,
          last_synced_vouchers_alter_id INTEGER DEFAULT 0,
          is_selected INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Create indexes for companies
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_companies_guid ON user_data.companies(company_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_companies_name ON user_data.companies(company_name)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_companies_selected ON user_data.companies(is_selected)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_companies_deleted ON user_data.companies(is_deleted)');

      print('✅ Companies table created in user_data schema');
    } catch (e) {
      print('❌ Error creating companies table: $e');
      rethrow;
    }
  }

  Future<void> _createTablesInSchema(String schemaName) async {
    if (_connection == null) await initialize();

    try {
      // ============================================
      // GROUPS TABLE - EXACT MATCH WITH LOCAL
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.groups (
          group_guid TEXT PRIMARY KEY,
          company_guid TEXT NOT NULL,
          name TEXT NOT NULL,
          reserved_name TEXT,
          alter_id INTEGER,
          parent_guid TEXT,
          narration TEXT,
          is_billwise_on INTEGER DEFAULT 0,
          is_addable INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          is_subledger INTEGER DEFAULT 0,
          is_revenue INTEGER DEFAULT 0,
          affects_gross_profit INTEGER DEFAULT 0,
          is_deemed_positive INTEGER DEFAULT 0,
          track_negative_balances INTEGER DEFAULT 0,
          is_condensed INTEGER DEFAULT 0,
          addl_alloc_type TEXT,
          gst_applicable TEXT,
          tds_applicable TEXT,
          tcs_applicable TEXT,
          sort_position INTEGER DEFAULT 0,
          language_names TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Create indexes for groups
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_groups_company ON $schemaName.groups(company_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_groups_name ON $schemaName.groups(name)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_groups_guid ON $schemaName.groups(group_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_groups_parent_guid ON $schemaName.groups(parent_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_groups_alter_id ON $schemaName.groups(alter_id)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_groups_deleted ON $schemaName.groups(is_deleted)');

      // ============================================
      // LEDGERS TABLE - EXACT MATCH WITH LOCAL
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.ledgers (
          ledger_guid TEXT PRIMARY KEY,
          company_guid TEXT NOT NULL,
          name TEXT NOT NULL,
          alter_id INTEGER,
          parent TEXT,
          parent_guid TEXT,
          narration TEXT,
          description TEXT,
          currency_name TEXT,
          email TEXT,
          website TEXT,
          income_tax_number TEXT,
          party_gstin TEXT,
          prior_state_name TEXT,
          country_of_residence TEXT,
          opening_balance REAL DEFAULT 0,
          closing_balance REAL DEFAULT 0,
          credit_limit REAL DEFAULT 0,
          is_billwise_on INTEGER DEFAULT 0,
          is_cost_centres_on INTEGER DEFAULT 0,
          is_interest_on INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          is_cost_tracking_on INTEGER DEFAULT 0,
          is_credit_days_chk_on INTEGER DEFAULT 0,
          affects_stock INTEGER DEFAULT 0,
          is_gst_applicable INTEGER DEFAULT 0,
          is_tds_applicable INTEGER DEFAULT 0,
          is_tcs_applicable INTEGER DEFAULT 0,
          tax_classification_name TEXT,
          tax_type TEXT,
          gst_type TEXT,
          gst_nature_of_supply TEXT,
          bill_credit_period TEXT,
          ifsc_code TEXT,
          swift_code TEXT,
          bank_account_holder_name TEXT,
          ledger_phone TEXT,
          ledger_mobile TEXT,
          ledger_contact TEXT,
          ledger_country_isd_code TEXT,
          sort_position INTEGER DEFAULT 0,
          mailing_name TEXT,
          mailing_state TEXT,
          mailing_pincode TEXT,
          mailing_country TEXT,
          mailing_address TEXT,
          gst_registration_type TEXT,
          gst_applicable_from TEXT,
          gst_place_of_supply TEXT,
          gstin TEXT,
          language_names TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Ledgers indexes
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_company ON $schemaName.ledgers(company_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_name ON $schemaName.ledgers(name)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_guid ON $schemaName.ledgers(ledger_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_parent ON $schemaName.ledgers(parent)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_parent_guid ON $schemaName.ledgers(parent_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_alter_id ON $schemaName.ledgers(alter_id)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_deleted ON $schemaName.ledgers(is_deleted)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_gstin ON $schemaName.ledgers(gstin)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_party_gstin ON $schemaName.ledgers(party_gstin)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_company_name ON $schemaName.ledgers(company_guid, name)');

      // ============================================
      // LEDGER CONTACTS TABLE
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.ledger_contacts (
          ledger_guid TEXT NOT NULL,
          name TEXT NOT NULL,
          phone_number TEXT NOT NULL,
          country_isd_code TEXT,
          is_default_whatsapp_num INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_contacts_ledger ON $schemaName.ledger_contacts(ledger_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_contacts_phone ON $schemaName.ledger_contacts(phone_number)');

      // ============================================
      // LEDGER MAILING DETAILS TABLE
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.ledger_mailing_details (
          ledger_guid TEXT NOT NULL,
          applicable_from TEXT NOT NULL,
          mailing_name TEXT,
          state TEXT,
          country TEXT,
          pincode TEXT,
          address TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_mailing_ledger ON $schemaName.ledger_mailing_details(ledger_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_mailing_date ON $schemaName.ledger_mailing_details(applicable_from)');

      // ============================================
      // LEDGER GST REGISTRATIONS TABLE
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.ledger_gst_registrations (
          ledger_guid TEXT NOT NULL,
          applicable_from TEXT NOT NULL,
          gst_registration_type TEXT,
          place_of_supply TEXT,
          gstin TEXT,
          transporter_id TEXT,
          is_oth_territory_assessee INTEGER DEFAULT 0,
          consider_purchase_for_export INTEGER DEFAULT 0,
          is_transporter INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_gst_ledger ON $schemaName.ledger_gst_registrations(ledger_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_gst_gstin ON $schemaName.ledger_gst_registrations(gstin)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_gst_date ON $schemaName.ledger_gst_registrations(applicable_from)');


      await _connection!.execute('''
  CREATE TABLE IF NOT EXISTS $schemaName.ledger_closing_balances (
    ledger_guid TEXT NOT NULL,
    company_guid TEXT NOT NULL,
    closing_date TEXT NOT NULL,
    amount REAL NOT NULL,
    FOREIGN KEY (ledger_guid) REFERENCES ledgers(ledger_guid) ON DELETE CASCADE
  )
''');

      await _connection!.execute(
    'CREATE INDEX IF NOT EXISTS idx_ledger_closing_ledger ON $schemaName.ledger_closing_balances(ledger_guid)');
      await _connection!.execute(
    'CREATE INDEX IF NOT EXISTS idx_ledger_closing_company ON $schemaName.ledger_closing_balances(company_guid)');
      await _connection!.execute(
    'CREATE INDEX IF NOT EXISTS idx_ledger_closing_date ON $schemaName.ledger_closing_balances(closing_date)');
      await _connection!.execute(
    'CREATE INDEX IF NOT EXISTS idx_ledger_closing_ledger_date ON $schemaName.ledger_closing_balances(ledger_guid, closing_date DESC)');

      // ============================================
      // STOCK ITEMS TABLE - EXACT MATCH WITH LOCAL
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.stock_items (
          stock_item_guid TEXT PRIMARY KEY,
          company_guid TEXT NOT NULL,
          name TEXT NOT NULL,
          alter_id INTEGER,
          parent TEXT,
          category TEXT,
          description TEXT,
          narration TEXT,
          base_units TEXT,
          additional_units TEXT,
          denominator REAL,
          conversion REAL,
          gst_applicable TEXT,
          gst_type_of_supply TEXT,
          costing_method TEXT,
          valuation_method TEXT,
          is_cost_centres_on INTEGER DEFAULT 0,
          is_batchwise_on INTEGER DEFAULT 0,
          is_perishable_on INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          ignore_negative_stock INTEGER DEFAULT 0,
          latest_hsn_code TEXT,
          latest_hsn_description TEXT,
          latest_hsn_applicable_from TEXT,
          latest_gst_taxability TEXT,
          latest_gst_applicable_from TEXT,
          latest_gst_is_reverse_charge INTEGER DEFAULT 0,
          latest_cgst_rate REAL,
          latest_sgst_rate REAL,
          latest_igst_rate REAL,
          latest_cess_rate REAL,
          latest_state_cess_rate REAL,
          latest_mrp_rate REAL,
          latest_mrp_from_date TEXT,
          mailing_names TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Stock items indexes
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_company ON $schemaName.stock_items(company_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_name ON $schemaName.stock_items(name)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_guid ON $schemaName.stock_items(stock_item_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_parent ON $schemaName.stock_items(parent)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_alter_id ON $schemaName.stock_items(alter_id)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_hsn ON $schemaName.stock_items(latest_hsn_code)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_deleted ON $schemaName.stock_items(is_deleted)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_company_name ON $schemaName.stock_items(company_guid, name)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_items_stock_item_deleted ON $schemaName.stock_items(stock_item_guid, is_deleted)');

      // ============================================
      // STOCK ITEM HSN HISTORY TABLE
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.stock_item_hsn_history (
          company_guid TEXT NOT NULL,
          applicable_from TEXT,
          hsn_code TEXT,
          stock_item_guid TEXT,
          hsn_description TEXT,
          source_of_details TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_hsn_history_stock_item ON $schemaName.stock_item_hsn_history(stock_item_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_hsn_history_code ON $schemaName.stock_item_hsn_history(hsn_code)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_hsn_history_date ON $schemaName.stock_item_hsn_history(applicable_from)');

      // ============================================
      // STOCK ITEM BATCH ALLOCATION TABLE
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.stock_item_batch_allocation (
          company_guid TEXT NOT NULL,
          stock_item_guid TEXT,
          godown_name TEXT,
          batch_name TEXT,
          mfd_on TEXT,
          opening_balance REAL DEFAULT 0,
          opening_value REAL DEFAULT 0,
          opening_rate REAL DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_batch_alloc_stock_item ON $schemaName.stock_item_batch_allocation(stock_item_guid)');

      // ============================================
      // STOCK ITEM GST HISTORY TABLE
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.stock_item_gst_history (
          company_guid TEXT NOT NULL,
          applicable_from TEXT,
          stock_item_guid TEXT,
          taxability TEXT,
          state_name TEXT,
          cgst_rate REAL,
          sgst_rate REAL,
          igst_rate REAL,
          cess_rate REAL,
          state_cess_rate REAL,
          is_reverse_charge_applicable INTEGER DEFAULT 0,
          is_non_gst_goods INTEGER DEFAULT 0,
          gst_ineligible_itc INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_gst_history_stock_item ON $schemaName.stock_item_gst_history(stock_item_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_gst_history_date ON $schemaName.stock_item_gst_history(applicable_from)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_gst_history_state ON $schemaName.stock_item_gst_history(state_name)');

      // ============================================
      // VOUCHERS TABLE - EXACT MATCH WITH LOCAL
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.vouchers (
          voucher_guid TEXT PRIMARY KEY,
          company_guid TEXT NOT NULL,
          master_id INTEGER NOT NULL,
          alter_id INTEGER,
          voucher_key BIGINT,
          voucher_retain_key INTEGER,
          date TEXT NOT NULL,
          effective_date TEXT,
          voucher_type TEXT NOT NULL,
          voucher_number TEXT NOT NULL,
          voucher_number_series TEXT,
          persisted_view TEXT,
          party_ledger_name TEXT,
          party_ledger_guid TEXT,
          party_gstin TEXT,
          amount REAL,
          total_amount REAL,
          discount REAL,
          gst_registration_type TEXT,
          place_of_supply TEXT,
          state_name TEXT,
          country_of_residence TEXT,
          narration TEXT,
          reference TEXT,
          is_deleted INTEGER DEFAULT 0,
          is_cancelled INTEGER DEFAULT 0,
          is_invoice INTEGER DEFAULT 0,
          is_optional INTEGER DEFAULT 0,
          has_discounts INTEGER DEFAULT 0,
          is_deemed_positive INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Vouchers indexes
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_company ON $schemaName.vouchers(company_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_guid ON $schemaName.vouchers(voucher_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_master_id ON $schemaName.vouchers(master_id)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_date ON $schemaName.vouchers(date)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_type ON $schemaName.vouchers(voucher_type)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_party ON $schemaName.vouchers(party_ledger_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_deleted ON $schemaName.vouchers(is_deleted)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_company_date ON $schemaName.vouchers(company_guid, date)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_vouchers_company_type ON $schemaName.vouchers(company_guid, voucher_type)');

      // ============================================
      // VOUCHER LEDGER ENTRIES TABLE - EXACT MATCH
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.voucher_ledger_entries (
          voucher_guid TEXT NOT NULL,
          ledger_name TEXT NOT NULL,
          ledger_guid TEXT,
          amount REAL NOT NULL,
          is_party_ledger INTEGER DEFAULT 0,
          is_deemed_positive INTEGER DEFAULT 0,
          bill_name TEXT,
          bill_amount REAL,
          bill_date TEXT,
          bill_type TEXT,
          instrument_number TEXT,
          instrument_date TEXT,
          transaction_type TEXT,
          cost_center_name TEXT,
          cost_center_amount REAL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_entries_voucher ON $schemaName.voucher_ledger_entries(voucher_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_entries_ledger ON $schemaName.voucher_ledger_entries(ledger_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_entries_bill ON $schemaName.voucher_ledger_entries(bill_name)');

      // ============================================
      // VOUCHER INVENTORY ENTRIES TABLE - EXACT MATCH
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.voucher_inventory_entries (
          voucher_guid TEXT NOT NULL,
          stock_item_name TEXT NOT NULL,
          stock_item_guid TEXT,
          rate TEXT,
          amount REAL NOT NULL,
          actual_qty TEXT,
          billed_qty TEXT,
          discount REAL,
          discount_percent REAL,
          gst_rate TEXT,
          cgst_amount REAL,
          sgst_amount REAL,
          igst_amount REAL,
          cess_amount REAL,
          hsn_code TEXT,
          hsn_description TEXT,
          unit TEXT,
          alternate_unit TEXT,
          tracking_number TEXT,
          order_number TEXT,
          indent_number TEXT,
          is_deemed_positive INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_inventory_entries_voucher ON $schemaName.voucher_inventory_entries(voucher_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_inventory_entries_stock ON $schemaName.voucher_inventory_entries(stock_item_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_inventory_entries_hsn ON $schemaName.voucher_inventory_entries(hsn_code)');

      // ============================================
      // VOUCHER BATCH ALLOCATIONS TABLE - EXACT MATCH WITH CORRECTED FOREIGN KEY
      // ============================================
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS $schemaName.voucher_batch_allocations (
          voucher_guid TEXT NOT NULL,
          godown_name TEXT NOT NULL,
          stock_item_name TEXT NOT NULL,
          stock_item_guid TEXT,
          batch_name TEXT,
          amount REAL NOT NULL,
          actual_qty TEXT,
          billed_qty TEXT,
          batch_id TEXT,
          mfg_date TEXT,
          expiry_date TEXT,
          batch_rate REAL,
          destination_godown_name TEXT,
          is_deemed_positive INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_batch_allocs_inventory ON $schemaName.voucher_batch_allocations(voucher_guid)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_batch_allocs_godown ON $schemaName.voucher_batch_allocations(godown_name)');
      await _connection!.execute(
          'CREATE INDEX IF NOT EXISTS idx_batch_allocs_batch ON $schemaName.voucher_batch_allocations(batch_name)');

      print('✅ All tables created in schema: $schemaName');
    } catch (e) {
      print('❌ Error creating tables in schema $schemaName: $e');
      rethrow;
    }
  }

  Future<void> checkSchemaExists(String schemaName) async {
    if (_connection == null) await initialize();

    try {
      final result = await _connection!.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.schemata 
          WHERE schema_name = \$1
        )
      ''', parameters: [schemaName]);

      final isSchemaExist = result.first[0] as bool;

      if (!isSchemaExist) {
        await createCompanySchema(schemaName);
      }
    } catch (e) {
      print('❌ Error checking schema $schemaName: $e');
    }
  }

  // ============================================
  // COMPANY SYNC - ALL 37 FIELDS FROM LOCAL DATABASE
  // ============================================
Future<void> syncCompany(Map<String, dynamic> company) async {
  if (_connection == null) await initialize();

  try {
    await _connection!.execute(
      '''
      INSERT INTO user_data.companies (
        company_guid,
        user_id,
        master_id,
        alter_id,
        company_name,
        reserved_name,
        starting_from,
        ending_at,
        books_from,
        books_beginning_from,
        gst_applicable_date,
        email,
        phone_number,
        fax_number,
        website,
        address,
        city,
        pincode,
        state,
        country,
        income_tax_number,
        pan,
        gsttin,
        currency_name,
        base_currency_name,
        maintain_accounts,
        maintain_bill_wise,
        enable_cost_centres,
        enable_interest_calc,
        maintain_inventory,
        integrate_inventory,
        multi_price_level,
        enable_batches,
        maintain_expiry_date,
        enable_job_order_processing,
        enable_cost_tracking,
        enable_job_costing,
        use_discount_column,
        use_separate_actual_billed_qty,
        is_gst_applicable,
        set_alter_company_gst_rate,
        is_tds_applicable,
        is_tcs_applicable,
        is_vat_applicable,
        is_excise_applicable,
        is_service_tax_applicable,
        enable_browser_reports,
        enable_tally_net,
        is_payroll_enabled,
        enable_payroll_statutory,
        enable_payment_link_qr,
        enable_multi_address,
        mark_modified_vouchers,
        is_deleted,
        is_audited,
        is_security_enabled,
        is_book_in_use,
        last_synced_groups_alter_id,
        last_synced_ledgers_alter_id,
        last_synced_stock_items_alter_id,
        last_synced_vouchers_alter_id,
        last_synced_voucher_types_alter_id,
        is_selected,
        created_at,
        updated_at
      )
      VALUES (
        \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10,
        \$11, \$12, \$13, \$14, \$15, \$16, \$17, \$18, \$19, \$20,
        \$21, \$22, \$23, \$24, \$25, \$26, \$27, \$28, \$29, \$30,
        \$31, \$32, \$33, \$34, \$35, \$36, \$37, \$38, \$39, \$40,
        \$41, \$42, \$43, \$44, \$45, \$46, \$47, \$48, \$49, \$50,
        \$51, \$52, \$53, \$54, \$55, \$56, \$57, \$58, \$59, \$60,
        \$61, \$62, \$63, \$64, \$65
      )
      ON CONFLICT (company_guid) 
      DO UPDATE SET
        master_id = EXCLUDED.master_id,
        alter_id = EXCLUDED.alter_id,
        company_name = EXCLUDED.company_name,
        reserved_name = EXCLUDED.reserved_name,
        starting_from = EXCLUDED.starting_from,
        ending_at = EXCLUDED.ending_at,
        books_from = EXCLUDED.books_from,
        books_beginning_from = EXCLUDED.books_beginning_from,
        gst_applicable_date = EXCLUDED.gst_applicable_date,
        email = EXCLUDED.email,
        phone_number = EXCLUDED.phone_number,
        fax_number = EXCLUDED.fax_number,
        website = EXCLUDED.website,
        address = EXCLUDED.address,
        city = EXCLUDED.city,
        pincode = EXCLUDED.pincode,
        state = EXCLUDED.state,
        country = EXCLUDED.country,
        income_tax_number = EXCLUDED.income_tax_number,
        pan = EXCLUDED.pan,
        gsttin = EXCLUDED.gsttin,
        currency_name = EXCLUDED.currency_name,
        base_currency_name = EXCLUDED.base_currency_name,
        maintain_accounts = EXCLUDED.maintain_accounts,
        maintain_bill_wise = EXCLUDED.maintain_bill_wise,
        enable_cost_centres = EXCLUDED.enable_cost_centres,
        enable_interest_calc = EXCLUDED.enable_interest_calc,
        maintain_inventory = EXCLUDED.maintain_inventory,
        integrate_inventory = EXCLUDED.integrate_inventory,
        multi_price_level = EXCLUDED.multi_price_level,
        enable_batches = EXCLUDED.enable_batches,
        maintain_expiry_date = EXCLUDED.maintain_expiry_date,
        enable_job_order_processing = EXCLUDED.enable_job_order_processing,
        enable_cost_tracking = EXCLUDED.enable_cost_tracking,
        enable_job_costing = EXCLUDED.enable_job_costing,
        use_discount_column = EXCLUDED.use_discount_column,
        use_separate_actual_billed_qty = EXCLUDED.use_separate_actual_billed_qty,
        is_gst_applicable = EXCLUDED.is_gst_applicable,
        set_alter_company_gst_rate = EXCLUDED.set_alter_company_gst_rate,
        is_tds_applicable = EXCLUDED.is_tds_applicable,
        is_tcs_applicable = EXCLUDED.is_tcs_applicable,
        is_vat_applicable = EXCLUDED.is_vat_applicable,
        is_excise_applicable = EXCLUDED.is_excise_applicable,
        is_service_tax_applicable = EXCLUDED.is_service_tax_applicable,
        enable_browser_reports = EXCLUDED.enable_browser_reports,
        enable_tally_net = EXCLUDED.enable_tally_net,
        is_payroll_enabled = EXCLUDED.is_payroll_enabled,
        enable_payroll_statutory = EXCLUDED.enable_payroll_statutory,
        enable_payment_link_qr = EXCLUDED.enable_payment_link_qr,
        enable_multi_address = EXCLUDED.enable_multi_address,
        mark_modified_vouchers = EXCLUDED.mark_modified_vouchers,
        is_deleted = EXCLUDED.is_deleted,
        is_audited = EXCLUDED.is_audited,
        is_security_enabled = EXCLUDED.is_security_enabled,
        is_book_in_use = EXCLUDED.is_book_in_use,
        last_synced_groups_alter_id = EXCLUDED.last_synced_groups_alter_id,
        last_synced_ledgers_alter_id = EXCLUDED.last_synced_ledgers_alter_id,
        last_synced_stock_items_alter_id = EXCLUDED.last_synced_stock_items_alter_id,
        last_synced_vouchers_alter_id = EXCLUDED.last_synced_vouchers_alter_id,
        last_synced_voucher_types_alter_id = EXCLUDED.last_synced_voucher_types_alter_id,
        is_selected = EXCLUDED.is_selected,
        updated_at = EXCLUDED.updated_at
      ''',
      parameters: [
        company['company_guid'],                                    // \$1
        company['user_id'],                                         // \$2
        company['master_id'],                                       // \$3
        parseInt(company['alter_id']),                              // \$4
        company['company_name'],                                    // \$5
        company['reserved_name'],                                   // \$6
        company['starting_from'],                                   // \$7
        company['ending_at'],                                       // \$8
        company['books_from'],                                      // \$9
        company['books_beginning_from'],                            // \$10
        company['gst_applicable_date'],                             // \$11
        company['email'],                                           // \$12
        company['phone_number'],                                    // \$13
        company['fax_number'],                                      // \$14
        company['website'],                                         // \$15
        company['address'],                                         // \$16
        company['city'],                                            // \$17
        company['pincode'],                                         // \$18
        company['state'],                                           // \$19
        company['country'],                                         // \$20
        company['income_tax_number'],                               // \$21
        company['pan'],                                             // \$22
        company['gsttin'],                                          // \$23
        company['currency_name'],                                   // \$24
        company['base_currency_name'],                              // \$25
        company['maintain_accounts'] ?? 0,                          // \$26
        company['maintain_bill_wise'] ?? 0,                         // \$27
        company['enable_cost_centres'] ?? 0,                        // \$28
        company['enable_interest_calc'] ?? 0,                       // \$29
        company['maintain_inventory'] ?? 0,                         // \$30
        company['integrate_inventory'] ?? 0,                        // \$31
        company['multi_price_level'] ?? 0,                          // \$32
        company['enable_batches'] ?? 0,                             // \$33
        company['maintain_expiry_date'] ?? 0,                       // \$34
        company['enable_job_order_processing'] ?? 0,                // \$35
        company['enable_cost_tracking'] ?? 0,                       // \$36
        company['enable_job_costing'] ?? 0,                         // \$37
        company['use_discount_column'] ?? 0,                        // \$38
        company['use_separate_actual_billed_qty'] ?? 0,             // \$39
        company['is_gst_applicable'] ?? 0,                          // \$40
        company['set_alter_company_gst_rate'] ?? 0,                 // \$41
        company['is_tds_applicable'] ?? 0,                          // \$42
        company['is_tcs_applicable'] ?? 0,                          // \$43
        company['is_vat_applicable'] ?? 0,                          // \$44
        company['is_excise_applicable'] ?? 0,                       // \$45
        company['is_service_tax_applicable'] ?? 0,                  // \$46
        company['enable_browser_reports'] ?? 0,                     // \$47
        company['enable_tally_net'] ?? 0,                           // \$48
        company['is_payroll_enabled'] ?? 0,                         // \$49
        company['enable_payroll_statutory'] ?? 0,                   // \$50
        company['enable_payment_link_qr'] ?? 0,                     // \$51
        company['enable_multi_address'] ?? 0,                       // \$52
        company['mark_modified_vouchers'] ?? 0,                     // \$53
        company['is_deleted'] ?? 0,                                 // \$54
        company['is_audited'] ?? 0,                                 // \$55
        company['is_security_enabled'] ?? 0,                        // \$56
        company['is_book_in_use'] ?? 0,                             // \$57
        company['last_synced_groups_alter_id'] ?? 0,                // \$58
        company['last_synced_ledgers_alter_id'] ?? 0,               // \$59
        company['last_synced_stock_items_alter_id'] ?? 0,           // \$60
        company['last_synced_vouchers_alter_id'] ?? 0,              // \$61
        company['last_synced_voucher_types_alter_id'] ?? 0,          // \$62
        company['is_selected'] ?? 0,                                // \$63
        company['created_at'],                                      // \$64
        company['updated_at'],                                      // \$65
      ],
    );
    
    print('☁️ Successfully synced company to Neon: ${company['company_name']}');
  } catch (e) {
    print('❌ Error syncing company to Neon: $e');
    rethrow;
  }
}

  Future<void> updateCompanySyncStatus(
      String companyGuid, String fieldName, int alterId) async {
    if (_connection == null) await initialize();

    try {
      // Validate field name to prevent SQL injection
      final validFields = [
        'last_synced_groups_alter_id',
        'last_synced_ledgers_alter_id',
        'last_synced_stock_items_alter_id',
        'last_synced_vouchers_alter_id',
      ];

      if (!validFields.contains(fieldName)) {
        throw ArgumentError('Invalid field name: $fieldName');
      }

      await _connection!.execute(
        'UPDATE user_data.companies SET $fieldName = \$1, updated_at = \$2 WHERE company_guid = \$3',
        parameters: [
          alterId,
          DateTime.now().toIso8601String(),
          companyGuid,
        ],
      );

      print('✅ Updated $fieldName to: $alterId for company: $companyGuid');
    } catch (e) {
      print('❌ Error updating company sync status: $e');
      rethrow;
    }
  }

  // Legacy method for backward compatibility
  @Deprecated('Use updateCompanySyncStatus instead')
  Future<void> updateCompany(
      String companyGuid, String keyName, int alterId) async {
    return updateCompanySyncStatus(companyGuid, keyName, alterId);
  }

  // ============================================
  // GROUPS SYNC - ALL 24 FIELDS
  // ============================================
  Future<void> syncGroups(
      List<Map<String, dynamic>> groups, String companyGuid) async {
    if (_connection == null) await initialize();
    final schemaName = _getSchemaName(companyGuid);
    await checkSchemaExists(schemaName);

    if (groups.isEmpty) return;

    const batchSize = 100;
    int successCount = 0;

    for (int i = 0; i < groups.length; i += batchSize) {
      final batch = groups.skip(i).take(batchSize).toList();

      try {
        await _syncGroupBatch(batch, schemaName);
        successCount += batch.length;
      } catch (e) {
        print('❌ Error syncing group batch at index $i: $e');
      }
    }

    print('✅ Synced $successCount/${groups.length} groups to Neon');
  }

  Future<void> _syncGroupBatch(
      List<Map<String, dynamic>> groups, String schemaName) async {
    if (groups.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      final baseIndex = i * 24; // 24 parameters per group

      final placeholders =
          List.generate(24, (j) => '\$${baseIndex + j + 1}').join(', ');
      valueClauses.add('($placeholders)');

      allParameters.addAll([
        group['group_guid'],
        group['company_guid'],
        group['name'],
        group['reserved_name'],
        parseInt(group['alter_id']),
        group['parent_guid'],
        group['narration'],
        group['is_billwise_on'] ?? 0,
        group['is_addable'] ?? 0,
        group['is_deleted'] ?? 0,
        group['is_subledger'] ?? 0,
        group['is_revenue'] ?? 0,
        group['affects_gross_profit'] ?? 0,
        group['is_deemed_positive'] ?? 0,
        group['track_negative_balances'] ?? 0,
        group['is_condensed'] ?? 0,
        group['addl_alloc_type'],
        group['gst_applicable'],
        group['tds_applicable'],
        group['tcs_applicable'],
        group['sort_position'] ?? 0,
        group['language_names'],
        group['created_at'],
        group['updated_at'],
      ]);
    }

    final sql = '''
    INSERT INTO $schemaName.groups (
      group_guid, company_guid, name, reserved_name, alter_id, parent_guid,
      narration, is_billwise_on, is_addable, is_deleted, is_subledger,
      is_revenue, affects_gross_profit, is_deemed_positive, track_negative_balances,
      is_condensed, addl_alloc_type, gst_applicable, tds_applicable, tcs_applicable,
      sort_position, language_names, created_at, updated_at
    )
    VALUES ${valueClauses.join(', ')}
    ON CONFLICT (group_guid) DO UPDATE SET
      name = EXCLUDED.name,
      reserved_name = EXCLUDED.reserved_name,
      alter_id = EXCLUDED.alter_id,
      parent_guid = EXCLUDED.parent_guid,
      narration = EXCLUDED.narration,
      is_billwise_on = EXCLUDED.is_billwise_on,
      is_addable = EXCLUDED.is_addable,
      is_deleted = EXCLUDED.is_deleted,
      is_subledger = EXCLUDED.is_subledger,
      is_revenue = EXCLUDED.is_revenue,
      affects_gross_profit = EXCLUDED.affects_gross_profit,
      is_deemed_positive = EXCLUDED.is_deemed_positive,
      track_negative_balances = EXCLUDED.track_negative_balances,
      is_condensed = EXCLUDED.is_condensed,
      addl_alloc_type = EXCLUDED.addl_alloc_type,
      gst_applicable = EXCLUDED.gst_applicable,
      tds_applicable = EXCLUDED.tds_applicable,
      tcs_applicable = EXCLUDED.tcs_applicable,
      sort_position = EXCLUDED.sort_position,
      language_names = EXCLUDED.language_names,
      updated_at = EXCLUDED.updated_at
  ''';

    await _connection!.execute(sql, parameters: allParameters);
  }

  // ============================================
  // LEDGERS SYNC - ALL 53 FIELDS
  // ============================================
  Future<void> syncLedgers(
      List<Map<String, dynamic>> ledgers, String companyGuid) async {
    if (_connection == null) await initialize();
    final schemaName = _getSchemaName(companyGuid);
    await checkSchemaExists(schemaName);

    if (ledgers.isEmpty) return;

    const batchSize = 50;
    int successCount = 0;

    for (int i = 0; i < ledgers.length; i += batchSize) {
      final batch = ledgers.skip(i).take(batchSize).toList();

      try {
        await _syncLedgerBatch(batch, schemaName);
        successCount += batch.length;
        print('✅ Synced $successCount/${ledgers.length} ledgers...');
      } catch (e) {
        print('❌ Error syncing ledger batch at index $i: $e');
      }
    }

    print('✅ Synced $successCount/${ledgers.length} ledgers to Neon');
  }

  Future<void> _syncLedgerBatch(
      List<Map<String, dynamic>> ledgers, String schemaName) async {
    if (ledgers.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < ledgers.length; i++) {
      final ledger = ledgers[i];
      final baseIndex = i * 53; // 53 parameters per ledger

      final placeholders =
          List.generate(53, (j) => '\$${baseIndex + j + 1}').join(', ');
      valueClauses.add('($placeholders)');

      allParameters.addAll([
        ledger['ledger_guid'],
        ledger['company_guid'],
        ledger['name'],
        parseInt(ledger['alter_id']),
        ledger['parent'],
        ledger['parent_guid'],
        ledger['narration'],
        ledger['description'],
        ledger['currency_name'],
        ledger['email'],
        ledger['website'],
        ledger['income_tax_number'],
        ledger['party_gstin'],
        ledger['prior_state_name'],
        ledger['country_of_residence'],
        ledger['opening_balance'] ?? 0,
        ledger['closing_balance'] ?? 0,
        ledger['credit_limit'] ?? 0,
        ledger['is_billwise_on'] ?? 0,
        ledger['is_cost_centres_on'] ?? 0,
        ledger['is_interest_on'] ?? 0,
        ledger['is_deleted'] ?? 0,
        ledger['is_cost_tracking_on'] ?? 0,
        ledger['is_credit_days_chk_on'] ?? 0,
        ledger['affects_stock'] ?? 0,
        ledger['is_gst_applicable'] ?? 0,
        ledger['is_tds_applicable'] ?? 0,
        ledger['is_tcs_applicable'] ?? 0,
        ledger['tax_classification_name'],
        ledger['tax_type'],
        ledger['gst_type'],
        ledger['gst_nature_of_supply'],
        ledger['bill_credit_period'],
        ledger['ifsc_code'],
        ledger['swift_code'],
        ledger['bank_account_holder_name'],
        ledger['ledger_phone'],
        ledger['ledger_mobile'],
        ledger['ledger_contact'],
        ledger['ledger_country_isd_code'],
        ledger['sort_position'] ?? 0,
        ledger['mailing_name'],
        ledger['mailing_state'],
        ledger['mailing_pincode'],
        ledger['mailing_country'],
        ledger['mailing_address'],
        ledger['gst_registration_type'],
        ledger['gst_applicable_from'],
        ledger['gst_place_of_supply'],
        ledger['gstin'],
        ledger['language_names'],
        ledger['created_at'],
        ledger['updated_at'],
      ]);
    }

    final sql = '''
    INSERT INTO $schemaName.ledgers (
      ledger_guid, company_guid, name, alter_id, parent, parent_guid, narration,
      description, currency_name, email, website, income_tax_number, party_gstin,
      prior_state_name, country_of_residence, opening_balance, closing_balance,
      credit_limit, is_billwise_on, is_cost_centres_on, is_interest_on, is_deleted,
      is_cost_tracking_on, is_credit_days_chk_on, affects_stock, is_gst_applicable,
      is_tds_applicable, is_tcs_applicable, tax_classification_name, tax_type,
      gst_type, gst_nature_of_supply, bill_credit_period, ifsc_code, swift_code,
      bank_account_holder_name, ledger_phone, ledger_mobile, ledger_contact,
      ledger_country_isd_code, sort_position, mailing_name, mailing_state,
      mailing_pincode, mailing_country, mailing_address, gst_registration_type,
      gst_applicable_from, gst_place_of_supply, gstin, language_names,
      created_at, updated_at
    )
    VALUES ${valueClauses.join(', ')}
    ON CONFLICT (ledger_guid) DO UPDATE SET
      name = EXCLUDED.name,
      alter_id = EXCLUDED.alter_id,
      parent = EXCLUDED.parent,
      parent_guid = EXCLUDED.parent_guid,
      narration = EXCLUDED.narration,
      description = EXCLUDED.description,
      currency_name = EXCLUDED.currency_name,
      email = EXCLUDED.email,
      website = EXCLUDED.website,
      income_tax_number = EXCLUDED.income_tax_number,
      party_gstin = EXCLUDED.party_gstin,
      prior_state_name = EXCLUDED.prior_state_name,
      country_of_residence = EXCLUDED.country_of_residence,
      opening_balance = EXCLUDED.opening_balance,
      closing_balance = EXCLUDED.closing_balance,
      credit_limit = EXCLUDED.credit_limit,
      is_billwise_on = EXCLUDED.is_billwise_on,
      is_cost_centres_on = EXCLUDED.is_cost_centres_on,
      is_interest_on = EXCLUDED.is_interest_on,
      is_deleted = EXCLUDED.is_deleted,
      is_cost_tracking_on = EXCLUDED.is_cost_tracking_on,
      is_credit_days_chk_on = EXCLUDED.is_credit_days_chk_on,
      affects_stock = EXCLUDED.affects_stock,
      is_gst_applicable = EXCLUDED.is_gst_applicable,
      is_tds_applicable = EXCLUDED.is_tds_applicable,
      is_tcs_applicable = EXCLUDED.is_tcs_applicable,
      tax_classification_name = EXCLUDED.tax_classification_name,
      tax_type = EXCLUDED.tax_type,
      gst_type = EXCLUDED.gst_type,
      gst_nature_of_supply = EXCLUDED.gst_nature_of_supply,
      bill_credit_period = EXCLUDED.bill_credit_period,
      ifsc_code = EXCLUDED.ifsc_code,
      swift_code = EXCLUDED.swift_code,
      bank_account_holder_name = EXCLUDED.bank_account_holder_name,
      ledger_phone = EXCLUDED.ledger_phone,
      ledger_mobile = EXCLUDED.ledger_mobile,
      ledger_contact = EXCLUDED.ledger_contact,
      ledger_country_isd_code = EXCLUDED.ledger_country_isd_code,
      sort_position = EXCLUDED.sort_position,
      mailing_name = EXCLUDED.mailing_name,
      mailing_state = EXCLUDED.mailing_state,
      mailing_pincode = EXCLUDED.mailing_pincode,
      mailing_country = EXCLUDED.mailing_country,
      mailing_address = EXCLUDED.mailing_address,
      gst_registration_type = EXCLUDED.gst_registration_type,
      gst_applicable_from = EXCLUDED.gst_applicable_from,
      gst_place_of_supply = EXCLUDED.gst_place_of_supply,
      gstin = EXCLUDED.gstin,
      language_names = EXCLUDED.language_names,
      updated_at = EXCLUDED.updated_at
  ''';

    await _connection!.execute(sql, parameters: allParameters);
  }

  // ============================================
  // STOCK ITEMS SYNC - ALL 37 FIELDS (CORRECTED)
  // ============================================
  Future<void> syncStockItems(
      List<Map<String, dynamic>> stockItems, String companyGuid) async {
    if (_connection == null) await initialize();
    final schemaName = _getSchemaName(companyGuid);
    await checkSchemaExists(schemaName);

    if (stockItems.isEmpty) return;

    const batchSize = 50;
    int successCount = 0;

    for (int i = 0; i < stockItems.length; i += batchSize) {
      final batch = stockItems.skip(i).take(batchSize).toList();

      try {
        await _syncStockItemBatch(batch, schemaName);
        successCount += batch.length;
        print('✅ Synced $successCount/${stockItems.length} stock items...');
      } catch (e) {
        print('❌ Error syncing stock item batch at index $i: $e');
      }
    }

    print('✅ Synced $successCount/${stockItems.length} stock items to Neon');
  }

  Future<void> _syncStockItemBatch(
      List<Map<String, dynamic>> stockItems, String schemaName) async {
    if (stockItems.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < stockItems.length; i++) {
      final item = stockItems[i];
      final baseIndex = i * 37; // 37 parameters per stock item (CORRECTED)

      final placeholders =
          List.generate(37, (j) => '\$${baseIndex + j + 1}').join(', ');
      valueClauses.add('($placeholders)');

      allParameters.addAll([
        item['stock_item_guid'],
        item['company_guid'],
        item['name'],
        parseInt(item['alter_id']), // CORRECTED: was item['alterid']
        item['parent'],
        item['category'],
        item['description'],
        item['narration'],
        item['base_units'],
        item['additional_units'],
        item['denominator'],
        item['conversion'],
        item['gst_applicable'],
        item['gst_type_of_supply'],
        item['costing_method'],
        item['valuation_method'],
        item['is_cost_centres_on'] ?? 0,
        item['is_batchwise_on'] ?? 0,
        item['is_perishable_on'] ?? 0,
        item['is_deleted'] ?? 0,
        item['ignore_negative_stock'] ?? 0,
        item['latest_hsn_code'],
        item['latest_hsn_description'],
        item['latest_hsn_applicable_from'],
        item['latest_gst_taxability'],
        item['latest_gst_applicable_from'],
        item['latest_gst_is_reverse_charge'] ?? 0,
        item['latest_cgst_rate'],
        item['latest_sgst_rate'],
        item['latest_igst_rate'],
        item['latest_cess_rate'],
        item['latest_state_cess_rate'],
        item['latest_mrp_rate'],
        item['latest_mrp_from_date'],
        item['mailing_names'],
        item['created_at'],
        item['updated_at'],
      ]);
    }

    final sql = '''
    INSERT INTO $schemaName.stock_items (
      stock_item_guid, company_guid, name, alter_id, parent, category, description,
      narration, base_units, additional_units, denominator, conversion, gst_applicable,
      gst_type_of_supply, costing_method, valuation_method, is_cost_centres_on,
      is_batchwise_on, is_perishable_on, is_deleted, ignore_negative_stock,
      latest_hsn_code, latest_hsn_description, latest_hsn_applicable_from,
      latest_gst_taxability, latest_gst_applicable_from, latest_gst_is_reverse_charge,
      latest_cgst_rate, latest_sgst_rate, latest_igst_rate, latest_cess_rate,
      latest_state_cess_rate, latest_mrp_rate, latest_mrp_from_date, mailing_names,
      created_at, updated_at
    )
    VALUES ${valueClauses.join(', ')}
    ON CONFLICT (stock_item_guid) DO UPDATE SET
      name = EXCLUDED.name,
      alter_id = EXCLUDED.alter_id,
      parent = EXCLUDED.parent,
      category = EXCLUDED.category,
      description = EXCLUDED.description,
      narration = EXCLUDED.narration,
      base_units = EXCLUDED.base_units,
      additional_units = EXCLUDED.additional_units,
      denominator = EXCLUDED.denominator,
      conversion = EXCLUDED.conversion,
      gst_applicable = EXCLUDED.gst_applicable,
      gst_type_of_supply = EXCLUDED.gst_type_of_supply,
      costing_method = EXCLUDED.costing_method,
      valuation_method = EXCLUDED.valuation_method,
      is_cost_centres_on = EXCLUDED.is_cost_centres_on,
      is_batchwise_on = EXCLUDED.is_batchwise_on,
      is_perishable_on = EXCLUDED.is_perishable_on,
      is_deleted = EXCLUDED.is_deleted,
      ignore_negative_stock = EXCLUDED.ignore_negative_stock,
      latest_hsn_code = EXCLUDED.latest_hsn_code,
      latest_hsn_description = EXCLUDED.latest_hsn_description,
      latest_hsn_applicable_from = EXCLUDED.latest_hsn_applicable_from,
      latest_gst_taxability = EXCLUDED.latest_gst_taxability,
      latest_gst_applicable_from = EXCLUDED.latest_gst_applicable_from,
      latest_gst_is_reverse_charge = EXCLUDED.latest_gst_is_reverse_charge,
      latest_cgst_rate = EXCLUDED.latest_cgst_rate,
      latest_sgst_rate = EXCLUDED.latest_sgst_rate,
      latest_igst_rate = EXCLUDED.latest_igst_rate,
      latest_cess_rate = EXCLUDED.latest_cess_rate,
      latest_state_cess_rate = EXCLUDED.latest_state_cess_rate,
      latest_mrp_rate = EXCLUDED.latest_mrp_rate,
      latest_mrp_from_date = EXCLUDED.latest_mrp_from_date,
      mailing_names = EXCLUDED.mailing_names,
      updated_at = EXCLUDED.updated_at
  ''';

    await _connection!.execute(sql, parameters: allParameters);
  }

  // ============================================
  // VOUCHERS SYNC - ALL 32 FIELDS (CORRECTED)
  // ============================================
  Future<void> syncVouchers(
      List<Map<String, dynamic>> vouchers, String companyGuid) async {
    if (_connection == null) await initialize();
    final schemaName = _getSchemaName(companyGuid);
    await checkSchemaExists(schemaName);

    if (vouchers.isEmpty) return;

    const batchSize = 50;
    int successCount = 0;

    for (int i = 0; i < vouchers.length; i += batchSize) {
      final batch = vouchers.skip(i).take(batchSize).toList();

      try {
        await _syncVoucherBatch(batch, schemaName);
        successCount += batch.length;
        print('✅ Synced $successCount/${vouchers.length} vouchers...');
      } catch (e) {
        print('❌ Error syncing voucher batch at index $i: $e');
      }
    }

    print('✅ Synced $successCount/${vouchers.length} vouchers to Neon');
  }

  Future<void> _syncVoucherBatch(
      List<Map<String, dynamic>> vouchers, String schemaName) async {
    if (vouchers.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < vouchers.length; i++) {
      final voucher = vouchers[i];
      final baseIndex = i * 32; // 32 parameters per voucher (CORRECTED)

      final placeholders =
          List.generate(32, (j) => '\$${baseIndex + j + 1}').join(', ');
      valueClauses.add('($placeholders)');

      allParameters.addAll([
        voucher['voucher_guid'],
        voucher['company_guid'],
        voucher['master_id'],
        parseInt(voucher['alter_id']),
        parseInt(voucher['voucher_key']),
        parseInt(voucher['voucher_retain_key']),
        voucher['date'],
        voucher['effective_date'],
        voucher['voucher_type'],
        voucher['voucher_number'],
        voucher['voucher_number_series'],
        voucher['persisted_view'],
        voucher['party_ledger_name'],
        voucher['party_ledger_guid'],
        voucher['party_gstin'],
        voucher['amount'],
        voucher['total_amount'],
        voucher['discount'],
        voucher['gst_registration_type'],
        voucher['place_of_supply'],
        voucher['state_name'],
        voucher['country_of_residence'],
        voucher['narration'],
        voucher['reference'],
        voucher['is_deleted'] ?? 0,
        voucher['is_cancelled'] ?? 0,
        voucher['is_invoice'] ?? 0,
        voucher['is_optional'] ?? 0,
        voucher['has_discounts'] ?? 0,
        voucher['is_deemed_positive'] ?? 0,
        voucher['created_at'],
        voucher['updated_at'],
      ]);
    }

    final sql = '''
    INSERT INTO $schemaName.vouchers (
      voucher_guid, company_guid, master_id, alter_id, voucher_key, voucher_retain_key,
      date, effective_date, voucher_type, voucher_number, voucher_number_series,
      persisted_view, party_ledger_name, party_ledger_guid, party_gstin, amount,
      total_amount, discount, gst_registration_type, place_of_supply, state_name,
      country_of_residence, narration, reference, is_deleted, is_cancelled, is_invoice,
      is_optional, has_discounts, is_deemed_positive, created_at, updated_at
    )
    VALUES ${valueClauses.join(', ')}
    ON CONFLICT (voucher_guid) DO UPDATE SET
      alter_id = EXCLUDED.alter_id,
      voucher_key = EXCLUDED.voucher_key,
      voucher_retain_key = EXCLUDED.voucher_retain_key,
      date = EXCLUDED.date,
      effective_date = EXCLUDED.effective_date,
      voucher_type = EXCLUDED.voucher_type,
      voucher_number = EXCLUDED.voucher_number,
      voucher_number_series = EXCLUDED.voucher_number_series,
      persisted_view = EXCLUDED.persisted_view,
      party_ledger_name = EXCLUDED.party_ledger_name,
      party_ledger_guid = EXCLUDED.party_ledger_guid,
      party_gstin = EXCLUDED.party_gstin,
      amount = EXCLUDED.amount,
      total_amount = EXCLUDED.total_amount,
      discount = EXCLUDED.discount,
      gst_registration_type = EXCLUDED.gst_registration_type,
      place_of_supply = EXCLUDED.place_of_supply,
      state_name = EXCLUDED.state_name,
      country_of_residence = EXCLUDED.country_of_residence,
      narration = EXCLUDED.narration,
      reference = EXCLUDED.reference,
      is_deleted = EXCLUDED.is_deleted,
      is_cancelled = EXCLUDED.is_cancelled,
      is_invoice = EXCLUDED.is_invoice,
      is_optional = EXCLUDED.is_optional,
      has_discounts = EXCLUDED.has_discounts,
      is_deemed_positive = EXCLUDED.is_deemed_positive,
      updated_at = EXCLUDED.updated_at
  ''';

    await _connection!.execute(sql, parameters: allParameters);
  }

  // ============================================
  // VOUCHER LEDGER ENTRIES SYNC - ALL 15 FIELDS
  // ============================================
  Future<void> syncVoucherLedgerEntries(
      List<Map<String, dynamic>> entries, String companyGuid) async {
    if (_connection == null) await initialize();
    final schemaName = _getSchemaName(companyGuid);
    await checkSchemaExists(schemaName);

    if (entries.isEmpty) return;

    const batchSize = 100;
    int successCount = 0;

    for (int i = 0; i < entries.length; i += batchSize) {
      final batch = entries.skip(i).take(batchSize).toList();

      try {
        await _syncVoucherLedgerEntriesBatch(batch, schemaName);
        successCount += batch.length;
      } catch (e) {
        print('❌ Error syncing ledger entries batch at index $i: $e');
      }
    }

    print(
        '✅ Synced $successCount/${entries.length} voucher ledger entries to Neon');
  }

  Future<void> _syncVoucherLedgerEntriesBatch(
      List<Map<String, dynamic>> entries, String schemaName) async {
    if (entries.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final baseIndex = i * 15; // 15 parameters per entry

      final placeholders =
          List.generate(15, (j) => '\$${baseIndex + j + 1}').join(', ');
      valueClauses.add('($placeholders)');

      allParameters.addAll([
        entry['voucher_guid'],
        entry['ledger_name'],
        entry['ledger_guid'],
        entry['amount'],
        entry['is_party_ledger'] ?? 0,
        entry['is_deemed_positive'] ?? 0,
        entry['bill_name'],
        entry['bill_amount'],
        entry['bill_date'],
        entry['bill_type'],
        entry['instrument_number'],
        entry['instrument_date'],
        entry['transaction_type'],
        entry['cost_center_name'],
        entry['cost_center_amount'],
      ]);
    }

    final sql = '''
    INSERT INTO $schemaName.voucher_ledger_entries (
      voucher_guid, ledger_name, ledger_guid, amount, is_party_ledger, is_deemed_positive,
      bill_name, bill_amount, bill_date, bill_type, instrument_number, instrument_date,
      transaction_type, cost_center_name, cost_center_amount
    )
    VALUES ${valueClauses.join(', ')}
  ''';

    await _connection!.execute(sql, parameters: allParameters);
  }

  // ============================================
  // VOUCHER INVENTORY ENTRIES SYNC - ALL 22 FIELDS
  // ============================================
  Future<void> syncVoucherInventoryEntries(
      List<Map<String, dynamic>> entries, String companyGuid) async {
    if (_connection == null) await initialize();
    final schemaName = _getSchemaName(companyGuid);
    await checkSchemaExists(schemaName);

    if (entries.isEmpty) return;

    const batchSize = 100;
    int successCount = 0;

    for (int i = 0; i < entries.length; i += batchSize) {
      final batch = entries.skip(i).take(batchSize).toList();

      try {
        await _syncVoucherInventoryEntriesBatch(batch, schemaName);
        successCount += batch.length;
      } catch (e) {
        print('❌ Error syncing inventory entries batch at index $i: $e');
      }
    }

    print(
        '✅ Synced $successCount/${entries.length} voucher inventory entries to Neon');
  }

  Future<void> _syncVoucherInventoryEntriesBatch(
      List<Map<String, dynamic>> entries, String schemaName) async {
    if (entries.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final baseIndex = i * 22; // 22 parameters per entry

      final placeholders =
          List.generate(22, (j) => '\$${baseIndex + j + 1}').join(', ');
      valueClauses.add('($placeholders)');

      allParameters.addAll([
        entry['voucher_guid'],
        entry['stock_item_name'],
        entry['stock_item_guid'],
        entry['rate'],
        entry['amount'],
        entry['actual_qty'],
        entry['billed_qty'],
        entry['discount'],
        entry['discount_percent'],
        entry['gst_rate'],
        entry['cgst_amount'],
        entry['sgst_amount'],
        entry['igst_amount'],
        entry['cess_amount'],
        entry['hsn_code'],
        entry['hsn_description'],
        entry['unit'],
        entry['alternate_unit'],
        entry['tracking_number'],
        entry['order_number'],
        entry['indent_number'],
        entry['is_deemed_positive'] ?? 0,
      ]);
    }

    final sql = '''
    INSERT INTO $schemaName.voucher_inventory_entries (
      voucher_guid, stock_item_name, stock_item_guid, rate, amount, actual_qty,
      billed_qty, discount, discount_percent, gst_rate, cgst_amount, sgst_amount,
      igst_amount, cess_amount, hsn_code, hsn_description, unit, alternate_unit,
      tracking_number, order_number, indent_number, is_deemed_positive
    )
    VALUES ${valueClauses.join(', ')}
  ''';

    await _connection!.execute(sql, parameters: allParameters);
  }

  // ============================================
  // VOUCHER BATCH ALLOCATIONS SYNC - ALL 14 FIELDS
  // ============================================
  Future<void> syncVoucherBatchAllocations(
      List<Map<String, dynamic>> allocations, String companyGuid) async {
    if (_connection == null) await initialize();
    final schemaName = _getSchemaName(companyGuid);
    await checkSchemaExists(schemaName);

    if (allocations.isEmpty) return;

    const batchSize = 100;
    int successCount = 0;

    for (int i = 0; i < allocations.length; i += batchSize) {
      final batch = allocations.skip(i).take(batchSize).toList();

      try {
        await _syncVoucherBatchAllocationsBatch(batch, schemaName);
        successCount += batch.length;
      } catch (e) {
        print('❌ Error syncing batch allocations batch at index $i: $e');
      }
    }

    print(
        '✅ Synced $successCount/${allocations.length} voucher batch allocations to Neon');
  }

  Future<void> _syncVoucherBatchAllocationsBatch(
      List<Map<String, dynamic>> allocations, String schemaName) async {
    if (allocations.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < allocations.length; i++) {
      final allocation = allocations[i];
      final baseIndex = i * 14; // 14 parameters per allocation

      final placeholders =
          List.generate(14, (j) => '\$${baseIndex + j + 1}').join(', ');
      valueClauses.add('($placeholders)');

      allParameters.addAll([
        allocation['voucher_guid'],
        allocation['godown_name'],
        allocation['stock_item_name'],
        allocation['stock_item_guid'],
        allocation['batch_name'],
        allocation['amount'],
        allocation['actual_qty'],
        allocation['billed_qty'],
        allocation['batch_id'],
        allocation['mfg_date'],
        allocation['expiry_date'],
        allocation['batch_rate'],
        allocation['destination_godown_name'],
        allocation['is_deemed_positive'] ?? 0,
      ]);
    }

    final sql = '''
    INSERT INTO $schemaName.voucher_batch_allocations (
      voucher_guid, godown_name, stock_item_name, stock_item_guid, batch_name,
      amount, actual_qty, billed_qty, batch_id, mfg_date, expiry_date, batch_rate,
      destination_godown_name, is_deemed_positive
    )
    VALUES ${valueClauses.join(', ')}
  ''';

    await _connection!.execute(sql, parameters: allParameters);
  }

  // ============================================
  // UTILITY FUNCTIONS
  // ============================================
  dynamic parseInt(dynamic value) {
    if (value == 0 || value == '' || value == 'null' || value == null) {
      return null;
    }
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }
}