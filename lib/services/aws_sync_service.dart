import 'package:postgres/postgres.dart';
import '../config/api_config.dart';

class AwsSyncService {
  static final AwsSyncService instance = AwsSyncService._init();
  Connection? _connection;
  DateTime? _lastUsed;
  bool _isConnecting = false;

  // Connection goes stale after 5 minutes of idle
  static const _maxIdleSeconds = 300;
  // Max retries on connection failure
  static const _maxRetries = 3;
  // Delay between retries
  static const _retryDelay = Duration(seconds: 2);

  AwsSyncService._init();

  // ============================================================
  // CONNECTION MANAGEMENT
  // ============================================================

  Future<void> initialize() async {
    if (_isConnecting) {
      // Wait for existing connection attempt
      while (_isConnecting) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    if (_connection != null && await _isConnectionAlive()) return;

    _isConnecting = true;
    try {
      await _closeExisting();
      _connection = await _openConnection();
      _lastUsed = DateTime.now();
      await createCompaniesTable();
      print('✅ AWS Aurora connected');
    } finally {
      _isConnecting = false;
    }
  }

  Future<Connection> _openConnection() async {
    return await Connection.open(
      Endpoint(
        host: AwsAuroraConfig.host,
        database: AwsAuroraConfig.database,
        username: AwsAuroraConfig.username,
        password: AwsAuroraConfig.password,
        port: AwsAuroraConfig.port,
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.require,
        connectTimeout: const Duration(seconds: 30),
        queryTimeout: const Duration(seconds: 120),
      ),
    );
  }

  Future<void> _closeExisting() async {
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
  }

  Future<bool> _isConnectionAlive() async {
    if (_connection == null) return false;

    // If idle too long, treat as stale
    if (_lastUsed != null) {
      final idleSeconds =
          DateTime.now().difference(_lastUsed!).inSeconds;
      if (idleSeconds > _maxIdleSeconds) {
        print('⚠️ Connection idle for ${idleSeconds}s, reconnecting...');
        return false;
      }
    }

    try {
      await _connection!.execute('SELECT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ensure connection is live before any operation
  Future<void> _ensureConnection() async {
    if (_connection == null || !await _isConnectionAlive()) {
      print('🔄 Reconnecting to AWS Aurora...');
      await initialize();
    }
    _lastUsed = DateTime.now();
  }

  Future<void> close() async {
    await _closeExisting();
  }

  Future<bool> isConnected() async => _connection != null && await _isConnectionAlive();

  Future<bool> testConnection() async {
    try {
      await initialize();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // RETRY WRAPPER — wraps any AWS execute call with retry logic
  // ============================================================

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempt = 0;
    while (true) {
      try {
        await _ensureConnection();
        final result = await operation();
        _lastUsed = DateTime.now();
        return result;
      } catch (e) {
        attempt++;
        final isConnectionError = _isConnectionError(e);

        if (attempt >= _maxRetries || !isConnectionError) {
          print('❌ AWS operation failed after $attempt attempt(s): $e');
          rethrow;
        }

        print('⚠️ AWS connection error (attempt $attempt/$_maxRetries), retrying in ${_retryDelay.inSeconds}s...');
        print('   Error: $e');

        // Force reconnect
        await _closeExisting();
        await Future.delayed(_retryDelay * attempt); // exponential backoff
      }
    }
  }

  bool _isConnectionError(dynamic e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('semaphore') ||
        msg.contains('errno = 121') ||
        msg.contains('broken pipe') ||
        msg.contains('reset by peer') ||
        msg.contains('connection refused');
  }

  // ============================================================
  // KEEPALIVE — call this periodically from your app (e.g. every 2 min)
  // ============================================================

  Future<void> keepAlive() async {
    try {
      if (_connection != null) {
        await _connection!.execute('SELECT 1');
        _lastUsed = DateTime.now();
        print('💓 AWS keepalive OK');
      }
    } catch (e) {
      print('⚠️ Keepalive failed, will reconnect on next use: $e');
      await _closeExisting();
    }
  }

  String _getSchemaName(String companyGuid) {
    final cleanGuid = companyGuid.replaceAll('-', '_');
    return 'company_$cleanGuid';
  }

  Future<void> createCompanySchema(String schemaName) async {
    await _ensureConnection();

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

  Future<void> deleteVouchersByGuids(List<String> guids, String companyGuid) async {
  if (guids.isEmpty) return;
  await _ensureConnection();

  final schemaName = _getSchemaName(companyGuid);

  try {
    // Build placeholders: $1, $2, $3...
    final placeholders = List.generate(guids.length, (i) => '\$${i + 1}').join(', ');

    // Delete child tables first, then vouchers
    await _connection!.execute(
      'DELETE FROM $schemaName.voucher_batch_allocations WHERE voucher_guid IN ($placeholders)',
      parameters: guids,
    );

    await _connection!.execute(
      'DELETE FROM $schemaName.voucher_inventory_entries WHERE voucher_guid IN ($placeholders)',
      parameters: guids,
    );

    await _connection!.execute(
      'DELETE FROM $schemaName.voucher_ledger_entries WHERE voucher_guid IN ($placeholders)',
      parameters: guids,
    );

    await _connection!.execute(
      'DELETE FROM $schemaName.vouchers WHERE voucher_guid IN ($placeholders)',
      parameters: guids,
    );

    print('☁️ Deleted ${guids.length} vouchers and related entries from AWS Aurora');
  } catch (e) {
    print('❌ Error deleting vouchers from AWS: $e');
    rethrow;
  }
}

  // ============================================
  // CREATE COMPANIES TABLE IN USER_DATA SCHEMA
  // This is NOT company-specific, it's a global table
  // ============================================
  Future<void> createCompaniesTable() async {
  try {
    await _connection!.execute('CREATE SCHEMA IF NOT EXISTS user_data');

    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS user_data.companies (
      id SERIAL,
        company_guid TEXT PRIMARY KEY,
        user_id TEXT,
        master_id INTEGER NOT NULL,
        alter_id INTEGER,
        company_name TEXT NOT NULL,
        reserved_name TEXT,

        -- Dates
        starting_from TEXT NOT NULL,
        ending_at TEXT NOT NULL,
        books_from TEXT,
        books_beginning_from TEXT,
        gst_applicable_date TEXT,

        -- Contact Details
        email TEXT,
        phone_number TEXT,
        fax_number TEXT,
        website TEXT,

        -- Address
        address TEXT,
        city TEXT,
        pincode TEXT,
        state TEXT,
        country TEXT,

        -- Tax Details
        income_tax_number TEXT,
        pan TEXT,
        gsttin TEXT,

        -- Currency
        currency_name TEXT,
        base_currency_name TEXT,

        -- Accounting Features
        maintain_accounts INTEGER DEFAULT 0,
        maintain_bill_wise INTEGER DEFAULT 0,
        enable_cost_centres INTEGER DEFAULT 0,
        enable_interest_calc INTEGER DEFAULT 0,

        -- Inventory Features
        maintain_inventory INTEGER DEFAULT 0,
        integrate_inventory INTEGER DEFAULT 0,
        multi_price_level INTEGER DEFAULT 0,
        enable_batches INTEGER DEFAULT 0,
        maintain_expiry_date INTEGER DEFAULT 0,
        enable_job_order_processing INTEGER DEFAULT 0,
        enable_cost_tracking INTEGER DEFAULT 0,
        enable_job_costing INTEGER DEFAULT 0,
        use_discount_column INTEGER DEFAULT 0,
        use_separate_actual_billed_qty INTEGER DEFAULT 0,

        -- Tax Features
        is_gst_applicable INTEGER DEFAULT 0,
        set_alter_company_gst_rate INTEGER DEFAULT 0,
        is_tds_applicable INTEGER DEFAULT 0,
        is_tcs_applicable INTEGER DEFAULT 0,
        is_vat_applicable INTEGER DEFAULT 0,
        is_excise_applicable INTEGER DEFAULT 0,
        is_service_tax_applicable INTEGER DEFAULT 0,

        -- Online Access Features
        enable_browser_reports INTEGER DEFAULT 0,
        enable_tally_net INTEGER DEFAULT 0,

        -- Payroll Features
        is_payroll_enabled INTEGER DEFAULT 0,
        enable_payroll_statutory INTEGER DEFAULT 0,

        -- Other Features
        enable_payment_link_qr INTEGER DEFAULT 0,
        enable_multi_address INTEGER DEFAULT 0,
        mark_modified_vouchers INTEGER DEFAULT 0,

        -- Status
        is_deleted INTEGER DEFAULT 0,
        is_audited INTEGER DEFAULT 0,
        is_security_enabled INTEGER DEFAULT 0,
        is_book_in_use INTEGER DEFAULT 0,

        -- Metadata
        is_selected INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_companies_guid ON user_data.companies(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_companies_name ON user_data.companies(company_name)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_companies_selected ON user_data.companies(is_selected)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_companies_deleted ON user_data.companies(is_deleted)');

    print('✅ Companies table created in user_data schema (AWS Aurora)');
  } catch (e) {
    print('❌ Error creating companies table: $e');
    rethrow;
  }
}

Future<void> _createTablesInSchema(String schemaName) async {
  try {
    // ============================================
    // GROUPS TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.groups (
        id SERIAL,
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
    // VOUCHER TYPES TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.voucher_types (
        id SERIAL,
        company_guid TEXT NOT NULL,
        name TEXT NOT NULL,
        voucher_type_guid TEXT PRIMARY KEY,
        reserved_name TEXT,
        parent_guid TEXT,
        alter_id INTEGER NOT NULL,
        master_id INTEGER NOT NULL,
        is_deemed_positive INTEGER NOT NULL DEFAULT 1,
        affects_stock INTEGER NOT NULL DEFAULT 0,
        is_optional INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        numbering_method TEXT NOT NULL,
        prevent_duplicates INTEGER NOT NULL DEFAULT 0,
        current_prefix TEXT,
        current_suffix TEXT,
        restart_period TEXT,
        is_tax_invoice INTEGER NOT NULL DEFAULT 0,
        print_after_save INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(company_guid, voucher_type_guid)
      )
    ''');

    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_voucher_types_company ON $schemaName.voucher_types(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_voucher_types_name ON $schemaName.voucher_types(company_guid, name)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_voucher_types_guid ON $schemaName.voucher_types(voucher_type_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_voucher_types_alter_id ON $schemaName.voucher_types(company_guid, alter_id)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_voucher_types_deleted ON $schemaName.voucher_types(is_deleted)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_voucher_types_affects_stock ON $schemaName.voucher_types(affects_stock)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_voucher_types_parent_guid ON $schemaName.voucher_types(parent_guid)');

    // ============================================
    // LEDGERS TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.ledgers (
      id SERIAL,
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
      id SERIAL PRIMARY KEY,
        ledger_guid TEXT NOT NULL,
        company_guid TEXT NOT NULL,
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
        'CREATE INDEX IF NOT EXISTS idx_ledger_contacts_company ON $schemaName.ledger_contacts(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_contacts_phone ON $schemaName.ledger_contacts(phone_number)');

    // ============================================
    // LEDGER MAILING DETAILS TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.ledger_mailing_details (
      id SERIAL PRIMARY KEY,
        ledger_guid TEXT NOT NULL,
        company_guid TEXT NOT NULL,
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
        'CREATE INDEX IF NOT EXISTS idx_ledger_mailing_company ON $schemaName.ledger_mailing_details(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_mailing_date ON $schemaName.ledger_mailing_details(applicable_from)');

    // ============================================
    // LEDGER GST REGISTRATIONS TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.ledger_gst_registrations (
      id SERIAL PRIMARY KEY,
        ledger_guid TEXT NOT NULL,
        company_guid TEXT NOT NULL,
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
        'CREATE INDEX IF NOT EXISTS idx_ledger_gst_company ON $schemaName.ledger_gst_registrations(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_gst_gstin ON $schemaName.ledger_gst_registrations(gstin)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_gst_date ON $schemaName.ledger_gst_registrations(applicable_from)');

    // ============================================
    // LEDGER CLOSING BALANCES TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.ledger_closing_balances (
      id SERIAL PRIMARY KEY,
        ledger_guid TEXT NOT NULL,
        company_guid TEXT NOT NULL,
        closing_date TEXT NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (ledger_guid) REFERENCES $schemaName.ledgers(ledger_guid) ON DELETE CASCADE
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
    // STOCK ITEMS TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.stock_items (
      id SERIAL,
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
      id SERIAL PRIMARY KEY,
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
      id SERIAL PRIMARY KEY,
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
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_batch_alloc_company ON $schemaName.stock_item_batch_allocation(company_guid)');

    // ============================================
    // STOCK ITEM CLOSING BALANCE TABLE  ← NEW (was missing entirely)
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.stock_item_closing_balance (
      id SERIAL PRIMARY KEY,
        company_guid TEXT NOT NULL,
        stock_item_guid TEXT,
        closing_balance REAL DEFAULT 0,
        closing_value REAL DEFAULT 0,
        closing_rate REAL DEFAULT 0,
        closing_date TEXT,

        FOREIGN KEY (stock_item_guid) REFERENCES $schemaName.stock_items(stock_item_guid) ON DELETE CASCADE
      )
    ''');

    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_closing_company ON $schemaName.stock_item_closing_balance(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_closing_guid ON $schemaName.stock_item_closing_balance(stock_item_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_closing_date ON $schemaName.stock_item_closing_balance(closing_date)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_closing_guid_date ON $schemaName.stock_item_closing_balance(stock_item_guid, closing_date DESC)');

    // ============================================
    // STOCK ITEM GST HISTORY TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.stock_item_gst_history (
      id SERIAL PRIMARY KEY,
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
    // VOUCHERS TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.vouchers (
      id SERIAL,
        voucher_guid TEXT PRIMARY KEY,
        company_guid TEXT NOT NULL,
        master_id INTEGER NOT NULL,
        alter_id INTEGER,
        voucher_key BIGINT,
        voucher_retain_key INTEGER,
        date TEXT NOT NULL,
        effective_date TEXT,
        voucher_type TEXT NOT NULL,
        voucher_type_guid TEXT NOT NULL,
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
    // VOUCHER LEDGER ENTRIES TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.voucher_ledger_entries (
      id SERIAL PRIMARY KEY,
        voucher_guid TEXT NOT NULL,
        company_guid TEXT NOT NULL,
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
        'CREATE INDEX IF NOT EXISTS idx_ledger_entries_company ON $schemaName.voucher_ledger_entries(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_entries_ledger ON $schemaName.voucher_ledger_entries(ledger_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_entries_bill ON $schemaName.voucher_ledger_entries(bill_name)');

    // ============================================
    // VOUCHER INVENTORY ENTRIES TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.voucher_inventory_entries (
      id SERIAL PRIMARY KEY,
        voucher_guid TEXT NOT NULL,
        company_guid TEXT NOT NULL,
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
        'CREATE INDEX IF NOT EXISTS idx_inventory_entries_company ON $schemaName.voucher_inventory_entries(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_entries_stock ON $schemaName.voucher_inventory_entries(stock_item_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_entries_hsn ON $schemaName.voucher_inventory_entries(hsn_code)');

    // ============================================
    // VOUCHER BATCH ALLOCATIONS TABLE
    // ============================================
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS $schemaName.voucher_batch_allocations (
      id SERIAL PRIMARY KEY,
        voucher_guid TEXT NOT NULL,
        company_guid TEXT NOT NULL,
        godown_name TEXT NOT NULL,
        stock_item_name TEXT NOT NULL,
        stock_item_guid TEXT,
        batch_name TEXT,
        amount REAL NOT NULL,
        actual_qty TEXT,
        billed_qty TEXT,
        batch_id TEXT,
        tracking_number TEXT,
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
        'CREATE INDEX IF NOT EXISTS idx_batch_allocs_company ON $schemaName.voucher_batch_allocations(company_guid)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_batch_allocs_godown ON $schemaName.voucher_batch_allocations(godown_name)');
    await _connection!.execute(
        'CREATE INDEX IF NOT EXISTS idx_batch_allocs_batch ON $schemaName.voucher_batch_allocations(batch_name)');

    print('✅ All tables created in schema: $schemaName (AWS Aurora)');
  } catch (e) {
    print('❌ Error creating tables in schema $schemaName: $e');
    rethrow;
  }
}

   Future<void> checkSchemaExists(String schemaName) async {
    await _ensureConnection();

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
  // COMPANY SYNC - ALL FIELDS FROM LOCAL DATABASE
  // ============================================
  Future<void> syncCompany(Map<String, dynamic> company) async {
    await _ensureConnection();

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
          \$51, \$52, \$53, \$54, \$55, \$56, \$57, \$58, \$59, \$60
        )
        ON CONFLICT (company_guid) 
        DO UPDATE SET
          master_id = EXCLUDED.master_id,
          user_id = EXCLUDED.user_id,
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
          is_selected = EXCLUDED.is_selected,
          updated_at = EXCLUDED.updated_at
        ''',
        parameters: [
          company['company_guid'],                                    // $1
          company['user_id'],                                         // $2
          company['master_id'],                                       // $3
          parseInt(company['alter_id']),                              // $4
          company['company_name'],                                    // $5
          company['reserved_name'],                                   // $6
          company['starting_from'],                                   // $7
          company['ending_at'],                                       // $8
          company['books_from'],                                      // $9
          company['books_beginning_from'],                            // $10
          company['gst_applicable_date'],                             // $11
          company['email'],                                           // $12
          company['phone_number'],                                    // $13
          company['fax_number'],                                      // $14
          company['website'],                                         // $15
          company['address'],                                         // $16
          company['city'],                                            // $17
          company['pincode'],                                         // $18
          company['state'],                                           // $19
          company['country'],                                         // $20
          company['income_tax_number'],                               // $21
          company['pan'],                                             // $22
          company['gsttin'],                                          // $23
          company['currency_name'],                                   // $24
          company['base_currency_name'],                              // $25
          company['maintain_accounts'] ?? 0,                          // $26
          company['maintain_bill_wise'] ?? 0,                         // $27
          company['enable_cost_centres'] ?? 0,                        // $28
          company['enable_interest_calc'] ?? 0,                       // $29
          company['maintain_inventory'] ?? 0,                         // $30
          company['integrate_inventory'] ?? 0,                        // $31
          company['multi_price_level'] ?? 0,                          // $32
          company['enable_batches'] ?? 0,                             // $33
          company['maintain_expiry_date'] ?? 0,                       // $34
          company['enable_job_order_processing'] ?? 0,                // $35
          company['enable_cost_tracking'] ?? 0,                       // $36
          company['enable_job_costing'] ?? 0,                         // $37
          company['use_discount_column'] ?? 0,                        // $38
          company['use_separate_actual_billed_qty'] ?? 0,             // $39
          company['is_gst_applicable'] ?? 0,                          // $40
          company['set_alter_company_gst_rate'] ?? 0,                 // $41
          company['is_tds_applicable'] ?? 0,                          // $42
          company['is_tcs_applicable'] ?? 0,                          // $43
          company['is_vat_applicable'] ?? 0,                          // $44
          company['is_excise_applicable'] ?? 0,                       // $45
          company['is_service_tax_applicable'] ?? 0,                  // $46
          company['enable_browser_reports'] ?? 0,                     // $47
          company['enable_tally_net'] ?? 0,                           // $48
          company['is_payroll_enabled'] ?? 0,                         // $49
          company['enable_payroll_statutory'] ?? 0,                   // $50
          company['enable_payment_link_qr'] ?? 0,                     // $51
          company['enable_multi_address'] ?? 0,                       // $52
          company['mark_modified_vouchers'] ?? 0,                     // $53
          company['is_deleted'] ?? 0,                                 // $54
          company['is_audited'] ?? 0,                                 // $55
          company['is_security_enabled'] ?? 0,                        // $56
          company['is_book_in_use'] ?? 0,                             // $57
          company['is_selected'] ?? 0,                                // $63
          company['created_at'],                                      // $64
          company['updated_at'],                                      // $65
        ],
      );

      print('☁️ Successfully synced company to AWS Aurora: ${company['company_name']}');
    } catch (e) {
      print('❌ Error syncing company to AWS Aurora: $e');
      rethrow;
    }
  }
  

  // ============================================
  // GROUPS SYNC - ALL 24 FIELDS
  // ============================================
  Future<void> syncGroups(
      List<Map<String, dynamic>> groups, String companyGuid) async {
    await _ensureConnection();
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

    print('✅ Synced $successCount/${groups.length} groups to AWS Aurora');
  }

  Future<void> _syncGroupBatch(
      List<Map<String, dynamic>> groups, String schemaName) async {
    if (groups.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      final baseIndex = i * 24;

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
    await _ensureConnection();
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

    print('✅ Synced $successCount/${ledgers.length} ledgers to AWS Aurora');
  }

  Future<void> _syncLedgerBatch(
      List<Map<String, dynamic>> ledgers, String schemaName) async {
    if (ledgers.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < ledgers.length; i++) {
      final ledger = ledgers[i];
      final baseIndex = i * 53;

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
  // STOCK ITEMS SYNC - ALL 37 FIELDS
  // ============================================
  Future<void> syncStockItems(
      List<Map<String, dynamic>> stockItems, String companyGuid) async {
    await _ensureConnection();
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

    print('✅ Synced $successCount/${stockItems.length} stock items to AWS Aurora');
  }

  Future<void> _syncStockItemBatch(
      List<Map<String, dynamic>> stockItems, String schemaName) async {
    if (stockItems.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < stockItems.length; i++) {
      final item = stockItems[i];
      final baseIndex = i * 37;

      final placeholders =
          List.generate(37, (j) => '\$${baseIndex + j + 1}').join(', ');
      valueClauses.add('($placeholders)');

      allParameters.addAll([
        item['stock_item_guid'],
        item['company_guid'],
        item['name'],
        parseInt(item['alter_id']),
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
// SYNC VOUCHER TYPES TO AWS/NEON
// ============================================

Future<void> syncVoucherTypes(
    List<Map<String, dynamic>> voucherTypes, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await _createTablesInSchema(schemaName);
  // await checkSchemaExists(schemaName);

  if (voucherTypes.isEmpty) return;

  const batchSize = 50;
  int successCount = 0;

  for (int i = 0; i < voucherTypes.length; i += batchSize) {
    final batch = voucherTypes.skip(i).take(batchSize).toList();

    try {
      await _syncVoucherTypeBatch(batch, schemaName);
      successCount += batch.length;
      print('✅ Synced $successCount/${voucherTypes.length} voucher types...');
    } catch (e) {
      print('❌ Error syncing voucher type batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${voucherTypes.length} voucher types to AWS Aurora');
}

Future<void> _syncVoucherTypeBatch(
    List<Map<String, dynamic>> voucherTypes, String schemaName) async {
  if (voucherTypes.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < voucherTypes.length; i++) {
    final voucherType = voucherTypes[i];
    final baseIndex = i * 20; // 21 fields

    final placeholders =
        List.generate(20, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      voucherType['company_guid'],
      voucherType['name'],
      voucherType['voucher_type_guid'],
      voucherType['parent_guid'],
      parseInt(voucherType['alter_id']),
      parseInt(voucherType['master_id']),
      voucherType['is_deemed_positive'] ?? 1,
      voucherType['affects_stock'] ?? 0,
      voucherType['is_optional'] ?? 0,
      voucherType['is_active'] ?? 1,
      voucherType['is_deleted'] ?? 0,
      voucherType['numbering_method'],
      voucherType['prevent_duplicates'] ?? 0,
      voucherType['current_prefix'],
      voucherType['current_suffix'],
      voucherType['restart_period'],
      voucherType['is_tax_invoice'] ?? 0,
      voucherType['print_after_save'] ?? 0,
      voucherType['created_at'],
      voucherType['updated_at'],
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.voucher_types (
      company_guid, name, voucher_type_guid, parent_guid, alter_id, master_id,
      is_deemed_positive, affects_stock, is_optional, is_active, is_deleted,
      numbering_method, prevent_duplicates, current_prefix, current_suffix,
      restart_period, is_tax_invoice, print_after_save, created_at, updated_at
    )
    VALUES ${valueClauses.join(', ')}
    ON CONFLICT (company_guid, voucher_type_guid) DO UPDATE SET
      name = EXCLUDED.name,
      parent_guid = EXCLUDED.parent_guid,
      alter_id = EXCLUDED.alter_id,
      master_id = EXCLUDED.master_id,
      is_deemed_positive = EXCLUDED.is_deemed_positive,
      affects_stock = EXCLUDED.affects_stock,
      is_optional = EXCLUDED.is_optional,
      is_active = EXCLUDED.is_active,
      is_deleted = EXCLUDED.is_deleted,
      numbering_method = EXCLUDED.numbering_method,
      prevent_duplicates = EXCLUDED.prevent_duplicates,
      current_prefix = EXCLUDED.current_prefix,
      current_suffix = EXCLUDED.current_suffix,
      restart_period = EXCLUDED.restart_period,
      is_tax_invoice = EXCLUDED.is_tax_invoice,
      print_after_save = EXCLUDED.print_after_save,
      updated_at = EXCLUDED.updated_at
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

  // ============================================
  // VOUCHERS SYNC - ALL 32 FIELDS
  // ============================================
  Future<void> syncVouchers(
      List<Map<String, dynamic>> vouchers, String companyGuid) async {
    await _ensureConnection();
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

    print('✅ Synced $successCount/${vouchers.length} vouchers to AWS Aurora');
  }

  Future<void> _syncVoucherBatch(
      List<Map<String, dynamic>> vouchers, String schemaName) async {
    if (vouchers.isEmpty) return;

    final valueClauses = <String>[];
    final allParameters = <dynamic>[];

    for (int i = 0; i < vouchers.length; i++) {
      final voucher = vouchers[i];
      final baseIndex = i * 33;

      final placeholders =
          List.generate(33, (j) => '\$${baseIndex + j + 1}').join(', ');
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
        voucher['voucher_type_guid'],
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
      date, effective_date, voucher_type, voucher_type_guid, voucher_number, voucher_number_series,
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
      voucher_type_guid = EXCLUDED.voucher_type_guid,
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
    await _ensureConnection();
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
        '✅ Synced $successCount/${entries.length} voucher ledger entries to AWS Aurora');
  }

  // ============================================
  // VOUCHER INVENTORY ENTRIES SYNC - ALL 22 FIELDS
  // ============================================
  Future<void> syncVoucherInventoryEntries(
      List<Map<String, dynamic>> entries, String companyGuid) async {
    await _ensureConnection();
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
        '✅ Synced $successCount/${entries.length} voucher inventory entries to AWS Aurora');
  }

  // ============================================
  // VOUCHER BATCH ALLOCATIONS SYNC - ALL 14 FIELDS
  // ============================================
  Future<void> syncVoucherBatchAllocations(
      List<Map<String, dynamic>> allocations, String companyGuid) async {
    await _ensureConnection();
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
        '✅ Synced $successCount/${allocations.length} voucher batch allocations to AWS Aurora');
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

  // ============================================================
// ADD THESE METHODS INSIDE AwsSyncService CLASS
// ============================================================

// ============================================
// LEDGER CONTACTS SYNC
// ============================================
Future<void> syncLedgerContacts(
    List<Map<String, dynamic>> contacts, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await checkSchemaExists(schemaName);

  if (contacts.isEmpty) return;

  const batchSize = 100;
  int successCount = 0;

  for (int i = 0; i < contacts.length; i += batchSize) {
    final batch = contacts.skip(i).take(batchSize).toList();
    try {
      await _syncLedgerContactsBatch(batch, schemaName);
      successCount += batch.length;
    } catch (e) {
      print('❌ Error syncing ledger contacts batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${contacts.length} ledger contacts to AWS Aurora');
}

Future<void> _syncLedgerContactsBatch(
    List<Map<String, dynamic>> contacts, String schemaName) async {
  if (contacts.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < contacts.length; i++) {
    final contact = contacts[i];
    final baseIndex = i * 6; // 6 fields

    final placeholders =
        List.generate(6, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      contact['ledger_guid'],        // $1
      contact['company_guid'],       // $2
      contact['name'],               // $3
      contact['phone_number'],       // $4
      contact['country_isd_code'],   // $5
      contact['is_default_whatsapp_num'] ?? 0, // $6
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.ledger_contacts (
      ledger_guid, company_guid, name, phone_number,
      country_isd_code, is_default_whatsapp_num
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================
// LEDGER MAILING DETAILS SYNC
// ============================================
Future<void> syncLedgerMailingDetails(
    List<Map<String, dynamic>> mailingDetails, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await checkSchemaExists(schemaName);

  if (mailingDetails.isEmpty) return;

  const batchSize = 100;
  int successCount = 0;

  for (int i = 0; i < mailingDetails.length; i += batchSize) {
    final batch = mailingDetails.skip(i).take(batchSize).toList();
    try {
      await _syncLedgerMailingDetailsBatch(batch, schemaName);
      successCount += batch.length;
    } catch (e) {
      print('❌ Error syncing ledger mailing details batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${mailingDetails.length} ledger mailing details to AWS Aurora');
}

Future<void> _syncLedgerMailingDetailsBatch(
    List<Map<String, dynamic>> mailingDetails, String schemaName) async {
  if (mailingDetails.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < mailingDetails.length; i++) {
    final detail = mailingDetails[i];
    final baseIndex = i * 8; // 8 fields

    final placeholders =
        List.generate(8, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      detail['ledger_guid'],       // $1
      detail['company_guid'],      // $2
      detail['applicable_from'],   // $3
      detail['mailing_name'],      // $4
      detail['state'],             // $5
      detail['country'],           // $6
      detail['pincode'],           // $7
      detail['address'],           // $8
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.ledger_mailing_details (
      ledger_guid, company_guid, applicable_from, mailing_name,
      state, country, pincode, address
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================
// LEDGER GST REGISTRATIONS SYNC
// ============================================
Future<void> syncLedgerGstRegistrations(
    List<Map<String, dynamic>> registrations, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await checkSchemaExists(schemaName);

  if (registrations.isEmpty) return;

  const batchSize = 100;
  int successCount = 0;

  for (int i = 0; i < registrations.length; i += batchSize) {
    final batch = registrations.skip(i).take(batchSize).toList();
    try {
      await _syncLedgerGstRegistrationsBatch(batch, schemaName);
      successCount += batch.length;
    } catch (e) {
      print('❌ Error syncing ledger GST registrations batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${registrations.length} ledger GST registrations to AWS Aurora');
}

Future<void> _syncLedgerGstRegistrationsBatch(
    List<Map<String, dynamic>> registrations, String schemaName) async {
  if (registrations.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < registrations.length; i++) {
    final reg = registrations[i];
    final baseIndex = i * 10; // 10 fields

    final placeholders =
        List.generate(10, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      reg['ledger_guid'],                          // $1
      reg['company_guid'],                         // $2
      reg['applicable_from'],                      // $3
      reg['gst_registration_type'],                // $4
      reg['place_of_supply'],                      // $5
      reg['gstin'],                                // $6
      reg['transporter_id'],                       // $7
      reg['is_oth_territory_assessee'] ?? 0,       // $8
      reg['consider_purchase_for_export'] ?? 0,    // $9
      reg['is_transporter'] ?? 0,                  // $10
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.ledger_gst_registrations (
      ledger_guid, company_guid, applicable_from, gst_registration_type,
      place_of_supply, gstin, transporter_id, is_oth_territory_assessee,
      consider_purchase_for_export, is_transporter
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================
// LEDGER CLOSING BALANCES SYNC
// ============================================
Future<void> syncLedgerClosingBalances(
    List<Map<String, dynamic>> balances, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await checkSchemaExists(schemaName);

  if (balances.isEmpty) return;

  const batchSize = 200;
  int successCount = 0;

  for (int i = 0; i < balances.length; i += batchSize) {
    final batch = balances.skip(i).take(batchSize).toList();
    try {
      await _syncLedgerClosingBalancesBatch(batch, schemaName);
      successCount += batch.length;
    } catch (e) {
      print('❌ Error syncing ledger closing balances batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${balances.length} ledger closing balances to AWS Aurora');
}

Future<void> _syncLedgerClosingBalancesBatch(
    List<Map<String, dynamic>> balances, String schemaName) async {
  if (balances.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < balances.length; i++) {
    final balance = balances[i];
    final baseIndex = i * 4; // 4 fields

    final placeholders =
        List.generate(4, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      balance['ledger_guid'],    // $1
      balance['company_guid'],   // $2
      balance['closing_date'],   // $3
      balance['amount'],         // $4
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.ledger_closing_balances (
      ledger_guid, company_guid, closing_date, amount
    )
    VALUES ${valueClauses.join(', ')}
    ON CONFLICT DO NOTHING
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================
// STOCK ITEM HSN HISTORY SYNC
// ============================================
Future<void> syncStockItemHsnHistory(
    List<Map<String, dynamic>> hsnHistory, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await checkSchemaExists(schemaName);

  if (hsnHistory.isEmpty) return;

  const batchSize = 100;
  int successCount = 0;

  for (int i = 0; i < hsnHistory.length; i += batchSize) {
    final batch = hsnHistory.skip(i).take(batchSize).toList();
    try {
      await _syncStockItemHsnHistoryBatch(batch, schemaName);
      successCount += batch.length;
    } catch (e) {
      print('❌ Error syncing stock item HSN history batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${hsnHistory.length} stock item HSN history to AWS Aurora');
}

Future<void> _syncStockItemHsnHistoryBatch(
    List<Map<String, dynamic>> hsnHistory, String schemaName) async {
  if (hsnHistory.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < hsnHistory.length; i++) {
    final hsn = hsnHistory[i];
    final baseIndex = i * 6; // 6 fields

    final placeholders =
        List.generate(6, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      hsn['company_guid'],        // $1
      hsn['applicable_from'],     // $2
      hsn['hsn_code'],            // $3
      hsn['stock_item_guid'],     // $4
      hsn['hsn_description'],     // $5
      hsn['source_of_details'],   // $6
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.stock_item_hsn_history (
      company_guid, applicable_from, hsn_code, stock_item_guid,
      hsn_description, source_of_details
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================
// STOCK ITEM BATCH ALLOCATION SYNC
// ============================================
Future<void> syncStockItemBatchAllocation(
    List<Map<String, dynamic>> allocations, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await checkSchemaExists(schemaName);

  if (allocations.isEmpty) return;

  const batchSize = 100;
  int successCount = 0;

  for (int i = 0; i < allocations.length; i += batchSize) {
    final batch = allocations.skip(i).take(batchSize).toList();
    try {
      await _syncStockItemBatchAllocationBatch(batch, schemaName);
      successCount += batch.length;
    } catch (e) {
      print('❌ Error syncing stock item batch allocation batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${allocations.length} stock item batch allocations to AWS Aurora');
}

Future<void> _syncStockItemBatchAllocationBatch(
    List<Map<String, dynamic>> allocations, String schemaName) async {
  if (allocations.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < allocations.length; i++) {
    final alloc = allocations[i];
    final baseIndex = i * 8; // 8 fields

    final placeholders =
        List.generate(8, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      alloc['company_guid'],          // $1
      alloc['stock_item_guid'],       // $2
      alloc['godown_name'],           // $3
      alloc['batch_name'],            // $4
      alloc['mfd_on'],                // $5
      alloc['opening_balance'] ?? 0,  // $6
      alloc['opening_value'] ?? 0,    // $7
      alloc['opening_rate'] ?? 0,     // $8
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.stock_item_batch_allocation (
      company_guid, stock_item_guid, godown_name, batch_name,
      mfd_on, opening_balance, opening_value, opening_rate
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================
// STOCK ITEM CLOSING BALANCE SYNC
// ============================================
Future<void> syncStockItemClosingBalance(
    List<Map<String, dynamic>> closingBalances, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await checkSchemaExists(schemaName);

  if (closingBalances.isEmpty) return;

  const batchSize = 200;
  int successCount = 0;

  for (int i = 0; i < closingBalances.length; i += batchSize) {
    final batch = closingBalances.skip(i).take(batchSize).toList();
    try {
      await _syncStockItemClosingBalanceBatch(batch, schemaName);
      successCount += batch.length;
    } catch (e) {
      print('❌ Error syncing stock item closing balance batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${closingBalances.length} stock item closing balances to AWS Aurora');
}

Future<void> _syncStockItemClosingBalanceBatch(
    List<Map<String, dynamic>> closingBalances, String schemaName) async {
  if (closingBalances.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < closingBalances.length; i++) {
    final balance = closingBalances[i];
    final baseIndex = i * 6; // 6 fields

    final placeholders =
        List.generate(6, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      balance['company_guid'],              // $1
      balance['stock_item_guid'],           // $2
      balance['closing_balance'] ?? 0,      // $3
      balance['closing_value'] ?? 0,        // $4
      balance['closing_rate'] ?? 0,         // $5
      balance['closing_date'],              // $6
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.stock_item_closing_balance (
      company_guid, stock_item_guid, closing_balance,
      closing_value, closing_rate, closing_date
    )
    VALUES ${valueClauses.join(', ')}
    ON CONFLICT DO NOTHING
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================
// STOCK ITEM GST HISTORY SYNC
// ============================================
Future<void> syncStockItemGstHistory(
    List<Map<String, dynamic>> gstHistory, String companyGuid) async {
  await _ensureConnection();
  final schemaName = _getSchemaName(companyGuid);
  await checkSchemaExists(schemaName);

  if (gstHistory.isEmpty) return;

  const batchSize = 100;
  int successCount = 0;

  for (int i = 0; i < gstHistory.length; i += batchSize) {
    final batch = gstHistory.skip(i).take(batchSize).toList();
    try {
      await _syncStockItemGstHistoryBatch(batch, schemaName);
      successCount += batch.length;
    } catch (e) {
      print('❌ Error syncing stock item GST history batch at index $i: $e');
    }
  }

  print('✅ Synced $successCount/${gstHistory.length} stock item GST history to AWS Aurora');
}

Future<void> _syncStockItemGstHistoryBatch(
    List<Map<String, dynamic>> gstHistory, String schemaName) async {
  if (gstHistory.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < gstHistory.length; i++) {
    final gst = gstHistory[i];
    final baseIndex = i * 13; // 13 fields

    final placeholders =
        List.generate(13, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      gst['company_guid'],                          // $1
      gst['applicable_from'],                       // $2
      gst['stock_item_guid'],                       // $3
      gst['taxability'],                            // $4
      gst['state_name'],                            // $5
      gst['cgst_rate'],                             // $6
      gst['sgst_rate'],                             // $7
      gst['igst_rate'],                             // $8
      gst['cess_rate'],                             // $9
      gst['state_cess_rate'],                       // $10
      gst['is_reverse_charge_applicable'] ?? 0,     // $11
      gst['is_non_gst_goods'] ?? 0,                 // $12
      gst['gst_ineligible_itc'] ?? 0,               // $13
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.stock_item_gst_history (
      company_guid, applicable_from, stock_item_guid, taxability, state_name,
      cgst_rate, sgst_rate, igst_rate, cess_rate, state_cess_rate,
      is_reverse_charge_applicable, is_non_gst_goods, gst_ineligible_itc
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================================
// FIXED: voucher_ledger_entries — added company_guid ($2)
// Field count: 15 → 16
// ============================================================
Future<void> _syncVoucherLedgerEntriesBatch(
    List<Map<String, dynamic>> entries, String schemaName) async {
  if (entries.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final baseIndex = i * 16; // was 15, now 16 with company_guid

    final placeholders =
        List.generate(16, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      entry['voucher_guid'],                   // $1
      entry['company_guid'],                   // $2  ← ADDED
      entry['ledger_name'],                    // $3
      entry['ledger_guid'],                    // $4
      entry['amount'],                         // $5
      entry['is_party_ledger'] ?? 0,           // $6
      entry['is_deemed_positive'] ?? 0,        // $7
      entry['bill_name'],                      // $8
      entry['bill_amount'],                    // $9
      entry['bill_date'],                      // $10
      entry['bill_type'],                      // $11
      entry['instrument_number'],              // $12
      entry['instrument_date'],                // $13
      entry['transaction_type'],               // $14
      entry['cost_center_name'],               // $15
      entry['cost_center_amount'],             // $16
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.voucher_ledger_entries (
      voucher_guid, company_guid, ledger_name, ledger_guid, amount,
      is_party_ledger, is_deemed_positive, bill_name, bill_amount, bill_date,
      bill_type, instrument_number, instrument_date, transaction_type,
      cost_center_name, cost_center_amount
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================================
// FIXED: voucher_inventory_entries — added company_guid ($2)
// Field count: 22 → 23
// ============================================================
Future<void> _syncVoucherInventoryEntriesBatch(
    List<Map<String, dynamic>> entries, String schemaName) async {
  if (entries.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final baseIndex = i * 23; // was 22, now 23 with company_guid

    final placeholders =
        List.generate(23, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      entry['voucher_guid'],                   // $1
      entry['company_guid'],                   // $2  ← ADDED
      entry['stock_item_name'],                // $3
      entry['stock_item_guid'],                // $4
      entry['rate'],                           // $5
      entry['amount'],                         // $6
      entry['actual_qty'],                     // $7
      entry['billed_qty'],                     // $8
      entry['discount'],                       // $9
      entry['discount_percent'],               // $10
      entry['gst_rate'],                       // $11
      entry['cgst_amount'],                    // $12
      entry['sgst_amount'],                    // $13
      entry['igst_amount'],                    // $14
      entry['cess_amount'],                    // $15
      entry['hsn_code'],                       // $16
      entry['hsn_description'],                // $17
      entry['unit'],                           // $18
      entry['alternate_unit'],                 // $19
      entry['tracking_number'],                // $20
      entry['order_number'],                   // $21
      entry['indent_number'],                  // $22
      entry['is_deemed_positive'] ?? 0,        // $23
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.voucher_inventory_entries (
      voucher_guid, company_guid, stock_item_name, stock_item_guid, rate, amount,
      actual_qty, billed_qty, discount, discount_percent, gst_rate, cgst_amount,
      sgst_amount, igst_amount, cess_amount, hsn_code, hsn_description, unit,
      alternate_unit, tracking_number, order_number, indent_number, is_deemed_positive
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}

// ============================================================
// FIXED: voucher_batch_allocations — added company_guid ($2)
// Field count: 14 → 15, also fixed placeholder count was off by 1
// ============================================================
Future<void> _syncVoucherBatchAllocationsBatch(
    List<Map<String, dynamic>> allocations, String schemaName) async {
  if (allocations.isEmpty) return;

  final valueClauses = <String>[];
  final allParameters = <dynamic>[];

  for (int i = 0; i < allocations.length; i++) {
    final allocation = allocations[i];
    final baseIndex = i * 16; // 16 fields including company_guid + is_deemed_positive

    final placeholders =
        List.generate(16, (j) => '\$${baseIndex + j + 1}').join(', ');
    valueClauses.add('($placeholders)');

    allParameters.addAll([
      allocation['voucher_guid'],                    // $1
      allocation['company_guid'],                    // $2  ← ADDED
      allocation['godown_name'],                     // $3
      allocation['stock_item_name'],                 // $4
      allocation['stock_item_guid'],                 // $5
      allocation['batch_name'],                      // $6
      allocation['amount'],                          // $7
      allocation['actual_qty'],                      // $8
      allocation['billed_qty'],                      // $9
      allocation['batch_id'],                        // $10
      allocation['tracking_number'],                 // $11
      allocation['mfg_date'],                        // $12
      allocation['expiry_date'],                     // $13
      allocation['batch_rate'],                      // $14
      allocation['destination_godown_name'],         // $15
      allocation['is_deemed_positive'] ?? 0,         // $16
    ]);
  }

  final sql = '''
    INSERT INTO $schemaName.voucher_batch_allocations (
      voucher_guid, company_guid, godown_name, stock_item_name, stock_item_guid,
      batch_name, amount, actual_qty, billed_qty, batch_id, tracking_number,
      mfg_date, expiry_date, batch_rate, destination_godown_name, is_deemed_positive
    )
    VALUES ${valueClauses.join(', ')}
  ''';

  await _connection!.execute(sql, parameters: allParameters);
}
}