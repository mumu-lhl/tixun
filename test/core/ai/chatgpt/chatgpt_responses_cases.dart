part of "chatgpt_test.dart";

void _responsesCases() {
  test("Responses requests use official fields, namespace tools, vision and encrypted reasoning replay", () async {
    final f = ChatGptFixture();
    await f.seed();
    var request = AiRequest(
      instructions: "Guide the student.",
      messages: [
        const AiMessage.user(
          "Explain",
          images: [AiImage("data:image/png;base64,fixture")],
        ),
      ],
      tools: [
        const AiTool(
          name: "create_quiz",
          description: "Quiz",
          parameters: {"type": "object"},
        ),
      ],
      maxOutputTokens: 20,
    );
    final output = [
      {
        "type": "reasoning",
        "id": "rs_fixture",
        "encrypted_content": "opaque-fixture",
        "summary": [],
      },
      {
        "type": "function_call",
        "call_id": "call_fixture",
        "name": "create_quiz",
        "namespace": "tixun",
        "arguments": "{}",
      },
    ];
    final sent = <Map<String, dynamic>>[];
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((r) {
        sent.add(Map<String, dynamic>.from(r.data as Map));
        return fixtureSse([completed(output: sent.length == 1 ? output : [])]);
      });
    final conversation = ChatGptResponses(f.auth, client: client).start(config);
    final chunks = await conversation.complete(request, CancelToken()).toList();
    final encoded = sent.first;
    expect(encoded["store"], false);
    expect(encoded["stream"], true);
    expect(encoded["instructions"], "Guide the student.");
    expect(encoded.containsKey("max_tokens"), false);
    expect(encoded.containsKey("max_output_tokens"), false);
    expect(encoded["input"][0]["content"][1]["type"], "input_image");
    expect(encoded["tools"][0]["type"], "namespace");
    expect(chunks.last.completed, true);
    expect(chunks.last.calls.single.id, "call_fixture");
    request = request.copyWith(
      messages: [
        ...request.messages,
        AiMessage.assistant("", calls: chunks.last.calls),
        const AiMessage.tool("call_fixture", '{"ok":true}'),
      ],
    );
    await conversation.complete(request, CancelToken()).toList();
    final next = sent.last;
    expect(next["input"][1], output.first);
    expect(next["input"][2], output.last);
    expect(next["input"][3]["type"], "function_call_output");
    expect(next.containsKey("_chatgpt_tool_context"), false);
    expect(
      () =>
          validateConfig(config.copyWith(baseUrl: "https://attacker.invalid")),
      throwsFormatException,
    );
  });

  test(
    "Optional usage metadata cannot invalidate a complete tool response",
    () async {
      final f = ChatGptFixture();
      await f.seed();
      for (final total in [17.0, "17", null]) {
        var requests = 0;
        final client = Dio()
          ..httpClientAdapter = FixtureAdapter((_) {
            final event = completed(
              output: ++requests == 1
                  ? [
                      {
                        "type": "message",
                        "content": [
                          {"type": "output_text", "text": "OK"},
                        ],
                      },
                    ]
                  : [
                      {
                        "type": "function_call",
                        "call_id": "quiz",
                        "name": "create_quiz",
                        "namespace": "tixun",
                        "arguments": "{}",
                      },
                    ],
            );
            (event["response"] as Map)["usage"] = {"total_tokens": total};
            return fixtureSse([event]);
          });
        final provider = ChatGptResponses(f.auth, client: client);
        final model = config.copyWith(model: "gpt-6.1-terra", effort: "high");
        final connection = await provider
            .start(model)
            .complete(
              AiRequest(
                instructions: "",
                messages: [const AiMessage.user("只回复 OK")],
              ),
              CancelToken(),
            )
            .toList();
        expect(connection.map((c) => c.text).join(), "OK");
        final chat = await provider
            .start(model)
            .complete(
              AiRequest(
                instructions: "Guide the student.",
                messages: [const AiMessage.user("出一道练习题")],
                tools: [
                  const AiTool(
                    name: "create_quiz",
                    description: "Quiz",
                    parameters: {"type": "object"},
                  ),
                ],
              ),
              CancelToken(),
            )
            .toList();
        expect(chat.last.completed, true);
        expect(chat.last.calls.single.name, "create_quiz");
        expect(chat.last.tokens, isNull);
      }
    },
  );

  test("Mislabeled SSE is delivered before the connection closes", () async {
    final f = ChatGptFixture();
    await f.seed();
    final wire = StreamController<Uint8List>();
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter(
        (_) => ResponseBody(
          wire.stream,
          200,
          headers: {
            "content-type": ["application/json"],
          },
        ),
      );
    final firstText = Completer<void>();
    final result = ChatGptResponses(f.auth, client: client)
        .start(config)
        .complete(
          AiRequest(instructions: "", messages: [const AiMessage.user("你好")]),
          CancelToken(),
        )
        .map((chunk) {
          if (chunk.text.isNotEmpty && !firstText.isCompleted) {
            firstText.complete();
          }
          return chunk;
        })
        .toList();
    final delta =
        ' \r\n\ufeffdata: ${jsonEncode({'type': 'response.output_text.delta', 'delta': '你好'})}\n\n';
    for (final byte in utf8.encode(delta)) {
      wire.add(Uint8List.fromList([byte]));
    }
    try {
      await expectLater(
        firstText.future.timeout(const Duration(seconds: 1)),
        completes,
      );
    } finally {
      wire.add(
        Uint8List.fromList(utf8.encode("data: ${jsonEncode(completed())}\n\n")),
      );
      // Completion cancels the consumer; don't wait on a paused fixture stream.
      unawaited(wire.close());
      final chunks = await result.timeout(const Duration(seconds: 3));
      expect(chunks.map((c) => c.text).join(), "你好");
      expect(chunks.last.completed, true);
    }
  });

  test(
    "A completed response fills a missing text delta without repeating text",
    () async {
      final events = [
        {"type": "response.output_text.delta", "delta": "关键步骤"},
        completed(
          output: [
            {
              "type": "message",
              "content": [
                {"type": "output_text", "text": "关键步骤与完整结论"},
              ],
            },
          ],
        ),
      ];
      final wire = events.map((e) => "data: ${jsonEncode(e)}\n\n").join();
      final chunks = await decodeResponses(
        Stream.value(utf8.encode(wire)),
        null,
      ).toList();
      expect(chunks.map((c) => c.text).join(), "关键步骤与完整结论");
      expect(chunks.last.completed, true);
    },
  );

  test("Empty SSE heartbeats do not invalidate text or reasoning", () async {
    final text =
        "data:\n\ndata:  \n\n: heartbeat\n\n"
        'data: ${jsonEncode({'type': 'response.reasoning_summary_text.delta', 'delta': '核对条件'})}\n\n'
        'data:\n\ndata: ${jsonEncode({'type': 'response.output_text.delta', 'delta': '答案'})}\n\n'
        "data: ${jsonEncode(completed())}\n\n";
    final chunks = await decodeResponses(
      Stream.value(utf8.encode(text)),
      null,
    ).toList();
    expect(chunks.map((c) => c.text).join(), "答案");
    expect(chunks.map((c) => c.reasoning).join(), "核对条件");
    expect(chunks.last.completed, true);
    await expectLater(
      decodeResponses(Stream.value(utf8.encode("data:\n\n")), null).toList(),
      throwsA(isA<AiFailure>()),
    );
  });

  test("Quota failure, invalid JSON and interrupted streams never become successful replies", () async {
    for (final tail in [
      'data: ${jsonEncode({
        'type': 'response.failed',
        'response': {
          'error': {'code': 'subscription_sharing_usage_limit_exceeded'},
        },
      })}\n\n',
      "data: {bad-json}\n\n",
      "",
      'data: ${jsonEncode({'type': 'response.incomplete'})}\n\n',
    ]) {
      final chunks = <AiChunk>[];
      final stream = decodeResponses(
        Stream.value(
          utf8.encode(
            'data: {"type":"response.output_text.delta","delta":"Partial"}\n\n$tail',
          ),
        ),
        null,
      );
      await expectLater(stream.forEach(chunks.add), throwsA(isA<AiFailure>()));
      expect(chunks.single.text, "Partial");
      expect(chunks.single.completed, false);
    }
  });

  test("Incomplete and failed responses keep reported usage before throwing", () async {
    for (final type in ["response.incomplete", "response.failed"]) {
      final wire =
          'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'Partial'})}\n\n'
          'data: ${jsonEncode({
            'type': type,
            'response': {
              'status': 'failed',
              'usage': {'input_tokens': 80, 'output_tokens': 20, 'total_tokens': 100},
            },
          })}\n\n';
      final chunks = <AiChunk>[];
      await expectLater(
        decodeResponses(
          Stream.value(utf8.encode(wire)),
          null,
        ).forEach(chunks.add),
        throwsA(isA<AiFailure>()),
      );
      expect(chunks.where((chunk) => chunk.usage != null), hasLength(1));
      expect(chunks.last.usage?.inputTokens, 80);
      expect(chunks.last.usage?.totalTokens, 100);
      expect(chunks.last.completed, isFalse);
    }
  });

  test("History with tool calls but no retained context synthesizes a fallback function_call", () async {
    final f = ChatGptFixture();
    await f.seed();
    final request = AiRequest(
      instructions: "",
      messages: [
        const AiMessage.user("出题"),
        AiMessage.assistant(
          "",
          calls: [
            ToolCall("call_fallback", "create_quiz", '{"kind":"numeric"}'),
          ],
        ),
        const AiMessage.tool("call_fallback", '{"ok":true}'),
      ],
      tools: [
        const AiTool(
          name: "create_quiz",
          description: "Quiz",
          parameters: {"type": "object"},
        ),
      ],
    );
    final sent = <Map<String, dynamic>>[];
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((r) {
        sent.add(Map<String, dynamic>.from(r.data as Map));
        return fixtureSse([completed()]);
      });
    final chunks = await ChatGptResponses(
      f.auth,
      client: client,
    ).start(config).complete(request, CancelToken()).toList();
    expect(chunks.last.completed, true);
    final input = sent.single["input"] as List;
    expect(input.length, 3);
    final call = input.firstWhere(
      (e) => e is Map && e["type"] == "function_call",
    ) as Map;
    expect(call["call_id"], "call_fallback");
    expect(call["name"], "create_quiz");
    expect(call["namespace"], "tixun");
    expect(call.containsKey("id"), false);
    expect(input.last, {
      "type": "function_call_output",
      "call_id": "call_fallback",
      "output": '{"ok":true}',
    });
  });

  test("Config errors keep their own message on both provider paths", () async {
    final f = ChatGptFixture();
    await f.seed();
    final badChatGpt = config.copyWith(effort: "ultra");
    expect(
      () => ChatGptResponses(f.auth).start(badChatGpt),
      throwsA(
        isA<AiFailure>().having((e) => e.message, "message", contains("思考参数")),
      ),
    );
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final badApi = (await db.config()).copyWith(
      baseUrl: "https://key@example.com",
    );
    await expectLater(
      OpenAiChatProvider()
          .start(badApi, apiKeyOverride: "test-only")
          .complete(AiRequest(instructions: "", messages: []), CancelToken())
          .toList(),
      throwsA(
        isA<AiFailure>().having(
          (e) => e.message,
          "message",
          contains("API 地址"),
        ),
      ),
    );
  });

  test("Controller creates a real interactive quiz through namespaced tools with reasoning enabled", () async {
    final f = ChatGptFixture();
    await f.seed();
    final responseClient = Dio();
    var count = 0;
    final sent = <Map<String, dynamic>>[];
    responseClient.httpClientAdapter = FixtureAdapter((r) {
      expect(r.path, "$chatGptResource/responses");
      expect(r.headers["Authorization"], "Bearer access-fixture");
      sent.add(Map<String, dynamic>.from(r.data as Map));
      count++;
      if (count == 1) {
        return fixtureSse([
          completed(
            output: [
              {
                "type": "reasoning",
                "id": "rs_search",
                "encrypted_content": "opaque-search",
                "summary": [],
              },
              {
                "type": "function_call",
                "namespace": "tixun",
                "call_id": "search_fixture",
                "name": "search_knowledge",
                "arguments": "{}",
              },
            ],
          ),
        ]);
      }
      return count == 2
          ? fixtureSse([
              completed(
                output: [
                  {
                    "type": "reasoning",
                    "id": "rs_quiz",
                    "encrypted_content": "opaque-quiz",
                    "summary": [],
                  },
                  {
                    "type": "function_call",
                    "namespace": "tixun",
                    "call_id": "quiz_fixture",
                    "name": "create_quiz",
                    "arguments": jsonEncode({
                      "kind": "single_choice",
                      "stem": "2 + 2 = ?",
                      "subject": "数学",
                      "options": {"A": "4", "B": "5"},
                      "answers": [
                        ["A"],
                      ],
                      "explanation": "2+2=4",
                    }),
                  },
                ],
              ),
            ])
          : fixtureSse([
              {
                "type": "response.output_text.delta",
                "delta": "Try the question.",
              },
              completed(),
            ]);
    });
    final dir = await Directory.systemTemp.createTemp("tixun-chatgpt");
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(dir),
      f.keys,
      RoutedChatProvider(f.auth, client: responseClient),
    );
    await c.initialize();
    final original = c.config;
    await c.saveSettings(config, null);
    await c.prepareQuickQuiz();
    expect(c.sessionConfig.thinking, true);
    await c.setTools(true);
    await c.send(c.selected!.draft);
    expect(c.error, isNull);
    expect(
      (await c.db.select(c.db.practiceQuestions).get()).single.stem,
      "2 + 2 = ?",
    );
    expect(sent.last["input"].any((p) => p["type"] == "reasoning"), true);
    expect(c.messages.any((m) => m.content.contains("opaque-quiz")), false);
    await c.restoreApiProvider();
    expect(c.config, original);
    await c.shutdown();
    await dir.delete(recursive: true);
  });

  test("Connection tests wait for terminal completion and cannot hide a late quota failure", () async {
    final f = ChatGptFixture();
    await f.seed();
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter(
        (_) => fixtureSse([
          {"type": "response.output_text.delta", "delta": "OK"},
          {
            "type": "response.failed",
            "response": {
              "error": {"code": "subscription_sharing_usage_limit_exceeded"},
            },
          },
        ]),
      );
    final root = await Directory.systemTemp.createTemp("tixun-chatgpt-connect");
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      f.keys,
      RoutedChatProvider(f.auth, client: client),
    );
    await c.initialize();
    await expectLater(
      c.testConnection(config, null),
      throwsA(isA<AiFailure>()),
    );
    expect(c.config.kind, "deepseek");
    await c.shutdown();
    await root.delete(recursive: true);
  });

  test("Cancelled inference cannot start an HTTP request", () async {
    final f = ChatGptFixture();
    await f.seed();
    var calls = 0;
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((_) {
        calls++;
        return fixtureSse([completed()]);
      });
    final cancel = CancelToken()..cancel();
    await expectLater(
      ChatGptResponses(f.auth, client: client)
          .start(config)
          .complete(AiRequest(instructions: "", messages: []), cancel)
          .drain<void>(),
      throwsA(isA<DioException>()),
    );
    expect(calls, 0);
  });
}
