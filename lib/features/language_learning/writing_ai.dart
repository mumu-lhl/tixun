import "dart:convert";

import "package:dio/dio.dart";

import "../../core/ai/ai_usage_store.dart";
import "../../core/ai/chat_provider.dart";
import "../../core/ai/prompt_settings.dart";
import "../../core/database/database.dart";
import "language_json_request.dart";
import "generation_store.dart";
import "language_store.dart";
import "writing_feedback.dart";
import "writing_store.dart";
import "generation_provider.dart";

class WritingAi {
  const WritingAi({
    required this.store,
    required this.provider,
    required this._config,
    this.usageStore,
    this.prompts,
    required this.task,
  });

  final LanguageLearningStore store;
  final ChatProvider provider;
  final ProviderConfig _config;
  ProviderConfig get config => languageConfiguration(provider, _config);
  final AiUsageStore? usageStore;
  final PromptSettings? prompts;
  final WritingTask task;
  static const _promptVersion = 1;

  Future<String> evaluate({
    required String text,
    required String glossLanguage,
    required CancelToken cancel,
    bool regenerate = false,
  }) async {
    cancel.checkCancelled();
    final previousVersion = await store.snapshotWriting(text, taskId: task.id);
    cancel.checkCancelled();
    final isMock = provider is MockChatProvider;
    final existing = await store.writingFeedback(previousVersion);
    cancel.checkCancelled();
    if (!regenerate && existing != null && (!existing.isMock || isMock)) {
      return previousVersion;
    }
    final oldNotes = existing == null
        ? const <LearningWritingNote>[]
        : await store.writingNotes(previousVersion);
    final original = existing == null
        ? null
        : GenerationOriginal(
            output: jsonEncode({
              "task": existing.taskScore,
              "organization": existing.organizationScore,
              "language": existing.languageScore,
              "summary": existing.summary,
              "notes": [
                for (final n in oldNotes)
                  {
                    "quote": text.substring(n.startOffset, n.endOffset),
                    "kind": n.kind,
                    "comment": n.comment,
                  },
              ],
            }),
            model: existing.model,
            kind: "writing_feedback",
            contentId: previousVersion,
          );

    final request = AiRequest(
      instructions: LanguagePrompt.writingFeedback.instructions(prompts),
      messages: [
        AiMessage.user(
          jsonEncode({
            "task": task.prompt,
            "sourcePassage": ?task.passage,
            "rubric": ?task.rubric,
            "draft": text,
            "feedbackLanguage": glossLanguage,
          }),
        ),
      ],
    );
    LanguageGenerationRun? generation;
    final feedback = isMock
        ? WritingFeedback.parse(
            jsonEncode({
              "task": 2,
              "organization": 2,
              "language": 2,
              "summary": glossLanguage == "zh"
                  ? "这是演示反馈，未评估你的作文。请自行检查作文是否满足所有任务要求。"
                  : "This is demo feedback, not an assessment. Check whether your draft addresses every part of the task.",
              "notes": [],
            }),
            text,
          )
        : await requestLanguageText(
            provider: provider,
            config: config,
            usageStore: usageStore,
            feature: "language_writing",
            original: original,
            request: request,
            cancel: cancel,
            maxChars: 8500,
            outputFormat: "json",
            onCaptured: (run) => generation = run,
            parse: (raw) => WritingFeedback.parse(raw, text),
          );
    cancel.checkCancelled();
    final linked = await LanguageGenerationStore(store.db)
        .linkedContent("writing_feedback", generation?.id);
    if (linked != null && await store.writingFeedback(linked) != null) {
      return linked;
    }
    final version = regenerate
        ? await store.snapshotWriting(text, taskId: task.id, forceNew: true)
        : previousVersion;
    await store.saveWritingFeedback(
      versionId: version,
      feedback: feedback,
      model: isMock ? "Mock" : (generation?.model ?? config.model),
      promptVersion: _promptVersion,
      isMock: isMock,
      cancel: cancel,
    );
    await LanguageGenerationStore(store.db)
        .link("writing_feedback", version, generation?.id);
    return version;
  }
}
