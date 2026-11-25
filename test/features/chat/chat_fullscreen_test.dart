import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/ai/study_tools.dart";
import "package:go_router/go_router.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/features/chat/chat_screen.dart";
import "package:tixun/features/visual/visual_markdown.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";

void main() {
  late AppController c;
  late Directory root;
  late ProviderContainer scope;
  late GoRouter router;
  setUp(() async {
    root = await Directory.systemTemp.createTemp("chat-fullscreen");
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    await c.initialize();
    await c.newSession();
    router = GoRouter(
      initialLocation: "/knowledge",
      routes: [
        ShellRoute(
          builder: (ctx, state, child) =>
              AppShell(path: state.uri.path, child: child),
          routes: [
            GoRoute(path: "/study", builder: (_, _) => const SizedBox()),
            GoRoute(path: "/knowledge", builder: (_, _) => const SizedBox()),
            GoRoute(path: "/chat", builder: (_, _) => const ChatScreen()),
          ],
        ),
      ],
    );
    scope = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith((ref) => c),
        routerProvider.overrideWithValue(router),
      ],
    );
  });
  tearDown(() async {
    scope.dispose();
    router.dispose();
    c.dispose();
    await c.db.close();
    await root.delete(recursive: true);
  });
  testWidgets("Dragging a user message scrolls the phone conversation", (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final message = List.filled(24, "请讲解二次函数的顶点公式。").join("\n");
    await t.runAsync(() => c.send(message));
    router.go("/chat");
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    final list = find.byKey(PageStorageKey("messages-${c.selected!.id}"));
    final position = t.widget<ListView>(list).controller!.position;
    for (final delta in [-100.0, 100.0]) {
      position.jumpTo(position.maxScrollExtent / 2);
      await t.pumpAndSettle();
      final visible = t.getRect(find.text(message)).intersect(t.getRect(list));
      expect(visible.height, greaterThan(100));
      final before = position.pixels;
      await t.dragFrom(visible.center, Offset(0, delta));
      await t.pumpAndSettle();
      expect((before - position.pixels) * delta, greaterThan(0));
    }
    await t.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets("Knowledge branch opens with a draft and toast at $width", (
      t,
    ) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = width < 600 ? 1.25 : 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.runAsync(() => c.send("请解释二次函数"));
      await t.runAsync(() => c.draft("原对话草稿"));
      final originalId = c.selected!.id;
      final source = c.messages.last;
      router.go("/chat");
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip(c.l10n.saveLearningMaterial).last);
      await t.pumpAndSettle();
      await t.tap(find.text(c.l10n.organizeAsKnowledgeWithAI));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key("start-ai-study-writing")));

      final toast = find.text(c.l10n.studyWritingBranchReady);
      for (var i = 0; i < 100 && toast.evaluate().isEmpty; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(toast, findsOneWidget);
      expect(c.selected!.id, isNot(originalId));
      expect(c.messages.last.content, source.content);
      expect(c.busy, isFalse);
      expect(
        t
            .widget<TextField>(find.byKey(const Key("chat-input")))
            .controller!
            .text,
        contains(c.l10n.organizeForkedContext),
      );
      expect(
        c.allSessions.singleWhere((s) => s.id == originalId).draft,
        "原对话草稿",
      );
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(toast, findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets("A photo can be added after typing on a narrow phone", (t) async {
    t.view.physicalSize = const Size(320, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    router.go("/chat");
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key("chat-input")), "请看看这道题");
    await t.pumpAndSettle();
    expect(find.byKey(const Key("send-message")), findsOneWidget);
    await t.tap(find.byKey(const Key("chat-add-photo")));
    await t.pumpAndSettle();
    expect(find.text("选择图片文件"), findsOneWidget);
    expect(
      t.widget<TextField>(find.byKey(const Key("chat-input"))).controller!.text,
      "请看看这道题",
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets("Material tools support individual categories and all-on/off", (
    t,
  ) async {
    router.go("/chat");
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip("开启本会话资料工具"));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key("study-tools-knowledge")));
    await t.tap(find.text("保存"));
    await t.pumpAndSettle();
    expect(c.studyToolCategories, {StudyToolCategory.knowledge});
    expect(c.selected!.toolsEnabled, isTrue);
    await t.tap(find.byTooltip("管理本会话资料工具"));
    await t.pumpAndSettle();
    await t.tap(find.text("全部启用"));
    await t.pumpAndSettle();
    expect(c.studyToolCategories, allStudyToolCategories);
    await t.tap(find.byTooltip("管理本会话资料工具"));
    await t.pumpAndSettle();
    await t.tap(find.text("关闭全部"));
    await t.pumpAndSettle();
    expect(c.selected!.toolsEnabled, isFalse);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  testWidgets("Externally sent drafts clear without losing new typing", (
    t,
  ) async {
    Future<void> pumpUntil(bool Function() ready) async {
      for (var i = 0; i < 250 && !ready(); i++) {
        await t.pump(const Duration(milliseconds: 20));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(ready(), isTrue);
    }

    await t.runAsync(() => c.draft("整理这份知识"));
    router.go("/chat");
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    final input = find.byKey(const Key("chat-input"));
    expect(t.widget<TextField>(input).controller!.text, "整理这份知识");
    bool sent = false;
    await t.runAsync(() async {
      unawaited(c.send("整理这份知识").then((_) => sent = true));
    });
    await pumpUntil(() => sent);
    await t.pumpAndSettle();
    expect(t.widget<TextField>(input).controller!.text, isEmpty);
    await t.enterText(input, "第二个问题");
    sent = false;
    await t.runAsync(() async {
      unawaited(c.send("第二个问题").then((_) => sent = true));
    });
    await pumpUntil(() => c.messages.any((m) => m.content == "第二个问题"));
    expect(sent, isFalse);
    await t.enterText(input, "还没发出的新问题");
    await pumpUntil(() => sent);
    await t.pumpAndSettle();
    expect(t.widget<TextField>(input).controller!.text, "还没发出的新问题");
    expect(c.selected!.draft, "还没发出的新问题");
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  testWidgets("Return-to-bottom appears only when reading history at rest", (
    t,
  ) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await c.draft("历史会话");
    final session = c.selected!;
    for (var i = 0; i < 35; i++) {
      await c.db
          .into(c.db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: "history-$i",
              sessionId: session.id,
              role: i.isEven ? "user" : "assistant",
              // Public figures may be attached without accompanying prose.
              // Cover that stable state instead of relying on a fleeting
              // empty assistant body during a live stream.
              content: i == 33 ? "" : "第 $i 条学习记录。\n解释知识与独立尝试。\n记录这一轮的学习结果。",
              createdAt: DateTime(2026, 11, 12, 10, i),
            ),
          );
    }
    await c.selectSession(session);
    router.go("/chat");
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    final bottom = find.byKey(const Key("chat-scroll-bottom"));
    final messages = find.byKey(PageStorageKey("messages-${session.id}"));
    expect(bottom, findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is VisualMarkdown && widget.data.isEmpty,
      ),
      findsOneWidget,
    );
    final drag = await t.startGesture(t.getCenter(messages));
    await drag.moveBy(const Offset(0, 20));
    await t.pump();
    await drag.moveBy(const Offset(0, 280));
    await t.pump();
    expect(
      bottom,
      findsNothing,
      reason: "The shortcut must not cover an active scroll",
    );
    await drag.up();
    await t.pumpAndSettle();
    expect(bottom, findsOneWidget);
    await t.tap(bottom);
    await t.pumpAndSettle();
    expect(bottom, findsNothing);
    expect(find.textContaining("第 34 条学习记录。"), findsOneWidget);
    await t.enterText(
      find.byKey(const Key("chat-input")),
      "长问题第一行\n第二行\n第三行\n第四行",
    );
    await t.pumpAndSettle();
    expect(find.textContaining("第 34 条学习记录。").hitTestable(), findsOneWidget);
    expect(bottom, findsNothing);
    t.view.physicalSize = const Size(1280, 900);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  testWidgets(
    "Phone Chat fills the screen and returns to its originating tab",
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await t.tap(find.byKey(const Key("nav-1")));
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        t.getRect(find.byKey(const Key("chat-input"))).bottom,
        greaterThan(770),
      );
      await t.tap(find.byKey(const Key("chat-back")));
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, "/knowledge");
      router.go("/chat");
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key("chat-back")));
      await t.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, "/study");
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );
  testWidgets("fullscreen Markdown editor applies and saves the chat draft", (
    t,
  ) async {
    await c.draft("原草稿");
    router.go("/chat");
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key("chat-markdown-fullscreen")));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key("markdown-source")), "## 新问题");
    await t.tap(find.byKey(const Key("markdown-done")));
    await t.pumpAndSettle();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byKey(const Key("chat-input"))).controller!.text,
      "## 新问题",
    );
    expect(c.selected!.draft, "## 新问题");
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
}
