import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/ai_types.dart';
import 'package:tixun/core/ai/quiz_tool.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/practice/question_spec.dart';
import 'package:tixun/features/visual/visual_store.dart';

const _sceneJson =
    '{"v":1,"kind":"plot2d","model":{"expression":"x^2-4"},"meta":{"alt":"抛物线"}}';

Map<String, dynamic> _quizArgs({String? visualId, int? visualRevision}) => {
  'kind': 'numeric',
  'stem': '抛物线与 x 轴交点的横坐标是多少？',
  'subject': '数学',
  'answers': [
    ['2'],
  ],
  'explanation': 'x^2 - 4 = 0 的根是 ±2。',
  'visual_id': ?visualId,
  'visual_revision': ?visualRevision,
};

Future<void> _seedSession(
  AppDatabase db,
  String sessionId,
  String messageId,
) async {
  final now = DateTime.now();
  await db
      .into(db.chatSessions)
      .insert(
        ChatSessionsCompanion.insert(
          id: sessionId,
          title: '会话',
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db
      .into(db.chatMessages)
      .insert(
        ChatMessagesCompanion.insert(
          id: messageId,
          sessionId: sessionId,
          role: 'assistant',
          content: '请看图',
          createdAt: now,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late PracticeStore practice;
  late VisualStore visual;

  setUp(() {
    db = AppDatabase.memory();
    practice = PracticeStore(db);
    visual = VisualStore(db);
    addTearDown(() async {
      practice.dispose();
      visual.dispose();
      await db.close();
    });
  });

  Future<Map<String, dynamic>> runQuiz(
    Map<String, dynamic> args, {
    String callId = 'c1',
    String runId = 'r1',
    bool exam = false,
    VisualStore? visualStore,
  }) => executeQuizTool(
    practice,
    ToolCall(callId, 'create_quiz', jsonEncode(args)),
    sessionId: 's',
    runId: runId,
    cancel: CancelToken(),
    visual: visualStore ?? visual,
    exam: exam,
  );

  Future<String> seedScene() async {
    await _seedSession(db, 's', 'r1');
    return visual.create(sceneJson: _sceneJson, messageId: 'r1');
  }

  test(
    'create_quiz with visual_id snapshots the scene and links the pin',
    () async {
      final id = await seedScene();
      final result = await runQuiz(_quizArgs(visualId: id));
      expect(result['ok'], true);
      final questionId = result['question_id'] as String;
      expect(result['visual_id'], id);
      expect(result['visual_revision'], 2);
      // The snapshot froze the scene at revision 2; the live row agrees.
      expect((await visual.get(id))!.revision, 2);
      expect(await visual.questionVisualLinks(questionId), [
        (visualId: id, revision: 2),
      ]);
      // The question detail carries the same pin for the card to render.
      expect((await practice.detail(questionId)).visualLinks, [
        (visualId: id, revision: 2),
      ]);
    },
  );

  test(
    'create_quiz with an explicit visual_revision pins it without snapshotting',
    () async {
      final id = await seedScene();
      final snap = await visual.snapshotForQuestion(id);
      expect(snap.revision, 2);
      final result = await runQuiz(_quizArgs(visualId: id, visualRevision: 1));
      expect(result['ok'], true);
      expect(result['visual_revision'], 1);
      // No new snapshot was taken for the explicit pin.
      expect((await visual.get(id))!.revision, 2);
      expect(
        await visual.questionVisualLinks(result['question_id'] as String),
        [(visualId: id, revision: 1)],
      );
    },
  );

  test(
    'create_quiz with an unknown visual fails without creating a question',
    () async {
      await _seedSession(db, 's', 'r1');
      final result = await runQuiz(_quizArgs(visualId: 'nope'));
      expect(result['ok'], false);
      expect(await db.select(db.practiceQuestions).get(), isEmpty);
    },
  );

  test(
    'create_quiz with a missing revision fails without creating a question',
    () async {
      final id = await seedScene();
      final result = await runQuiz(_quizArgs(visualId: id, visualRevision: 99));
      expect(result['ok'], false);
      expect(await db.select(db.practiceQuestions).get(), isEmpty);
    },
  );

  test('create_quiz in exam mode rejects the visual', () async {
    final id = await seedScene();
    final result = await runQuiz(_quizArgs(visualId: id), exam: true);
    expect(result['ok'], false);
    expect(result['error'], contains('考试模式'));
    expect(await db.select(db.practiceQuestions).get(), isEmpty);
  });

  test('create_quiz without a visual store rejects the visual', () async {
    final id = await seedScene();
    final result = await executeQuizTool(
      practice,
      ToolCall('c1', 'create_quiz', jsonEncode(_quizArgs(visualId: id))),
      sessionId: 's',
      runId: 'r1',
      cancel: CancelToken(),
      visual: null,
    );
    expect(result['ok'], false);
    expect(await db.select(db.practiceQuestions).get(), isEmpty);
  });

  test('replaying a visual quiz call does not re-snapshot', () async {
    final id = await seedScene();
    final first = await runQuiz(_quizArgs(visualId: id));
    expect(first['ok'], true);
    expect(first['visual_revision'], 2);
    final second = await runQuiz(_quizArgs(visualId: id));
    // The replay returns the cached op result (no 'note' field) for the
    // same question, and takes no new snapshot.
    expect(second['ok'], true);
    expect(second['question_id'], first['question_id']);
    expect(second['visual_revision'], 2);
    expect((await visual.get(id))!.revision, 2);
    expect(await db.select(db.practiceQuestions).get(), hasLength(1));
  });

  test('QuestionSpec visual fields round-trip and validate', () {
    final spec = QuestionSpec.fromJson(
      _quizArgs(visualId: 'v1', visualRevision: 3),
    );
    expect(spec.visualId, 'v1');
    expect(spec.visualRevision, 3);
    expect(spec.toJson()['visual_id'], 'v1');
    expect(spec.toJson()['visual_revision'], 3);
    final plain = QuestionSpec.fromJson(_quizArgs());
    expect(plain.visualId, isNull);
    expect(plain.visualRevision, isNull);
    expect(plain.toJson().containsKey('visual_id'), false);
    expect(
      () => QuestionSpec.fromJson(_quizArgs(visualRevision: 2)),
      throwsA(isA<AppFormatException>()),
    );
    expect(
      () => QuestionSpec.fromJson(_quizArgs(visualId: 'v1', visualRevision: 0)),
      throwsA(isA<AppFormatException>()),
    );
    expect(
      () => QuestionSpec.fromJson(_quizArgs(visualId: '  ')),
      throwsA(isA<AppFormatException>()),
    );
  });

  test(
    'create_quiz accepts point_select and region_select with a visual',
    () async {
      await _seedSession(db, 's', 'r1');
      final id = await visual.create(sceneJson: _sceneJson, messageId: 'r1');
      final point = await runQuiz({
        'kind': 'point_select',
        'stem': '点出抛物线的顶点',
        'subject': '数学',
        'answers': [
          ['0,-4'],
        ],
        'explanation': '顶点在 (0, -4)。',
        'visual_id': id,
      }, callId: 'c1');
      expect(point['ok'], true);
      final pointId = point['question_id'] as String;
      expect((await practice.detail(pointId)).spec.kind, 'point_select');
      final region = await runQuiz({
        'kind': 'region_select',
        'stem': '点出阴影区域',
        'subject': '数学',
        'options': {'r1': '中心'},
        'answers': [
          ['r1'],
        ],
        'explanation': '阴影在中心。',
        'visual_id': id,
      }, callId: 'c2');
      expect(region['ok'], true);
      // Without a visual the same kinds are rejected — and no question
      // row is left behind.
      final noVisual = await runQuiz({
        'kind': 'point_select',
        'stem': '点出顶点',
        'subject': '数学',
        'answers': [
          ['0,0'],
        ],
        'explanation': '无图。',
      }, callId: 'c3');
      expect(noVisual['ok'], false);
      expect(await db.select(db.practiceQuestions).get(), hasLength(2));
    },
  );

  test(
    'create_quiz accepts drag_to_target and read_value with a visual',
    () async {
      await _seedSession(db, 's', 'r1');
      final id = await visual.create(sceneJson: _sceneJson, messageId: 'r1');
      final drag = await runQuiz({
        'kind': 'drag_to_target',
        'stem': '把点 P 拖到 (2, 0)',
        'subject': '数学',
        'answers': [
          ['2,0'],
        ],
        'explanation': '目标在 (2, 0)。',
        'visual_id': id,
      }, callId: 'c1');
      expect(drag['ok'], true);
      final dragId = drag['question_id'] as String;
      expect((await practice.detail(dragId)).spec.kind, 'drag_to_target');
      final read = await runQuiz({
        'kind': 'read_value',
        'stem': '读出抛物线顶点的纵坐标',
        'subject': '数学',
        'answers': [
          ['-4'],
        ],
        'explanation': '顶点在 (0, -4)。',
        'visual_id': id,
      }, callId: 'c2');
      expect(read['ok'], true);
      final noVisual = await runQuiz({
        'kind': 'read_value',
        'stem': '读出数值',
        'subject': '数学',
        'answers': [
          ['4'],
        ],
        'explanation': '无图。',
      }, callId: 'c3');
      expect(noVisual['ok'], false);
      expect(await db.select(db.practiceQuestions).get(), hasLength(2));
    },
  );
}
