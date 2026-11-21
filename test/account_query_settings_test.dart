import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/chatgpt/auth.dart";
import "package:tixun/core/ai/provider_balance.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";

import "support/chatgpt_fixture.dart";

class _Auth extends ChatGptAuth {
  _Auth(super.keys);
  @override
  Future<List<ChatGptModel>> models() async => const [
    ChatGptModel(
      "fixture-gpt",
      "Fixture GPT",
      false,
      reasoningEfforts: ["low", "medium"],
    ),
  ];
}

class _Controller extends AppController {
  _Controller(Directory root, {super.demo = false})
    : super(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
      );

  int balanceRequests = 0;
  Future<void> pending = Future.value();
  bool fail = false;
  Dio http(ResponseBody Function() response) =>
      Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = FixtureAdapter((_) => response());
  late final _auth = _Auth(keys);
  @override
  ChatGptAuth get chatGpt => _auth;
  late final balanceClient = ProviderBalanceClient(
    client: http(() {
      balanceRequests++;
      return fixtureJson({
        "is_available": true,
        "balance_infos": [
          {
            "currency": "CNY",
            "total_balance": "42.00",
            "granted_balance": "0.00",
            "topped_up_balance": "42.00",
          },
        ],
      }, status: fail ? 500 : 200);
    }),
  );

  @override
  Future<ProviderBalance?> cachedProviderBalance(
    ProviderConfig candidate,
  ) async => balanceClient.cached(
    baseUrl: candidate.baseUrl,
    apiKey: await keys.read(providerKeyId(candidate)) ?? "",
  );
  @override
  Future<ProviderBalance> providerBalance(
    ProviderConfig candidate, {
    String? key,
    ProviderBalanceClient? client,
    bool refresh = false,
  }) {
    final result = super.providerBalance(
      candidate,
      key: key,
      client: client ?? balanceClient,
      refresh: refresh,
    );
    pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

void main() {
  for (final service in ["DeepSeek", "ChatGPT", "demo", "disconnected"]) {
    testWidgets(
      switch (service) {
        "ChatGPT" =>
          "activate a ChatGPT model, update Settings, and offer web usage",
        "DeepSeek" => "DeepSeek uses cached balance until explicit refresh",
        _ => "$service skips DeepSeek balance queries",
      },
      (tester) async {
        late Directory root;
        late _Controller c;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp("account-settings");
          c = _Controller(root, demo: service == "demo");
          await c.initialize(seed: false);
          if (service != "disconnected") {
            await c.keys.write(providerKeyId(c.config), "fixture-key");
            await c.keys.write(
              ChatGptAuth.storageKey,
              jsonEncode({
                "version": 1,
                "active": "test:user",
                "accounts": [
                  {
                    "client_id": "test",
                    "sub": "user",
                    "access_token": "fixture-token",
                    "refresh_token": "fixture-refresh",
                    "scopes": ["resource.invoke", "chatgpt.tokens.use.direct"],
                    "expires_at": DateTime.now()
                        .add(const Duration(hours: 1))
                        .toIso8601String(),
                  },
                ],
              }),
            );
          }
        });
        final scope = ProviderContainer(
          overrides: [appControllerProvider.overrideWith((_) => c)],
        );
        addTearDown(() async {
          scope.dispose();
          await c.db.close();
          await root.delete(recursive: true);
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: scope, child: const TixunApp()),
        );
        Future<void> open(String path) async {
          await tester.runAsync(() async {
            scope.read(routerProvider).go(path);
            await tester.pump();
            await c.pending;
            await tester.pumpAndSettle();
          });
          await tester.pumpAndSettle();
        }

        if (service == "demo" || service == "disconnected") {
          await open("/settings/ai");
          expect(c.balanceRequests, 0);
        } else if (service == "ChatGPT") {
          await open("/settings");
          final settings = find.byKey(const Key("settings-ai"));
          await tester.ensureVisible(settings);
          await tester.tap(settings);
          await tester.pumpAndSettle();

          Future<void> choose(String key, String label, {String? kind}) async {
            await tester.runAsync(() async {
              final field = find.byKey(Key(key));
              await tester.ensureVisible(field);
              await tester.pumpAndSettle();
              await tester.tap(field);
              await tester.pumpAndSettle();
              await tester.tap(find.widgetWithText(MenuItemButton, label));
              await tester.pumpAndSettle();
              if (kind != null) {
                for (var i = 0; i < 50 && c.config.kind != kind; i++) {
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  await tester.pump();
                }
                await tester.pumpAndSettle();
              }
            });
          }

          await choose("provider-selector", "ChatGPT 订阅");
          expect(find.text("ChatGPT 尚未启用"), findsOneWidget);
          expect(c.config.kind, "deepseek");
          await choose("chatgpt-model-selector", "Fixture GPT");
          expect(c.config.kind, "chatgpt");
          expect(find.byKey(const Key("use-chatgpt")), findsNothing);
          final vision = find.byType(SwitchListTile).first;
          await tester.runAsync(() async {
            await tester.ensureVisible(vision);
            await tester.tap(vision);
            await tester.pumpAndSettle();
          });
          await choose("chatgpt-effort-selector", "中");
          await tester.runAsync(() async {
            final saved = await c.db.config();
            expect(saved.kind, "chatgpt");
            expect(saved.model, "fixture-gpt");
            expect(saved.vision, true);
            expect(saved.thinking, true);
            expect(saved.effort, "medium");
          });
          await choose("provider-selector", "DeepSeek", kind: "deepseek");
          expect(c.config.kind, "deepseek");
          await open("/settings/chatgpt");
          expect(
            c.config.kind,
            "deepseek",
            reason: "Visiting settings does not activate a provider",
          );
          await choose("provider-selector", "DeepSeek");
          await choose("provider-selector", "ChatGPT 订阅", kind: "chatgpt");
          expect(c.config.kind, "chatgpt");
          expect(c.config.vision, true);
          expect(c.config.effort, "medium");
          await open("/settings");
          await tester.ensureVisible(settings);
          await tester.tap(settings);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key("chatgpt-quota-refresh")), findsNothing);
          const launcher = MethodChannel("plugins.flutter.io/url_launcher");
          final messenger = tester.binding.defaultBinaryMessenger;
          MethodCall? launch;
          messenger.setMockMethodCallHandler(launcher, (call) async {
            launch = call;
            return true;
          });
          addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));
          final usage = find.text("在 ChatGPT 中管理用量和授权");
          await tester.ensureVisible(usage);
          await tester.pumpAndSettle();
          await tester.tap(usage);
          await tester.pump();
          expect(launch?.method, "launch");
          expect(
            launch?.arguments["url"],
            "https://chatgpt.com/settings/usage",
          );

