import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/data_model.dart';
import '../services/neon_sync_service.dart';
import '../services/aws_sync_service.dart';
import '../utils/secure_storage.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Initialize FFI for Windows/Linux/macOS
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDB('tally_clone.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      singleInstance: true,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
  CREATE TABLE voucher_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_guid TEXT NOT NULL,
    
    -- Core Identification
    name TEXT NOT NULL,
    guid TEXT NOT NULL,
    reserved_name TEXT,
    parent_guid TEXT,
    alter_id INTEGER NOT NULL,
    master_id INTEGER NOT NULL,
    
    -- Behavior Flags (What matters for business logic)
    is_deemed_positive INTEGER NOT NULL DEFAULT 1,
    affects_stock INTEGER NOT NULL DEFAULT 0,
    is_optional INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    
    -- Numbering Configuration
    numbering_method TEXT NOT NULL,
    prevent_duplicates INTEGER NOT NULL DEFAULT 0,
    
    -- Current prefix/suffix (just store latest, not history)
    current_prefix TEXT,
    current_suffix TEXT,
    
    -- Current restart rule
    restart_period TEXT, -- "Yearly", "Monthly", "Daily", "Never"
    
    -- Tax & Invoice (useful for validation)
    is_tax_invoice INTEGER NOT NULL DEFAULT 0,
    print_after_save INTEGER NOT NULL DEFAULT 0,
    
    -- Sync Metadata
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
    UNIQUE(company_guid, guid)
  )
''');

    await db.execute(
        'CREATE INDEX idx_voucher_types_company ON voucher_types(company_guid)');
    await db.execute(
        'CREATE INDEX idx_voucher_types_name ON voucher_types(company_guid, name)');
    await db
        .execute('CREATE INDEX idx_voucher_types_guid ON voucher_types(guid)');
    await db.execute(
        'CREATE INDEX idx_voucher_types_deleted ON voucher_types(is_deleted)');
    await db.execute(
        'CREATE INDEX idx_voucher_types_parent_guid ON voucher_types(parent_guid)');

    await db.execute('''
          CREATE TABLE groups (
            group_guid TEXT PRIMARY KEY,
            company_guid TEXT NOT NULL,
            name TEXT NOT NULL,
            reserved_name TEXT,
            alter_id INTEGER,
            parent_guid TEXT,
            narration TEXT,
            is_billwise_on BOOL DEFAULT 0,
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
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
            FOREIGN KEY (parent_guid) REFERENCES groups(group_guid) ON DELETE SET NULL
          )
        ''');

    // Create indexes for groups
    await db.execute('CREATE INDEX idx_groups_company ON groups(company_guid)');
    await db.execute('CREATE INDEX idx_groups_name ON groups(name)');
    await db.execute('CREATE INDEX idx_groups_guid ON groups(group_guid)');
    await db
        .execute('CREATE INDEX idx_groups_parent_guid ON groups(parent_guid)');
    await db.execute('CREATE INDEX idx_groups_alter_id ON groups(alter_id)');
    await db.execute('CREATE INDEX idx_groups_deleted ON groups(is_deleted)');

    // Add to local_database_helper.dart in _createDB method

    await db.execute('''
        CREATE TABLE ledgers (
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
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,

          FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
          FOREIGN KEY (parent_guid) REFERENCES groups(group_guid) ON DELETE SET NULL
        )
      ''');

    // ============================================
    // LEDGER CONTACTS TABLE (Multiple contacts per ledger)
    // ============================================
    await db.execute('''
        CREATE TABLE ledger_contacts (
          ledger_guid TEXT NOT NULL,
          company_guid TEXT NOT NULL,
          name TEXT NOT NULL,
          phone_number TEXT NOT NULL,
          country_isd_code TEXT,
          is_default_whatsapp_num INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,

          FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
          FOREIGN KEY (ledger_guid) REFERENCES ledgers(ledger_guid) ON DELETE CASCADE
        )
      ''');

    // ============================================
    // LEDGER MAILING DETAILS TABLE (History of mailing addresses)
    // ============================================
    await db.execute('''
        CREATE TABLE ledger_mailing_details (
          ledger_guid TEXT NOT NULL,
          company_guid TEXT NOT NULL,
          applicable_from TEXT NOT NULL,
          mailing_name TEXT,
          state TEXT,
          country TEXT,
          pincode TEXT,
          address TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,

          FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
          FOREIGN KEY (ledger_guid) REFERENCES ledgers(ledger_guid) ON DELETE CASCADE
        )
      ''');

    // ============================================
    // LEDGER GST REGISTRATIONS TABLE (History of GST registrations)
    // ============================================
    await db.execute('''
        CREATE TABLE ledger_gst_registrations (
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
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,

          FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
          FOREIGN KEY (ledger_guid) REFERENCES ledgers(ledger_guid) ON DELETE CASCADE
        )
      ''');

    // ============================================
// LEDGER CLOSING BALANCES TABLE (Historical closing balances)
// ============================================
    await db.execute('''
  CREATE TABLE ledger_closing_balances (
    ledger_guid TEXT NOT NULL,
    company_guid TEXT NOT NULL,
    closing_date TEXT NOT NULL,
    amount REAL NOT NULL,
    
    FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
    FOREIGN KEY (ledger_guid) REFERENCES ledgers(ledger_guid) ON DELETE CASCADE
  )
''');

    // ============================================
    // CREATE INDEXES
    // ============================================

    // Ledgers indexes
    await db
        .execute('CREATE INDEX idx_ledgers_company ON ledgers(company_guid)');
    await db.execute('CREATE INDEX idx_ledgers_name ON ledgers(name)');
    await db.execute('CREATE INDEX idx_ledgers_guid ON ledgers(ledger_guid)');
    await db.execute('CREATE INDEX idx_ledgers_parent ON ledgers(parent)');
    await db.execute(
        'CREATE INDEX idx_ledgers_parent_guid ON ledgers(parent_guid)');
    await db.execute('CREATE INDEX idx_ledgers_alter_id ON ledgers(alter_id)');
    await db.execute('CREATE INDEX idx_ledgers_deleted ON ledgers(is_deleted)');
    await db.execute('CREATE INDEX idx_ledgers_gstin ON ledgers(gstin)');
    await db.execute(
        'CREATE INDEX idx_ledgers_party_gstin ON ledgers(party_gstin)');
    await db.execute(
        'CREATE INDEX idx_ledgers_company_name ON ledgers(company_guid, name)');

    // Ledger contacts indexes
    await db.execute(
        'CREATE INDEX idx_ledger_contacts_ledger ON ledger_contacts(ledger_guid)');
    await db.execute(
        'CREATE INDEX idx_ledger_contacts_phone ON ledger_contacts(phone_number)');

    // Mailing details indexes
    await db.execute(
        'CREATE INDEX idx_ledger_mailing_ledger ON ledger_mailing_details(ledger_guid)');
    await db.execute(
        'CREATE INDEX idx_ledger_mailing_date ON ledger_mailing_details(applicable_from)');

    // GST registrations indexes
    await db.execute(
        'CREATE INDEX idx_ledger_gst_ledger ON ledger_gst_registrations(ledger_guid)');
    await db.execute(
        'CREATE INDEX idx_ledger_gst_gstin ON ledger_gst_registrations(gstin)');
    await db.execute(
        'CREATE INDEX idx_ledger_gst_date ON ledger_gst_registrations(applicable_from)');

    // Index for closing balances
    await db.execute(
        'CREATE INDEX idx_ledger_closing_ledger ON ledger_closing_balances(ledger_guid)');
    await db.execute(
        'CREATE INDEX idx_ledger_closing_company ON ledger_closing_balances(company_guid)');
    await db.execute(
        'CREATE INDEX idx_ledger_closing_date ON ledger_closing_balances(closing_date)');
    await db.execute(
        'CREATE INDEX idx_ledger_closing_ledger_date ON ledger_closing_balances(ledger_guid, closing_date DESC)');

    await db.execute('''
          CREATE TABLE stock_items (
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
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE
          )
        ''');

    // ============================================
    // HSN HISTORY TABLE (Full HSN change history)
    // ============================================
    await db.execute('''
      CREATE TABLE stock_item_hsn_history (
        company_guid TEXT NOT NULL,
        applicable_from TEXT,
        hsn_code TEXT,
        stock_item_guid TEXT,
        hsn_description TEXT,
        source_of_details TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,

        FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
        FOREIGN KEY (stock_item_guid) REFERENCES stock_items(stock_item_guid) ON DELETE CASCADE      )
    ''');

    await db.execute('''
      CREATE TABLE stock_item_batch_allocation (
        company_guid TEXT NOT NULL,
        stock_item_guid TEXT,
        godown_name TEXT,
        batch_name TEXT,
        mfd_on TEXT,
        opening_balance REAL DEFAULT 0,
        opening_value REAL DEFAULT 0,
        opening_rate REAL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,

        FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
        FOREIGN KEY (stock_item_guid) REFERENCES stock_items(stock_item_guid) ON DELETE CASCADE      )
    ''');

    // ============================================
    // GST HISTORY TABLE (Full GST change history)
    // ============================================
    await db.execute('''
      CREATE TABLE stock_item_gst_history (
        company_guid TEXT NOT NULL,
        applicable_from,
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
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,

        FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
        FOREIGN KEY (stock_item_guid) REFERENCES stock_items(stock_item_guid) ON DELETE CASCADE      )
    ''');

    await db.execute(
        'CREATE INDEX idx_stock_items_company ON stock_items(company_guid)');
    await db.execute('CREATE INDEX idx_stock_items_name ON stock_items(name)');
    await db.execute(
        'CREATE INDEX idx_stock_items_guid ON stock_items(stock_item_guid)');
    await db
        .execute('CREATE INDEX idx_stock_items_parent ON stock_items(parent)');
    await db.execute(
        'CREATE INDEX idx_stock_items_alter_id ON stock_items(alter_id)');
    await db.execute(
        'CREATE INDEX idx_stock_items_hsn ON stock_items(latest_hsn_code)');
    await db.execute(
        'CREATE INDEX idx_stock_items_deleted ON stock_items(is_deleted)');
    await db.execute(
        'CREATE INDEX idx_stock_items_company_name ON stock_items(company_guid, name)');
    await db.execute(
        'CREATE INDEX idx_stock_items_stock_item_deleted ON stock_items(stock_item_guid, is_deleted)');

    // HSN History Indexes
    await db.execute(
        'CREATE INDEX idx_hsn_history_stock_item ON stock_item_hsn_history(stock_item_guid)');
    await db.execute(
        'CREATE INDEX idx_hsn_history_code ON stock_item_hsn_history(hsn_code)');
    await db.execute(
        'CREATE INDEX idx_hsn_history_date ON stock_item_hsn_history(applicable_from)');

    // GST History Indexes
    await db.execute(
        'CREATE INDEX idx_gst_history_stock_item ON stock_item_gst_history(stock_item_guid)');
    await db.execute(
        'CREATE INDEX idx_gst_history_date ON stock_item_gst_history(applicable_from)');
    await db.execute(
        'CREATE INDEX idx_gst_history_state ON stock_item_gst_history(state_name)');

    // Add to local_database_helper.dart in _createDB method

// ============================================
// VOUCHERS TABLE
// ============================================
    await db.execute('''
  CREATE TABLE vouchers (
    voucher_guid TEXT PRIMARY KEY,
    company_guid TEXT NOT NULL,
    
    -- Primary identifiers
    master_id INTEGER NOT NULL,
    alter_id INTEGER,
    voucher_key INTEGER,
    voucher_retain_key INTEGER,
    
    -- Voucher details
    date TEXT NOT NULL,
    effective_date TEXT,
    voucher_type TEXT NOT NULL,
    voucher_type_guid TEXT,
    voucher_number TEXT NOT NULL,
    voucher_number_series TEXT,
    persisted_view TEXT,
    
    -- Party details
    party_ledger_name TEXT,
    party_ledger_guid TEXT,
    party_gstin TEXT,
    
    -- Amounts
    amount REAL,
    total_amount REAL,
    discount REAL,
    
    -- GST details
    gst_registration_type TEXT,
    place_of_supply TEXT,
    state_name TEXT,
    country_of_residence TEXT,
    
    -- Text fields
    narration TEXT,
    reference TEXT,
    
    -- Boolean flags
    is_deleted INTEGER DEFAULT 0,
    is_cancelled INTEGER DEFAULT 0,
    is_invoice INTEGER DEFAULT 0,
    is_optional INTEGER DEFAULT 0,
    has_discounts INTEGER DEFAULT 0,
    is_deemed_positive INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
    FOREIGN KEY (party_ledger_guid) REFERENCES ledgers(ledger_guid) ON DELETE SET NULL
  )
