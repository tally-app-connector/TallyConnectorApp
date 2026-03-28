import '../models/query_template.dart';

/// All pre-built SQL query templates organized by category.
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
        'What were my sales last month?',
        'Show me total revenue',
        'Show me sales for this quarter',
        'What is my total revenue this year?',
        'What were my sales?',
      ],
    ),
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
  SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as credit_total,
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
      sampleQuestions: ['Top 5 customers by sales', 'Who bought the most?', 'Show me top 5 customers by sales'],
    ),
  ];

  // ─── Purchase ───

  static final _purchaseTemplates = [
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
        'Total purchases this month',
        'How much did we buy?',
        'What were my purchases last month?',
        'Show me purchase summary for this quarter',
        'What did I buy this year?',
      ],
    ),
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
      sampleQuestions: ['Top suppliers', 'Who did we buy the most from?', 'Show top 5 suppliers by purchase value'],
    ),
  ];

  // ─── Receivables ───

  static final _receivablesTemplates = [
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
        'Who owes us money?',
        'Outstanding receivables',
        'Who owes me money?',
        'Show me total receivables',
        'What is my outstanding from customers?',
        'Show top 10 debtors',
      ],
    ),
  ];

  // ─── Payables ───

  static final _payablesTemplates = [
    const QueryTemplate(
      templateId: 'tmpl-payables-001',
      category: 'payables',
      intentKeywords: ['payable', 'creditor', 'owe', 'outstanding', 'supplier balance'],
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
    AND v.company_guid = l.company_guid
    AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
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
      sampleQuestions: [
        'What do we owe?',
        'Outstanding payables',
        'What do I owe to suppliers?',
        'Show me total payables',
        'What is my outstanding to creditors?',
        'Show top 10 creditors',
      ],
    ),
  ];

  // ─── Stock ───

  static final _stockTemplates = [
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
      sampleQuestions: [
        'What is my closing stock value?',
        'Show me stock summary',
        'What are my top 10 stock items?',
        'Show inventory by category',
        'Stock valuation',
      ],
    ),
  ];

  // ─── Expenses ───

  static final _expensesTemplates = [
    const QueryTemplate(
      templateId: 'tmpl-expenses-001',
      category: 'expenses',
      intentKeywords: ['direct expense', 'cost of goods', 'manufacturing expense'],
      description: 'Direct expenses breakdown',
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
      sampleQuestions: [
        'Direct expenses breakdown',
        'Cost of goods',
        'Show direct expenses breakdown',
        'What were my expenses last month?',
      ],
    ),
    const QueryTemplate(
      templateId: 'tmpl-expenses-002',
      category: 'expenses',
      intentKeywords: ['indirect expense', 'overhead', 'operating expense', 'office expense'],
      description: 'Indirect expenses breakdown',
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
      sampleQuestions: [
        'Operating expenses',
        'Indirect expenses',
        'Show indirect expenses breakdown',
        'What are my operating expenses?',
        'What are my top 5 expense categories?',
      ],
    ),
  ];

  // ─── Profit & Loss ───

  static final _profitLossTemplates = [
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
        'Net profit this year',
        'Profit and loss statement',
        'Show me P&L for this month',
        'What is my gross profit this quarter?',
        'What is my net profit this year?',
        'Show profit & loss statement',
      ],
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
WHERE l.company_guid = '{{company_guid}}' AND l.is_deleted = 0
GROUP BY l.name, l.parent, l.opening_balance
ORDER BY l.parent, l.name''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: [
        'Show trial balance',
        'All ledger balances',
        'What is my trial balance for this period?',
        'Show all ledger balances',
        'Show trial balance as of today',
      ],
    ),
  ];

  // ─── Balance Sheet ───

  static final _balanceSheetTemplates = [
    const QueryTemplate(
      templateId: 'tmpl-bs-001',
      category: 'balance_sheet',
      intentKeywords: ['balance sheet', 'assets', 'liabilities', 'equity'],
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
      sampleQuestions: [
        'Show balance sheet',
        'Assets and liabilities',
        'Show me balance sheet',
        'What are my total assets?',
        'What are my total liabilities?',
        'Show balance sheet as of today',
      ],
    ),
  ];

  // ─── Cashflow ───

  static final _cashflowTemplates = [
    const QueryTemplate(
      templateId: 'tmpl-cf-001',
      category: 'cashflow',
      intentKeywords: ['cash flow', 'cash in', 'cash out', 'receipt', 'payment'],
      description: 'Cash flow analysis (receipts and payments)',
      sqlTemplate: '''SELECT
  SUM(CASE WHEN v.voucher_type = 'Receipt' THEN ABS(v.amount) ELSE 0 END) as total_receipts,
  SUM(CASE WHEN v.voucher_type = 'Payment' THEN ABS(v.amount) ELSE 0 END) as total_payments,
  SUM(CASE WHEN v.voucher_type = 'Receipt' THEN ABS(v.amount) ELSE 0 END) -
  SUM(CASE WHEN v.voucher_type = 'Payment' THEN ABS(v.amount) ELSE 0 END) as net_cash_flow
FROM vouchers v
WHERE v.company_guid = '{{company_guid}}'
  AND v.voucher_type IN ('Receipt', 'Payment')
  AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
  AND v.date >= '{{from_date}}' AND v.date <= '{{to_date}}' ''',
      parameterSchema: {
        'company_guid': {'type': 'string', 'required': true},
        'from_date': {'type': 'date_tally', 'required': true},
        'to_date': {'type': 'date_tally', 'required': true},
      },
      sampleQuestions: [
        'Cash flow this month',
        'Receipts vs payments',
        'Show me cash flow for this month',
        'What were my receipts and payments?',
        'Show me cash inflows and outflows',
      ],
    ),
  ];

  // ─── GST ───

  static final _gstTemplates = [
    const QueryTemplate(
      templateId: 'tmpl-gst-001',
      category: 'gst',
      intentKeywords: ['gst', 'tax', 'cgst', 'sgst', 'igst', 'tds'],
      description: 'GST/Tax summary from Duties & Taxes group',
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
      sampleQuestions: [
        'GST summary',
        'Tax liability',
        'TDS total',
        'Show me GST report for this month',
        'What is my GST liability?',
        'What GST did I pay this quarter?',
        'Show input and output GST',
      ],
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
        'Show bank balance',
        'What is my cash position?',
        'Cash in hand balance',
        'Bank balance',
        'Fund position',
      ],
    ),
  ];
}
