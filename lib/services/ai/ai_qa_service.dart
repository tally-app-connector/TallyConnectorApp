import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/ai_dependencies.dart';
import '../../database/database_helper.dart';
import '../../models/ai/chat_message.dart';
import '../../models/ai/query_result.dart';
import '../../config/ai_endpoints.dart';
import 'prompt_builder.dart';
import 'entity_extractor.dart';
import 'claude_service.dart';
import 'ai_provider_service.dart';
import 'query_templates.dart';
import 'query_builder.dart';
import 'template_matcher.dart';

/// AI Q&A Service - Handles local AI query generation and execution
class AiQaService {
  static String get _baseUrl => (AiDependencies.apiBaseUrl ?? '').replaceAll('/api', '');

  static final PromptBuilder _promptBuilder = PromptBuilder();
  static final EntityExtractor _entityExtractor = EntityExtractor();

  static final Map<String, Map<String, dynamic>> _summaryCache = {};
  static final Map<String, DateTime> _summaryCacheTimestamp = {};
  static const _summaryCacheDuration = Duration(hours: 24);

  /// Create AI provider service based on provider name
  static dynamic _createProvider(String aiProvider) {
    final hfKey = AiDependencies.huggingFaceApiKey;
    final orKey = AiDependencies.openRouterApiKey;
    final claudeKey = AiDependencies.claudeApiKey;
    final glmKey = AiDependencies.glm5ApiKey;

    switch (aiProvider) {
      case 'claude':
        return ClaudeService(apiKey: claudeKey);
      case 'deepseek': // Kimi K2.5
        return KimiService(apiKey: hfKey);
      case 'llama':
        return LlamaService(apiKey: hfKey);
      case 'qwen':
        return QwenService(apiKey: hfKey);
      case 'openrouter':
        return OpenRouterService(apiKey: orKey);
      case 'qwen3_8b':
        return Qwen3_8BService(apiKey: hfKey);
      case 'qwen3_4b':
        return Qwen3_4BService(apiKey: hfKey);
      case 'glm5':
        return Glm5Service(apiKey: glmKey);
      case 'aws':
        return AwsService();
      default:
        return OpenRouterService(apiKey: orKey);
    }
  }

  /// Send natural language question, generate SQL locally via AI, and execute
  static Future<Map<String, dynamic>> sendQuery({
    required String companyGuid,
    required String userId,
    required String message,
    String? sessionId,
    required String token,
    List<Map<String, dynamic>>? conversationHistory,
    String aiProvider = 'claude',
  }) async {
    try {
      final actualSessionId = sessionId ?? DateTime.now().toString().substring(0, 10);
      debugPrint('[AI DEBUG] Starting local query for provider: $aiProvider');

      // 1. Build company summary snapshot
      final companySummary = await _getOrBuildSummary(companyGuid);
      final companyDataStr = companySummary != null ? jsonEncode(companySummary) : '';

      // 2. Extract entities (dates, amounts, party names) from question
      final entities = _entityExtractor.extract(message);
      final fromDate = entities['from_date'] as String? ?? _defaultFromDate();
      final toDate = entities['to_date'] as String? ?? _defaultToDate();

      // 3. Try local template match first (skip AI API for preset/common questions)
      final localResult = _tryLocalTemplate(
        message: message,
        companyGuid: companyGuid,
        fromDate: fromDate,
        toDate: toDate,
        entities: entities,
      );
      if (localResult != null) {
        debugPrint('[AI DEBUG] Local template matched! Skipping AI API.');
        final queryResult = await _executeLocalQuery(localResult);
        debugPrint('[AI DEBUG] Local query result: ${queryResult.rowCount} rows');

        await _saveChatMessage(
          companyGuid: companyGuid, userId: userId, message: message,
          generatedSql: localResult, resultCount: queryResult.rowCount,
          sessionId: actualSessionId,
        );

        return {
          'success': true,
          'ai_response': queryResult.hasError
              ? 'Query executed but had an error: ${queryResult.error}'
              : 'Found ${queryResult.rowCount} result${queryResult.rowCount == 1 ? '' : 's'}.',
          'query_result': queryResult,
          'generated_sql': localResult,
          'suggestions': _generateSuggestions(message),
          'metadata': {'from_date': fromDate, 'to_date': toDate},
          'source': 'local_template',
          'provider': 'local',
        };
      }

      // 4. Build system prompt and user message (AI path)
      final systemPrompt = _promptBuilder.buildSystemPrompt(
        companyGuid: companyGuid,
        companyData: companyDataStr,
      );
      final userMessage = _promptBuilder.buildUserMessage(
        question: message,
        fromDate: fromDate,
        toDate: toDate,
        entities: entities,
        conversationHistory: conversationHistory,
      );

      // 5. Handle "both" mode — run two providers in parallel
      if (aiProvider == 'both') {
        return _runBothProviders(
          companyGuid: companyGuid,
          userId: userId,
          message: message,
          sessionId: actualSessionId,
          systemPrompt: systemPrompt,
          userMessage: userMessage,
          fromDate: fromDate,
          toDate: toDate,
          conversationHistory: conversationHistory,
        );
      }

      // 5. Call AI provider directly
      final provider = _createProvider(aiProvider);
      debugPrint('[AI DEBUG] Calling $aiProvider directly...');

      final aiResult = await provider.generateSql(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
      );

      if (aiResult['success'] != true) {
        return {
          'success': false,
          'error': aiResult['error'] ?? 'AI provider failed',
          'ai_response': 'AI provider ($aiProvider) failed: ${aiResult['error']}',
          'suggestions': ['What were my sales last month?', 'Show me receivables', 'What is my profit this year?'],
          'failed_provider': aiProvider,
          'provider': aiProvider,
        };
      }

      // 6. Replace placeholders in generated SQL
      String generatedSql = aiResult['sql'] as String;
      final openingStockDate = _getPreviousDate(fromDate);
      generatedSql = generatedSql
          .replaceAll('{company_guid}', companyGuid)
          .replaceAll('{from_date}', fromDate)
          .replaceAll('{to_date}', toDate)
          .replaceAll('{opening_stock_date}', openingStockDate);
      if (entities['party_name'] != null) {
        generatedSql = generatedSql.replaceAll('{party_name}', entities['party_name']);
      }

      debugPrint('[AI DEBUG] Generated SQL: ${generatedSql.substring(0, generatedSql.length > 100 ? 100 : generatedSql.length)}...');

      // 7. Execute SQL locally
      final queryResult = await _executeLocalQuery(generatedSql);

      // 8. Save chat message
      await _saveChatMessage(
        companyGuid: companyGuid,
        userId: userId,
        message: message,
        generatedSql: generatedSql,
        resultCount: queryResult.rowCount,
        sessionId: actualSessionId,
      );

      return {
        'success': true,
        'ai_response': queryResult.hasError
            ? 'Query executed but had an error: ${queryResult.error}'
            : 'Found ${queryResult.rowCount} result${queryResult.rowCount == 1 ? '' : 's'}.',
        'query_result': queryResult,
        'generated_sql': generatedSql,
        'suggestions': _generateSuggestions(message),
        'metadata': {'from_date': fromDate, 'to_date': toDate},
        'source': 'local_ai',
        'provider': aiProvider,
        'token_usage': aiResult['usage'],
        'reasoning': aiResult['reasoning'],
      };
    } catch (e) {
      debugPrint('[AI DEBUG] AiQaService.sendQuery FAILED: $e');
      final isTimeout = e.toString().contains('TimeoutException');
      return {
        'success': false,
        'error': e.toString(),
        'ai_response': isTimeout
            ? 'Request timed out. The AI model may be warming up — please try again.'
            : 'Sorry, something went wrong. Please try again.',
        'suggestions': ['What were my sales last month?', 'Show me receivables', 'What is my profit this year?'],
      };
    }
  }

