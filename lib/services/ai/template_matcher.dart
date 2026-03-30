import '../../models/ai/query_template.dart';

class TemplateMatcher {
  final List<QueryTemplate> templates;
  late final Map<String, List<QueryTemplate>> _categoryIndex;
  late final Map<String, List<QueryTemplate>> _keywordIndex;

  TemplateMatcher(this.templates) {
    _buildIndex();
  }

  void _buildIndex() {
    _categoryIndex = {};
    _keywordIndex = {};

    for (final template in templates) {
      _categoryIndex.putIfAbsent(template.category, () => []).add(template);

      for (final keyword in template.intentKeywords) {
        final kw = keyword.toLowerCase();
        _keywordIndex.putIfAbsent(kw, () => []).add(template);
      }
    }
  }

  /// Select best matching template based on intent and available entities
  QueryTemplate? select({
    required String intent,
    required Map<String, dynamic> entities,
    double confidence = 0.0,
  }) {
    final category = intent.split('_').first;
    var candidates = _categoryIndex[category] ?? [];

    if (candidates.isEmpty) {
      candidates = _keywordMatch(intent);
    }

    if (candidates.isEmpty) return null;

    final scored = candidates
        .map((t) => _ScoredTemplate(t, _calculateScore(t, intent, entities)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.first.template;
  }

  List<QueryTemplate> _keywordMatch(String intent) {
    final matches = <QueryTemplate>{};
    final intentWords = intent.toLowerCase().split('_');

    for (final word in intentWords) {
      final templates = _keywordIndex[word];
      if (templates != null) matches.addAll(templates);
    }

    return matches.toList();
  }

  double _calculateScore(
    QueryTemplate template,
    String intent,
    Map<String, dynamic> entities,
  ) {
    var score = 0.0;
    final intentLower = intent.toLowerCase();

    // Keyword matching score (0-50)
    if (template.intentKeywords.isNotEmpty) {
      final keywordMatches = template.intentKeywords
          .where((kw) => intentLower.contains(kw.toLowerCase()))
          .length;
      score += (keywordMatches / template.intentKeywords.length) * 50;
    }

    // Parameter coverage score (0-30)
    final requiredParams = template.parameterSchema.entries
        .where((e) => (e.value as Map<String, dynamic>)['required'] == true)
        .map((e) => e.key)
        .toList();

    if (requiredParams.isNotEmpty) {
      final availableParams = requiredParams
          .where((p) => entities.containsKey(p) || p == 'company_guid')
          .length;
      score += (availableParams / requiredParams.length) * 30;
    }

    // Template specificity score (0-20)
    score += (template.parameterSchema.length * 5).clamp(0, 20).toDouble();

    return score;
  }

  List<QueryTemplate> getTemplatesByCategory(String category) {
    return _categoryIndex[category] ?? [];
  }

  List<String> getAllCategories() {
    return _categoryIndex.keys.toList();
  }
}

class _ScoredTemplate {
  final QueryTemplate template;
  final double score;
  _ScoredTemplate(this.template, this.score);
}