          expect(find.text("当前生效的 ChatGPT 模型：fixture-gpt"), findsOneWidget);
          final back = find.byType(BackButton);
          await tester.ensureVisible(back);
          await tester.pumpAndSettle();
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(scope.read(routerProvider).state.uri.path, "/settings");
          expect(find.text("ChatGPT · fixture-gpt"), findsOneWidget);
          await tester.ensureVisible(settings);
          await tester.tap(settings);
          await tester.pumpAndSettle();
          expect(find.text("当前生效的 ChatGPT 模型：fixture-gpt"), findsOneWidget);
        } else {
          const path = "/settings/ai";
          await open(path);
          expect(c.balanceRequests, 1);
          await open("/settings");
          await open(path);
          expect(c.balanceRequests, 1);
          c.fail = true;
          final refresh = find.byKey(const Key("provider-balance-refresh"));
          await tester.ensureVisible(refresh);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await tester.tap(refresh);
            await c.pending;
            await tester.pumpAndSettle();
          });
          await tester.pumpAndSettle();
          expect(c.balanceRequests, 2);
          expect(find.text("可用余额 ¥42.00"), findsOneWidget);
          expect(find.text("上次查询结果，可能已过期。"), findsOneWidget);

          // Editing a key hides the old account without querying the draft.
          final keyInput = find.byWidgetPredicate(
            (widget) => widget is TextField && widget.obscureText,
          );
          await tester.ensureVisible(keyInput);
          await tester.enterText(keyInput, "unsaved-key");
          await tester.pump();
          expect(find.text("可用余额 ¥42.00"), findsNothing);
          expect(c.balanceRequests, 2);
          await open("/settings"); // Dispose the form and its autosave timer.
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
