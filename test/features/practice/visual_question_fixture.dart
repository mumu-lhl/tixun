part of "visual_question_card_test.dart";

class _VisualQuestionFixture {
  late AppController c;

  late ProviderContainer container;

  Future<void> openController() async {
    final root = await Directory.systemTemp.createTemp(
      "tixun-visual-question-card",
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

  VisualPainter questionPainter(WidgetTester tester) {
    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    final visual = paints.where((p) => p.painter is VisualPainter).toList();
    return visual.single.painter as VisualPainter;
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
      await seedVisualMessage(c.db, "s", "r1");
      final visualId = await c.visual.create(
        sceneJson: sceneJson,
        messageId: "r1",
      );
      final result = await executeQuizTool(
        c.practice,
        ToolCall(
          "c1",
          "create_quiz",
          jsonEncode({
            "kind": kind,
            "stem": "请在图上作答。",
            "subject": "数学",
            "options": options,
            "answers": answers,
            "explanation": "见图。",
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
    return questionId;
  }

  Future<void> submitAndCheck(
    WidgetTester tester,
    String questionId,
    bool correct,
  ) async {
    await tester.tap(find.byKey(const Key("submit-quiz")));
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
      if (find.textContaining("参考答案：").evaluate().isNotEmpty) break;
      if (i == 19) fail("the attempt was never graded");
    }
    await tester.runAsync(() async {
      expect((await c.practice.detail(questionId)).latest!.correct, correct);
    });
    expect(tester.takeException(), isNull);
  }

  Future<void> _closeController() async {
    container.dispose();
    await c.db.close();
    if (await c.files.root.exists()) {
      await c.files.root.delete(recursive: true);
    }
  }
}
