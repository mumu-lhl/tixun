import "dart:convert";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:uuid/uuid.dart";

import "../../core/ai/ai_usage_store.dart";
import "../../core/ai/chat_provider.dart";
import "../../core/ai/prompt_settings.dart";
import "../../core/database/database.dart";
import "language_stream.dart";
import "language_store.dart";
import "sentence_content.dart";
import "sentence_store.dart";

class SentenceExplanation {
  const SentenceExplanation({
    required this.store,
    required this.provider,
    required this.config,
    this.usageStore,
    this.prompts,
  });

  final LanguageLearningStore store;
  final ChatProvider provider;
  final ProviderConfig config;
  final AiUsageStore? usageStore;
  final PromptSettings? prompts;
  static const _promptVersion = 1;

  Future<String> explain({
    required SentenceCard card,
    required String glossLanguage,
    required bool simpler,
    required CancelToken cancel,
  }) async {
    final isMock = provider is MockChatProvider;
    final model = isMock ? "Mock" : config.model;
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
              ?prompts?.overrides[LanguagePrompt.sentenceExplanation.id],
            ]),
          ),
        )
        .toString();
    cancel.checkCancelled();
    final cached = await store.cachedExplanation(key);
    cancel.checkCancelled();
    if (cached != null) return cached;

    final request = AiRequest(
      instructions: LanguagePrompt.sentenceExplanation.instructions(prompts),
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
    final started = DateTime.now();
    final buffer = StringBuffer();
    final reasoning = StringBuffer();
    var complete = false;
    var status = "error";
    var breakdownComplete = true;
    AiTokenUsage? usage;
    try {
      final stream = isMock
          ? Stream.value(
              AiChunk(
                text: glossLanguage == "zh" ? card.translation : card.hint,
                completed: true,
              ),
            )
          : boundedLanguageStream(
              (transport) =>
                  provider.start(config).complete(request, transport),
              cancel,
            );
      await for (final chunk in stream) {
        cancel.checkCancelled();
        usage = chunk.usage ?? usage;
        if (chunk.calls.isNotEmpty ||
            (complete &&
                (chunk.text.isNotEmpty || chunk.reasoning.isNotEmpty)) ||
            buffer.length + chunk.text.length > 1600) {
          throw const FormatException("Invalid explanation reply");
        }
        buffer.write(chunk.text);
        breakdownComplete &= reasoning.length + chunk.reasoning.length <= 32000;
        if (breakdownComplete) reasoning.write(chunk.reasoning);
        complete |= chunk.completed;
      }
      cancel.checkCancelled();
      if (!complete) {
        status = "incomplete";
        throw const FormatException("Incomplete explanation reply");
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) throw const FormatException("Empty explanation reply");
      await store.cacheExplanation(
        key: key,
        card: card,
        model: model,
        promptVersion: _promptVersion,
        text: text,
        cancel: cancel,
      );
      status = "complete";
      return text;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) status = "cancelled";
      rethrow;
    } finally {
      final recorder = usageStore;
      if (recorder != null && !isMock) {
        try {
          await recorder.record(
            AiUsageCapture(
              actionId: const Uuid().v4(),
              providerKind: config.kind,
              endpoint: config.baseUrl,
              model: model,
              feature: "language_explanation",
              status: cancel.isCancelled ? "cancelled" : status,
              occurredAt: started,
              durationMs: DateTime.now().difference(started).inMilliseconds,
              usage: usage,
            ),
            request: breakdownComplete ? request : null,
            response: buffer.toString(),
            reasoning: reasoning.toString(),
          );
        } catch (_) {
          // Usage recording must not obscure either an explanation or its error.
        }
      }
    }
  }
}
