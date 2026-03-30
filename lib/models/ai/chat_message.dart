/// Chat Message Model
class ChatMessage {
  final String messageId;
  final String companyGuid;
  final String userId;
  final String messageType; // 'user_question', 'ai_response', 'error'
  final String content;
  final String? generatedSql;
  final int? resultCount;
  final DateTime timestamp;
  final String? sessionId;

  ChatMessage({
    required this.messageId,
    required this.companyGuid,
    required this.userId,
    required this.messageType,
    required this.content,
    this.generatedSql,
    this.resultCount,
    required this.timestamp,
    this.sessionId,
  });

  /// Create from Map (database row)
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      messageId: map['message_id'] as String,
      companyGuid: map['company_guid'] as String,
      userId: map['user_id'] as String,
      messageType: map['message_type'] as String,
      content: map['content'] as String,
      generatedSql: map['generated_sql'] as String?,
      resultCount: map['result_count'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      sessionId: map['session_id'] as String?,
    );
  }

  /// Convert to Map (for database insertion)
  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'company_guid': companyGuid,
      'user_id': userId,
      'message_type': messageType,
      'content': content,
      'generated_sql': generatedSql,
      'result_count': resultCount,
      'timestamp': timestamp.toIso8601String(),
      'session_id': sessionId,
    };
  }

  bool get isUserMessage => messageType == 'user_question';
  bool get isAiResponse => messageType == 'ai_response';
  bool get isError => messageType == 'error';
}