  /// Run two providers in parallel ("both" mode)
  static Future<Map<String, dynamic>> _runBothProviders({
    required String companyGuid,
    required String userId,
    required String message,
    required String sessionId,
    required String systemPrompt,
    required String userMessage,
    required String fromDate,
    required String toDate,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    final providerA = _createProvider('claude');
    final providerB = _createProvider('openrouter');

    final Future<Map<String, dynamic>> futureA = providerA.generateSql(systemPrompt: systemPrompt, userMessage: userMessage);
    final Future<Map<String, dynamic>> futureB = providerB.generateSql(systemPrompt: systemPrompt, userMessage: userMessage);
    final results = await Future.wait([futureA, futureB]);

    final resultA = results[0];
    final resultB = results[1];

    // Use the first successful result as primary
    final primary = resultA['success'] == true ? resultA : resultB;
    final secondary = resultA['success'] == true ? resultB : resultA;
    final primaryProvider = resultA['success'] == true ? 'claude' : 'openrouter';

    if (primary['success'] != true) {
      return {
        'success': false,
        'error': 'Both providers failed',
        'ai_response': 'Both AI providers failed. Please try again.',
        'suggestions': ['What were my sales last month?', 'Show me receivables'],
      };
    }

    final openingStockDate = _getPreviousDate(fromDate);
    String generatedSql = (primary['sql'] as String)
        .replaceAll('{company_guid}', companyGuid)
        .replaceAll('{from_date}', fromDate)
        .replaceAll('{to_date}', toDate)
        .replaceAll('{opening_stock_date}', openingStockDate);

    final queryResult = await _executeLocalQuery(generatedSql);

    await _saveChatMessage(
      companyGuid: companyGuid, userId: userId, message: message,
      generatedSql: generatedSql, resultCount: queryResult.rowCount,
      sessionId: sessionId,
    );

    // Build compare result if secondary also succeeded
    Map<String, dynamic>? compareResult;
    if (secondary['success'] == true) {
      String compareSql = (secondary['sql'] as String)
          .replaceAll('{company_guid}', companyGuid)
          .replaceAll('{from_date}', fromDate)
          .replaceAll('{to_date}', toDate)
          .replaceAll('{opening_stock_date}', openingStockDate);
      final compareQueryResult = await _executeLocalQuery(compareSql);
      compareResult = {
        'generated_sql': compareSql,
        'query_result': compareQueryResult,
        'provider': resultA['success'] == true ? 'openrouter' : 'claude',
      };
    }

    return {
      'success': true,
      'ai_response': 'Found ${queryResult.rowCount} result${queryResult.rowCount == 1 ? '' : 's'}.',
      'query_result': queryResult,
      'generated_sql': generatedSql,
      'suggestions': _generateSuggestions(message),
      'metadata': {'from_date': fromDate, 'to_date': toDate},
      'source': 'local_ai',
      'provider': primaryProvider,
      'token_usage': primary['usage'],
      'compare_result': compareResult,
    };
  }

  /// Generate follow-up suggestions based on the question
  static List<String> _generateSuggestions(String question) {
    final q = question.toLowerCase();
    if (q.contains('sale')) {
      return ['Top 10 customers by sales', 'Sales this month vs last month', 'Show purchase summary'];
    } else if (q.contains('purchase')) {
      return ['Top suppliers', 'Purchase this quarter', 'Show profit & loss'];
    } else if (q.contains('salary')) {
      return ['Salary breakdown by employee', 'Total deductions', 'Show TDS details'];
    } else if (q.contains('expense')) {
      return ['Indirect expenses breakdown', 'Top expense heads', 'Show profit & loss'];
    } else if (q.contains('receivable') || q.contains('debtor')) {
      return ['Top 10 debtors', 'Overdue receivables', 'Show payables'];
    } else if (q.contains('payable') || q.contains('creditor')) {
      return ['Top creditors', 'Show receivables', 'Cash flow summary'];
    }
    return ['What were my sales last month?', 'Show me receivables', 'What is my profit this year?'];
  }

  /// Default financial year start date
  static String _defaultFromDate() {
    final now = DateTime.now();
    final fyStart = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
    return '${fyStart.year}${fyStart.month.toString().padLeft(2, '0')}${fyStart.day.toString().padLeft(2, '0')}';
  }

  /// Default to today
  static String _defaultToDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  // ─── SUMMARY CACHE ───

  static Future<Map<String, dynamic>?> _getOrBuildSummary(String companyGuid) async {
    try {
      final cachedAt = _summaryCacheTimestamp[companyGuid];
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) < _summaryCacheDuration &&
          _summaryCache.containsKey(companyGuid)) {
        return _summaryCache[companyGuid];
      }

      final summary = await _buildCompanySummary(companyGuid);
      if (summary != null) {
        _summaryCache[companyGuid] = summary;
        _summaryCacheTimestamp[companyGuid] = DateTime.now();
        print('📊 Snapshot built: '
            'groups=${summary['groups']?.length ?? 0}, '
            'ledgers=${summary['ledgers']?.length ?? 0}, '
            'active=${summary['active_ledgers']?.length ?? 0}, '
            'vouchers=${summary['voucher_summary']?.length ?? 0}, '
            'stock_items=${summary['stock_items']?.length ?? 0}, '
            'stock_mvmt=${summary['stock_movement']?.length ?? 0}, '
            'expenses=${summary['expense_ledgers']?.length ?? 0}, '
            'income=${summary['income_ledgers']?.length ?? 0}, '
            'parties=${summary['top_parties']?.length ?? 0}, '
            'bank_cash=${summary['bank_cash_ledgers']?.length ?? 0}, '
            'salary_employees=${summary['salary_per_person']?.length ?? 0}, '
            'salary_components=${summary['salary_breakdown']?.length ?? 0}, '
            'deductions=${summary['salary_deductions']?.length ?? 0}, '
            'tax_ledgers=${summary['tax_ledgers']?.length ?? 0}');
      }
      return summary;
    } catch (e) {
      print('Error building company summary: $e');
      return _summaryCache[companyGuid];
    }
  }

  // ─── COMPREHENSIVE SNAPSHOT BUILDER ───
  // Each query is independent — one failure doesn't kill the rest.

  static Future<Map<String, dynamic>?> _buildCompanySummary(String companyGuid) async {
    final db = await AiDependencies.databaseProvider!();

    // Safe query wrapper — logs error, returns empty list on failure
    Future<List<Map<String, dynamic>>> q(String label, String sql, [List<Object?>? args]) async {
      try {
        return await db.rawQuery(sql, args ?? []);
      } catch (e) {
        print('Snapshot [$label] failed: $e');
        return [];
      }
    }

    // 1. Company info
    final companyResult = await q('company', '''
      SELECT company_name, starting_from, ending_at, currency_name,
             maintain_inventory, is_gst_applicable, state, city
      FROM companies WHERE company_guid = ? AND is_deleted = 0 LIMIT 1
    ''', [companyGuid]);

    // 2. Groups
    final groupsResult = await q('groups', '''
      SELECT g.name, g.reserved_name as reserved_name, pg.name as parent_name
      FROM groups g
      LEFT JOIN groups pg ON g.parent_guid = pg.group_guid AND pg.company_guid = g.company_guid
      WHERE g.company_guid = ? AND g.is_deleted = 0 ORDER BY g.name
    ''', [companyGuid]);

    // 3. Ledgers
    final ledgersResult = await q('ledgers', '''
      SELECT name, parent FROM ledgers
      WHERE company_guid = ? AND is_deleted = 0 ORDER BY parent, name
    ''', [companyGuid]);

    if (groupsResult.isEmpty && ledgersResult.isEmpty) return null;

    // 4. Active ledgers (with transactions)
    final activeLedgersResult = await q('active_ledgers', '''
      SELECT vle.ledger_name, l.parent as group_name,
        COUNT(DISTINCT v.voucher_guid) as txn_count,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as total_debit,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as total_credit
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      LEFT JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      GROUP BY vle.ledger_name, l.parent ORDER BY txn_count DESC LIMIT 200
    ''', [companyGuid]);

    // 5. Voucher summary
    final voucherSummaryResult = await q('vouchers', '''
      SELECT voucher_type, COUNT(*) as voucher_count,
        MIN(date) as earliest_date, MAX(date) as latest_date,
        SUM(ABS(COALESCE(amount, 0))) as total_amount
      FROM vouchers WHERE company_guid = ? AND is_deleted = 0 AND is_cancelled = 0 AND is_optional = 0
      GROUP BY voucher_type ORDER BY voucher_count DESC
    ''', [companyGuid]);

    // 6. Stock items (safe columns only — no opening_balance)
    final stockItemsResult = await q('stock', '''
      SELECT name, parent as stock_group, base_units
      FROM stock_items WHERE company_guid = ? AND is_deleted = 0
      ORDER BY parent, name LIMIT 300
    ''', [companyGuid]);

    // 7. Stock movement
    final stockMovementResult = await q('stock_mvmt', '''
      SELECT vie.stock_item_name, COUNT(DISTINCT v.voucher_guid) as txn_count,
        SUM(CASE WHEN v.voucher_type = 'Sales' THEN ABS(vie.amount) ELSE 0 END) as sales_value,
        SUM(CASE WHEN v.voucher_type = 'Purchase' THEN ABS(vie.amount) ELSE 0 END) as purchase_value
      FROM voucher_inventory_entries vie
      INNER JOIN vouchers v ON v.voucher_guid = vie.voucher_guid
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      GROUP BY vie.stock_item_name ORDER BY txn_count DESC LIMIT 100
    ''', [companyGuid]);

    // 8. Top parties (debtors & creditors)
    final topPartiesResult = await q('parties', '''
      SELECT l.name as party_name, l.parent as group_name, l.opening_balance,
        COUNT(DISTINCT v.voucher_guid) as txn_count,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as total_debit,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as total_credit
      FROM ledgers l
      INNER JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid AND v.company_guid = l.company_guid
      WHERE l.company_guid = ? AND l.is_deleted = 0
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
        AND l.parent IN (
          SELECT name FROM groups WHERE company_guid = ? AND is_deleted = 0
          AND (name IN ('Sundry Debtors','Sundry Creditors') OR reserved_name IN ('Sundry Debtors','Sundry Creditors'))
        )
      GROUP BY l.name, l.parent, l.opening_balance ORDER BY txn_count DESC LIMIT 50
    ''', [companyGuid, companyGuid]);

    // 9. Expense & salary ledgers
    final expenseLedgersResult = await q('expenses', '''
      WITH RECURSIVE et AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name='Indirect Expenses' OR name='Direct Expenses') AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g INNER JOIN et ON g.parent_guid = et.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT vle.ledger_name, l.parent as group_name,
        COUNT(DISTINCT v.voucher_guid) as txn_count,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as total_debit,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as total_credit
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN et ON l.parent = et.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      GROUP BY vle.ledger_name, l.parent ORDER BY total_debit DESC LIMIT 100
    ''', [companyGuid, companyGuid, companyGuid]);

    // 10. Income ledgers
    final incomeLedgersResult = await q('income', '''
      WITH RECURSIVE it AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND (name='Indirect Incomes' OR name='Direct Incomes') AND is_deleted = 0
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g INNER JOIN it ON g.parent_guid = it.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT vle.ledger_name, l.parent as group_name,
        COUNT(DISTINCT v.voucher_guid) as txn_count,
        SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END) as total_credit,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as total_debit
      FROM voucher_ledger_entries vle
      INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
      INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
      INNER JOIN it ON l.parent = it.name
      WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      GROUP BY vle.ledger_name, l.parent ORDER BY total_credit DESC LIMIT 100
    ''', [companyGuid, companyGuid, companyGuid]);

    // 11. Bank & cash
    final bankCashResult = await q('bank_cash', '''
      SELECT l.name as ledger_name, l.parent as group_name, l.opening_balance,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as total_debit,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as total_credit,
        COUNT(DISTINCT v.voucher_guid) as txn_count
      FROM ledgers l
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid AND v.company_guid = l.company_guid
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      WHERE l.company_guid = ? AND l.is_deleted = 0
        AND l.parent IN (
          SELECT name FROM groups WHERE company_guid = ? AND is_deleted = 0
          AND (name IN ('Bank Accounts','Cash-in-Hand','Bank OD A/c') OR reserved_name IN ('Bank Accounts','Cash-in-Hand','Bank OD A/c'))
        )
      GROUP BY l.name, l.parent, l.opening_balance ORDER BY txn_count DESC
    ''', [companyGuid, companyGuid]);

    // 12. SALARY PER-PERSON — Hybrid approach:
    //     - Keywords to identify salary vouchers (unavoidable — SALARY vs TRAVELLING both under Indirect Expenses)
    //     - Group hierarchy for bank/cash exclusion
    //     - Group hierarchy for deductions (TDS, Prof Tax, EPF, ESI)
    final salaryPerPersonResult = await q('salary_per_person', '''
      WITH salary_voucher_ids AS (
        SELECT DISTINCT v.voucher_guid, v.party_ledger_name
        FROM voucher_ledger_entries vle
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ?
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.party_ledger_name IS NOT NULL AND v.party_ledger_name != ''
          AND vle.amount < 0
          AND (LOWER(vle.ledger_name) LIKE '%salary%'
               OR LOWER(vle.ledger_name) LIKE '%wage%'
               OR LOWER(vle.ledger_name) LIKE '%wages%'
               OR LOWER(vle.ledger_name) LIKE '%payroll%'
               OR LOWER(vle.ledger_name) LIKE '%bonus%'
               OR LOWER(vle.ledger_name) LIKE '%incentive%'
               OR LOWER(vle.ledger_name) LIKE '%stipend%'
               OR LOWER(vle.ledger_name) LIKE '%honorarium%'
               OR LOWER(vle.ledger_name) LIKE '%remuneration%'
               OR LOWER(vle.ledger_name) LIKE '%esop%'
               OR LOWER(vle.ledger_name) LIKE '%employee benefit%'
               OR LOWER(vle.ledger_name) LIKE '%staff welfare%'
               OR LOWER(vle.ledger_name) LIKE '%gratuity%'
               OR LOWER(vle.ledger_name) LIKE '%overtime%'
               OR LOWER(vle.ledger_name) LIKE '%allowance%'
               OR LOWER(vle.ledger_name) LIKE '%perquisite%'
               OR LOWER(vle.ledger_name) LIKE '%perk%'
               OR LOWER(vle.ledger_name) LIKE '%manpower%'
               OR LOWER(vle.ledger_name) LIKE '%labour cost%'
               OR LOWER(vle.ledger_name) LIKE '%labor cost%'
               OR LOWER(vle.ledger_name) LIKE '%contract staff%'
               OR LOWER(vle.ledger_name) LIKE '%staff cost%'
               OR LOWER(vle.ledger_name) LIKE '%employee cost%'
               OR LOWER(vle.ledger_name) LIKE '%personnel%'
               OR LOWER(vle.ledger_name) LIKE '%commission%'
               )
      ),
      bank_cash_ledgers AS (
        SELECT l.name FROM ledgers l
        INNER JOIN groups g ON g.name = l.parent AND g.company_guid = l.company_guid
        WHERE l.company_guid = ? AND l.is_deleted = 0 AND g.is_deleted = 0
          AND (g.reserved_name IN ('Bank Accounts', 'Cash-in-Hand', 'Bank OD A/c')
               OR g.name IN ('Bank Accounts', 'Cash-in-Hand', 'Bank OD A/c'))
      )
      SELECT
        sv.party_ledger_name as employee_name,
        COUNT(DISTINCT sv.voucher_guid) as payment_count,
        SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as total_salary,
        GROUP_CONCAT(DISTINCT vle.ledger_name) as salary_ledgers_used
      FROM salary_voucher_ids sv
      INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = sv.voucher_guid
      WHERE vle.amount < 0
        AND vle.ledger_name NOT IN (SELECT name FROM bank_cash_ledgers)
        AND vle.ledger_name != sv.party_ledger_name
        AND (LOWER(vle.ledger_name) LIKE '%salary%'
             OR LOWER(vle.ledger_name) LIKE '%wage%'
             OR LOWER(vle.ledger_name) LIKE '%wages%'
             OR LOWER(vle.ledger_name) LIKE '%payroll%'
             OR LOWER(vle.ledger_name) LIKE '%bonus%'
             OR LOWER(vle.ledger_name) LIKE '%incentive%'
             OR LOWER(vle.ledger_name) LIKE '%stipend%'
             OR LOWER(vle.ledger_name) LIKE '%honorarium%'
             OR LOWER(vle.ledger_name) LIKE '%remuneration%'
             OR LOWER(vle.ledger_name) LIKE '%esop%'
             OR LOWER(vle.ledger_name) LIKE '%employee benefit%'
             OR LOWER(vle.ledger_name) LIKE '%staff welfare%'
             OR LOWER(vle.ledger_name) LIKE '%gratuity%'
             OR LOWER(vle.ledger_name) LIKE '%overtime%'
             OR LOWER(vle.ledger_name) LIKE '%allowance%'
             OR LOWER(vle.ledger_name) LIKE '%perquisite%'
             OR LOWER(vle.ledger_name) LIKE '%perk%'
             OR LOWER(vle.ledger_name) LIKE '%manpower%'
             OR LOWER(vle.ledger_name) LIKE '%labour cost%'
             OR LOWER(vle.ledger_name) LIKE '%labor cost%'
             OR LOWER(vle.ledger_name) LIKE '%contract staff%'
             OR LOWER(vle.ledger_name) LIKE '%staff cost%'
             OR LOWER(vle.ledger_name) LIKE '%employee cost%'
             OR LOWER(vle.ledger_name) LIKE '%personnel%'
             OR LOWER(vle.ledger_name) LIKE '%commission%'
             )
      GROUP BY sv.party_ledger_name
      ORDER BY total_salary DESC
      LIMIT 50
    ''', [companyGuid, companyGuid]);

    // 12b. SALARY BREAKDOWN — Per employee, per ledger component
    final salaryBreakdownResult = await q('salary_breakdown', '''
      WITH salary_voucher_ids AS (
        SELECT DISTINCT v.voucher_guid, v.party_ledger_name
        FROM voucher_ledger_entries vle
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ?
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.party_ledger_name IS NOT NULL AND v.party_ledger_name != ''
          AND vle.amount < 0
          AND (LOWER(vle.ledger_name) LIKE '%salary%'
               OR LOWER(vle.ledger_name) LIKE '%wage%'
               OR LOWER(vle.ledger_name) LIKE '%wages%'
               OR LOWER(vle.ledger_name) LIKE '%payroll%'
               OR LOWER(vle.ledger_name) LIKE '%bonus%'
               OR LOWER(vle.ledger_name) LIKE '%incentive%'
               OR LOWER(vle.ledger_name) LIKE '%stipend%'
               OR LOWER(vle.ledger_name) LIKE '%honorarium%'
               OR LOWER(vle.ledger_name) LIKE '%remuneration%'
               OR LOWER(vle.ledger_name) LIKE '%esop%'
               OR LOWER(vle.ledger_name) LIKE '%employee benefit%'
               OR LOWER(vle.ledger_name) LIKE '%staff welfare%'
               OR LOWER(vle.ledger_name) LIKE '%gratuity%'
               OR LOWER(vle.ledger_name) LIKE '%overtime%'
               OR LOWER(vle.ledger_name) LIKE '%allowance%'
               OR LOWER(vle.ledger_name) LIKE '%perquisite%'
               OR LOWER(vle.ledger_name) LIKE '%perk%'
               OR LOWER(vle.ledger_name) LIKE '%manpower%'
               OR LOWER(vle.ledger_name) LIKE '%labour cost%'
               OR LOWER(vle.ledger_name) LIKE '%labor cost%'
               OR LOWER(vle.ledger_name) LIKE '%contract staff%'
               OR LOWER(vle.ledger_name) LIKE '%staff cost%'
               OR LOWER(vle.ledger_name) LIKE '%employee cost%'
               OR LOWER(vle.ledger_name) LIKE '%personnel%'
               OR LOWER(vle.ledger_name) LIKE '%commission%'
               )
      )
      SELECT
        sv.party_ledger_name as employee_name,
        vle.ledger_name as component,
        SUM(ABS(vle.amount)) as amount
      FROM salary_voucher_ids sv
      INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = sv.voucher_guid
      WHERE vle.amount < 0
        AND vle.ledger_name != sv.party_ledger_name
        AND (LOWER(vle.ledger_name) LIKE '%salary%'
             OR LOWER(vle.ledger_name) LIKE '%wage%'
             OR LOWER(vle.ledger_name) LIKE '%wages%'
             OR LOWER(vle.ledger_name) LIKE '%payroll%'
             OR LOWER(vle.ledger_name) LIKE '%bonus%'
             OR LOWER(vle.ledger_name) LIKE '%incentive%'
             OR LOWER(vle.ledger_name) LIKE '%stipend%'
             OR LOWER(vle.ledger_name) LIKE '%honorarium%'
             OR LOWER(vle.ledger_name) LIKE '%remuneration%'
             OR LOWER(vle.ledger_name) LIKE '%esop%'
             OR LOWER(vle.ledger_name) LIKE '%employee benefit%'
             OR LOWER(vle.ledger_name) LIKE '%staff welfare%'
             OR LOWER(vle.ledger_name) LIKE '%gratuity%'
             OR LOWER(vle.ledger_name) LIKE '%overtime%'
             OR LOWER(vle.ledger_name) LIKE '%allowance%'
             OR LOWER(vle.ledger_name) LIKE '%perquisite%'
             OR LOWER(vle.ledger_name) LIKE '%perk%'
             OR LOWER(vle.ledger_name) LIKE '%manpower%'
             OR LOWER(vle.ledger_name) LIKE '%labour cost%'
             OR LOWER(vle.ledger_name) LIKE '%labor cost%'
             OR LOWER(vle.ledger_name) LIKE '%contract staff%'
             OR LOWER(vle.ledger_name) LIKE '%staff cost%'
             OR LOWER(vle.ledger_name) LIKE '%employee cost%'
             OR LOWER(vle.ledger_name) LIKE '%personnel%'
             OR LOWER(vle.ledger_name) LIKE '%commission%'
             )
      GROUP BY sv.party_ledger_name, vle.ledger_name
      ORDER BY sv.party_ledger_name, amount DESC
    ''', [companyGuid]);

    // 13. DEDUCTIONS PER EMPLOYEE — Group hierarchy for deductions
    //     Same salary vouchers (keyword-identified), but credit entries to
    //     non-bank, non-employee, non-expense ledgers = TDS, Prof Tax, EPF, ESI
    final deductionsResult = await q('salary_deductions', '''
      WITH salary_voucher_ids AS (
        SELECT DISTINCT v.voucher_guid, v.party_ledger_name
        FROM voucher_ledger_entries vle
        INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        WHERE v.company_guid = ?
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.party_ledger_name IS NOT NULL AND v.party_ledger_name != ''
          AND vle.amount < 0
          AND (LOWER(vle.ledger_name) LIKE '%salary%'
               OR LOWER(vle.ledger_name) LIKE '%wage%'
               OR LOWER(vle.ledger_name) LIKE '%wages%'
               OR LOWER(vle.ledger_name) LIKE '%payroll%'
               OR LOWER(vle.ledger_name) LIKE '%bonus%'
               OR LOWER(vle.ledger_name) LIKE '%incentive%'
               OR LOWER(vle.ledger_name) LIKE '%stipend%'
               OR LOWER(vle.ledger_name) LIKE '%honorarium%'
               OR LOWER(vle.ledger_name) LIKE '%remuneration%'
               OR LOWER(vle.ledger_name) LIKE '%esop%'
               OR LOWER(vle.ledger_name) LIKE '%employee benefit%'
               OR LOWER(vle.ledger_name) LIKE '%staff welfare%'
               OR LOWER(vle.ledger_name) LIKE '%gratuity%'
               OR LOWER(vle.ledger_name) LIKE '%overtime%'
               OR LOWER(vle.ledger_name) LIKE '%allowance%'
               OR LOWER(vle.ledger_name) LIKE '%perquisite%'
               OR LOWER(vle.ledger_name) LIKE '%perk%'
               OR LOWER(vle.ledger_name) LIKE '%manpower%'
               OR LOWER(vle.ledger_name) LIKE '%labour cost%'
               OR LOWER(vle.ledger_name) LIKE '%labor cost%'
               OR LOWER(vle.ledger_name) LIKE '%contract staff%'
               OR LOWER(vle.ledger_name) LIKE '%staff cost%'
               OR LOWER(vle.ledger_name) LIKE '%employee cost%'
               OR LOWER(vle.ledger_name) LIKE '%personnel%'
               OR LOWER(vle.ledger_name) LIKE '%commission%'
               )
      ),
      bank_cash_ledgers AS (
        SELECT l.name FROM ledgers l
        INNER JOIN groups g ON g.name = l.parent AND g.company_guid = l.company_guid
        WHERE l.company_guid = ? AND l.is_deleted = 0 AND g.is_deleted = 0
          AND (g.reserved_name IN ('Bank Accounts', 'Cash-in-Hand', 'Bank OD A/c')
               OR g.name IN ('Bank Accounts', 'Cash-in-Hand', 'Bank OD A/c'))
      )
      SELECT
        sv.party_ledger_name as employee_name,
        vle.ledger_name as deduction_type,
        SUM(vle.amount) as total_amount
      FROM salary_voucher_ids sv
      INNER JOIN voucher_ledger_entries vle ON vle.voucher_guid = sv.voucher_guid
      WHERE vle.amount > 0
        AND vle.ledger_name != sv.party_ledger_name
        AND vle.ledger_name NOT IN (SELECT name FROM bank_cash_ledgers)
      GROUP BY sv.party_ledger_name, vle.ledger_name
      ORDER BY sv.party_ledger_name, total_amount DESC
    ''', [companyGuid, companyGuid]);

    // 14. TAX LEDGERS — All ledgers under 'Duties & Taxes' group with balances
    //     Covers: GST (CGST, SGST, IGST), TDS (on Salary, Rent, Interest, Labour),
    //     TCS, Professional Tax, Service Tax, etc.
    //     Uses group hierarchy — catches ALL tax ledgers regardless of name.
    final taxLedgersResult = await q('tax_ledgers', '''
      WITH RECURSIVE tax_groups AS (
        SELECT group_guid, name FROM groups
        WHERE company_guid = ? AND is_deleted = 0
          AND (name = 'Duties & Taxes' OR reserved_name = 'Duties & Taxes')
        UNION ALL
        SELECT g.group_guid, g.name FROM groups g
        INNER JOIN tax_groups tg ON g.parent_guid = tg.group_guid
        WHERE g.company_guid = ? AND g.is_deleted = 0
      )
      SELECT
        l.name as ledger_name,
        l.parent as group_name,
        COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) as debit_total,
        COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0) as credit_total,
        (COALESCE(SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN vle.amount > 0 THEN vle.amount ELSE 0 END), 0)) as net_amount,
        COUNT(DISTINCT v.voucher_guid) as txn_count
      FROM ledgers l
      INNER JOIN tax_groups tg ON l.parent = tg.name
      LEFT JOIN voucher_ledger_entries vle ON vle.ledger_name = l.name
      LEFT JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
        AND v.company_guid = l.company_guid
        AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
      WHERE l.company_guid = ? AND l.is_deleted = 0
      GROUP BY l.name, l.parent
      HAVING txn_count > 0
      ORDER BY l.parent, debit_total DESC
    ''', [companyGuid, companyGuid, companyGuid]);

    // ── OLD APPROACHES (commented out — kept for reference) ──
    // // 12-OLD. Salary structure detection via party_ledger_name analysis
    // final salaryStructureResult = await q('salary_structure', '''
    //   SELECT vle.ledger_name, COUNT(DISTINCT v.voucher_guid) as txn_count,
    //     COUNT(DISTINCT v.party_ledger_name) as unique_parties,
    //     SUM(CASE WHEN vle.amount < 0 THEN ABS(vle.amount) ELSE 0 END) as total_paid,
    //     GROUP_CONCAT(DISTINCT v.party_ledger_name) as sample_parties
    //   FROM voucher_ledger_entries vle
    //   INNER JOIN vouchers v ON v.voucher_guid = vle.voucher_guid
    //   INNER JOIN ledgers l ON l.name = vle.ledger_name AND l.company_guid = v.company_guid
    //   WHERE v.company_guid = ? AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
    //     AND (LOWER(vle.ledger_name) LIKE '%salary%' OR LOWER(vle.ledger_name) LIKE '%wage%')
    //   GROUP BY vle.ledger_name ORDER BY total_paid DESC
    // ''', [companyGuid]);
    //
    // // 13-OLD. Salary creditor group detection (e.g., "Salary Creditor", "Employee Payable")
    // final salaryCreditorResult = await q('salary_creditor', '''
    //   SELECT g.name as group_name, l.name as employee_name, l.opening_balance,
    //     COALESCE(act.txn_count, 0) as txn_count, ...
    //   FROM groups g INNER JOIN ledgers l ON l.parent = g.name ...
    //   WHERE ... AND (LOWER(g.name) LIKE '%salary%' OR LOWER(g.name) LIKE '%employee%' ...)
    // ''', [companyGuid, companyGuid]);

    // ── BUILD PAYLOAD ──
    return {
      'company_info': companyResult.isNotEmpty ? companyResult.first : null,
      'groups': groupsResult.map((g) { return {'name': g['name'] as String, 'parent_name': g['parent_name'] as String?, 'reserved_name': g['reserved_name'] as String?}; }).toList(),
      'ledgers': ledgersResult.map((l) { return {'name': l['name'] as String, 'parent': l['parent'] as String?}; }).toList(),
      'active_ledgers': activeLedgersResult.map((a) { return {'ledger_name': a['ledger_name'] as String, 'group_name': a['group_name'] as String?, 'txn_count': a['txn_count'] as int, 'total_debit': a['total_debit'] as num, 'total_credit': a['total_credit'] as num}; }).toList(),
      'voucher_summary': voucherSummaryResult.map((v) { return {'voucher_type': v['voucher_type'] as String, 'voucher_count': v['voucher_count'] as int, 'earliest_date': v['earliest_date'] as String?, 'latest_date': v['latest_date'] as String?, 'total_amount': v['total_amount'] as num?}; }).toList(),
      'stock_items': stockItemsResult.map((s) { return {'name': s['name'] as String, 'stock_group': s['stock_group'] as String?, 'base_units': s['base_units'] as String?}; }).toList(),
      'stock_movement': stockMovementResult.map((s) { return {'stock_item_name': s['stock_item_name'] as String, 'txn_count': s['txn_count'] as int, 'sales_value': s['sales_value'] as num?, 'purchase_value': s['purchase_value'] as num?}; }).toList(),
      'top_parties': topPartiesResult.map((p) { return {'party_name': p['party_name'] as String, 'group_name': p['group_name'] as String?, 'opening_balance': p['opening_balance'] as num?, 'txn_count': p['txn_count'] as int, 'total_debit': p['total_debit'] as num, 'total_credit': p['total_credit'] as num}; }).toList(),
      'expense_ledgers': expenseLedgersResult.map((e) { return {'ledger_name': e['ledger_name'] as String, 'group_name': e['group_name'] as String?, 'txn_count': e['txn_count'] as int, 'total_debit': e['total_debit'] as num, 'total_credit': e['total_credit'] as num}; }).toList(),
      'income_ledgers': incomeLedgersResult.map((i) { return {'ledger_name': i['ledger_name'] as String, 'group_name': i['group_name'] as String?, 'txn_count': i['txn_count'] as int, 'total_credit': i['total_credit'] as num, 'total_debit': i['total_debit'] as num}; }).toList(),
      'bank_cash_ledgers': bankCashResult.map((b) { return {'ledger_name': b['ledger_name'] as String, 'group_name': b['group_name'] as String?, 'opening_balance': b['opening_balance'] as num?, 'total_debit': b['total_debit'] as num, 'total_credit': b['total_credit'] as num, 'txn_count': b['txn_count'] as int}; }).toList(),
      'salary_per_person': salaryPerPersonResult.map((s) { return {'employee_name': s['employee_name'] as String, 'payment_count': s['payment_count'] as int, 'total_salary': s['total_salary'] as num, 'salary_ledgers_used': s['salary_ledgers_used'] as String?}; }).toList(),
      'salary_breakdown': salaryBreakdownResult.map((s) { return {'employee_name': s['employee_name'] as String, 'component': s['component'] as String, 'amount': s['amount'] as num}; }).toList(),
      'salary_deductions': deductionsResult.map((s) { return {'employee_name': s['employee_name'] as String, 'deduction_type': s['deduction_type'] as String, 'total_amount': s['total_amount'] as num}; }).toList(),
      'tax_ledgers': taxLedgersResult.map((t) { return {'ledger_name': t['ledger_name'] as String, 'group_name': t['group_name'] as String?, 'debit_total': t['debit_total'] as num, 'credit_total': t['credit_total'] as num, 'net_amount': t['net_amount'] as num, 'txn_count': t['txn_count'] as int}; }).toList(),
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Force refresh the company summary cache
  static Future<void> refreshSummary(String companyGuid) async {
    _summaryCache.remove(companyGuid);
    _summaryCacheTimestamp.remove(companyGuid);
    await _getOrBuildSummary(companyGuid);
  }

  /// Get snapshot data for debug UI
  static Future<Map<String, dynamic>?> getSnapshotDebug(String companyGuid) async {
    if (_summaryCache.containsKey(companyGuid)) return _summaryCache[companyGuid];
    return await _buildCompanySummary(companyGuid);
  }

  /// Try to match the user's question against local SQL templates.
  /// Returns the ready-to-execute SQL if matched, or null to fall through to AI.
  static String? _tryLocalTemplate({
    required String message,
    required String companyGuid,
    required String fromDate,
    required String toDate,
    required Map<String, dynamic> entities,
  }) {
    debugPrint('[LOCAL TEMPLATE] === ENTERING _tryLocalTemplate ===');
    debugPrint('[LOCAL TEMPLATE] Message: "$message"');
    try {
      final templates = QueryTemplates.loadAll();
      debugPrint('[LOCAL TEMPLATE] Loaded ${templates.length} templates');
      final matcher = TemplateMatcher(templates);
      final builder = QueryBuilder();
      // Strip any [Filter: ...] suffix before matching
      final cleanMessage = message.replaceAll(RegExp(r'\s*\[Filter:.*?\]\s*$'), '').trim();
      final msgLower = cleanMessage.toLowerCase();
      debugPrint('[LOCAL TEMPLATE] Trying to match: "$msgLower"');

      // Step 1: Exact match against sampleQuestions
      for (final t in templates) {
        for (final sq in t.sampleQuestions) {
          if (_fuzzyMatch(msgLower, sq.toLowerCase())) {
            debugPrint('[LOCAL TEMPLATE] Exact match: ${t.templateId} (${t.description})');
            return builder.build(
              template: t,
              entities: {'from_date': fromDate, 'to_date': toDate, ...entities},
              companyGuid: companyGuid,
            );
          }
        }
      }

      // Step 2: Keyword-based matching via TemplateMatcher
      final matched = matcher.select(
        intent: msgLower.replaceAll(RegExp(r'[?.,!]'), '').replaceAll(' ', '_'),
        entities: {'from_date': fromDate, 'to_date': toDate, ...entities},
      );

      if (matched != null) {
        // Only use template if keyword match is strong enough
        final keywordHits = matched.intentKeywords
            .where((kw) => msgLower.contains(kw.toLowerCase()))
            .length;
        if (keywordHits >= 1) {
          debugPrint('[LOCAL TEMPLATE] Keyword match: ${matched.templateId} (${matched.description}), hits: $keywordHits');
          return builder.build(
            template: matched,
            entities: {'from_date': fromDate, 'to_date': toDate, ...entities},
            companyGuid: companyGuid,
          );
        }
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('[LOCAL TEMPLATE] ERROR: $e');
      debugPrint('[LOCAL TEMPLATE] Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      return null;
    }
  }

  /// Fuzzy match: true if messages are similar enough
  static bool _fuzzyMatch(String input, String sample) {
    // Exact match
    if (input == sample) return true;
    // Input contains the full sample or vice versa
    if (input.contains(sample) || sample.contains(input)) return true;
    // Remove common filler words and compare
    final clean = (String s) => s
        .replaceAll(RegExp(r'\b(show|me|tell|what|is|my|the|were|for|this|please|can you)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final c1 = clean(input);
    final c2 = clean(sample);
    if (c1 == c2) return true;
    if (c1.isNotEmpty && c2.isNotEmpty && (c1.contains(c2) || c2.contains(c1))) return true;
    return false;
  }

  /// Get previous date in YYYYMMDD format (subtract 1 day)
  static String _getPreviousDate(String dateStr) {
    try {
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      final date = DateTime(year, month, day).subtract(const Duration(days: 1));
      return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  /// Execute SQL locally (READ-ONLY)
  static Future<QueryResult> _executeLocalQuery(String sql) async {
    try {
      final db = await AiDependencies.databaseProvider!();
      final sw = Stopwatch()..start();
      final results = await db.rawQuery(sql);
      sw.stop();
      return QueryResult(data: results, rowCount: results.length, executionTimeMs: sw.elapsedMilliseconds);
    } catch (e) {
      print('Local query error: $e');
      return QueryResult(data: [], rowCount: 0, executionTimeMs: 0, error: e.toString());
    }
  }

  /// Re-run an existing SQL query with new date range (no API call)
  static Future<QueryResult> reRunWithDates({
    required String originalSql,
    required String newFromDate,
    required String newToDate,
  }) async {
    // Replace date placeholders in the SQL using regex
    // Dates are in YYYYMMDD format like '20250401'
    String updatedSql = originalSql.replaceAllMapped(
      RegExp(r"v\.date\s*>=\s*'(\d{8})'"),
      (m) => "v.date >= '$newFromDate'",
    );
    updatedSql = updatedSql.replaceAllMapped(
      RegExp(r"v\.date\s*<=\s*'(\d{8})'"),
      (m) => "v.date <= '$newToDate'",
    );
    // Also handle: date >= 'YYYYMMDD' (without v. prefix)
    updatedSql = updatedSql.replaceAllMapped(
      RegExp(r"date\s*>=\s*'(\d{8})'"),
      (m) => "date >= '$newFromDate'",
    );
    updatedSql = updatedSql.replaceAllMapped(
      RegExp(r"date\s*<=\s*'(\d{8})'"),
      (m) => "date <= '$newToDate'",
    );
    return _executeLocalQuery(updatedSql);
  }

  /// Save chat message to AI database
  static Future<void> _saveChatMessage({
    required String companyGuid, required String userId, required String message,
    required String generatedSql, required int resultCount, required String sessionId,
  }) async {
    try {
      final chatMessage = ChatMessage(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        companyGuid: companyGuid, userId: userId, messageType: 'user_question',
        content: message, generatedSql: generatedSql, resultCount: resultCount,
        timestamp: DateTime.now(), sessionId: sessionId,
      );
      await DatabaseHelper.instance.insertChatMessage(chatMessage.toMap());
    } catch (e) {
      print('Error saving chat message: $e');
    }
  }

  /// Get chat history
  static Future<List<ChatMessage>> getChatHistory({
    required String companyGuid, String? sessionId, int limit = 50,
  }) async {
    try {
      final results = await DatabaseHelper.instance.getChatHistory(
        companyGuid: companyGuid, sessionId: sessionId, limit: limit,
      );
      return results.map((row) => ChatMessage.fromMap(row)).toList();
    } catch (e) {
      print('Error fetching chat history: $e');
      return [];
    }
  }

  /// Submit feedback
  static Future<bool> submitFeedback({required String logId, required int score, required String token}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl${AiEndpoints.feedback}'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'log_id': logId, 'score': score}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }

  /// Clear chat history
  static Future<bool> clearChatHistory(String companyGuid) async {
    try {
      await DatabaseHelper.instance.clearChatHistory(companyGuid);
      return true;
    } catch (e) {
      print('Error clearing chat history: $e');
      return false;
    }
  }
}