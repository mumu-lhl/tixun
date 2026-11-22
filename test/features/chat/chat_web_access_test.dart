import "dart:io";

import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/app/preferences.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/chatgpt/auth.dart";
import "package:tixun/core/ai/chatgpt/responses.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/chat/chat_context_store.dart";

import "../../support/chatgpt_fixture.dart";

const _page = "https://example.org/lesson";
const _read = {
  "index": 0,
  "id": "srvtoolu_read",
  "type": "deepseek_read_url",
  "kind": "read_link",
  "action": {"type": "read_link", "url": _page},
  "status": "completed",
  "page": {"url": _page, "title": "A lesson"},
  "signature": "signed-page-fixture",
};
const _steps = [
  {
    "index": 0,
    "reasoning_content": "Read the page first.",
    "calls": [_read],
  },
];

Map<String, dynamic> _deepSeek(
  Map<String, Object> delta, {
  String? finish,
  Map<String, Object>? serverEvent,
}) => {
  "choices": [
    {
      "delta": delta,
      "finish_reason": ?finish,
      "server_tool_event": ?serverEvent,
    },
  ],
};

Iterable<dynamic> _toolTypes(Map body) =>
    (body["tools"] as List? ?? []).map((t) => (t as Map)["type"]);

class _WebUiProvider implements ChatProvider {
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        yield const AiChunk(text: "Lesson summary.");
        yield AiChunk(
          completed: true,
          webActivity: request.webAccess == WebAccess.off
              ? null
              : WebActivity(
                  operations: [
                    WebOperation(
                      WebAction.search,
                      queries: ["official lesson"],
                    ),
                    WebOperation(WebAction.read, page: {"url": _page}),
                  ],
                  sources: [
                    {"url": _page, "title": "A lesson"},
                  ],
                ),
        );
      });
}

