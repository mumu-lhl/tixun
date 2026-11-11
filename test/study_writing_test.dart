import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/study_tools.dart';
import 'package:tixun/core/ai/study_write_task.dart';
import 'package:tixun/core/ai/token_estimator.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/progress/learning_profile.dart';

import 'controller_tools_test.dart' show waitFor;

class _Writer implements ChatProvider {
  final requests = <AiRequest>[];
  String? wrongId;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests.add(request);
        final task = request.tools.map((t) => t.name).toSet();
        ToolCall call(String name, Map<String, Object?> args) =>
            ToolCall('call-${requests.length}', name, jsonEncode(args));
        if (request.messages.last.role == AiRole.tool) {
          final last = request.messages.last;
          if (last.callId == 'call-${requests.length - 1}' &&
              request.messages.where((m) => m.role == AiRole.tool).length ==
                  1 &&
              task.contains('update_knowledge')) {
            final k = jsonDecode(last.text) as Map;
            yield AiChunk(
              calls: [
                call('update_knowledge', {
                  'id': wrongId ?? k['id'],
                  'expected_revision': k['revision'],
                  'content': '${k['content']}\n新增：适用条件 x > 0',
                }),
              ],
              completed: true,
            );
          } else {
            yield const AiChunk(text: '已处理，请查看执行结果。', completed: true);
          }
        } else if (task.contains('update_knowledge')) {
          final match = RegExp(r'"knowledge_id":"([^"]+)"')
              .firstMatch(request.instructions)!;
          yield AiChunk(
            calls: [
              call('get_knowledge', {'id': match[1]}),
            ],
            completed: true,
          );
        } else if (task.contains('create_knowledge')) {
          yield AiChunk(
            calls: [
              call('create_knowledge', {
                'title': '指数函数',
                'content': '指数函数的底数须大于零且不等于一。',
                'subject': '数学',
              }),
            ],
            completed: true,
          );
        } else if (task.contains('create_mistake')) {
          yield AiChunk(
            calls: [
              call('create_mistake', {
                'title': '定义域判断',
                'question': '求 ln(x) 的定义域',
                'subject': '数学',
                'correct_answer': 'x > 0',
                'ai_analysis': '真数须为正数。',
                if (request.messages.any((m) => m.images.isNotEmpty))
                  'image_indices': [0],
              }),
            ],
            completed: true,
          );
        } else {
          yield const AiChunk(text: '指数函数：注意底数的取值范围。', completed: true);
        }
      });
}

