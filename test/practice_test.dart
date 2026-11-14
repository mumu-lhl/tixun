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
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/practice/question_spec.dart';

void main() {
  test('Deterministic grades: exact sets, positional aliases, finite fractions and tolerances', () {
    const multiple = QuestionSpec(
      kind: 'multiple_choice',
      stem: '选质数',
      options: {'A': '2', 'B': '3', 'C': '4'},
      answers: [
        ['A'],
        ['B'],
      ],
    );
    expect(multiple.grade(['B', 'A']), true);
    expect(multiple.grade(['A']), false);
    expect(multiple.grade(['A', 'A', 'B']), false);
    expect(multiple.grade(['A', 'B', 'C']), false);
    const blank = QuestionSpec(
      kind: 'fill_blank',
      stem: '填写',
      answers: [
        ['oxygen', 'O2'],
        ['氢'],
      ],
      caseSensitive: false,
    );
    expect(blank.grade([' OXYGEN ', '氢']), true);
    expect(blank.grade(['氢', 'oxygen']), false);
    const numeric = QuestionSpec(
      kind: 'numeric',
      stem: '1/3',
      answers: [
        ['0.333333333333'],
      ],
      absoluteTolerance: 0.00001,
    );
    expect(numeric.grade(['1/3']), true);
    expect(numeric.grade(['Infinity']), false);
    expect(numeric.grade(['1/0']), false);
    expect(numeric.grade(['1/3/4']), false);
    const relative = QuestionSpec(
      kind: 'numeric',
      stem: '',
      answers: [
        ['1000'],
      ],
      relativeTolerance: 0.001,
    );
    expect(() => relative.validate(), throwsFormatException);
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'single_choice',
        'stem': 'x',
        'options': {'A': 'x', 'B': 'y'},
        'answers': [
          ['C'],
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'numeric',
        'stem': 'x',
        'answers': [
          ['NaN'],
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'numeric',
        'stem': 'x',
        'answers': [
          ['2'],
        ],
        'verified': true,
      }),
      throwsFormatException,
    );
  });

  test('Visual answers: point distance with a tap-sized default tolerance, region ids', () {
    const point = QuestionSpec(
      kind: 'point_select',
      stem: '点出抛物线的顶点',
      answers: [
        ['1,2'],
      ],
      absoluteTolerance: 0.5,
      visualId: 'v',
    );
    expect(point.grade(['1.2,2.1']), true);
    expect(point.grade(['1,2']), true);
    expect(point.grade(['2,2']), false);
    expect(point.grade(['not-a-point']), false);
    expect(point.grade(['1,2', '3,4']), false);
    // The const constructor keeps the numeric default (1e-6); the 0.5
    // default only applies when the JSON omits absolute_tolerance.
    final fromJson = QuestionSpec.fromJson({
      'kind': 'point_select',
      'stem': '点出抛物线的顶点',
      'answers': [
        ['1,2'],
      ],
      'visual_id': 'v',
    });
    expect(fromJson.absoluteTolerance, 0.5);
    expect(fromJson.grade(['1.4,2.3']), true);
    expect(fromJson.grade(['1.6,2']), false);
    final explicit = QuestionSpec.fromJson({
      'kind': 'point_select',
      'stem': '点出抛物线的顶点',
      'answers': [
        ['1,2'],
      ],
      'visual_id': 'v',
      'absolute_tolerance': 0.1,
    });
    expect(explicit.grade(['1.05,2']), true);
    expect(explicit.grade(['1.2,2']), false);
    const region = QuestionSpec(
      kind: 'region_select',
      stem: '点出阴影区域',
      options: {'r1': '中心', 'r2': '右上'},
      answers: [
        ['r1'],
      ],
      visualId: 'v',
    );
    expect(region.grade(['r1']), true);
    expect(region.grade(['r2']), false);
    expect(region.grade([]), false);
    // A visual-answer kind without a visual is unanswerable.
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'point_select',
        'stem': '点出顶点',
        'answers': [
          ['1,2'],
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'region_select',
        'stem': '点出区域',
        'options': {'r1': '中心'},
        'answers': [
          ['r1'],
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'point_select',
        'stem': '点出顶点',
        'answers': [
          ['1;2'],
        ],
        'visual_id': 'v',
      }),
      throwsFormatException,
    );
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'region_select',
        'stem': '点出区域',
        'options': {'r1': '中心'},
        'answers': [
          ['r9'],
        ],
        'visual_id': 'v',
      }),
      throwsFormatException,
    );
  });

  test('Visual answers: drag to a target, read a value off the graph', () {
    // drag_to_target grades exactly like point_select (distance within
    // the tap-sized tolerance), including the 0.5 fromJson default.
    final drag = QuestionSpec.fromJson({
      'kind': 'drag_to_target',
      'stem': '把点 P 拖到 (2, 0)',
      'answers': [
        ['2,0'],
      ],
      'visual_id': 'v',
    });
    expect(drag.absoluteTolerance, 0.5);
    expect(drag.grade(['2.1,0.2']), true);
    expect(drag.grade(['2.6,0']), false);
    expect(drag.grade(['not-a-point']), false);
    // read_value grades like numeric, but requires a visual.
    final read = QuestionSpec.fromJson({
      'kind': 'read_value',
      'stem': '读出抛物线顶点的纵坐标',
      'answers': [
        ['4'],
      ],
      'visual_id': 'v',
      'absolute_tolerance': 0.1,
    });
    expect(read.grade(['4.05']), true);
    expect(read.grade(['4.2']), false);
    expect(read.grade(['abc']), false);
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'drag_to_target',
        'stem': '把点拖到目标',
        'answers': [
          ['2,0'],
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'read_value',
        'stem': '读出数值',
        'answers': [
          ['4'],
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => QuestionSpec.fromJson({
        'kind': 'read_value',
        'stem': '读出数值',
        'answers': [
          ['four'],
        ],
        'visual_id': 'v',
      }),
      throwsFormatException,
    );
  });
  test('Attempt drafts survive reopen, duplicate submissions are atomic, self assessment is separate', () async {
    final root = await Directory.systemTemp.createTemp('tixun-practice');
    var db = AppDatabase.file(File('${root.path}/test.sqlite'));
    var store = PracticeStore(db);
    final q = await store.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '1+1=?',
        answers: [
          ['2'],
        ],
        hint: '试试数手指。',
      ),
      origin: 'ai',
      verification: 'unverified',
    );
    final a = await store.begin(q);
    expect(
      (await Future.wait([store.begin(q), store.begin(q)]))
          .map((a) => a.id)
          .toSet(),
      {a.id},
    );
    await store.draft(a.id, ['2']);
    await store.useHint(a.id);
    store.dispose();
    await db.close();
    db = AppDatabase.file(File('${root.path}/test.sqlite'));
    store = PracticeStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    expect((await store.detail(q)).responses[a.id], ['2']);
    final results = await Future.wait([
      store.submit(a.id, ['2']),
      store.submit(a.id, ['4']),
    ]);
    expect(results.every((a) => a.correct == true), true);
    final detail = await store.detail(q);
    expect(detail.attempts.length, 1);
    expect(detail.latest!.hintUsed, true);
    expect(detail.latest!.gradingBasis, 'ai_reference');
    await store.verify(q);
    expect((await store.detail(q)).latest!.gradingBasis, 'ai_reference');
    final retry = await store.begin(q, retry: true);
    expect(retry.id, isNot(a.id));
    expect((await store.submit(retry.id, ['2'])).gradingBasis, 'deterministic');
    final self = await store.create(
      const QuestionSpec(
        kind: 'short_answer',
        stem: '解释牛顿第二定律',
        answers: [],
        explanation: 'F=ma',
      ),
      origin: 'recall',
      verification: 'unverified',
    );
    final sa = await store.begin(self);
    final pending = await store.submit(sa.id, ['我的推导']);
    expect(pending.status, 'awaiting_self_grade');
    expect(pending.correct, isNull);
    expect((await store.selfGrade(sa.id, false)).gradingBasis, 'self');
    expect((await store.selfGrade(sa.id, true)).correct, false);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('Quiz tool validates, deduplicates per run, never accepts forged verification', () async {
    final db = AppDatabase.memory();
    final store = PracticeStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final s = await db.createSession();
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: 'run',
            sessionId: s.id,
            role: 'assistant',
            content: '',
            createdAt: DateTime.now(),
          ),
        );
    final args = const QuestionSpec(
      kind: 'single_choice',
      stem: '2+2=?',
      options: {'A': '4', 'B': '5'},
      answers: [
        ['A'],
      ],
    ).toJson();
    final token = CancelToken();
    final first = await executeQuizTool(
      store,
      ToolCall('1', 'create_quiz', jsonEncode(args)),
      sessionId: s.id,
      runId: 'run',
      cancel: token,
    );
    final twice = await executeQuizTool(
      store,
      ToolCall('2', 'create_quiz', jsonEncode(args)),
      sessionId: s.id,
      runId: 'run',
      cancel: token,
    );
    expect(first['ok'], true);
    expect(first['question_id'], twice['question_id']);
    expect((await store.list()).length, 1);
    final forged = await executeQuizTool(
      store,
      ToolCall(
        '3',
        'create_quiz',
        jsonEncode({...args, 'verification': 'verified'}),
      ),
      sessionId: s.id,
      runId: 'run',
      cancel: token,
    );
    expect(forged['ok'], false);
    expect((await store.list()).single.verification, 'unverified');
  });
  test('Mock Chat produces persisted interactive quizzes without material permissions', () async {
    final root = await Directory.systemTemp.createTemp('tixun-quiz-chat');
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
    await c.newSession();
    await c.mode('exam');
    await c.send('请给我出题');
    expect(c.messages.last.status, 'complete');
    expect(c.messages.last.content, isNot(contains('顶点为')));
    final quizzes = await c.practice.list(messageId: c.messages.last.id);
    expect(quizzes.length, 1);
    expect((await c.db.sessions()).single.stage, 'practice');
    expect((await c.db.sessions()).single.toolsEnabled, false);
  });
}
