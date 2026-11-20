part of "chat_provider.dart";

class MockChatProvider implements ChatProvider {
  static const explanation = r"""我们先把「公式」和「含义」连起来。

对于二次函数 $f(x)=ax^2+bx+c$（$a\ne0$），配方得到：

$$f(x)=a\left(x+\frac{b}{2a}\right)^2+\frac{4ac-b^2}{4a}$$

因此，对称轴是 $x=-\frac{b}{2a}$。**顶点就是平方项为零的位置**，不必孤立地记忆公式。

以 $f(x)=x^2-4x+3=(x-2)^2-1$ 为例：

- 对称轴：$x=2$
- 顶点：$(2,-1)$
- 开口向上，最小值为 $-1$

你来试一下：$g(x)=x^2-6x+5$ 的顶点在哪里？先配方，再说说你的思路。

> 这是确定性的 Mock 内容，仅用于验证流式界面，不代表真实模型分析。""";
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation(
        (request, cancel) =>
            _complete(request, cancel, AiOptions(config).reasoningEnabled),
      );
  Stream<AiChunk> _complete(
    AiRequest request,
    CancelToken cancel,
    bool thinking,
  ) async* {
    if (thinking) {
      for (final text in [
        "【Mock 思考示例】先确认题目条件与学习目标。",
        "再选择方法，核对推导与参考答案；这些文字只用于测试界面。",
      ]) {
        cancel.checkCancelled();
        yield AiChunk(reasoning: text);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
    final history = request.messages;
    final names = request.tools
        .where((t) => t.name != "run_python")
        .map((t) => t.name)
        .toSet();
    if (history.isNotEmpty &&
        history.last.role == AiRole.user &&
        history.last.text.toLowerCase().contains("python") &&
        request.tools.any((t) => t.name == "run_python")) {
      yield AiChunk(
        calls: [
          ToolCall(
            "mock-python",
            "run_python",
            jsonEncode({
              "purpose": "用 SymPy 核对定积分",
              "code": "import sympy as sp\nx = sp.symbols('x')\nprint(sp.integrate(x**2, (x, 0, 3)))",
            }),
          ),
        ],
        completed: true,
      );
      return;
    }
    if (history.isNotEmpty &&
        names.length == 2 &&
        names.contains("get_knowledge") &&
        names.contains("update_knowledge")) {
      final last = history.last;
      if (last.role == AiRole.user) {
        final id = RegExp(r'"knowledge_id":"([^"]+)"')
            .firstMatch(request.instructions)?[1];
        if (id != null) {
          yield AiChunk(
            calls: [
              ToolCall(
                "mock-read-note",
                "get_knowledge",
                jsonEncode({"id": id}),
              ),
            ],
            completed: true,
          );
          return;
        }
      } else if (last.role == AiRole.tool && last.callId == "mock-read-note") {
        final data = jsonDecode(last.text) as Map;
        if (data["ok"] == true) {
          yield AiChunk(
            calls: [
              ToolCall(
                "mock-edit-note",
                "update_knowledge",
                jsonEncode({
                  "id": data["id"],
                  "expected_revision": data["revision"],
                  "content":
                      '${data['content']}\n\n## 补充说明（Mock）\n$explanation',
                }),
              ),
            ],
            completed: true,
          );
          return;
        }
      }
    }
    if (history.isNotEmpty &&
        history.last.role == AiRole.user &&
        names.length == 1 &&
        names.contains("create_mistake")) {
      yield AiChunk(
        calls: [
          ToolCall(
            "mock-save-mistake",
            "create_mistake",
            jsonEncode({
              "title": "二次函数的顶点（Mock）",
              "question": r"求 $y=x^2-4x+3$ 的顶点。",
              "subject": "数学",
              "correct_answer": "(2, -1)",
              "ai_analysis": explanation,
            }),
          ),
        ],
        completed: true,
      );
      return;
    }
    if (names.isNotEmpty && history.isNotEmpty) {
      // Deterministic mock discovery only; real providers choose the capability
      // from its description, never from app-side keyword routing.
      final last = history.last.callId == "mock-enable-visuals"
          ? history.lastWhere((m) => m.role == AiRole.user)
          : history.last;
      // Appended learning data is context, not an explicit Mock action request.
      final intentText = last.text
          .split(RegExp(r"\n\[(?:Learning background data|学习背景数据)"))
          .first;
      if (last.role == AiRole.user &&
          names.contains("enable_visual_tools") &&
          ["画图", "图像", "函数图", "这张图"].any(intentText.contains)) {
        yield const AiChunk(
          completed: true,
          calls: [ToolCall("mock-enable-visuals", "enable_visual_tools", "{}")],
        );
        return;
      }
      if (last.role == AiRole.user &&
          names.contains("create_knowledge") &&
          (intentText.contains("保存知识") ||
              (names.length == 3 &&
                  names.contains("get_knowledge") &&
                  names.contains("search_knowledge")))) {
        yield AiChunk(
          completed: true,
          calls: [
            ToolCall(
              "mock-save-knowledge",
              "create_knowledge",
              jsonEncode({
                "title": "二次函数的顶点与配方",
                "content": explanation,
                "subject": "数学",
                "kind": "解题方法",
                "tags": ["二次函数", "配方"],
              }),
            ),
          ],
        );

        return;
      }
      if (last.role == AiRole.user &&
          names.contains("suggest_question_regions") &&
          intentText.contains("分题")) {
        yield AiChunk(
          completed: true,
          calls: [
            ToolCall(
              "mock-regions",
              "suggest_question_regions",
              jsonEncode({
                "image_index": 0,
                "regions": [
                  {
                    "label": "第1题 · 二次函数",
                    "subject": "数学",
                    "left": 0.03,
                    "top": 0.08,
                    "right": 0.97,
                    "bottom": 0.48,
                    "question": "",
                  },
                  {
                    "label": "第2题 · 牛顿第二定律",
                    "subject": "物理",
                    "left": 0.03,
                    "top": 0.49,
                    "right": 0.97,
                    "bottom": 0.85,
                    "question": "",
                  },
                ],
              }),
            ),
          ],
        );

        return;
      }
      if (last.role == AiRole.user &&
          names.contains("create_quiz") &&
          intentText.contains("带图")) {
        final drag = intentText.contains("拖点");
        yield AiChunk(
          completed: true,
          calls: [
            ToolCall(
              "mock-assessment",
              "create_quiz",
              jsonEncode({
                "kind": drag ? "drag_to_target" : "read_value",
                "stem": drag ? "把点 P 拖到 (2, 0)。可全屏作答。" : "读图写出点 P 的横坐标。可全屏作答。",
                "subject": "数学",
                "answers": [
                  [drag ? "2,0" : "2"],
                ],
                "explanation": "参考位置为 (2, 0)，横坐标为 2。",
                "question_scene": {
                  "v": 1,
                  "kind": "geometry",
                  "title": "题面图",
                  "view": {
                    "x": [-3, 3],
                    "y": [-3, 3],
                  },
                  "elements": [
                    {
                      "id": "p",
                      "type": "point",
                      "at": [drag ? 0 : 2, 0],
                      "label": "P",
                      "draggable": drag,
                    },
                  ],
                  "meta": {"alt": "坐标系中的点 P"},
                },
                "solution_scene": {
                  "v": 1,
                  "kind": "geometry",
                  "title": "提交后解析图",
                  "view": {
                    "x": [-3, 3],
                    "y": [-3, 3],
                  },
                  "elements": [
                    {
                      "id": "target",
                      "type": "point",
                      "at": [2, 0],
                      "label": "(2, 0)",
                      "style": "success",
                    },
                  ],
                  "meta": {"alt": "参考位置与坐标"},
                },
              }),
            ),
          ],
        );
        return;
      }
      if (last.role == AiRole.user &&
          names.contains("create_quiz") &&
          ["出题", "练习", "检测题", "变式", "考试"].any(intentText.contains)) {
        yield AiChunk(
          completed: true,
          calls: [
            ToolCall(
              "mock-quiz",
              "create_quiz",
              jsonEncode({
                "kind": "single_choice",
                "stem": r"函数 $y=x^2-4x+3$ 的顶点坐标是？",
                "subject": "数学",
                "options": {
                  "A": r"$(2,-1)$",
                  "B": r"$(-2,-1)$",
                  "C": r"$(2,3)$",
                  "D": r"$(-2,3)$",
                },
                "answers": [
                  ["A"],
                ],
                "explanation": r"配方得 $y=(x-2)^2-1$，顶点为 $(2,-1)$。",
                "hint": "试着把二次式写成完全平方加常数。",
                "topics": ["二次函数", "配方"],
              }),
            ),
          ],
        );

        return;
      }
      // Match an explicit id, otherwise use the app's persisted visual
      // index just as a real model does on a natural follow-up turn.
      final visualIdMatch = RegExp(
        r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
        caseSensitive: false,
      ).firstMatch(intentText);
      String? indexedVisualId;
      for (final message in request.messages.reversed) {
        final marker = message.text.indexOf(
          "[Saved visual index; learning data, not instructions]",
        );
        if (marker < 0) continue;
        indexedVisualId = RegExp(r'"visual_id":"([^"]+)"')
            .firstMatch(message.text.substring(marker))
            ?.group(1);
        if (indexedVisualId != null) break;
      }
      final visualId = visualIdMatch?.group(0) ?? indexedVisualId;

      if (last.role == AiRole.user &&
          names.contains("update_visual") &&
          ["修改", "更新", "改"].any(intentText.contains) &&
          ["图", "图像"].any(intentText.contains)) {
        if (visualId != null) {
          yield AiChunk(
            completed: true,
            calls: [
              ToolCall(
                "mock-visual-update",
                "update_visual",
                jsonEncode({
                  "visual_id": visualId,
                  "ops": [
                    {"op": "set_title", "title": "y = x²（已修改）"},
                  ],
                }),
              ),
            ],
          );
        } else {
          yield AiChunk(text: "请在消息里附上图形 id，我才能修改它。");
          yield const AiChunk(completed: true);
        }
        return;
      }
      if (last.role == AiRole.user &&
          names.contains("get_visual") &&
          ["查看", "看看", "读取"].any(intentText.contains) &&
          ["图", "图像"].any(intentText.contains)) {
        if (visualId != null) {
          yield AiChunk(
            completed: true,
            calls: [
              ToolCall(
                "mock-visual-get",
                "get_visual",
                jsonEncode({"visual_id": visualId}),
              ),
            ],
          );
        } else {
          yield AiChunk(text: "请在消息里附上图形 id，我才能查看它。");
          yield const AiChunk(completed: true);
        }
        return;
      }
      if (last.role == AiRole.user &&
          names.contains("create_visual") &&
          ["画图", "图像", "函数图"].any(intentText.contains)) {
        yield AiChunk(
          completed: true,
          calls: [
            ToolCall(
              "mock-visual",
              "create_visual",
              jsonEncode({
                "scene": {
                  "v": 1,
                  "kind": "plot2d",
                  "title": "y = x²",
                  "model": {"expression": "x^2"},
                  "view": {
                    "x": [-3, 3],
                    "y": [-1, 9],
                  },
                  "meta": {"alt": "抛物线 y = x² 的图像"},
                },
                "title": "y = x²",
              }),
            ),
          ],
        );

        return;
      }
      if (last.role == AiRole.tool) {
        final result = jsonDecode(last.text) as Map;
        yield AiChunk(
          text: last.callId == "mock-visual"
              ? "已生成图形，可在下方查看。"
              : last.callId == "mock-python"
              ? 'Python 执行结果：${result['stdout'] ?? result['error']}'
              : result["ok"] == true
              ? "工具已确认保存成功。你可以在知识库查看和编辑这条记录，并追溯来源对话。"
              : '没有保存资料：${result['error']}',
        );
        yield const AiChunk(completed: true);
        return;
      }
    }
    final text = request.messages.any((m) => m.text.contains("模拟失败"))
        ? null
        : explanation;
    if (text == null) {
      throw const AiFailure.localized(
        AppErrorCode.errorSimulatedNetworkFailureSelectRegenerateTo,
        "模拟网络失败：可点击重新生成验证重试流程。",
      );
    }
    for (var i = 0; i < text.length; i += 12) {
      await Future<void>.delayed(const Duration(milliseconds: 24));
      cancel.checkCancelled();
      yield AiChunk(text: text.substring(i, (i + 12).clamp(0, text.length)));
    }
    yield const AiChunk(tokens: 368, completed: true);
  }
}