''');

// ============================================
// LEDGER ENTRIES TABLE
// ============================================
    await db.execute('''
  CREATE TABLE voucher_ledger_entries (
    voucher_guid TEXT NOT NULL,
    company_guid TEXT NOT NULL,
    
    ledger_name TEXT NOT NULL,
    ledger_guid TEXT,
    amount REAL NOT NULL,
    is_party_ledger INTEGER DEFAULT 0,
    is_deemed_positive INTEGER DEFAULT 0,
    
    -- Bill allocations
    bill_name TEXT,
    bill_amount REAL,
    bill_date TEXT,
    bill_type TEXT,
    
    -- Bank allocations
    instrument_number TEXT,
    instrument_date TEXT,
    transaction_type TEXT,
    
    -- Cost center
    cost_center_name TEXT,
    cost_center_amount REAL,
    
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
    FOREIGN KEY (voucher_guid) REFERENCES vouchers(voucher_guid) ON DELETE CASCADE,
    FOREIGN KEY (ledger_guid) REFERENCES ledgers(ledger_guid) ON DELETE SET NULL
  )
''');

// ============================================
// INVENTORY ENTRIES TABLE
// ============================================
    await db.execute('''
  CREATE TABLE voucher_inventory_entries (
    voucher_guid TEXT NOT NULL,
    company_guid TEXT NOT NULL,
    
    stock_item_name TEXT NOT NULL,
    stock_item_guid TEXT,
    rate TEXT,
    amount REAL NOT NULL,
    actual_qty TEXT,
    billed_qty TEXT,
    
    -- Discount
    discount REAL,
    discount_percent REAL,
    
    -- GST details
    gst_rate TEXT,
    cgst_amount REAL,
    sgst_amount REAL,
    igst_amount REAL,
    cess_amount REAL,
    hsn_code TEXT,
    hsn_description TEXT,
    
    -- Unit
    unit TEXT,
    alternate_unit TEXT,
    
    -- Tracking
    tracking_number TEXT,
    order_number TEXT,
    indent_number TEXT,

    is_deemed_positive INTEGER DEFAULT 0,
    
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
    FOREIGN KEY (voucher_guid) REFERENCES vouchers(voucher_guid) ON DELETE CASCADE,
    FOREIGN KEY (stock_item_guid) REFERENCES stock_items(stock_item_guid) ON DELETE SET NULL
  )
''');

// ============================================
// BATCH ALLOCATIONS TABLE
// ============================================
    await db.execute('''
  CREATE TABLE voucher_batch_allocations (
    voucher_guid TEXT NOT NULL,
    company_guid TEXT NOT NULL,
    godown_name TEXT NOT NULL,
    stock_item_name TEXT NOT NULL,
    stock_item_guid TEXT,
    batch_name TEXT,
    amount REAL NOT NULL,
    actual_qty TEXT,
    billed_qty TEXT,
    tracking_number TEXT,
    
    -- Batch details
    batch_id TEXT,
    mfg_date TEXT,
    expiry_date TEXT,
    batch_rate REAL,
    destination_godown_name TEXT,

    is_deemed_positive INTEGER DEFAULT 0,
    
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (company_guid) REFERENCES companies(company_guid) ON DELETE CASCADE,
    FOREIGN KEY (voucher_guid) REFERENCES vouchers(voucher_guid) ON DELETE CASCADE,
    FOREIGN KEY (stock_item_guid) REFERENCES stock_items(stock_item_guid) ON DELETE SET NULL
  )
