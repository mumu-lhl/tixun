import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/ai_types.dart';
import 'package:tixun/core/ai/quiz_tool.dart';
import 'package:tixun/core/ai/visual_tool.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/visual/visual_store.dart';

/// P2 coverage for the read entry points: `get_visual` returns the
/// stored scene (it performs no validation of its own — the store
/// entry points validate on write instead) and `create_quiz` with a
/// `visual_id` pins the snapshot it is given. These are behaviour
/// tests on valid snapshots; they assert no new validation.

const _sceneV1 =
    '{"v":1,"kind":"plot2d","title":"V1","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';
const _sceneV2 =
    '{"v":1,"kind":"plot2d","title":"V2","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';

Future<void> _seedMessage(
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

  setUp(() async {
    db = AppDatabase.memory();
    practice = PracticeStore(db);
    visual = VisualStore(db);
    await _seedMessage(db, 's', 'r1');
    await _seedMessage(db, 's', 'r2');
    addTearDown(() async {
      practice.dispose();
      visual.dispose();
      await db.close();
    });
  });

  Future<Map<String, dynamic>> runGet(
    String callId,
    Map<String, dynamic> args,
  ) => executeGetVisualTool(
    visual,
    ToolCall(callId, 'get_visual', jsonEncode(args)),
    sessionId: 's',
    runId: 'r1',
    cancel: CancelToken(),
  );

  Future<Map<String, dynamic>> runQuiz(
    String callId,
    Map<String, dynamic> args, {
    String runId = 'r1',
  }) => executeQuizTool(
    practice,
    ToolCall(callId, 'create_quiz', jsonEncode(args)),
    sessionId: 's',
    runId: runId,
    cancel: CancelToken(),
    visual: visual,
  );

  /// Mirrors the create tool: the store does NOT derive the row title
  /// from the scene JSON — the caller passes `scene.title` explicitly.
  Future<String> createVisual(String sceneJson, String title) =>
      visual.create(sceneJson: sceneJson, messageId: 'r1', title: title);

  Map<String, dynamic> quizArgs({String? visualId, int? visualRevision}) => {
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

  group('get_visual', () {
    test('returns the current scene without a revision', () async {
      final id = await createVisual(_sceneV1, 'V1');
      final result = await runGet('g1', {'visual_id': id});
      expect(result['ok'], isTrue);
      expect(result['revision'], 1);
      expect((result['scene'] as Map)['title'], 'V1');
      expect(result['title'], 'V1');
      expect(result['verification_status'], isNotEmpty);
    });

    test('returns the pinned snapshot for an old revision', () async {
      final id = await createVisual(_sceneV1, 'V1');
      await visual.revise(id, _sceneV2);
      final result = await runGet('g1', {'visual_id': id, 'revision': 1});
      expect(result['ok'], isTrue);
      expect(result['revision'], 1);
      // The snapshot itself is the old scene.
      expect((result['scene'] as Map)['title'], 'V1');
      // A pinned revision carries its own title: the snapshot's title
      // wins over the current row title (which is V2 after the revise).
      // The verification status is likewise re-derived from the
      // snapshot, not read off the current row.
      expect(result['title'], 'V1');
      expect(result['verification_status'], isNotEmpty);
    });

    test('create without a title leaves the row title null', () async {
      // The store does not derive the title from the scene JSON; the
      // create tool passes scene.title explicitly. A direct store call
      // without title leaves get_visual with nothing to report.
      final id = await visual.create(sceneJson: _sceneV1, messageId: 'r1');
      final result = await runGet('g1', {'visual_id': id});
      expect(result['ok'], isTrue);
      expect((result['scene'] as Map)['title'], 'V1');
      expect(result['title'], isNull);
    });

    test('returns the current scene for the latest revision', () async {
      final id = await createVisual(_sceneV1, 'V1');
      await visual.revise(id, _sceneV2);
      final result = await runGet('g1', {'visual_id': id, 'revision': 2});
      expect(result['ok'], isTrue);
      expect((result['scene'] as Map)['title'], 'V2');
      expect(result['title'], 'V2');
    });

    test('an unknown revision is rejected', () async {
      final id = await createVisual(_sceneV1, 'V1');
      final result = await runGet('g1', {'visual_id': id, 'revision': 9});
      expect(result['ok'], isFalse);
      expect(result['error'], contains('图形修订不存在'));
    });

    test('an unknown visual is rejected', () async {
      final result = await runGet('g1', {'visual_id': 'missing'});
      expect(result['ok'], isFalse);
      expect(result['error'], contains('图形不存在'));
    });

    test('get_visual writes nothing: no revision bump, no op row', () async {
      final id = await createVisual(_sceneV1, 'V1');
      await runGet('g1', {'visual_id': id});
      await runGet('g2', {'visual_id': id, 'revision': 1});
      expect((await visual.get(id))!.revision, 1);
      final ops = await (db.select(
        db.aiToolOperations,
      )..where((t) => t.name.equals('get_visual'))).get();
      expect(ops, isEmpty);
    });
  });

  group('create_quiz with visual_id', () {
    test('pins the current revision and links the question to it', () async {
      final id = await createVisual(_sceneV1, 'V1');
      final result = await runQuiz('q1', quizArgs(visualId: id));
      expect(result['ok'], isTrue);
      final questionId = result['question_id'] as String;
      // Pinning without an explicit revision freezes the current scene
      // as a NEW snapshot: the row revision moves 1 -> 2 and the
      // question pins revision 2, so later edits never change it.
      expect(result['visual_revision'], 2);
      expect((await visual.get(id))!.revision, 2);
      final links = await visual.questionVisualLinks(questionId);
      expect(links, [(visualId: id, revision: 2)]);
      // The question spec carries the same pin.
      final detail = await practice.detail(questionId);
      expect(detail.spec.visualId, id);
      expect(detail.spec.visualRevision, 2);
    });

    test('an explicit visual_revision pins that snapshot', () async {
      final id = await createVisual(_sceneV1, 'V1');
      await visual.revise(id, _sceneV2);
      final result = await runQuiz(
        'q1',
        quizArgs(visualId: id, visualRevision: 1),
      );
      expect(result['ok'], isTrue);
      expect(result['visual_revision'], 1);
      final links = await visual.questionVisualLinks(
        result['question_id'] as String,
      );
      expect(links.single.revision, 1);
    });

    test('a later quiz pins the newer revision', () async {
      final id = await createVisual(_sceneV1, 'V1');
      await runQuiz('q1', quizArgs(visualId: id));
      await visual.revise(id, _sceneV2);
      // A second quiz in the SAME run with identical arguments is
      // rejected by the PracticeStore dedup guard (see the test below),
      // so the later quiz runs in a fresh run.
      final result = await runQuiz('q2', quizArgs(visualId: id), runId: 'r2');
      expect(result['ok'], isTrue);
      // q1 froze revision 2, revise moved the row to 3, and this quiz
      // freezes the new current scene as revision 4.
      expect(result['visual_revision'], 4);
      expect((await visual.get(id))!.revision, 4);
    });

    test(
      'the same quiz repeated in the same run is rejected, not re-pinned',
      () async {
        final id = await createVisual(_sceneV1, 'V1');
        await runQuiz('q1', quizArgs(visualId: id));
        // NOTE (observed behaviour, pinned as-is): the retry uses a
        // fresh call id, so the tool-level idempotency cache does not
        // apply; PracticeStore dedups on runId + args hash and its
        // content comparison rebuilds the old spec WITHOUT the visual
        // fields, so an identical visual quiz is reported as
        // "content differs" even though nothing changed.
        final result = await runQuiz('q2', quizArgs(visualId: id));
        expect(result['ok'], isFalse);
        expect(result['error'], contains('已创建过题目'));
      },
    );

    test('an unknown visual_revision is rejected', () async {
      final id = await createVisual(_sceneV1, 'V1');
      final result = await runQuiz(
        'q1',
        quizArgs(visualId: id, visualRevision: 5),
      );
      expect(result['ok'], isFalse);
    });
  });
}
