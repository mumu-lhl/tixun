import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/ai_usage_store.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/ai/prompt_settings.dart';
import '../../core/database/database.dart';
import 'language_stream.dart';
import 'language_store.dart';
import 'writing_feedback.dart';
import 'writing_store.dart';

class WritingAi {
  const WritingAi({
    required this.store,
    required this.provider,
    required this.config,
    this.usageStore,
    this.prompts,
    required this.task,
  });

  final LanguageLearningStore store;
  final ChatProvider provider;
  final ProviderConfig config;
  final AiUsageStore? usageStore;
  final PromptSettings? prompts;
  final WritingTask task;
  static const _promptVersion = 1;

  Future<String> evaluate({
    required String text,
    required String glossLanguage,
    required CancelToken cancel,
  }) async {
    cancel.checkCancelled();
    final version = await store.snapshotWriting(text, taskId: task.id);
    cancel.checkCancelled();
    final isMock = provider is MockChatProvider;
    final existing = await store.writingFeedback(version);
    cancel.checkCancelled();
    if (existing != null && (!existing.isMock || isMock)) return version;

    final request = AiRequest(
      instructions: LanguagePrompt.writingFeedback.instructions(prompts),
      messages: [
        AiMessage.user(
          jsonEncode({
            'task': task.prompt,
            'sourcePassage': ?task.passage,
            'rubric': ?task.rubric,
            'draft': text,
            'feedbackLanguage': glossLanguage,
          }),
        ),
      ],
    );
    final started = DateTime.now();
    final body = StringBuffer();
    final reasoning = StringBuffer();
    AiTokenUsage? usage;
    var completed = false;
    var status = 'error';
    var breakdownComplete = true;
    final model = isMock ? 'Mock' : config.model;
    try {
      final stream = isMock
          ? Stream.value(
              AiChunk(
                completed: true,
                text: jsonEncode({
                  'task': 2,
                  'organization': 2,
                  'language': 2,
                  'summary': glossLanguage == 'zh'
                      ? '这是演示反馈，未评估你的作文。请自行检查作文是否满足所有任务要求。'
                      : 'This is demo feedback, not an assessment. Check whether '
                            'your draft addresses every part of the task.',
                  'notes': [],
                }),
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
            (completed &&
                (chunk.text.isNotEmpty || chunk.reasoning.isNotEmpty)) ||
            body.length + chunk.text.length > 8500) {
          throw const FormatException('Invalid writing feedback reply');
        }
        completed |= chunk.completed;
        body.write(chunk.text);
        breakdownComplete &= reasoning.length + chunk.reasoning.length <= 32000;
        if (breakdownComplete) reasoning.write(chunk.reasoning);
      }
      cancel.checkCancelled();
      if (!completed) {
        status = 'incomplete';
        throw const FormatException('Incomplete writing feedback reply');
      }
      final feedback = WritingFeedback.parse(body.toString(), text);
      await store.saveWritingFeedback(
        versionId: version,
        feedback: feedback,
        model: model,
        promptVersion: _promptVersion,
        isMock: isMock,
        cancel: cancel,
      );
      status = 'complete';
      return version;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) status = 'cancelled';
      rethrow;
    } finally {
      final recorder = usageStore;
      if (!isMock && recorder != null) {
        try {
          await recorder.record(
            AiUsageCapture(
              actionId: const Uuid().v4(),
              providerKind: config.kind,
              endpoint: config.baseUrl,
              model: model,
              feature: 'language_writing',
              status: cancel.isCancelled ? 'cancelled' : status,
              occurredAt: started,
              durationMs: DateTime.now().difference(started).inMilliseconds,
              usage: usage,
            ),
            request: breakdownComplete ? request : null,
            response: body.toString(),
            reasoning: reasoning.toString(),
          );
        } catch (_) {
          // Usage accounting must not obscure an evaluation result.
        }
      }
    }
  }
}
