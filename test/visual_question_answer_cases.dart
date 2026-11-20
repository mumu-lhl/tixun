part of "visual_question_card_test.dart";

extension _VisualQuestionAnswerCases on _VisualQuestionFixture {
  void _answerCases() {
    testWidgets("Point-select: tapping the visual answers and grades", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"点选图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[0,0],"label":"原点"}],"meta":{"alt":"点选"}}';
      final questionId = await createVisualQuestion(
        tester,
        "point_select",
        scene,
        [
          ["0,0"],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key("option-A")), findsNothing);
      // The canvas center is model (0,0) for this symmetric view.
      await tester.tap(find.byKey(const Key("visual-tap-answer")));
      await tester.pumpAndSettle();
      expect(find.textContaining("已选点："), findsOneWidget);
      await submitAndCheck(tester, questionId, true);
    });

    testWidgets("Region-select: tapping inside a region answers with its id", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"区域图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"r1","type":"polygon","points":[[-1,-1],[1,-1],[1,1],[-1,1]],"fill":true},{"id":"r2","type":"polygon","points":[[1.5,1.5],[2.5,1.5],[2.5,2.5],[1.5,2.5]],"fill":true}],"meta":{"alt":"区域"}}';
      final questionId = await createVisualQuestion(
        tester,
        "region_select",
        scene,
        [
          ["r1"],
        ],
        options: {"r1": "中心区域", "r2": "右上区域"},
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key("option-r1")), findsNothing);
      await tester.tap(find.byKey(const Key("visual-tap-answer")));
      await tester.pumpAndSettle();
      expect(find.text("已选区域：中心区域"), findsOneWidget);
      await submitAndCheck(tester, questionId, true);
    });

    testWidgets("Region-select: a tap outside every region selects nothing", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"区域图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"r2","type":"polygon","points":[[1.5,1.5],[2.5,1.5],[2.5,2.5],[1.5,2.5]],"fill":true}],"meta":{"alt":"区域"}}';
      final questionId = await createVisualQuestion(
        tester,
        "region_select",
        scene,
        [
          ["r2"],
        ],
        options: {"r2": "右上区域"},
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      // The canvas center (0,0) is outside the only region.
      await tester.tap(find.byKey(const Key("visual-tap-answer")));
      await tester.pumpAndSettle();
      expect(find.textContaining("已选区域："), findsNothing);
      expect(find.text("请选择"), findsOneWidget);
      await tester.tap(find.byKey(const Key("submit-quiz")));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        if (find.textContaining("请先完成作答").evaluate().isNotEmpty) break;
        if (i == 19) fail("the incomplete-answer hint never appeared");
      }
      await tester.runAsync(() async {
        expect((await c.practice.detail(questionId)).latest!.status, "draft");
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets("Drag-to-target: dragging the point answers and grades", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"拖点图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[0,0],"label":"P","draggable":true}],"meta":{"alt":"拖点"}}';
      final questionId = await createVisualQuestion(
        tester,
        "drag_to_target",
        scene,
        [
          ["2,0"],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key("option-A")), findsNothing);
      // The canvas is 358 wide for a 6-unit view, letterboxed to a
      // 44.75 px/unit scale: dragging 90 px right moves the point from
      // model (0,0) to about (2.01, 0), inside the 0.5 tolerance.
      final canvas = find.byKey(const Key("visual-canvas-paint"));
      await tester.dragFrom(tester.getCenter(canvas), const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining("已选点："), findsOneWidget);
      await submitAndCheck(tester, questionId, true);
    });

    testWidgets("Read-value: typing the value read off the graph grades", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"plot2d","title":"抛物线","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';
      final questionId = await createVisualQuestion(
        tester,
        "read_value",
        scene,
        [
          ["-4"],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      // Read-value keeps the typed input: the visual is shown, and the
      // answer is typed like a numeric question — with a numeric
      // keyboard, not the default one.
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      await tester.enterText(find.byType(TextField), "-4");
      await tester.pumpAndSettle();
      await submitAndCheck(tester, questionId, true);
    });

    testWidgets("Read-value: a non-numeric answer is rejected before grading", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"plot2d","title":"抛物线","model":{"expression":"x^2-4"},"view":{"x":[-3,3],"y":[-5,6]},"meta":{"alt":"抛物线"}}';
      final questionId = await createVisualQuestion(
        tester,
        "read_value",
        scene,
        [
          ["-4"],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      await tester.enterText(find.byType(TextField), "abc");
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("submit-quiz")));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        if (find.textContaining("请输入有限数值").evaluate().isNotEmpty) break;
        if (i == 19) fail("the non-numeric hint never appeared");
      }
      await tester.runAsync(() async {
        expect((await c.practice.detail(questionId)).latest!.status, "draft");
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets("Drag-to-target: graded view keeps the point at the answer", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"拖点图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[0,0],"label":"P","draggable":true}],"meta":{"alt":"拖点"}}';
      final questionId = await createVisualQuestion(
        tester,
        "drag_to_target",
        scene,
        [
          ["2,0"],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      final canvas = find.byKey(const Key("visual-canvas-paint"));
      await tester.dragFrom(tester.getCenter(canvas), const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining("已选点："), findsOneWidget);
      final dragged = questionPainter(tester).pointOverrides["p1"]!;
      expect(dragged.dx, greaterThan(1.5));
      await submitAndCheck(tester, questionId, true);
      // Graded view: the answer hint stays, and the point still renders
      // at the submitted position instead of snapping back to the origin.
      expect(find.textContaining("已选点："), findsOneWidget);
      final overrides = questionPainter(tester).pointOverrides;
      expect(overrides.keys, ["p1"]);
      expect(overrides["p1"]!.dx, closeTo(dragged.dx, 0.01));
      expect(overrides["p1"]!.dy, closeTo(dragged.dy, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets("Point-select: graded view keeps the selection marker", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"点选图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[0,0],"label":"原点"}],"meta":{"alt":"点选"}}';
      final questionId = await createVisualQuestion(
        tester,
        "point_select",
        scene,
        [
          ["0,0"],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      await tester.tap(find.byKey(const Key("visual-tap-answer")));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("visual-selection-point")), findsOneWidget);
      await submitAndCheck(tester, questionId, true);
      // The marker and the hint survive grading: the student's own
      // answer stays visible on the figure.
      expect(find.textContaining("已选点："), findsOneWidget);
      expect(find.byKey(const Key("visual-selection-point")), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Region-select: graded view keeps the region highlight", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"区域图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"r1","type":"polygon","points":[[-1,-1],[1,-1],[1,1],[-1,1]],"fill":true},{"id":"r2","type":"polygon","points":[[1.5,1.5],[2.5,1.5],[2.5,2.5],[1.5,2.5]],"fill":true}],"meta":{"alt":"区域"}}';
      final questionId = await createVisualQuestion(
        tester,
        "region_select",
        scene,
        [
          ["r1"],
        ],
        options: {"r1": "中心区域", "r2": "右上区域"},
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      await tester.tap(find.byKey(const Key("visual-tap-answer")));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("visual-selection-region")), findsOneWidget);
      await submitAndCheck(tester, questionId, true);
      expect(find.text("已选区域：中心区域"), findsOneWidget);
      expect(find.byKey(const Key("visual-selection-region")), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Drag-to-target: retry clears the previous drag position", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"拖点图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[0,0],"label":"P","draggable":true}],"meta":{"alt":"拖点"}}';
      final questionId = await createVisualQuestion(
        tester,
        "drag_to_target",
        scene,
        [
          ["2,0"],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      final canvas = find.byKey(const Key("visual-canvas-paint"));
      await tester.dragFrom(tester.getCenter(canvas), const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining("已选点："), findsOneWidget);
      await submitAndCheck(tester, questionId, true);
      expect(find.text("再做一次"), findsOneWidget);
      await tester.tap(find.text("再做一次"));
      await tester.pumpAndSettle();
      // Retry starts a new attempt (a Drift round-trip): wait for the
      // draft view to come back, like the submit flow does.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        if (find.byKey(const Key("submit-quiz")).evaluate().isNotEmpty) break;
        if (i == 19) fail("the retry never returned to the draft view");
      }
      expect(find.textContaining("已选点："), findsNothing);
      expect(questionPainter(tester).pointOverrides, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      "Drag-to-target: a point inside a group restores from the saved answer",
      (tester) async {
        const scene =
            '{"v":1,"kind":"geometry","title":"分组拖点","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[-2,-2],"label":"A","draggable":true},{"id":"g1","type":"group","children":[{"id":"p2","type":"point","at":[0,0],"label":"B","draggable":true}]}],"meta":{"alt":"分组拖点"}}';
        final questionId = await createVisualQuestion(
          tester,
          "drag_to_target",
          scene,
          [
            ["2,0"],
          ],
        );
        await pumpScaffold(tester, QuestionCard(questionId));
        final canvas = find.byKey(const Key("visual-canvas-paint"));
        // The canvas center is model (0,0): the grouped point p2, not p1.
        await tester.dragFrom(tester.getCenter(canvas), const Offset(90, 0));
        await tester.pumpAndSettle();
        expect(find.textContaining("已选点："), findsOneWidget);
        final dragged = questionPainter(tester).pointOverrides["p2"]!;
        expect(dragged.dx, greaterThan(1.5));
        await submitAndCheck(tester, questionId, true);
        // Reload the question: a fresh state must restore the grouped
        // point from the saved "p2:x,y" answer, not the first point.
        await pumpScaffold(tester, QuestionCard(questionId));
        final restored = questionPainter(tester).pointOverrides;
        expect(restored.keys, ["p2"]);
        expect(restored["p2"]!.dx, closeTo(dragged.dx, 0.01));
        expect(restored["p2"]!.dy, closeTo(dragged.dy, 0.01));
        expect(tester.takeException(), isNull);
      },
    );

    test("parseVisualPoint accepts an id-prefixed drag answer", () {
      expect(parseVisualPoint("p2:1.5,-2"), (1.5, -2));
      expect(parseVisualPoint("1.5,-2"), (1.5, -2));
      expect(parseVisualPoint("p2:abc"), isNull);
      expect(parseVisualPoint("p2:"), isNull);
    });

    testWidgets("fullscreen drag shares the card answer and persists the draft", (
      tester,
    ) async {
      const scene =
          '{"v":1,"kind":"geometry","title":"拖点图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"p1","type":"point","at":[0,0],"label":"P","draggable":true}],"meta":{"alt":"拖点"}}';
      final questionId = await createVisualQuestion(
        tester,
        "drag_to_target",
        scene,
        [
          ["2,0"],
        ],
      );
      await pumpScaffold(tester, QuestionCard(questionId));
      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("visual-play-pause")), findsNothing);
      expect(find.byKey(const Key("visual-reset-drag")), findsNothing);
      final center = tester.getCenter(
        find.byKey(const Key("visual-canvas-paint")).last,
      );
      await tester.dragFrom(center, const Offset(90, 0));
      await tester.pump();
      final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final visual = paints.where((p) => p.painter is VisualPainter).toList();
      final moved = (visual.last.painter as VisualPainter).pointOverrides["p1"];
      expect(moved, isNotNull);
      await tester.tap(find.byKey(const Key("visual-return-to-answer")));
      await tester.pumpAndSettle();
      expect(questionPainter(tester).pointOverrides["p1"], moved);
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        await c.practice.flushDrafts();
        final d = await c.practice.detail(questionId);
        expect(d.responses[d.latest!.id]!.single, startsWith("p1:"));
        expect(d.attempts, hasLength(1));
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      "Region-select: a region hidden by the first step cannot be tapped",
      (tester) async {
        const scene =
            '{"v":1,"kind":"geometry","title":"区域图","view":{"x":[-3,3],"y":[-3,3]},"elements":[{"id":"r1","type":"polygon","points":[[-1,-1],[1,-1],[1,1],[-1,1]],"fill":true},{"id":"r2","type":"polygon","points":[[1.5,1.5],[2.5,1.5],[2.5,2.5],[1.5,2.5]],"fill":true}],"timeline":{"durationMs":1000,"steps":[{"atMs":0,"show":[],"hide":["r1"],"note":"藏起"}]},"meta":{"alt":"区域"}}';
        final questionId = await createVisualQuestion(
          tester,
          "region_select",
          scene,
          [
            ["r2"],
          ],
          options: {"r2": "右上区域"},
        );
        await pumpScaffold(tester, QuestionCard(questionId));
        // The canvas center (0,0) is inside r1, but the first step hides
        // it — the card renders the t=0 frame, so the tap selects nothing.
        await tester.tap(find.byKey(const Key("visual-tap-answer")));
        await tester.pumpAndSettle();
        expect(find.textContaining("已选区域："), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
