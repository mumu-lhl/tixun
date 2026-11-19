import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/ai_usage_store.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/ai/prompt_settings.dart';
import '../../core/database/database.dart';
import 'exam_material.dart';
import 'language_json_request.dart';
import 'language_store.dart';
import 'sentence_content.dart';
import 'writing_store.dart';

enum WritingTaskKind { application, continuation }

extension WritingTaskLibrary on LanguageLearningStore {
  Stream<List<LearningWritingTaskRow>> savedWritingTasks() =>
      (db.select(db.learningWritingTasks)
            ..where((row) => row.model.equals('Mock').not())
            ..orderBy([
              (row) => OrderingTerm.desc(row.createdAt),
              (row) => OrderingTerm.desc(row.rowId),
            ])
            ..limit(40))
          .watch();
}

WritingTask openWritingTask(LearningWritingTaskRow row) => WritingTask(
  row.id,
  row.prompt,
  title: row.title,
  passage: row.passage,
  rubric: row.kind == WritingTaskKind.continuation.name
      ? continuationRubric
      : null,
);

class WritingTaskAi {
  const WritingTaskAi({
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
  static const promptVersion = 1;

  Future<WritingTask> generate({
    required WritingTaskKind kind,
    required SentenceLevel level,
    required String topic,
    required CancelToken cancel,
    ExamProfile profile = ExamProfile.zhejiang2026,
  }) async {
    if (topic.length > 100) {
      throw const FormatException('Oversized writing topic');
    }
    cancel.checkCancelled();
    if (provider is MockChatProvider) {
      throw const FormatException('Writing generation requires an AI provider');
    }
    final task = await requestLanguageJson(
      provider: provider,
      config: config,
      usageStore: usageStore,
      feature: 'language_writing_task',
      request: AiRequest(
        instructions: LanguagePrompt.writingTask.instructions(prompts),
        messages: [
          AiMessage.user(
            jsonEncode({
              'profile': profile.id,
              'kind': kind.name,
              'level': level.name,
              if (topic.trim().isNotEmpty) 'topic': topic.trim(),
            }),
          ),
        ],
      ),
      cancel: cancel,
      maxChars: 6200,
      parse: (data) => _validateTask(data, kind),
    );
    return store.runOperation(
      () => store.db.transaction(() async {
        cancel.checkCancelled();
        final table = store.db.learningWritingTasks;
        final existing =
            await (store.db.select(table)
                  ..where(
                    (row) =>
                        row.kind.equals(kind.name) &
                        row.profile.equals(profile.id) &
                        row.model.equals(config.model) &
                        row.prompt.equals(task.prompt) &
                        (task.passage == null
                            ? row.passage.isNull()
                            : row.passage.equals(task.passage!)),
                  )
                  ..limit(1))
                .getSingleOrNull();
        cancel.checkCancelled();
        if (existing != null) return openWritingTask(existing);
        final row = await store.db
            .into(table)
            .insertReturning(
              LearningWritingTasksCompanion.insert(
                id: 'generated:${const Uuid().v4()}',
                kind: kind.name,
                profile: profile.id,
                level: level.name,
                topic: topic.trim(),
                title: task.title,
                prompt: task.prompt,
                passage: Value(task.passage),
                model: config.model,
                promptVersion: promptVersion,
                createdAt: DateTime.now(),
              ),
            );
        cancel.checkCancelled();
        return openWritingTask(row);
      }),
    );
  }
}

({String title, String prompt, String? passage}) _validateTask(
  Object? json,
  WritingTaskKind kind,
) {
  if (json is! Map ||
      json.keys.any(
        (key) => !const {'title', 'prompt', 'passage'}.contains(key),
      )) {
    throw const FormatException('Invalid writing task');
  }
  String text(Object? value, int max) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > max ||
        !_latin.hasMatch(value) ||
        !_englishText.hasMatch(value) ||
        _key.hasMatch(value)) {
      throw const FormatException('Invalid writing task text');
    }
    return value.trim();
  }

  final rawPassage = json['passage'];
  if (kind == WritingTaskKind.continuation
      ? rawPassage == null
      : rawPassage != null) {
    throw const FormatException('Unexpected writing task passage');
  }
  final passage = rawPassage == null ? null : text(rawPassage, 2600);
  if (passage != null &&
      (passage.split(RegExp(r'\s+')).length < 75 ||
          passage.split(RegExp(r'\s+')).length > 260)) {
    throw const FormatException('Invalid continuation length');
  }
  return (
    title: text(json['title'], 120),
    prompt: text(json['prompt'], 900),
    passage: passage,
  );
}

final _latin = RegExp(r'\p{Script=Latin}', unicode: true);
final _englishText = RegExp(
  r'^[\p{Script=Latin}\p{M}\p{N}\p{P}\p{Zs}\r\n]+$',
  unicode: true,
);
final _key = RegExp(r'(?:model|sample)\s*answer\s*:', caseSensitive: false);
