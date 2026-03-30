import 'schema_provider.dart';

class PromptBuilder {
  static const String _exampleQueries = '''
=== PROVEN SQL PATTERNS (from the app's Analysis screens) ===

PATTERN 1: SALES QUERIES
(Source: analysis_home_screen.dart - Sales query)

*** DECISION LOGIC — READ FIRST ***
Does the user want to know WHO/WHICH party, or a TOTAL number?
- "total sales", "revenue", "turnover" → Use VARIANT A (total, no GROUP BY)
- "top customer", "top party", "customer name", "who bought most",
  "highest sales party", "party-wise", "customer-wise", "list customers" → Use VARIANT B (GROUP BY party)
If the question contains: top, who, which, name, customer, party, supplier, list, biggest, highest, lowest
→ ALWAYS use VARIANT B. When in doubt, use VARIANT B — it's better to show names than a single number.

VARIANT A — SALES TOTAL (only when user wants a single total number):
WITH RECURSIVE group_tree AS (
  SELECT group_guid, name
  FROM groups
  WHERE company_guid = '{company_guid}'
    AND reserved_name = 'Sales Accounts'
    AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name
  FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}'
    AND g.is_deleted = 0
)
SELECT
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
  (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) -
   SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'

VARIANT B — PARTY-WISE SALES (when user wants names/breakdown/top/who/which):
WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
)
SELECT
  v.party_ledger_name as party_name,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
  (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) -
   SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
  AND v.party_ledger_name IS NOT NULL AND v.party_ledger_name != ''
GROUP BY v.party_ledger_name
ORDER BY net_sales DESC
LIMIT 10
-- Adjust LIMIT: "top 1" → LIMIT 1, "top 5" → LIMIT 5, "all" → no LIMIT


PATTERN 2: PURCHASE QUERIES
(Source: analysis_home_screen.dart - Purchase query)
SAME decision logic as Pattern 1:
- "total purchase", "how much purchased" → VARIANT A (total)
- "top supplier", "which vendor", "supplier name", "party-wise purchase" → VARIANT B (GROUP BY party)
Net purchase = debit_total - credit_total (opposite of sales).

VARIANT A — PURCHASE TOTAL:
WITH RECURSIVE group_tree AS (
  SELECT group_guid, name
  FROM groups
  WHERE company_guid = '{company_guid}'
    AND reserved_name = 'Purchase Accounts'
    AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name
  FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}'
    AND g.is_deleted = 0
)
SELECT
  COUNT(*) as vouchers,
  SUM(debit_amount) as debit_total,
  SUM(credit_amount) as credit_total,
  SUM(net_amount) as net_purchase
FROM (
  SELECT
    SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
    SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_amount,
    (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
     SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
  FROM vouchers v
  INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
  INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
  INNER JOIN group_tree gt ON l.parent = gt.name
  WHERE v.company_guid = '{company_guid}'
    AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{from_date}' AND v.date <= '{to_date}'
  GROUP BY v.voucher_guid
) voucher_totals

VARIANT B — PARTY-WISE PURCHASE (when user wants names/top/who/which):
WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
)
SELECT
  v.party_ledger_name as party_name,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
  (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
   SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_purchase,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
  AND v.party_ledger_name IS NOT NULL AND v.party_ledger_name != ''
GROUP BY v.party_ledger_name
ORDER BY net_purchase DESC
LIMIT 10


PATTERN 3: DIRECT/INDIRECT EXPENSES or INCOMES by ledger
(Source: analysis_home_screen.dart - Expenses queries)
USE THIS for expenses, spending, cost queries. Change the group name as needed:
  - 'Direct Expenses' for COGS/direct costs
  - 'Indirect Expenses' for overhead/operating expenses
  - 'Direct Incomes' for other direct revenue
  - 'Indirect Incomes' for other income
NOTE: For Direct/Indirect Expenses, use name = 'Direct Expenses' (not reserved_name).
NOTE: For Direct/Indirect Incomes, use name = 'Direct Incomes' or 'Indirect Incomes'.

WITH RECURSIVE group_tree AS (
  SELECT group_guid, name
  FROM groups
  WHERE company_guid = '{company_guid}'
    AND name = 'Direct Expenses'
    AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name
  FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}'
    AND g.is_deleted = 0
)
SELECT
  vle.ledger_name,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
  (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
   SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY vle.ledger_name
ORDER BY net_amount DESC


PATTERN 4: RECEIVABLES (Sundry Debtors) - Who owes us money
(Source: analysis_home_screen.dart - Receivables query)
USE THIS for receivables, debtors, who owes, outstanding from customers.
IMPORTANT: Opening balance calculation = (ledger_opening_balance * -1) + debit_before - credit_before
Outstanding = opening_balance + debit_total - credit_total
Filter WHERE outstanding > 0.01 to get only those who OWE us.

WITH RECURSIVE group_tree AS (
  SELECT group_guid, name
  FROM groups
  WHERE company_guid = '{company_guid}'
    AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors')
    AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name
  FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}'
    AND g.is_deleted = 0
),
base_data AS (
  SELECT
    l.name as party_name,
    l.parent as group_name,
    l.opening_balance as ledger_opening_balance,
    COALESCE(SUM(CASE WHEN v.date < '{from_date}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
    COALESCE(SUM(CASE WHEN v.date < '{from_date}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
    COALESCE(SUM(CASE WHEN v.date >= '{from_date}' AND v.date <= '{to_date}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
    COALESCE(SUM(CASE WHEN v.date >= '{from_date}' AND v.date <= '{to_date}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
    COUNT(DISTINCT CASE WHEN v.date >= '{from_date}' AND v.date <= '{to_date}' THEN v.voucher_guid ELSE NULL END) as transaction_count
  FROM ledgers l
  INNER JOIN group_tree gt ON l.parent = gt.name
  LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
  LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    AND v.company_guid = l.company_guid
    AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  WHERE l.company_guid = '{company_guid}'
    AND l.is_deleted = 0
  GROUP BY l.name, l.parent, l.opening_balance
)
SELECT
  party_name,
  group_name,
  ((ledger_opening_balance * -1) + debit_before - credit_before) as opening_balance,
  debit_total,
  credit_total,
  ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) as outstanding,
  transaction_count
FROM base_data
WHERE ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) > 0.01
ORDER BY outstanding DESC


PATTERN 5: PAYABLES (Sundry Creditors) - What we owe to suppliers
(Source: analysis_home_screen.dart - Payables query)
USE THIS for payables, creditors, what we owe, outstanding to suppliers.
IMPORTANT: For creditors, opening_balance = ledger_opening_balance + credit_before - debit_before
Outstanding = opening_balance + credit_total - debit_total
Filter WHERE outstanding > 0.01 to get only those we OWE.

WITH RECURSIVE group_tree AS (
  SELECT group_guid, name
  FROM groups
  WHERE company_guid = '{company_guid}'
    AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors')
    AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name
  FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}'
    AND g.is_deleted = 0
),
base_data AS (
  SELECT
    l.name as party_name,
    l.parent as group_name,
    l.opening_balance as ledger_opening_balance,
    COALESCE(SUM(CASE WHEN v.date < '{from_date}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
    COALESCE(SUM(CASE WHEN v.date < '{from_date}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
    COALESCE(SUM(CASE WHEN v.date >= '{from_date}' AND v.date <= '{to_date}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
    COALESCE(SUM(CASE WHEN v.date >= '{from_date}' AND v.date <= '{to_date}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
    COUNT(DISTINCT CASE WHEN v.date >= '{from_date}' AND v.date <= '{to_date}' THEN v.voucher_guid ELSE NULL END) as transaction_count
  FROM ledgers l
  INNER JOIN group_tree gt ON l.parent = gt.name
  LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
  LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    AND v.company_guid = l.company_guid
    AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  WHERE l.company_guid = '{company_guid}'
    AND l.is_deleted = 0
  GROUP BY l.name, l.parent, l.opening_balance
)
SELECT
  party_name,
  group_name,
  (ledger_opening_balance + credit_before - debit_before) as opening_balance,
  credit_total,
  debit_total,
  (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding,
  transaction_count
FROM base_data
WHERE (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
ORDER BY outstanding DESC


PATTERN 6: TRIAL BALANCE
(Source: trial_balance_screen.dart)
USE THIS for trial balance, all ledger balances, debit vs credit totals.

SELECT
  l.name as ledger_name,
  l.parent as group_name,
  l.opening_balance,
  COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
  COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
  (l.opening_balance +
   COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
   COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
FROM ledgers l
LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  AND v.company_guid = l.company_guid
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
WHERE l.company_guid = '{company_guid}'
  AND l.is_deleted = 0
GROUP BY l.name, l.parent, l.opening_balance
ORDER BY l.parent, l.name


PATTERN 7: PAYMENT VOUCHERS (money going out)
(Source: analysis_home_screen.dart - Payments query)
USE THIS for payments, money paid, cash outflow.

SELECT
  v.voucher_guid,
  v.date,
  v.voucher_number,
  v.narration,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as amount,
  GROUP_CONCAT(DISTINCT CASE WHEN vle.amount > 0 THEN vle.ledger_name ELSE NULL END) as party_names
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.voucher_type = 'Payment'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
ORDER BY v.date DESC, v.voucher_number DESC


PATTERN 8: RECEIPT VOUCHERS (money coming in)
(Source: receipt_screen.dart)
USE THIS for receipts, money received, cash inflow.

SELECT
  v.voucher_guid,
  v.date,
  v.voucher_number,
  v.narration,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as amount,
  GROUP_CONCAT(DISTINCT CASE WHEN vle.amount < 0 THEN vle.ledger_name ELSE NULL END) as party_names
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.voucher_type = 'Receipt'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
ORDER BY v.date DESC, v.voucher_number DESC


PATTERN 9: LEDGER-WISE TRANSACTIONS with running balance
(Source: ledger_detail_screen.dart)
USE THIS for specific ledger transactions, party statement, account details.

SELECT v.voucher_guid, v.date, v.voucher_type, v.voucher_number, v.narration,
  vle.amount,
  CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END as debit,
  CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END as credit
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE vle.ledger_name = '{party_name}'
  AND v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
ORDER BY v.date ASC, v.voucher_number ASC


PATTERN 10: STOCK SUMMARY
(Source: stock_summary_screen.dart, profit_loss_screen2.dart)
USE THIS for stock items, inventory list, stock on hand.
NOTE: For stock VALUE queries, prefer Pattern 14 (reads pre-calculated closing values).
This pattern shows basic stock list. For value/qty, use Pattern 14 VARIANT B.

SELECT
  si.name as item_name,
  COALESCE(si.parent, '') as stock_group,
  COALESCE(si.base_units, '') as unit,
  COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
  COALESCE(cb.closing_balance, 0.0) as closing_qty,
  COALESCE(cb.closing_value, 0.0) as closing_value,
  COALESCE(cb.closing_rate, 0.0) as closing_rate
FROM stock_items si
INNER JOIN (
  SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
  UNION
  SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{company_guid}'
) active ON active.stock_item_guid = si.stock_item_guid
LEFT JOIN stock_item_closing_balance cb
  ON cb.stock_item_guid = si.stock_item_guid
  AND cb.company_guid = '{company_guid}'
  AND cb.closing_date = (
    SELECT MAX(closing_date) FROM stock_item_closing_balance
    WHERE company_guid = '{company_guid}' AND closing_date <= '{to_date}'
  )
WHERE si.company_guid = '{company_guid}'
  AND si.is_deleted = 0
ORDER BY si.parent, si.name


PATTERN 11: GROUP-WISE LEDGER BREAKDOWN with balances
(Source: group_detail_screen.dart)
USE THIS to list all ledgers under a specific group with their balances.
Change the reserved_name or name to match the desired group.

WITH RECURSIVE group_tree AS (
  SELECT group_guid, name
  FROM groups
  WHERE company_guid = '{company_guid}'
    AND reserved_name = 'Purchase Accounts'
    AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name
  FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}'
    AND g.is_deleted = 0
)
SELECT
  l.name as ledger_name,
  l.opening_balance,
  COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
  COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
  (l.opening_balance +
   COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
   COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance,
  COUNT(DISTINCT v.voucher_guid) as voucher_count
FROM ledgers l
INNER JOIN group_tree gt ON l.parent = gt.name
INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  AND v.company_guid = l.company_guid
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
WHERE l.company_guid = '{company_guid}'
  AND l.is_deleted = 0
GROUP BY l.name, l.opening_balance
ORDER BY closing_balance DESC


PATTERN 12: PROFIT & LOSS (P&L) STATEMENT
(Source: profit_loss_screen2.dart)

*** DECISION LOGIC — READ FIRST ***
- "net profit", "P&L", "P&L statement", "profit and loss", "net profit or loss" → VARIANT A (full P&L with all components)
- "gross profit" → VARIANT A2 (gross profit only — shorter query, faster)
- "expense breakdown", "what expenses", "direct expense", "indirect expense", "cost breakdown", "operating expenses" → VARIANT B (expense ledger details)
- "income breakdown", "other income", "direct income", "indirect income" → VARIANT C (income ledger details)
When in doubt, use VARIANT A — it gives the complete picture.

FORMULAS (from profit_loss_screen2.dart):
  Gross Profit = (Net Sales + Direct Incomes + Closing Stock) - (Opening Stock + Net Purchase + Direct Expenses)
  Net Profit = Gross Profit + Indirect Incomes - Indirect Expenses

STOCK IN P&L (UPDATED — now uses pre-calculated stock_item_closing_balance table):
- The app pre-calculates closing stock per item per date and stores results in stock_item_closing_balance table.
- Opening stock = SUM of closing_value from stock_item_closing_balance WHERE closing_date = previous day of from_date.
  If from_date is the FY start (company starting_from), opening stock = closing_value at that same date.
- Closing stock = SUM of closing_value from stock_item_closing_balance WHERE closing_date = to_date.
- Both opening and closing stock are now available via SQL (no need for FIFO/LIFO in-query).
- Only items with activity are included: items that exist in stock_item_batch_allocation OR voucher_inventory_entries.
- For NON-INVENTORY companies (integrate_inventory = 0): use Stock-in-Hand group + ledger_closing_balances table instead.

VARIANT A — FULL P&L SUMMARY (when user wants net profit/loss numbers):
IMPORTANT: This is a long query with 13 CTEs. You MUST output it COMPLETELY — do NOT truncate.

WITH RECURSIVE
sales_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN sales_groups sg ON g.parent_guid = sg.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
purchase_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN purchase_groups pg ON g.parent_guid = pg.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
de_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND name = 'Direct Expenses' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN de_groups dg ON g.parent_guid = dg.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
ie_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND name = 'Indirect Expenses' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN ie_groups ig ON g.parent_guid = ig.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
di_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND name = 'Direct Incomes' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN di_groups dig ON g.parent_guid = dig.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
ii_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND name = 'Indirect Incomes' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN ii_groups iig ON g.parent_guid = iig.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
sales_total AS (
  SELECT
    COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as net_sales
  FROM voucher_ledger_entries vle
  INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
  INNER JOIN sales_groups sg ON l.parent = sg.name
  WHERE v.company_guid = '{company_guid}'
    AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{from_date}' AND v.date <= '{to_date}'
),
purchase_total AS (
  SELECT COALESCE(SUM(net_amount), 0) as net_purchase FROM (
    SELECT
      (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
       SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
    FROM vouchers v
    INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
    INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
    INNER JOIN purchase_groups pg ON l.parent = pg.name
    WHERE v.company_guid = '{company_guid}'
      AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{from_date}' AND v.date <= '{to_date}'
    GROUP BY v.voucher_guid
  )
),
de_total AS (
  SELECT COALESCE(ABS(SUM(closing_balance)), 0) as direct_expenses_total FROM (
    SELECT
      (l.opening_balance +
       COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
       COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
    FROM ledgers l
    INNER JOIN de_groups dg ON l.parent = dg.name
    INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{from_date}' AND v.date <= '{to_date}'
    WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
    GROUP BY l.name, l.opening_balance
  )
),
ie_total AS (
  SELECT COALESCE(ABS(SUM(closing_balance)), 0) as indirect_expenses_total FROM (
    SELECT
      (l.opening_balance +
       COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
       COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
    FROM ledgers l
    INNER JOIN ie_groups ig ON l.parent = ig.name
    INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{from_date}' AND v.date <= '{to_date}'
    WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
    GROUP BY l.name, l.opening_balance
  )
),
di_total AS (
  SELECT COALESCE(SUM(closing_balance), 0) as direct_incomes_total FROM (
    SELECT
      (l.opening_balance +
       COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
       COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
    FROM ledgers l
    INNER JOIN di_groups dig ON l.parent = dig.name
    INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{from_date}' AND v.date <= '{to_date}'
    WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
    GROUP BY l.name, l.opening_balance
    HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
  )
),
ii_total AS (
  SELECT COALESCE(SUM(closing_balance), 0) as indirect_incomes_total FROM (
    SELECT
      (l.opening_balance +
       COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
       COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
    FROM ledgers l
    INNER JOIN ii_groups iig ON l.parent = iig.name
    INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{from_date}' AND v.date <= '{to_date}'
    WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
    GROUP BY l.name, l.opening_balance
    HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
  )
),
opening_stock AS (
  SELECT COALESCE(SUM(cb.closing_value), 0) as opening_stock_value
  FROM stock_items si
  INNER JOIN (
    SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
    UNION
    SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{company_guid}'
  ) active ON active.stock_item_guid = si.stock_item_guid
  LEFT JOIN stock_item_closing_balance cb
    ON cb.stock_item_guid = si.stock_item_guid
    AND cb.company_guid = '{company_guid}'
    AND cb.closing_date = '{opening_stock_date}'
  WHERE si.company_guid = '{company_guid}' AND si.is_deleted = 0
),
closing_stock AS (
  SELECT COALESCE(SUM(cb.closing_value), 0) as closing_stock_value
  FROM stock_items si
  INNER JOIN (
    SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
    UNION
    SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{company_guid}'
  ) active ON active.stock_item_guid = si.stock_item_guid
  LEFT JOIN stock_item_closing_balance cb
    ON cb.stock_item_guid = si.stock_item_guid
    AND cb.company_guid = '{company_guid}'
    AND cb.closing_date = '{to_date}'
  WHERE si.company_guid = '{company_guid}' AND si.is_deleted = 0
)
SELECT
  (SELECT net_sales FROM sales_total) as net_sales,
  (SELECT net_purchase FROM purchase_total) as net_purchase,
  (SELECT direct_expenses_total FROM de_total) as direct_expenses,
  (SELECT direct_incomes_total FROM di_total) as direct_incomes,
  (SELECT opening_stock_value FROM opening_stock) as opening_stock,
  (SELECT closing_stock_value FROM closing_stock) as closing_stock,
  (SELECT net_sales FROM sales_total) + (SELECT direct_incomes_total FROM di_total)
    + (SELECT closing_stock_value FROM closing_stock)
    - (SELECT opening_stock_value FROM opening_stock)
    - (SELECT net_purchase FROM purchase_total) - (SELECT direct_expenses_total FROM de_total) as gross_profit,
  (SELECT indirect_expenses_total FROM ie_total) as indirect_expenses,
  (SELECT indirect_incomes_total FROM ii_total) as indirect_incomes,
  (SELECT net_sales FROM sales_total) + (SELECT direct_incomes_total FROM di_total)
    + (SELECT closing_stock_value FROM closing_stock)
    - (SELECT opening_stock_value FROM opening_stock)
    - (SELECT net_purchase FROM purchase_total) - (SELECT direct_expenses_total FROM de_total)
    + (SELECT indirect_incomes_total FROM ii_total) - (SELECT indirect_expenses_total FROM ie_total) as net_profit

NOTE ON '{opening_stock_date}': This is the day BEFORE '{from_date}'.
  - If from_date is the FY start date (e.g., '20250401'), use from_date itself.
  - Otherwise, subtract 1 day from from_date. Example: from_date='20250501' → opening_stock_date='20250430'.
  - The app calculates this as: getPreviousDate(from_date).

VARIANT A2 — GROSS PROFIT ONLY (shorter query when user asks only about gross profit):
Gross Profit = Net Sales + Direct Incomes + Closing Stock - Opening Stock - Net Purchase - Direct Expenses
Uses 11 CTEs (includes opening_stock and closing_stock CTEs).

WITH RECURSIVE
sales_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN sales_groups sg ON g.parent_guid = sg.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
purchase_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN purchase_groups pg ON g.parent_guid = pg.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
de_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND name = 'Direct Expenses' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN de_groups dg ON g.parent_guid = dg.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
di_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND name = 'Direct Incomes' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN di_groups dig ON g.parent_guid = dig.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
),
sales_total AS (
  SELECT
    COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as net_sales
  FROM voucher_ledger_entries vle
  INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
  INNER JOIN sales_groups sg ON l.parent = sg.name
  WHERE v.company_guid = '{company_guid}'
    AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{from_date}' AND v.date <= '{to_date}'
),
purchase_total AS (
  SELECT COALESCE(SUM(net_amount), 0) as net_purchase FROM (
    SELECT
      (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
       SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
    FROM vouchers v
    INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
    INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
    INNER JOIN purchase_groups pg ON l.parent = pg.name
    WHERE v.company_guid = '{company_guid}'
      AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{from_date}' AND v.date <= '{to_date}'
    GROUP BY v.voucher_guid
  )
),
de_total AS (
  SELECT COALESCE(ABS(SUM(closing_balance)), 0) as direct_expenses_total FROM (
    SELECT
      (l.opening_balance +
       COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
       COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
    FROM ledgers l
    INNER JOIN de_groups dg ON l.parent = dg.name
    INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{from_date}' AND v.date <= '{to_date}'
    WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
    GROUP BY l.name, l.opening_balance
  )
),
di_total AS (
  SELECT COALESCE(SUM(closing_balance), 0) as direct_incomes_total FROM (
    SELECT
      (l.opening_balance +
       COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
       COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
    FROM ledgers l
    INNER JOIN di_groups dig ON l.parent = dig.name
    INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
    INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      AND v.company_guid = l.company_guid
      AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{from_date}' AND v.date <= '{to_date}'
    WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
    GROUP BY l.name, l.opening_balance
    HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
  )
),
opening_stock AS (
  SELECT COALESCE(SUM(cb.closing_value), 0) as opening_stock_value
  FROM stock_items si
  INNER JOIN (
    SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
    UNION
    SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{company_guid}'
  ) active ON active.stock_item_guid = si.stock_item_guid
  LEFT JOIN stock_item_closing_balance cb
    ON cb.stock_item_guid = si.stock_item_guid
    AND cb.company_guid = '{company_guid}'
    AND cb.closing_date = '{opening_stock_date}'
  WHERE si.company_guid = '{company_guid}' AND si.is_deleted = 0
),
closing_stock AS (
  SELECT COALESCE(SUM(cb.closing_value), 0) as closing_stock_value
  FROM stock_items si
  INNER JOIN (
    SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
    UNION
    SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{company_guid}'
  ) active ON active.stock_item_guid = si.stock_item_guid
  LEFT JOIN stock_item_closing_balance cb
    ON cb.stock_item_guid = si.stock_item_guid
    AND cb.company_guid = '{company_guid}'
    AND cb.closing_date = '{to_date}'
  WHERE si.company_guid = '{company_guid}' AND si.is_deleted = 0
)
SELECT
  (SELECT net_sales FROM sales_total) as net_sales,
  (SELECT net_purchase FROM purchase_total) as net_purchase,
  (SELECT direct_expenses_total FROM de_total) as direct_expenses,
  (SELECT direct_incomes_total FROM di_total) as direct_incomes,
  (SELECT opening_stock_value FROM opening_stock) as opening_stock,
  (SELECT closing_stock_value FROM closing_stock) as closing_stock,
  (SELECT net_sales FROM sales_total) + (SELECT direct_incomes_total FROM di_total)
    + (SELECT closing_stock_value FROM closing_stock)
    - (SELECT opening_stock_value FROM opening_stock)
    - (SELECT net_purchase FROM purchase_total) - (SELECT direct_expenses_total FROM de_total) as gross_profit

VARIANT B — EXPENSE BREAKDOWN BY LEDGER (when user wants expense details):
Change group name: 'Direct Expenses' for COGS/direct costs, 'Indirect Expenses' for overhead/operating.
closing_balance = opening_balance + credit_total - debit_total (negative means net expense).

WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND name = 'Direct Expenses' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
)
SELECT
  l.name as ledger_name,
  l.opening_balance,
  COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
  COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
  (l.opening_balance +
   COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
   COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
FROM ledgers l
INNER JOIN group_tree gt ON l.parent = gt.name
INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  AND v.company_guid = l.company_guid
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
GROUP BY l.name, l.opening_balance
ORDER BY closing_balance DESC

VARIANT C — INCOME BREAKDOWN BY LEDGER (when user wants income details):
Change group name: 'Direct Incomes' or 'Indirect Incomes'.
Includes HAVING filter to exclude ledgers with zero balance and no transactions.

WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND name = 'Indirect Incomes' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
)
SELECT
  l.name as ledger_name,
  l.opening_balance,
  COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
  COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
  (l.opening_balance +
   COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
   COALESCE(SUM(CASE WHEN v.voucher_guid IS NOT NULL AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
FROM ledgers l
INNER JOIN group_tree gt ON l.parent = gt.name
INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  AND v.company_guid = l.company_guid
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
GROUP BY l.name, l.opening_balance
HAVING l.opening_balance != 0 OR COUNT(v.voucher_guid) > 0
ORDER BY closing_balance DESC


PATTERN 13: VOUCHER DETAIL (single voucher with all entries)
(Source: voucher_detail_screen.dart)
USE THIS when user asks about a specific voucher or invoice.

SELECT v.voucher_guid, v.date, v.voucher_type, v.voucher_number,
  v.reference, v.narration, v.party_ledger_name,
  vle.ledger_name,
  CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END as debit,
  CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END as credit
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE v.voucher_guid = '{voucher_guid}'
  AND v.company_guid = '{company_guid}'


PATTERN 14: STOCK ANALYSIS
(Source: profit_loss_screen2.dart, stock_summary_screen.dart)

*** HOW STOCK WORKS IN THIS APP ***
Stock closing values are PRE-CALCULATED and stored in the stock_item_closing_balance table.
The app calculates FIFO/LIFO/Avg Cost offline and saves results per item per date.
You do NOT need to calculate stock from vouchers — just READ the pre-calculated values.

*** 2 KEY TABLES ***
  stock_items:                  item metadata (name, costing_method, base_units, parent group)
  stock_item_closing_balance:   pre-calculated closing qty, value, rate per item per date

*** DECISION LOGIC — READ FIRST ***

Step 1: Does the question ONLY ask for stock item NAMES or METADATA (no values, no quantities)?
  Detection keywords: "list items", "what items do I have", "show stock item names", "inventory list"
  YES → VARIANT A (metadata only)
  NO → Step 2

Step 2: Is the question about a SPECIFIC ITEM (by name)?
  Detection: question mentions a specific item name from the company snapshot
  YES → VARIANT B with item name filter
  NO → Step 3

Step 3: ALL other stock questions → use VARIANT B or VARIANT C
  This covers: closing stock, current stock, stock value, total stock, category wise, etc.
  Use the CLOSING_STOCK_CALCULATION_REQUIRED marker — the frontend will use the
  stockValuationCalculator to find the nearest available closing date and return results.

*** STOCK_QUERY_TYPE MARKER ***

You MUST add a STOCK_QUERY_TYPE marker line to tell the frontend HOW to format the results.
Place it AFTER the CLOSING_STOCK_CALCULATION_REQUIRED line (and after STOCK_ITEM_FILTER if present).

Format: -- STOCK_QUERY_TYPE: {type}

Available types:
  closing_stock     — Default. Per-item closing stock value table. Use for: "closing stock", "current stock", "stock value", "how much stock", "stock now", "stock at [date]"
  out_of_stock      — Items with zero or negative closing qty. Use for: "out of stock items", "zero stock", "items with no stock", "items finished"
  low_stock         — Items sorted by closing qty ascending (lowest first). Use for: "low stock items", "items running low", "minimum stock"
  by_category       — Items grouped by stock group (parent). Use for: "inventory by category", "stock by group", "category wise stock", "group wise stock"
  godown_breakdown  — Per-godown breakdown showing qty and value per godown per item. Use for: "godown wise stock", "warehouse stock", "location wise", "godown breakdown"
  movement_report   — Inward/outward movement totals per item. Use for: "stock movement", "inward outward summary", "movement report", "which items moved most"
  slow_moving       — Items sorted by outward qty ascending (least sold/moved). Use for: "slow moving items", "non-moving stock", "dead stock", "items not selling"
  comparison        — Compare stock between two dates. Use for: "compare stock", "stock this month vs last", "stock change". For comparison, add: -- STOCK_COMPARE_DATE: {earlier_date_YYYYMMDD}
  profit_margin     — Item-wise cost vs sales analysis. Use for: "item wise profit", "profit margin", "margin per item"

*** DATE CONVERSION ***
  "stock in year 2020"       → target_date = 20201231
  "stock in year 2022"       → target_date = 20221231
  "stock as on 31-Dec-2025"  → target_date = 20251231
  "current stock" / "now"    → target_date = today in YYYYMMDD
  "closing stock"            → target_date = {to_date} (end of selected period)
  "stock at end of FY"       → target_date = 20250331 (March 31 of current FY)
  "opening stock for 1-4-2022" → target_date = 20220401

Example markers:
  -- CLOSING_STOCK_CALCULATION_REQUIRED: 20260216
  -- STOCK_QUERY_TYPE: closing_stock

  -- CLOSING_STOCK_CALCULATION_REQUIRED: 20260216
  -- STOCK_ITEM_FILTER: Zinc Oxide White Seal
  -- STOCK_QUERY_TYPE: closing_stock

  -- CLOSING_STOCK_CALCULATION_REQUIRED: 20260216
  -- STOCK_QUERY_TYPE: comparison
  -- STOCK_COMPARE_DATE: 20260116


VARIANT A — LIST ALL STOCK ITEMS (metadata only)
USE WHEN: "show all stock items", "list items", "what items do we have"

SELECT
  si.name as item_name,
  COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
  COALESCE(si.base_units, '') as unit,
  COALESCE(si.parent, '') as stock_group
FROM stock_items si
WHERE si.company_guid = '{company_guid}'
  AND si.is_deleted = 0
ORDER BY si.parent, si.name


VARIANT B — STOCK VALUES (closing stock with pre-calculated values)
(Source: profit_loss_screen2.dart fetchAllClosingStock, stock_summary_screen.dart)
USE WHEN: ANY stock question involving values, quantities, closing stock, current stock, etc.

The FIRST LINE must be the marker comment — this tells the frontend to trigger
the stock valuation calculator which finds the nearest available closing date.
The frontend handles: finding nearest date, filtering, formatting by query type.

For specific item, add STOCK_ITEM_FILTER marker on the second line.

-- CLOSING_STOCK_CALCULATION_REQUIRED: {target_date_YYYYMMDD}
-- STOCK_QUERY_TYPE: closing_stock
SELECT
  si.name as item_name,
  si.stock_item_guid,
  COALESCE(si.costing_method, 'Avg. Cost') as costing_method,
  COALESCE(si.base_units, '') as unit,
  COALESCE(si.parent, '') as stock_group,
  COALESCE(cb.closing_balance, 0.0) as closing_qty,
  COALESCE(cb.closing_value, 0.0) as closing_value,
  COALESCE(cb.closing_rate, 0.0) as closing_rate
FROM stock_items si
INNER JOIN (
  SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
  UNION
  SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{company_guid}'
) active ON active.stock_item_guid = si.stock_item_guid
LEFT JOIN stock_item_closing_balance cb
  ON cb.stock_item_guid = si.stock_item_guid
  AND cb.company_guid = '{company_guid}'
  AND cb.closing_date = (
    SELECT MAX(closing_date) FROM stock_item_closing_balance
    WHERE company_guid = '{company_guid}' AND closing_date <= '{target_date_YYYYMMDD}'
  )
WHERE si.company_guid = '{company_guid}'
  AND si.is_deleted = 0
ORDER BY si.parent, si.name

NOTE: The subquery finds the latest available closing_date <= target_date because
stock_item_closing_balance stores month-end snapshots, not daily values.
The frontend ALSO does this lookup, so even if the SQL returns 0, the frontend
will find the correct date and return proper values.


VARIANT C — TOTAL STOCK VALUE (single number)
USE WHEN: "total stock value", "how much stock do we have", "inventory value"

-- CLOSING_STOCK_CALCULATION_REQUIRED: {target_date_YYYYMMDD}
-- STOCK_QUERY_TYPE: closing_stock
SELECT
  COALESCE(SUM(cb.closing_value), 0.0) as total_stock_value,
  COUNT(DISTINCT si.stock_item_guid) as item_count
FROM stock_items si
INNER JOIN (
  SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
  UNION
  SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{company_guid}'
) active ON active.stock_item_guid = si.stock_item_guid
LEFT JOIN stock_item_closing_balance cb
  ON cb.stock_item_guid = si.stock_item_guid
  AND cb.company_guid = '{company_guid}'
  AND cb.closing_date = (
    SELECT MAX(closing_date) FROM stock_item_closing_balance
    WHERE company_guid = '{company_guid}' AND closing_date <= '{target_date_YYYYMMDD}'
  )
WHERE si.company_guid = '{company_guid}'
  AND si.is_deleted = 0


PATTERN 15: CASH & BANK BALANCE
(Source: balance sheet / trial balance logic)
USE THIS for cash balance, bank balance, cash in hand, how much in bank, fund position.

*** DECISION LOGIC ***
- "cash balance", "cash in hand" → filter group 'Cash-in-Hand'
- "bank balance", "how much in bank" → filter group 'Bank Accounts'
- "fund position", "liquid funds", "cash and bank" → combine both groups

VARIANT A — CASH IN HAND:
WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND (name = 'Cash-in-Hand' OR reserved_name = 'Cash-in-Hand') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
)
SELECT
  l.name as ledger_name,
  l.opening_balance,
  COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
  COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
  (l.opening_balance +
   COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
   COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
FROM ledgers l
INNER JOIN group_tree gt ON l.parent = gt.name
LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  AND v.company_guid = l.company_guid
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
GROUP BY l.name, l.opening_balance
ORDER BY l.name

VARIANT B — BANK BALANCE:
Same as Variant A but change group filter to: (name = 'Bank Accounts' OR reserved_name = 'Bank Accounts')

VARIANT C — CASH + BANK COMBINED (fund position):
WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}'
    AND (name IN ('Cash-in-Hand', 'Bank Accounts', 'Bank OD A/c') OR reserved_name IN ('Cash-in-Hand', 'Bank Accounts', 'Bank OD A/c'))
    AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
)
SELECT
  l.name as ledger_name,
  l.parent as group_name,
  l.opening_balance,
  COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
  COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
  (l.opening_balance +
   COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
   COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0)) as closing_balance
FROM ledgers l
INNER JOIN group_tree gt ON l.parent = gt.name
LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  AND v.company_guid = l.company_guid
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
WHERE l.company_guid = '{company_guid}' AND l.is_deleted = 0
GROUP BY l.name, l.parent, l.opening_balance
ORDER BY l.parent, l.name


PATTERN 16: DAY BOOK (all vouchers for a date or period)
USE THIS for day book, all transactions, all vouchers today, voucher list, transaction register.

*** DECISION LOGIC ***
- "day book", "all vouchers", "all transactions" → list all vouchers in period
- "today's transactions" → filter v.date = today's date in YYYYMMDD
- "specific date" → filter v.date = that date

SELECT
  v.date,
  v.voucher_type,
  v.voucher_number,
  v.party_ledger_name,
  v.narration,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_amount,
  GROUP_CONCAT(DISTINCT vle.ledger_name) as ledgers_involved
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY v.voucher_guid, v.date, v.voucher_type, v.voucher_number, v.party_ledger_name, v.narration
ORDER BY v.date DESC, v.voucher_type, v.voucher_number DESC
LIMIT 50


PATTERN 17: ITEM-WISE SALES / PURCHASE
(Source: voucher_inventory_entries table)
USE THIS for item-wise sales, product-wise sales, which item sold most, item-wise purchase, top selling item.

*** DECISION LOGIC ***
- "item wise sales", "product wise sales", "top selling item" → VARIANT A (sales)
- "item wise purchase", "which item purchased most" → VARIANT B (purchase)

VARIANT A — ITEM-WISE SALES:
SELECT
  vie.stock_item_name as item_name,
  COUNT(DISTINCT v.voucher_guid) as num_invoices,
  SUM(ABS(vie.amount)) as total_amount,
  SUM(CAST(REPLACE(REPLACE(vie.actual_qty, ' Nos', ''), ' Pcs', '') AS REAL)) as total_qty,
  vie.unit
FROM vouchers v
INNER JOIN voucher_inventory_entries vie ON vie.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.voucher_type IN ('Sales', 'Credit Note')
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY vie.stock_item_name, vie.unit
ORDER BY total_amount DESC
LIMIT 20

VARIANT B — ITEM-WISE PURCHASE:
SELECT
  vie.stock_item_name as item_name,
  COUNT(DISTINCT v.voucher_guid) as num_invoices,
  SUM(ABS(vie.amount)) as total_amount,
  SUM(CAST(REPLACE(REPLACE(vie.actual_qty, ' Nos', ''), ' Pcs', '') AS REAL)) as total_qty,
  vie.unit
FROM vouchers v
INNER JOIN voucher_inventory_entries vie ON vie.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.voucher_type IN ('Purchase', 'Debit Note')
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY vie.stock_item_name, vie.unit
ORDER BY total_amount DESC
LIMIT 20


PATTERN 18: MONTHLY / PERIOD-WISE BREAKDOWN
USE THIS for month-wise sales, monthly purchase trend, monthly expense, period-wise analysis.
Change the group CTE as needed (Sales Accounts, Purchase Accounts, Direct Expenses, etc.)

*** DECISION LOGIC ***
- "month wise sales", "monthly sales" → group by month on Sales Accounts
- "month wise purchase" → group by month on Purchase Accounts
- "monthly expenses" → group by month on Direct/Indirect Expenses

VARIANT A — MONTHLY SALES BREAKDOWN:
WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
)
SELECT
  SUBSTR(v.date, 1, 6) as month_yyyymm,
  CASE SUBSTR(v.date, 5, 2)
    WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
    WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
    WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
    WHEN '10' THEN 'October' WHEN '11' THEN 'November' WHEN '12' THEN 'December'
  END || ' ' || SUBSTR(v.date, 1, 4) as month_name,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
  (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) -
   SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY SUBSTR(v.date, 1, 6)
ORDER BY month_yyyymm ASC

VARIANT B — MONTHLY PURCHASE BREAKDOWN:
Same as Variant A but change:
- reserved_name = 'Purchase Accounts'
- Net purchase = debit_total - credit_total (swap the formula)

VARIANT C — MONTHLY EXPENSE BREAKDOWN:
Same as Variant A but change:
- Use name = 'Direct Expenses' or name = 'Indirect Expenses' (or both combined)
- Net expense = debit_total - credit_total


PATTERN 19: VOUCHER TYPE SUMMARY
USE THIS for voucher summary, how many sales invoices, transaction count by type, voucher count.

SELECT
  v.voucher_type,
  COUNT(*) as voucher_count,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as total_debit,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as total_credit
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY v.voucher_type
ORDER BY voucher_count DESC


PATTERN 20: GST SUMMARY (HSN-wise)
(Source: voucher_inventory_entries table with GST columns)
USE THIS for GST report, GST collected, GST paid, HSN-wise summary, tax summary, CGST SGST IGST.

*** DECISION LOGIC ***
- "GST collected", "output GST", "GST on sales" → VARIANT A (sales GST)
- "GST paid", "input GST", "GST on purchase" → VARIANT B (purchase GST)
- "HSN summary", "HSN wise" → VARIANT C (HSN-wise breakdown)

VARIANT A — GST ON SALES:
SELECT
  COALESCE(vie.hsn_code, 'No HSN') as hsn_code,
  vie.stock_item_name,
  SUM(ABS(vie.amount)) as taxable_value,
  SUM(COALESCE(vie.cgst_amount, 0)) as cgst,
  SUM(COALESCE(vie.sgst_amount, 0)) as sgst,
  SUM(COALESCE(vie.igst_amount, 0)) as igst,
  SUM(COALESCE(vie.cess_amount, 0)) as cess,
  SUM(ABS(vie.amount)) + SUM(COALESCE(vie.cgst_amount, 0)) + SUM(COALESCE(vie.sgst_amount, 0))
    + SUM(COALESCE(vie.igst_amount, 0)) + SUM(COALESCE(vie.cess_amount, 0)) as total_with_tax
FROM vouchers v
INNER JOIN voucher_inventory_entries vie ON vie.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.voucher_type = 'Sales'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY vie.hsn_code, vie.stock_item_name
ORDER BY taxable_value DESC

VARIANT B — GST ON PURCHASE:
Same as Variant A but change: v.voucher_type = 'Purchase'

VARIANT C — HSN-WISE SUMMARY (aggregated by HSN code only):
SELECT
  COALESCE(vie.hsn_code, 'No HSN') as hsn_code,
  COALESCE(vie.hsn_description, '') as description,
  vie.gst_rate,
  COUNT(DISTINCT v.voucher_guid) as num_invoices,
  SUM(ABS(vie.amount)) as taxable_value,
  SUM(COALESCE(vie.cgst_amount, 0)) as cgst,
  SUM(COALESCE(vie.sgst_amount, 0)) as sgst,
  SUM(COALESCE(vie.igst_amount, 0)) as igst,
  SUM(COALESCE(vie.cess_amount, 0)) as cess
FROM vouchers v
INNER JOIN voucher_inventory_entries vie ON vie.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.voucher_type IN ('Sales', 'Purchase')
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY vie.hsn_code, vie.hsn_description, vie.gst_rate
ORDER BY taxable_value DESC


PATTERN 21: BILL-WISE OUTSTANDING (Aging for debtors or creditors)
(Source: voucher_ledger_entries bill columns)
USE THIS for bill aging, overdue bills, pending bills, bill-wise outstanding, aging analysis.
IMPORTANT: Only works if company has maintain_bill_wise enabled. Check bill_name IS NOT NULL.

*** DECISION LOGIC ***
- "bill aging", "overdue receivables", "pending bills from customers" → VARIANT A (debtors)
- "overdue payables", "pending bills to suppliers" → VARIANT B (creditors)

VARIANT A — BILL-WISE RECEIVABLE AGING:
WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{company_guid}' AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{company_guid}' AND g.is_deleted = 0
)
SELECT
  vle.ledger_name as party_name,
  vle.bill_name,
  vle.bill_date,
  vle.bill_type,
  SUM(vle.bill_amount) as bill_outstanding,
  CASE
    WHEN CAST(julianday('now') - julianday(
      SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
    ) AS INTEGER) <= 30 THEN '0-30 days'
    WHEN CAST(julianday('now') - julianday(
      SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
    ) AS INTEGER) <= 60 THEN '31-60 days'
    WHEN CAST(julianday('now') - julianday(
      SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
    ) AS INTEGER) <= 90 THEN '61-90 days'
    ELSE '90+ days'
  END as aging_bucket
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{company_guid}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND vle.bill_name IS NOT NULL AND vle.bill_name != ''
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY vle.ledger_name, vle.bill_name, vle.bill_date, vle.bill_type
HAVING bill_outstanding > 0.01
ORDER BY vle.ledger_name, vle.bill_date

VARIANT B — BILL-WISE PAYABLE AGING:
Same as Variant A but change group to 'Sundry Creditors' and
HAVING bill_outstanding < -0.01 (creditor bills have negative outstanding)
ORDER BY bill_outstanding ASC


PATTERN 22: CONTRA VOUCHERS (Fund Transfers)
USE THIS for contra entries, fund transfers, bank to cash, cash deposit, cash withdrawal.

SELECT
  v.date,
  v.voucher_number,
  v.narration,
  GROUP_CONCAT(DISTINCT CASE WHEN vle.amount < 0 THEN vle.ledger_name ELSE NULL END) as from_account,
  GROUP_CONCAT(DISTINCT CASE WHEN vle.amount > 0 THEN vle.ledger_name ELSE NULL END) as to_account,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as amount
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.voucher_type = 'Contra'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
ORDER BY v.date DESC, v.voucher_number DESC


PATTERN 23: JOURNAL VOUCHERS (Adjustments)
USE THIS for journal entries, adjustments, JV list.

SELECT
  v.date,
  v.voucher_number,
  v.narration,
  GROUP_CONCAT(DISTINCT CASE WHEN vle.amount < 0 THEN vle.ledger_name ELSE NULL END) as debit_ledgers,
  GROUP_CONCAT(DISTINCT CASE WHEN vle.amount > 0 THEN vle.ledger_name ELSE NULL END) as credit_ledgers,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as amount
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{company_guid}'
  AND v.voucher_type = 'Journal'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{from_date}' AND v.date <= '{to_date}'
GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
ORDER BY v.date DESC, v.voucher_number DESC
LIMIT 50


=== SALARY QUERIES ===
For ANY salary-related query:
1. CHECK the "SALARY PER-PERSON" section in the company data snapshot FIRST.
2. Salary = DEBIT entries from keyword-matching expense ledgers on vouchers with party_ledger_name.
3. Deductions = CREDIT entries on those same vouchers (auto-detected via group hierarchy).

=== TAX / TDS / GST QUERIES ===
CRITICAL: For ANY TDS/GST/tax query, query the 'Duties & Taxes' group DIRECTLY.
Do NOT use salary voucher CTE — TDS on Rent, Interest, Labour are NOT salary vouchers.
''';

