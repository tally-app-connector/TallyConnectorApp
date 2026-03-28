import 'dart:convert';
import 'package:flutter/material.dart';
import '../../ai/services/ai_provider_service.dart';
import '../../ai/models/metric_config.dart';
import '../../ai/di/ai_dependencies.dart';
import '../../ai/services/ai_qa_service.dart';
import '../../ai/models/query_result.dart';
import '../../ai/services/query_templates.dart';
import '../../ai/services/query_builder.dart';

/// Result type categories for universal summary card
enum _ResultType {
  salary, deduction, breakdown, sales, purchase, expense,
  outstanding, payment, receipt, stock, profitLoss,
  debitCredit, ledgerTxn, generic,
}

class _ResultTheme {
final Color color;
final IconData icon;
final String label;
final String entityLabel;
const _ResultTheme(this.color, this.icon, this.label, this.entityLabel);
}
/// Lightweight wrapper to match QueryResult interface for custom-built results
/// (e.g. closing stock calculation results)
class _SimpleQueryResult {
final bool hasError;
final bool isEmpty;
final String? error;
final List<String> columnNames;
final List<Map<String, dynamic>> data;
final String formattedExecutionTime;
_SimpleQueryResult({
this.hasError = false,
this.isEmpty = false,
this.error,
required this.columnNames,
required this.data,
this.formattedExecutionTime = '0ms',
});
}
/// AI Queries Screen - Phase 1 MVP (Simple Test Version)
/// Full-featured version with charts/widgets will be in Phase 2
class AIQueriesScreen extends StatefulWidget {
  final String companyGuid;
  final String userId;
  final String token;

