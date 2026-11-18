import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/ai_usage_store.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/prompt_settings.dart';
import 'package:tixun/core/ai/quiz_tool.dart';
import 'package:tixun/core/ai/visual_schema.dart';
import 'package:tixun/core/ai/visual_tool.dart';
import 'package:tixun/core/ai/visual_toolset.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/practice/question_spec.dart';
import 'package:tixun/features/progress/learning_profile.dart';

class _Provider implements ChatProvider {
  _Provider(this.respond);
  final AiChunk Function(AiRequest request, int turn) respond;
  final requests = <AiRequest>[];

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests.add(request);
        yield respond(request, requests.length);
      });
}

const _done = AiChunk(text: '解释', completed: true);
const _load = AiChunk(
  completed: true,
  reasoning: 'Need a diagram.',
  usage: AiTokenUsage(inputTokens: 100, outputTokens: 10),
  calls: [ToolCall('load', enableVisualToolsName, '{}')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppController> open(_Provider provider, {bool drawing = true}) async {
    final root = await Directory.systemTemp.createTemp('prompt-cost');
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      provider,
    );
    addTearDown(() async {
      await c.shutdown();
      await root.delete(recursive: true);
    });
    await c.initialize();
    if (drawing) await c.setAiDrawingEnabled(true);
    c.prompts = c.prompts.withLanguage('zh');
    await c.newSession();
    return c;
  }

  for (final exam in [false, true]) {
    test('drawing is opt-in with no protocol or index (exam=$exam)', () async {
      final provider = _Provider((_, _) => _done);
      final c = await open(provider, drawing: false);
      if (exam) await c.mode('exam');
      await c.send('请画图并出一道题');
      final request = provider.requests.single;
      expect(c.aiDrawingEnabled, false);
      expect(
        request.tools.map((t) => t.name),
        isNot(contains(enableVisualToolsName)),
      );
      final payload = jsonEncode(encodeCompletion(c.config, request));
      for (final field in [
        'enable_visual_tools',
        'create_visual',
        'update_visual',
        'get_visual',
        'question_scene',
        'solution_scene',
        'visual_id',
        'visual_revision',
        'Saved visual index',
      ]) {
        expect(payload, isNot(contains(field)));
      }
      expect(request.instructions, isNot(contains(visualDslInstructions)));
      final quiz = request.tools.singleWhere((t) => t.name == 'create_quiz');
      expect(
        (quiz.parameters['properties'] as Map)['kind']['enum'],
        isNot(contains('point_select')),
      );
    });

    test(
      'disabled drawing rejects hidden quiz scene arguments (exam=$exam)',
      () async {
        final provider = _Provider(
          (_, turn) => turn == 1
              ? AiChunk(
                  completed: true,
                  calls: [
                    ToolCall(
                      'quiz',
                      'create_quiz',
                      jsonEncode({
                        'kind': 'numeric',
                        'stem': '2+2',
                        'subject': '数学',
                        'answers': [
                          ['4'],
                        ],
                        'explanation': '相加得4',
                        'question_scene': visualDslExamples.first,
                      }),
                    ),
                  ],
                )
              : _done,
        );
        final c = await open(provider, drawing: false);
        if (exam) await c.mode('exam');
        await c.send('请出题');
        final result =
            jsonDecode(provider.requests.last.messages.last.text) as Map;
        expect(result['ok'], false);
        expect(await c.db.select(c.db.practiceQuestions).get(), isEmpty);
        expect(await c.db.select(c.db.visualScenes).get(), isEmpty);
      },
    );
  }

  test('disabled drawing rejects the loader before execution', () async {
    final provider = _Provider((_, _) => _load);
    final c = await open(provider, drawing: false);
    await c.send('请画图');
    expect(c.messages.last.status, 'error');
    expect(provider.requests, hasLength(1));
    expect(await c.db.select(c.db.visualScenes).get(), isEmpty);
  });

  test(
    'turning drawing off removes saved indices without altering history',
    () async {
      final provider = _Provider((_, _) => _done);
      final c = await open(provider);
      await c.send('解释导数');
      final source = c.messages.last;
      final scene = await c.visual.create(
        sceneJson: jsonEncode(visualDslExamples.first),
        messageId: source.id,
        title: 'SAVED_FIGURE_TITLE',
      );
      final originals = await c.db.select(c.db.chatMessages).get();
      await c.send('继续');
      expect(
        provider.requests.last.messages.last.text,
        contains('SAVED_FIGURE_TITLE'),
      );
      await c.setAiDrawingEnabled(false);
      await c.send('再继续');
      final request = provider.requests.last;
      expect(
        request.messages.map((m) => m.text).join(),
        isNot(contains('Saved visual index')),
      );
      expect(
        request.messages.map((m) => m.text).join(),
        isNot(contains('SAVED_FIGURE_TITLE')),
      );
      expect(request.messages[1].text, source.content);
      final stored = await c.db.select(c.db.chatMessages).get();
      for (final original in originals) {
        final current = stored.singleWhere((m) => m.id == original.id);
        expect(current.content, original.content);
        expect(current.role, original.role);
      }
      expect(stored.where((m) => m.role == 'user').map((m) => m.content), [
        '解释导数',
        '继续',
        '再继续',
      ]);
      expect(await c.visual.get(scene), isNotNull);
    },
  );

  test(
    'chat drawing override enables discovery without changing defaults',
    () async {
      late AppController c;
      final provider = _Provider((_, _) {
        expect(c.busy, true);
        c.setSessionDrawingEnabled(
          false,
        ); // A running request cannot change policy.
        return _done;
      });
      c = await open(provider, drawing: false);
      c.setSessionDrawingEnabled(true);
      await c.send('解释导数');
      expect(c.sessionDrawingOverride, true);
      expect(c.aiDrawingEnabled, false);
      expect(await c.db.preference(aiDrawingEnabledKey), isNull);
      expect(
        provider.requests.single.tools.map((t) => t.name),
        contains(enableVisualToolsName),
      );
      c.setSessionDrawingEnabled(false);
      expect(c.sessionDrawingEnabled, false);
    },
  );

  test(
    'chat drawing off suppresses global drawing protocol and hidden scenes',
    () async {
      final provider = _Provider(
        (_, turn) => turn == 1
            ? AiChunk(
                completed: true,
                calls: [
                  ToolCall(
                    'quiz',
                    'create_quiz',
                    jsonEncode({
                      'kind': 'numeric',
                      'stem': '2+2',
                      'subject': '数学',
                      'answers': [
                        ['4'],
                      ],
                      'explanation': '相加得4',
                      'question_scene': visualDslExamples.first,
                    }),
                  ),
                ],
              )
            : _done,
      );
      final c = await open(provider);
      c.setSessionDrawingEnabled(false);
      await c.send('请画图并出题');
      final request = provider.requests.first;
      expect(
        request.tools.map((t) => t.name),
        isNot(contains(enableVisualToolsName)),
      );
      final quiz = request.tools.singleWhere((t) => t.name == 'create_quiz');
      expect(quiz.parameters['properties'], isNot(contains('visual_id')));
      final result =
          jsonDecode(provider.requests.last.messages.last.text) as Map;
      expect(result['ok'], false);
      expect(await c.db.select(c.db.practiceQuestions).get(), isEmpty);
      expect(await c.db.select(c.db.visualScenes).get(), isEmpty);
      expect(c.aiDrawingEnabled, true);
      expect(await c.db.preference(aiDrawingEnabledKey), 'true');
    },
  );

  test(
    'chat drawing choice is isolated and follow-default stays live',
    () async {
      final provider = _Provider((_, _) => _done);
      final c = await open(provider, drawing: false);
      final first = c.selected!;
      c.setSessionDrawingEnabled(true);
      await c.newSession();
      expect(c.sessionDrawingOverride, isNull);
      expect(c.sessionDrawingEnabled, false);
      await c.send('解释导数');
      expect(
        provider.requests.last.tools.map((t) => t.name),
        isNot(contains(enableVisualToolsName)),
      );
      await c.setAiDrawingEnabled(true);
      expect(c.sessionDrawingEnabled, true);
      c.setSessionDrawingEnabled(false);
      await c.send('继续');
      expect(
        provider.requests.last.tools.map((t) => t.name),
        isNot(contains(enableVisualToolsName)),
      );
      await c.selectSession(first);
      expect(c.sessionDrawingOverride, true);
      await c.setAiDrawingEnabled(false);
      expect(c.sessionDrawingEnabled, true);
      c.setSessionDrawingEnabled(null);
      expect(c.sessionDrawingOverride, isNull);
      expect(c.sessionDrawingEnabled, false);
      await c.setAiDrawingEnabled(true);
      expect(c.sessionDrawingEnabled, true);
      await c.send('继续');
      expect(
        provider.requests.last.tools.map((t) => t.name),
        contains(enableVisualToolsName),
      );
    },
  );

  test('chat drawing overrides survive restarting the controller', () async {
    final root = await Directory.systemTemp.createTemp('chat-drawing-restart');
    AppController? active;
    addTearDown(() async {
      await active?.shutdown();
      await root.delete(recursive: true);
    });
    Future<AppController> reopen() => AppController.openRoot(
      root,
      demo: false,
      seed: false,
      keyStore: MemoryKeyStore(),
      chatProvider: _Provider((_, _) => _done),
    );
    active = await reopen();
    await active.newSession();
    await active.setAiDrawingEnabled(true);
    await active.setSessionDrawingEnabled(false);
    final session = active.selected!.id;
    expect(active.sessionDrawingEnabled, false);
    await active.shutdown();
    active = null;
    active = await reopen();
    expect(active.selected!.id, session);
    expect(active.aiDrawingEnabled, true);
    expect(active.sessionDrawingOverride, false);
    expect(active.sessionDrawingEnabled, false);
    await active.setSessionDrawingEnabled(null);
    await active.shutdown();
    active = await reopen();
    expect(active.sessionDrawingOverride, isNull);
    expect(active.sessionDrawingEnabled, true);
  });

  test(
    'ordinary requests omit large visual schemas and DSL examples',
    () async {
      final provider = _Provider((_, _) => _done);
      final c = await open(provider);
      await c.send('解释一下导数');
      final request = provider.requests.single;
      expect(request.tools.map((t) => t.name), contains(enableVisualToolsName));
      expect(request.instructions, isNot(contains(visualDslInstructions)));
      final quiz = request.tools.singleWhere((t) => t.name == 'create_quiz');
      expect(quiz.parameters['properties'], isNot(contains('question_scene')));
      expect(
        request.tools.map((t) => t.name),
        isNot(contains('create_visual')),
      );

      // A reproducible payload-size comparison, NOT a billed-token estimate.
      final baseline = request.copyWith(
        instructions: '${request.instructions}\n$visualDslInstructions',
        tools: [
          ...request.tools.where(
            (t) => t.name != 'create_quiz' && t.name != enableVisualToolsName,
          ),
          quizToolSchema,
          visualToolSchema,
          updateVisualToolSchema,
          getVisualToolSchema,
        ],
      );
      int bytes(AiRequest r) =>
          utf8.encode(jsonEncode(encodeCompletion(c.config, r))).length;
      debugPrint(
        'Ordinary request UTF-8 bytes: ${bytes(baseline)} -> ${bytes(request)}',
      );
      expect(bytes(request), lessThan(bytes(baseline) ~/ 4));
    },
  );

  test(
    'loading retains complete scene and patch contracts, usage and reasoning',
    () async {
      final provider = _Provider((_, turn) => turn == 1 ? _load : _done);
      final c = await open(provider);
      c.config = c.config.copyWith(thinking: true);
      await c.send('帮助理解抛物线'); // No explicit drawing keyword is required.
      expect(c.messages.last.status, 'complete');
      final request = provider.requests.last;
      expect(request.instructions, contains(visualDslInstructions));
      expect(
        request.tools.map((t) => t.name),
        isNot(contains(enableVisualToolsName)),
      );
      final create = request.tools.singleWhere(
        (t) => t.name == 'create_visual',
      );
      expect(
        (create.parameters['properties'] as Map)['scene'],
        visualSceneSchema,
      );
      final update = request.tools.singleWhere(
        (t) => t.name == 'update_visual',
      );
      expect(update.parameters, updateVisualToolSchema.parameters);
      final quiz = request.tools.singleWhere((t) => t.name == 'create_quiz');
      expect(quiz.parameters['properties'], contains('visual_id'));
      expect(quiz.parameters['properties'], isNot(contains('question_scene')));
      expect(
        request.messages
            .where((m) => m.calls.isNotEmpty)
            .single
            .reasoningContent,
        'Need a diagram.',
      );
      final loadResult = jsonDecode(request.messages.last.text) as Map;
      expect(loadResult['saved'], false);
      expect(await c.study.searchKnowledge(), isEmpty);
      expect(await c.db.select(c.db.aiToolOperations).get(), isEmpty);
      expect(await AiUsageStore(c.db).events(), hasLength(2));
    },
  );

  test('invalid loader arguments do not enable visuals', () {
    final tools = VisualToolset(exam: false);
    for (final args in ['{', '[]', '{"authorized":true}']) {
      expect(
        tools.enable(ToolCall('load', enableVisualToolsName, args))['ok'],
        false,
      );
      expect(tools.enabled, false);
      expect(tools.instructions, isEmpty);
    }
  });

  test('exam discovery exposes private scenes, never exploration tools', () {
    final tools = VisualToolset(exam: true);
    expect(
      tools.tools.first.parameters['properties'],
      isNot(contains('question_scene')),
    );
    tools.enable(const ToolCall('load', enableVisualToolsName, '{}'));
    expect(tools.tools.map((t) => t.name), ['create_quiz']);
    final properties = tools.tools.single.parameters['properties'] as Map;
    expect(properties['question_scene'], visualSceneSchema);
    expect(properties['solution_scene'], visualSceneSchema);
    expect(properties, isNot(contains('visual_id')));
    expect(tools.instructions, contains('only in solution_scene'));
  });

  test('unloaded visual tool calls are rejected before any writes', () async {
    final provider = _Provider(
      (_, _) => const AiChunk(
        completed: true,
        calls: [ToolCall('unexpected', 'create_visual', '{}')],
      ),
    );
    final c = await open(provider);
    await c.send('请解释');
    expect(c.messages.last.status, 'error');
    expect(await c.db.select(c.db.visualScenes).get(), isEmpty);
  });

  test('loading schemas does not authorize study writes', () async {
    final provider = _Provider(
      (_, turn) => turn == 1
          ? _load
          : const AiChunk(
              completed: true,
              calls: [
                ToolCall('write', 'create_knowledge', '{"title":"injected"}'),
              ],
            ),
    );
    final c = await open(provider);
    await c.send('请解释');
    expect(c.messages.last.status, 'error');
    expect(c.pendingTool, isNull);
    expect(await c.study.searchKnowledge(), isEmpty);
  });

  test(
    'configured cumulative budget counts discovery and each batched call',
    () async {
      final provider = _Provider((_, turn) {
        if (turn == 1) return _load;
        if (turn == 5) return _done;
        return AiChunk(
          completed: true,
          calls: [
            for (var i = 0; i < (turn == 4 ? 2 : 3); i++)
              ToolCall('read-$turn-$i', 'get_learning_progress', '{}'),
          ],
        );
      });
      final c = await open(provider);
      await c.setMaxToolCalls(9);
      await c.setTools(true);
      await c.send('查看学习进度');
      expect(c.messages.last.status, 'complete');
      expect(provider.requests, hasLength(5));
      expect(
        provider.requests.last.messages.where((m) => m.role == AiRole.tool),
        hasLength(9),
      );
    },
  );

  test(
    'schema discovery cannot reset or extend the default call budget',
    () async {
      final provider = _Provider(
        (_, turn) => turn == 1
            ? _load
            : AiChunk(
                completed: true,
                calls: [ToolCall('read-$turn', 'get_learning_progress', '{}')],
              ),
      );
      final c = await open(provider);
      await c.setTools(true);
      await c.send('查看学习进度');
      expect(c.maxToolCalls, 8);
      expect(c.messages.last.status, 'error');
      expect(provider.requests, hasLength(9));
      expect(
        provider.requests.last.messages.where((m) => m.role == AiRole.tool),
        hasLength(8),
      );
    },
  );

  test(
    'repeated loading is rejected rather than extending discovery again',
    () async {
      final provider = _Provider((_, _) => _load);
      final c = await open(provider);
      await c.send('解释一下');
      expect(c.messages.last.status, 'error');
      expect(provider.requests, hasLength(2));
      expect(await c.db.select(c.db.aiToolOperations).get(), isEmpty);
    },
  );

  test(
    'a checkpoint is historical data without rewriting previous inputs',
    () async {
      final provider = _Provider((_, _) => _done);
      final c = await open(provider);
      await c.db.setContextSummary(c.selected!.id, '历史摘要 A', null);
      await c.send('解释一下');
      final before = provider.requests.last;
      expect(before.instructions, isNot(contains('历史摘要 A')));
      expect(before.messages.first.text, contains('历史摘要 A'));
      expect(before.messages.last.text, isNot(contains('历史摘要 A')));
      await c.db.setContextSummary(c.selected!.id, '历史摘要 B', null);
      await c.send('继续');
      final after = provider.requests.last;
      expect(after.instructions, before.instructions);
      expect(after.messages.first.text, contains('历史摘要 B'));
      expect(
        after.messages.map((m) => m.text).join(),
        isNot(contains('历史摘要 A')),
      );
      expect(after.messages.last.text, isNot(contains('历史摘要 B')));
      expect(after.messages[1].text, before.messages[1].text);
    },
  );

  test('material requests can load drawings without quizzes, incapable models cannot', () async {
    final provider = _Provider((_, turn) => turn == 1 ? _load : _done);
    final c = await open(provider);
    await c.send('请整理数学公式清单');
    expect(
      provider.requests.first.tools.map((t) => t.name),
      contains(enableVisualToolsName),
    );
    expect(c.messages.last.status, 'complete');
    expect(
      provider.requests.last.tools.map((t) => t.name),
      containsAll(['create_visual', 'update_visual', 'get_visual']),
    );
    expect(
      provider.requests.expand((r) => r.tools).map((t) => t.name),
      isNot(contains('create_quiz')),
    );
    c.config = c.config.copyWith(supportsTools: false);
    await c.send('解释导数');
    expect(provider.requests.last.tools, isEmpty);
  });

  test('changing practice state and profile keeps system and old assistant turns stable', () async {
    final provider = _Provider((_, _) => _done);
    final c = await open(provider);
    await c.send('解释一下');
    final source = c.messages.last;
    final questionId = await c.practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '2+2',
        answers: [
          ['4'],
        ],
        explanation: 'SECRET EXPLANATION',
      ),
      sessionId: c.selected!.id,
      messageId: source.id,
    );
    await c.send('继续');
    final before = provider.requests.last;
    expect(before.messages.last.text, contains('"status":"not_started"'));
    expect(
      before.messages.last.text,
      contains('"source_message_id":"${source.id}"'),
    );
    expect(before.messages.last.text, contains('"source_message_number":2'));
    final attempt = await c.practice.begin(questionId);
    await c.practice.submit(attempt.id, ['4']);
    await const LearningProfile(stage: '高三', region: '浙江').save(c.db);
    await c.send('再继续');
    final after = provider.requests.last;
    expect(after.instructions, before.instructions);
    expect(after.messages.first.text, before.messages.first.text);
    expect(after.messages[1].text, source.content);
    expect(after.messages[2].text, before.messages[2].text);
    expect(after.messages.last.text, contains('"status":"graded"'));
    expect(after.messages.last.text, contains('"stage":"高三"'));
    expect(after.messages.last.text, contains('"user_answer":["4"]'));
    expect(
      after.messages.map((m) => m.text).join(),
      isNot(contains('SECRET EXPLANATION')),
    );
  });

  test('concise defaults preserve requested derivations, full explanations and custom prompts', () {
    final zh = teachingPrompt(
      'direct',
      prompts: PromptSettings().update('direct', 'CUSTOM'),
    );
    final en = teachingPrompt(
      'direct',
      prompts: PromptSettings().withLanguage('en'),
    );
    expect(zh, contains('CUSTOM'));
    expect(zh, contains('不省略用户要求的范围、关键推导、适用条件或题目完整解析'));
    expect(en, contains('never omit requested coverage, key derivation steps'));
    expect(en, contains('complete quiz explanation'));
  });
}