  static const String _reservedGroups = '''
=== RESERVED GROUP NAMES IN TALLY ===
Use these with the groups table. Check BOTH name and reserved_name fields.

Revenue/Expense groups (for P&L):
- 'Sales Accounts' (reserved_name)
- 'Purchase Accounts' (reserved_name)
- 'Direct Expenses' (name only)
- 'Indirect Expenses' (name only)
- 'Direct Incomes' (name only)
- 'Indirect Incomes' (name only)

Party groups (for receivables/payables):
- 'Sundry Debtors' (both name and reserved_name)
- 'Sundry Creditors' (both name and reserved_name)

Balance Sheet groups:
- 'Capital Account', 'Current Assets', 'Current Liabilities'
- 'Fixed Assets', 'Investments', 'Loans (Liability)'
- 'Bank Accounts', 'Cash-in-Hand', 'Duties & Taxes', 'Bank OD A/c'
- 'Stock-in-Hand' (used for non-inventory mode stock valuation via ledger_closing_balances)

Voucher types: 'Sales', 'Purchase', 'Receipt', 'Payment', 'Journal', 'Contra', 'Credit Note', 'Debit Note'

Salary/Payroll:
- ALWAYS check "SALARY PER-PERSON" and "SALARY DEDUCTIONS" sections in snapshot.
- Salary = DEBIT entries from keyword-matching expense ledgers (SALARY, BONUS, WAGE, etc.)
- Deductions = CREDIT entries on salary vouchers (auto-detected).
- ALWAYS separate TDS, Professional Tax, EPF, ESI as individual items.
''';

