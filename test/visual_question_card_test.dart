import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/app/theme.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/quiz_tool.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/core/visual/render/visual_painter.dart";
import "package:tixun/features/practice/question_card.dart";
import "package:tixun/features/practice/question_spec.dart";
import "package:tixun/features/visual/study_visuals.dart";

import "support/visual_fixtures.dart";

part "visual_question_answer_cases.dart";
part "visual_question_fixture.dart";

const _sceneV1 =
    '{"v":1,"kind":"plot2d","title":"V1","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';
const _sceneV2 =
    '{"v":1,"kind":"plot2d","title":"V2","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString("FontManifest.json")) as List;
    for (final font in manifest) {
      final loader = FontLoader(font["family"] as String);
      for (final asset in font["fonts"] as List) {
        loader.addFont(rootBundle.load(asset["asset"] as String));
      }
      await loader.load();
    }
  });

  final fixture = _VisualQuestionFixture();
  tearDown(fixture._closeController);
  fixture._previewCases();
  fixture._answerCases();
}

extension _VisualQuestionPreviewCases on _VisualQuestionFixture {
  void _previewCases() {
    testWidgets(
      "question fullscreen is a fixed preview with a return-to-answer action",
      (tester) async {
        late String questionId;
        await tester.runAsync(() async {
          await openController();
          await seedVisualMessage(c.db, "s", "r1");
          final visualId = await c.visual.create(
            sceneJson: jsonEncode({
              "v": 1,
              "kind": "geometry",
              "model": {
                "parameters": {"a": 1},
              },
              "view": {
                "x": [-5, 5],
                "y": [-5, 5],
              },
              "elements": [
                {
                  "id": "answer",
                  "type": "point",
                  "at": [1, 1],
                },
              ],
              "controls": [
                {
                  "id": "a",
                  "kind": "slider",
                  "label": "a",
                  "min": 0,
                  "max": 5,
                  "step": 1,
                  "value": 1,
                },
              ],
              "timeline": {
                "durationMs": 1000,
                "tracks": [
                  {
                    "id": "track",
                    "target": "a",
                    "from": 3,
                    "to": 5,
                    "startMs": 0,
                    "endMs": 1000,
                  },
                ],
                "steps": [
                  {
                    "atMs": 0,
                    "hide": ["answer"],
                  },
                  {
                    "atMs": 500,
                    "show": ["answer"],
                    "note": "SOLUTION",
                  },
                ],
              },
              "meta": {"alt": "固定题图"},
            }),
            messageId: "r1",
          );
          questionId = await c.practice.create(
            QuestionSpec(
              kind: "numeric",
              stem: "读图",
              answers: const [
                ["1"],
              ],
              visualId: visualId,
            ),
          );
        });
        await pumpScaffold(tester, QuestionCard(questionId));
        await tester.tap(find.byIcon(Icons.open_in_full));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key("visual-play-pause")), findsNothing);
        expect(find.byType(Slider), findsNothing);
        expect(find.text("SOLUTION"), findsNothing);
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<VisualPainter>()
            .last;
        expect(painter.parameters["a"], 3);
        expect(painter.hiddenElementIds, contains("answer"));
        await tester.tap(find.byKey(const Key("visual-return-to-answer")));
        await tester.pumpAndSettle();
        expect(find.byType(QuestionCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets("QuestionCard shows the pinned visual, frozen after edits", (
      tester,
    ) async {
      late String questionId;
      await tester.runAsync(() async {
        await openController();
        await seedVisualMessage(c.db, "s", "r1");
        final visualId = await c.visual.create(
          sceneJson: _sceneV1,
          messageId: "r1",
        );
        final result = await executeQuizTool(
          c.practice,
          ToolCall(
            "c1",
            "create_quiz",
            jsonEncode({
              "kind": "numeric",
              "stem": "抛物线与 x 轴交点的横坐标是多少？",
              "subject": "数学",
              "answers": [
                ["2"],
              ],
              "explanation": "x^2 - 4 = 0 的根是 ±2。",
              "visual_id": visualId,
            }),
          ),
          sessionId: "s",
          runId: "r1",
          cancel: CancelToken(),
          visual: c.visual,
        );
        expect(result["ok"], true);
        questionId = result["question_id"] as String;
      });
      await pumpScaffold(tester, QuestionCard(questionId));
      expect(find.text("V1"), findsOneWidget);
      expect(find.textContaining("抛物线与 x 轴交点"), findsOneWidget);
      await tester.runAsync(() async {
        final scenes = await c.visual.listByMessage("r1");
        await c.visual.revise(scenes.single.id, _sceneV2);
      });
      await tester.pumpAndSettle();
      expect(find.text("V1"), findsOneWidget);
      expect(find.text("V2"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("StudyVisuals shows linked visuals and hides when empty", (
      tester,
    ) async {
      await tester.runAsync(() async {
        await openController();
        await seedVisualMessage(c.db, "s", "r1");
        final now = DateTime.now();
        await c.db
            .into(c.db.knowledgeItems)
            .insert(
              KnowledgeItemsCompanion.insert(
                id: "k",
                title: "二次函数",
                content: "正文",
                subject: "数学",
                createdAt: now,
                updatedAt: now,
              ),
            );
        final visualId = await c.visual.create(
          sceneJson: _sceneV1,
          messageId: "r1",
        );
        await c.visual.linkToStudy(visualId, knowledgeId: "k");
      });
      await pumpScaffold(
        tester,
        const StudyVisuals(knowledgeId: "k", mistakeId: null, panelTitle: "图形"),
      );
      expect(find.text("图形"), findsOneWidget);
      expect(find.text("V1"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("StudyVisuals renders nothing for an unlinked study item", (
      tester,
    ) async {
      await tester.runAsync(() async {
        await openController();
      });
      await pumpScaffold(
        tester,
        const StudyVisuals(
          knowledgeId: "missing",
          mistakeId: null,
          panelTitle: "图形",
        ),
      );
      expect(find.text("图形"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final kind in ["point_select", "region_select", "read_value"]) {
      testWidgets("fullscreen $kind shares selection, submission and retry", (
        tester,
      ) async {
        const scene =
            '{"v":1,"kind":"geometry","title":"Question figure","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"r","type":"polygon","points":[[-1,-1],[1,-1],[1,1],[-1,1]],"fill":true}]}';
        final questionId = await createVisualQuestion(tester, kind, scene, [
          [
            kind == "region_select"
                ? "r"
                : kind == "read_value"
                ? "2"
                : "0,0",
          ],
        ], options: kind == "region_select" ? {"r": "Region"} : const {});
        await pumpScaffold(tester, QuestionCard(questionId));
        await tester.tap(find.byIcon(Icons.open_in_full));
        await tester.pumpAndSettle();
        if (kind == "read_value") {
          await tester.ensureVisible(find.byKey(const Key("quiz-answer-0")));
          await tester.enterText(find.byKey(const Key("quiz-answer-0")), "2");
        } else {
          await tester.tap(find.byKey(const Key("visual-tap-answer")));
          await tester.pumpAndSettle();
          expect(
            find.byKey(
              Key(
                kind == "region_select"
                    ? "visual-selection-region"
                    : "visual-selection-point",
              ),
            ),
            findsOneWidget,
          );
        }
        await tester.ensureVisible(find.byKey(const Key("submit-quiz")));
        await submitAndCheck(tester, questionId, true);
        await tester.tap(find.byKey(const Key("visual-return-to-answer")));
        await tester.pumpAndSettle();
        expect(find.textContaining("参考答案："), findsOneWidget);
        await tester.runAsync(() async {
          final detail = await c.practice.detail(questionId);
          expect(detail.attempts, hasLength(1));
        });
        await tester.ensureVisible(find.text("再做一次"));
        await tester.tap(find.text("再做一次"));
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          if (find.byKey(const Key("submit-quiz")).evaluate().isNotEmpty) break;
        }
        expect(find.byKey(const Key("visual-selection-region")), findsNothing);
        expect(find.byKey(const Key("visual-selection-point")), findsNothing);
        if (kind == "read_value") {
          expect(
            tester
                .widget<TextField>(find.byKey(const Key("quiz-answer-0")))
                .controller!
                .text,
            isEmpty,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      "solution figures are gated by the current attempt in both routes and on retry",
      (tester) async {
        late String id;
        await tester.runAsync(() async {
          await openController();
          id = await c.practice.create(
            const QuestionSpec(
              kind: "numeric",
              stem: "Read the graph",
              answers: [
                ["2"],
              ],
              questionScene: {
                "v": 1,
                "kind": "plot2d",
                "title": "QUESTION ONLY",
                "model": {"expression": "x^2"},
              },
              solutionScene: {
                "v": 1,
                "kind": "geometry",
                "title": "SOLUTION SECRET",
                "elements": [
                  {
                    "id": "text",
                    "type": "text",
                    "at": [0, 0],
                    "text": "ANSWER 2",
                  },
                ],
              },
            ),
          );
        });
        await pumpScaffold(tester, QuestionCard(id));
        expect(find.text("SOLUTION SECRET"), findsNothing);
        await tester.tap(find.byIcon(Icons.open_in_full));
        await tester.pumpAndSettle();
        expect(find.text("SOLUTION SECRET"), findsNothing);
        await tester.ensureVisible(find.byKey(const Key("quiz-answer-0")));
        await tester.enterText(find.byKey(const Key("quiz-answer-0")), "2");
        await tester.ensureVisible(find.byKey(const Key("submit-quiz")));
        await submitAndCheck(tester, id, true);
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text("SOLUTION SECRET"), findsOneWidget);
        await tester.tap(find.byKey(const Key("visual-return-to-answer")));
        await tester.pumpAndSettle();
        expect(find.text("SOLUTION SECRET"), findsOneWidget);
        await tester.ensureVisible(find.text("再做一次"));
        await tester.tap(find.text("再做一次"));
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pumpAndSettle();
          if (find.byKey(const Key("submit-quiz")).evaluate().isNotEmpty) break;
        }
        expect(find.text("SOLUTION SECRET"), findsNothing);
        await tester.tap(find.byIcon(Icons.open_in_full));
        await tester.pumpAndSettle();
        expect(find.text("SOLUTION SECRET"), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      "fullscreen view navigation cannot change answers and transformed taps still use model coordinates",
      (tester) async {
        const scene =
            '{"v":1,"kind":"geometry","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p","type":"point","at":[0,0]}]}';
        final id = await createVisualQuestion(
          tester,
          "point_select",
          scene,
          const [
            ["0,0"],
          ],
        );
        await pumpScaffold(tester, QuestionCard(id));
        await tester.tap(find.byIcon(Icons.open_in_full));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key("visual-tap-answer")));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key("visual-navigation-mode")));
        await tester.pumpAndSettle();
        final canvas = find.byKey(const Key("visual-canvas-paint"));
        final before = tester.getCenter(canvas);
        final initialWidth = tester.getRect(canvas).width;
        final finger1 = await tester.createGesture(pointer: 1);
        final finger2 = await tester.createGesture(pointer: 2);
        await finger1.down(before - const Offset(35, 0));
        await finger2.down(before + const Offset(35, 0));
        await tester.pump();
        await finger1.moveTo(before - const Offset(60, 0));
        await finger2.moveTo(before + const Offset(60, 0));
        await tester.pump();
        await finger1.moveTo(before - const Offset(95, 0));
        await finger2.moveTo(before + const Offset(95, 0));
        await tester.pump();
        await finger1.up();
        await finger2.up();
        await tester.pumpAndSettle();
        expect(tester.getRect(canvas).width, greaterThan(initialWidth * 1.2));
        await tester.timedDragFrom(
          before,
          const Offset(50, 30),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
        final after = tester.getCenter(canvas);
        expect((after - before).distance, greaterThan(10));
        expect(find.textContaining("已选点：(0.00, 0.00)"), findsOneWidget);
        await tester.tap(find.byKey(const Key("visual-navigation-mode")));
        await tester.pumpAndSettle();
        await tester.tapAt(after);
        await tester.pumpAndSettle();
        expect(find.textContaining("已选点："), findsOneWidget);
        await tester.tap(find.byKey(const Key("visual-reset-view")));
        await tester.pumpAndSettle();
        expect((tester.getCenter(canvas) - before).distance, lessThan(.1));
        await tester.ensureVisible(find.byKey(const Key("submit-quiz")));
        await submitAndCheck(tester, id, true);
        await tester.runAsync(() async {
          final d = await c.practice.detail(id);
          final saved = parseVisualPoint(d.responses[d.latest!.id]!.single)!;
          expect(saved.$1, closeTo(0, .00001));
          expect(saved.$2, closeTo(0, .00001));
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