''');

// ============================================
// CREATE INDEXES
// ============================================

// Vouchers indexes
    await db
        .execute('CREATE INDEX idx_vouchers_company ON vouchers(company_guid)');
    await db
        .execute('CREATE INDEX idx_vouchers_guid ON vouchers(voucher_guid)');
    await db
        .execute('CREATE INDEX idx_vouchers_master_id ON vouchers(master_id)');
    await db.execute('CREATE INDEX idx_vouchers_date ON vouchers(date)');
    await db
        .execute('CREATE INDEX idx_vouchers_type ON vouchers(voucher_type)');
    await db.execute(
        'CREATE INDEX idx_vouchers_party ON vouchers(party_ledger_guid)');
    await db
        .execute('CREATE INDEX idx_vouchers_deleted ON vouchers(is_deleted)');
    await db.execute(
        'CREATE INDEX idx_vouchers_company_date ON vouchers(company_guid, date)');
    await db.execute(
        'CREATE INDEX idx_vouchers_company_type ON vouchers(company_guid, voucher_type)');

// Ledger entries indexes
    await db.execute(
        'CREATE INDEX idx_ledger_entries_voucher ON voucher_ledger_entries(voucher_guid)');
    await db.execute(
        'CREATE INDEX idx_ledger_entries_ledger ON voucher_ledger_entries(ledger_guid)');
    await db.execute(
        'CREATE INDEX idx_ledger_entries_bill ON voucher_ledger_entries(bill_name)');

// Inventory entries indexes
    await db.execute(
        'CREATE INDEX idx_inventory_entries_voucher ON voucher_inventory_entries(voucher_guid)');
    await db.execute(
        'CREATE INDEX idx_inventory_entries_stock ON voucher_inventory_entries(stock_item_guid)');
    await db.execute(
        'CREATE INDEX idx_inventory_entries_hsn ON voucher_inventory_entries(hsn_code)');

// Batch allocations indexes
    await db.execute(
        'CREATE INDEX idx_batch_allocs_inventory ON voucher_batch_allocations(voucher_guid)');
    await db.execute(
        'CREATE INDEX idx_batch_allocs_godown ON voucher_batch_allocations(godown_name)');
    await db.execute(
        'CREATE INDEX idx_batch_allocs_batch ON voucher_batch_allocations(batch_name)');

// ============================================
// COMPANIES TABLE
// ============================================
    await db.execute('''
  CREATE TABLE companies (    
    -- Primary identifiers
    company_guid TEXT PRIMARY KEY,
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
    
    -- Sync tracking
    last_synced_groups_alter_id INTEGER DEFAULT 0,
    last_synced_ledgers_alter_id INTEGER DEFAULT 0,
    last_synced_stock_items_alter_id INTEGER DEFAULT 0,
    last_synced_vouchers_alter_id INTEGER DEFAULT 0,
    last_synced_voucher_types_alter_id INTEGER DEFAULT 0,
    
    -- Metadata
    is_selected INTEGER DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
)
''');

// ============================================
// CREATE INDEXES
// ============================================
    await db
        .execute('CREATE INDEX idx_companies_guid ON companies(company_guid)');
    await db
        .execute('CREATE INDEX idx_companies_name ON companies(company_name)');
    await db.execute(
        'CREATE INDEX idx_companies_selected ON companies(is_selected)');
    await db
        .execute('CREATE INDEX idx_companies_deleted ON companies(is_deleted)');
  }

  Future<List<Map<String, dynamic>>> query({
    required String table,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    final db = await database;
    return await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ============================================
  // UPDATE METHOD
  // ============================================
  Future<int> update({
    required String table,
    required Map<String, dynamic> values,
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  // ============================================
  // DELETE METHOD
  // ============================================
  Future<int> delete({
    required String table,
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<void> clearAllData(String companyId) async {
    final db = await database;

    await db.transaction((txn) async {
      // Delete in reverse order of dependencies

      // 1. Delete voucher-related data first
      await txn.delete('voucher_batch_allocations',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('voucher_inventory_entries',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('voucher_ledger_entries',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('vouchers',
          where: 'company_guid = ?', whereArgs: [companyId]);

      // 2. Delete stock item related data
      await txn.delete('stock_item_gst_history',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('stock_item_batch_allocation',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('stock_item_hsn_history',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('stock_items',
          where: 'company_guid = ?', whereArgs: [companyId]);

      // 3. Delete ledger related data
      await txn.delete('ledger_closing_balances',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('ledger_gst_registrations',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('ledger_mailing_details',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn.delete('ledger_contacts',
          where: 'company_guid = ?', whereArgs: [companyId]);
      await txn
          .delete('ledgers', where: 'company_guid = ?', whereArgs: [companyId]);

      // 4. Delete groups
      await txn
          .delete('groups', where: 'company_guid = ?', whereArgs: [companyId]);

      // 5. Finally delete company
      await txn.delete('companies',
          where: 'company_guid = ?', whereArgs: [companyId]);
    });
  }

//   Future<void> clearAllData(String companyId) async {
//   final db = await database;

//   // Single delete - everything cascades automatically!
//   await db.delete(
//     'companies',
//     where: 'company_guid = ?',
//     whereArgs: [companyId],
//   );
// }

  Future<Map<String, dynamic>?> getSelectedCompanyByGuid() async {
    final String? selectedGuid = await SecureStorage.getSelectedCompanyGuid();
    if (selectedGuid == null || selectedGuid.isEmpty) {
      return null;
    } else {
      final db = await database;

      final results = await db.query(
        'companies',
        where: 'company_guid = ?',
        whereArgs: [selectedGuid],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    }
  }

  /// Get all companies
  Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final db = await database;
    return await db.query('companies', orderBy: 'created_at DESC');
  }

  /// Get company by GUID
  Future<Map<String, dynamic>?> getCompanyByGuid(String guid) async {
    final db = await database;
    final results = await db.query(
      'companies',
      where: 'company_guid = ?',
      whereArgs: [guid],
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get company by name
  Future<Map<String, dynamic>?> getCompanyByName(String name) async {
    final db = await database;
    final results = await db.query(
      'companies',
      where: 'company_name = ?',
      whereArgs: [name],
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get selected company
  Future<Map<String, dynamic>?> getSelectedCompany() async {
    final db = await database;
    final results = await db.query(
      'companies',
      where: 'is_selected = 1',
      limit: 1,
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Set selected company (only one can be selected at a time)
  Future<void> setSelectedCompany(String guid) async {
    final db = await database;

    await db.transaction((txn) async {
      // Unselect all companies
      await txn.update(
        'companies',
        {'is_selected': 0},
      );

      // Select the requested company
      await txn.update(
        'companies',
        {'is_selected': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'company_guid = ?',
        whereArgs: [guid],
      );
    });

    print('✅ Selected company: $guid');
  }

  /// Update sync tracking for a company
  Future<void> updateSyncTracking(
    String companyGuid, {
    int? lastSyncedGroupsAlterId,
    int? lastSyncedLedgersAlterId,
    int? lastSyncedStockItemsAlterId,
    int? lastSyncedVouchersAlterId,
    int? lastSyncedVoucherTypesAlterId,
  }) async {
    final db = await database;

    final updateData = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (lastSyncedGroupsAlterId != null) {
      updateData['last_synced_groups_alter_id'] = lastSyncedGroupsAlterId;
    }
    if (lastSyncedLedgersAlterId != null) {
      updateData['last_synced_ledgers_alter_id'] = lastSyncedLedgersAlterId;
    }
    if (lastSyncedStockItemsAlterId != null) {
      updateData['last_synced_stock_items_alter_id'] =
          lastSyncedStockItemsAlterId;
    }
    if (lastSyncedVouchersAlterId != null) {
      updateData['last_synced_vouchers_alter_id'] = lastSyncedVouchersAlterId;
    
    }
    
    if (lastSyncedVoucherTypesAlterId != null) {
      updateData['last_synced_voucher_types_alter_id'] = lastSyncedVoucherTypesAlterId;
    }

    await db.update(
      'companies',
      updateData,
      where: 'company_guid = ?',
      whereArgs: [companyGuid],
    );

    print('✅ Updated sync tracking for: $companyGuid');
  }

  /// Delete company
  Future<void> deleteCompany(String guid) async {
    final db = await database;

    await db.delete(
      'companies',
      where: 'company_guid = ?',
      whereArgs: [guid],
    );

    print('✅ Deleted company: $guid');
  }

  /// Save single company (insert or update) - UPDATED WITH AWS SYNC
  Future<void> saveCompany(Company company, {bool syncToAws = false}) async {
    final db = await database;

    final companyData =
        company.toMap(); // Use the model's toMap method which has all fields

    await db.insert(
      'companies',
      companyData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('✅ Saved company locally: ${company.name}');

    // Auto-sync to AWS
    if (syncToAws) {
      try {
        await AwsSyncService.instance.syncCompany(companyData);
        print('☁️ Synced company to AWS: ${company.name}');
      } catch (e) {
        print('⚠️ AWS sync failed for company ${company.name}: $e');
        // Don't throw - local save succeeded
      }
    }
  }

  /// Save multiple companies in batch - UPDATED WITH AWS SYNC
  Future<void> saveCompanyBatch(List<Company> companies,
      {bool syncToAws = false}) async {
    print('💾 Saving ${companies.length} companies locally...');

    final db = await database;
    final batch = db.batch();

    for (final company in companies) {
      final companyData = {
        'company_guid': company.guid,
        'master_id': company.masterId,
        'alter_id': company.alterId,
        'company_name': company.name,
        'reserved_name': company.reservedName,
        'starting_from': company.startingFrom,
        'ending_at': company.endingAt,
        'books_from': company.booksFrom,
        'gst_applicable_date': company.gstApplicableDate,
        'email': company.email,
        'phone_number': company.phoneNumber,
        'fax_number': company.faxNumber,
        'website': company.website,
        'address': company.address,
        'city': company.city,
        'pincode': company.pincode,
        'state': company.state,
        'country': company.country,
        'income_tax_number': company.incomeTaxNumber,
        'pan': company.pan,
        'gsttin': company.gsttin,
        'currency_name': company.currencyName,
        'maintain_bill_wise': company.maintainBillWise ? 1 : 0,
        'maintain_inventory': company.maintainInventory ? 1 : 0,
        'integrate_inventory': company.integrateInventory ? 1 : 0,
        'is_gst_applicable': company.isGstApplicable ? 1 : 0,
        'is_tds_applicable': company.isTdsApplicable ? 1 : 0,
        'is_tcs_applicable': company.isTcsApplicable ? 1 : 0,
        'is_payroll_enabled': company.isPayrollEnabled ? 1 : 0,
        'is_deleted': company.isDeleted ? 1 : 0,
        'is_security_enabled': company.isSecurityEnabled ? 1 : 0,
        'last_synced_groups_alter_id': company.lastSyncedGroupsAlterId,
        'last_synced_ledgers_alter_id': company.lastSyncedLedgersAlterId,
        'last_synced_stock_items_alter_id': company.lastSyncedStockItemsAlterId,
        'last_synced_vouchers_alter_id': company.lastSyncedVouchersAlterId,
        'is_selected': company.isSelected ? 1 : 0,
        'created_at': company.createdAt,
        'updated_at': company.updatedAt,
      };

      batch.insert(
        'companies',
        companyData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('✅ Saved: ${companies.length} companies locally');

    // NEW: Auto-sync to AWS
    if (syncToAws) {
      for (final company in companies) {
        try {
          final companyData = {
            'company_guid': company.guid,
            'master_id': company.masterId,
            'alter_id': company.alterId,
            'company_name': company.name,
            'reserved_name': company.reservedName,
            'starting_from': company.startingFrom,
            'ending_at': company.endingAt,
            'books_from': company.booksFrom,
            'gst_applicable_date': company.gstApplicableDate,
            'email': company.email,
            'phone_number': company.phoneNumber,
            'fax_number': company.faxNumber,
            'website': company.website,
            'address': company.address,
            'city': company.city,
            'pincode': company.pincode,
            'state': company.state,
            'country': company.country,
            'income_tax_number': company.incomeTaxNumber,
            'pan': company.pan,
            'gsttin': company.gsttin,
            'currency_name': company.currencyName,
            'maintain_bill_wise': company.maintainBillWise ? 1 : 0,
            'maintain_inventory': company.maintainInventory ? 1 : 0,
            'integrate_inventory': company.integrateInventory ? 1 : 0,
            'is_gst_applicable': company.isGstApplicable ? 1 : 0,
            'is_tds_applicable': company.isTdsApplicable ? 1 : 0,
            'is_tcs_applicable': company.isTcsApplicable ? 1 : 0,
            'is_payroll_enabled': company.isPayrollEnabled ? 1 : 0,
            'is_deleted': company.isDeleted ? 1 : 0,
            'is_security_enabled': company.isSecurityEnabled ? 1 : 0,
            'last_synced_groups_alter_id': company.lastSyncedGroupsAlterId,
            'last_synced_ledgers_alter_id': company.lastSyncedLedgersAlterId,
            'last_synced_stock_items_alter_id':
                company.lastSyncedStockItemsAlterId,
            'last_synced_vouchers_alter_id': company.lastSyncedVouchersAlterId,
            'is_selected': company.isSelected ? 1 : 0,
            'created_at': company.createdAt,
            'updated_at': company.updatedAt,
          };

          await AwsSyncService.instance.syncCompany(companyData);
        } catch (e) {
          print('⚠️ AWS sync failed for company ${company.name}: $e');
        }
      }
      print('☁️ Synced ${companies.length} companies to AWS');
    }
  }

  /// Get all selected companies (if you want multi-select in future)
  Future<List<Map<String, dynamic>>> getSelectedCompanies() async {
    final db = await database;
    return await db.query(
      'companies',
      where: 'is_selected = 1',
    );
  }

  /// Toggle company selection (for multi-select)
  Future<void> toggleCompanySelection(String guid) async {
    final db = await database;

    final company = await getCompanyByGuid(guid);
    if (company == null) return;

    final currentSelection = company['is_selected'] == 1;

    await db.update(
      'companies',
      {
        'is_selected': currentSelection ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'company_guid = ?',
      whereArgs: [guid],
    );

    print('✅ Toggled selection for: $guid');
  }

// ============================================
// STOCK ITEMS
// ============================================

  Future<void> saveStockItem(StockItem stockItem, String companyGuid) async {
    final db = await database;

    await db.transaction((txn) async {
      // Extract latest details
      final latestHsn = _getLatestHsn(stockItem.hsnDetails);
      final latestGst = _getLatestGst(stockItem.gstDetails);
      final latestGstRates = _extractGstRates(latestGst);
      final latestMrp = _getLatestMrp(stockItem.mrpDetails);

      // 1. Save main stock item (with latest data)
      final stockItemData = {
        'company_guid': companyGuid,
        'stock_item_guid': stockItem.guid,
        'name': stockItem.name,
        'alter_id': stockItem.alterid,
        'parent': _cleanValue(stockItem.parent),
        'category': _cleanValue(stockItem.category),
        'description': stockItem.description,
        'narration': stockItem.narration,
        'base_units': stockItem.baseUnits,
        'additional_units': stockItem.additionalUnits,
        'denominator': stockItem.denominator,
        'conversion': stockItem.conversion,
        'gst_applicable': _cleanValue(stockItem.gstApplicable),
        'gst_type_of_supply': stockItem.gstTypeOfSupply,
        'costing_method': stockItem.costingMethod,
        'valuation_method': stockItem.valuationMethod,
        'is_cost_centres_on': stockItem.isCostCentresOn ? 1 : 0,
        'is_batchwise_on': stockItem.isBatchwiseOn ? 1 : 0,
        'is_perishable_on': stockItem.isPerishableOn ? 1 : 0,
        'is_deleted': stockItem.isDeleted ? 1 : 0,
        'ignore_negative_stock': stockItem.ignoreNegativeStock ? 1 : 0,
        'latest_hsn_code': latestHsn?['code'],
        'latest_hsn_description': latestHsn?['description'],
        'latest_hsn_applicable_from': latestHsn?['from'],
        'latest_gst_taxability': latestGst?['taxability'],
        'latest_gst_applicable_from': latestGst?['from'],
        'latest_gst_is_reverse_charge': latestGst?['is_reverse_charge'] ?? 0,
        'latest_cgst_rate': latestGstRates['CGST'],
        'latest_sgst_rate': latestGstRates['SGST/UTGST'],
        'latest_igst_rate': latestGstRates['IGST'],
        'latest_cess_rate': latestGstRates['Cess'],
        'latest_state_cess_rate': latestGstRates['State Cess'],
        'latest_mrp_rate': latestMrp?['rate'],
        'latest_mrp_from_date': latestMrp?['from'],
        'mailing_names': jsonEncode(stockItem.mailingNames),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await txn.rawInsert('''
      INSERT INTO stock_items (${stockItemData.keys.join(', ')})
      VALUES (${List.filled(stockItemData.length, '?').join(', ')})
      ON CONFLICT(stock_item_guid) DO UPDATE SET
      ${stockItemData.keys.where((k) => k != 'stock_item_guid').map((k) => '$k = excluded.$k').join(', ')}
    ''', stockItemData.values.toList());

      // Get stock_item_id
      final result = await txn.query(
        'stock_items',
        columns: ['stock_item_guid'],
        where: 'stock_item_guid = ?',
        whereArgs: [stockItem.guid],
      );

      if (result.isEmpty) {
        throw Exception('Failed to save stock item: ${stockItem.name}');
      }

      final stockItemId = result.first['stock_item_guid'] as String;

      // 2. Delete old history
      if (stockItem.hsnDetails.isNotEmpty) {
        await txn.delete('stock_item_hsn_history',
            where: 'stock_item_guid = ?', whereArgs: [stockItemId]);
        for (final hsn in stockItem.hsnDetails) {
          await txn.insert('stock_item_hsn_history', {
            'company_guid': companyGuid,
            'stock_item_guid': stockItemId,
            'applicable_from': hsn.applicableFrom,
            'hsn_code': hsn.hsnCode,
            'hsn_description': hsn.hsnDescription,
            'source_of_details': hsn.sourceOfDetails,
          });
        }
      }

      if (stockItem.batchAllocations.isNotEmpty) {
        await txn.delete('stock_item_batch_allocation',
            where: 'stock_item_guid = ?', whereArgs: [stockItemId]);
        for (final batch in stockItem.batchAllocations) {
          await txn.insert('stock_item_batch_allocation', {
            'company_guid': companyGuid,
            'stock_item_guid': stockItemId,
            'godown_name': batch.godownName,
            'batch_name': batch.batchName,
            'mfd_on': batch.mfdOn,
            'opening_balance': batch.openingBalance,
            'opening_value': batch.openingValue,
            'opening_rate': batch.openingRate,
          });
        }
      }

      if (stockItem.gstDetails.isNotEmpty) {
        await txn.delete('stock_item_gst_history',
            where: 'stock_item_guid = ?', whereArgs: [stockItemId]);

        // 4. Insert GST history (flattened - all states and dates)
        for (final gst in stockItem.gstDetails) {
          for (final state in gst.statewiseDetails) {
            final rates = <String, double?>{
              'CGST': null,
              'SGST/UTGST': null,
              'IGST': null,
              'Cess': null,
              'State Cess': null,
            };

            for (final rate in state.rateDetails) {
              rates[rate.dutyHead] = rate.rate;
            }

            await txn.insert('stock_item_gst_history', {
              'company_guid': companyGuid,
              'stock_item_guid': stockItemId,
              'applicable_from': gst.applicableFrom,
              'taxability': gst.taxability,
              'state_name': _cleanValue(state.stateName),
              'cgst_rate': rates['CGST'],
              'sgst_rate': rates['SGST/UTGST'],
              'igst_rate': rates['IGST'],
              'cess_rate': rates['Cess'],
              'state_cess_rate': rates['State Cess'],
              'is_reverse_charge_applicable':
                  gst.isReverseChargeApplicable ? 1 : 0,
              'is_non_gst_goods': gst.isNonGstGoods ? 1 : 0,
              'gst_ineligible_itc': gst.gstIneligibleItc ? 1 : 0,
            });
          }
        }
      }

      print(
          '✅ Saved: ${stockItem.name} | HSN: ${latestHsn?['code']} | History: ${stockItem.hsnDetails.length} HSN, ${stockItem.gstDetails.length} GST, ${stockItem.mrpDetails.length} MRP');
    });
  }

  // UPDATED WITH AWS SYNC
  Future<void> saveStockItemBatch(
      List<StockItem> stockItems, String companyGuid,
      {bool syncToAws = false}) async {
    print('💾 Saving ${stockItems.length} stock items locally...');

    int successCount = 0;
    int failCount = 0;
    final savedStockItemMaps = <Map<String, dynamic>>[];

    for (final item in stockItems) {
      try {
        if (item.guid.isEmpty == false) {
          await saveStockItem(item, companyGuid);
          successCount++;

          // NEW: Collect for AWS sync
          if (syncToAws) {
            savedStockItemMaps
                .add(await _convertStockItemToMap(item, companyGuid));
          }
        }
      } catch (e) {
        print('❌ Error saving ${item.name}: $e');
        failCount++;
      }
    }

    print('✅ Local save complete! Success: $successCount, Failed: $failCount');

    // NEW: Auto-sync to AWS
    if (syncToAws && savedStockItemMaps.isNotEmpty) {
      try {
        await AwsSyncService.instance
            .syncStockItems(savedStockItemMaps, companyGuid);
        print('☁️ Synced $successCount stock items to AWS');
      } catch (e) {
        print('⚠️ AWS sync failed for stock items: $e');
      }
    }
  }

// STOCK ITEM CONVERSION
// ============================================
  Future<Map<String, dynamic>> _convertStockItemToMap(
      StockItem stockItem, String companyGuid) async {
    // Extract latest details (same logic as saveStockItem)
    final latestHsn = _getLatestHsn(stockItem.hsnDetails);
    final latestGst = _getLatestGst(stockItem.gstDetails);
    final latestGstRates = _extractGstRates(latestGst);
    final latestMrp = _getLatestMrp(stockItem.mrpDetails);

    // Return the EXACT same structure as stockItemData in saveStockItem
    return {
      'company_guid': companyGuid,
      'stock_item_guid': stockItem.guid,
      'name': stockItem.name,
      'alter_id': stockItem.alterid,
      'parent': _cleanValue(stockItem.parent),
      'category': _cleanValue(stockItem.category),
      'description': stockItem.description,
      'narration': stockItem.narration,
      'base_units': stockItem.baseUnits,
      'additional_units': stockItem.additionalUnits,
      'denominator': stockItem.denominator,
      'conversion': stockItem.conversion,
      'gst_applicable': _cleanValue(stockItem.gstApplicable),
      'gst_type_of_supply': stockItem.gstTypeOfSupply,
      'costing_method': stockItem.costingMethod,
      'valuation_method': stockItem.valuationMethod,
      'is_cost_centres_on': stockItem.isCostCentresOn ? 1 : 0,
      'is_batchwise_on': stockItem.isBatchwiseOn ? 1 : 0,
      'is_perishable_on': stockItem.isPerishableOn ? 1 : 0,
      'is_deleted': stockItem.isDeleted ? 1 : 0,
      'ignore_negative_stock': stockItem.ignoreNegativeStock ? 1 : 0,
      'latest_hsn_code': latestHsn?['code'],
      'latest_hsn_description': latestHsn?['description'],
      'latest_hsn_applicable_from': latestHsn?['from'],
      'latest_gst_taxability': latestGst?['taxability'],
      'latest_gst_applicable_from': latestGst?['from'],
      'latest_gst_is_reverse_charge': latestGst?['is_reverse_charge'] ?? 0,
      'latest_cgst_rate': latestGstRates['CGST'],
      'latest_sgst_rate': latestGstRates['SGST/UTGST'],
      'latest_igst_rate': latestGstRates['IGST'],
      'latest_cess_rate': latestGstRates['Cess'],
      'latest_state_cess_rate': latestGstRates['State Cess'],
      'latest_mrp_rate': latestMrp?['rate'],
      'latest_mrp_from_date': latestMrp?['from'],
      'mailing_names': jsonEncode(stockItem.mailingNames),
      'updated_at': DateTime.now().toIso8601String(),
      // NOTE: created_at is handled by database DEFAULT
    };
  }

  // ============================================
  // GROUPS
  // ============================================

  Future<String?> resolveParentGuid(
    String? parentName,
    String companyGuid,
    List<Group>? inMemoryGroups,
  ) async {
    final db = await database;

    if (parentName == null || parentName.isEmpty) return null;

    // First, check in-memory groups array
    if (inMemoryGroups != null) {
      try {
        final parent = inMemoryGroups.firstWhere(
          (g) => g.name == parentName && g.companyGuid == companyGuid,
        );
        return parent.groupGuid;
      } catch (e) {
        // Not found in memory, will check DB
      }
    }

    // If not in memory, check database
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      columns: ['group_guid'],
      where: 'company_guid = ? AND name = ?',
      whereArgs: [companyGuid, parentName],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first['group_guid'] as String?;
  }

  // Process and insert new groups (handles parent resolution) - UPDATED WITH AWS SYNC
  Future<void> processNewGroups(List<Group> newGroups, String companyGuid,
      {bool syncToAws = false}) async {
    final db = await database;

    // Get existing groups from DB
    final existingGroups = await getGroupsByCompany(companyGuid);

    // Merge newGroups into existingGroups (priority to new)
    Map<String, Group> allGroupsMap = {
      for (var g in existingGroups) g.groupGuid: g, // Existing first
      for (var g in newGroups) g.groupGuid: g, // New groups override
    };

    // Build name lookup map from merged groups
    Map<String, Group> nameToGroupMap = {
      for (var g in allGroupsMap.values) g.name: g
    };

    List<Group> processedGroups = [];

    // Process new groups
    for (var group in newGroups) {
      // First check in already processed groups
      String? parentGuid = nameToGroupMap[group.parent]?.groupGuid;

      // Create new group with resolved parentGuid
      final updatedGroup = Group(
        groupGuid: group.groupGuid,
        companyGuid: group.companyGuid,
        name: group.name,
        parentGuid: parentGuid, // Resolved GUID
        reservedName: group.reservedName,
        alterId: group.alterId,
        narration: group.narration,
        isBillwiseOn: group.isBillwiseOn,
        isAddable: group.isAddable,
        isDeleted: group.isDeleted,
        isSubledger: group.isSubledger,
        isRevenue: group.isRevenue,
        affectsGrossProfit: group.affectsGrossProfit,
        isDeemedPositive: group.isDeemedPositive,
        trackNegativeBalances: group.trackNegativeBalances,
        isCondensed: group.isCondensed,
        addlAllocType: group.addlAllocType,
        gstApplicable: group.gstApplicable,
        tdsApplicable: group.tdsApplicable,
        tcsApplicable: group.tcsApplicable,
        sortPosition: group.sortPosition,
        languageNames: group.languageNames,
      );

      processedGroups.add(updatedGroup);

      // Add to map for subsequent lookups
      nameToGroupMap[updatedGroup.name] = updatedGroup;
    }

    // Batch insert
    final batch = db.batch();
    for (var group in processedGroups) {
      batch.insert(
        'groups',
        group.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    print('✅ Saved ${processedGroups.length} groups locally');

    // NEW: Auto-sync to AWS
    if (syncToAws) {
      try {
        final groupMaps = processedGroups.map((g) => g.toMap()).toList();
        await AwsSyncService.instance.syncGroups(groupMaps, companyGuid);
        print('☁️ Synced ${processedGroups.length} groups to AWS');
      } catch (e) {
        print('⚠️ AWS sync failed for groups: $e');
      }
    }
  }

  Future<List<Group>> getGroupsByCompany(String companyGuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: 'company_guid = ?',
      whereArgs: [companyGuid],
    );

    return maps.map((map) => Group.fromMap(map)).toList();
  }

  // ============================================
  // LEDGERS
  // ============================================

  Future<void> saveLedger(Ledger ledger, String companyGuid) async {
    final db = await database;

    await db.transaction((txn) async {
      // Lookup parent GUID
      String? parentGuid;
      if (ledger.parent != null && ledger.parent!.isNotEmpty) {
        final cleanedParent = _cleanValue(ledger.parent);
        if (cleanedParent != null && cleanedParent.isNotEmpty) {
          parentGuid =
              await _getGroupGuidByName(cleanedParent, companyGuid, txn);
        }
      }

      final latestClosingBalance = ledger.closingBalances.isEmpty
          ? 0
          : (ledger.closingBalances..sort((a, b) => b.date.compareTo(a.date)))
              .first
              .amount;

      // Prepare main ledger data
      final ledgerData = {
        'company_guid': companyGuid,
        'ledger_guid': ledger.guid,
        'name': ledger.name,
        'alter_id': ledger.alterid,
        'parent': _cleanValue(ledger.parent),
        'parent_guid': parentGuid,
        'narration': ledger.narration,
        'description': ledger.description,
        'currency_name': ledger.currencyName,
        'email': ledger.email,
        'website': ledger.website,
        'income_tax_number': ledger.incomeTaxNumber,
        'party_gstin': ledger.partyGstin,
        'prior_state_name': ledger.priorStateName,
        'country_of_residence': ledger.countryOfResidence,
        'opening_balance': ledger.openingBalance,
        'closing_balance': latestClosingBalance,
        'credit_limit': ledger.creditLimit,
        'is_billwise_on': ledger.isBillwiseOn ? 1 : 0,
        'is_cost_centres_on': ledger.isCostCentresOn ? 1 : 0,
        'is_interest_on': ledger.isInterestOn ? 1 : 0,
        'is_deleted': ledger.isDeleted ? 1 : 0,
        'is_cost_tracking_on': ledger.isCostTrackingOn ? 1 : 0,
        'is_credit_days_chk_on': ledger.isCreditDaysChkOn ? 1 : 0,
        'affects_stock': ledger.affectsStock ? 1 : 0,
        'is_gst_applicable': ledger.isGstApplicable ? 1 : 0,
        'is_tds_applicable': ledger.isTdsApplicable ? 1 : 0,
        'is_tcs_applicable': ledger.isTcsApplicable ? 1 : 0,
        'tax_classification_name': _cleanValue(ledger.taxClassificationName),
        'tax_type': ledger.taxType,
        'gst_type': _cleanValue(ledger.gstType),
        'gst_nature_of_supply': _cleanValue(ledger.gstNatureOfSupply),
        'bill_credit_period': ledger.billCreditPeriod,
        'ifsc_code': ledger.ifscCode,
        'swift_code': ledger.swiftCode,
        'bank_account_holder_name': ledger.bankAccountHolderName,
        'ledger_phone': ledger.ledgerPhone,
        'ledger_mobile': ledger.ledgerMobile,
        'ledger_contact': ledger.ledgerContact,
        'ledger_country_isd_code': ledger.ledgerCountryIsdCode,
        'sort_position': ledger.sortPosition,
        'mailing_name': ledger.mailingName,
        'mailing_state': ledger.mailingState,
        'mailing_pincode': ledger.mailingPincode,
        'mailing_country': ledger.mailingCountry,
        'mailing_address': jsonEncode(ledger.mailingAddress),
        'gst_registration_type': ledger.gstRegistrationType,
        'gst_applicable_from': ledger.gstApplicableFrom,
        'gst_place_of_supply': ledger.gstPlaceOfSupply,
        'gstin': ledger.gstin,
        'language_names': jsonEncode(ledger.languageNames),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert main ledger
      await txn.rawInsert('''
        INSERT INTO ledgers (${ledgerData.keys.join(', ')})
        VALUES (${List.filled(ledgerData.length, '?').join(', ')})
        ON CONFLICT(ledger_guid) DO UPDATE SET
        ${ledgerData.keys.where((k) => k != 'ledger_guid').map((k) => '$k = excluded.$k').join(', ')}
      ''', ledgerData.values.toList());

      // Get ledger_id
      final result = await txn.query(
        'ledgers',
        columns: ['ledger_guid'],
        where: 'ledger_guid = ?',
        whereArgs: [ledger.guid],
      );

      if (result.isEmpty) {
        throw Exception('Failed to save ledger: ${ledger.name}');
      }

      final ledgerId = result.first['ledger_guid'] as String;

      // Delete old nested data
      await txn.delete('ledger_contacts',
          where: 'ledger_guid = ?', whereArgs: [ledgerId]);
      await txn.delete('ledger_mailing_details',
          where: 'ledger_guid = ?', whereArgs: [ledgerId]);
      await txn.delete('ledger_gst_registrations',
          where: 'ledger_guid = ?', whereArgs: [ledgerId]);
      await txn.delete('ledger_closing_balances',
          where: 'ledger_guid = ?', whereArgs: [ledgerId]);

      for (final closingData in ledger.closingBalances) {
        await txn.insert('ledger_closing_balances', {
          'ledger_guid': ledgerId,
          'company_guid': companyGuid,
          'closing_date': closingData.date,
          'amount': closingData.amount,
        });
      }

      // Insert contacts
      for (final contact in ledger.contacts) {
        await txn.insert('ledger_contacts', {
          'ledger_guid': ledgerId,
          'company_guid': companyGuid,
          'name': contact.name,
          'phone_number': contact.phoneNumber,
          'country_isd_code': contact.countryIsdCode,
          'is_default_whatsapp_num': contact.isDefaultWhatsappNum ? 1 : 0,
        });
      }

      // Insert mailing details
      for (final mailing in ledger.mailingDetails) {
        await txn.insert('ledger_mailing_details', {
          'ledger_guid': ledgerId,
          'company_guid': companyGuid,
          'applicable_from': mailing.applicableFrom,
          'mailing_name': mailing.mailingName,
          'state': mailing.state,
          'country': mailing.country,
          'pincode': mailing.pincode,
          'address': jsonEncode(mailing.address),
        });
      }

      // Insert GST registrations
      for (final gst in ledger.gstRegistrations) {
        await txn.insert('ledger_gst_registrations', {
          'ledger_guid': ledgerId,
          'company_guid': companyGuid,
          'applicable_from': gst.applicableFrom,
          'gst_registration_type': gst.gstRegistrationType,
          'place_of_supply': gst.placeOfSupply,
          'gstin': gst.gstin,
          'transporter_id': gst.transporterId,
          'is_oth_territory_assessee': gst.isOthTerritoryAssessee ? 1 : 0,
          'consider_purchase_for_export': gst.considerPurchaseForExport ? 1 : 0,
          'is_transporter': gst.isTransporter ? 1 : 0,
        });
      }

      print(
          '✅ Saved: ${ledger.name} | Contacts: ${ledger.contacts.length} | Mailing: ${ledger.mailingDetails.length} | GST Regs: ${ledger.gstRegistrations.length}');
    });
  }

  /// Get Group GUID by name
  Future<String?> _getGroupGuidByName(
      String groupName, String companyGuid, Transaction txn) async {
    try {
      final results = await txn.query(
        'groups',
        columns: ['group_guid'],
        where: 'name = ? AND company_guid = ?',
        whereArgs: [groupName, companyGuid],
      );

      if (results.isNotEmpty) {
        return results.first['group_guid'] as String;
      }
    } catch (e) {
      print('Error getting group GUID: $e');
    }
    return null;
  }

  // UPDATED WITH AWS SYNC
  Future<void> saveLedgerBatch(List<Ledger> ledgers, String companyGuid,
      {bool syncToAws = false}) async {
    print('💾 Saving ${ledgers.length} ledgers locally...');

    int successCount = 0;
    final savedLedgerMaps = <Map<String, dynamic>>[];

    for (final ledger in ledgers) {
      try {
        await saveLedger(ledger, companyGuid);
        successCount++;

        // NEW: Collect for AWS sync
        if (syncToAws) {
          savedLedgerMaps.add(await _convertLedgerToMap(ledger, companyGuid));
        }
      } catch (e) {
        print('❌ Error saving ${ledger.name}: $e');
      }
    }

    print('✅ Saved: $successCount/${ledgers.length} ledgers locally');

    // NEW: Auto-sync to AWS
    if (syncToAws && savedLedgerMaps.isNotEmpty) {
      try {
        await AwsSyncService.instance.syncLedgers(savedLedgerMaps, companyGuid);
        print('☁️ Synced $successCount ledgers to AWS');
      } catch (e) {
        print('⚠️ AWS sync failed for ledgers: $e');
      }
    }
  }

  // NEW: Convert Ledger to Map for AWS sync
  Future<Map<String, dynamic>> _convertLedgerToMap(
      Ledger ledger, String companyGuid) async {
    // Lookup parent GUID (same logic as saveLedger)
    String? parentGuid;
    if (ledger.parent != null && ledger.parent!.isNotEmpty) {
      final cleanedParent = _cleanValue(ledger.parent);
      if (cleanedParent != null && cleanedParent.isNotEmpty) {
        parentGuid =
            await _getGroupGuidByNameForSync(cleanedParent, companyGuid);
      }
    }
    final latestClosingBalance = ledger.closingBalances.isEmpty
        ? 0
        : (ledger.closingBalances..sort((a, b) => b.date.compareTo(a.date)))
            .first
            .amount;
    // Return the EXACT same structure as ledgerData in saveLedger
    return {
      'company_guid': companyGuid,
      'ledger_guid': ledger.guid,
      'name': ledger.name,
      'alter_id': ledger.alterid,
      'parent': _cleanValue(ledger.parent),
      'parent_guid': parentGuid, // RESOLVED from groups table
      'narration': ledger.narration,
      'description': ledger.description,
      'currency_name': ledger.currencyName,
      'email': ledger.email,
      'website': ledger.website,
      'income_tax_number': ledger.incomeTaxNumber,
      'party_gstin': ledger.partyGstin,
      'prior_state_name': ledger.priorStateName,
      'country_of_residence': ledger.countryOfResidence,
      'opening_balance': ledger.openingBalance,
      'closing_balance': latestClosingBalance,
      'credit_limit': ledger.creditLimit,
      'is_billwise_on': ledger.isBillwiseOn ? 1 : 0,
      'is_cost_centres_on': ledger.isCostCentresOn ? 1 : 0,
      'is_interest_on': ledger.isInterestOn ? 1 : 0,
      'is_deleted': ledger.isDeleted ? 1 : 0,
      'is_cost_tracking_on': ledger.isCostTrackingOn ? 1 : 0,
      'is_credit_days_chk_on': ledger.isCreditDaysChkOn ? 1 : 0,
      'affects_stock': ledger.affectsStock ? 1 : 0,
      'is_gst_applicable': ledger.isGstApplicable ? 1 : 0,
      'is_tds_applicable': ledger.isTdsApplicable ? 1 : 0,
      'is_tcs_applicable': ledger.isTcsApplicable ? 1 : 0,
      'tax_classification_name': _cleanValue(ledger.taxClassificationName),
      'tax_type': ledger.taxType,
      'gst_type': _cleanValue(ledger.gstType),
      'gst_nature_of_supply': _cleanValue(ledger.gstNatureOfSupply),
      'bill_credit_period': ledger.billCreditPeriod,
      'ifsc_code': ledger.ifscCode,
      'swift_code': ledger.swiftCode,
      'bank_account_holder_name': ledger.bankAccountHolderName,
      'ledger_phone': ledger.ledgerPhone,
      'ledger_mobile': ledger.ledgerMobile,
      'ledger_contact': ledger.ledgerContact,
      'ledger_country_isd_code': ledger.ledgerCountryIsdCode,
      'sort_position': ledger.sortPosition,
      'mailing_name': ledger.mailingName,
      'mailing_state': ledger.mailingState,
      'mailing_pincode': ledger.mailingPincode,
      'mailing_country': ledger.mailingCountry,
      'mailing_address': jsonEncode(ledger.mailingAddress),
      'gst_registration_type': ledger.gstRegistrationType,
      'gst_applicable_from': ledger.gstApplicableFrom,
      'gst_place_of_supply': ledger.gstPlaceOfSupply,
      'gstin': ledger.gstin,
      'language_names': jsonEncode(ledger.languageNames),
      'updated_at': DateTime.now().toIso8601String(),
      // NOTE: created_at is handled by database DEFAULT
    };
  }

  Future<String?> _getGroupGuidByNameForSync(
      String groupName, String companyGuid) async {
    final db = await database;

    try {
      final results = await db.query(
        'groups',
        columns: ['group_guid'],
        where: 'name = ? AND company_guid = ?',
        whereArgs: [groupName, companyGuid],
      );

      if (results.isNotEmpty) {
        return results.first['group_guid'] as String;
      }
    } catch (e) {
      print('Error getting group GUID: $e');
    }
    return null;
  }

  // ============================================
// VOUCHER TYPES
// ============================================

Future<String?> resolveVoucherTypeParentGuid(
  String? parentName,
  String companyGuid,
  List<VoucherType>? inMemoryVoucherTypes,
) async {
  final db = await database;

  if (parentName == null || parentName.isEmpty) return null;

  // First, check in-memory voucher types array
  if (inMemoryVoucherTypes != null) {
    try {
      final parent = inMemoryVoucherTypes.firstWhere(
        (vt) => vt.name == parentName && vt.companyGuid == companyGuid,
      );
      return parent.guid;
    } catch (e) {
      // Not found in memory, will check DB
    }
  }

  // If not in memory, check database
  final List<Map<String, dynamic>> maps = await db.query(
    'voucher_types',
    columns: ['guid'],
    where: 'company_guid = ? AND name = ?',
    whereArgs: [companyGuid, parentName],
    limit: 1,
  );

  if (maps.isEmpty) return null;
  return maps.first['guid'] as String?;
}

// Process and insert new voucher types (handles parent resolution)
Future<void> processNewVoucherTypes(
  List<VoucherType> newVoucherTypes,
  String companyGuid,
  {bool syncToAws = false}
) async {
  final db = await database;

  // Get existing voucher types from DB
  final existingVoucherTypes = await getVoucherTypesByCompany(companyGuid);
  
  // Merge newVoucherTypes into existingVoucherTypes (priority to new)
  Map<String, VoucherType> allVoucherTypesMap = {
    for (var vt in existingVoucherTypes) vt.guid: vt,  // Existing first
    for (var vt in newVoucherTypes) vt.guid: vt,  // New voucher types override
  };

  // Build name lookup map from merged voucher types
  Map<String, VoucherType> nameToVoucherTypeMap = {
    for (var vt in allVoucherTypesMap.values) vt.name: vt
  };

  List<VoucherType> processedVoucherTypes = [];

  // Process new voucher types
  for (var voucherType in newVoucherTypes) {
    // First check in already processed voucher types
    String? parentGuid = nameToVoucherTypeMap[voucherType.parent]?.guid;

    // Create new voucher type with resolved parentGuid
    final updatedVoucherType = VoucherType(
      name: voucherType.name,
      companyGuid: companyGuid,
      guid: voucherType.guid,
      parent: voucherType.parent,
      reservedName: voucherType.reservedName,
      parentGuid: parentGuid,  // Resolved GUID
      alterId: voucherType.alterId,
      masterId: voucherType.masterId,
      isDeemedPositive: voucherType.isDeemedPositive,
      affectsStock: voucherType.affectsStock,
      isOptional: voucherType.isOptional,
      isActive: voucherType.isActive,
      isDeleted: voucherType.isDeleted,
      numberingMethod: voucherType.numberingMethod,
      preventDuplicates: voucherType.preventDuplicates,
      currentPrefix: voucherType.currentPrefix,
      currentSuffix: voucherType.currentSuffix,
      restartPeriod: voucherType.restartPeriod,
      isTaxInvoice: voucherType.isTaxInvoice,
      printAfterSave: voucherType.printAfterSave,
    );

    processedVoucherTypes.add(updatedVoucherType);
    
    // Add to map for subsequent lookups
    nameToVoucherTypeMap[updatedVoucherType.name] = updatedVoucherType;
  }

  // Batch insert
  final batch = db.batch();
  for (var voucherType in processedVoucherTypes) {
    batch.insert(
      'voucher_types',
      voucherType.toMap(companyGuid),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  await batch.commit(noResult: true);

  print('✅ Saved ${processedVoucherTypes.length} voucher types locally');

  // Auto-sync to Neon
  if (syncToAws) {
    try {
      final voucherTypeMaps = processedVoucherTypes.map((vt) => vt.toMap(companyGuid)).toList();
      await AwsSyncService.instance.syncVoucherTypes(voucherTypeMaps, companyGuid);
      print('☁️ Synced ${processedVoucherTypes.length} voucher types to AWS');
    } catch (e) {
      print('⚠️ AWS sync failed for voucher types: $e');
    }
  }
}

Future<List<VoucherType>> getVoucherTypesByCompany(String companyGuid) async {
  final db = await database;
  List<VoucherType> voucherTypes = [];
  final List<Map<String, dynamic>> maps = await db.query(
    'voucher_types',
    where: 'company_guid = ?',
    whereArgs: [companyGuid],
  );

  for (final map in maps){
    print(map);
    voucherTypes.add(VoucherType.fromMap(map));
  }

  return maps.map((map) => VoucherType.fromMap(map)).toList();
}

// Get specific voucher type by name
Future<VoucherType?> getVoucherTypeByName(
    String companyGuid, String name, {Transaction? txn}) async {
  final DatabaseExecutor executor = txn ?? await database;
  final List<Map<String, dynamic>> maps = await executor.query(
    'voucher_types',
    where: 'company_guid = ? AND name = ? AND is_deleted = 0',
    whereArgs: [companyGuid, name],
    limit: 1,
  );

  if (maps.isEmpty) return null;
  return VoucherType.fromMap(maps.first);
}

// Get voucher types that affect stock (for inventory vouchers)
Future<List<VoucherType>> getStockAffectingVoucherTypes(String companyGuid) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'voucher_types',
    where: 'company_guid = ? AND affects_stock = 1 AND is_deleted = 0',
    whereArgs: [companyGuid],
    orderBy: 'name ASC',
  );

  return maps.map((map) => VoucherType.fromMap(map)).toList();
}

// Get max alter_id for incremental sync
Future<int> getMaxVoucherTypeAlterId(String companyGuid) async {
  final db = await database;
  final result = await db.rawQuery(
    'SELECT MAX(alter_id) as max_alter_id FROM voucher_types WHERE company_guid = ?',
    [companyGuid],
  );
  return (result.first['max_alter_id'] as int?) ?? 0;
}

// Update last synced alter_id in companies table
Future<void> updateLastSyncedVoucherTypesAlterId(String companyGuid, int alterId) async {
  final db = await database;
  await db.update(
    'companies',
    {'last_synced_voucher_types_alter_id': alterId},
    where: 'company_guid = ?',
    whereArgs: [companyGuid],
  );
}

  Future<void> saveVoucher(Voucher voucher, String companyGuid) async {
    final db = await database;

    await db.transaction((txn) async {
      // Build lookup maps
      final ledgerMap = await _buildLedgerLookupMap(companyGuid, txn);
      final stockItemMap = await _buildStockItemLookupMap(companyGuid, txn);

      // Get party ledger GUID
      String? partyLedgerGuid;
      if (voucher.partyLedgerName != null &&
          voucher.partyLedgerName!.isNotEmpty) {
        partyLedgerGuid = ledgerMap[voucher.partyLedgerName];
      }

      String? voucherTypeParentGuid;
      final vType = await getVoucherTypeByName(companyGuid, voucher.voucherType, txn: txn);
      if (vType != null && vType.guid.isNotEmpty) {
          // parentGuid = await _getGroupGuidByName(cleanedParent, companyGuid, txn);
          voucherTypeParentGuid = vType.guid;
      }

      // Save main voucher
      final voucherData = {
        'company_guid': companyGuid,
        'voucher_guid': voucher.guid,
        'master_id': voucher.masterId,
        'alter_id': voucher.alterId,
        'voucher_key': voucher.voucherKey,
        'voucher_retain_key': voucher.voucherRetainKey,
        'date': voucher.date,
        'effective_date': voucher.effectiveDate,
        'voucher_type': voucher.voucherType,
        'voucher_type_guid': voucherTypeParentGuid,
        'voucher_number': voucher.voucherNumber,
        'voucher_number_series': voucher.voucherNumberSeries,
        'persisted_view': voucher.persistedView,
        'party_ledger_name': voucher.partyLedgerName,
        'party_ledger_guid': partyLedgerGuid,
        'party_gstin': voucher.partyGstin,
        'amount': voucher.amount,
        'total_amount': voucher.totalAmount,
        'discount': voucher.discount,
        'gst_registration_type': voucher.gstRegistrationType,
        'place_of_supply': voucher.placeOfSupply,
        'state_name': voucher.stateName,
        'country_of_residence': voucher.countryOfResidence,
        'narration': voucher.narration,
        'reference': voucher.reference,
        'is_deleted': voucher.isDeleted ? 1 : 0,
        'is_cancelled': voucher.isCancelled ? 1 : 0,
        'is_invoice': voucher.isInvoice ? 1 : 0,
        'is_optional': voucher.isOptional == true ? 1 : 0,
        'has_discounts': voucher.hasDiscounts == true ? 1 : 0,
        'is_deemed_positive': voucher.isDeemedPositive == true ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await txn.rawInsert('''
      INSERT INTO vouchers (${voucherData.keys.join(', ')})
      VALUES (${List.filled(voucherData.length, '?').join(', ')})
      ON CONFLICT(voucher_guid) DO UPDATE SET
      ${voucherData.keys.where((k) => k != 'voucher_guid').map((k) => '$k = excluded.$k').join(', ')}
    ''', voucherData.values.toList());

      // Get voucher_id
      final voucherResult = await txn.query('vouchers',
          where: 'voucher_guid = ?', whereArgs: [voucher.guid]);
      if (voucherResult.isEmpty) {
        throw Exception('Failed to save voucher: ${voucher.voucherNumber}');
      }

      final voucherId = voucherResult.first['voucher_guid'] as String;

      // DEBUG: Count existing entries BEFORE delete
      // final oldBatchCount = Sqflite.firstIntValue(
      //   await txn.rawQuery(
      //     'SELECT COUNT(*) FROM voucher_batch_allocations WHERE voucher_guid = ?',
      //     [voucherId]
      //   )
      // );
      // print('🔍 DEBUG: Voucher ${voucher.voucherNumber} (${voucherId})');
      // print('   Old batch allocations count: $oldBatchCount');

      // Delete old entries
      final deletedLedgers = await txn.delete('voucher_ledger_entries',
          where: 'voucher_guid = ?', whereArgs: [voucherId]);
      final deletedInventory = await txn.delete('voucher_inventory_entries',
          where: 'voucher_guid = ?', whereArgs: [voucherId]);
      final deletedBatches = await txn.delete('voucher_batch_allocations',
          where: 'voucher_guid = ?', whereArgs: [voucherId]);

      // print('   Deleted: $deletedLedgers ledgers, $deletedInventory inventory, $deletedBatches batches');

      // DEBUG: Count after delete (should be 0)
      // final afterDeleteCount = Sqflite.firstIntValue(
      //   await txn.rawQuery(
      //     'SELECT COUNT(*) FROM voucher_batch_allocations WHERE voucher_guid = ?',
      //     [voucherId]
      //   )
      // );
      // print('   After delete count: $afterDeleteCount (should be 0)');

      // Insert ledger entries
      for (final ledger in voucher.ledgerEntries) {
        await txn.insert('voucher_ledger_entries', {
          'voucher_guid': voucherId,
          'company_guid': companyGuid,
          'ledger_name': ledger.ledgerName,
          'ledger_guid': ledgerMap[ledger.ledgerName],
          'amount': ledger.amount,
          'is_party_ledger': ledger.isPartyLedger ? 1 : 0,
          'is_deemed_positive': ledger.isDeemedPositive == true ? 1 : 0,
          'bill_name': ledger.billName,
          'bill_amount': ledger.billAmount,
          'bill_date': ledger.billDate,
          'bill_type': ledger.billType,
          'instrument_number': ledger.instrumentNumber,
          'instrument_date': ledger.instrumentDate,
          'transaction_type': ledger.transactionType,
          'cost_center_name': ledger.costCenterName,
          'cost_center_amount': ledger.costCenterAmount,
        });
      }

      // Insert inventory entries
      int batchInsertCount = 0;
      for (final inventory in voucher.inventoryEntries) {
        await txn.insert('voucher_inventory_entries', {
          'voucher_guid': voucherId,
          'company_guid': companyGuid,
          'stock_item_name': inventory.stockItemName,
          'stock_item_guid': stockItemMap[inventory.stockItemName],
          'rate': inventory.rate,
          'amount': inventory.amount,
          'actual_qty': inventory.actualQty,
          'billed_qty': inventory.billedQty,
          'discount': inventory.discount,
          'discount_percent': inventory.discountPercent,
          'gst_rate': inventory.gstRate,
          'cgst_amount': inventory.cgstAmount,
          'sgst_amount': inventory.sgstAmount,
          'igst_amount': inventory.igstAmount,
          'cess_amount': inventory.cessAmount,
          'hsn_code': inventory.hsnCode,
          'hsn_description': inventory.hsnDescription,
          'unit': inventory.unit,
          'alternate_unit': inventory.alternateUnit,
          'tracking_number': inventory.trackingNumber,
          'order_number': inventory.orderNumber,
          'indent_number': inventory.indentNumber,
          'is_deemed_positive': inventory.isDeemedPositive == true ? 1 : 0
        });

        // Insert batch allocations
        for (final batch in inventory.batchAllocations) {
          await txn.insert('voucher_batch_allocations', {
            'voucher_guid': voucherId,
            'company_guid': companyGuid,
            'godown_name': batch.godownName,
            'stock_item_name': inventory.stockItemName,
            'stock_item_guid': stockItemMap[inventory.stockItemName],
            'batch_name': batch.batchName,
            'amount': batch.amount,
            'actual_qty': batch.actualQty,
            'billed_qty': batch.billedQty,
            'tracking_number': batch.trackingNumber,
            'batch_id': batch.batchId,
            'mfg_date': batch.mfgDate,
            'expiry_date': batch.expiryDate,
            'batch_rate': batch.batchRate,
            'destination_godown_name': batch.destinationGodownName,
            'is_deemed_positive': batch.isDeemedPositive == true ? 1 : 0
          });
          batchInsertCount++;
        }
      }

      // print('   Inserted: ${voucher.ledgerEntries.length} ledgers, ${voucher.inventoryEntries.length} inventory, $batchInsertCount batches');

      // DEBUG: Final count
      // final finalBatchCount = Sqflite.firstIntValue(
      //   await txn.rawQuery(
      //     'SELECT COUNT(*) FROM voucher_batch_allocations WHERE voucher_guid = ?',
      //     [voucherId]
      //   )
      // );
      // print('   Final batch count: $finalBatchCount (expected: $batchInsertCount)');

      // if (finalBatchCount != batchInsertCount) {
      //   print('   ⚠️ WARNING: Final count does not match inserted count!');
      // }
    });
  }

  /// Build ledger lookup map
  Future<Map<String, String>> _buildLedgerLookupMap(
      String companyGuid, Transaction txn) async {
    final ledgers = await txn.query(
      'ledgers',
      columns: ['name', 'ledger_guid'],
      where: 'company_guid = ?',
      whereArgs: [companyGuid],
    );

    return Map.fromEntries(ledgers
        .map((l) => MapEntry(l['name'] as String, l['ledger_guid'] as String)));
  }

  /// Build stock item lookup map
  Future<Map<String, String>> _buildStockItemLookupMap(
      String companyGuid, Transaction txn) async {
    final items = await txn.query(
      'stock_items',
      columns: ['name', 'stock_item_guid'],
      where: 'company_guid = ?',
      whereArgs: [companyGuid],
    );

    return Map.fromEntries(items.map(
        (i) => MapEntry(i['name'] as String, i['stock_item_guid'] as String)));
  }

  /// Save multiple vouchers - UPDATED WITH AWS SYNC
  Future<void> saveVoucherBatch(List<Voucher> vouchers, String companyGuid,
      {bool syncToAws = false}) async {
    print('💾 Saving ${vouchers.length} vouchers locally...');

    int successCount = 0;
    final savedVoucherMaps = <Map<String, dynamic>>[];

    for (final voucher in vouchers) {
      try {
        await saveVoucher(voucher, companyGuid);
        successCount++;

        // NEW: Collect for AWS sync
        if (syncToAws) {
          savedVoucherMaps
              .add(await _convertVoucherToMap(voucher, companyGuid));
        }
      } catch (e) {
        print('❌ Error saving ${voucher.voucherNumber}: $e');
      }
    }

    print('✅ Saved: $successCount/${vouchers.length} vouchers locally');

    // NEW: Auto-sync to AWS
    if (syncToAws && savedVoucherMaps.isNotEmpty) {
    try {
      // Separate the data
      final voucherMaps = savedVoucherMaps.map((d) => d['voucher'] as Map<String, dynamic>).toList();
      final allLedgerEntries = <Map<String, dynamic>>[];
      final allInventoryEntries = <Map<String, dynamic>>[];
      final allBatchAllocations = <Map<String, dynamic>>[];

      for (final data in savedVoucherMaps) {
        allLedgerEntries.addAll(data['ledger_entries'] as List<Map<String, dynamic>>);
        allInventoryEntries.addAll(data['inventory_entries'] as List<Map<String, dynamic>>);
        allBatchAllocations.addAll(data['batch_allocations'] as List<Map<String, dynamic>>);
      }

      // Sync main vouchers
      await AwsSyncService.instance.syncVouchers(voucherMaps, companyGuid);
      print('☁️ Synced $successCount vouchers to AWS');

      // Sync ledger entries
      if (allLedgerEntries.isNotEmpty) {
        await AwsSyncService.instance.syncVoucherLedgerEntries(allLedgerEntries, companyGuid);
        print('☁️ Synced ${allLedgerEntries.length} ledger entries to AWS');
      }

      // Sync inventory entries
      if (allInventoryEntries.isNotEmpty) {
        await AwsSyncService.instance.syncVoucherInventoryEntries(allInventoryEntries, companyGuid);
        print('☁️ Synced ${allInventoryEntries.length} inventory entries to AWS');
      }

      // Sync batch allocations
      if (allBatchAllocations.isNotEmpty) {
        await AwsSyncService.instance.syncVoucherBatchAllocations(allBatchAllocations, companyGuid);
        print('☁️ Synced ${allBatchAllocations.length} batch allocations to AWS');
      }

    } catch (e) {
      print('⚠️ AWS sync failed for vouchers: $e');
    }
    }
  }

  // ============================================
// VOUCHER CONVERSION
// ============================================
  // Future<Map<String, dynamic>> _convertVoucherToMap(
  //     Voucher voucher, String companyGuid) async {
  //   final db = await database;

  //   // Build lookup map (same as saveVoucher)
  //   final ledgerMap = await _buildLedgerLookupMapForSync(companyGuid);

  //   // Get party ledger GUID (same logic as saveVoucher)
  //   String? partyLedgerGuid;
  //   if (voucher.partyLedgerName != null &&
  //       voucher.partyLedgerName!.isNotEmpty) {
  //     partyLedgerGuid = ledgerMap[voucher.partyLedgerName];
  //   }

  //   // Return the EXACT same structure as voucherData in saveVoucher
  //   return {
  //     'company_guid': companyGuid,
  //     'voucher_guid': voucher.guid,
  //     'master_id': voucher.masterId,
  //     'alter_id': voucher.alterId,
  //     'voucher_key': voucher.voucherKey,
  //     'voucher_retain_key': voucher.voucherRetainKey,
  //     'date': voucher.date,
  //     'effective_date': voucher.effectiveDate,
  //     'voucher_type': voucher.voucherType,
  //     'voucher_number': voucher.voucherNumber,
  //     'voucher_number_series': voucher.voucherNumberSeries,
  //     'persisted_view': voucher.persistedView,
  //     'party_ledger_name': voucher.partyLedgerName,
  //     'party_ledger_guid': partyLedgerGuid, // RESOLVED from ledgerMap
  //     'party_gstin': voucher.partyGstin,
  //     'amount': voucher.amount,
  //     'total_amount': voucher.totalAmount,
  //     'discount': voucher.discount,
  //     'gst_registration_type': voucher.gstRegistrationType,
  //     'place_of_supply': voucher.placeOfSupply,
  //     'state_name': voucher.stateName,
  //     'country_of_residence': voucher.countryOfResidence,
  //     'narration': voucher.narration,
  //     'reference': voucher.reference,
  //     'is_deleted': voucher.isDeleted ? 1 : 0,
  //     'is_cancelled': voucher.isCancelled ? 1 : 0,
  //     'is_invoice': voucher.isInvoice ? 1 : 0,
  //     'is_optional': voucher.isOptional == true ? 1 : 0,
  //     'has_discounts': voucher.hasDiscounts == true ? 1 : 0,
  //     'is_deemed_positive': voucher.isDeemedPositive == true ? 1 : 0,
  //     'updated_at': DateTime.now().toIso8601String(),
  //     // NOTE: created_at is handled by database DEFAULT
  //   };
  // }

  // ============================================================
// VOUCHER CONVERSION - NOW INCLUDES NESTED DATA
// ============================================================
Future<Map<String, dynamic>> _convertVoucherToMap(
    Voucher voucher, String companyGuid) async {
  final db = await database;

  // Build lookup maps
  final ledgerMap = await _buildLedgerLookupMapForSync(companyGuid);
  final stockItemMap = await _buildStockItemLookupMapForSync(companyGuid);

  // Get party ledger GUID
  String? partyLedgerGuid;
  if (voucher.partyLedgerName != null &&
      voucher.partyLedgerName!.isNotEmpty) {
    partyLedgerGuid = ledgerMap[voucher.partyLedgerName];
  }

  // Main voucher data
  final voucherData = {
    'company_guid': companyGuid,
    'voucher_guid': voucher.guid,
    'master_id': voucher.masterId,
    'alter_id': voucher.alterId,
    'voucher_key': voucher.voucherKey,
    'voucher_retain_key': voucher.voucherRetainKey,
    'date': voucher.date,
    'effective_date': voucher.effectiveDate,
    'voucher_type': voucher.voucherType,
    'voucher_number': voucher.voucherNumber,
    'voucher_number_series': voucher.voucherNumberSeries,
    'persisted_view': voucher.persistedView,
    'party_ledger_name': voucher.partyLedgerName,
    'party_ledger_guid': partyLedgerGuid,
    'party_gstin': voucher.partyGstin,
    'amount': voucher.amount,
    'total_amount': voucher.totalAmount,
    'discount': voucher.discount,
    'gst_registration_type': voucher.gstRegistrationType,
    'place_of_supply': voucher.placeOfSupply,
    'state_name': voucher.stateName,
    'country_of_residence': voucher.countryOfResidence,
    'narration': voucher.narration,
    'reference': voucher.reference,
    'is_deleted': voucher.isDeleted ? 1 : 0,
    'is_cancelled': voucher.isCancelled ? 1 : 0,
    'is_invoice': voucher.isInvoice ? 1 : 0,
    'is_optional': voucher.isOptional == true ? 1 : 0,
    'has_discounts': voucher.hasDiscounts == true ? 1 : 0,
    'is_deemed_positive': voucher.isDeemedPositive == true ? 1 : 0,
    'updated_at': DateTime.now().toIso8601String(),
  };

  // Ledger entries
  final ledgerEntries = <Map<String, dynamic>>[];
  for (final ledger in voucher.ledgerEntries) {
    ledgerEntries.add({
      'voucher_guid': voucher.guid,
      'ledger_name': ledger.ledgerName,
      'ledger_guid': ledgerMap[ledger.ledgerName],
      'amount': ledger.amount,
      'is_party_ledger': ledger.isPartyLedger ? 1 : 0,
      'is_deemed_positive': ledger.isDeemedPositive == true ? 1 : 0,
      'bill_name': ledger.billName,
      'bill_amount': ledger.billAmount,
      'bill_date': ledger.billDate,
      'bill_type': ledger.billType,
      'instrument_number': ledger.instrumentNumber,
      'instrument_date': ledger.instrumentDate,
      'transaction_type': ledger.transactionType,
      'cost_center_name': ledger.costCenterName,
      'cost_center_amount': ledger.costCenterAmount,
    });
  }

  // Inventory entries and batch allocations
  final inventoryEntries = <Map<String, dynamic>>[];
  final batchAllocations = <Map<String, dynamic>>[];
  
  for (final inventory in voucher.inventoryEntries) {
    inventoryEntries.add({
      'voucher_guid': voucher.guid,
      'stock_item_name': inventory.stockItemName,
      'stock_item_guid': stockItemMap[inventory.stockItemName],
      'rate': inventory.rate,
      'amount': inventory.amount,
      'actual_qty': inventory.actualQty,
      'billed_qty': inventory.billedQty,
      'discount': inventory.discount,
      'discount_percent': inventory.discountPercent,
      'gst_rate': inventory.gstRate,
      'cgst_amount': inventory.cgstAmount,
      'sgst_amount': inventory.sgstAmount,
      'igst_amount': inventory.igstAmount,
      'cess_amount': inventory.cessAmount,
      'hsn_code': inventory.hsnCode,
      'hsn_description': inventory.hsnDescription,
      'unit': inventory.unit,
      'alternate_unit': inventory.alternateUnit,
      'tracking_number': inventory.trackingNumber,
      'order_number': inventory.orderNumber,
      'indent_number': inventory.indentNumber,
      'is_deemed_positive': inventory.isDeemedPositive == true ? 1 : 0,
    });

    // Batch allocations for this inventory item
    for (final batch in inventory.batchAllocations) {
      batchAllocations.add({
        'voucher_guid': voucher.guid,
        'godown_name': batch.godownName,
        'stock_item_name': inventory.stockItemName,
        'stock_item_guid': stockItemMap[inventory.stockItemName],
        'batch_name': batch.batchName,
        'amount': batch.amount,
        'actual_qty': batch.actualQty,
        'billed_qty': batch.billedQty,
        'batch_id': batch.batchId,
        'mfg_date': batch.mfgDate,
        'expiry_date': batch.expiryDate,
        'batch_rate': batch.batchRate,
        'destination_godown_name': batch.destinationGodownName,
        'is_deemed_positive': batch.isDeemedPositive == true ? 1 : 0,
      });
    }
  }

  // Return everything wrapped
  return {
    'voucher': voucherData,
    'ledger_entries': ledgerEntries,
    'inventory_entries': inventoryEntries,
    'batch_allocations': batchAllocations,
  };
}

// Helper for ledger lookup (non-transaction version)
  Future<Map<String, String>> _buildLedgerLookupMapForSync(
      String companyGuid) async {
    final db = await database;

    final ledgers = await db.query(
      'ledgers',
      columns: ['name', 'ledger_guid'],
      where: 'company_guid = ?',
      whereArgs: [companyGuid],
    );

    return Map.fromEntries(ledgers
        .map((l) => MapEntry(l['name'] as String, l['ledger_guid'] as String)));
  }
  // ==================== HELPER METHODS ====================

  Future<Map<String, String>> _buildStockItemLookupMapForSync(
    String companyGuid) async {
  final db = await database;

  final items = await db.query(
    'stock_items',
    columns: ['name', 'stock_item_guid'],
    where: 'company_guid = ?',
    whereArgs: [companyGuid],
  );

  return Map.fromEntries(items.map(
      (i) => MapEntry(i['name'] as String, i['stock_item_guid'] as String)));
}

  Future<List<Map<String, dynamic>>> getAllVoucherGuids(
      String companyId) async {
    final db = await database;
    return await db.query(
      'vouchers',
      columns: ['voucher_guid', 'voucher_number'],
      where: 'company_guid = ?',
      whereArgs: [companyId],
    );
  }

  // Delete vouchers by GUIDs
  Future<void> deleteVouchersByGuids(List<String> guids) async {
    final db = await database;
    final batch = db.batch();

    for (var guid in guids) {
      batch.delete(
        'vouchers',
        where: 'voucher_guid = ?',
        whereArgs: [guid],
      );

      // Also delete related data
      batch.delete(
        'voucher_ledger_entries',
        where: 'voucher_guid = ?',
        whereArgs: [guid],
      );

      batch.delete(
        'voucher_inventory_entries',
        where: 'voucher_guid = ?',
        whereArgs: [guid],
      );

      batch.delete(
        'voucher_batch_allocations',
        where: 'voucher_guid = ?',
        whereArgs: [guid],
      );
    }

    await batch.commit(noResult: true);
    print('✅ Deleted ${guids.length} vouchers and related entries');
  }

  /// Get latest HSN detail
  Map<String, dynamic>? _getLatestHsn(List<HSNDetail> hsnDetails) {
    if (hsnDetails.isEmpty) return null;

    final latest = hsnDetails.reduce((a, b) {
      final dateA = _parseDate(a.applicableFrom);
      final dateB = _parseDate(b.applicableFrom);
      return (dateB?.isAfter(dateA ?? DateTime(1900)) ?? false) ? b : a;
    });

    return {
      'code': latest.hsnCode,
      'description': latest.hsnDescription,
      'from': latest.applicableFrom,
    };
  }

  /// Get latest GST detail
  Map<String, dynamic>? _getLatestGst(List<GSTDetail> gstDetails) {
    if (gstDetails.isEmpty) return null;

    final latest = gstDetails.reduce((a, b) {
      final dateA = _parseDate(a.applicableFrom);
      final dateB = _parseDate(b.applicableFrom);
      return (dateB?.isAfter(dateA ?? DateTime(1900)) ?? false) ? b : a;
    });

    return {
      'taxability': latest.taxability,
      'from': latest.applicableFrom,
      'detail': latest,
    };
  }

  /// Extract GST rates from latest GST detail
  Map<String, double?> _extractGstRates(Map<String, dynamic>? latestGst) {
    final rates = <String, double?>{
      'CGST': null,
      'SGST/UTGST': null,
      'IGST': null,
      'Cess': null,
    };

    if (latestGst == null) return rates;

    final gstDetail = latestGst['detail'] as GSTDetail;
    if (gstDetail.statewiseDetails.isEmpty) return rates;

    // Get rates for "Any" state (default for all states)
    final anyState = gstDetail.statewiseDetails.firstWhere(
      (s) => _cleanValue(s.stateName)?.toLowerCase() == 'any',
      orElse: () => gstDetail.statewiseDetails.first,
    );

    for (final rate in anyState.rateDetails) {
      rates[rate.dutyHead] = rate.rate;
    }

    return rates;
  }

  /// Get latest MRP detail
  Map<String, dynamic>? _getLatestMrp(List<MRPDetail> mrpDetails) {
    if (mrpDetails.isEmpty) return null;

    final latest = mrpDetails.reduce((a, b) {
      final dateA = _parseDate(a.fromDate);
      final dateB = _parseDate(b.fromDate);
      return (dateB?.isAfter(dateA ?? DateTime(1900)) ?? false) ? b : a;
    });

    if (latest.mrpRates.isEmpty) return null;

    // Get MRP for "Any" state (default for all states)
    final anyStateMrp = latest.mrpRates.firstWhere(
      (r) => _cleanValue(r.stateName)?.toLowerCase() == 'any',
      orElse: () => latest.mrpRates.first,
    );

    return {
      'rate': anyStateMrp.mrpRate,
      'from': latest.fromDate,
    };
  }

  /// Clean Tally values (remove special characters)
  String? _cleanValue(String? value) {
    if (value == null) return null;
    return value.replaceAll('\u0004', '').replaceAll('&#4;', '').trim();
  }

  /// Parse Tally date (YYYYMMDD) to DateTime
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.length != 8) return null;
    try {
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }
}
