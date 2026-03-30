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
        'Total sales this year',
        'Top 10 customers by sales',
        'Month wise sales breakdown',
        'Item wise sales summary',
      ],
    ),
    const MetricConfig(
      name: 'Purchase',
      icon: Icons.shopping_cart,
      color: Colors.orange,
      description: 'Purchase and procurement analysis',
      presetQuestions: [
        'Total purchases this year',
        'Top 10 suppliers by purchase',
        'Month wise purchase breakdown',
        'Item wise purchase summary',
      ],
    ),
    const MetricConfig(
      name: 'Profit & Loss',
      icon: Icons.assessment,
      color: Colors.blue,
      description: 'P&L statement and profitability',
      presetQuestions: [
        'Show full P&L statement',
        'What is my gross profit?',
        'Direct expenses breakdown',
        'Indirect expenses breakdown',
      ],
    ),
    const MetricConfig(
      name: 'Receivables',
      icon: Icons.call_received,
      color: Colors.teal,
      description: 'Outstanding from customers',
      presetQuestions: [
        'All outstanding receivables',
        'Top 10 debtors by amount',
        'Bill wise aging analysis',
        'Overdue receivables above 90 days',
      ],
    ),
    const MetricConfig(
      name: 'Payables',
      icon: Icons.call_made,
      color: Colors.purple,
      description: 'Outstanding to suppliers',
      presetQuestions: [
        'All outstanding payables',
        'Top 10 creditors by amount',
        'Bill wise payable aging',
        'Overdue payables above 90 days',
      ],
    ),
    const MetricConfig(
      name: 'Stock',
      icon: Icons.inventory,
      color: Colors.brown,
      description: 'Inventory and stock summary',
      presetQuestions: [
        'Closing stock summary',
        'Top 10 stock items by value',
        'Zero or out of stock items',
        'Stock group wise summary',
      ],
    ),
    const MetricConfig(
      name: 'Expenses',
      icon: Icons.account_balance_wallet,
      color: Colors.red,
      description: 'Direct and indirect expenses',
      presetQuestions: [
        'Top 10 expense ledgers',
        'Direct expenses breakdown',
        'Indirect expenses breakdown',
        'Month wise expense trend',
      ],
    ),
    const MetricConfig(
      name: 'Cash Flow',
      icon: Icons.attach_money,
      color: Colors.indigo,
      description: 'Cash receipts and payments',
      presetQuestions: [
        'Total receipts and payments',
        'Cash and bank balance',
        'Recent payment vouchers',
        'Recent receipt vouchers',
      ],
    ),
    const MetricConfig(
      name: 'Balance Sheet',
      icon: Icons.balance,
      color: Colors.deepPurple,
      description: 'Assets, liabilities, and equity',
      presetQuestions: [
        'Show balance sheet',
        'Current assets breakdown',
        'Fixed assets breakdown',
        'Capital account details',
      ],
    ),
    const MetricConfig(
      name: 'GST',
      icon: Icons.receipt_long,
      color: Colors.amber,
      description: 'GST reports and tax liability',
      presetQuestions: [
        'GST on sales - HSN wise',
        'GST on purchases - HSN wise',
        'Duties and taxes summary',
        'GST ledger wise breakup',
      ],
    ),
    const MetricConfig(
      name: 'Trial Balance',
      icon: Icons.account_balance,
      color: Colors.cyan,
      description: 'All ledger balances',
      presetQuestions: [
        'Show trial balance',
        'Voucher type summary',
        'Day book - recent transactions',
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
