part of "visual_tool_test.dart";

void _visualToolChatCases() {
  group("MessageVisuals", () {
    testWidgets("renders a card for a linked scene, nothing without one", (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      late Directory root;
      late AppController c;
      late ProviderContainer scope;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp("tixun-visual-tool");
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await c.initialize();
        await seedVisualMessage(c.db, "session-1", "msg-1");
        await c.visual.create(
          sceneJson: jsonEncode(_plotArgs()["scene"]),
          messageId: "msg-1",
          title: "二次函数",
        );
        scope = ProviderContainer(
          overrides: [appControllerProvider.overrideWith((ref) => c)],
        );
      });
      addTearDown(() async {
        await tester.runAsync(() async {
          scope.dispose();
          await c.shutdown();
          await root.delete(recursive: true);
        });
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(
            home: Scaffold(body: MessageVisuals("msg-1")),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VisualCard), findsOneWidget);
      expect(find.text("二次函数"), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(
            home: Scaffold(body: MessageVisuals("msg-none")),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VisualCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group("Mock create_visual flow", () {
    test("asking to draw a figure creates a scene via the mock", () async {
      final root = await Directory.systemTemp.createTemp("tixun-visual-mock");
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
      await c.setAiDrawingEnabled(true);
      await c.newSession();
      // Pin the prompt language so the run's closing text is deterministic
      // (the test host locale decides the default otherwise).
      c.prompts = c.prompts.withLanguage("zh");
      await c.send("请画图，画出 y = x^2 的函数图");
      expect(c.messages.last.status, "complete");
      expect(c.messages.last.content, "已生成图形，可在下方查看。");
      final scenes = await c.db.select(c.db.visualScenes).get();
      expect(scenes, hasLength(1));
      expect(scenes.single.title, "y = x²");
      final links = await c.db.select(c.db.visualMessageLinks).get();
      expect(links, hasLength(1));
      expect(links.single.messageId, c.messages.last.id);
      final op = (await c.db.select(c.db.aiToolOperations).get()).single;
      expect(op.name, "create_visual");
      expect(op.status, "succeeded");
      final result = jsonDecode(op.result!) as Map;
      expect(result["verification"], "verified");
      expect(await c.visual.listByMessage(c.messages.last.id), hasLength(1));
    });

    Future<AppController> openMock() async {
      final root = await Directory.systemTemp.createTemp("tixun-visual-mock");
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
      await c.setAiDrawingEnabled(true);
      await c.newSession();
      c.prompts = c.prompts.withLanguage("zh");
      await c.send("请画图，画出 y = x^2 的函数图");
      expect(c.messages.last.status, "complete");
      expect((await c.db.select(c.db.visualScenes).get()), hasLength(1));
      return c;
    }

    test("asking to change the figure updates it via the mock", () async {
      final c = await openMock();
      final id = (await c.db.select(c.db.visualScenes).get()).single.id;
      await c.send("请把这张图改一下，图形 id 是 $id");
      expect(c.messages.last.status, "complete");
      final scenes = await c.db.select(c.db.visualScenes).get();
      expect(scenes, hasLength(1));
      expect(scenes.single.title, "y = x²（已修改）");
      expect(scenes.single.revision, 2);
      final ops = await c.db.select(c.db.aiToolOperations).get();
      expect(ops.map((o) => o.name), contains("update_visual"));
    });

    test("asking to view the figure reads it via the mock", () async {
      final c = await openMock();
      final id = (await c.db.select(c.db.visualScenes).get()).single.id;
      await c.send("请查看这张图，图形 id 是 $id");
      expect(c.messages.last.status, "complete");
      final scenes = await c.db.select(c.db.visualScenes).get();
      expect(scenes, hasLength(1));
      expect(scenes.single.title, "y = x²");
      expect(scenes.single.revision, 1);
      final ops = await c.db.select(c.db.aiToolOperations).get();
      expect(ops.map((o) => o.name), ["create_visual", "get_visual"]);
      final read = ops.singleWhere((o) => o.name == "get_visual");
      expect(read.runId, c.messages.last.id);
      expect(jsonDecode(read.result!)["title"], "y = x²");
      expect(jsonDecode(read.result!), isNot(contains("scene")));
      expect(c.messages.last.content, contains("工具已确认保存成功"));
    });

    test("natural follow-up edits still work after closing and reopening the database", () async {
      final root = await Directory.systemTemp.createTemp(
        "tixun-visual-restart",
      );
      final file = File("${root.path}/study.sqlite");
      AppController open() => AppController(
        AppDatabase.file(file),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
      );
      var c = open();
      addTearDown(() async {
        await c.shutdown();
        await root.delete(recursive: true);
      });
      await c.initialize();
      await c.setAiDrawingEnabled(true);
      await c.newSession();
      await c.send("请画图，画出 y = x^2 的函数图");
      final id = (await c.db.select(c.db.visualScenes).get()).single.id;
      final sessionId = c.selected!.id;
      await c.shutdown();
      c = open();
      await c.initialize();
      await c.selectSession(c.sessions.singleWhere((s) => s.id == sessionId));
      await c.send("请把这张图改一下");
      expect(c.messages.last.status, "complete");
      expect((await c.visual.get(id))!.revision, 2);
      expect((await c.db.select(c.db.visualScenes).get()), hasLength(1));
    });

    test("natural follow-up edits use the saved visual index without a user-supplied id", () async {
      final c = await openMock();
      await c.send("请把这张图改一下");
      expect(c.messages.last.status, "complete");
      final scenes = await c.db.select(c.db.visualScenes).get();
      expect(scenes, hasLength(1));
      expect(scenes.single.title, "y = x²（已修改）");
      expect(scenes.single.revision, 2);
      final ops = await c.db.select(c.db.aiToolOperations).get();
      expect(ops.map((o) => o.name), ["create_visual", "update_visual"]);
    });
  });
}