  const AIQueriesScreen({
    Key? key,
    required this.companyGuid,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  _AIQueriesScreenState createState() => _AIQueriesScreenState();
}

class _AIQueriesScreenState extends State<AIQueriesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _selectedMetric;
  DateTime? _loadingStartTime;

  // Conversation context for follow-up questions (max 5 turns)
  final List<Map<String, dynamic>> _conversationHistory = [];
  int _contextTurnCount = 0;
  static const int _maxContextTurns = 5;

  // Entity filter state
  bool _showEntityFilters = false;
  String? _pendingQuestion;  // question waiting for filter selection
  Map<String, List<String>> _availableFilters = {};  // entity_type -> [values]
  Map<String, String> _selectedFilters = {};  // entity_type -> selected value

  // AI provider selection
  String _aiProvider = 'claude';  // 'claude', 'deepseek', 'both'

  // Metric categories with preset questions
  final metrics = MetricConfig.allMetrics;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Queries'),
        backgroundColor: Colors.teal,
        actions: [
          if (_contextTurnCount > 0)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'New Session (reset context)',
              onPressed: () {
                setState(() {
                  _conversationHistory.clear();
                  _contextTurnCount = 0;
                  _messages.add({
                    'type': 'system',
                    'content': '🔄 Context reset. Starting fresh session.',
                    'timestamp': DateTime.now(),
                  });
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.bug_report, size: 22),
            tooltip: 'View Snapshot',
            onPressed: _showSnapshotDebug,
          ),
        ],
      ),
      body: Column(
        children: [
          // Horizontal scrollable metric categories
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: metrics.length,
              itemBuilder: (context, index) {
                final metric = metrics[index];
                final isSelected = _selectedMetric == metric.name;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMetric = isSelected ? null : metric.name;
                      });
                    },
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        color: isSelected ? metric.color : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? metric.color : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            metric.icon,
                            color: isSelected ? Colors.white : metric.color,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Preset questions for selected metric
          if (_selectedMetric != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                  bottom: BorderSide(color: Colors.blue[200]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Suggested questions for $_selectedMetric:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (MetricConfig.getByName(_selectedMetric!)
                                ?.presetQuestions ??
                            [])
                        .map((question) => ActionChip(
                              label: Text(
                                question,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: _isLoading ? null : () {
                                _runPresetQuery(question);
                              },
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.blue[300]!),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Select a metric above to get started',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'or type your question below',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // Loading indicator with live timer
          if (_isLoading)
            _buildLiveLoadingIndicator(),

          // AI Provider selector
          _buildProviderSelector(),

          // Entity filter bar (shown when question has filterable entities)
          if (_showEntityFilters && _pendingQuestion != null)
            _buildEntityFilterBar(),

          // Input field
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask anything or select a question above...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  mini: true,
                  backgroundColor: _isLoading ? Colors.grey : Colors.teal,
                  child: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLoadingIndicator() {
    final providerMeta = _providerMeta[_aiProvider];
    final providerLabel = providerMeta?['label'] ?? _aiProvider;
    final providerIcon = providerMeta?['icon'] ?? '...';

    return Padding(
      padding: const EdgeInsets.all(8),
      child: StreamBuilder(
        stream: Stream.periodic(const Duration(seconds: 1)),
        builder: (context, snapshot) {
          final elapsed = _loadingStartTime != null
              ? DateTime.now().difference(_loadingStartTime!).inSeconds
              : 0;

          String statusText;
          // Check if last message was from a preset/local query
          final lastUserMsg = _messages.isNotEmpty && _messages.last['type'] == 'user'
              ? _messages.last : null;
          final isLocalQuery = lastUserMsg != null && _messages.isNotEmpty &&
              QueryTemplates.loadAll().any((t) => t.sampleQuestions.any(
                (sq) => sq.toLowerCase() == (lastUserMsg['content'] as String?)?.toLowerCase()));

          if (isLocalQuery) {
            statusText = 'Running query locally... ${elapsed}s';
          } else if (elapsed < 3) {
            statusText = 'Connecting to $providerLabel...';
          } else if (elapsed < 15) {
            statusText = '$providerLabel is generating SQL... ${elapsed}s';
          } else if (elapsed < 40) {
            statusText = '$providerLabel is thinking... ${elapsed}s (model may be warming up)';
          } else {
            statusText = '$providerLabel still processing... ${elapsed}s (please wait)';
          }

          // Debug print every 10 seconds
          if (elapsed > 0 && elapsed % 10 == 0 && !isLocalQuery) {
            debugPrint('[AI DEBUG] $statusText');
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                ),
                const SizedBox(width: 10),
                Text(providerIcon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          Text('AI:', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          // _providerChip('claude', '🟣 Claude', Colors.purple),
          // const SizedBox(width: 4),
          _providerChip('deepseek', '🟡 Kimi K2.5', Colors.amber),
          const SizedBox(width: 4),
          _providerChip('llama', '🦙 Llama 8B', Colors.green),
          const SizedBox(width: 4),
          _providerChip('qwen', '🧠 Qwen3 32B', Colors.cyan),
          const SizedBox(width: 4),
          _providerChip('openrouter', '🌐 OR-Qwen3', Colors.teal),
          const SizedBox(width: 4),
          _providerChip('qwen3_8b', '🔷 Q3-8B HF', Colors.indigo),
          const SizedBox(width: 4),
          _providerChip('qwen3_4b', '🔹 Q3-1.7B', Colors.blue),
          const SizedBox(width: 4),
          _providerChip('glm5', '🟢 GLM-5', Colors.green),
          const SizedBox(width: 4),
          _providerChip('aws', '☁️ AWS', Colors.deepOrange),
          const SizedBox(width: 4),
          _providerChip('both', '⚔️ Both', Colors.orange),
        ],
      ),
    );
  }

  Widget _providerChip(String value, String label, Color color) {
    final isActive = _aiProvider == value;
    return GestureDetector(
      onTap: () => setState(() => _aiProvider = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.25),
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? color : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildEntityFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        border: Border(top: BorderSide(color: Colors.teal.withOpacity(0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.filter_alt, size: 14, color: Colors.teal[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Select filters for: "${_pendingQuestion}"',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showEntityFilters = false;
                    _pendingQuestion = null;
                    _availableFilters.clear();
                    _selectedFilters.clear();
                  });
                },
                child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Dropdown(s) for each detected entity
          ..._availableFilters.entries.map((entry) {
            final entityType = entry.key;
            final values = entry.value;
            final meta = _entityMeta[entityType] ?? {'label': entityType, 'icon': Icons.filter_list};
            final selected = _selectedFilters[entityType] ?? 'ALL';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(meta['icon'] as IconData, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 90,
                    child: Text(
                      meta['label'] as String,
                      style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selected,
                          isExpanded: true,
                          isDense: true,
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                          icon: Icon(Icons.arrow_drop_down, size: 18, color: Colors.teal[400]),
                          items: [
                            DropdownMenuItem<String>(
                              value: 'ALL',
                              child: Text('ALL (${values.length})',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal[700])),
                            ),
                            ...values.map((v) => DropdownMenuItem<String>(
                              value: v,
                              child: Text(v, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedFilters[entityType] = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showEntityFilters = false;
                    _pendingQuestion = null;
                  });
                },
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text('Cancel', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final filters = Map<String, String>.from(_selectedFilters);
                  final question = _pendingQuestion!;
                  setState(() {
                    _showEntityFilters = false;
                    _pendingQuestion = null;
                    _availableFilters.clear();
                    _selectedFilters.clear();
                  });
                  _executeQuestion(question, filters: filters);
                },
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Run Query', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['type'] == 'user';
    final isError = message['type'] == 'error';
    final isSystem = message['type'] == 'system';
    final isProviderFailed = message['type'] == 'provider_failed';

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message['content'] ?? '',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
      );
    }

    if (isProviderFailed) {
      return _buildProviderFailedMessage(message);
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red[100]
              : isUser
                  ? Colors.teal[500]
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['content'],
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            // Show applied filters as chips on user messages
            if (isUser && message['filters'] != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: (message['filters'] as Map<String, String>).entries
                    .where((e) => e.value != 'ALL')
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_entityMeta[e.key]?['label'] ?? e.key}: ${e.value}',
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                          ),
                        ))
                    .toList(),
              ),
            ],
            // Show applied filters as chips on AI response
            if (!isUser && message['applied_filters'] != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: (message['applied_filters'] as Map<String, String>).entries
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal.withOpacity(0.2)),
                          ),
                          child: Text(
                            e.value == 'ALL' ? '${_entityMeta[e.key]?['label'] ?? e.key}: All' : '🔍 ${e.value}',
                            style: TextStyle(fontSize: 9, color: Colors.teal[700]),
                          ),
                        ))
                    .toList(),
              ),
            ],
            if (message['query_result'] != null) ...[
              const SizedBox(height: 12),
              // Universal summary card — auto-detects type from columns
              _buildResultSummaryCard(
                message['query_result'],
                message['original_question']?.toString() ?? message['content']?.toString() ?? '',
              ),
              // Date range filter (inline, re-runs locally)
              if (message['generated_sql'] != null)
                _buildDateRangeFilter(message),
              _buildQueryResultTable(message['query_result']),
              // Calculation methodology note for salary/TDS queries
              if (_isSalaryQuery(message['original_question']?.toString() ?? message['content']?.toString() ?? ''))
                _buildCalcNote(
                  'Salary = Direct expense debits (Salary + Bonus + Incentive etc.). '
                  'Excludes deductions: TDS, Professional Tax, EPF, ESI.',
                  Icons.info_outline,
                ),
              if (_isTdsQuery(message['original_question']?.toString() ?? message['content']?.toString() ?? ''))
                _buildCalcNote(
                  'Showing TDS on Salary only. Professional Tax, EPF, ESI shown separately. '
                  'Check related suggestions below for full deduction breakdown.',
                  Icons.info_outline,
                ),
              // Side-by-side comparison for "both" mode
              if (message['compare_result'] != null)
                _buildComparisonView(message),
            ],
            if (message['generated_sql'] != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Generated SQL', style: TextStyle(fontSize: 14)),
                      content: SingleChildScrollView(
                        child: SelectableText(
                          message['generated_sql'],
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'View SQL',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              // Source indicator + context debug
              const SizedBox(height: 4),
              _buildSourceAndTokenInfo(message),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonView(Map<String, dynamic> message) {
    final primary = message['provider']?.toString() ?? 'claude';
    final compare = message['compare_result'] as Map<String, dynamic>?;
    if (compare == null) return const SizedBox.shrink();

    final compProvider = compare['provider']?.toString() ?? 'deepseek';
    final compSql = compare['generated_sql']?.toString() ?? '';
    final compTokens = compare['token_usage'] as Map<String, dynamic>?;
    final compReasoning = compare['reasoning']?.toString() ?? '';
    final primarySql = message['generated_sql']?.toString() ?? '';

    final sqlMatch = primarySql.trim() == compSql.trim();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('⚔️ ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  'Comparison: ${primary.toUpperCase()} vs ${compProvider.toUpperCase()}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sqlMatch ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sqlMatch ? '✓ SQL Match' : '✗ SQL Differs',
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold,
                    color: sqlMatch ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Side by side SQL (full, scrollable)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sqlCompareCard(
                  primary, primarySql,
                  message['token_usage'] as Map<String, dynamic>?,
                  primary == 'claude' ? Colors.purple : Colors.blue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _sqlCompareCard(
                  compProvider, compSql,
                  compTokens,
                  compProvider == 'deepseek' ? Colors.amber : Colors.purple,
                ),
              ),
            ],
          ),

          // Side by side RESULTS (if compare has query_result)
          if (compare['query_result'] != null) ...[
            const SizedBox(height: 8),
            Text('Result Comparison:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange[700])),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary result summary
                Expanded(
                  child: _resultCompareCard(
                    primary,
                    message['query_result'],
                    primary == 'claude' ? Colors.purple : Colors.blue,
                  ),
                ),
                const SizedBox(width: 6),
                // Compare result summary
                Expanded(
                  child: _resultCompareCard(
                    compProvider,
                    compare['query_result'],
                    compProvider == 'deepseek' ? Colors.amber : Colors.purple,
                  ),
                ),
              ],
            ),
          ],

          // DeepSeek reasoning
          if (compReasoning.isNotEmpty || (message['reasoning']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                final reasoning = compReasoning.isNotEmpty
                    ? compReasoning
                    : message['reasoning']?.toString() ?? '';
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('🧠 Kimi K2.5 Thinking', style: TextStyle(fontSize: 14)),
                    content: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          reasoning,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.5),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    ],
                  ),
                );
              },
              child: Text(
                '🧠 View Kimi K2.5 Thinking',
                style: TextStyle(fontSize: 10, color: Colors.blue[400], decoration: TextDecoration.underline),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sqlCompareCard(String provider, String sql, Map<String, dynamic>? tokens, Color color) {
    final inputT = tokens?['input_tokens'] ?? 0;
    final outputT = tokens?['output_tokens'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  provider.toUpperCase(),
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const Spacer(),
              Text('$inputT↑ $outputT↓', style: TextStyle(fontSize: 8, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 4),
          // Full SQL - scrollable, no truncation
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: SelectableText(
                sql,
                style: TextStyle(fontSize: 8, fontFamily: 'monospace', color: Colors.grey[700]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCompareCard(String provider, dynamic queryResult, Color color) {
    if (queryResult == null || queryResult.hasError || queryResult.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Text(
          '${provider.toUpperCase()}: ${queryResult?.error ?? "No results"}',
          style: TextStyle(fontSize: 9, color: Colors.red[600]),
        ),
      );
    }

    final rows = List<Map<String, dynamic>>.from(queryResult.data);
    final columns = List<String>.from(queryResult.columnNames);

    // Find amount column for summary
    final amountCol = columns.firstWhere(
      (c) => c.contains('net') || c.contains('amount') || c.contains('total') || c.contains('salary'),
      orElse: () => '',
    );

    // Calculate total
    num total = 0;
    if (amountCol.isNotEmpty) {
      for (final row in rows) {
        final val = row[amountCol];
        if (val is num) total += val;
      }
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  provider.toUpperCase(),
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const Spacer(),
              Text('${rows.length} rows', style: TextStyle(fontSize: 8, color: Colors.grey[500])),
            ],
          ),
          if (amountCol.isNotEmpty && total > 0) ...[
            const SizedBox(height: 2),
            Text(
              '₹${_formatIndianNumber(total.toDouble())}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
          const SizedBox(height: 4),
          // Show first 3 rows as preview
          ...rows.take(3).map((row) {
            final nameCol = columns.firstWhere(
              (c) => c.contains('name') || c.contains('party') || c.contains('ledger'),
              orElse: () => columns.first,
            );
            final name = row[nameCol]?.toString() ?? '';
            final amt = amountCol.isNotEmpty ? row[amountCol]?.toString() ?? '' : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                '$name${amt.isNotEmpty ? ": ₹$amt" : ""}',
                style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          if (rows.length > 3)
            Text('...+${rows.length - 3} more', style: TextStyle(fontSize: 8, color: Colors.grey[400])),
        ],
      ),
    );
  }

  // Provider name/icon mapping
  static const _providerMeta = {
    'claude': {'label': 'Claude', 'icon': '🟣', 'color': 'purple'},
    'deepseek': {'label': 'Kimi K2.5', 'icon': '🟡', 'color': 'amber'},
    'llama': {'label': 'Llama 8B', 'icon': '🦙', 'color': 'green'},
    'qwen': {'label': 'Qwen3 32B', 'icon': '🧠', 'color': 'cyan'},
    'openrouter': {'label': 'OR-Qwen3 8B', 'icon': '🌐', 'color': 'teal'},
    'qwen3_8b': {'label': 'Qwen3 8B HF', 'icon': '🔷', 'color': 'indigo'},
    'qwen3_4b': {'label': 'Qwen3 1.7B HF', 'icon': '🔹', 'color': 'blue'},
    'glm5': {'label': 'GLM-5', 'icon': '🟢', 'color': 'green'},
    'aws': {'label': 'AWS Qwen', 'icon': '☁️', 'color': 'deepOrange'},
  };

  Color _providerColor(String provider) {
    switch (provider) {
      case 'claude': return Colors.purple;
      case 'deepseek': return Colors.amber.shade700;
      case 'llama': return Colors.green;
      case 'qwen': return Colors.cyan;
      case 'openrouter': return Colors.teal;
      case 'qwen3_8b': return Colors.indigo;
      case 'qwen3_4b': return Colors.blue;
      case 'glm5': return Colors.green;
      case 'aws': return Colors.deepOrange;
      default: return Colors.grey;
    }
  }

  Widget _buildProviderFailedMessage(Map<String, dynamic> message) {
    final failedProvider = message['failed_provider']?.toString() ?? '';
    final fallbackChain = List<String>.from(message['fallback_chain'] ?? []);
    final errorMsg = message['content']?.toString() ?? 'Provider failed';
    final meta = _providerMeta[failedProvider];
    final failedLabel = meta?['label'] ?? failedProvider;
    final failedIcon = meta?['icon'] ?? '❌';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error header
            Row(
              children: [
                Text(failedIcon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$failedLabel failed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              errorMsg,
              style: TextStyle(fontSize: 11, color: Colors.red[600]),
            ),
            const SizedBox(height: 10),

            // Fallback options
            Text(
              'Try with another provider:',
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: fallbackChain.map((provider) {
                final pMeta = _providerMeta[provider];
                final pLabel = pMeta?['label'] ?? provider;
                final pIcon = pMeta?['icon'] ?? '🤖';
                final pColor = _providerColor(provider);
                return ElevatedButton.icon(
                  onPressed: () => _retryWithProvider(
                    provider,
                    message['original_question']?.toString() ?? '',
                    message['enriched_question']?.toString() ?? '',
                    message['filters'] as Map<String, String>?,
                  ),
                  icon: Text(pIcon, style: const TextStyle(fontSize: 12)),
                  label: Text(
                    'Try $pLabel',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pColor.withOpacity(0.1),
                    foregroundColor: pColor,
                    side: BorderSide(color: pColor.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryWithProvider(
    String provider,
    String originalQuestion,
    String enrichedQuestion,
    Map<String, String>? filters,
  ) async {
    // Switch provider and re-execute
    setState(() {
      _aiProvider = provider;
      _isLoading = true;
    });

    try {
      final result = await AiQaService.sendQuery(
        companyGuid: widget.companyGuid,
        userId: widget.userId,
        message: enrichedQuestion.isNotEmpty ? enrichedQuestion : originalQuestion,
        token: widget.token,
        conversationHistory: _conversationHistory,
        aiProvider: provider,
      );

      // If this provider also failed, show another failure message
      if (result['success'] != true && result['failed_provider'] != null) {
        final failedProvider = result['failed_provider'] as String;
        final fallbackChain = result['fallback_chain'] as List<String>? ?? [];

        setState(() {
          _messages.add({
            'type': 'provider_failed',
            'content': result['error']?.toString() ?? 'Provider failed',
            'failed_provider': failedProvider,
            'fallback_chain': fallbackChain,
            'original_question': originalQuestion,
            'enriched_question': enrichedQuestion,
            'filters': filters,
            'timestamp': DateTime.now(),
          });
          _isLoading = false; _loadingStartTime = null;
        });
        return;
      }

      if (result['success'] != true) {
        setState(() {
          _messages.add({
            'type': 'error',
            'content': result['error']?.toString() ?? 'Something went wrong',
            'timestamp': DateTime.now(),
          });
          _isLoading = false; _loadingStartTime = null;
        });
        return;
      }

      // Success! Build result summary
      String resultSummary = '';
      List<String> sqlColumns = [];
      if (result['query_result'] != null && !result['query_result'].hasError && !result['query_result'].isEmpty) {
        final qr = result['query_result'];
        sqlColumns = List<String>.from(qr.columnNames);
        final rows = List<Map<String, dynamic>>.from(qr.data);
        final summaryRows = rows.take(2).map((r) =>
          r.entries.map((e) => '${e.key}=${e.value}').join(', ')
        ).join(' | ');
        resultSummary = '${rows.length} rows. Columns: ${sqlColumns.join(", ")}. Sample: $summaryRows';
        if (resultSummary.length > 300) {
          resultSummary = resultSummary.substring(0, 300) + '...';
        }
      }

      _conversationHistory.add({
        'question': originalQuestion,
        'result_summary': resultSummary,
        'sql_columns': sqlColumns,
      });
      _contextTurnCount++;

      setState(() {
        _messages.add({
          'type': 'ai_response',
          'content': result['ai_response'],
          'query_result': result['query_result'],
          'generated_sql': result['generated_sql'],
          'suggestions': result['suggestions'],
          'original_question': originalQuestion,
          'timestamp': DateTime.now(),
          'source': result['source'] ?? 'ai',
          'provider': result['provider'] ?? provider,
          'token_usage': result['token_usage'],
          'context_turn': _contextTurnCount,
          'applied_filters': filters,
          'reasoning': result['reasoning'],
          'compare_result': result['compare_result'],
        });
        _isLoading = false; _loadingStartTime = null;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'type': 'error',
          'content': 'Error: $e',
          'timestamp': DateTime.now(),
        });
        _isLoading = false; _loadingStartTime = null;
      });
    }
  }

  Widget _buildDateRangeFilter(Map<String, dynamic> message) {
    // Extract current dates from SQL
    final sql = message['generated_sql']?.toString() ?? '';
    final fromMatch = RegExp(r"date\s*>=\s*'(\d{8})'").firstMatch(sql);
    final toMatch = RegExp(r"date\s*<=\s*'(\d{8})'").firstMatch(sql);

    if (fromMatch == null || toMatch == null) return const SizedBox.shrink();

    final currentFrom = message['_filterFromDate']?.toString() ?? fromMatch.group(1)!;
    final currentTo = message['_filterToDate']?.toString() ?? toMatch.group(1)!;

    // Parse YYYYMMDD to DateTime for display
    DateTime parseYmd(String ymd) {
      return DateTime(
        int.parse(ymd.substring(0, 4)),
        int.parse(ymd.substring(4, 6)),
        int.parse(ymd.substring(6, 8)),
      );
    }
    String formatDisplay(String ymd) {
      final d = parseYmd(ymd);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    }
    String dateToYmd(DateTime d) {
      return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, size: 14, color: Colors.blue[400]),
          const SizedBox(width: 6),
          // From date chip
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: parseYmd(currentFrom),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                _reRunWithNewDates(message, dateToYmd(picked), currentTo);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                formatDisplay(currentFrom),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue[700]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('→', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ),
          // To date chip
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: parseYmd(currentTo),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                _reRunWithNewDates(message, currentFrom, dateToYmd(picked));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                formatDisplay(currentTo),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue[700]),
              ),
            ),
          ),
          const Spacer(),
          // Quick presets
          _buildDatePreset('FY', message, currentFrom, currentTo, '20250401', '20260331'),
          const SizedBox(width: 4),
          _buildDatePreset('Q3', message, currentFrom, currentTo, '20251001', '20251231'),
          const SizedBox(width: 4),
          _buildDatePreset('Q4', message, currentFrom, currentTo, '20260101', '20260331'),
        ],
      ),
    );
  }

  Widget _buildDatePreset(String label, Map<String, dynamic> message,
      String currentFrom, String currentTo, String presetFrom, String presetTo) {
    final isActive = currentFrom == presetFrom && currentTo == presetTo;
    return GestureDetector(
      onTap: isActive ? null : () => _reRunWithNewDates(message, presetFrom, presetTo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? Colors.blue.withOpacity(0.4) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.blue[700] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Future<void> _reRunWithNewDates(Map<String, dynamic> message, String newFrom, String newTo) async {
    final sql = message['generated_sql']?.toString() ?? '';
    if (sql.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final newResult = await AiQaService.reRunWithDates(
        originalSql: sql,
        newFromDate: newFrom,
        newToDate: newTo,
      );

      setState(() {
        // Update the message in place
        final idx = _messages.indexOf(message);
        if (idx >= 0) {
          _messages[idx]['query_result'] = newResult;
          _messages[idx]['_filterFromDate'] = newFrom;
          _messages[idx]['_filterToDate'] = newTo;
          // Update SQL with new dates too
          String updatedSql = sql.replaceAllMapped(
            RegExp(r"date\s*>=\s*'(\d{8})'"), (m) => "date >= '$newFrom'",
          );
          updatedSql = updatedSql.replaceAllMapped(
            RegExp(r"date\s*<=\s*'(\d{8})'"), (m) => "date <= '$newTo'",
          );
          _messages[idx]['generated_sql'] = updatedSql;
        }
        _isLoading = false; _loadingStartTime = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSourceAndTokenInfo(Map<String, dynamic> message) {
    final source = message['source']?.toString() ?? 'ai';
    final provider = message['provider']?.toString() ?? 'claude';
    final isLocal = source == 'local';
    final isBoth = source == 'both';
    final tokenUsage = message['token_usage'] as Map<String, dynamic>?;
    final contextTurn = message['context_turn'] as int?;

    String badge;
    Color badgeColor;
    if (isLocal) {
      badge = '⚡ Local';
      badgeColor = Colors.grey;
    } else if (isBoth) {
      badge = '⚔️ Both';
      badgeColor = Colors.orange;
    } else if (provider == 'deepseek') {
      badge = '🟡 Kimi K2.5';
      badgeColor = Colors.amber;
    } else if (provider == 'llama') {
      badge = '🦙 Llama 8B';
      badgeColor = Colors.green;
    } else if (provider == 'qwen') {
      badge = '🧠 Qwen3 32B';
      badgeColor = Colors.cyan;
    } else if (provider == 'openrouter') {
      badge = '🌐 OR-Qwen3';
      badgeColor = Colors.teal;
    } else if (provider == 'qwen3_8b') {
      badge = '🔷 Q3-8B HF';
      badgeColor = Colors.indigo;
    } else if (provider == 'qwen3_4b') {
      badge = '🔹 Q3-1.7B';
      badgeColor = Colors.blue;
    } else if (provider == 'glm5') {
      badge = '🟢 GLM-5';
      badgeColor = Colors.green;
    } else {
      badge = '🟣 Claude';
      badgeColor = Colors.purple;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source badge + context turn
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: badgeColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
            if (contextTurn != null) ...[
              const SizedBox(width: 6),
              Text(
                'Turn $contextTurn/$_maxContextTurns',
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              ),
            ],
            if (tokenUsage != null) ...[
              const SizedBox(width: 6),
              Text(
                '${tokenUsage['input_tokens'] ?? 0}↑ ${tokenUsage['output_tokens'] ?? 0}↓ tokens',
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              ),
            ],
            const Spacer(),
            // Expand debug button
            if (tokenUsage != null)
              GestureDetector(
                onTap: () => _showTokenDebug(message),
                child: Text(
                  'Debug',
                  style: TextStyle(fontSize: 9, color: Colors.purple[300], decoration: TextDecoration.underline),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showTokenDebug(Map<String, dynamic> message) {
    final tokenUsage = message['token_usage'] as Map<String, dynamic>?;
    if (tokenUsage == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Context Window Debug', style: TextStyle(fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _debugRow('Source', message['source']?.toString() ?? 'ai'),
              _debugRow('Turn', '${message['context_turn'] ?? '-'} / $_maxContextTurns'),
              _debugRow('Input Tokens', '${tokenUsage['input_tokens'] ?? 0}'),
              _debugRow('Output Tokens', '${tokenUsage['output_tokens'] ?? 0}'),
              _debugRow('Context Turns Sent', '${tokenUsage['context_turns'] ?? 0}'),
              const Divider(),
              const Text('System Prompt Preview:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  tokenUsage['system_prompt_preview']?.toString() ?? 'N/A',
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              const Text('User Message Sent:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  tokenUsage['user_message_preview']?.toString() ?? 'N/A',
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Conversation History Sent:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ..._conversationHistory.asMap().entries.map((entry) {
                final i = entry.key + 1;
                final turn = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Turn $i: ${turn['question']}\n  → ${(turn['result_summary']?.toString() ?? 'no result').substring(0, (turn['result_summary']?.toString().length ?? 0).clamp(0, 100))}',
                    style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return '0';
    if (value is double) {
      if (value == value.truncateToDouble()) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(2);
    }
    if (value is int) return value.toString();
    final str = value.toString();
    return str.isEmpty ? '0' : str;
  }

  Widget _buildQueryResultTable(dynamic queryResult) {
    if (queryResult.hasError) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Error: ${queryResult.error}',
          style: TextStyle(fontSize: 12, color: Colors.red[700]),
        ),
      );
    }

    if (queryResult.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No results found (${queryResult.formattedExecutionTime})',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final List<String> columns = List<String>.from(queryResult.columnNames);
    final List<Map<String, dynamic>> rows =
        List<Map<String, dynamic>>.from(queryResult.data);
    final displayRows = rows; // Show all results, no pagination limit

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 8,
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 48,
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              columns: columns
                  .map<DataColumn>((col) => DataColumn(label: Text(col)))
                  .toList(),
              rows: displayRows
                  .map<DataRow>((row) => DataRow(
                        cells: columns
                            .map<DataCell>((col) => DataCell(
                                  Text(
                                    _formatCellValue(row[col]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                      ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${rows.length} result${rows.length == 1 ? '' : 's'} (${queryResult.formattedExecutionTime})',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSnapshotDebug() async {
    setState(() => _isLoading = true);

    try {
      // Force rebuild the snapshot and capture it
      await AiQaService.refreshSummary(widget.companyGuid);

      // Access the cached snapshot via a test query to the service
      // We'll use a lightweight approach: rebuild and inspect
      final snapshot = await AiQaService.getSnapshotDebug(widget.companyGuid);

      setState(() => _isLoading = false);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Company Snapshot Debug',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                // Summary stats
                if (snapshot != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _debugChip('Groups', snapshot['groups']?.length ?? 0, Colors.blue),
                      _debugChip('Ledgers', snapshot['ledgers']?.length ?? 0, Colors.green),
                      _debugChip('Active Ledgers', snapshot['active_ledgers']?.length ?? 0, Colors.orange),
                      _debugChip('Voucher Types', snapshot['voucher_summary']?.length ?? 0, Colors.purple),
                      _debugChip('Stock Items', snapshot['stock_items']?.length ?? 0, Colors.red),
                      _debugChip('Stock Movement', snapshot['stock_movement']?.length ?? 0, Colors.pink),
                      _debugChip('Top Parties', snapshot['top_parties']?.length ?? 0, Colors.indigo),
                      _debugChip('Expense Ledgers', snapshot['expense_ledgers']?.length ?? 0, Colors.deepOrange),
                      _debugChip('Income Ledgers', snapshot['income_ledgers']?.length ?? 0, Colors.teal),
                      _debugChip('Bank/Cash', snapshot['bank_cash_ledgers']?.length ?? 0, Colors.brown),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                ],
                // Full snapshot JSON
                Expanded(
                  child: snapshot != null
                      ? DefaultTabController(
                          length: 14,
                          child: Column(
                            children: [
                              SizedBox(
                                height: 40,
                                child: TabBar(
                                  isScrollable: true,
                                  labelColor: Colors.teal,
                                  unselectedLabelColor: Colors.grey,
                                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  tabs: const [
                                    Tab(text: 'Company'),
                                    Tab(text: 'Vouchers'),
                                    Tab(text: 'Active Ldgr'),
                                    Tab(text: 'Expenses'),
                                    Tab(text: 'Income'),
                                    Tab(text: 'Parties'),
                                    Tab(text: 'Bank/Cash'),
                                    Tab(text: 'Stock'),
                                    Tab(text: 'Stock Mvmt'),
                                    Tab(text: 'Groups'),
                                    Tab(text: 'Ledgers'),
                                    Tab(text: 'Salary'),
                                    Tab(text: 'Deductions'),
                                    Tab(text: 'Tax'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _debugJsonView(snapshot['company_info']),
                                    _debugListView(snapshot['voucher_summary'], 'voucher_type', 'voucher_count'),
                                    _debugListView(snapshot['active_ledgers'], 'ledger_name', 'txn_count'),
                                    _debugListView(snapshot['expense_ledgers'], 'ledger_name', 'total_debit'),
                                    _debugListView(snapshot['income_ledgers'], 'ledger_name', 'total_credit'),
                                    _debugListView(snapshot['top_parties'], 'party_name', 'txn_count'),
                                    _debugListView(snapshot['bank_cash_ledgers'], 'ledger_name', 'opening_balance'),
                                    _debugListView(snapshot['stock_items'], 'name', 'opening_value'),
                                    _debugListView(snapshot['stock_movement'], 'stock_item_name', 'txn_count'),
                                    _debugListView(snapshot['groups'], 'name', 'parent_name'),
                                    _debugListView(snapshot['ledgers'], 'name', 'parent'),
                                    _debugSalaryView(snapshot['salary_per_person'], snapshot['salary_breakdown']),
                                    _debugDeductionsView(snapshot['salary_deductions']),
                                    _debugTaxView(snapshot['tax_ledgers']),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Center(
                          child: Text(
                            'No snapshot data available.\nMake sure company has synced data.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Snapshot error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _debugChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          count.toString(),
          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.1),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _debugJsonView(dynamic data) {
    if (data == null) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.grey)));
    }
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: SelectableText(
        jsonStr,
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
      ),
    );
  }

  /// Universal summary card — auto-detects result type from column names and renders
  /// a smart summary above the raw data table.
  ///
  /// Handles: salary, deductions, sales, purchase, expenses, receivables, payables,
  /// payments, receipts, stock, ledger transactions, trial balance, P&L, etc.
  Widget _buildResultSummaryCard(dynamic queryResult, String question) {
    if (queryResult == null || queryResult.hasError || queryResult.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<String> columns = List<String>.from(queryResult.columnNames);
    final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(queryResult.data);
    final colLower = columns.map((c) => c.toLowerCase()).toList();
    final q = question.toLowerCase();

    // ── Detect result type from columns ──
    final _ResultType resultType = _detectResultType(colLower, q);

    // ── Find key columns ──
    final String amountCol = _findAmountColumn(columns, colLower, resultType);
    final String nameCol = _findNameColumn(columns, colLower);
    final String groupCol = _findGroupColumn(columns, colLower);

    if (amountCol.isEmpty && resultType != _ResultType.debitCredit) {
      return const SizedBox.shrink();
    }

    // ── Calculate totals ──
    num grandTotal = 0;
    if (amountCol.isNotEmpty) {
      for (final row in rows) {
        final val = row[amountCol];
        if (val is num) grandTotal += val.abs();
      }
    }

    // For debit/credit results, compute separate totals
    num totalDebit = 0, totalCredit = 0;
    String? debitCol, creditCol;
    if (resultType == _ResultType.debitCredit || resultType == _ResultType.ledgerTxn) {
      debitCol = _findCol(columns, colLower, ['debit_total', 'debit', 'debit_amount']);
      creditCol = _findCol(columns, colLower, ['credit_total', 'credit', 'credit_amount']);
      if (debitCol != null) {
        for (final row in rows) {
          final val = row[debitCol];
          if (val is num) totalDebit += val.abs();
        }
      }
      if (creditCol != null) {
        for (final row in rows) {
          final val = row[creditCol];
          if (val is num) totalCredit += val.abs();
        }
      }
      if (grandTotal == 0) grandTotal = (totalDebit - totalCredit).abs();
    }

    // ── Get unique name (if single entity) ──
    String entityName = '';
    if (nameCol.isNotEmpty) {
      final names = rows.map((r) => r[nameCol]?.toString() ?? '').toSet().where((n) => n.isNotEmpty);
      if (names.length == 1) entityName = names.first;
    }

    // ── Component/category breakdown ──
    Map<String, num> componentTotals = {};
    String componentCol = _findComponentColumn(columns, colLower);
    if (componentCol.isNotEmpty && rows.length > 1) {
      for (final row in rows) {
        final comp = row[componentCol]?.toString() ?? '?';
        final val = amountCol.isNotEmpty ? row[amountCol] : null;
        if (val is num) {
          componentTotals[comp] = (componentTotals[comp] ?? 0) + val.abs();
        }
      }
      // Don't show breakdown if it's 1:1 with rows (no aggregation benefit)
      if (componentTotals.length == rows.length && componentTotals.length > 5) {
        componentTotals.clear();
      }
    }

    // ── Theme ──
    final theme = _getResultTheme(resultType, q);
    final int entityCount = nameCol.isNotEmpty
        ? rows.map((r) => r[nameCol]?.toString()).toSet().length
        : rows.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.color.withOpacity(0.1), theme.color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + Title/Entity + Grand Total
          Row(
            children: [
              Icon(theme.icon, size: 16, color: theme.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entityName.isNotEmpty
                      ? entityName
                      : theme.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (grandTotal > 0)
                Text(
                  '₹${_formatIndianNumber(grandTotal)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.color),
                ),
            ],
          ),
          // Row 2: Debit / Credit breakdown (if applicable)
          if (resultType == _ResultType.debitCredit || resultType == _ResultType.ledgerTxn) ...[
            if (totalDebit > 0 || totalCredit > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (totalDebit > 0)
                      _buildMiniChip('Debit: ₹${_formatIndianNumber(totalDebit)}', Colors.red),
                    if (totalDebit > 0 && totalCredit > 0) const SizedBox(width: 6),
                    if (totalCredit > 0)
                      _buildMiniChip('Credit: ₹${_formatIndianNumber(totalCredit)}', Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Net: ₹${_formatIndianNumber((totalDebit - totalCredit).abs())}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
          ],
          // Row 3: Component breakdown chips
          if (componentTotals.isNotEmpty && componentTotals.length <= 8) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: componentTotals.entries.map((entry) {
                final color = _getSalaryComponentColor(entry.key);
                return _buildMiniChip(
                  '${entry.key}: ₹${_formatIndianNumber(entry.value)}',
                  color,
                );
              }).toList(),
            ),
          ],
          // Row 4: Entity count + row count
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              entityCount > 1 && nameCol.isNotEmpty
                  ? '$entityCount ${theme.entityLabel} · ${rows.length} rows'
                  : '${rows.length} ${rows.length == 1 ? "result" : "rows"}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Result type detection ──

  _ResultType _detectResultType(List<String> colLower, String question) {
    final hasDebit = colLower.any((c) => c.contains('debit'));
    final hasCredit = colLower.any((c) => c.contains('credit'));
    final hasOutstanding = colLower.any((c) => c.contains('outstanding'));
    final hasComponent = colLower.any((c) =>
        c.contains('component') || c == 'ledger_name' || c == 'component_type');
    final hasDeduction = colLower.any((c) => c.contains('deduction') || c.contains('tax_'));
    final hasStock = colLower.any((c) =>
        c.contains('quantity') || c.contains('stock') || c.contains('base_units'));
    final hasNetSales = colLower.any((c) => c.contains('net_sales'));
    final hasNetPurchase = colLower.any((c) => c.contains('net_purchase'));

    if (hasDeduction) return _ResultType.deduction;
    if (hasComponent) return _ResultType.breakdown;
    if (hasOutstanding) return _ResultType.outstanding;
    if (hasNetSales) return _ResultType.sales;
    if (hasNetPurchase) return _ResultType.purchase;
    if (hasStock) return _ResultType.stock;
    if (hasDebit && hasCredit) return _ResultType.debitCredit;

    // Fallback to question-based
    if (question.contains('salary') || question.contains('payroll') || question.contains('ctc')) {
      return _ResultType.salary;
    }
    if (question.contains('tds') || question.contains('deduction') || question.contains('epf')) {
      return _ResultType.deduction;
    }
    if (question.contains('receiv') || question.contains('debtor')) return _ResultType.outstanding;
    if (question.contains('payable') || question.contains('creditor')) return _ResultType.outstanding;
    if (question.contains('payment') || question.contains('paid')) return _ResultType.payment;
    if (question.contains('receipt') || question.contains('received')) return _ResultType.receipt;
    if (question.contains('expense') || question.contains('cost')) return _ResultType.expense;
    if (question.contains('stock') || question.contains('inventory')) return _ResultType.stock;
    if (question.contains('profit') || question.contains('loss') || question.contains('p&l')) {
      return _ResultType.profitLoss;
    }

    return _ResultType.generic;
  }

  // ── Column finders ──

  String _findAmountColumn(List<String> columns, List<String> colLower, _ResultType type) {
    // Priority 1: Net/total columns (the "answer" number)
    final netPriorities = [
      'net_sales', 'net_purchase', 'net_revenue', 'net_amount', 'net_profit',
      'net_tax', 'net_salary', 'gross_profit', 'outstanding',
      'total_salary', 'total_amount', 'total_tds_amount', 'total_paid',
      'closing_balance', 'amount', 'value',
    ];
    for (final p in netPriorities) {
      final idx = colLower.indexOf(p);
      if (idx >= 0) return columns[idx];
    }
    // Priority 2: Any column starting with 'net_' or 'total_'
    for (int i = 0; i < colLower.length; i++) {
      if (colLower[i].startsWith('net_') || colLower[i].startsWith('total_')) {
        return columns[i];
      }
    }
    // Priority 3: Any column with 'amount', 'outstanding', 'salary', 'value'
    for (int i = 0; i < colLower.length; i++) {
      final c = colLower[i];
      if (c.contains('amount') || c.contains('outstanding') ||
          c.contains('salary') || c.contains('value')) {
        return columns[i];
      }
    }
    // Priority 4 (last resort): debit_total or credit_total
    for (int i = 0; i < colLower.length; i++) {
      if (colLower[i] == 'debit_total' || colLower[i] == 'credit_total') {
        return columns[i];
      }
    }
    return '';
  }

  String _findNameColumn(List<String> columns, List<String> colLower) {
    // Specific entity columns first (never ambiguous)
    final highPriority = ['employee_name', 'party_name', 'party_names', 'customer', 'supplier', 'stock_item_name'];
    for (final p in highPriority) {
      final idx = colLower.indexOf(p);
      if (idx >= 0) return columns[idx];
    }
    // 'name' as standalone
    final nameIdx = colLower.indexOf('name');
    if (nameIdx >= 0) return columns[nameIdx];
    // 'ledger_name' ONLY if no amount/debit/credit columns beside it
    // (if there are, it's a breakdown and ledger_name is the component, not entity)
    final hasAmountCols = colLower.any((c) =>
        c.contains('debit') || c.contains('credit') || c.contains('net_amount') || c.contains('outstanding'));
    final ledgerIdx = colLower.indexOf('ledger_name');
    if (ledgerIdx >= 0 && !hasAmountCols) return columns[ledgerIdx];
    // Fallback: any column with 'party' or 'employee'
    for (int i = 0; i < colLower.length; i++) {
      final c = colLower[i];
      if (c.contains('party') || c.contains('employee')) return columns[i];
    }
    return '';
  }

  String _findGroupColumn(List<String> columns, List<String> colLower) {
    for (int i = 0; i < colLower.length; i++) {
      if (colLower[i].contains('group')) return columns[i];
    }
    return '';
  }

  String _findComponentColumn(List<String> columns, List<String> colLower) {
    final priorities = [
      'component', 'component_type', 'deduction_type', 'tax_deduction_type',
      'ledger_name', 'voucher_type',
    ];
    for (final p in priorities) {
      final idx = colLower.indexOf(p);
      if (idx >= 0) return columns[idx];
    }
    return '';
  }

  String? _findCol(List<String> columns, List<String> colLower, List<String> candidates) {
    for (final c in candidates) {
      final idx = colLower.indexOf(c);
      if (idx >= 0) return columns[idx];
    }
    return null;
  }

  // ── Theme per result type ──

  _ResultTheme _getResultTheme(_ResultType type, String question) {
    switch (type) {
      case _ResultType.salary:
        return _ResultTheme(Colors.teal, Icons.account_balance_wallet, 'Total Salary', 'employees');
      case _ResultType.deduction:
        return _ResultTheme(Colors.orange, Icons.receipt_long, 'Total Deductions', 'employees');
      case _ResultType.breakdown:
        return _ResultTheme(Colors.teal, Icons.pie_chart_outline, 'Total', 'components');
      case _ResultType.sales:
        return _ResultTheme(Colors.green, Icons.trending_up, 'Total Sales', 'entries');
      case _ResultType.purchase:
        return _ResultTheme(Colors.blue, Icons.shopping_cart, 'Total Purchases', 'entries');
      case _ResultType.expense:
        return _ResultTheme(Colors.red[700]!, Icons.money_off, 'Total Expenses', 'ledgers');
      case _ResultType.outstanding:
        final isReceivable = question.contains('receiv') || question.contains('debtor');
        return _ResultTheme(
          isReceivable ? Colors.orange : Colors.purple,
          isReceivable ? Icons.call_received : Icons.call_made,
          isReceivable ? 'Total Receivable' : 'Total Payable',
          'parties',
        );
      case _ResultType.payment:
        return _ResultTheme(Colors.red, Icons.arrow_upward, 'Total Paid', 'payments');
      case _ResultType.receipt:
        return _ResultTheme(Colors.green, Icons.arrow_downward, 'Total Received', 'receipts');
      case _ResultType.stock:
        return _ResultTheme(Colors.brown, Icons.inventory_2, 'Total Stock Value', 'items');
      case _ResultType.profitLoss:
        return _ResultTheme(Colors.indigo, Icons.assessment, 'Profit & Loss', 'items');
      case _ResultType.debitCredit:
      case _ResultType.ledgerTxn:
        return _ResultTheme(Colors.blueGrey, Icons.swap_horiz, 'Summary', 'entries');
      case _ResultType.generic:
        return _ResultTheme(Colors.blueGrey, Icons.table_chart, 'Summary', 'rows');
    }
  }

  Color _getSalaryComponentColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('salary') && !n.contains('tds') && !n.contains('bonus')) return Colors.green;
    if (n.contains('bonus') || n.contains('incentive')) return Colors.purple;
    if (n.contains('tds')) return Colors.red;
    if (n.contains('professional') || n.contains('prof tax')) return Colors.orange;
    if (n.contains('epf') || n.contains('provident')) return Colors.blue;
    if (n.contains('esi')) return Colors.indigo;
    if (n.contains('sales') || n.contains('revenue')) return Colors.green;
    if (n.contains('purchase')) return Colors.blue;
    if (n.contains('expense') || n.contains('cost')) return Colors.red;
    return Colors.grey;
  }

  String _formatIndianNumber(num value) {
    final absVal = value.abs();
    if (absVal >= 10000000) return '${(absVal / 10000000).toStringAsFixed(2)} Cr';
    if (absVal >= 100000) return '${(absVal / 100000).toStringAsFixed(2)} L';
    final intVal = absVal.round();
    final str = intVal.toString();
    if (str.length <= 3) return str;
    String result = str.substring(str.length - 3);
    String remaining = str.substring(0, str.length - 3);
    while (remaining.length > 2) {
      result = '${remaining.substring(remaining.length - 2)},$result';
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) result = '$remaining,$result';
    return result;
  }

  bool _isSalaryQuery(String content) {
    final q = content.toLowerCase();
    return q.contains('salary') || q.contains('highest paid') || q.contains('top salary') ||
           q.contains('payroll') || q.contains('ctc') || q.contains('wage');
  }

  bool _isTdsQuery(String content) {
    final q = content.toLowerCase();
    return q.contains('tds') || q.contains('professional tax') || q.contains('prof tax');
  }

  Widget _buildCalcNote(String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.blue[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 10, color: Colors.blue[800], fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _debugSalaryView(List<dynamic>? items, List<dynamic>? breakdown) {
    if (items == null || items.isEmpty) {
      return const Center(
        child: Text(
          'No salary data found.\nCheck if salary ledgers exist in this company.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Build breakdown map: employee_name → [{component, amount}, ...]
    final Map<String, List<Map<String, dynamic>>> breakdownMap = {};
    if (breakdown != null) {
      for (final item in breakdown) {
        final emp = item['employee_name']?.toString() ?? '';
        breakdownMap.putIfAbsent(emp, () => []);
        breakdownMap[emp]!.add({
          'component': item['component']?.toString() ?? '?',
          'amount': (item['amount'] as num?) ?? 0,
        });
      }
    }

    // Calculate totals
    num grandTotal = 0;
    for (final item in items) {
      grandTotal += (item['total_salary'] as num?) ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people, size: 16, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length} employees | Total Salary: ₹${_formatNum(grandTotal)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Includes: Direct expense debits (Salary, Bonus, Incentive, etc.)\n'
                'Excludes: TDS, Prof Tax, EPF, ESI (deductions from employee, not expense)',
                style: TextStyle(fontSize: 9, color: Colors.teal[700], fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        // Employee list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(4),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;
              final name = item['employee_name']?.toString() ?? '—';
              final total = (item['total_salary'] as num?) ?? 0;
              final count = (item['payment_count'] as num?) ?? 0;

              // Get per-ledger breakdown for this employee
              final empBreakdown = breakdownMap[name] ?? [];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee name and total
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.teal.withOpacity(0.2),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '₹${_formatNum(total)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Payment count
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        '$count vouchers',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                    // Per-ledger breakdown with amounts
                    if (empBreakdown.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, top: 4),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: empBreakdown.map((comp) {
                            final ledger = comp['component'] as String;
                            final amount = comp['amount'] as num;
                            // Color code
                            Color chipColor = Colors.grey;
                            if (ledger.toLowerCase().contains('salary') && !ledger.toLowerCase().contains('tds')) {
                              chipColor = Colors.green;
                            } else if (ledger.toLowerCase().contains('tds') || ledger.toLowerCase().contains('tax')) {
                              chipColor = Colors.orange;
                            } else if (ledger.toLowerCase().contains('epf') || ledger.toLowerCase().contains('esi') || ledger.toLowerCase().contains('provident')) {
                              chipColor = Colors.blue;
                            } else if (ledger.toLowerCase().contains('bonus') || ledger.toLowerCase().contains('incentive')) {
                              chipColor = Colors.purple;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: chipColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: chipColor.withOpacity(0.3), width: 0.5),
                              ),
                              child: Text(
                                '$ledger: ₹${_formatNum(amount)}',
                                style: TextStyle(fontSize: 9, color: chipColor, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _debugDeductionsView(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return const Center(
        child: Text(
          'No deductions found on salary vouchers.\n(TDS, Prof Tax, EPF, ESI etc.)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Group by deduction_type for summary
    final Map<String, num> typeTotals = {};
    final Map<String, int> typeEmployeeCount = {};
    for (final item in items) {
      final dtype = item['deduction_type']?.toString() ?? '?';
      final amount = (item['total_amount'] as num?) ?? 0;
      typeTotals[dtype] = (typeTotals[dtype] ?? 0) + amount;
      typeEmployeeCount[dtype] = (typeEmployeeCount[dtype] ?? 0) + 1;
    }

    final sortedTypes = typeTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Group by employee
    final Map<String, List<Map<String, dynamic>>> byEmployee = {};
    for (final item in items) {
      final emp = item['employee_name']?.toString() ?? '';
      byEmployee.putIfAbsent(emp, () => []);
      byEmployee[emp]!.add({
        'type': item['deduction_type']?.toString() ?? '?',
        'amount': (item['total_amount'] as num?) ?? 0,
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary by type
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deduction Summary (from salary vouchers)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 4),
              ...sortedTypes.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _getDeductionColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${entry.key} (${typeEmployeeCount[entry.key]} employees)',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Text(
                      '₹${_formatNum(entry.value)}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getDeductionColor(entry.key)),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        // Per employee detail
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(4),
            itemCount: byEmployee.length,
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemBuilder: (context, index) {
              final emp = byEmployee.keys.elementAt(index);
              final deductions = byEmployee[emp]!;
              final empTotal = deductions.fold<num>(0, (sum, d) => sum + (d['amount'] as num));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(emp, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      Text('₹${_formatNum(empTotal)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: deductions.map((d) {
                      final dtype = d['type'] as String;
                      final amount = d['amount'] as num;
                      final color = _getDeductionColor(dtype);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$dtype: ₹${_formatNum(amount)}',
                          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _debugTaxView(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return const Center(
        child: Text(
          'No tax ledgers found under Duties & Taxes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Categorize
    final gst = <Map<String, dynamic>>[];
    final tds = <Map<String, dynamic>>[];
    final other = <Map<String, dynamic>>[];
    for (final item in items) {
      final name = (item['ledger_name']?.toString() ?? '').toLowerCase();
      if (name.contains('gst') || name.contains('cgst') || name.contains('sgst') || name.contains('igst')) {
        gst.add(Map<String, dynamic>.from(item));
      } else if (name.contains('tds')) {
        tds.add(Map<String, dynamic>.from(item));
      } else {
        other.add(Map<String, dynamic>.from(item));
      }
    }

    Widget buildCategory(String title, List<Map<String, dynamic>> ledgers, Color color) {
      if (ledgers.isEmpty) return const SizedBox.shrink();
      final totalDebit = ledgers.fold<num>(0, (s, l) => s + ((l['debit_total'] as num?) ?? 0));
      final totalCredit = ledgers.fold<num>(0, (s, l) => s + ((l['credit_total'] as num?) ?? 0));
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Text('Dr: ₹${_formatNum(totalDebit)}', style: TextStyle(fontSize: 10, color: Colors.red[400])),
                const SizedBox(width: 8),
                Text('Cr: ₹${_formatNum(totalCredit)}', style: TextStyle(fontSize: 10, color: Colors.green[400])),
              ],
            ),
            const SizedBox(height: 4),
            ...ledgers.map((l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l['ledger_name']?.toString() ?? '?',
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Dr ₹${_formatNum((l['debit_total'] as num?) ?? 0)}',
                    style: TextStyle(fontSize: 9, color: Colors.red[300]),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cr ₹${_formatNum((l['credit_total'] as num?) ?? 0)}',
                    style: TextStyle(fontSize: 9, color: Colors.green[300]),
                  ),
                ],
              ),
            )),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${items.length} tax ledgers found', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 6),
          buildCategory('GST (${gst.length})', gst, Colors.blue),
          buildCategory('TDS (${tds.length})', tds, Colors.red),
          buildCategory('Other Tax (${other.length})', other, Colors.grey),
        ],
      ),
    );
  }

  Color _getDeductionColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('tds')) return Colors.red;
    if (n.contains('professional') || n.contains('prof')) return Colors.orange;
    if (n.contains('epf') || n.contains('provident')) return Colors.blue;
    if (n.contains('esi')) return Colors.indigo;
    return Colors.grey;
  }

  String _formatNum(num value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(2)} Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(2)} L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  Widget _debugListView(List<dynamic>? items, String nameKey, String valueKey) {
    if (items == null || items.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index] as Map<String, dynamic>;
        final name = item[nameKey]?.toString() ?? '—';
        final value = item[valueKey];
        final valueStr = value is num
            ? (value is double ? '₹${value.toStringAsFixed(2)}' : value.toString())
            : value?.toString() ?? '—';

        // Show all fields in subtitle
        final otherFields = item.entries
            .where((e) => e.key != nameKey)
            .map((e) {
              final v = e.value;
              if (v is num && v > 999) {
                return '${e.key}: ₹${v.toStringAsFixed(v is double ? 2 : 0)}';
              }
              return '${e.key}: $v';
            })
            .join(' | ');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    valueStr,
                    style: TextStyle(fontSize: 12, color: Colors.teal[700], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (otherFields.isNotEmpty)
                Text(
                  otherFields,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Entity detection from question keywords ──
  static const Map<String, List<String>> _entityKeywords = {
    'party': ['party', 'customer', 'client', 'debtor', 'buyer'],
    'supplier': ['supplier', 'vendor', 'creditor', 'seller'],
    'employee': ['employee', 'staff', 'person', 'salary of', 'tds of'],
    'stock_item': ['item', 'product', 'stock item', 'material', 'goods'],
    'expense_head': ['expense head', 'cost head', 'expense category'],
    'voucher_type': ['voucher type', 'type of voucher'],
  };

  /// Detect which entity filters are relevant for this question
  Map<String, bool> _detectEntities(String question) {
    final q = question.toLowerCase();
    final detected = <String, bool>{};

    // Only detect if question implies listing/filtering by entity
    // Keywords that suggest "show me options": by, wise, for, of, per, each, specific
    final filterHints = ['by ', 'wise', ' for ', ' of ', ' per ', 'each ', 'specific ',
        'particular', 'select', 'choose', 'which ', 'filter'];
    final hasFilterIntent = filterHints.any((h) => q.contains(h));

    // Direct name triggers (always show filter regardless of intent)
    final directTriggers = {
      'party': ['party name', 'customer name', 'by party', 'by customer', 'partywise', 'party wise', 'customerwise', 'customer wise'],
      'supplier': ['supplier name', 'vendor name', 'by supplier', 'by vendor', 'supplierwise', 'supplier wise', 'vendorwise', 'vendor wise'],
      'employee': ['employee name', 'staff name', 'by employee', 'employeewise', 'employee wise', 'salary of', 'tds of'],
      'stock_item': ['item name', 'product name', 'by item', 'by product', 'itemwise', 'item wise', 'productwise', 'product wise'],
    };

    for (final entry in directTriggers.entries) {
      if (entry.value.any((t) => q.contains(t))) {
        detected[entry.key] = true;
      }
    }

    // If filter intent + entity keyword present
    if (hasFilterIntent) {
      for (final entry in _entityKeywords.entries) {
        if (!detected.containsKey(entry.key) && entry.value.any((k) => q.contains(k))) {
          detected[entry.key] = true;
        }
      }
    }

    return detected;
  }

  /// Load dropdown options from snapshot data
  Future<Map<String, List<String>>> _loadFilterOptions(Map<String, bool> entities) async {
    final snapshot = await AiQaService.getSnapshotDebug(widget.companyGuid);
    if (snapshot == null) return {};

    final options = <String, List<String>>{};

    if (entities.containsKey('party')) {
      // Sundry Debtors from top_parties
      final parties = (snapshot['top_parties'] as List?)
          ?.where((p) {
            final group = (p['group_name']?.toString() ?? '').toLowerCase();
            return group.contains('debtor') || group.contains('customer');
          })
          .map((p) => p['party_name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList() ?? [];
      // If no debtors specifically, show all parties
      if (parties.isEmpty) {
        final allParties = (snapshot['top_parties'] as List?)
            ?.map((p) => p['party_name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList() ?? [];
        options['party'] = allParties;
      } else {
        options['party'] = parties;
      }
    }

    if (entities.containsKey('supplier')) {
      final suppliers = (snapshot['top_parties'] as List?)
          ?.where((p) {
            final group = (p['group_name']?.toString() ?? '').toLowerCase();
            return group.contains('creditor') || group.contains('supplier');
          })
          .map((p) => p['party_name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList() ?? [];
      if (suppliers.isEmpty) {
        final allParties = (snapshot['top_parties'] as List?)
            ?.map((p) => p['party_name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList() ?? [];
        options['supplier'] = allParties;
      } else {
        options['supplier'] = suppliers;
      }
    }

    if (entities.containsKey('employee')) {
      options['employee'] = (snapshot['salary_per_person'] as List?)
          ?.map((e) => e['employee_name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList() ?? [];
    }

    if (entities.containsKey('stock_item')) {
      options['stock_item'] = (snapshot['stock_items'] as List?)
          ?.map((s) => s['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList() ?? [];
    }

    if (entities.containsKey('expense_head')) {
      options['expense_head'] = (snapshot['expense_ledgers'] as List?)
          ?.map((e) => e['ledger_name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList() ?? [];
    }

    if (entities.containsKey('voucher_type')) {
      options['voucher_type'] = (snapshot['voucher_summary'] as List?)
          ?.map((v) => v['voucher_type']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList() ?? [];
    }

    return options;
  }

  /// Entity type display labels and icons
  static const Map<String, Map<String, dynamic>> _entityMeta = {
    'party': {'label': 'Customer / Party', 'icon': Icons.people},
    'supplier': {'label': 'Supplier / Vendor', 'icon': Icons.local_shipping},
    'employee': {'label': 'Employee', 'icon': Icons.badge},
    'stock_item': {'label': 'Stock Item', 'icon': Icons.inventory_2},
    'expense_head': {'label': 'Expense Head', 'icon': Icons.receipt_long},
    'voucher_type': {'label': 'Voucher Type', 'icon': Icons.description},
  };

  /// Run a preset question using local SQL templates (no AI API call).
  /// Falls back to AI if no template matches.
  Future<void> _runPresetQuery(String question) async {
    if (_isLoading) return;

    try {
      final templates = QueryTemplates.loadAll();
      final builder = QueryBuilder();
      final qLower = question.toLowerCase().trim();

      // Find matching template by sampleQuestions
      for (final t in templates) {
        for (final sq in t.sampleQuestions) {
          if (qLower == sq.toLowerCase() || qLower.contains(sq.toLowerCase()) || sq.toLowerCase().contains(qLower)) {
            debugPrint('[PRESET] Matched template: ${t.templateId} — ${t.description}');

            // Build dates (current FY)
            final now = DateTime.now();
            final fyStart = now.month < 4 ? DateTime(now.year - 1, 4, 1) : DateTime(now.year, 4, 1);
            final fromDate = '${fyStart.year}${fyStart.month.toString().padLeft(2, '0')}${fyStart.day.toString().padLeft(2, '0')}';
            final toDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

            final sql = builder.build(
              template: t,
              entities: {'from_date': fromDate, 'to_date': toDate},
              companyGuid: widget.companyGuid,
            );

            debugPrint('[PRESET] SQL built, executing locally...');

            // Show user message + loading
            setState(() {
              _messages.add({'type': 'user', 'content': question, 'timestamp': DateTime.now()});
              _isLoading = true;
              _loadingStartTime = DateTime.now();
            });

            // Execute SQL locally
            final db = await AiDependencies.databaseProvider!();
            final stopwatch = Stopwatch()..start();
            final results = await db.rawQuery(sql);
            stopwatch.stop();

            debugPrint('[PRESET] ${results.length} rows in ${stopwatch.elapsedMilliseconds}ms');

            final queryResult = QueryResult(
              data: results,
              rowCount: results.length,
              executionTimeMs: stopwatch.elapsedMilliseconds,
            );

            // Add to conversation history
            _conversationHistory.add({
              'question': question,
              'result_summary': '${results.length} rows',
              'sql_columns': queryResult.columnNames,
            });
            _contextTurnCount++;

            // Display result
            setState(() {
              _messages.add({
                'type': 'ai_response',
                'content': 'Found ${results.length} result${results.length == 1 ? '' : 's'}.',
                'query_result': queryResult,
                'generated_sql': sql,
                'suggestions': [],
                'original_question': question,
                'timestamp': DateTime.now(),
                'source': 'local_template',
                'provider': 'local',
                'context_turn': _contextTurnCount,
              });
              _isLoading = false;
              _loadingStartTime = null;
              _selectedMetric = null;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[PRESET] Error: $e');
      setState(() {
        _isLoading = false;
        _loadingStartTime = null;
      });
    }

    // No match — fall back to normal AI flow
    debugPrint('[PRESET] No template match, falling back to AI');
    _messageController.clear();
    _executeQuestion(question);
  }

  Future<void> _sendMessage() async {
    final question = _messageController.text.trim();
    if (question.isEmpty) return;

    // Check context window limit
    if (_contextTurnCount >= _maxContextTurns) {
      setState(() {
        _messages.add({
          'type': 'system',
          'content': '⚠️ Context window limit reached (${_maxContextTurns} questions). '
              'Start a new session for fresh context.',
          'timestamp': DateTime.now(),
        });
      });
      return;
    }

    // Detect entity filters from question
    final detectedEntities = _detectEntities(question);

    if (detectedEntities.isNotEmpty) {
      // Load dropdown options before showing
      setState(() => _isLoading = true);
      final options = await _loadFilterOptions(detectedEntities);
      setState(() => _isLoading = false);

      // Only show filter if we actually have dropdown data
      final hasOptions = options.values.any((v) => v.isNotEmpty);

      if (hasOptions) {
        setState(() {
          _pendingQuestion = question;
          _availableFilters = options;
          _selectedFilters = { for (final k in options.keys) k: 'ALL' };
          _showEntityFilters = true;
          _messageController.clear();
        });
        return;
      }
    }

    // No filters needed — execute directly
    _messageController.clear();
    _executeQuestion(question);
  }

  /// Execute after filter selection (or direct if no filters)
  Future<void> _executeQuestion(String question, {Map<String, String>? filters}) async {
    setState(() {
      _messages.add({
        'type': 'user',
        'content': question,
        'timestamp': DateTime.now(),
        'filters': filters,
      });
      _isLoading = true;
      _loadingStartTime = DateTime.now();
      _showEntityFilters = false;
      _pendingQuestion = null;
    });

    // Append filter context to question for Claude
    String enrichedQuestion = question;
    if (filters != null) {
      final filterParts = <String>[];
      for (final entry in filters.entries) {
        if (entry.value != 'ALL') {
          final label = _entityMeta[entry.key]?['label'] ?? entry.key;
          filterParts.add('$label: ${entry.value}');
        }
      }
      if (filterParts.isNotEmpty) {
        enrichedQuestion = '$question [Filter: ${filterParts.join(", ")}]';
      }
    }

    try {
      debugPrint('[AI DEBUG] Sending query to $_aiProvider: ${enrichedQuestion.substring(0, enrichedQuestion.length > 50 ? 50 : enrichedQuestion.length)}...');
      final stopwatch = Stopwatch()..start();

      final result = await AiQaService.sendQuery(
        companyGuid: widget.companyGuid,
        userId: widget.userId,
        message: enrichedQuestion,
        token: widget.token,
        conversationHistory: _conversationHistory,
        aiProvider: _aiProvider,
      );

      stopwatch.stop();
      debugPrint('[AI DEBUG] $_aiProvider responded in ${stopwatch.elapsedMilliseconds}ms. Success: ${result['success']}');
      if (result['provider'] != null) debugPrint('[AI DEBUG] Actual provider: ${result['provider']}');
      if (result['error'] != null) debugPrint('[AI DEBUG] Error: ${result['error']}');

      // *** STOCK VALUATION CALCULATION DETECTION ***
      // Check if SQL contains CLOSING_STOCK_CALCULATION_REQUIRED marker
      // This handles ALL stock value/quantity questions (closing, opening, item detail, etc.)
      final generatedSql = result['generated_sql']?.toString() ?? '';
      if (generatedSql.contains('CLOSING_STOCK_CALCULATION_REQUIRED')) {
        debugPrint('[STOCK VALUATION] Detected stock calculation request');

        // Extract markers from SQL
        final dateMatch = RegExp(r'CLOSING_STOCK_CALCULATION_REQUIRED[:\s]+(\d{8})').firstMatch(generatedSql);
        final itemFilterMatch = RegExp(r'STOCK_ITEM_FILTER[:\s]+(.+?)(?:\n|$)').firstMatch(generatedSql);
        final queryTypeMatch = RegExp(r'STOCK_QUERY_TYPE[:\s]+(\S+)').firstMatch(generatedSql);
        final compareDateMatch = RegExp(r'STOCK_COMPARE_DATE[:\s]+(\d{8})').firstMatch(generatedSql);

        final itemFilter = itemFilterMatch?.group(1)?.trim();
        final queryType = queryTypeMatch?.group(1)?.trim() ?? 'closing_stock';
        final compareDate = compareDateMatch?.group(1);

        if (dateMatch != null) {
          final targetDate = dateMatch.group(1)!;
          debugPrint('[STOCK VALUATION] Target date: $targetDate, Type: $queryType${itemFilter != null ? ", Item: $itemFilter" : ""}');

          try {
            // Get FY start date for the target date
            final fyStartDate = AiDependencies.fyStartDateGetter!(targetDate);
            debugPrint('[STOCK VALUATION] FY start: $fyStartDate, Target: $targetDate');

            // Call stock valuation via DI
            final stockResult = await AiDependencies.stockValuationCalculator!(
              companyGuid: widget.companyGuid,
              fromDate: fyStartDate,
              toDate: targetDate,
            );

            debugPrint('[STOCK VALUATION] Calculation complete. Total closing value: ${stockResult.closingStockValue}');

            if (itemFilter != null && itemFilter.isNotEmpty) {
              // *** SPECIFIC ITEM QUERY — show transactions + calculated value ***
              await _handleItemSpecificStockResult(
                result: result,
                stockResult: stockResult,
                itemFilter: itemFilter,
                targetDate: targetDate,
                fyStartDate: fyStartDate,
              );
            } else {
              // *** DISPATCH BASED ON QUERY TYPE ***
              switch (queryType) {
                case 'out_of_stock':
                  await _handleOutOfStockResult(result: result, stockResult: stockResult, targetDate: targetDate);
                  break;
                case 'low_stock':
                  _handleLowStockResult(result: result, stockResult: stockResult, targetDate: targetDate);
                  break;
                case 'by_category':
                  await _handleByCategoryResult(result: result, stockResult: stockResult, targetDate: targetDate);
                  break;
                case 'godown_breakdown':
                  await _handleGodownBreakdownResult(result: result, stockResult: stockResult, targetDate: targetDate);
                  break;
                case 'movement_report':
                  await _handleMovementReportResult(result: result, stockResult: stockResult, targetDate: targetDate, fyStartDate: fyStartDate);
                  break;
                case 'slow_moving':
                  await _handleSlowMovingResult(result: result, stockResult: stockResult, targetDate: targetDate, fyStartDate: fyStartDate);
                  break;
                case 'comparison':
                  await _handleComparisonResult(result: result, stockResult: stockResult, targetDate: targetDate, compareDate: compareDate);
                  break;
                case 'profit_margin':
                  await _handleProfitMarginResult(result: result, stockResult: stockResult, targetDate: targetDate, fyStartDate: fyStartDate);
                  break;
                default:
                  _handleGeneralStockResult(result: result, stockResult: stockResult, targetDate: targetDate);
              }
            }

            debugPrint('[STOCK VALUATION] Query result replaced with stock data');
          } catch (e) {
            debugPrint('[STOCK VALUATION ERROR] Failed to calculate stock: $e');
            // Keep original SQL result and add error note
            result['ai_response'] = '${result['ai_response']?.toString() ?? ''}'
                '\n\n⚠️ Note: Could not calculate stock with FIFO/LIFO/Avg Cost. Error: $e';
          }
        }
      }

      // Check if provider failed — show error with fallback options
      if (result['success'] != true && result['failed_provider'] != null) {
        final failedProvider = result['failed_provider'] as String;
        final fallbackChain = result['fallback_chain'] as List<String>? ?? [];
        final errorMsg = result['error']?.toString() ?? 'Provider failed';

        setState(() {
          _messages.add({
            'type': 'provider_failed',
            'content': errorMsg,
            'failed_provider': failedProvider,
            'fallback_chain': fallbackChain,
            'original_question': question,
            'enriched_question': enrichedQuestion,
            'filters': filters,
            'timestamp': DateTime.now(),
          });
          _isLoading = false; _loadingStartTime = null;
        });
        return;
      }

      // If generic failure (not provider-specific), show simple error
      if (result['success'] != true) {
        setState(() {
          _messages.add({
            'type': 'error',
            'content': result['error']?.toString() ?? 'Something went wrong',
            'timestamp': DateTime.now(),
          });
          _isLoading = false; _loadingStartTime = null;
        });
        return;
      }

      // Build result summary for next turn's context
      String resultSummary = '';
      List<String> sqlColumns = [];
      if (result['query_result'] != null && !result['query_result'].hasError && !result['query_result'].isEmpty) {
        final qr = result['query_result'];
        sqlColumns = List<String>.from(qr.columnNames);
        final rows = List<Map<String, dynamic>>.from(qr.data);
        final summaryRows = rows.take(2).map((r) =>
          r.entries.map((e) => '${e.key}=${e.value}').join(', ')
        ).join(' | ');
        resultSummary = '${rows.length} rows. Columns: ${sqlColumns.join(", ")}. '
            'Sample: $summaryRows';
        if (resultSummary.length > 300) {
          resultSummary = resultSummary.substring(0, 300) + '...';
        }
      }

      _conversationHistory.add({
        'question': question,
        'result_summary': resultSummary,
        'sql_columns': sqlColumns,
      });
      _contextTurnCount++;

      setState(() {
        _messages.add({
          'type': 'ai_response',
          'content': result['ai_response'],
          'query_result': result['query_result'],
          'generated_sql': result['generated_sql'],
          'suggestions': result['suggestions'],
          'original_question': question,
          'timestamp': DateTime.now(),
          'source': result['source'] ?? 'ai',
          'provider': result['provider'] ?? 'claude',
          'token_usage': result['token_usage'],
          'context_turn': _contextTurnCount,
          'applied_filters': filters,
          'reasoning': result['reasoning'],
          'compare_result': result['compare_result'],
        });
        _isLoading = false; _loadingStartTime = null;
        _selectedMetric = null;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'type': 'error',
          'content': 'Error: $e',
          'timestamp': DateTime.now(),
        });
        _isLoading = false; _loadingStartTime = null;
      });
    }
  }

  /// Handle general stock query — show per-item closing stock table
  void _handleGeneralStockResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
  }) {
    final List<Map<String, dynamic>> closingStockRows = [];

    // Add summary row (use num values, NOT strings!)
    closingStockRows.add({
      'item_name': 'TOTAL CLOSING STOCK',
      'item_count': stockResult.itemCount,
      'closing_value': stockResult.closingStockValue,
      'opening_value': stockResult.openingStockValue,
    });

    // Add per-item breakdown from detailedResults
    for (final itemResult in stockResult.detailedResults) {
      double itemTotalQty = 0.0;
      double itemTotalValue = 0.0;

      // Sum across all godowns for this item
      for (final godownCost in itemResult.godowns.values) {
        itemTotalQty += godownCost.currentStockQty;
        itemTotalValue += godownCost.closingValue;
      }

      if (itemTotalValue != 0 || itemTotalQty != 0) {
        closingStockRows.add({
          'item_name': itemResult.itemName,
          'closing_quantity': double.parse(itemTotalQty.toStringAsFixed(3)),
          'closing_value': double.parse(itemTotalValue.toStringAsFixed(2)),
          'average_rate': itemTotalQty != 0
              ? double.parse((itemTotalValue / itemTotalQty).toStringAsFixed(2))
              : 0.0,
        });
      }
    }

    // Replace query_result with calculated closing stock data
    result['query_result'] = _createQueryResultFromData(
      columns: ['item_name', 'closing_quantity', 'closing_value', 'average_rate'],
      rows: closingStockRows,
    );
    result['ai_response'] = 'Calculated closing stock as on ${_formatDateYYYYMMDD(targetDate)} using FIFO/LIFO/Avg Cost methods. '
        'Total closing stock value: \u20B9${stockResult.closingStockValue.toStringAsFixed(2)} '
        '(Opening: \u20B9${stockResult.openingStockValue.toStringAsFixed(2)})';
  }

  /// Handle specific item stock query — show transactions + calculated closing value
  Future<void> _handleItemSpecificStockResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String itemFilter,
    required String targetDate,
    required String fyStartDate,
  }) async {
    // Find matching item(s) from calculation results
    final matchingItems = stockResult.detailedResults.where(
      (item) => item.itemName.toLowerCase().contains(itemFilter.toLowerCase()),
    ).toList();

    final List<Map<String, dynamic>> resultRows = [];

    // Fetch transaction list for the item from database
    try {
      final db = await AiDependencies.databaseProvider!();
      final transactions = await db.rawQuery('''
        SELECT
          v.date as voucher_date,
          v.voucher_number,
          v.voucher_type,
          COALESCE(vba.godown_name, 'Main Location') as godown_name,
          vba.actual_qty as quantity,
          COALESCE(vba.batch_rate, 0) as rate,
          vba.amount,
          CASE WHEN vba.is_deemed_positive = 1 THEN 'Inward' ELSE 'Outward' END as direction
        FROM vouchers v
        INNER JOIN voucher_batch_allocations vba
          ON vba.voucher_guid = v.voucher_guid
        WHERE LOWER(vba.stock_item_name) LIKE ?
          AND v.company_guid = ?
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        ORDER BY v.date, v.voucher_key
      ''', ['%${itemFilter.toLowerCase()}%', widget.companyGuid, fyStartDate, targetDate]);

      // Add transaction rows
      for (final txn in transactions) {
        resultRows.add({
          'voucher_date': txn['voucher_date']?.toString() ?? '',
          'voucher_number': txn['voucher_number']?.toString() ?? '',
          'voucher_type': txn['voucher_type']?.toString() ?? '',
          'quantity': txn['quantity']?.toString() ?? '',
          'rate': txn['rate'] ?? 0,
          'amount': txn['amount'] ?? 0,
          'direction': txn['direction']?.toString() ?? '',
        });
      }
    } catch (e) {
      debugPrint('[STOCK VALUATION] Failed to fetch transactions for item: $e');
    }

    // Add calculated closing value summary row(s) at the end
    for (final itemResult in matchingItems) {
      double itemTotalQty = 0.0;
      double itemTotalValue = 0.0;

      for (final godownCost in itemResult.godowns.values) {
        itemTotalQty += godownCost.currentStockQty;
        itemTotalValue += godownCost.closingValue;
      }

      resultRows.add({
        'voucher_date': '--- CLOSING STOCK ---',
        'voucher_number': itemResult.itemName,
        'voucher_type': '',
        'quantity': itemTotalQty.toStringAsFixed(3),
        'rate': itemTotalQty != 0
            ? double.parse((itemTotalValue / itemTotalQty).toStringAsFixed(2))
            : 0.0,
        'amount': double.parse(itemTotalValue.toStringAsFixed(2)),
        'direction': 'Calculated',
      });
    }

    // Build response text
    String responseText = 'Stock details for "$itemFilter" as on ${_formatDateYYYYMMDD(targetDate)} (calculated using FIFO/LIFO/Avg Cost).';
    if (matchingItems.isNotEmpty) {
      double totalValue = 0.0;
      double totalQty = 0.0;
      for (final item in matchingItems) {
        for (final g in item.godowns.values) {
          totalValue += g.closingValue;
          totalQty += g.currentStockQty;
        }
      }
      responseText += ' Closing stock: ${totalQty.toStringAsFixed(3)} units, value: \u20B9${totalValue.toStringAsFixed(2)}';
    } else {
      responseText += ' No matching stock item found in calculation results.';
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['voucher_date', 'voucher_number', 'voucher_type', 'quantity', 'rate', 'amount', 'direction'],
      rows: resultRows,
    );
    result['ai_response'] = responseText;
  }

  // ======== STOCK QUERY TYPE HANDLERS ========

  /// Helper: get per-item totals from stock result
  List<Map<String, dynamic>> _buildItemTotals(AiStockValuationResult stockResult) {
    final List<Map<String, dynamic>> items = [];
    for (final itemResult in stockResult.detailedResults) {
      double qty = 0.0, value = 0.0;
      for (final g in itemResult.godowns.values) {
        qty += g.currentStockQty;
        value += g.closingValue;
      }
      items.add({
        'itemName': itemResult.itemName,
        'stockGroup': itemResult.stockGroup,
        'unit': itemResult.unit,
        'qty': qty,
        'value': value,
        'rate': qty != 0 ? value / qty : 0.0,
        'godowns': itemResult.godowns,
      });
    }
    return items;
  }

  /// Out of stock — items with qty <= 0
  Future<void> _handleOutOfStockResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
  }) async {
    final items = _buildItemTotals(stockResult);
    final outOfStock = items.where((i) => (i['qty'] as double) <= 0).toList();

    final List<Map<String, dynamic>> rows = [];
    for (final item in outOfStock) {
      rows.add({
        'item_name': item['itemName'],
        'closing_quantity': double.parse((item['qty'] as double).toStringAsFixed(3)),
        'closing_value': double.parse((item['value'] as double).toStringAsFixed(2)),
      });
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['item_name', 'closing_quantity', 'closing_value'],
      rows: rows,
    );
    result['ai_response'] = 'Items with zero or negative stock as on ${_formatDateYYYYMMDD(targetDate)}. '
        'Found ${rows.length} out of stock items (out of ${stockResult.itemCount} total).';
  }

  /// Low stock — items sorted by qty ascending
  void _handleLowStockResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
  }) {
    final items = _buildItemTotals(stockResult);
    // Filter items with qty > 0 (not already out of stock) and sort ascending
    final lowStock = items.where((i) => (i['qty'] as double) > 0).toList()
      ..sort((a, b) => (a['qty'] as double).compareTo(b['qty'] as double));

    final List<Map<String, dynamic>> rows = [];
    for (final item in lowStock.take(20)) {
      rows.add({
        'item_name': item['itemName'],
        'closing_quantity': double.parse((item['qty'] as double).toStringAsFixed(3)),
        'closing_value': double.parse((item['value'] as double).toStringAsFixed(2)),
        'average_rate': double.parse((item['rate'] as double).toStringAsFixed(2)),
      });
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['item_name', 'closing_quantity', 'closing_value', 'average_rate'],
      rows: rows,
    );
    result['ai_response'] = 'Items with lowest stock quantities as on ${_formatDateYYYYMMDD(targetDate)} '
        '(showing top ${rows.length} items sorted by quantity ascending).';
  }

  /// By category — items grouped by stock group
  Future<void> _handleByCategoryResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
  }) async {
    final items = _buildItemTotals(stockResult);

    // If stockGroup is empty (not passed via DI), fetch from DB
    bool needsGroupLookup = items.every((i) => (i['stockGroup'] as String).isEmpty);
    Map<String, String> groupLookup = {};
    if (needsGroupLookup) {
      try {
        final db = await AiDependencies.databaseProvider!();
        final groupRows = await db.rawQuery('''
          SELECT name, COALESCE(parent, 'Ungrouped') as parent
          FROM stock_items
          WHERE company_guid = ? AND is_deleted = 0
        ''', [widget.companyGuid]);
        for (final row in groupRows) {
          groupLookup[row['name'] as String] = row['parent'] as String;
        }
      } catch (e) {
        debugPrint('[STOCK] Failed to fetch groups: $e');
      }
    }

    // Group items by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in items) {
      if ((item['qty'] as double) == 0 && (item['value'] as double) == 0) continue;
      String group = (item['stockGroup'] as String).isNotEmpty
          ? item['stockGroup'] as String
          : groupLookup[item['itemName']] ?? 'Ungrouped';
      grouped.putIfAbsent(group, () => []).add(item);
    }

    final List<Map<String, dynamic>> rows = [];
    for (final entry in grouped.entries) {
      double groupQty = 0, groupValue = 0;
      for (final item in entry.value) {
        groupQty += item['qty'] as double;
        groupValue += item['value'] as double;
      }
      // Group header row
      rows.add({
        'item_name': '--- ${entry.key} ---',
        'closing_quantity': double.parse(groupQty.toStringAsFixed(3)),
        'closing_value': double.parse(groupValue.toStringAsFixed(2)),
        'average_rate': '',
      });
      // Individual items
      for (final item in entry.value) {
        rows.add({
          'item_name': '  ${item['itemName']}',
          'closing_quantity': double.parse((item['qty'] as double).toStringAsFixed(3)),
          'closing_value': double.parse((item['value'] as double).toStringAsFixed(2)),
          'average_rate': double.parse((item['rate'] as double).toStringAsFixed(2)),
        });
      }
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['item_name', 'closing_quantity', 'closing_value', 'average_rate'],
      rows: rows,
    );
    result['ai_response'] = 'Stock by category as on ${_formatDateYYYYMMDD(targetDate)}. '
        '${grouped.length} groups, ${stockResult.itemCount} items. '
        'Total value: \u20B9${stockResult.closingStockValue.toStringAsFixed(2)}';
  }

  /// Godown breakdown — per-godown per-item detail
  Future<void> _handleGodownBreakdownResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
  }) async {
    final List<Map<String, dynamic>> rows = [];

    // Group by godown
    final Map<String, List<Map<String, dynamic>>> byGodown = {};
    for (final itemResult in stockResult.detailedResults) {
      for (final entry in itemResult.godowns.entries) {
        final godownName = entry.key.isEmpty ? 'Main Location' : entry.key;
        final g = entry.value;
        if (g.currentStockQty == 0 && g.closingValue == 0) continue;
        byGodown.putIfAbsent(godownName, () => []).add({
          'itemName': itemResult.itemName,
          'qty': g.currentStockQty,
          'value': g.closingValue,
          'rate': g.currentStockQty != 0 ? g.closingValue / g.currentStockQty : 0.0,
        });
      }
    }

    for (final entry in byGodown.entries) {
      double godownTotal = 0;
      for (final item in entry.value) {
        godownTotal += item['value'] as double;
      }
      // Godown header
      rows.add({
        'godown_name': '--- ${entry.key} ---',
        'item_name': '',
        'closing_quantity': '',
        'closing_value': double.parse(godownTotal.toStringAsFixed(2)),
      });
      for (final item in entry.value) {
        rows.add({
          'godown_name': entry.key,
          'item_name': item['itemName'],
          'closing_quantity': double.parse((item['qty'] as double).toStringAsFixed(3)),
          'closing_value': double.parse((item['value'] as double).toStringAsFixed(2)),
        });
      }
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['godown_name', 'item_name', 'closing_quantity', 'closing_value'],
      rows: rows,
    );
    result['ai_response'] = 'Godown-wise stock breakdown as on ${_formatDateYYYYMMDD(targetDate)}. '
        '${byGodown.length} godowns. Total value: \u20B9${stockResult.closingStockValue.toStringAsFixed(2)}';
  }

  /// Movement report — inward/outward totals per item from DB
  Future<void> _handleMovementReportResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
    required String fyStartDate,
  }) async {
    final List<Map<String, dynamic>> rows = [];
    try {
      final db = await AiDependencies.databaseProvider!();
      final movements = await db.rawQuery('''
        SELECT
          vba.stock_item_name as item_name,
          SUM(CASE WHEN vba.is_deemed_positive = 1 THEN ABS(vba.amount) ELSE 0 END) as inward_value,
          SUM(CASE WHEN vba.is_deemed_positive = 0 THEN ABS(vba.amount) ELSE 0 END) as outward_value,
          COUNT(DISTINCT v.voucher_guid) as txn_count
        FROM voucher_batch_allocations vba
        INNER JOIN vouchers v ON v.voucher_guid = vba.voucher_guid
        WHERE v.company_guid = ?
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        GROUP BY vba.stock_item_name
        ORDER BY inward_value + outward_value DESC
      ''', [widget.companyGuid, fyStartDate, targetDate]);

      // Build lookup of closing values from calculation
      final closingMap = <String, double>{};
      for (final item in stockResult.detailedResults) {
        double val = 0;
        for (final g in item.godowns.values) { val += g.closingValue; }
        closingMap[item.itemName] = val;
      }

      for (final m in movements) {
        final name = m['item_name']?.toString() ?? '';
        rows.add({
          'item_name': name,
          'inward_value': double.parse(((m['inward_value'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)),
          'outward_value': double.parse(((m['outward_value'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)),
          'closing_value': double.parse((closingMap[name] ?? 0).toStringAsFixed(2)),
          'txn_count': m['txn_count'] ?? 0,
        });
      }
    } catch (e) {
      debugPrint('[STOCK] Movement report query failed: $e');
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['item_name', 'inward_value', 'outward_value', 'closing_value', 'txn_count'],
      rows: rows,
    );
    result['ai_response'] = 'Stock movement report from ${_formatDateYYYYMMDD(fyStartDate)} to ${_formatDateYYYYMMDD(targetDate)}. '
        '${rows.length} items with movements. Closing values calculated using FIFO/LIFO/Avg Cost.';
  }

  /// Slow moving — items sorted by outward movement ascending
  Future<void> _handleSlowMovingResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
    required String fyStartDate,
  }) async {
    final List<Map<String, dynamic>> rows = [];
    try {
      final db = await AiDependencies.databaseProvider!();
      // Get all stock items and their outward movement
      final movements = await db.rawQuery('''
        SELECT
          si.name as item_name,
          COALESCE(SUM(CASE WHEN vba.is_deemed_positive = 0 THEN ABS(vba.amount) ELSE 0 END), 0) as outward_value,
          COUNT(DISTINCT CASE WHEN vba.is_deemed_positive = 0 THEN v.voucher_guid END) as outward_txns
        FROM stock_items si
        LEFT JOIN voucher_batch_allocations vba ON vba.stock_item_name = si.name
        LEFT JOIN vouchers v ON v.voucher_guid = vba.voucher_guid
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        WHERE si.company_guid = ? AND si.is_deleted = 0
        GROUP BY si.name
        ORDER BY outward_value ASC
        LIMIT 30
      ''', [fyStartDate, targetDate, widget.companyGuid]);

      // Closing value lookup
      final closingMap = <String, double>{};
      final closingQtyMap = <String, double>{};
      for (final item in stockResult.detailedResults) {
        double val = 0, qty = 0;
        for (final g in item.godowns.values) {
          val += g.closingValue;
          qty += g.currentStockQty;
        }
        closingMap[item.itemName] = val;
        closingQtyMap[item.itemName] = qty;
      }

      for (final m in movements) {
        final name = m['item_name']?.toString() ?? '';
        final closingQty = closingQtyMap[name] ?? 0.0;
        if (closingQty <= 0) continue; // Skip items with no stock
        rows.add({
          'item_name': name,
          'closing_quantity': double.parse(closingQty.toStringAsFixed(3)),
          'closing_value': double.parse((closingMap[name] ?? 0).toStringAsFixed(2)),
          'outward_value': double.parse(((m['outward_value'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)),
          'outward_txns': m['outward_txns'] ?? 0,
        });
      }
    } catch (e) {
      debugPrint('[STOCK] Slow moving query failed: $e');
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['item_name', 'closing_quantity', 'closing_value', 'outward_value', 'outward_txns'],
      rows: rows,
    );
    result['ai_response'] = 'Slow moving items (${_formatDateYYYYMMDD(fyStartDate)} to ${_formatDateYYYYMMDD(targetDate)}). '
        'Items with stock but least outward movement. ${rows.length} items shown.';
  }

  /// Comparison — compare stock between two dates
  Future<void> _handleComparisonResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
    required String? compareDate,
  }) async {
    if (compareDate == null) {
      // Fallback to general if no compare date
      _handleGeneralStockResult(result: result, stockResult: stockResult, targetDate: targetDate);
      return;
    }

    // Run second calculation for the earlier date
    final fyStartDate2 = AiDependencies.fyStartDateGetter!(compareDate);
    final stockResult2 = await AiDependencies.stockValuationCalculator!(
      companyGuid: widget.companyGuid,
      fromDate: fyStartDate2,
      toDate: compareDate,
    );

    // Build lookup for earlier date
    final earlierMap = <String, double>{};
    final earlierQtyMap = <String, double>{};
    for (final item in stockResult2.detailedResults) {
      double val = 0, qty = 0;
      for (final g in item.godowns.values) {
        val += g.closingValue;
        qty += g.currentStockQty;
      }
      earlierMap[item.itemName] = val;
      earlierQtyMap[item.itemName] = qty;
    }

    final List<Map<String, dynamic>> rows = [];
    // Summary row
    rows.add({
      'item_name': 'TOTAL',
      'earlier_value': double.parse(stockResult2.closingStockValue.toStringAsFixed(2)),
      'current_value': double.parse(stockResult.closingStockValue.toStringAsFixed(2)),
      'change': double.parse((stockResult.closingStockValue - stockResult2.closingStockValue).toStringAsFixed(2)),
    });

    // Per-item comparison
    final allItemNames = <String>{};
    for (final item in stockResult.detailedResults) { allItemNames.add(item.itemName); }
    for (final item in stockResult2.detailedResults) { allItemNames.add(item.itemName); }

    for (final name in allItemNames) {
      double currentVal = 0;
      for (final item in stockResult.detailedResults) {
        if (item.itemName == name) {
          for (final g in item.godowns.values) { currentVal += g.closingValue; }
        }
      }
      final earlierVal = earlierMap[name] ?? 0.0;
      final change = currentVal - earlierVal;
      if (currentVal == 0 && earlierVal == 0) continue;
      rows.add({
        'item_name': name,
        'earlier_value': double.parse(earlierVal.toStringAsFixed(2)),
        'current_value': double.parse(currentVal.toStringAsFixed(2)),
        'change': double.parse(change.toStringAsFixed(2)),
      });
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['item_name', 'earlier_value', 'current_value', 'change'],
      rows: rows,
    );
    result['ai_response'] = 'Stock comparison: ${_formatDateYYYYMMDD(compareDate)} vs ${_formatDateYYYYMMDD(targetDate)}. '
        'Earlier total: \u20B9${stockResult2.closingStockValue.toStringAsFixed(2)}, '
        'Current total: \u20B9${stockResult.closingStockValue.toStringAsFixed(2)}, '
        'Change: \u20B9${(stockResult.closingStockValue - stockResult2.closingStockValue).toStringAsFixed(2)}';
  }

  /// Profit margin — cost (from stock) vs sales (from vouchers)
  Future<void> _handleProfitMarginResult({
    required Map<String, dynamic> result,
    required AiStockValuationResult stockResult,
    required String targetDate,
    required String fyStartDate,
  }) async {
    final List<Map<String, dynamic>> rows = [];
    try {
      final db = await AiDependencies.databaseProvider!();
      // Get sales data per item
      final sales = await db.rawQuery('''
        SELECT
          vba.stock_item_name as item_name,
          SUM(CASE WHEN vba.is_deemed_positive = 0 THEN ABS(vba.amount) ELSE 0 END) as sales_value,
          SUM(CASE WHEN vba.is_deemed_positive = 1 THEN ABS(vba.amount) ELSE 0 END) as purchase_value
        FROM voucher_batch_allocations vba
        INNER JOIN vouchers v ON v.voucher_guid = vba.voucher_guid
        WHERE v.company_guid = ?
          AND v.is_deleted = 0 AND v.is_cancelled = 0 AND v.is_optional = 0
          AND v.date >= ? AND v.date <= ?
        GROUP BY vba.stock_item_name
        HAVING sales_value > 0
        ORDER BY sales_value DESC
      ''', [widget.companyGuid, fyStartDate, targetDate]);

      // Closing value lookup
      final closingMap = <String, double>{};
      for (final item in stockResult.detailedResults) {
        double val = 0;
        for (final g in item.godowns.values) { val += g.closingValue; }
        closingMap[item.itemName] = val;
      }

      for (final s in sales) {
        final name = s['item_name']?.toString() ?? '';
        final salesVal = (s['sales_value'] as num?)?.toDouble() ?? 0;
        final purchaseVal = (s['purchase_value'] as num?)?.toDouble() ?? 0;
        final margin = salesVal > 0 ? ((salesVal - purchaseVal) / salesVal * 100) : 0.0;
        rows.add({
          'item_name': name,
          'purchase_value': double.parse(purchaseVal.toStringAsFixed(2)),
          'sales_value': double.parse(salesVal.toStringAsFixed(2)),
          'profit': double.parse((salesVal - purchaseVal).toStringAsFixed(2)),
          'margin_pct': double.parse(margin.toStringAsFixed(1)),
          'closing_stock': double.parse((closingMap[name] ?? 0).toStringAsFixed(2)),
        });
      }
    } catch (e) {
      debugPrint('[STOCK] Profit margin query failed: $e');
    }

    result['query_result'] = _createQueryResultFromData(
      columns: ['item_name', 'purchase_value', 'sales_value', 'profit', 'margin_pct', 'closing_stock'],
      rows: rows,
    );
    result['ai_response'] = 'Item-wise profit margin from ${_formatDateYYYYMMDD(fyStartDate)} to ${_formatDateYYYYMMDD(targetDate)}. '
        '${rows.length} items with sales. Closing stock values calculated using FIFO/LIFO/Avg Cost.';
  }

/// Create a QueryResult-compatible object from custom data
/// Returns _SimpleQueryResult which has .hasError, .columnNames, .data getters
/// that match the real QueryResult interface used throughout the UI
dynamic _createQueryResultFromData({
required List<String> columns,
required List<Map<String, dynamic>> rows,
}) {
return _SimpleQueryResult(
hasError: false,
isEmpty: rows.isEmpty,
error: null,
columnNames: columns,
data: rows,
formattedExecutionTime: '0ms',
);
}

  /// Format YYYYMMDD date string to readable format
  String _formatDateYYYYMMDD(String dateStr) {
    if (dateStr.length != 8) return dateStr;
    try {
      final year = dateStr.substring(0, 4);
      final month = dateStr.substring(4, 6);
      final day = dateStr.substring(6, 8);
      return '$day-$month-$year';
    } catch (e) {
      return dateStr;
    }
  }
}