  static const String _systemPromptTemplate = '''You are an expert SQL query generator for an Indian accounting application (Tally ERP data stored in SQLite).
You generate SQLite-compatible SELECT queries against a local database called tally_clone.db.

ABSOLUTE RULES - NEVER VIOLATE:
1. ONLY generate SELECT or WITH...SELECT queries. NEVER INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, TRUNCATE, GRANT, REVOKE.
2. Every query MUST filter by company_guid = '{company_guid}'.
3. Dates are YYYYMMDD strings. Use string comparison: v.date >= '{from_date}' AND v.date <= '{to_date}'
4. For vouchers, ALWAYS include: v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
5. For ledgers and groups: ALWAYS include is_deleted = 0
6. Amount in voucher_ledger_entries: NEGATIVE = DEBIT, POSITIVE = CREDIT.
7. When querying ledgers under ANY group hierarchy, ALWAYS use a recursive CTE on the groups table.
8. Join ledgers to groups via: l.parent = gt.name (name-based, NOT guid).
9. Join voucher_ledger_entries to ledgers via: vle.ledger_name = l.name AND l.company_guid = v.company_guid
10. For Sales: reserved_name = 'Sales Accounts'. Net sales = credit_total - debit_total.
11. For Purchase: reserved_name = 'Purchase Accounts'. Net purchase = debit_total - credit_total.
12. For Expenses: use name = 'Direct Expenses' or name = 'Indirect Expenses'.
13. For Incomes: use name = 'Direct Incomes' or name = 'Indirect Incomes'.
14. For Sundry Debtors/Creditors: check BOTH name and reserved_name.
15. If no LIMIT is specified and results could be large, default to LIMIT 50.
16. NAME/WHO/WHICH/TOP QUERIES: ALWAYS include the name column and GROUP BY it.
17. For TDS/GST/tax queries: ALWAYS query 'Duties & Taxes' group directly with recursive CTE.

{schema}

{reserved_groups}

{examples}

{company_data}

OUTPUT FORMAT:
- Return ONLY the raw SQL query. Nothing else.
- Do NOT include any explanation, markdown, code fences, or comments.
- Do NOT wrap in ```sql or ```.
- The query must be a single valid SQLite query.
- Use '{company_guid}' literally as the company_guid placeholder.
- Use '{from_date}' and '{to_date}' literally as date placeholders.
- Use '{opening_stock_date}' literally for the opening stock date placeholder (day before from_date).
- Use '{party_name}' literally if the query needs a party filter.
- Do NOT add trailing semicolons.
''';

