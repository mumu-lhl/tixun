import "dart:convert";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";

import "../../core/ai/ai_usage_store.dart";
import "../../core/ai/chat_provider.dart";
import "../../core/ai/prompt_settings.dart";
import "../../core/database/database.dart";
import "language_json_request.dart";
import "generation_store.dart";
import "language_store.dart";
import "sentence_content.dart";
import "sentence_store.dart";
import "generation_provider.dart";

class SentenceExplanation {
  const SentenceExplanation({
    required this.store,
    required this.provider,
    required this._config,
    this.usageStore,
    this.prompts,
  });

  final LanguageLearningStore store;
  final ChatProvider provider;
  final ProviderConfig _config;
  ProviderConfig get config => languageConfiguration(provider, _config);
  final AiUsageStore? usageStore;
  final PromptSettings? prompts;
  static const _promptVersion = 1;

  Future<String> explain({
    required SentenceCard card,
    required String glossLanguage,
    required bool simpler,
    required CancelToken cancel,
    bool regenerate = false,
    String? originalText,
  }) async {
    final isMock = provider is MockChatProvider;
    final model = isMock ? "Mock" : config.model;
    final currentPrompts = provider is LanguageGenerationProvider
        ? (provider as LanguageGenerationProvider).promptSettings()
        : prompts;
    final key = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              card.id,
              card.revision,
              card.text,
              card.language,
              glossLanguage,
              simpler,
              isMock ? "mock" : config.kind,
              isMock ? "" : config.baseUrl,
              model,
              _promptVersion,
              config.thinking,
              config.effort,
              LanguagePrompt.sentenceExplanation.instructions(currentPrompts),
            ]),
          ),
        )
        .toString();
    cancel.checkCancelled();
    final cached = await store.cachedExplanation(key);
    cancel.checkCancelled();
    if (!regenerate && cached != null) return cached;

    final request = AiRequest(
      instructions: LanguagePrompt.sentenceExplanation.instructions(
        currentPrompts,
      ),
      messages: [
        AiMessage.user(
          jsonEncode({
            "sentence": card.text,
            "language": card.language,
            "glossLanguage": glossLanguage,
            "simpler": simpler,
          }),
        ),
      ],
    );
    LanguageGenerationRun? generation;
    final text = isMock
        ? (glossLanguage == "zh" ? card.translation : card.hint)
        : await requestLanguageText(
            provider: provider,
            config: config,
            usageStore: usageStore,
            feature: "language_explanation",
            original: (originalText ?? cached) == null
                ? null
                : GenerationOriginal(
                    output: originalText ?? cached!,
                    model: cached == null ? "unknown" : model,
                    kind: "explanation",
                    contentId: key,
                  ),
            request: request,
            cancel: cancel,
            maxChars: 1600,
            onCaptured: (run) => generation = run,
            parse: (raw) {
              final text = raw.trim();
              if (text.isEmpty) {
                throw const FormatException("Empty explanation reply");
              }
              return text;
            },
          );
    cancel.checkCancelled();
    await store.cacheExplanation(
      key: key,
      card: card,
      model: generation?.model ?? model,
      promptVersion: _promptVersion,
      text: text,
      cancel: cancel,
    );
    await LanguageGenerationStore(store.db)
        .link("explanation", key, generation?.id);
    return text;
  }
}
