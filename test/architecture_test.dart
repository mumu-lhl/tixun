import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/prompt_settings.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/chat/learning_run.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/practice/question_spec.dart';
import 'package:tixun/features/review/review_store.dart';

import 'support/chatgpt_fixture.dart';

class ScriptProvider implements ChatProvider {
  ScriptProvider(this.events);
  final List<AiChunk> Function(int turn) events;
  int turns = 0;
  final requests = <AiRequest>[];
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests.add(request);
        for (final e in events(++turns)) {
          yield e;
        }
      });
}

class WaitingKeyStore extends MemoryKeyStore {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(String provider, String value) async {
    if (value == 'preference-test-key') {
      started.complete();
      await release.future;
    }
    await super.write(provider, value);
  }
}

void main() {
  test('One capability policy resolves effort, vision and thinking/tool compatibility', () async {
    final db = AppDatabase.memory();
    final base = await db.config();
    expect(AiOptions(base).toolsAvailable, true);
    expect(AiOptions(base.copyWith(thinking: true)).toolsAvailable, false);
    expect(
      AiOptions(base.copyWith(kind: 'compatible', supportsTools: false))
          .toolsAvailable,
      false,
    );
    final chat = base.copyWith(
      kind: 'chatgpt',
      baseUrl: 'https://api.openai.com/v1',
      thinking: true,
      effort: 'max',
    );
    expect(AiOptions(chat).toolsAvailable, true);
    expect(AiOptions(chat).effortParameter, 'xhigh');
    expect(AiOptions(chat).offLabel, '模型默认');
    expect(AiOptions(base.copyWith(kind: 'compatible')).offChoiceLabel, '模型默认');
    expect(AiOptions.forSession(chat, 'off').thinking, false);
    expect(AiOptions.forSession(chat, '').effort, 'max');
    expect(AiOptions(base.copyWith(model: 'deepseek-v4-pro')).vision, false);
    await db.close();
  });

  test(
    'Account snapshot is read-only and never exposes credential records',
    () async {
      final f = ChatGptFixture();
      await f.seed();
      final snapshot = await f.auth.snapshot();
      expect(snapshot.accounts.single.id, snapshot.activeId);
      expect(snapshot.accounts.single.label, 'student@example.test');
      expect(() => snapshot.accounts.clear(), throwsUnsupportedError);
      final stored = jsonDecode(
        (await f.keys.read('chatgpt.oauth.v1'))!,
      ) as Map<String, dynamic>;
      stored['active'] = 'missing-registration';
      await f.keys.write('chatgpt.oauth.v1', jsonEncode(stored));
      expect((await f.auth.snapshot()).activeId, isNull);
      await expectLater(f.auth.accessToken(), throwsA(isA<AiFailure>()));
    },
  );

  test('Controller shutdown waits for preferences independently of study operations', () async {
    final root = await Directory.systemTemp.createTemp('tixun-prefs-barrier');
    final keys = WaitingKeyStore();
    var c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: keys,
      chatProvider: MockChatProvider(),
    );
    final save = c.saveSettings(
      c.config.copyWith(model: 'deepseek-v4-pro', vision: false),
      'preference-test-key',
    );
    await keys.started.future;
    var closed = false;
    final closing = c.shutdown().then((_) => closed = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(closed, false);
    keys.release.complete();
    await save;
    await closing;
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
      chatProvider: MockChatProvider(),
    );
    expect(c.config.model, 'deepseek-v4-pro');
    await c.shutdown();
    await root.delete(recursive: true);
  });

  test('Practice revision atomically inherits current knowledge links and retains old attempts', () async {
    final db = AppDatabase.memory();
    final dir = await Directory.systemTemp.createTemp('tixun-revision');
    final study = StudyStore(db, AttachmentStore(dir)),
        practice = PracticeStore(db);
    final knowledge = await study.saveKnowledge(
      const KnowledgeDraft(title: '加法', content: '两个量的和'),
    );
    final old = await practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '2+2',
        answers: [
          ['4'],
        ],
      ),
      knowledgeIds: [knowledge.id],
    );
    final attempt = await practice.begin(old);
    await practice.submit(attempt.id, ['4']);
    final revision = await practice.revise(
      old,
      const QuestionSpec(
        kind: 'numeric',
        stem: '3+3',
        answers: [
          ['6'],
        ],
      ),
    );
    final links = await (db.select(
      db.practiceQuestionKnowledge,
    )..where((l) => l.questionId.equals(revision))).get();
    expect(links.single.knowledgeId, knowledge.id);
    expect((await practice.detail(revision)).row.parentQuestionId, old);
    expect((await practice.detail(old)).attempts.single.id, attempt.id);
    expect((await practice.detail(old)).responses[attempt.id], ['4']);
    study.dispose();
    practice.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  group('Learning run public interface', () {
    late AppDatabase db;
    late Directory dir;
    late StudyStore study;
    late PracticeStore practice;
    late ReviewStore review;
    late ChatSession session;
    late ProviderConfig config;
    setUp(() async {
      db = AppDatabase.memory();
      dir = await Directory.systemTemp.createTemp('tixun-learning-run');
      study = StudyStore(db, AttachmentStore(dir));
      practice = PracticeStore(db);
      review = ReviewStore(db);
      session = await db.createSession(mode: 'exam');
      config = (await db.config()).copyWith(
        kind: 'chatgpt',
        baseUrl: 'https://api.openai.com/v1',
        thinking: true,
      );
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: 'reply',
              sessionId: session.id,
              role: 'assistant',
              content: '',
              createdAt: DateTime.now(),
            ),
          );
    });
    tearDown(() async {
      study.dispose();
      practice.dispose();
      review.dispose();
      await db.close();
      await dir.delete(recursive: true);
    });
    Future<LearningRunResult> run(
      ScriptProvider p, {
      String mode = 'guided',
      CancelToken? cancel,
      Future<void> Function(LearningRunResult)? progress,
    }) => LearningRun(db, AttachmentStore(dir), study, practice, review, p).run(
      sessionId: session.id,
      runId: 'reply',
      requestConfig: config,
      requestPrompts: PromptSettings(),
      history: [],
      images: [],
      mode: mode,
      authorized: true,
      cancel: cancel ?? CancelToken(),
      confirm: (_, _, _) async => false,
      onProgress: progress ?? (_) async {},
    );

    test(
      'Incomplete or duplicate terminal events cannot execute a data tool',
      () async {
        const call = ToolCall(
          'write',
          'create_knowledge',
          '{"title":"injected","subject":"数学","content":"content"}',
        );
        for (final events in [
          [const AiChunk(text: 'partial')],
          [
            const AiChunk(calls: [call]),
          ],
          [
            const AiChunk(completed: true),
            const AiChunk(completed: true, calls: [call]),
          ],
        ]) {
          await expectLater(
            run(ScriptProvider((_) => events)),
            throwsA(isA<AiFailure>()),
          );
          expect(await study.searchKnowledge(), isEmpty);
          expect(await db.select(db.aiToolOperations).get(), isEmpty);
        }
      },
    );

    test('Exam progress and failures never publish an answer before a submitted question', () async {
      final progress = <LearningRunResult>[];
      await expectLater(
        run(
          ScriptProvider((_) => [const AiChunk(text: '答案是 42')]),
          mode: 'exam',
          progress: (p) async => progress.add(p),
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(progress, isNotEmpty);
      expect(progress.every((p) => p.text.isEmpty && !p.quizCreated), true);
    });

    test(
      'Runtime enforces four tool rounds independently of provider protocol',
      () async {
        final provider = ScriptProvider(
          (turn) => [
            AiChunk(
              completed: true,
              calls: [ToolCall('read-$turn', 'get_learning_progress', '{}')],
            ),
          ],
        );
        await expectLater(
          run(provider),
          throwsA(
            isA<AiFailure>().having((e) => e.message, 'limit', contains('4 轮')),
          ),
        );
        expect(provider.turns, 4);
        expect(
          provider.requests.last.messages
              .where((m) => m.role == AiRole.tool)
              .length,
          3,
        );
      },
    );

    test(
      'Turn totals replace streaming estimates and sum correctly across tools',
      () async {
        final provider = ScriptProvider(
          (turn) => turn == 1
              ? [
                  const AiChunk(text: 'before', tokens: 5),
                  const AiChunk(
                    completed: true,
                    tokens: 10,
                    calls: [ToolCall('read', 'get_learning_progress', '{}')],
                  ),
                ]
              : [
                  const AiChunk(text: 'after', tokens: 12),
                  const AiChunk(completed: true, tokens: 14),
                ],
        );
        final result = await run(provider);
        expect(result.tokens, 24);
        expect(result.text, 'before\n\nafter');
        expect(
          provider.requests.last.messages
              .where((m) => m.role == AiRole.tool)
              .single
              .callId,
          'read',
        );
      },
    );

    test(
      'Cancellation is enforced even if a custom provider forgets to check it',
      () async {
        final cancel = CancelToken();
        final values = <String>[];
        await expectLater(
          run(
            ScriptProvider(
              (_) => [
                const AiChunk(text: 'first'),
                const AiChunk(text: 'second', completed: true),
              ],
            ),
            cancel: cancel,
            progress: (p) async {
              values.add(p.text);
              cancel.cancel('user');
            },
          ),
          throwsA(isA<DioException>()),
        );
        expect(values, ['first']);
      },
    );
  });
}
