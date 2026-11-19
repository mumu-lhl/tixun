import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/language_learning/language_store.dart';
import 'package:tixun/features/language_learning/writing_ai.dart';
import 'package:tixun/features/language_learning/writing_store.dart';
import 'package:tixun/features/language_learning/writing_task_ai.dart';
import 'package:tixun/features/language_learning/sentence_content.dart';

class _WritingProvider implements ChatProvider {
  int calls = 0;
  bool complete = true;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        calls++;
        yield AiChunk(
          completed: complete,
          text: jsonEncode({
            'task': 3,
            'organization': 3,
            'language': 2,
            'summary': 'Explain what you would like to read.',
            'notes': [
              {
                'kind': 'issue',
                'quote': 'want join',
                'comment': 'Use to before join.',
              },
              {
                'kind': 'issue',
                'quote': 'Made-up sentence',
                'comment': 'Not in this draft.',
              },
            ],
          }),
        );
      });
}

class _TaskProvider implements ChatProvider {
  final requests = <AiRequest>[];
  late Map<String, String> data;
  bool complete = true;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests.add(request);
        yield AiChunk(text: jsonEncode(data), completed: complete);
      });
}

const writingTaskId = 'test-writing-task';

void main() {
  test('revision preserves the original with anchored feedback even if reassessment fails', () async {
    final db = AppDatabase.memory();
    final store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final provider = _WritingProvider();
    final ai = WritingAi(
      task: const WritingTask(
        writingTaskId,
        'Write a short email to join a book club.',
      ),
      store: store,
      provider: provider,
      config: const ProviderConfig(
        id: 1,
        kind: 'openai',
        baseUrl: 'https://example.com',
        model: 'test-model',
        vision: false,
        supportsTools: false,
        thinking: false,
        supportsThinking: false,
        effort: '',
      ),
    );
    Future<String> evaluate(String draft) =>
        ai.evaluate(text: draft, glossLanguage: 'en', cancel: CancelToken());

    const initial = 'Hello, I want join the book club.';
    const revision = 'Hello, I want to join the book club.';
    await store.saveWritingDraft(initial, taskId: writingTaskId);
    expect(await store.writingDraft(taskId: writingTaskId), initial);
    expect(provider.calls, 0);

    final first = await evaluate(initial);
    final note = (await store.writingNotes(first)).single;
    expect(initial.substring(note.startOffset, note.endOffset), 'want join');
    expect((await store.writingFeedback(first))?.languageScore, 2);

    provider.complete = false;
    await expectLater(evaluate(revision), throwsFormatException);
    expect(await store.writingDraft(taskId: writingTaskId), revision);
    final interruptedHistory = await store
        .writingHistory(taskId: writingTaskId)
        .first;
    expect(interruptedHistory.map((row) => row.version.content), [
      revision,
      initial,
    ]);
    expect(interruptedHistory.first.evaluation, isNull);
    expect(interruptedHistory.last.evaluation?.versionId, first);

    provider.complete = true;
    final second = await evaluate(revision);
    expect(second, isNot(first));
    expect(await store.writingNotes(second), isEmpty);
    expect(
      await store.writingHistory(taskId: writingTaskId).first,
      hasLength(2),
    );
    expect(await db.select(db.chatMessages).get(), isEmpty);
  });

  test('generated writing tasks persist and partition drafts and versions', () async {
    final db = AppDatabase.memory();
    final store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final provider = _TaskProvider();
    final ai = WritingTaskAi(
      store: store,
      provider: provider,
      config: const ProviderConfig(
        id: 1,
        kind: 'openai',
        baseUrl: 'https://example.com',
        model: 'test-model',
        vision: false,
        supportsTools: true,
        thinking: false,
        supportsThinking: false,
        effort: '',
      ),
    );
    Future<WritingTask> generate(WritingTaskKind kind) => ai.generate(
      kind: kind,
      level: SentenceLevel.intermediate,
      topic: 'Community',
      cancel: CancelToken(),
    );
    provider.data = {
      'title': 'A letter to the volunteer team',
      'prompt': 'Write an email asking the volunteers for a weekend training session.',
    };
    final application = await generate(WritingTaskKind.application);
    expect(application.passage, isNull);
    expect(provider.requests.single.maxOutputTokens, 750);
    final source =
        'Maya found a sketchbook with a green cover as the outdoor market was closing. It held pictures of the stalls and customers throughout the day. On the last page someone had left a note promising to return at noon. Maya looked around for the owner. '
        'A shopkeeper pointed to a narrow lane where the artists usually waited '
        'for a bus. Maya wondered if she still had time to reach them. The next bus was not due for another fifteen minutes.';
    provider.data = {
      'title': 'An unfinished search',
      'prompt': 'Continue the story and explain how Maya finds the owner.',
      'passage': source,
    };
    final story = await generate(WritingTaskKind.continuation);
    expect(story.passage, source);
    expect(story.rubric, contains('source'));
    expect(provider.requests.last.tools, isEmpty);
    expect(provider.requests.last.maxOutputTokens, 1750);
    final saved = await store.savedWritingTasks().first;
    expect(
      saved.map((row) => openWritingTask(row).id),
      containsAll([application.id, story.id]),
    );
    final first = await store.snapshotWriting(
      'Her search continued.',
      taskId: application.id,
    );
    final second = await store.snapshotWriting(
      'Her search continued.',
      taskId: story.id,
    );
    expect(first, isNot(second));
    expect(
      (await store.writingHistory(taskId: application.id).first)
          .single
          .version
          .id,
      first,
    );
    expect(await store.writingDraft(taskId: writingTaskId), isEmpty);
    provider.complete = false;
    await expectLater(
      generate(WritingTaskKind.continuation),
      throwsFormatException,
    );
    expect(await store.savedWritingTasks().first, hasLength(2));
    expect(await db.select(db.chatMessages).get(), isEmpty);
  });
}
