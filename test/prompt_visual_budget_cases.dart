part of "prompt_cost_test.dart";

void _visualBudgetCases(
  Future<AppController> Function(_Provider, {bool drawing}) open,
) {
  test(
    "ordinary requests omit large visual schemas and DSL examples",
    () async {
      final provider = _Provider((_, _) => _done);
      final c = await open(provider);
      await c.send("解释一下导数");
      final request = provider.requests.single;
      expect(request.tools.map((t) => t.name), contains(enableVisualToolsName));
      expect(request.instructions, isNot(contains(visualDslInstructions)));
      final quiz = request.tools.singleWhere((t) => t.name == "create_quiz");
      expect(quiz.parameters["properties"], isNot(contains("question_scene")));
      expect(
        request.tools.map((t) => t.name),
        isNot(contains("create_visual")),
      );

      // A reproducible payload-size comparison, NOT a billed-token estimate.
      final baseline = request.copyWith(
        instructions: "${request.instructions}\n$visualDslInstructions",
        tools: [
          ...request.tools.where(
            (t) => t.name != "create_quiz" && t.name != enableVisualToolsName,
          ),
          quizToolSchema,
          visualToolSchema,
          updateVisualToolSchema,
          getVisualToolSchema,
        ],
      );
      int bytes(AiRequest r) =>
          utf8.encode(jsonEncode(encodeCompletion(c.config, r))).length;
      debugPrint(
        "Ordinary request UTF-8 bytes: ${bytes(baseline)} -> ${bytes(request)}",
      );
      expect(bytes(request), lessThan(bytes(baseline) ~/ 4));
    },
  );

  test(
    "loading retains complete scene and patch contracts, usage and reasoning",
    () async {
      final provider = _Provider((_, turn) => turn == 1 ? _load : _done);
      final c = await open(provider);
      c.config = c.config.copyWith(thinking: true);
      await c.send("帮助理解抛物线"); // No explicit drawing keyword is required.
      expect(c.messages.last.status, "complete");
      final request = provider.requests.last;
      expect(request.instructions, contains(visualDslInstructions));
      expect(
        request.tools.map((t) => t.name),
        isNot(contains(enableVisualToolsName)),
      );
      final create = request.tools.singleWhere(
        (t) => t.name == "create_visual",
      );
      expect(
        (create.parameters["properties"] as Map)["scene"],
        visualSceneSchema,
      );
      final update = request.tools.singleWhere(
        (t) => t.name == "update_visual",
      );
      expect(update.parameters, updateVisualToolSchema.parameters);
      final quiz = request.tools.singleWhere((t) => t.name == "create_quiz");
      expect(quiz.parameters["properties"], contains("visual_id"));
      expect(quiz.parameters["properties"], isNot(contains("question_scene")));
      expect(
        request.messages
            .where((m) => m.calls.isNotEmpty)
            .single
            .reasoningContent,
        "Need a diagram.",
      );
      final loadResult = jsonDecode(request.messages.last.text) as Map;
      expect(loadResult["saved"], false);
      expect(await c.study.searchKnowledge(), isEmpty);
      expect(await c.db.select(c.db.aiToolOperations).get(), isEmpty);
      expect(await AiUsageStore(c.db).events(), hasLength(2));
    },
  );

  test("invalid loader arguments do not enable visuals", () {
    final tools = VisualToolset(exam: false);
    for (final args in ["{", "[]", '{"authorized":true}']) {
      expect(
        tools.enable(ToolCall("load", enableVisualToolsName, args))["ok"],
        false,
      );
      expect(tools.enabled, false);
      expect(tools.instructions, isEmpty);
    }
  });

  test("exam discovery exposes private scenes, never exploration tools", () {
    final tools = VisualToolset(exam: true);
    expect(
      tools.tools.first.parameters["properties"],
      isNot(contains("question_scene")),
    );
    tools.enable(const ToolCall("load", enableVisualToolsName, "{}"));
    expect(tools.tools.map((t) => t.name), ["create_quiz"]);
    final properties = tools.tools.single.parameters["properties"] as Map;
    expect(properties["question_scene"], visualSceneSchema);
    expect(properties["solution_scene"], visualSceneSchema);
    expect(properties, isNot(contains("visual_id")));
    expect(tools.instructions, contains("only in solution_scene"));
  });

  test("unloaded visual tool calls are rejected before any writes", () async {
    final provider = _Provider(
      (_, _) => const AiChunk(
        completed: true,
        calls: [ToolCall("unexpected", "create_visual", "{}")],
      ),
    );
    final c = await open(provider);
    await c.send("请解释");
    expect(c.messages.last.status, "error");
    expect(await c.db.select(c.db.visualScenes).get(), isEmpty);
  });

  test("loading schemas does not authorize study writes", () async {
    final provider = _Provider(
      (_, turn) => turn == 1
          ? _load
          : const AiChunk(
              completed: true,
              calls: [
                ToolCall("write", "create_knowledge", '{"title":"injected"}'),
              ],
            ),
    );
    final c = await open(provider);
    await c.send("请解释");
    expect(c.messages.last.status, "error");
    expect(c.pendingTool, isNull);
    expect(await c.study.searchKnowledge(), isEmpty);
  });

  test(
    "configured cumulative budget counts discovery and each batched call",
    () async {
      final provider = _Provider((_, turn) {
        if (turn == 1) return _load;
        if (turn == 5) return _done;
        return AiChunk(
          completed: true,
          calls: [
            for (var i = 0; i < (turn == 4 ? 2 : 3); i++)
              ToolCall("read-$turn-$i", "get_learning_progress", "{}"),
          ],
        );
      });
      final c = await open(provider);
      await c.setMaxToolCalls(9);
      await c.setTools(true);
      await c.send("查看学习进度");
      expect(c.messages.last.status, "complete");
      expect(provider.requests, hasLength(5));
      expect(
        provider.requests.last.messages.where((m) => m.role == AiRole.tool),
        hasLength(9),
      );
    },
  );

  test(
    "schema discovery cannot reset or extend the default call budget",
    () async {
      final provider = _Provider(
        (_, turn) => turn == 1
            ? _load
            : AiChunk(
                completed: true,
                calls: [ToolCall("read-$turn", "get_learning_progress", "{}")],
              ),
      );
      final c = await open(provider);
      await c.setTools(true);
      await c.send("查看学习进度");
      expect(c.maxToolCalls, 8);
      expect(c.messages.last.status, "error");
      expect(provider.requests, hasLength(9));
      expect(
        provider.requests.last.messages.where((m) => m.role == AiRole.tool),
        hasLength(8),
      );
    },
  );

  test(
    "repeated loading is rejected rather than extending discovery again",
    () async {
      final provider = _Provider((_, _) => _load);
      final c = await open(provider);
      await c.send("解释一下");
      expect(c.messages.last.status, "error");
      expect(provider.requests, hasLength(2));
      expect(await c.db.select(c.db.aiToolOperations).get(), isEmpty);
    },
  );
}
