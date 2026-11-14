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
import 'package:tixun/features/practice/question_spec.dart';

/// P2 coverage for visual answering: grade-level boundaries
/// (`read_value` tolerance, empty/non-numeric input, unanswered
/// point-select) and widget-level submits (a wrong answer grades as
/// wrong; submitting without an answer is refused with a prompt).

QuestionSpec _readValueSpec(String answer) => QuestionSpec.fromJson({
  'kind': 'read_value',
  'stem': '图中横坐标是多少？',
  'subject': '数学',
  'answers': [
    [answer],
  ],
  'visual_id': 'v1',
});

QuestionSpec _pointSpec(String answer) => QuestionSpec.fromJson({
  'kind': 'point_select',
  'stem': '点出原点。',
  'subject': '数学',
  'answers': [
    [answer],
  ],
  'visual_id': 'v1',
});

QuestionSpec _regionSpec() => QuestionSpec.fromJson({
  'kind': 'region_select',
  'stem': '选出三角形所在的区域。',
  'subject': '数学',
  'options': {'r1': '区域一', 'r2': '区域二'},
  'answers': [
    ['r1'],
  ],
  'visual_id': 'v1',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('read_value grading boundaries', () {
    test('4.1 against 4.0 is wrong (default tolerance 1e-6)', () {
      expect(_readValueSpec('4').grade(['4.1']), isFalse);
    });

    test('just inside the tolerance passes', () {
      // Default absolute tolerance is 1e-6 (relative is 0). 4.0000005
      // is 5e-7 away, inside; 4.000002 is 2e-6 away, outside. There is
      // no "exactly at the edge" case: 4.000001 as a double is
      // 1.00000000014e-06 away from 4, i.e. just past 1e-6, so it
      // grades wrong — the edge is a floating-point cliff, not a
      // decimal one.
      expect(_readValueSpec('4').grade(['4.0000005']), isTrue);
      expect(_readValueSpec('4').grade(['4.000001']), isFalse);
    });

    test('just past the tolerance edge fails', () {
      expect(_readValueSpec('4').grade(['4.000002']), isFalse);
    });

    test('empty text is wrong', () {
      expect(_readValueSpec('4').grade(['']), isFalse);
      expect(_readValueSpec('4').grade(['   ']), isFalse);
    });

    test('non-numeric text is wrong', () {
      expect(_readValueSpec('4').grade(['abc']), isFalse);
      expect(_readValueSpec('4').grade(['4a']), isFalse);
    });

    test('fractions and surrounding whitespace parse', () {
      expect(_readValueSpec('4').grade(['4/1']), isTrue);
      expect(_readValueSpec('4').grade([' 4 ']), isTrue);
    });
  });

  group('point_select and region_select grading', () {
    test('no response is wrong', () {
      expect(_pointSpec('0,0').grade([]), isFalse);
    });

    test('a point within 0.5 model units is right', () {
      expect(_pointSpec('0,0').grade(['0.3,0.4']), isTrue);
    });

    test('a point past 0.5 model units is wrong', () {
      expect(_pointSpec('0,0').grade(['0.4,0.4']), isFalse);
    });

    test('an unparseable point is wrong', () {
      expect(_pointSpec('0,0').grade(['here']), isFalse);
    });

    test('region_select grades by region id', () {
      expect(_regionSpec().grade(['r1']), isTrue);
      expect(_regionSpec().grade(['r2']), isFalse);
      expect(_regionSpec().grade([]), isFalse);
    });
  });

  group('widget submits', () {
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
        'tixun-visual-p2-answer',
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
        final now = DateTime.now();
        await c.db
            .into(c.db.chatSessions)
            .insert(
              ChatSessionsCompanion.insert(
                id: 's',
                title: '会话',
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await c.db
            .into(c.db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: 'r1',
                sessionId: 's',
                role: 'assistant',
                content: '请看图',
                createdAt: now,
              ),
            );
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

    /// Taps submit and waits until the graded view appears, then
    /// checks the stored verdict. Same pattern as
    /// visual_question_card_test.dart: the submit transaction only
    /// advances in real async time.
    Future<void> submitAndCheck(
      WidgetTester tester,
      String questionId,
      bool correct,
    ) async {
      await tester.tap(find.byKey(const Key('submit-quiz')));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        if (find.textContaining('参考答案：').evaluate().isNotEmpty) break;
        if (i == 19) fail('the attempt was never graded');
      }
      await tester.runAsync(() async {
        expect((await c.practice.detail(questionId)).latest!.correct, correct);
      });
      expect(tester.takeException(), isNull);
    }

    const readValueScene =
        '{"v":1,"kind":"geometry","title":"读图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[2,0],"label":"A"}],"meta":{"alt":"读图"}}';

    testWidgets('read_value: a wrong typed answer grades as wrong', (
      tester,
    ) async {
      final questionId = await createVisualQuestion(
        tester,
        'read_value',
        readValueScene,
        [
          ['4'],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      await tester.enterText(find.byKey(const Key('quiz-answer-0')), '4.1');
      await tester.pumpAndSettle();
      await submitAndCheck(tester, questionId, false);
    });

    testWidgets('read_value: the exact answer grades as right', (tester) async {
      final questionId = await createVisualQuestion(
        tester,
        'read_value',
        readValueScene,
        [
          ['4'],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      await tester.enterText(find.byKey(const Key('quiz-answer-0')), '4');
      await tester.pumpAndSettle();
      await submitAndCheck(tester, questionId, true);
    });

    testWidgets('read_value: submitting empty text is refused', (tester) async {
      final questionId = await createVisualQuestion(
        tester,
        'read_value',
        readValueScene,
        [
          ['4'],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      await tester.tap(find.byKey(const Key('submit-quiz')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      // The empty submit is refused with a prompt; no graded view.
      expect(find.textContaining('请先完成作答'), findsWidgets);
      expect(find.textContaining('参考答案：'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('point_select: submitting without a tap is refused', (
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
      await tester.tap(find.byKey(const Key('submit-quiz')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('请先完成作答'), findsWidgets);
      expect(find.textContaining('参考答案：'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
