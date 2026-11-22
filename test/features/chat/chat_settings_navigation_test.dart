import "dart:async";
import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";

Future<(AppController, GoRouter)> openApp(
  WidgetTester tester, {
  double width = 390,
  String route = "/chat",
}) async {
  late Directory root;
  late AppController c;
  await tester.runAsync(() async {
    root = await Directory.systemTemp.createTemp("chat-settings-back");
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
      demo: true,
    );
    await c.initialize(seed: false);
    await c.newSession();
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
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: scope, child: const TixunApp()),
  );
  final router = scope.read(routerProvider);
  router.go(route);
  await tester.pumpAndSettle();
  return (c, router);
}

Future<void> openFromChat(
  WidgetTester tester,
  String destination, {
  double width = 390,
}) async {
  if (destination == "ai") {
    if (width < 700) {
      await tester.tap(find.byKey(const Key("chat-more")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("模型设置"));
    } else {
      await tester.tap(find.byTooltip("模型设置"));
    }
  } else {
    await tester.tap(find.byKey(const Key("reasoning-menu")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("管理提示词"));
  }
  await tester.pumpAndSettle();
}

Future<void> pageBack(WidgetTester tester, String destination) async {
  final button = destination == "ai"
      ? find.byType(BackButton)
      : find.byKey(const Key("prompt-manager-back"));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("mobile settings subpages hide and restore bottom navigation", (
    tester,
  ) async {
    final (_, router) = await openApp(tester, route: "/settings");
    final bar = find.byKey(const ValueKey("main-navigation-bar"));
    expect(bar, findsOneWidget);
    unawaited(router.push("/settings/ai"));
    await tester.pumpAndSettle();
    expect(bar, findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    expect(bar, findsOneWidget);
  });

  testWidgets(
    "small dashboard groups secondary actions below the filled action",
    (tester) async {
      await openApp(tester, route: "/study", width: 320);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final primary = find.byKey(const Key("today-review"));
      final schedule = find.byKey(const Key("today-review-schedule"));
      final diagnosis = find.byKey(const Key("today-learning-insights"));
      await tester.ensureVisible(diagnosis);
      await tester.pumpAndSettle();
      expect(tester.getCenter(schedule).dy, tester.getCenter(diagnosis).dy);
      expect(
        tester.getBottomLeft(primary).dy,
        lessThan(tester.getTopLeft(diagnosis).dy),
      );
      expect(
        tester.getSize(primary).width,
        greaterThan(tester.getSize(diagnosis).width),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "prompt groups are collapsible and search opens matching language entries",
    (tester) async {
      final (controller, _) = await openApp(tester, route: "/settings/prompts");
      final group = find.byKey(const PageStorageKey("prompt-group-language"));
      final row = find.byKey(const Key("prompt-language_explanation"));
      final search = find.byKey(const Key("prompt-search"));
      expect(find.byKey(const Key("prompt-global")), findsOneWidget);
      expect(row, findsNothing);
      final header = find.descendant(of: group, matching: find.text("语言学习"));
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await tester.tap(header.hitTestable());
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(find.byKey(const Key("prompt-quick-actions")), findsOneWidget);
      await tester.ensureVisible(search);
      await tester.enterText(search, "句子原位解释");
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("prompt-global")), findsNothing);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      final field = find.byKey(const Key("prompt-content"));
      await tester.enterText(field, "突出句子中的固定搭配。");
      final preview = find.text("预览效果");
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      await tester.tap(preview);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final requestContract = find.descendant(
        of: dialog,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data?.contains("at most three short sentences") ?? false),
        ),
      );
      expect(requestContract, findsOneWidget);
      final editableSection = find.descendant(
        of: dialog,
        matching: find.byKey(const Key("prompt-preview-language_explanation")),
      );
      expect(
        find.descendant(
          of: editableSection,
          matching: find.text("突出句子中的固定搭配。"),
        ),
        findsOneWidget,
      );
      final close = find.descendant(
        of: dialog,
        matching: find.byType(TextButton),
      );
      await tester.tap(close);
      await tester.pumpAndSettle();
      final save = find.byKey(const Key("save-prompt"));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(save);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(controller.prompts.text("language_explanation"), "突出句子中的固定搭配。");
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("language prompt group opens the original quick-task manager", (
    tester,
  ) async {
    await openApp(tester, route: "/settings/prompts");
    final search = find.byKey(const Key("prompt-search"));
    await tester.enterText(search, "语言速查");
    await tester.pumpAndSettle();
    final link = find.byKey(const Key("prompt-quick-actions"));
    await tester.tap(link);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 70));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(find.byKey(const ValueKey("language_express")), findsOneWidget);
    expect(find.byKey(const ValueKey("language_meaning")), findsOneWidget);
    expect(find.byKey(const ValueKey("language_usage")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Pairwise coverage: both layouts × destinations, both destinations ×
  // back methods, and both layouts × back methods. Nested/deep-link/editor
  // regressions below remain independent.
  for (final (width, destination, systemBack) in [
    (390.0, "ai", false),
    (1200.0, "ai", true),
    (390.0, "prompts", true),
    (1200.0, "prompts", false),
  ]) {
    testWidgets(
      'chat → $destination → ${systemBack ? 'system' : 'page'} back at $width',
      (tester) async {
        final (c, router) = await openApp(tester, width: width);
        final sessionId = c.selected!.id;
        await openFromChat(tester, destination, width: width);
        expect(router.state.uri.path, "/settings/$destination");
        if (systemBack) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await pageBack(tester, destination);
        }
        expect(router.state.uri.path, "/chat");
        expect(find.byKey(const Key("chat-input")), findsOneWidget);
        expect(c.selected!.id, sessionId);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final destination in ["ai", "prompts"]) {
    for (final deepLink in [false, true]) {
      testWidgets(
        '$destination entered from ${deepLink ? 'deep link' : 'settings'} returns to settings',
        (tester) async {
          final (_, router) = await openApp(
            tester,
            route: deepLink ? "/settings/$destination" : "/settings",
          );
          if (!deepLink) {
            unawaited(router.push("/settings/$destination"));
            await tester.pumpAndSettle();
          }
          await pageBack(tester, destination);
          expect(router.state.uri.path, "/settings");
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final systemBack in [false, true]) {
    testWidgets(
      'switching to ChatGPT keeps one model page and ${systemBack ? 'system' : 'page'} back returns to chat',
      (tester) async {
        final (_, router) = await openApp(tester);
        await openFromChat(tester, "ai");
        final picker = find.byKey(const Key("provider-selector"));
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.text("ChatGPT 订阅").last);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, "/settings/ai");
        expect(find.byKey(const Key("api-key")), findsNothing);
        expect(find.byKey(const Key("provider-selector")), findsOneWidget);
        if (systemBack) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await pageBack(tester, "ai");
        }
        expect(router.state.uri.path, "/chat");
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets("model dropdown restores the saved API endpoint and model", (
    tester,
  ) async {
    final (controller, router) = await openApp(tester, route: "/settings");
    const endpoint = "https://example.test/v1";
    await tester.runAsync(() async {
      await controller.saveSettings(
        controller.config.copyWith(
          kind: "compatible",
          baseUrl: endpoint,
          model: "saved-model",
        ),
        null,
      );
      await controller.saveSettings(
        controller.config.copyWith(
          kind: "chatgpt",
          baseUrl: "https://api.openai.com/v1",
          model: "gpt-5.4",
        ),
        null,
      );
    });
    unawaited(router.push("/settings/ai"));
    await tester.pumpAndSettle();
    final picker = find.byKey(const Key("provider-selector"));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text("OpenAI-compatible").last);
      for (var i = 0; i < 20 && controller.config.kind != "compatible"; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(router.state.uri.path, "/settings/ai");
    expect(controller.config.kind, "compatible");
    expect(controller.config.baseUrl, endpoint);
    expect(controller.config.model, "saved-model");
    expect(find.byKey(const Key("api-key")), findsOneWidget);
  });

  for (final action in ["clean", "discard", "save"]) {
    testWidgets("prompt editor $action preserves manager and chat origin", (
      tester,
    ) async {
      final (c, router) = await openApp(tester);
      await openFromChat(tester, "prompts");
      final prompt = find.byKey(const Key("prompt-global"));
      await tester.ensureVisible(prompt);
      await tester.tap(prompt);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, "/settings/prompts/global");
      final original = c.prompts.text("global");
      if (action != "clean") {
        await tester.enterText(
          find.byKey(const Key("prompt-content")),
          "临时导航测试提示词",
        );
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      if (action != "clean") {
        expect(find.text("提示词尚未保存"), findsOneWidget);
        await tester.tap(find.text("取消"));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, "/settings/prompts/global");
        await tester.tap(find.byKey(const Key("prompt-back")));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => tester.tap(find.text(action == "save" ? "保存提示词" : "放弃修改").last),
        );
        await tester.pumpAndSettle();
      }
      expect(router.state.uri.path, "/settings/prompts");
      expect(
        c.prompts.text("global"),
        action == "save" ? "临时导航测试提示词" : original,
      );
      await pageBack(tester, "prompts");
      expect(router.state.uri.path, "/chat");
      expect(tester.takeException(), isNull);
    });
  }
}
