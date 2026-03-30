import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Base class for AI provider services that follow the OpenAI-compatible API pattern.
/// Used by: Deepseek/Kimi, OpenRouter, Qwen, GLM-5, AWS vLLM, Llama, etc.
abstract class AiProviderService {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String providerName;
  final double temperature;
  final Map<String, String> extraHeaders;

  AiProviderService({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.providerName,
    this.temperature = 0.7,
    this.extraHeaders = const {},
  });

  bool get isAvailable => apiKey.isNotEmpty;

  Future<Map<String, dynamic>> generateSql({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 4096,
  }) async {
    try {
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        ...extraHeaders,
      };

      final body = {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': maxTokens,
        'temperature': temperature,
      };

      final response = await http
          .post(Uri.parse('$baseUrl/chat/completions'),
              headers: headers, body: jsonEncode(body))
          .timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode != 200) {
        return _error('$providerName error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final rawText = data['choices'][0]['message']['content'] as String;
      final sql = cleanSqlResponse(rawText);

      final usage = data['usage'] as Map<String, dynamic>? ?? {};

      debugPrint('$providerName success. Tokens: $usage');

      return {
        'sql': sql,
        'success': true,
        'error': null,
        'usage': usage,
        'reasoning': _extractReasoning(rawText),
      };
    } catch (e) {
      debugPrint('Error calling $providerName: $e');
      return _error('$providerName error: $e');
    }
  }

  int get timeoutSeconds => 120;

  String cleanSqlResponse(String rawText) {
    var text = rawText.trim();

    // Remove <think>...</think> tags (DeepSeek R1 reasoning)
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();

    // Remove GLM box tags
    text = text.replaceAll(RegExp(r'<\|begin_of_box\|>'), '').trim();
    text = text.replaceAll(RegExp(r'<\|end_of_box\|>'), '').trim();

    // Remove markdown code blocks
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) text = text.substring(firstNewline + 1);
      if (text.endsWith('```')) text = text.substring(0, text.length - 3);
      text = text.trim();
    }

    // Remove leading sql identifier
    if (text.toLowerCase().startsWith('sql\n')) {
      text = text.substring(4).trim();
    }

    // Remove trailing semicolons
    while (text.endsWith(';')) {
      text = text.substring(0, text.length - 1).trimRight();
    }

    return text.trim();
  }

  String? _extractReasoning(String rawText) {
    final match = RegExp(r'<think>([\s\S]*?)</think>').firstMatch(rawText);
    return match?.group(1)?.trim();
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

// ─── Concrete Provider Implementations ───

class KimiService extends AiProviderService {
  KimiService({required String apiKey})
      : super(
          apiKey: apiKey,
          baseUrl: 'https://router.huggingface.co/v1',
          model: 'moonshotai/Kimi-K2.5',
          providerName: 'Kimi K2.5',
          temperature: 0.7,
          extraHeaders: {},
        );

  @override
  int get timeoutSeconds => 180;
}

class OpenRouterService extends AiProviderService {
  OpenRouterService({required String apiKey})
      : super(
          apiKey: apiKey,
          baseUrl: 'https://openrouter.ai/api/v1',
          model: 'qwen/qwen3-8b:free',
          providerName: 'OpenRouter Qwen3 8B',
          temperature: 0.7,
          extraHeaders: {
            'HTTP-Referer': 'https://tally-connector.app',
            'X-Title': 'Tally Connector AI',
          },
        );
}

class QwenService extends AiProviderService {
  QwenService({required String apiKey})
      : super(
          apiKey: apiKey,
          baseUrl: 'https://router.huggingface.co/v1',
          model: 'Qwen/Qwen3-32B',
          providerName: 'Qwen 32B',
          temperature: 0.01,
        );

  @override
  int get timeoutSeconds => 180;
}

class Qwen3_4BService extends AiProviderService {
  Qwen3_4BService({required String apiKey})
      : super(
          apiKey: apiKey,
          baseUrl: 'https://router.huggingface.co/v1',
          model: 'Qwen/Qwen3-0.6B',
          providerName: 'Qwen3 4B',
          temperature: 0.7,
        );
}

class Qwen3_8BService extends AiProviderService {
  Qwen3_8BService({required String apiKey})
      : super(
          apiKey: apiKey,
          baseUrl: 'https://router.huggingface.co/v1',
          model: 'Qwen/Qwen3-8B:nscale',
          providerName: 'Qwen3 8B',
          temperature: 0.7,
        );
}

class LlamaService extends AiProviderService {
  LlamaService({required String apiKey})
      : super(
          apiKey: apiKey,
          baseUrl: 'https://router.huggingface.co/v1',
          model: 'meta-llama/Llama-3.1-8B-Instruct',
          providerName: 'Llama 8B',
          temperature: 0.01,
        );

  @override
  int get timeoutSeconds => 180;
}

class Glm5Service extends AiProviderService {
  Glm5Service({required String apiKey})
      : super(
          apiKey: apiKey,
          baseUrl: 'https://api.z.ai/api/paas/v4',
          model: 'glm-5',
          providerName: 'GLM-5',
          temperature: 0.7,
        );
}

class AwsService extends AiProviderService {
  static const String _wakeUrl =
      'https://yesuycqyug.execute-api.ap-south-1.amazonaws.com/wake';

  AwsService()
      : super(
          apiKey: 'dummy-key',
          baseUrl: 'http://3.6.218.114:8000/v1',
          model: '',
          providerName: 'AWS vLLM',
          temperature: 0.1,
        );

  @override
  bool get isAvailable => true;

  @override
  Future<Map<String, dynamic>> generateSql({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 4096,
  }) async {
    // Wake up the EC2 instance
    try {
      await http.get(Uri.parse(_wakeUrl)).timeout(const Duration(seconds: 10));
    } catch (_) {
      debugPrint('AWS wake call failed, proceeding anyway');
    }

    // Auto-detect model
    try {
      final modelsResp = await http
          .get(Uri.parse('${baseUrl}/models'))
          .timeout(const Duration(seconds: 10));
      if (modelsResp.statusCode == 200) {
        final models = jsonDecode(modelsResp.body);
        final modelList = models['data'] as List;
        if (modelList.isNotEmpty) {
          // Use detected model
          final detectedModel = modelList[0]['id'] as String;
          return _callWithModel(detectedModel, systemPrompt, userMessage, maxTokens);
        }
      }
    } catch (_) {}

    return _callWithModel('Qwen/Qwen3-8B', systemPrompt, userMessage, maxTokens);
  }

  Future<Map<String, dynamic>> _callWithModel(
    String modelId,
    String systemPrompt,
    String userMessage,
    int maxTokens,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': modelId,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'max_tokens': maxTokens,
          'temperature': temperature,
        }),
      ).timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode != 200) {
        return {'sql': '', 'success': false, 'error': 'AWS error: ${response.statusCode}', 'usage': {}};
      }

      final data = jsonDecode(response.body);
      final rawText = data['choices'][0]['message']['content'] as String;
      return {
        'sql': cleanSqlResponse(rawText),
        'success': true,
        'error': null,
        'usage': data['usage'] ?? {},
      };
    } catch (e) {
      return {'sql': '', 'success': false, 'error': 'AWS error: $e', 'usage': {}};
    }
  }

  @override
  int get timeoutSeconds => 120;
}
