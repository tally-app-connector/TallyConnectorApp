/// AI Queries API Endpoints Configuration
class AiEndpoints {
  // Base URL will be imported from main API config
  static const String baseRoute = '/api/ai-queries';

  /// Chat endpoint - Send natural language question
  static const String chat = '$baseRoute/chat';

  /// Feedback endpoint - Submit thumbs up/down
  static const String feedback = '$baseRoute/feedback';

  /// History endpoint - Get chat history
  static String history(String companyGuid) => '$baseRoute/history/$companyGuid';
}

class AiConfig {
  // Pass these via --dart-define when building:
  // flutter run --dart-define=CLAUDE_API_KEY=your_key --dart-define=HUGGINGFACE_API_KEY=your_key ...

  // Claude (Anthropic) - https://console.anthropic.com/
  static const String claudeApiKey = String.fromEnvironment('CLAUDE_API_KEY');

  // HuggingFace - https://huggingface.co/settings/tokens
  // Used for: Kimi K2.5, Qwen3 32B, Qwen3 8B, Qwen3 0.6B, Llama 8B
  static const String huggingFaceApiKey = String.fromEnvironment('HUGGINGFACE_API_KEY');

  // OpenRouter - https://openrouter.ai/keys
  // Used for: OR-Qwen3 8B (free tier)
  static const String openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');

  // GLM-5 (Zhipu AI) - https://open.bigmodel.cn/
  static const String glm5ApiKey = String.fromEnvironment('GLM5_API_KEY');
}
