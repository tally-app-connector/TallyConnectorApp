import 'package:flutter/material.dart';

/// Metric Configuration Model
/// Defines metadata for each metric category (icon, color, preset questions)
class MetricConfig {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> presetQuestions;
  final String description;

  const MetricConfig({
    required this.name,
    required this.icon,
    required this.color,
    required this.presetQuestions,
    required this.description,
  });

  /// All available metrics
  static final List<MetricConfig> allMetrics = [
    const MetricConfig(
      name: 'Sales',
      icon: Icons.trending_up,
      color: Colors.green,
      description: 'Sales and revenue analysis',
      presetQuestions: [
        'What were my sales last month?',
        'Show me sales for this quarter',
        'What is my total revenue this year?',
        'Compare sales this month vs last month',
        'Show me top 5 customers by sales',
      ],
    ),
    const MetricConfig(
      name: 'Purchase',
      icon: Icons.shopping_cart,
      color: Colors.orange,
      description: 'Purchase and procurement analysis',
      presetQuestions: [
        'What were my purchases last month?',
        'Show me purchase summary for this quarter',
        'What did I buy this year?',
        'Show top 5 suppliers by purchase value',
        'Compare purchases with last month',
      ],
    ),
    const MetricConfig(
      name: 'Profit & Loss',
      icon: Icons.assessment,
      color: Colors.blue,
      description: 'P&L statement and profitability',
      presetQuestions: [
        'Show me P&L for this month',
        'What is my gross profit this quarter?',
        'What is my net profit this year?',
        'Show profit & loss statement',
        'What are my operating expenses?',
      ],
    ),
    const MetricConfig(
      name: 'Receivables',
      icon: Icons.call_received,
      color: Colors.teal,
      description: 'Outstanding from customers',
      presetQuestions: [
        'Who owes me money?',
        'Show me total receivables',
        'What is my outstanding from customers?',
        'Show top 10 debtors',
        'Show me aging analysis',
      ],
    ),
    const MetricConfig(
      name: 'Payables',
      icon: Icons.call_made,
      color: Colors.purple,
      description: 'Outstanding to suppliers',
      presetQuestions: [
        'What do I owe to suppliers?',
        'Show me total payables',
        'What is my outstanding to creditors?',
        'Show top 10 creditors',
        'Show payment due dates',
      ],
    ),
    const MetricConfig(
      name: 'Stock',
      icon: Icons.inventory,
      color: Colors.brown,
      description: 'Inventory and stock summary',
      presetQuestions: [
        'What is my closing stock value?',
        'Show me stock summary',
        'What are my top 10 stock items?',
        'Show inventory by category',
        'What items are low in stock?',
      ],
    ),
    const MetricConfig(
      name: 'Expenses',
      icon: Icons.account_balance_wallet,
      color: Colors.red,
      description: 'Direct and indirect expenses',
      presetQuestions: [
        'What were my expenses last month?',
        'Show direct expenses breakdown',
        'Show indirect expenses breakdown',
        'What are my top 5 expense categories?',
        'Compare expenses with last month',
      ],
    ),
    const MetricConfig(
      name: 'Cash Flow',
      icon: Icons.attach_money,
      color: Colors.indigo,
      description: 'Cash receipts and payments',
      presetQuestions: [
        'Show me cash flow for this month',
        'What were my receipts and payments?',
        'Show bank balance',
        'What is my cash position?',
        'Show me cash inflows and outflows',
      ],
    ),
    const MetricConfig(
      name: 'Balance Sheet',
      icon: Icons.balance,
      color: Colors.deepPurple,
      description: 'Assets, liabilities, and equity',
      presetQuestions: [
        'Show me balance sheet',
        'What are my total assets?',
        'What are my total liabilities?',
        'Show balance sheet as of today',
        'What is my net worth?',
      ],
    ),
    const MetricConfig(
      name: 'GST',
      icon: Icons.receipt_long,
      color: Colors.amber,
      description: 'GST reports and tax liability',
      presetQuestions: [
        'Show me GST report for this month',
        'What is my GST liability?',
        'Show GSTR-1 summary',
        'What GST did I pay this quarter?',
        'Show input and output GST',
      ],
    ),
    const MetricConfig(
      name: 'Trial Balance',
      icon: Icons.account_balance,
      color: Colors.cyan,
      description: 'All ledger balances',
      presetQuestions: [
        'Show trial balance',
        'What is my trial balance for this period?',
        'Show all ledger balances',
        'Show trial balance as of today',
      ],
    ),
  ];

  /// Get metric by name
  static MetricConfig? getByName(String name) {
    try {
      return allMetrics.firstWhere(
        (metric) => metric.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}
