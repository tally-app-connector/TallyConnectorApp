class QueryTemplate {
  final String templateId;
  final String category;
  final List<String> intentKeywords;
  final String sqlTemplate;
  final Map<String, dynamic> parameterSchema;
  final List<String> sampleQuestions;
  final String? description;
  final String? sourceFile;

  const QueryTemplate({
    required this.templateId,
    required this.category,
    required this.intentKeywords,
    required this.sqlTemplate,
    required this.parameterSchema,
    this.sampleQuestions = const [],
    this.description,
    this.sourceFile,
  });

  factory QueryTemplate.fromMap(Map<String, dynamic> map) {
    return QueryTemplate(
      templateId: map['template_id'] as String,
      category: map['category'] as String,
      intentKeywords: List<String>.from(map['intent_keywords'] as List),
      sqlTemplate: map['sql_template'] as String,
      parameterSchema: Map<String, dynamic>.from(map['parameter_schema'] as Map),
      sampleQuestions: map['sample_questions'] != null
          ? List<String>.from(map['sample_questions'] as List)
          : [],
      description: map['description'] as String?,
      sourceFile: map['source_file'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'template_id': templateId,
      'category': category,
      'intent_keywords': intentKeywords,
      'sql_template': sqlTemplate,
      'parameter_schema': parameterSchema,
      'sample_questions': sampleQuestions,
      'description': description,
      'source_file': sourceFile,
    };
  }
}
