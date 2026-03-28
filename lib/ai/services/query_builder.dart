/// Query Builder Service
/// Injects parameters into SQL templates and validates security.

import '../models/query_template.dart';

class QuerySecurityError implements Exception {
  final String message;
  QuerySecurityError(this.message);
  @override
  String toString() => 'QuerySecurityError: $message';
}

class QueryBuilder {
  static const List<String> _forbiddenKeywords = [
    'DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER',
    'CREATE', 'TRUNCATE', 'GRANT', 'REVOKE',
  ];

  /// Build SQL query from template and parameters
  String build({
    required QueryTemplate template,
    required Map<String, dynamic> entities,
    required String companyGuid,
  }) {
    var sql = template.sqlTemplate;

    final params = _prepareParameters(entities, companyGuid);
    _validateParameters(template, params);
    sql = _replacePlaceholders(sql, params);
    _validateSecurity(sql);
    sql = _cleanSql(sql);

    return sql;
  }

  Map<String, String> _prepareParameters(
    Map<String, dynamic> entities,
    String companyGuid,
  ) {
    final params = <String, String>{'company_guid': companyGuid};

    if (entities.containsKey('from_date')) {
      params['from_date'] = _formatDate(entities['from_date']);
    }
    if (entities.containsKey('to_date')) {
      params['to_date'] = _formatDate(entities['to_date']);
    }

    for (final entry in entities.entries) {
      if (!params.containsKey(entry.key)) {
        params[entry.key] = entry.value.toString();
      }
    }

    return params;
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue is String) {
      if (RegExp(r'^\d{8}$').hasMatch(dateValue)) return dateValue;
      if (dateValue.contains('-')) return dateValue.replaceAll('-', '');
    }
    return dateValue.toString();
  }

  String _replacePlaceholders(String sql, Map<String, String> params) {
    const stringKeys = {'company_guid', 'from_date', 'to_date', 'party_name'};

    for (final entry in params.entries) {
      final placeholder = '{{${entry.key}}}';
      if (stringKeys.contains(entry.key)) {
        // If template already has quotes around placeholder, don't double-quote
        final quotedPlaceholder = "'$placeholder'";
        if (sql.contains(quotedPlaceholder)) {
          sql = sql.replaceAll(quotedPlaceholder, "'${entry.value}'");
        } else {
          sql = sql.replaceAll(placeholder, "'${entry.value}'");
        }
      } else {
        sql = sql.replaceAll(placeholder, entry.value);
      }
    }
    return sql;
  }

  void _validateParameters(QueryTemplate template, Map<String, String> params) {
    final requiredParams = template.parameterSchema.entries
        .where((e) => (e.value as Map<String, dynamic>)['required'] == true)
        .map((e) => e.key)
        .toList();

    final missing = requiredParams.where((p) => !params.containsKey(p)).toList();
    if (missing.isNotEmpty) {
      throw ArgumentError('Missing required parameters: ${missing.join(', ')}');
    }
  }

  void _validateSecurity(String sql) {
    final sqlUpper = sql.toUpperCase();

    for (final keyword in _forbiddenKeywords) {
      if (RegExp('\\b$keyword\\b').hasMatch(sqlUpper)) {
        throw QuerySecurityError('Query contains forbidden operation: $keyword');
      }
    }

    final trimmed = sqlUpper.trim();
    if (!trimmed.startsWith('SELECT') && !trimmed.startsWith('WITH')) {
      throw QuerySecurityError('Only SELECT queries are allowed');
    }
  }

  String _cleanSql(String sql) {
    return sql.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
