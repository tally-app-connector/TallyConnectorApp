/// Schema Provider Service
/// Provides the full tally_clone.db schema for AI system prompts.

class SchemaProvider {
  static const String tallyDbSchema = '''
DATABASE: tally_clone.db (SQLite)

CRITICAL CONVENTIONS:
- All dates are stored as TEXT in YYYYMMDD format (e.g., '20250415'). Use string comparison for date ranges.
- Amount sign convention in voucher_ledger_entries: amount < 0 = DEBIT, amount > 0 = CREDIT.
- Every query MUST filter by company_guid.
- For vouchers, ALWAYS add: v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
- Join ledgers to groups via: ledgers.parent = groups.name (NOT via GUID).
- Join voucher_ledger_entries to ledgers via: vle.ledger_name = l.name AND l.company_guid = v.company_guid
- Groups form a TREE hierarchy via parent_guid. To get all ledgers under a reserved group (e.g., 'Sales Accounts'), you MUST use a recursive CTE on groups using parent_guid.
- Indian Financial Year: April 1 to March 31.

=== TABLE: companies ===
company_guid TEXT PRIMARY KEY
master_id INTEGER NOT NULL
alter_id INTEGER
company_name TEXT NOT NULL
reserved_name TEXT
starting_from TEXT NOT NULL       -- FY start in YYYYMMDD
ending_at TEXT NOT NULL           -- FY end in YYYYMMDD
books_from TEXT
books_beginning_from TEXT
gst_applicable_date TEXT
email TEXT, phone_number TEXT, fax_number TEXT, website TEXT
address TEXT, city TEXT, pincode TEXT, state TEXT, country TEXT
income_tax_number TEXT, pan TEXT, gsttin TEXT
currency_name TEXT, base_currency_name TEXT
maintain_accounts INTEGER DEFAULT 0
maintain_bill_wise INTEGER DEFAULT 0
enable_cost_centres INTEGER DEFAULT 0
maintain_inventory INTEGER DEFAULT 0
integrate_inventory INTEGER DEFAULT 0
is_gst_applicable INTEGER DEFAULT 0
is_tds_applicable INTEGER DEFAULT 0
is_tcs_applicable INTEGER DEFAULT 0
is_payroll_enabled INTEGER DEFAULT 0
is_deleted INTEGER DEFAULT 0
is_selected INTEGER DEFAULT 0

=== TABLE: voucher_types ===
(Defines voucher types like Sales, Purchase, Payment, Receipt, Journal, etc.)
voucher_type_guid TEXT PRIMARY KEY
company_guid TEXT NOT NULL
name TEXT NOT NULL
reserved_name TEXT
parent_guid TEXT
alter_id INTEGER NOT NULL
master_id INTEGER NOT NULL
is_deemed_positive INTEGER DEFAULT 1
affects_stock INTEGER DEFAULT 0
is_optional INTEGER DEFAULT 0
is_active INTEGER DEFAULT 1
is_deleted INTEGER DEFAULT 0
numbering_method TEXT NOT NULL
is_tax_invoice INTEGER DEFAULT 0

=== TABLE: groups ===
(Chart of Accounts hierarchy. Groups form a tree via parent_guid.)
group_guid TEXT PRIMARY KEY
company_guid TEXT NOT NULL
name TEXT NOT NULL
reserved_name TEXT                -- e.g., 'Sales Accounts', 'Sundry Debtors'
alter_id INTEGER
parent_guid TEXT                  -- FK to groups.group_guid (tree hierarchy)
narration TEXT
is_deleted INTEGER DEFAULT 0
is_revenue INTEGER DEFAULT 0
affects_gross_profit INTEGER DEFAULT 0
is_deemed_positive INTEGER DEFAULT 0
gst_applicable TEXT
tds_applicable TEXT
tcs_applicable TEXT

=== TABLE: ledgers ===
(GL accounts, parties, bank accounts. Linked to groups via parent field = groups.name.)
ledger_guid TEXT PRIMARY KEY
company_guid TEXT NOT NULL
name TEXT NOT NULL
alter_id INTEGER
parent TEXT                       -- group name (join via groups.name)
parent_guid TEXT                  -- FK to groups.group_guid
opening_balance REAL DEFAULT 0
closing_balance REAL DEFAULT 0
credit_limit REAL DEFAULT 0
is_deleted INTEGER DEFAULT 0
currency_name TEXT
party_gstin TEXT
email TEXT, website TEXT
income_tax_number TEXT
ledger_phone TEXT, ledger_mobile TEXT, ledger_contact TEXT
mailing_name TEXT, mailing_state TEXT, mailing_pincode TEXT, mailing_country TEXT, mailing_address TEXT
gst_registration_type TEXT, gstin TEXT
gst_applicable_from TEXT, gst_place_of_supply TEXT
is_billwise_on INTEGER DEFAULT 0
is_gst_applicable INTEGER DEFAULT 0
is_tds_applicable INTEGER DEFAULT 0
is_tcs_applicable INTEGER DEFAULT 0
tax_classification_name TEXT, tax_type TEXT, gst_type TEXT
ifsc_code TEXT, swift_code TEXT, bank_account_holder_name TEXT

=== TABLE: ledger_contacts ===
(Multiple contacts per ledger)
id INTEGER PRIMARY KEY AUTOINCREMENT
ledger_guid TEXT NOT NULL (FK -> ledgers)
company_guid TEXT NOT NULL
name TEXT NOT NULL
phone_number TEXT NOT NULL
country_isd_code TEXT

=== TABLE: ledger_mailing_details ===
(History of mailing addresses for ledgers)
id INTEGER PRIMARY KEY AUTOINCREMENT
ledger_guid TEXT NOT NULL (FK -> ledgers)
company_guid TEXT NOT NULL
applicable_from TEXT NOT NULL
mailing_name TEXT, state TEXT, country TEXT, pincode TEXT, address TEXT

=== TABLE: ledger_gst_registrations ===
(History of GST registrations for ledgers)
id INTEGER PRIMARY KEY AUTOINCREMENT
ledger_guid TEXT NOT NULL (FK -> ledgers)
company_guid TEXT NOT NULL
applicable_from TEXT NOT NULL
gst_registration_type TEXT
place_of_supply TEXT
gstin TEXT

=== TABLE: ledger_closing_balances ===
(Historical closing balances per ledger)
id INTEGER PRIMARY KEY AUTOINCREMENT
ledger_guid TEXT NOT NULL (FK -> ledgers)
company_guid TEXT NOT NULL
closing_date TEXT NOT NULL
amount REAL NOT NULL

=== TABLE: stock_items ===
(Inventory master data)
stock_item_guid TEXT PRIMARY KEY
company_guid TEXT NOT NULL
name TEXT NOT NULL
alter_id INTEGER
parent TEXT                       -- stock group name
category TEXT
base_units TEXT
additional_units TEXT
denominator REAL, conversion REAL
gst_applicable TEXT
costing_method TEXT
valuation_method TEXT
is_deleted INTEGER DEFAULT 0
is_batchwise_on INTEGER DEFAULT 0
latest_hsn_code TEXT
latest_hsn_description TEXT
latest_gst_taxability TEXT
latest_cgst_rate REAL, latest_sgst_rate REAL, latest_igst_rate REAL
latest_cess_rate REAL

=== TABLE: stock_item_batch_allocation ===
(Opening stock per godown/batch)
id INTEGER PRIMARY KEY AUTOINCREMENT
company_guid TEXT NOT NULL
stock_item_guid TEXT (FK -> stock_items)
godown_name TEXT, batch_name TEXT
mfd_on TEXT
opening_balance REAL DEFAULT 0
opening_value REAL DEFAULT 0
opening_rate REAL DEFAULT 0

=== TABLE: stock_item_closing_balance ===
(Closing inventory balances)
id INTEGER PRIMARY KEY AUTOINCREMENT
company_guid TEXT NOT NULL
stock_item_guid TEXT (FK -> stock_items)
closing_balance REAL DEFAULT 0
closing_value REAL DEFAULT 0
closing_rate REAL DEFAULT 0
closing_date TEXT

=== TABLE: stock_item_gst_history ===
(GST rate change history per stock item)
id INTEGER PRIMARY KEY AUTOINCREMENT
company_guid TEXT NOT NULL
stock_item_guid TEXT (FK -> stock_items)
applicable_from TEXT, taxability TEXT, state_name TEXT
cgst_rate REAL, sgst_rate REAL, igst_rate REAL, cess_rate REAL

=== TABLE: stock_item_hsn_history ===
(HSN code change history per stock item)
id INTEGER PRIMARY KEY AUTOINCREMENT
company_guid TEXT NOT NULL
stock_item_guid TEXT (FK -> stock_items)
applicable_from TEXT, hsn_code TEXT, hsn_description TEXT

=== TABLE: vouchers ===
(All transactions: Sales, Purchase, Receipt, Payment, Journal, Contra, Credit Note, Debit Note, etc.)
voucher_guid TEXT PRIMARY KEY
company_guid TEXT NOT NULL
master_id INTEGER NOT NULL
alter_id INTEGER
date TEXT NOT NULL                -- YYYYMMDD format
effective_date TEXT
voucher_type TEXT NOT NULL        -- e.g., 'Sales', 'Purchase', 'Payment', 'Receipt', 'Journal'
voucher_type_guid TEXT
voucher_number TEXT NOT NULL
party_ledger_name TEXT
party_ledger_guid TEXT
party_gstin TEXT
amount REAL
total_amount REAL
discount REAL
gst_registration_type TEXT
place_of_supply TEXT, state_name TEXT
narration TEXT
reference TEXT
is_deleted INTEGER DEFAULT 0
is_cancelled INTEGER DEFAULT 0
is_invoice INTEGER DEFAULT 0
is_optional INTEGER DEFAULT 0
has_discounts INTEGER DEFAULT 0
is_deemed_positive INTEGER DEFAULT 0

=== TABLE: voucher_ledger_entries ===
(Debit/credit line items for each voucher. This is the CORE accounting table.)
id INTEGER PRIMARY KEY AUTOINCREMENT
voucher_guid TEXT NOT NULL (FK -> vouchers)
company_guid TEXT NOT NULL
ledger_name TEXT NOT NULL
ledger_guid TEXT
amount REAL NOT NULL              -- NEGATIVE = DEBIT, POSITIVE = CREDIT
is_party_ledger INTEGER DEFAULT 0
is_deemed_positive INTEGER DEFAULT 0
bill_name TEXT
bill_amount REAL
bill_date TEXT
bill_type TEXT
instrument_number TEXT
instrument_date TEXT
transaction_type TEXT
cost_center_name TEXT
cost_center_amount REAL

=== TABLE: voucher_inventory_entries ===
(Stock line items for Sales/Purchase vouchers, with GST details)
id INTEGER PRIMARY KEY AUTOINCREMENT
voucher_guid TEXT NOT NULL (FK -> vouchers)
company_guid TEXT NOT NULL
stock_item_name TEXT NOT NULL
stock_item_guid TEXT
rate TEXT
amount REAL NOT NULL
actual_qty TEXT, billed_qty TEXT
discount REAL, discount_percent REAL
gst_rate TEXT
cgst_amount REAL, sgst_amount REAL, igst_amount REAL, cess_amount REAL
hsn_code TEXT, hsn_description TEXT
unit TEXT, alternate_unit TEXT
tracking_number TEXT, order_number TEXT
is_deemed_positive INTEGER DEFAULT 0

=== TABLE: voucher_batch_allocations ===
(Batch/godown wise stock allocation within inventory entries)
id INTEGER PRIMARY KEY AUTOINCREMENT
voucher_guid TEXT NOT NULL (FK -> vouchers)
company_guid TEXT NOT NULL
godown_name TEXT NOT NULL
stock_item_name TEXT NOT NULL
stock_item_guid TEXT
batch_name TEXT
amount REAL NOT NULL
actual_qty TEXT, billed_qty TEXT
batch_rate REAL
destination_godown_name TEXT
is_deemed_positive INTEGER DEFAULT 0
''';

  static String getSchema() => tallyDbSchema;
}