  /// Build the system prompt with schema, examples, rules, and company data.
  String buildSystemPrompt({
    required String companyGuid,
    String companyData = '',
  }) {
    return _systemPromptTemplate
        .replaceAll('{schema}', SchemaProvider.tallyDbSchema)
        .replaceAll('{reserved_groups}', _reservedGroups)
        .replaceAll('{examples}', _exampleQueries)
        .replaceAll('{company_data}', companyData)
        .replaceAll('{company_guid}', companyGuid)
        .replaceAll('{from_date}', '{from_date}')
        .replaceAll('{to_date}', '{to_date}')
        .replaceAll('{opening_stock_date}', '{opening_stock_date}')
        .replaceAll('{party_name}', '{party_name}');
  }

  /// Build the user message with the question, context, and conversation history.
  String buildUserMessage({
    required String question,
    required String fromDate,
    required String toDate,
    required Map<String, dynamic> entities,
    List<Map<String, dynamic>>? conversationHistory,
  }) {
    final parts = <String>[];

    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      parts.add('=== CONVERSATION CONTEXT (previous questions in this session) ===');
      final recentHistory = conversationHistory.length > 5
          ? conversationHistory.sublist(conversationHistory.length - 5)
          : conversationHistory;
      for (var i = 0; i < recentHistory.length; i++) {
        final turn = recentHistory[i];
        parts.add('Turn ${i + 1}:');
        parts.add('  Q: ${turn['question'] ?? '?'}');
        if (turn['result_summary'] != null) {
          parts.add('  Result: ${turn['result_summary']}');
        }
        if (turn['sql_columns'] != null) {
          parts.add('  Columns: ${(turn['sql_columns'] as List).join(', ')}');
        }
      }
      parts.add('=== END CONTEXT ===');
      parts.add('');
      parts.add('Use the above context to understand follow-up questions like '
          '"what about X?", "same for Y", "show breakdown", "and for last month?".');
      parts.add('');
    }

    parts.add('Question: $question');
    parts.add('Date range: $fromDate to $toDate');

    if (entities['party_name'] != null) {
      parts.add('Party/customer/supplier name: ${entities['party_name']}');
    }
    if (entities['limit'] != null) {
      parts.add('Limit results to: ${entities['limit']} rows');
    }
    if (entities['amount_min'] != null) {
      parts.add('Minimum amount filter: ${entities['amount_min']}');
    }
    if (entities['amount_max'] != null) {
      parts.add('Maximum amount filter: ${entities['amount_max']}');
    }

    parts.add('\nGenerate the SQL query now.');
    return parts.join('\n');
  }
}
