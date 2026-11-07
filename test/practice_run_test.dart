import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/quiz_tool.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/practice/question_spec.dart';

void main() {
  test('Offline random run resumes, requires real grading and makes duplicate Next presses idempotent', () async {
    final db = AppDatabase.memory();
    var store = PracticeStore(db);
    addTearDown(() async {
      await store.whenIdle;
      store.dispose();
      await db.close();
    });
    final ids = <String>{};
    for (var i = 1; i <= 5; i++) {
      ids.add(
        await store.create(
          QuestionSpec(
            kind: 'numeric',
            stem: '填写 $i',
            answers: [
              ['$i'],
            ],
          ),
        ),
      );
    }
    await store.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '物理',
        subject: '物理',
        answers: [
          ['1'],
        ],
      ),
    );
    final initial = await store.startRandomRun(subject: '数学');
    expect(initial.ids.toSet(), ids);
    expect(initial.attempts.whereType<String>().length, 1);
    final repeated = await store.startRandomRun(subject: '数学');
    expect(repeated.attempts, initial.attempts);
    expect(repeated.ids, initial.ids);
    await expectLater(store.advanceRun(), throwsFormatException);
    for (var i = 0; i < 5; i++) {
      final run = (await store.loadRun())!;
      expect(run.index, i);
      final detail = await store.detail(run.ids[i], attemptId: run.attempts[i]);
      expect(detail.latest!.status, 'draft');
      if (i == 1) await store.useHint(detail.latest!.id);
      await store.submit(
        detail.latest!.id,
        i == 2 ? ['999'] : detail.spec.answers.single,
      );
      final next = await Future.wait([
        store.advanceRun(expectedAttemptId: detail.latest!.id),
        store.advanceRun(expectedAttemptId: detail.latest!.id),
      ]);
      expect(next.every((r) => r.index == i + 1), true);
    }
    store.dispose();
    store = PracticeStore(db);
    final restored = (await store.loadRun())!;
    expect(restored.completed, true);
    final attempts = await db.select(db.practiceAttempts).get();
    expect(attempts.length, 5);
    expect(attempts.where((a) => a.correct == true).length, 4);
    expect(attempts.where((a) => a.hintUsed).length, 1);
    await store.clearRun();
    expect(await store.loadRun(), isNull);
    expect((await db.select(db.practiceAttempts).get()).length, 5);
  });
  test('A specific older attempt is readable beyond compact history; revisions keep original responses intact', () async {
    final db = AppDatabase.memory();
    final practice = PracticeStore(db);
    addTearDown(() async {
      practice.dispose();
      await db.close();
    });
    final old = await practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '旧答案待纠正',
        answers: [
          ['2'],
        ],
      ),
      origin: 'ai',
      verification: 'unverified',
    );
    final first = await practice.begin(old);
    await practice.submit(first.id, ['3']);
    for (var i = 0; i < 51; i++) {
      await practice.submit((await practice.begin(old, retry: true)).id, ['2']);
    }
    final focused = await practice.detail(old, attemptId: first.id);
    expect(focused.latest!.id, first.id);
    expect(focused.responses[first.id], ['3']);
    expect(focused.latest!.correct, false);
    expect((await practice.history(old, offset: 50)).length, 2);
    final revision = await practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '修订后的题目',
        answers: [
          ['3'],
        ],
      ),
      parentId: old,
    );
    expect((await practice.detail(revision)).attempts, isEmpty);
    expect((await practice.detail(revision)).row.parentQuestionId, old);
    expect((await practice.detail(old)).spec.answers, [
      ['2'],
    ]);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('Knowledge-scoped quizzes, variant provenance, image references and branched chats stay linked without duplicate statistics', () async {
    final root = await Directory.systemTemp.createTemp('tixun-training-links');
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    addTearDown(() async {
      await c.shutdown();
      await root.delete(recursive: true);
    });
    await c.initialize();
    final k1 = await c.study.saveKnowledge(
      const KnowledgeDraft(title: '二次函数', content: '配方理解顶点'),
    );
    final k2 = await c.study.saveKnowledge(
      const KnowledgeDraft(title: '函数的最小值', content: '联系完全平方'),
    );
    await c.prepareKnowledgePractice([k1.id, k2.id]);
    expect(c.selected!.toolsEnabled, false);
    expect(c.selected!.draft, contains('配方理解顶点'));
    await c.send(c.selected!.draft);
    final original = (await c.practice.list(messageId: c.messages.last.id))
        .single;
    expect((await c.db.select(c.db.practiceQuestionKnowledge).get()).length, 2);
    final a = await c.practice.begin(original.id);
    await c.practice.submit(a.id, ['A']);
    await c.send('请换种方式解释');
    final lastUser = c.messages.where((m) => m.role == 'user').last;
    await c.editAndResend(lastUser, '请重新解释');
    final copied = c.messages.where((m) => m.role == 'assistant').first;
    expect(
      (await c.practice.list(messageId: copied.id)).single.id,
      original.id,
    );
    expect((await c.db.select(c.db.practiceQuestions).get()).length, 1);
    expect((await c.db.select(c.db.practiceAttempts).get()).length, 1);
    final pending = await c.practice.begin(original.id, retry: true);
    await c.practice.useHint(pending.id);
    expect(
      (await c.db.sessions()).where((s) => s.stage == 'hinting').length,
      2,
    );
    await c.prepareVariant(await c.practice.detail(original.id));
    await c.send(c.selected!.draft);
    final variant = (await c.practice.list(messageId: c.messages.last.id))
        .single;
    expect(variant.parentQuestionId, original.id);
    expect((await c.practice.detail(variant.id)).images, isEmpty);
    await c.newSession();
    await c.addImage('assets/demo/two_problems.png');
    await c.send('看一下这张图');
    final body = {
      ...const QuestionSpec(
        kind: 'single_choice',
        stem: '根据所附原图选择',
        options: {'A': '是', 'B': '否'},
        answers: [
          ['A'],
        ],
      ).toJson(),
      'image_indices': [0],
    };
    final result = await executeQuizTool(
      c.practice,
      ToolCall('image-quiz', 'create_quiz', jsonEncode(body)),
      sessionId: c.selected!.id,
      runId: c.messages.last.id,
      cancel: CancelToken(),
      sourceImages: c.attachments,
    );
    expect(result['ok'], true);
    expect(
      (await c.practice.detail(result['question_id'] as String))
          .images
          .single
          .relativePath,
      c.attachments.single.relativePath,
    );
    final denied = await executeQuizTool(
      c.practice,
      ToolCall(
        'bad-image',
        'create_quiz',
        jsonEncode({
          ...body,
          'image_indices': [3],
        }),
      ),
      sessionId: c.selected!.id,
      runId: c.messages.last.id,
      cancel: CancelToken(),
      sourceImages: c.attachments,
    );
    expect(denied['ok'], false);
  });
}
