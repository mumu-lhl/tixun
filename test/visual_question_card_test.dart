import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/quiz_tool.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/practice/question_card.dart';
import 'package:tixun/features/visual/study_visuals.dart';

const _sceneV1 =
    '{"v":1,"kind":"plot2d","title":"V1","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';
const _sceneV2 =
    '{"v":1,"kind":"plot2d","title":"V2","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';

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
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });

  late AppController c;
  late ProviderContainer container;

  Future<void> openController() async {
    final root = await Directory.systemTemp.createTemp(
      'tixun-visual-question-card',
    );
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    await c.initialize();
    container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
  }

  tearDown(() async {
    container.dispose();
    await c.db.close();
    if (await c.files.root.exists()) {
      await c.files.root.delete(recursive: true);
    }
  });

  Future<void> pumpScaffold(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('QuestionCard shows the pinned visual, frozen after edits', (
    tester,
  ) async {
    late String questionId;
    await tester.runAsync(() async {
      await openController();
      await _seedSession(c.db, 's', 'r1');
      final visualId = await c.visual.create(
        sceneJson: _sceneV1,
        messageId: 'r1',
      );
      final result = await executeQuizTool(
        c.practice,
        ToolCall(
          'c1',
          'create_quiz',
          jsonEncode({
            'kind': 'numeric',
            'stem': '抛物线与 x 轴交点的横坐标是多少？',
            'subject': '数学',
            'answers': [
              ['2'],
            ],
            'explanation': 'x^2 - 4 = 0 的根是 ±2。',
            'visual_id': visualId,
          }),
        ),
        sessionId: 's',
        runId: 'r1',
        cancel: CancelToken(),
        visual: c.visual,
      );
      expect(result['ok'], true);
      questionId = result['question_id'] as String;
    });
    await pumpScaffold(tester, QuestionCard(questionId));
    // The card shows the pinned revision's title above the stem.
    expect(find.text('V1'), findsOneWidget);
    expect(find.textContaining('抛物线与 x 轴交点'), findsOneWidget);
    // Editing the scene afterwards must not change the question's figure.
    await tester.runAsync(() async {
      final scenes = await c.visual.listByMessage('r1');
      await c.visual.revise(scenes.single.id, _sceneV2);
    });
    await tester.pumpAndSettle();
    expect(find.text('V1'), findsOneWidget);
    expect(find.text('V2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StudyVisuals shows linked visuals and hides when empty', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await openController();
      await _seedSession(c.db, 's', 'r1');
      final now = DateTime.now();
      await c.db
          .into(c.db.knowledgeItems)
          .insert(
            KnowledgeItemsCompanion.insert(
              id: 'k',
              title: '二次函数',
              content: '正文',
              subject: '数学',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final visualId = await c.visual.create(
        sceneJson: _sceneV1,
        messageId: 'r1',
      );
      await c.visual.linkToStudy(visualId, knowledgeId: 'k');
    });
    await pumpScaffold(
      tester,
      const StudyVisuals(knowledgeId: 'k', mistakeId: null, panelTitle: '图形'),
    );
    expect(find.text('图形'), findsOneWidget);
    expect(find.text('V1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StudyVisuals renders nothing for an unlinked study item', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await openController();
    });
    await pumpScaffold(
      tester,
      const StudyVisuals(
        knowledgeId: 'missing',
        mistakeId: null,
        panelTitle: '图形',
      ),
    );
    expect(find.text('图形'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  /// Creates a visual question through the real tool path and returns
  /// its id. The scene is created first so the tool can snapshot it.
  Future<String> createVisualQuestion(
    WidgetTester tester,
    String kind,
    String sceneJson,
    List<List<String>> answers, {
    Map<String, String> options = const {},
  }) async {
    late String questionId;
    await tester.runAsync(() async {
      await openController();
      await _seedSession(c.db, 's', 'r1');
      final visualId = await c.visual.create(
        sceneJson: sceneJson,
        messageId: 'r1',
      );
      final result = await executeQuizTool(
        c.practice,
        ToolCall(
          'c1',
          'create_quiz',
          jsonEncode({
            'kind': kind,
            'stem': '请在图上作答。',
            'subject': '数学',
            'options': options,
            'answers': answers,
            'explanation': '见图。',
            'visual_id': visualId,
          }),
        ),
        sessionId: 's',
        runId: 'r1',
        cancel: CancelToken(),
        visual: c.visual,
      );
      expect(result['ok'], true);
      questionId = result['question_id'] as String;
    });
    return questionId;
  }

  Future<void> submitAndCheck(
    WidgetTester tester,
    String questionId,
    bool correct,
  ) async {
    await tester.tap(find.byKey(const Key('submit-quiz')));
    // The submit runs a Drift transaction that only advances in real
    // async time: alternate runAsync windows with pumps until the
    // graded view appears (same pattern as ui_test.dart). Reading the
    // store inside runAsync while the submit is still in flight can
    // deadlock on the zone-scoped transaction lock, so the store is
    // only read after the graded view proves the submit finished.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      // The graded view renders '参考答案：…' (with the colon); the
      // header's 'AI 参考答案待核对' must not match.
      if (find.textContaining('参考答案：').evaluate().isNotEmpty) break;
      if (i == 19) fail('the attempt was never graded');
    }
    await tester.runAsync(() async {
      expect((await c.practice.detail(questionId)).latest!.correct, correct);
    });
    expect(tester.takeException(), isNull);
  }

  testWidgets('Point-select: tapping the visual answers and grades', (
    tester,
  ) async {
    const scene =
        '{"v":1,"kind":"geometry","title":"点选图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[0,0],"label":"原点"}],"meta":{"alt":"点选"}}';
    final questionId = await createVisualQuestion(
      tester,
      'point_select',
      scene,
      [
        ['0,0'],
      ],
    );
    await pumpScaffold(tester, QuestionCard(questionId));
    // No text field and no option rows: the visual is the control.
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('option-A')), findsNothing);
    // The canvas center is model (0,0) for this symmetric view.
    await tester.tap(find.byKey(const Key('visual-tap-answer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选点：'), findsOneWidget);
    await submitAndCheck(tester, questionId, true);
  });

  testWidgets('Region-select: tapping inside a region answers with its id', (
    tester,
  ) async {
    const scene =
        '{"v":1,"kind":"geometry","title":"区域图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"r1","type":"polygon","points":[[-1,-1],[1,-1],[1,1],[-1,1]],"fill":true},{"id":"r2","type":"polygon","points":[[1.5,1.5],[2.5,1.5],[2.5,2.5],[1.5,2.5]],"fill":true}],"meta":{"alt":"区域"}}';
    final questionId = await createVisualQuestion(
      tester,
      'region_select',
      scene,
      [
        ['r1'],
      ],
      options: {'r1': '中心区域', 'r2': '右上区域'},
    );
    await pumpScaffold(tester, QuestionCard(questionId));
    expect(find.byType(TextField), findsNothing);
    // The option rows must not render: the visual is the control.
    expect(find.byKey(const Key('option-r1')), findsNothing);
    await tester.tap(find.byKey(const Key('visual-tap-answer')));
    await tester.pumpAndSettle();
    expect(find.text('已选区域：中心区域'), findsOneWidget);
    await submitAndCheck(tester, questionId, true);
  });

  testWidgets('Region-select: a tap outside every region selects nothing', (
    tester,
  ) async {
    const scene =
        '{"v":1,"kind":"geometry","title":"区域图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"r2","type":"polygon","points":[[1.5,1.5],[2.5,1.5],[2.5,2.5],[1.5,2.5]],"fill":true}],"meta":{"alt":"区域"}}';
    final questionId = await createVisualQuestion(
      tester,
      'region_select',
      scene,
      [
        ['r2'],
      ],
      options: {'r2': '右上区域'},
    );
    await pumpScaffold(tester, QuestionCard(questionId));
    // The canvas center (0,0) is outside the only region.
    await tester.tap(find.byKey(const Key('visual-tap-answer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选区域：'), findsNothing);
    // With no selection the submit is rejected: the attempt stays a
    // draft and the card reports that the answer is incomplete.
    await tester.tap(find.byKey(const Key('submit-quiz')));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      if (find.textContaining('请先完成作答').evaluate().isNotEmpty) break;
      if (i == 19) fail('the incomplete-answer hint never appeared');
    }
    await tester.runAsync(() async {
      expect((await c.practice.detail(questionId)).latest!.status, 'draft');
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('Drag-to-target: dragging the point answers and grades', (
    tester,
  ) async {
    const scene =
        '{"v":1,"kind":"geometry","title":"拖点图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[0,0],"label":"P","draggable":true}],"meta":{"alt":"拖点"}}';
    final questionId = await createVisualQuestion(
      tester,
      'drag_to_target',
      scene,
      [
        ['2,0'],
      ],
    );
    await pumpScaffold(tester, QuestionCard(questionId));
    // No text field and no option rows: the visual is the control.
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('option-A')), findsNothing);
    // The canvas is 358 wide for a 6-unit view, letterboxed to a
    // 44.75 px/unit scale: dragging 90 px right moves the point from
    // model (0,0) to about (2.01, 0), inside the 0.5 tolerance.
    final canvas = find.byKey(const Key('visual-canvas-paint'));
    await tester.dragFrom(tester.getCenter(canvas), const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选点：'), findsOneWidget);
    await submitAndCheck(tester, questionId, true);
  });

  testWidgets('Read-value: typing the value read off the graph grades', (
    tester,
  ) async {
    const scene =
        '{"v":1,"kind":"plot2d","title":"抛物线","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';
    final questionId = await createVisualQuestion(tester, 'read_value', scene, [
      ['-4'],
    ]);
    await pumpScaffold(tester, QuestionCard(questionId));
    // Read-value keeps the typed input: the visual is shown, and the
    // answer is typed like a numeric question.
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '-4');
    await tester.pumpAndSettle();
    await submitAndCheck(tester, questionId, true);
  });
}