void main() {
  late AppController c;
  late _Writer provider;
  setUp(() async {
    provider = _Writer();
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(await Directory.systemTemp.createTemp('tixun-writing')),
      MemoryKeyStore(),
      provider,
    );
    await c.initialize();
    await c.send('讲解指数函数');
  });
  tearDown(() async {
    await c.shutdown();
    await c.files.root.delete(recursive: true);
  });

  for (final mistake in [false, true]) {
    test(
      'Selected reply creates confirmed ${mistake ? 'mistake' : 'knowledge'} with source links',
      () async {
        final original = c.selected!.id;
        final source = c.messages.last;
        final prompt = await c.prepareStudyWriting(
          sourceMessageId: source.id,
          mistake: mistake,
          instruction: '保留适用条件',
        );
        expect(c.selected!.id, isNot(original));
        expect(prompt, contains(source.content));
        final pending = c.send(prompt);
        await waitFor(() => c.pendingTool != null);
        expect(await c.study.searchKnowledge(), isEmpty);
        expect(await c.study.searchMistakes(), isEmpty);
        c.decideTool(true);
        await pending;
        expect(c.messages.last.status, 'complete');
        final id = mistake
            ? (await c.study.searchMistakes()).single.id
            : (await c.study.searchKnowledge()).single.id;
        final links = await c.db.select(c.db.studyChatLinks).get();
        expect(
          links.where(
            (l) =>
                l.sessionId == original &&
                (mistake ? l.mistakeId : l.knowledgeId) == id,
          ),
          hasLength(1),
        );
        expect(links.where((l) => l.sessionId == c.selected!.id), hasLength(1));
        final tools = provider.requests[1].tools
            .where((t) => t.name != 'run_python')
            .map((t) => t.name)
            .toSet();
        expect(
          tools,
          mistake
              ? {'create_mistake'}
              : {'search_knowledge', 'get_knowledge', 'create_knowledge'},
        );
      },
    );
  }

  test(
    'Mistake organization preserves both cropped photo and stable original',
    () async {
      await c.newSession();
      final image = await c.addImage(
        File('assets/demo/two_problems.png').absolute.path,
      );
      await c.replaceDraftImage(
        image,
        await File('assets/demo/two_problems.png').readAsBytes(),
      );
      await c.send('解释这张照片');
      final prompt = await c.prepareStudyWriting(
        sourceMessageId: c.messages.last.id,
        mistake: true,
        instruction: '保留图片',
      );
      expect(c.attachments.single.originalPath, image.relativePath);
      final pending = c.send(prompt);
      await waitFor(() => c.pendingTool != null);
      c.decideTool(true);
      await pending;
      final mistake = (await c.study.searchMistakes()).single;
      final photos = await c.study.images(mistake.id, isMistake: true);
      expect(photos.map((p) => p.role).toSet(), {'original', 'crop'});
      for (final photo in photos) {
        expect(await c.files.resolve(photo.relativePath).exists(), true);
      }
    },
  );

  test(
    'Merge reads selected note, requires approval, and preserves revisions',
    () async {
      final old = await c.study.saveKnowledge(
        const KnowledgeDraft(title: '对数函数', content: '原有定义与笔记'),
      );
      final prompt = await c.prepareStudyWriting(
        sourceMessageId: c.messages.last.id,
        knowledgeId: old.id,
        instruction: '补充定义域',
      );
      final pending = c.send(prompt);
      await waitFor(() => c.pendingTool != null);
      expect((await c.study.knowledge(old.id)).content, old.content);
      c.decideTool(true);
      await pending;
      final updated = await c.study.knowledge(old.id);
      expect(updated.content, contains(old.content));
      expect(updated.content, contains('x > 0'));
      expect(updated.revision, old.revision + 1);
      expect(
        (await c.study.revisions(old.id))
            .singleWhere((r) => r.revision == old.revision)
            .content,
        old.content,
      );
      expect(await c.study.searchKnowledge(), hasLength(1));
      expect(c.messages.last.status, 'complete');
    },
  );

  test('Unselected target is blocked before confirmation or writes', () async {
    final a = await c.study.saveKnowledge(
      const KnowledgeDraft(title: 'A', content: 'A'),
    );
    final b = await c.study.saveKnowledge(
      const KnowledgeDraft(title: 'B', content: 'B'),
    );
    provider.wrongId = b.id;
    final prompt = await c.prepareStudyWriting(
      knowledgeId: a.id,
      instruction: '完善',
    );
    await c.send(prompt);
    expect(c.messages.last.status, 'error');
    expect(c.pendingTool, isNull);
    expect((await c.study.knowledge(a.id)).revision, 1);
    expect((await c.study.knowledge(b.id)).revision, 1);
  });

  test(
    'Truncated knowledge cannot be replaced by a partially informed rewrite',
    () async {
      final note = await c.study.saveKnowledge(
        KnowledgeDraft(title: '长笔记', content: '原文' * 7000),
      );
      final prompt = await c.prepareStudyWriting(
        knowledgeId: note.id,
        instruction: '整理',
      );
      await c.send(prompt);
      expect(c.messages.last.status, 'error');
      expect(c.pendingTool, isNull);
      expect((await c.study.knowledge(note.id)).content, note.content);
    },
  );

  test('Rejecting a proposal leaves no knowledge or source backlink', () async {
    final original = c.selected!.id;
    final prompt = await c.prepareStudyWriting(
      sourceMessageId: c.messages.last.id,
      instruction: '',
    );
    final pending = c.send(prompt);
    await waitFor(() => c.pendingTool != null);
    c.decideTool(false);
    await pending;
    expect(await c.study.searchKnowledge(), isEmpty);
    expect(
      (await c.db.select(c.db.studyChatLinks).get()).where(
        (l) => l.sessionId == original,
      ),
      isEmpty,
    );
    expect(await StudyWriteTask.load(c.db, c.selected!.id, prompt), isNotNull);
    expect(await StudyWriteTask.load(c.db, c.selected!.id, '换个问题'), isNull);
  });

  test('Stage and optional region reach system context as background, old profiles remain readable', () async {
    await c.db.setPreference('learning_profile', '{"stage":"高三"}');
    expect((await LearningProfile.load(c.db)).region, isEmpty);
    expect((await LearningProfile.load(c.db)).partialFallback, false);
    await const LearningProfile(stage: '高三', region: ' 浙江 ').save(c.db);
    expect((await LearningProfile.load(c.db)).region, '浙江');
    await c.send('梳理数学公式');
    final request = provider.requests.last;
    expect(request.instructions, contains('"stage":"高三"'));
    expect(request.instructions, contains('"region":"浙江"'));
    expect(request.instructions, contains('不可断定当地考纲'));
    expect(
      request.tools.any((t) => t.name == 'suggest_question_regions'),
      false,
    );
    await c.db.setPreference('learning_profile', '{"region":42}');
    expect((await LearningProfile.load(c.db)).partialFallback, true);
    await expectLater(
      LearningProfile(region: '浙' * 101).save(c.db),
      throwsFormatException,
    );
  });

  test('Focused tasks materially reduce transmitted tool schema estimates', () async {
    int tokens(Iterable<AiTool> tools) => estimateTokens(
      jsonEncode([
        for (final t in tools)
          {
            'name': t.name,
            'description': t.description,
            'parameters': t.parameters,
          },
      ]),
    );
    final full = tokens(studyToolSchemas);
    for (final op in [
      'create_knowledge',
      'update_knowledge',
      'create_mistake',
    ]) {
      final task = StudyWriteTask(
        operation: op,
        prompt: 'test',
        knowledgeId: op == 'update_knowledge' ? 'selected-id' : null,
      );
      final scoped = tokens(
        studyToolSchemas.where((t) => task.tools.contains(t.name)),
      );
      // Estimates are not billing measurements; this verifies useful ablation.
      expect(scoped, lessThan(full ~/ 2));
      // ignore: avoid_print
      print('$op schema estimate: $full -> $scoped tokens');
    }
  });
}
