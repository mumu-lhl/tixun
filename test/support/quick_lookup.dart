import "package:dio/dio.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_models.dart";

const quickTestConfig = ProviderConfig(
  id: 1,
  kind: "deepseek",
  baseUrl: "https://api.deepseek.com",
  model: "test-lookup",
  vision: false,
  supportsTools: true,
  thinking: true,
  supportsThinking: true,
  effort: "max",
);

const validQuickReply = '''
{"summary":"n. 快乐、愉悦；荣幸。","content":"**Pleasure** means enjoyment. Use it in My pleasure.",
"vocabulary":[{"form":"pleasure","type":"word","meaning":"愉悦","example":"It was a pleasure."}],
"sentence":{"text":"It was a pleasure to meet you.","gloss":"很高兴认识您。","hint":"Greetings"}}
''';

class QuickTestProvider implements ChatProvider {
  final requests = <AiRequest>[];
  final configs = <ProviderConfig>[];
  Stream<AiChunk> Function(CancelToken) reply = (_) => Stream.fromIterable([
    const AiChunk(text: validQuickReply),
    const AiChunk(
      completed: true,
      usage: AiTokenUsage(
        inputTokens: 100,
        cachedInputTokens: 22,
        outputTokens: 40,
      ),
    ),
  ]);

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) {
    configs.add(config);
    return AiConversation((request, cancel) {
      requests.add(request);
      return reply(cancel);
    });
  }
}

QuickQuery quickTestQuery(
  LanguageQuickAction action, {
  String input = "pleasure",
}) => QuickQuery(
  actionId: action.id,
  actionName: action.name.isEmpty ? action.id : action.name,
  actionRevision: action.revision,
  prompt: action.prompt,
  input: input,
  sourceLanguage: action.sourceLanguage,
  targetLanguage: action.targetLanguage,
  glossLanguage: "zh",
  level: "intermediate",
  detailed: action.detailed,
);
