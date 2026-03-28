import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ClaudeService {
  final String apiKey;
  final String model;

  ClaudeService({
    required this.apiKey,
    this.model = 'claude-haiku-4-5-20251001',
  });

  bool get isAvailable => apiKey.isNotEmpty;

  /// Call Claude API to generate a SQL query
  Future<Map<String, dynamic>> generateSql({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 4096,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': maxTokens,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userMessage}
          ],
          'temperature': 0.0,
        }),
      );

      if (response.statusCode == 401) {
        return _error('AI authentication failed. Check API key.');
      }
      if (response.statusCode == 429) {
        return _error('AI service is busy. Please try again in a moment.');
      }
      if (response.statusCode != 200) {
        return _error('AI service error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final rawText = (data['content'][0]['text'] as String).trim();
      final sql = _cleanSqlResponse(rawText);

      final usage = {
        'input_tokens': data['usage']['input_tokens'],
        'output_tokens': data['usage']['output_tokens'],
      };

      debugPrint('Claude API success. Input: ${usage['input_tokens']}, Output: ${usage['output_tokens']} tokens');

      return {
        'sql': sql,
        'success': true,
        'error': null,
        'usage': usage,
      };
    } catch (e) {
      debugPrint('Error calling Claude: $e');
      return _error('Unexpected error: $e');
    }
  }

  String _cleanSqlResponse(String rawText) {
    var text = rawText.trim();

    // Remove markdown code blocks
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) {
        text = text.substring(firstNewline + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }

    // Remove leading sql language identifier
    if (text.toLowerCase().startsWith('sql\n')) {
      text = text.substring(4).trim();
    }

    // Remove trailing semicolons
    text = text.trimRight();
    while (text.endsWith(';')) {
      text = text.substring(0, text.length - 1).trimRight();
    }

    return text;
  }

  Map<String, dynamic> _error(String message) {
    return {
      'sql': '',
      'success': false,
      'error': message,
      'usage': <String, dynamic>{},
    };
  }
}