void main() {
  testWidgets("chat override and expandable web details on a narrow screen", (
    tester,
  ) async {
    late AppController c;
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp("tixun-web-ui");
      c = AppController(
        AppDatabase.memory(),
        AttachmentStore(directory),
        MemoryKeyStore(),
        _WebUiProvider(),
      );
      await c.initialize(seed: false);
      await c.newSession();
    });
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((_) => c)],
    );
    addTearDown(() async {
      container.dispose();
      await c.db.close();
      await c.files.root.delete(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TixunApp()),
    );
    container.read(routerProvider).go("/chat");
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("chat-more")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("chat-web-settings")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("chat-web-on")));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await c.preferences.whenIdle;
      expect(c.sessionWebOverride, true);
      await c.send("Search and read a lesson");
    });
    await tester.pumpAndSettle();
    final panel = find.byKey(
      PageStorageKey("web-activity-${c.messages.last.id}"),
    );
    await tester.runAsync(() async {
      await tester.pump();
      await c.db.select(c.db.chatContextEvents).get();
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(panel);
    expect(find.text("official lesson"), findsNothing);
    await tester.tap(panel);
    await tester.pumpAndSettle();
    expect(find.text("official lesson"), findsOneWidget);
    expect(find.text(_page), findsOneWidget);
    expect(find.text("A lesson"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test("DeepSeek opts in per chat, replays signed pages, and stops replay when disabled", () async {
    final db = AppDatabase.memory();
    final files = await Directory.systemTemp.createTemp("tixun-web-tests");
    final keys = MemoryKeyStore();
    final requests = <Map>[];
    final dio = Dio()
      ..httpClientAdapter = FixtureAdapter((request) {
        expect(request.path, "https://api.deepseek.com/chat/completions");
        final body = request.data as Map;
        requests.add(body);
        return fixtureSse([
          if (requests.length == 2) ...[
            _deepSeek({"reasoning_content": "Read the page first."}),
            _deepSeek(
              {},
              serverEvent: {"type": "step_reasoning_done", "step": 0},
            ),
            _deepSeek(
              {},
              serverEvent: {"type": "call_started", "step": 0, "call": _read},
            ),
            _deepSeek({"reasoning_content": "Now answer."}),
          ],
          _deepSeek({"content": "Lesson summary."}),
          _deepSeek(
            requests.length == 2
                ? {
                    "server_tool_calls": _steps,
                    "annotations": [
                      {
                        "type": "url_citation",
                        "url_citation": {"url": _page, "title": "A lesson"},
                      },
                      {
                        "type": "url_citation",
                        "url_citation": {"url": "file:///tmp/private"},
                      },
                    ],
                  }
                : {},
            finish: "stop",
          ),
        ]);
      });
    final c = AppController(
      db,
      AttachmentStore(files),
      keys,
      OpenAiChatProvider(client: dio, keys: keys),
    );
    addTearDown(() async {
      await c.shutdown();
      await files.delete(recursive: true);
      dio.close();
    });
    await c.initialize(seed: false);
    await c.saveSettings(c.config.copyWith(thinking: true), "fixture-key");
    await c.newSession();
    final first = c.selected!;
    expect(c.sessionWebEnabled, false);
    await c.send("Hello");
    expect(_toolTypes(requests.first), isNot(contains("deepseek_web_search")));

    await c.setSessionWebEnabled(true);
    final progress = <WebAction>{};
    c.addListener(() {
      if (c.activeWebAction case final action?) progress.add(action);
    });
    await c.send("Summarize $_page");
    expect(c.messages.last.status, "complete");
    expect(c.messages.last.reasoningContent, "Now answer.");
    expect(progress, {WebAction.read});
    expect(c.activeWebAction, isNull);
    final activity = (await ChatContextStore(
      db,
    ).webActivity(c.messages.last.id)).single;
    expect(activity.operations.single.page!.url.toString(), _page);
    expect(activity.sources.map((s) => s.url.toString()), [_page]);
    expect(
      activity.toJson().toString(),
      isNot(contains("signed-page-fixture")),
    );
    expect(
      _toolTypes(requests[1]),
      containsAll(["deepseek_read_url", "function"]),
    );
    expect(_toolTypes(requests[1]), isNot(contains("deepseek_web_search")));

    await c.send("Explain the first sentence");
    expect(_toolTypes(requests[2]), contains("deepseek_web_search"));
    final sent = (requests[2]["messages"] as List).cast<Map>();
    expect(
      sent.singleWhere(
        (m) => m.containsKey("server_tool_calls"),
      )["server_tool_calls"],
      _steps,
    );

    await c.preferences.setAiWebEnabled(true);
    await c.setSessionWebEnabled(false);
    await c.send("No more web");
    expect(_toolTypes(requests[3]), isNot(anyElement(startsWith("deepseek_"))));
    expect(
      (requests[3]["messages"] as List).cast<Map>(),
      isNot(anyElement(contains("server_tool_calls"))),
    );

    final reloaded = AppPreferences(db, keys, demo: false);
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.aiWebEnabled, true);
    await c.newSession();
    expect(c.sessionWebEnabled, true);
    await c.selectSession(first);
    expect(c.sessionWebEnabled, false);
    await c.setSessionWebEnabled(null);
    expect(c.sessionWebEnabled, true);
  });

  test(
    "DeepSeek web tools are not sent to Pro or compatible endpoints",
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final config = await db.config();
      final request = AiRequest(
        instructions: "",
        messages: [const AiMessage.user("Search the web")],
        webAccess: WebAccess.automatic,
      );
      expect(_toolTypes(encodeCompletion(config, request)), [
        "deepseek_web_search",
        "deepseek_read_url",
      ]);
      for (final unsupported in [
        config.copyWith(model: "deepseek-v4-pro", vision: false),
        config.copyWith(baseUrl: "https://proxy.example.org/v1"),
        config.copyWith(kind: "compatible"),
      ]) {
        expect(_toolTypes(encodeCompletion(unsupported, request)), isEmpty);
      }
    },
  );

  test("ChatGPT subscription uses hosted search/open without turning them into local calls", () async {
    final fixture = ChatGptFixture();
    await fixture.seed();
    final requests = <Map>[];
    const search = {
      "type": "web_search_call",
      "id": "ws_search",
      "status": "completed",
      "action": {
        "type": "search",
        "query": "official lesson",
        "sources": [
          {"url": _page},
        ],
      },
    };
    const open = {
      "type": "web_search_call",
      "id": "ws_open",
      "status": "completed",
      "action": {"type": "open_page", "url": _page},
    };
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((r) {
        expect(r.path, "$chatGptResource/responses");
        expect(r.headers["Authorization"], "Bearer access-fixture");
        requests.add(r.data as Map);
        return fixtureSse(
          requests.length == 1
              ? [
                  {"type": "response.output_item.added", "item": search},
                  {"type": "response.output_item.added", "item": open},
                  completed(
                    output: [
                      search,
                      open,
                      {
                        "type": "message",
                        "content": [
                          {
                            "type": "output_text",
                            "text": "Found a page.",
                            "annotations": [
                              {
                                "type": "url_citation",
                                "url": _page,
                                "title": "A lesson",
                              },
                            ],
                          },
                        ],
                      },
                      {
                        "type": "function_call",
                        "namespace": "tixun",
                        "call_id": "local_call",
                        "name": "fixture_tool",
                        "arguments": "{}",
                      },
                    ],
                  ),
                ]
              : [completed()],
        );
      });
    addTearDown(client.close);
    const config = ProviderConfig(
      id: 1,
      kind: "chatgpt",
      baseUrl: chatGptResource,
      model: "gpt-6-luna",
      vision: false,
      thinking: false,
      supportsThinking: true,
      supportsTools: true,
      effort: "high",
    );
    final conversation = ChatGptResponses(
      fixture.auth,
      client: client,
    ).start(config);
    final request = AiRequest(
      instructions: "",
      messages: [const AiMessage.user("Read $_page")],
      tools: [
        const AiTool(name: "fixture_tool", description: "", parameters: {}),
      ],
      webAccess: WebAccess.readLink,
    );
    final chunks = await conversation.complete(request, CancelToken()).toList();
    expect(_toolTypes(requests.first), ["web_search", "namespace"]);
    expect(
      requests.first["include"],
      contains("web_search_call.action.sources"),
    );
    expect(requests.first["tool_choice"], isNot("required"));
    expect(chunks.map((c) => c.webAction).nonNulls, [
      WebAction.search,
      WebAction.read,
    ]);
    final terminal = chunks.last;
    expect(terminal.calls.single.name, "fixture_tool");
    expect(terminal.webActivity!.operations.first.queries, ["official lesson"]);
    expect(terminal.webActivity!.operations.last.page!.url.toString(), _page);
    expect(terminal.webActivity!.sources.single.title, "A lesson");

    await conversation
        .complete(
          request.copyWith(
            messages: [
              ...request.messages,
              AiMessage.assistant("Found a page.", calls: terminal.calls),
              const AiMessage.tool("local_call", "{}"),
            ],
          ),
          CancelToken(),
        )
        .drain<void>();
    expect(requests[1]["input"], containsAll([search, open]));
    await conversation
        .complete(request.copyWith(webAccess: WebAccess.off), CancelToken())
        .drain<void>();
    expect(_toolTypes(requests.last), ["namespace"]);
  });
}
