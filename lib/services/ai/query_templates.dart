import '../../models/ai/query_template.dart';

/// All pre-built SQL query templates organized by category.
/// Each template maps to exactly ONE preset question — no duplicates.
class QueryTemplates {
  static List<QueryTemplate> loadAll() {
    return [
      ..._salesTemplates,
      ..._purchaseTemplates,
      ..._receivablesTemplates,
      ..._payablesTemplates,
      ..._stockTemplates,
      ..._expensesTemplates,
      ..._profitLossTemplates,
      ..._trialBalanceTemplates,
      ..._balanceSheetTemplates,
      ..._cashflowTemplates,
      ..._gstTemplates,
      ..._bankCashTemplates,
      ..._comboTemplates,
    ];
  }

  static List<QueryTemplate> getByCategory(String category) {
    return loadAll().where((t) => t.category == category).toList();
  }

  static QueryTemplate? getById(String templateId) {
    try {
      return loadAll().firstWhere((t) => t.templateId == templateId);
    } catch (_) {
      return null;
    }
  }

  // ─── Sales ───

  static final _salesTemplates = [
    // 1. Total sales aggregate
    const QueryTemplate(
      templateId: 'tmpl-sales-001',
      category: 'sales',
      intentKeywords: ['sales', 'revenue', 'income', 'turnover'],
      description: 'Total sales from Sales Accounts group',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
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
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' ''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: [
        'Total sales this year',
        'What were my sales?',
        'What is my total revenue this year?',
      ],
    ),
    // 2. Top N customers by sales
    const QueryTemplate(
      templateId: 'tmpl-sales-002',
      category: 'sales',
      intentKeywords: ['top', 'customer', 'party', 'buyer', 'sales breakdown'],
      description: 'Top N customers by sales value',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT v.party_ledger_name as party_name,
  (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) -
   SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as total_sales,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
  AND v.party_ledger_name IS NOT NULL AND v.party_ledger_name != ''
GROUP BY v.party_ledger_name
ORDER BY total_sales DESC
LIMIT {{limit}}''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
        'limit': {'type': 'integer', 'required': false, 'default': 10},
      },
      sampleQuestions: [
        'Top 10 customers by sales',
        'Show me top 5 customers by sales',
      ],
    ),
    // 3. Month wise sales breakdown
    const QueryTemplate(
      templateId: 'tmpl-sales-003',
      category: 'sales',
      intentKeywords: ['month wise', 'monthly sales', 'sales trend'],
      description: 'Monthly sales breakdown',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT
  SUBSTR(v.date, 1, 6) as month_yyyymm,
  CASE SUBSTR(v.date, 5, 2)
    WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
    WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
    WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
    WHEN '10' THEN 'October' WHEN '11' THEN 'November' WHEN '12' THEN 'December'
  END || ' ' || SUBSTR(v.date, 1, 4) as month_name,
  (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) -
   SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY SUBSTR(v.date, 1, 6)
ORDER BY month_yyyymm ASC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Month wise sales breakdown', 'Monthly sales trend'],
    ),
    // 4. Item wise sales
    const QueryTemplate(
      templateId: 'tmpl-sales-004',
      category: 'sales',
      intentKeywords: ['item wise sales', 'product wise sales', 'top selling item'],
      description: 'Item wise sales from inventory entries',
      sqlTemplate: '''SELECT
  vie.stock_item_name as item_name,
  COUNT(DISTINCT v.voucher_guid) as num_invoices,
  SUM(ABS(vie.amount)) as total_amount,
  SUM(CAST(REPLACE(REPLACE(vie.actual_qty, ' Nos', ''), ' Pcs', '') AS REAL)) as total_qty,
  vie.unit
FROM vouchers v
INNER JOIN voucher_inventory_entries vie ON vie.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type IN ('Sales', 'Credit Note')
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vie.stock_item_name, vie.unit
ORDER BY total_amount DESC
LIMIT 20''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Item wise sales summary', 'Top selling items'],
    ),
  ];

  // ─── Purchase ───

  static final _purchaseTemplates = [
    // 1. Total purchase aggregate
    const QueryTemplate(
      templateId: 'tmpl-purchase-001',
      category: 'purchase',
      intentKeywords: ['purchase', 'bought', 'procurement'],
      description: 'Total purchases from Purchase Accounts group',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT COUNT(*) as vouchers,
  SUM(debit_amount) as debit_total, SUM(credit_amount) as credit_total,
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
  WHERE v.company_guid = '{{company_guid}}'
    AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
  GROUP BY v.voucher_guid
) voucher_totals''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: [
        'Total purchases this year',
        'What were my purchases?',
      ],
    ),
    // 2. Top N suppliers
    const QueryTemplate(
      templateId: 'tmpl-purchase-002',
      category: 'purchase',
      intentKeywords: ['top', 'supplier', 'vendor', 'purchase breakdown'],
      description: 'Top N suppliers by purchase value',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT v.party_ledger_name as party_name,
  (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
   SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as total_purchase,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
  AND v.party_ledger_name IS NOT NULL AND v.party_ledger_name != ''
GROUP BY v.party_ledger_name
ORDER BY total_purchase DESC
LIMIT {{limit}}''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
        'limit': {'type': 'integer', 'required': false, 'default': 10},
      },
      sampleQuestions: ['Top 10 suppliers by purchase', 'Show top 5 suppliers by purchase value'],
    ),
    // 3. Month wise purchase
    const QueryTemplate(
      templateId: 'tmpl-purchase-003',
      category: 'purchase',
      intentKeywords: ['month wise purchase', 'monthly purchase', 'purchase trend'],
      description: 'Monthly purchase breakdown',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT
  SUBSTR(v.date, 1, 6) as month_yyyymm,
  CASE SUBSTR(v.date, 5, 2)
    WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
    WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
    WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
    WHEN '10' THEN 'October' WHEN '11' THEN 'November' WHEN '12' THEN 'December'
  END || ' ' || SUBSTR(v.date, 1, 4) as month_name,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
  (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
   SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_purchase,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY SUBSTR(v.date, 1, 6)
ORDER BY month_yyyymm ASC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Month wise purchase breakdown', 'Monthly purchase trend'],
    ),
    // 4. Item wise purchase
    const QueryTemplate(
      templateId: 'tmpl-purchase-004',
      category: 'purchase',
      intentKeywords: ['item wise purchase', 'product wise purchase'],
      description: 'Item wise purchase from inventory entries',
      sqlTemplate: '''SELECT
  vie.stock_item_name as item_name,
  COUNT(DISTINCT v.voucher_guid) as num_invoices,
  SUM(ABS(vie.amount)) as total_amount,
  SUM(CAST(REPLACE(REPLACE(vie.actual_qty, ' Nos', ''), ' Pcs', '') AS REAL)) as total_qty,
  vie.unit
FROM vouchers v
INNER JOIN voucher_inventory_entries vie ON vie.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type IN ('Purchase', 'Debit Note')
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vie.stock_item_name, vie.unit
ORDER BY total_amount DESC
LIMIT 20''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Item wise purchase summary', 'Top purchased items'],
    ),
  ];

  // ─── Receivables ───

  static final _receivablesTemplates = [
    // 1. All outstanding receivables
    const QueryTemplate(
      templateId: 'tmpl-receivables-001',
      category: 'receivables',
      intentKeywords: ['receivable', 'debtor', 'owed', 'outstanding', 'customer balance'],
      description: 'Outstanding receivables from Sundry Debtors',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}'
    AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
base_data AS (
  SELECT l.name as party_name, l.parent as group_name, l.opening_balance as ledger_opening_balance,
    COALESCE(SUM(CASE WHEN v.date < '{{from_date}}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
    COALESCE(SUM(CASE WHEN v.date < '{{from_date}}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
    COALESCE(SUM(CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
    COALESCE(SUM(CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
    COUNT(DISTINCT CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' THEN v.voucher_guid ELSE NULL END) as transaction_count
  FROM ledgers l
  INNER JOIN group_tree gt ON l.parent = gt.name
  LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
  LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    AND v.company_guid = l.company_guid
    AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
  GROUP BY l.name, l.parent, l.opening_balance
)
SELECT party_name, group_name,
  ((ledger_opening_balance * -1) + debit_before - credit_before) as opening_balance,
  debit_total, credit_total,
  ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) as outstanding,
  transaction_count
FROM base_data
WHERE ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) > 0.01
ORDER BY outstanding DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: [
        'All outstanding receivables',
        'Who owes me money?',
      ],
    ),
    // 2. Top 10 debtors
    const QueryTemplate(
      templateId: 'tmpl-receivables-002',
      category: 'receivables',
      intentKeywords: ['top debtor', 'biggest debtor'],
      description: 'Top N debtors by outstanding',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}'
    AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
base_data AS (
  SELECT l.name as party_name, l.opening_balance as ledger_opening_balance,
    COALESCE(SUM(CASE WHEN v.date < '{{from_date}}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
    COALESCE(SUM(CASE WHEN v.date < '{{from_date}}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
    COALESCE(SUM(CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
    COALESCE(SUM(CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total
  FROM ledgers l
  INNER JOIN group_tree gt ON l.parent = gt.name
  LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
  LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
  GROUP BY l.name, l.opening_balance
)
SELECT party_name,
  ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) as outstanding
FROM base_data
WHERE ((ledger_opening_balance * -1) + debit_before - credit_before + debit_total - credit_total) > 0.01
ORDER BY outstanding DESC
LIMIT {{limit}}''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
        'limit': {'type': 'integer', 'required': false, 'default': 10},
      },
      sampleQuestions: ['Top 10 debtors by amount', 'Show top 10 debtors'],
    ),
    // 3. Bill wise aging (receivables)
    const QueryTemplate(
      templateId: 'tmpl-receivables-003',
      category: 'receivables',
      intentKeywords: ['aging', 'bill wise', 'overdue', 'pending bills'],
      description: 'Bill-wise receivable aging with aging buckets',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT
  vle.ledger_name as party_name,
  vle.bill_name,
  vle.bill_date,
  SUM(vle.bill_amount) as bill_outstanding,
  CAST(julianday('now') - julianday(
    SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
  ) AS INTEGER) as days_overdue,
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
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND vle.bill_name IS NOT NULL AND vle.bill_name != ''
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vle.ledger_name, vle.bill_name, vle.bill_date
HAVING bill_outstanding > 0.01
ORDER BY days_overdue DESC, vle.ledger_name''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Bill wise aging analysis', 'Show me aging analysis'],
    ),
    // 4. Overdue above 90 days
    const QueryTemplate(
      templateId: 'tmpl-receivables-004',
      category: 'receivables',
      intentKeywords: ['overdue 90', 'long overdue', 'oldest bills'],
      description: 'Overdue receivables above 90 days',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND (name = 'Sundry Debtors' OR reserved_name = 'Sundry Debtors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT
  vle.ledger_name as party_name,
  vle.bill_name,
  vle.bill_date,
  SUM(vle.bill_amount) as bill_outstanding,
  CAST(julianday('now') - julianday(
    SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
  ) AS INTEGER) as days_overdue
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND vle.bill_name IS NOT NULL AND vle.bill_name != ''
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vle.ledger_name, vle.bill_name, vle.bill_date
HAVING bill_outstanding > 0.01
  AND CAST(julianday('now') - julianday(
    SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
  ) AS INTEGER) > 90
ORDER BY days_overdue DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Overdue receivables above 90 days', 'Long overdue debtors'],
    ),
  ];

  // ─── Payables ───

  static final _payablesTemplates = [
    // 1. All outstanding payables
    const QueryTemplate(
      templateId: 'tmpl-payables-001',
      category: 'payables',
      intentKeywords: ['payable', 'creditor', 'owe', 'supplier balance'],
      description: 'Outstanding payables to Sundry Creditors',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}'
    AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
base_data AS (
  SELECT l.name as party_name, l.parent as group_name, l.opening_balance as ledger_opening_balance,
    COALESCE(SUM(CASE WHEN v.date < '{{from_date}}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
    COALESCE(SUM(CASE WHEN v.date < '{{from_date}}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
    COALESCE(SUM(CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
    COALESCE(SUM(CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
    COUNT(DISTINCT CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' THEN v.voucher_guid ELSE NULL END) as transaction_count
  FROM ledgers l
  INNER JOIN group_tree gt ON l.parent = gt.name
  LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
  LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
  GROUP BY l.name, l.parent, l.opening_balance
)
SELECT party_name, group_name,
  (ledger_opening_balance + credit_before - debit_before) as opening_balance,
  credit_total, debit_total,
  (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding,
  transaction_count
FROM base_data
WHERE (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
ORDER BY outstanding DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['All outstanding payables', 'What do I owe to suppliers?'],
    ),
    // 2. Top 10 creditors
    const QueryTemplate(
      templateId: 'tmpl-payables-002',
      category: 'payables',
      intentKeywords: ['top creditor', 'biggest creditor'],
      description: 'Top N creditors by outstanding',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}'
    AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
base_data AS (
  SELECT l.name as party_name, l.opening_balance as ledger_opening_balance,
    COALESCE(SUM(CASE WHEN v.date < '{{from_date}}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_before,
    COALESCE(SUM(CASE WHEN v.date < '{{from_date}}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_before,
    COALESCE(SUM(CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
    COALESCE(SUM(CASE WHEN v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total
  FROM ledgers l
  INNER JOIN group_tree gt ON l.parent = gt.name
  LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
  LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    AND v.company_guid = l.company_guid AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
  GROUP BY l.name, l.opening_balance
)
SELECT party_name,
  (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) as outstanding
FROM base_data
WHERE (ledger_opening_balance + credit_before - debit_before + credit_total - debit_total) > 0.01
ORDER BY outstanding DESC
LIMIT {{limit}}''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
        'limit': {'type': 'integer', 'required': false, 'default': 10},
      },
      sampleQuestions: ['Top 10 creditors by amount', 'Show top 10 creditors'],
    ),
    // 3. Bill wise payable aging
    const QueryTemplate(
      templateId: 'tmpl-payables-003',
      category: 'payables',
      intentKeywords: ['payable aging', 'creditor aging', 'bill wise payable'],
      description: 'Bill-wise payable aging with aging buckets',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT
  vle.ledger_name as party_name,
  vle.bill_name,
  vle.bill_date,
  SUM(vle.bill_amount) as bill_outstanding,
  CAST(julianday('now') - julianday(
    SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
  ) AS INTEGER) as days_overdue,
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
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND vle.bill_name IS NOT NULL AND vle.bill_name != ''
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vle.ledger_name, vle.bill_name, vle.bill_date
HAVING bill_outstanding < -0.01
ORDER BY days_overdue DESC, vle.ledger_name''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Bill wise payable aging'],
    ),
    // 4. Overdue payables above 90 days
    const QueryTemplate(
      templateId: 'tmpl-payables-004',
      category: 'payables',
      intentKeywords: ['overdue payables 90', 'long overdue payables'],
      description: 'Overdue payables above 90 days',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND (name = 'Sundry Creditors' OR reserved_name = 'Sundry Creditors') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT
  vle.ledger_name as party_name,
  vle.bill_name,
  vle.bill_date,
  SUM(vle.bill_amount) as bill_outstanding,
  CAST(julianday('now') - julianday(
    SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
  ) AS INTEGER) as days_overdue
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND vle.bill_name IS NOT NULL AND vle.bill_name != ''
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vle.ledger_name, vle.bill_name, vle.bill_date
HAVING bill_outstanding < -0.01
  AND CAST(julianday('now') - julianday(
    SUBSTR(vle.bill_date, 1, 4) || '-' || SUBSTR(vle.bill_date, 5, 2) || '-' || SUBSTR(vle.bill_date, 7, 2)
  ) AS INTEGER) > 90
ORDER BY days_overdue DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Overdue payables above 90 days', 'Long overdue creditors'],
    ),
  ];

  // ─── Stock ───

  static final _stockTemplates = [
    // 1. Closing stock summary (all items)
    const QueryTemplate(
      templateId: 'tmpl-stock-001',
      category: 'stock',
      intentKeywords: ['stock', 'inventory', 'closing stock', 'stock value', 'stock summary'],
      description: 'Stock summary with pre-calculated closing values',
      sqlTemplate: '''SELECT
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
  SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{{company_guid}}'
) active ON active.stock_item_guid = si.stock_item_guid
LEFT JOIN stock_item_closing_balance cb
  ON cb.stock_item_guid = si.stock_item_guid
  AND cb.company_guid = '{{company_guid}}'
  AND cb.closing_date = (
    SELECT MAX(closing_date) FROM stock_item_closing_balance
    WHERE company_guid = '{{company_guid}}' AND closing_date <= '{{to_date}}'
  )
WHERE si.company_guid = '{{company_guid}}'
  AND si.is_deleted = 0
ORDER BY si.parent, si.name''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Closing stock summary', 'Show me stock summary'],
    ),
    // 2. Top 10 stock items by value
    const QueryTemplate(
      templateId: 'tmpl-stock-002',
      category: 'stock',
      intentKeywords: ['top stock', 'highest stock', 'most valuable stock'],
      description: 'Top N stock items by closing value',
      sqlTemplate: '''SELECT
  si.name as item_name,
  COALESCE(si.parent, '') as stock_group,
  COALESCE(si.base_units, '') as unit,
  COALESCE(cb.closing_balance, 0.0) as closing_qty,
  COALESCE(cb.closing_value, 0.0) as closing_value,
  COALESCE(cb.closing_rate, 0.0) as closing_rate
FROM stock_items si
INNER JOIN (
  SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
  UNION
  SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{{company_guid}}'
) active ON active.stock_item_guid = si.stock_item_guid
LEFT JOIN stock_item_closing_balance cb
  ON cb.stock_item_guid = si.stock_item_guid
  AND cb.company_guid = '{{company_guid}}'
  AND cb.closing_date = (
    SELECT MAX(closing_date) FROM stock_item_closing_balance
    WHERE company_guid = '{{company_guid}}' AND closing_date <= '{{to_date}}'
  )
WHERE si.company_guid = '{{company_guid}}'
  AND si.is_deleted = 0
  AND COALESCE(cb.closing_value, 0.0) > 0
ORDER BY cb.closing_value DESC
LIMIT {{limit}}''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
        'limit': {'type': 'integer', 'required': false, 'default': 10},
      },
      sampleQuestions: ['Top 10 stock items by value', 'Most valuable stock items'],
    ),
    // 3. Zero / out of stock items
    const QueryTemplate(
      templateId: 'tmpl-stock-003',
      category: 'stock',
      intentKeywords: ['low stock', 'out of stock', 'zero stock'],
      description: 'Zero or out of stock items',
      sqlTemplate: '''SELECT
  si.name as item_name,
  COALESCE(si.parent, '') as stock_group,
  COALESCE(si.base_units, '') as unit,
  COALESCE(cb.closing_balance, 0.0) as closing_qty,
  COALESCE(cb.closing_value, 0.0) as closing_value
FROM stock_items si
INNER JOIN (
  SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
  UNION
  SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{{company_guid}}'
) active ON active.stock_item_guid = si.stock_item_guid
LEFT JOIN stock_item_closing_balance cb
  ON cb.stock_item_guid = si.stock_item_guid
  AND cb.company_guid = '{{company_guid}}'
  AND cb.closing_date = (
    SELECT MAX(closing_date) FROM stock_item_closing_balance
    WHERE company_guid = '{{company_guid}}' AND closing_date <= '{{to_date}}'
  )
WHERE si.company_guid = '{{company_guid}}'
  AND si.is_deleted = 0
  AND COALESCE(cb.closing_balance, 0.0) <= 0
ORDER BY si.name''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Zero or out of stock items', 'Items with no stock'],
    ),
    // 4. Stock group wise summary
    const QueryTemplate(
      templateId: 'tmpl-stock-004',
      category: 'stock',
      intentKeywords: ['stock group', 'category wise stock', 'group wise stock'],
      description: 'Stock summary grouped by stock group',
      sqlTemplate: '''SELECT
  COALESCE(si.parent, 'Ungrouped') as stock_group,
  COUNT(*) as item_count,
  SUM(COALESCE(cb.closing_balance, 0.0)) as total_qty,
  SUM(COALESCE(cb.closing_value, 0.0)) as total_value
FROM stock_items si
INNER JOIN (
  SELECT DISTINCT stock_item_guid FROM stock_item_batch_allocation
  UNION
  SELECT DISTINCT stock_item_guid FROM voucher_inventory_entries WHERE company_guid = '{{company_guid}}'
) active ON active.stock_item_guid = si.stock_item_guid
LEFT JOIN stock_item_closing_balance cb
  ON cb.stock_item_guid = si.stock_item_guid
  AND cb.company_guid = '{{company_guid}}'
  AND cb.closing_date = (
    SELECT MAX(closing_date) FROM stock_item_closing_balance
    WHERE company_guid = '{{company_guid}}' AND closing_date <= '{{to_date}}'
  )
WHERE si.company_guid = '{{company_guid}}'
  AND si.is_deleted = 0
GROUP BY si.parent
ORDER BY total_value DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Stock group wise summary', 'Show inventory by category'],
    ),
  ];

  // ─── Expenses ───

  static final _expensesTemplates = [
    // 1. Top 10 expense ledgers (direct + indirect combined)
    const QueryTemplate(
      templateId: 'tmpl-expenses-001',
      category: 'expenses',
      intentKeywords: ['top expense', 'expense category', 'biggest expense'],
      description: 'Top N expense ledgers (direct + indirect combined)',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND name IN ('Direct Expenses', 'Indirect Expenses') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT vle.ledger_name,
  (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
   SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vle.ledger_name
HAVING net_amount > 0
ORDER BY net_amount DESC
LIMIT {{limit}}''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
        'limit': {'type': 'integer', 'required': false, 'default': 10},
      },
      sampleQuestions: ['Top 10 expense ledgers', 'What are my top 5 expense categories?'],
    ),
    // 2. Direct expenses breakdown
    const QueryTemplate(
      templateId: 'tmpl-expenses-002',
      category: 'expenses',
      intentKeywords: ['direct expense', 'cost of goods', 'manufacturing expense'],
      description: 'Direct expenses breakdown by ledger',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND name = 'Direct Expenses' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT vle.ledger_name,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
  (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
   SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vle.ledger_name ORDER BY net_amount DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Direct expenses breakdown', 'Show direct expenses breakdown'],
    ),
    // 3. Indirect expenses breakdown
    const QueryTemplate(
      templateId: 'tmpl-expenses-003',
      category: 'expenses',
      intentKeywords: ['indirect expense', 'overhead', 'operating expense'],
      description: 'Indirect expenses breakdown by ledger',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND name = 'Indirect Expenses' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT vle.ledger_name,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_total,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
  (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
   SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vle.ledger_name ORDER BY net_amount DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Indirect expenses breakdown', 'Show indirect expenses breakdown', 'What are my operating expenses?'],
    ),
    // 4. Month wise expense trend
    const QueryTemplate(
      templateId: 'tmpl-expenses-004',
      category: 'expenses',
      intentKeywords: ['month wise expense', 'monthly expense', 'expense trend'],
      description: 'Monthly expense breakdown (direct + indirect)',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND name IN ('Direct Expenses', 'Indirect Expenses') AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT
  SUBSTR(v.date, 1, 6) as month_yyyymm,
  CASE SUBSTR(v.date, 5, 2)
    WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
    WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
    WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
    WHEN '10' THEN 'October' WHEN '11' THEN 'November' WHEN '12' THEN 'December'
  END || ' ' || SUBSTR(v.date, 1, 4) as month_name,
  (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
   SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_expense,
  COUNT(DISTINCT v.voucher_guid) as vouchers
FROM voucher_ledger_entries vle
INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY SUBSTR(v.date, 1, 6)
ORDER BY month_yyyymm ASC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Month wise expense trend', 'Monthly expenses'],
    ),
  ];

  // ─── Profit & Loss ───

  static final _profitLossTemplates = [
    // 1. Full P&L (sales - purchase = gross profit)
    const QueryTemplate(
      templateId: 'tmpl-pl-001',
      category: 'profit_loss',
      intentKeywords: ['profit', 'loss', 'p&l', 'net profit', 'gross profit'],
      description: 'Full P&L with sales, purchase, expenses, and profit calculation',
      sqlTemplate: '''WITH RECURSIVE
sales_groups AS (
  SELECT group_guid, name FROM groups WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL SELECT g.group_guid, g.name FROM groups g INNER JOIN sales_groups sg ON g.parent_guid = sg.group_guid WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
purchase_groups AS (
  SELECT group_guid, name FROM groups WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL SELECT g.group_guid, g.name FROM groups g INNER JOIN purchase_groups pg ON g.parent_guid = pg.group_guid WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
sales_total AS (
  SELECT COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as net_sales
  FROM voucher_ledger_entries vle
  INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
  INNER JOIN sales_groups sg ON l.parent = sg.name
  WHERE v.company_guid = '{{company_guid}}' AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
),
purchase_total AS (
  SELECT COALESCE(SUM(net_amount), 0) as net_purchase FROM (
    SELECT (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
            SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
    FROM vouchers v
    INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
    INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
    INNER JOIN purchase_groups pg ON l.parent = pg.name
    WHERE v.company_guid = '{{company_guid}}' AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
    GROUP BY v.voucher_guid
  )
)
SELECT
  (SELECT net_sales FROM sales_total) as net_sales,
  (SELECT net_purchase FROM purchase_total) as net_purchase,
  (SELECT net_sales FROM sales_total) - (SELECT net_purchase FROM purchase_total) as gross_profit''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: [
        'Show full P&L statement',
        'Show profit & loss statement',
        'What is my net profit this year?',
      ],
    ),
    // 2. Gross profit
    const QueryTemplate(
      templateId: 'tmpl-pl-002',
      category: 'profit_loss',
      intentKeywords: ['gross profit only'],
      description: 'Gross profit calculation',
      sqlTemplate: '''WITH RECURSIVE
sales_groups AS (
  SELECT group_guid, name FROM groups WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL SELECT g.group_guid, g.name FROM groups g INNER JOIN sales_groups sg ON g.parent_guid = sg.group_guid WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
purchase_groups AS (
  SELECT group_guid, name FROM groups WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL SELECT g.group_guid, g.name FROM groups g INNER JOIN purchase_groups pg ON g.parent_guid = pg.group_guid WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
sales_total AS (
  SELECT COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as net_sales
  FROM voucher_ledger_entries vle INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
  INNER JOIN sales_groups sg ON l.parent = sg.name
  WHERE v.company_guid = '{{company_guid}}' AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
),
purchase_total AS (
  SELECT COALESCE(SUM(net_amount), 0) as net_purchase FROM (
    SELECT (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
            SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
    FROM vouchers v INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
    INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
    INNER JOIN purchase_groups pg ON l.parent = pg.name
    WHERE v.company_guid = '{{company_guid}}' AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
    GROUP BY v.voucher_guid
  )
)
SELECT
  (SELECT net_sales FROM sales_total) as net_sales,
  (SELECT net_purchase FROM purchase_total) as net_purchase,
  (SELECT net_sales FROM sales_total) - (SELECT net_purchase FROM purchase_total) as gross_profit''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['What is my gross profit?'],
    ),
  ];

  // ─── Trial Balance ───

  static final _trialBalanceTemplates = [
    const QueryTemplate(
      templateId: 'tmpl-tb-001',
      category: 'trial_balance',
      intentKeywords: ['trial balance', 'all ledgers', 'ledger balances'],
      description: 'Trial balance with all ledger balances',
      sqlTemplate: '''SELECT l.name as ledger_name, l.parent as group_name, l.opening_balance,
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
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
WHERE l.company_guid = '{{company_guid}}'
  AND l.is_deleted = 0
GROUP BY l.name, l.parent, l.opening_balance
ORDER BY l.parent, l.name''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Show trial balance', 'Show all ledger balances'],
    ),
    // Voucher type summary
    const QueryTemplate(
      templateId: 'tmpl-tb-002',
      category: 'trial_balance',
      intentKeywords: ['voucher type', 'voucher summary', 'transaction count'],
      description: 'Voucher type summary with counts and totals',
      sqlTemplate: '''SELECT
  v.voucher_type,
  COUNT(DISTINCT v.voucher_guid) as voucher_count,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as total_debit,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as total_credit
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY v.voucher_type
ORDER BY voucher_count DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Voucher type summary', 'How many vouchers by type'],
    ),
    // Day book - recent transactions
    const QueryTemplate(
      templateId: 'tmpl-tb-003',
      category: 'trial_balance',
      intentKeywords: ['day book', 'recent transactions', 'all vouchers'],
      description: 'Day book - recent transactions',
      sqlTemplate: '''SELECT
  v.date,
  v.voucher_type,
  v.voucher_number,
  v.party_ledger_name,
  v.narration,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as debit_amount,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_amount
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{{company_guid}}'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY v.voucher_guid, v.date, v.voucher_type, v.voucher_number, v.party_ledger_name, v.narration
ORDER BY v.date DESC, v.voucher_type, v.voucher_number DESC
LIMIT 50''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Day book - recent transactions', 'Show all transactions'],
    ),
  ];

  // ─── Balance Sheet ───

  static final _balanceSheetTemplates = [
    // 1. Full balance sheet
    const QueryTemplate(
      templateId: 'tmpl-bs-001',
      category: 'balance_sheet',
      intentKeywords: ['balance sheet', 'assets', 'liabilities', 'equity', 'net worth'],
      description: 'Balance sheet with assets, liabilities, and equity',
      sqlTemplate: '''SELECT g.name as group_name, g.reserved_name,
  SUM(l.closing_balance) as total_balance
FROM ledgers l
INNER JOIN groups g ON l.parent = g.name AND g.company_guid = l.company_guid
WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0 AND g.is_deleted = 0
  AND g.reserved_name IN ('Current Assets', 'Fixed Assets', 'Current Liabilities', 'Capital Account', 'Investments', 'Loans (Liability)', 'Secured Loans', 'Unsecured Loans')
GROUP BY g.name, g.reserved_name
ORDER BY g.reserved_name''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
      },
      sampleQuestions: ['Show balance sheet', 'What is my net worth?'],
    ),
    // 2. Current assets breakdown
    const QueryTemplate(
      templateId: 'tmpl-bs-002',
      category: 'balance_sheet',
      intentKeywords: ['current assets'],
      description: 'Current assets ledger breakdown',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Current Assets' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT l.name as ledger_name, l.parent as group_name, l.closing_balance
FROM ledgers l
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
  AND l.closing_balance != 0
ORDER BY ABS(l.closing_balance) DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
      },
      sampleQuestions: ['Current assets breakdown'],
    ),
    // 3. Fixed assets breakdown
    const QueryTemplate(
      templateId: 'tmpl-bs-003',
      category: 'balance_sheet',
      intentKeywords: ['fixed assets'],
      description: 'Fixed assets ledger breakdown',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Fixed Assets' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT l.name as ledger_name, l.parent as group_name, l.closing_balance
FROM ledgers l
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
  AND l.closing_balance != 0
ORDER BY ABS(l.closing_balance) DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
      },
      sampleQuestions: ['Fixed assets breakdown'],
    ),
    // 4. Capital account details
    const QueryTemplate(
      templateId: 'tmpl-bs-004',
      category: 'balance_sheet',
      intentKeywords: ['capital account', 'equity', 'owners equity'],
      description: 'Capital account ledger breakdown',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Capital Account' AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT l.name as ledger_name, l.parent as group_name, l.opening_balance, l.closing_balance
FROM ledgers l
INNER JOIN group_tree gt ON l.parent = gt.name
WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
ORDER BY ABS(l.closing_balance) DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
      },
      sampleQuestions: ['Capital account details'],
    ),
  ];

  // ─── Cashflow ───

  static final _cashflowTemplates = [
    // 1. Total receipts and payments (FIXED: uses vle.amount, not v.amount)
    const QueryTemplate(
      templateId: 'tmpl-cf-001',
      category: 'cashflow',
      intentKeywords: ['cash flow', 'receipts and payments', 'cash inflow', 'cash outflow'],
      description: 'Cash flow - total receipts vs payments',
      sqlTemplate: '''SELECT
  COALESCE(SUM(CASE WHEN v.voucher_type = 'Receipt' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total_receipts,
  COALESCE(SUM(CASE WHEN v.voucher_type = 'Payment' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as total_payments,
  COALESCE(SUM(CASE WHEN v.voucher_type = 'Receipt' AND vle.amount > 0 THEN vle.amount ELSE 0 END), 0) -
  COALESCE(SUM(CASE WHEN v.voucher_type = 'Payment' AND vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as net_cash_flow
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type IN ('Receipt', 'Payment')
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' ''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Total receipts and payments', 'Show me cash flow'],
    ),
    // 2. Recent payment vouchers
    const QueryTemplate(
      templateId: 'tmpl-cf-002',
      category: 'cashflow',
      intentKeywords: ['payment voucher', 'money paid', 'cash outflow list'],
      description: 'Recent payment vouchers',
      sqlTemplate: '''SELECT
  v.date,
  v.voucher_number,
  v.narration,
  SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as amount,
  GROUP_CONCAT(DISTINCT CASE WHEN vle.amount > 0 THEN vle.ledger_name ELSE NULL END) as paid_to
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type = 'Payment'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
ORDER BY v.date DESC, v.voucher_number DESC
LIMIT 50''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Recent payment vouchers', 'Show payment list'],
    ),
    // 3. Recent receipt vouchers
    const QueryTemplate(
      templateId: 'tmpl-cf-003',
      category: 'cashflow',
      intentKeywords: ['receipt voucher', 'money received', 'cash inflow list'],
      description: 'Recent receipt vouchers',
      sqlTemplate: '''SELECT
  v.date,
  v.voucher_number,
  v.narration,
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as amount,
  GROUP_CONCAT(DISTINCT CASE WHEN vle.amount < 0 THEN vle.ledger_name ELSE NULL END) as received_from
FROM vouchers v
INNER JOIN voucher_ledger_entries vle ON v.voucher_guid = vle.voucher_guid
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type = 'Receipt'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY v.voucher_guid, v.date, v.voucher_number, v.narration
ORDER BY v.date DESC, v.voucher_number DESC
LIMIT 50''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Recent receipt vouchers', 'Show receipt list'],
    ),
  ];

  // ─── GST ───

  static final _gstTemplates = [
    // 1. GST on sales - HSN wise
    const QueryTemplate(
      templateId: 'tmpl-gst-001',
      category: 'gst',
      intentKeywords: ['gst sales', 'output gst', 'hsn sales'],
      description: 'GST on sales - HSN wise with CGST/SGST/IGST',
      sqlTemplate: '''SELECT
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
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type = 'Sales'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vie.hsn_code, vie.stock_item_name
ORDER BY taxable_value DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['GST on sales - HSN wise', 'Output GST summary'],
    ),
    // 2. GST on purchases - HSN wise
    const QueryTemplate(
      templateId: 'tmpl-gst-002',
      category: 'gst',
      intentKeywords: ['gst purchase', 'input gst', 'hsn purchase'],
      description: 'GST on purchases - HSN wise with CGST/SGST/IGST',
      sqlTemplate: '''SELECT
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
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type = 'Purchase'
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vie.hsn_code, vie.stock_item_name
ORDER BY taxable_value DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['GST on purchases - HSN wise', 'Input GST summary'],
    ),
    // 3. Duties & Taxes summary (all tax ledgers)
    const QueryTemplate(
      templateId: 'tmpl-gst-003',
      category: 'gst',
      intentKeywords: ['duties taxes', 'tax ledger', 'gst liability', 'tds'],
      description: 'Duties & Taxes group ledger summary',
      sqlTemplate: '''WITH RECURSIVE tax_groups AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}' AND is_deleted = 0
    AND (name = 'Duties & Taxes' OR reserved_name = 'Duties & Taxes')
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN tax_groups tg ON g.parent_guid = tg.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
)
SELECT l.name as ledger_name,
  COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
  COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
  COUNT(DISTINCT v.voucher_guid) as txn_count
FROM ledgers l
INNER JOIN tax_groups tg ON l.parent = tg.name
LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  AND v.company_guid = l.company_guid
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
GROUP BY l.name HAVING txn_count > 0
ORDER BY debit_total DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Duties and taxes summary', 'What is my GST liability?'],
    ),
    // 4. GST ledger wise breakup
    const QueryTemplate(
      templateId: 'tmpl-gst-004',
      category: 'gst',
      intentKeywords: ['gst breakup', 'cgst sgst igst breakup'],
      description: 'HSN-wise GST breakup across sales and purchases',
      sqlTemplate: '''SELECT
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
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type IN ('Sales', 'Purchase')
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
GROUP BY vie.hsn_code, vie.hsn_description, vie.gst_rate
ORDER BY taxable_value DESC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['GST ledger wise breakup', 'HSN summary'],
    ),
  ];

  // ─── Bank / Cash Balance ───

  static final _bankCashTemplates = [
    const QueryTemplate(
      templateId: 'tmpl-bank-001',
      category: 'cashflow',
      intentKeywords: ['bank balance', 'cash position', 'cash balance', 'cash in hand', 'fund position'],
      description: 'Cash and bank balance',
      sqlTemplate: '''WITH RECURSIVE group_tree AS (
  SELECT group_guid, name FROM groups
  WHERE company_guid = '{{company_guid}}'
    AND (name IN ('Cash-in-Hand', 'Bank Accounts', 'Bank OD A/c')
         OR reserved_name IN ('Cash-in-Hand', 'Bank Accounts', 'Bank OD A/c'))
    AND is_deleted = 0
  UNION ALL
  SELECT g.group_guid, g.name FROM groups g
  INNER JOIN group_tree gt ON g.parent_guid = gt.group_guid
  WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
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
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
GROUP BY l.name, l.parent, l.opening_balance
ORDER BY l.parent, l.name''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: [
        'Cash and bank balance',
        'Show bank balance',
        'What is my cash position?',
      ],
    ),
  ];

  // ─── Combo / Cross-category templates ───

  static final _comboTemplates = [
    // Sales vs Expenses month on month
    const QueryTemplate(
      templateId: 'tmpl-combo-001',
      category: 'combo',
      intentKeywords: ['sales vs expense', 'expense vs sales', 'monthly sales vs expense'],
      description: 'Month wise sales vs expenses comparison',
      sqlTemplate: '''WITH RECURSIVE
sales_groups AS (
  SELECT group_guid, name FROM groups WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL SELECT g.group_guid, g.name FROM groups g INNER JOIN sales_groups sg ON g.parent_guid = sg.group_guid WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
expense_groups AS (
  SELECT group_guid, name FROM groups WHERE company_guid = '{{company_guid}}' AND name IN ('Direct Expenses', 'Indirect Expenses') AND is_deleted = 0
  UNION ALL SELECT g.group_guid, g.name FROM groups g INNER JOIN expense_groups eg ON g.parent_guid = eg.group_guid WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
monthly_sales AS (
  SELECT SUBSTR(v.date, 1, 6) as m,
    (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales
  FROM voucher_ledger_entries vle INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
  INNER JOIN sales_groups sg ON l.parent = sg.name
  WHERE v.company_guid = '{{company_guid}}' AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
  GROUP BY SUBSTR(v.date, 1, 6)
),
monthly_expense AS (
  SELECT SUBSTR(v.date, 1, 6) as m,
    (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) - SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_expense
  FROM voucher_ledger_entries vle INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
  INNER JOIN expense_groups eg ON l.parent = eg.name
  WHERE v.company_guid = '{{company_guid}}' AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
  GROUP BY SUBSTR(v.date, 1, 6)
)
SELECT
  COALESCE(s.m, e.m) as month_yyyymm,
  CASE SUBSTR(COALESCE(s.m, e.m), 5, 2)
    WHEN '01' THEN 'Jan' WHEN '02' THEN 'Feb' WHEN '03' THEN 'Mar'
    WHEN '04' THEN 'Apr' WHEN '05' THEN 'May' WHEN '06' THEN 'Jun'
    WHEN '07' THEN 'Jul' WHEN '08' THEN 'Aug' WHEN '09' THEN 'Sep'
    WHEN '10' THEN 'Oct' WHEN '11' THEN 'Nov' WHEN '12' THEN 'Dec'
  END || ' ' || SUBSTR(COALESCE(s.m, e.m), 3, 2) as month_name,
  COALESCE(s.net_sales, 0) as net_sales,
  COALESCE(e.net_expense, 0) as net_expense,
  COALESCE(s.net_sales, 0) - COALESCE(e.net_expense, 0) as net_margin
FROM monthly_sales s
LEFT JOIN monthly_expense e ON s.m = e.m
UNION ALL
SELECT e.m, CASE SUBSTR(e.m, 5, 2)
    WHEN '01' THEN 'Jan' WHEN '02' THEN 'Feb' WHEN '03' THEN 'Mar'
    WHEN '04' THEN 'Apr' WHEN '05' THEN 'May' WHEN '06' THEN 'Jun'
    WHEN '07' THEN 'Jul' WHEN '08' THEN 'Aug' WHEN '09' THEN 'Sep'
    WHEN '10' THEN 'Oct' WHEN '11' THEN 'Nov' WHEN '12' THEN 'Dec'
  END || ' ' || SUBSTR(e.m, 3, 2), 0, e.net_expense, 0 - e.net_expense
FROM monthly_expense e WHERE e.m NOT IN (SELECT m FROM monthly_sales)
ORDER BY month_yyyymm ASC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Month wise sales vs expenses'],
    ),
    // Sales vs Purchase month on month
    const QueryTemplate(
      templateId: 'tmpl-combo-002',
      category: 'combo',
      intentKeywords: ['sales vs purchase', 'purchase vs sales', 'monthly sales vs purchase'],
      description: 'Month wise sales vs purchase comparison',
      sqlTemplate: '''WITH RECURSIVE
sales_groups AS (
  SELECT group_guid, name FROM groups WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Sales Accounts' AND is_deleted = 0
  UNION ALL SELECT g.group_guid, g.name FROM groups g INNER JOIN sales_groups sg ON g.parent_guid = sg.group_guid WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
purchase_groups AS (
  SELECT group_guid, name FROM groups WHERE company_guid = '{{company_guid}}' AND reserved_name = 'Purchase Accounts' AND is_deleted = 0
  UNION ALL SELECT g.group_guid, g.name FROM groups g INNER JOIN purchase_groups pg ON g.parent_guid = pg.group_guid WHERE g.company_guid = '{{company_guid}}' AND g.is_deleted = 0
),
monthly_sales AS (
  SELECT SUBSTR(v.date, 1, 6) as m,
    (SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) - SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END)) as net_sales
  FROM voucher_ledger_entries vle INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
  INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
  INNER JOIN sales_groups sg ON l.parent = sg.name
  WHERE v.company_guid = '{{company_guid}}' AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
  GROUP BY SUBSTR(v.date, 1, 6)
),
monthly_purchase AS (
  SELECT SUBSTR(v.date, 1, 6) as m,
    COALESCE(SUM(net_amount), 0) as net_purchase FROM (
      SELECT v.date, (SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) -
       SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END)) as net_amount
      FROM vouchers v INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = v.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN purchase_groups pg ON l.parent = pg.name
      WHERE v.company_guid = '{{company_guid}}' AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}'
      GROUP BY v.voucher_guid
    ) GROUP BY SUBSTR(date, 1, 6)
)
SELECT s.m as month_yyyymm,
  CASE SUBSTR(s.m, 5, 2)
    WHEN '01' THEN 'Jan' WHEN '02' THEN 'Feb' WHEN '03' THEN 'Mar'
    WHEN '04' THEN 'Apr' WHEN '05' THEN 'May' WHEN '06' THEN 'Jun'
    WHEN '07' THEN 'Jul' WHEN '08' THEN 'Aug' WHEN '09' THEN 'Sep'
    WHEN '10' THEN 'Oct' WHEN '11' THEN 'Nov' WHEN '12' THEN 'Dec'
  END || ' ' || SUBSTR(s.m, 3, 2) as month_name,
  COALESCE(s.net_sales, 0) as net_sales,
  COALESCE(p.net_purchase, 0) as net_purchase,
  COALESCE(s.net_sales, 0) - COALESCE(p.net_purchase, 0) as gross_margin
FROM monthly_sales s
LEFT JOIN monthly_purchase p ON s.m = p.m
ORDER BY month_yyyymm ASC''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: ['Month wise sales vs purchase'],
    ),
  ];

  /// Related questions mapping — shown after a query result
  static const Map<String, List<String>> relatedQuestions = {
    // Sales
    'Total sales this year': ['Top 10 customers by sales', 'Month wise sales breakdown', 'Month wise sales vs purchase', 'Show full P&L statement'],
    'Top 10 customers by sales': ['Total sales this year', 'All outstanding receivables', 'Item wise sales summary'],
    'Month wise sales breakdown': ['Month wise purchase breakdown', 'Month wise sales vs expenses', 'Month wise expense trend'],
    'Item wise sales summary': ['GST on sales - HSN wise', 'Top 10 customers by sales', 'Item wise purchase summary'],
    // Purchase
    'Total purchases this year': ['Top 10 suppliers by purchase', 'Month wise purchase breakdown', 'Show full P&L statement'],
    'Top 10 suppliers by purchase': ['Total purchases this year', 'All outstanding payables', 'Item wise purchase summary'],
    'Month wise purchase breakdown': ['Month wise sales breakdown', 'Month wise sales vs purchase', 'Month wise expense trend'],
    'Item wise purchase summary': ['GST on purchases - HSN wise', 'Top 10 suppliers by purchase', 'Item wise sales summary'],
    // P&L
    'Show full P&L statement': ['Direct expenses breakdown', 'Indirect expenses breakdown', 'Month wise sales vs expenses', 'Total sales this year'],
    'What is my gross profit?': ['Show full P&L statement', 'Month wise sales vs purchase', 'Direct expenses breakdown'],
    'Direct expenses breakdown': ['Indirect expenses breakdown', 'Top 10 expense ledgers', 'Show full P&L statement'],
    'Indirect expenses breakdown': ['Direct expenses breakdown', 'Top 10 expense ledgers', 'Month wise expense trend'],
    // Receivables
    'All outstanding receivables': ['Top 10 debtors by amount', 'Bill wise aging analysis', 'Overdue receivables above 90 days'],
    'Top 10 debtors by amount': ['All outstanding receivables', 'Bill wise aging analysis', 'Top 10 customers by sales'],
    'Bill wise aging analysis': ['Overdue receivables above 90 days', 'Top 10 debtors by amount', 'All outstanding receivables'],
    'Overdue receivables above 90 days': ['Bill wise aging analysis', 'All outstanding receivables', 'Total receipts and payments'],
    // Payables
    'All outstanding payables': ['Top 10 creditors by amount', 'Bill wise payable aging', 'Overdue payables above 90 days'],
    'Top 10 creditors by amount': ['All outstanding payables', 'Bill wise payable aging', 'Top 10 suppliers by purchase'],
    'Bill wise payable aging': ['Overdue payables above 90 days', 'Top 10 creditors by amount', 'All outstanding payables'],
    'Overdue payables above 90 days': ['Bill wise payable aging', 'All outstanding payables', 'Total receipts and payments'],
    // Stock
    'Closing stock summary': ['Top 10 stock items by value', 'Stock group wise summary', 'Zero or out of stock items'],
    'Top 10 stock items by value': ['Closing stock summary', 'Stock group wise summary', 'Item wise sales summary'],
    'Zero or out of stock items': ['Closing stock summary', 'Item wise purchase summary', 'Stock group wise summary'],
    'Stock group wise summary': ['Closing stock summary', 'Top 10 stock items by value', 'Zero or out of stock items'],
    // Expenses
    'Top 10 expense ledgers': ['Direct expenses breakdown', 'Indirect expenses breakdown', 'Month wise expense trend'],
    'Month wise expense trend': ['Month wise sales vs expenses', 'Top 10 expense ledgers', 'Show full P&L statement'],
    // Cash Flow
    'Total receipts and payments': ['Cash and bank balance', 'Recent payment vouchers', 'Recent receipt vouchers'],
    'Cash and bank balance': ['Total receipts and payments', 'Show balance sheet', 'Recent payment vouchers'],
    'Recent payment vouchers': ['Recent receipt vouchers', 'Total receipts and payments', 'All outstanding payables'],
    'Recent receipt vouchers': ['Recent payment vouchers', 'Total receipts and payments', 'All outstanding receivables'],
    // Balance Sheet
    'Show balance sheet': ['Current assets breakdown', 'Fixed assets breakdown', 'Capital account details'],
    'Current assets breakdown': ['Show balance sheet', 'Cash and bank balance', 'All outstanding receivables'],
    'Fixed assets breakdown': ['Show balance sheet', 'Current assets breakdown', 'Capital account details'],
    'Capital account details': ['Show balance sheet', 'Show full P&L statement', 'Fixed assets breakdown'],
    // GST
    'GST on sales - HSN wise': ['GST on purchases - HSN wise', 'Duties and taxes summary', 'Item wise sales summary'],
    'GST on purchases - HSN wise': ['GST on sales - HSN wise', 'Duties and taxes summary', 'Item wise purchase summary'],
    'Duties and taxes summary': ['GST on sales - HSN wise', 'GST on purchases - HSN wise', 'GST ledger wise breakup'],
    'GST ledger wise breakup': ['Duties and taxes summary', 'GST on sales - HSN wise', 'GST on purchases - HSN wise'],
    // Trial Balance
    'Show trial balance': ['Voucher type summary', 'Show balance sheet', 'Show full P&L statement'],
    'Voucher type summary': ['Day book - recent transactions', 'Show trial balance', 'Total receipts and payments'],
    'Day book - recent transactions': ['Voucher type summary', 'Recent payment vouchers', 'Recent receipt vouchers'],
    // Combos
    'Month wise sales vs expenses': ['Month wise sales breakdown', 'Month wise expense trend', 'Show full P&L statement'],
    'Month wise sales vs purchase': ['Month wise sales breakdown', 'Month wise purchase breakdown', 'What is my gross profit?'],
  };
}
