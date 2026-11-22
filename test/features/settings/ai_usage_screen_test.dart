import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/ai_usage_store.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/app_strings.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/core/ui/usage_token_breakdown.dart";
import "package:tixun/features/settings/ai_usage_screen.dart";

void main() {
  testWidgets("usage screen shows summary, trend, and request details", (
    tester,
  ) async {
    late Directory root;
    late AppController controller;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp("tixun-ai-usage-screen");
      controller = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await controller.initialize(seed: false);
      await controller.newSession();
      await controller.send("Explain the example");
      await AiUsageStore(controller.db).record(
        AiUsageCapture(
          actionId: controller.messages.last.id,
          sessionId: controller.selected!.id,
          messageId: controller.messages.last.id,
          providerKind: "deepseek",
          endpoint: "https://api.deepseek.com",
          model: "deepseek-flash",
          feature: "chat",
          status: "complete",
          occurredAt: DateTime.now(),
          durationMs: 1200,
          tokenBreakdownJson:
              '{"encoding":"cl100k_base","counts":{"system":25,"user":75}}',
          usage: const AiTokenUsage(
            inputTokens: 1000,
            cachedInputTokens: 200,
            outputTokens: 300,
            reasoningTokens: 50,
            reportedTotalTokens: 1300,
          ),
        ),
      );
    });
    final scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((_) => controller)],
    );
    addTearDown(() async {
      scope.dispose();
      await controller.db.close();
      await root.delete(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    scope.read(routerProvider).go("/settings/ai-usage");
    await tester.pumpAndSettle();

    expect(find.text("AI 用量"), findsOneWidget);
    expect(find.byKey(const Key("ai-usage-summary")), findsOneWidget);
    expect(find.text("20.0%"), findsOneWidget);
    expect(find.textContaining("1.3K"), findsWidgets);
    await tester.scrollUntilVisible(find.text("Token 类型占比"), 250);
    expect(find.text("15.4% · 200 (200)"), findsOneWidget);
    expect(find.text("61.5% · 800 (800)"), findsOneWidget);
    expect(find.text("3.8% · 50 (50)"), findsOneWidget);
    expect(find.textContaining("分别显示缓存命中和思考用量"), findsOneWidget);
    await tester.scrollUntilVisible(find.text("本地文本 Token 分类"), 250);
    expect(find.text("25.0% · 25 (25)"), findsOneWidget);
    expect(find.text("75.0% · 75 (75)"), findsOneWidget);
    await tester.scrollUntilVisible(find.text("每日 Token"), 250);
    expect(find.text("每日 Token"), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text("按功能统计"), 250);
    expect(find.text("按功能统计"), findsOneWidget);
    await tester.scrollUntilVisible(find.text("请求明细"), 250);
    expect(find.text("请求明细"), findsOneWidget);
    expect(find.byKey(const Key("add-ai-model-price")), findsOneWidget);
    expect(find.textContaining("离峰 -50%"), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key("add-ai-model-price")));
    await tester.tap(find.byKey(const Key("add-ai-model-price")));
    await tester.pumpAndSettle();
    expect(find.text("离峰折扣（%）"), findsOneWidget);
    expect(find.textContaining("01:00–04:00"), findsWidgets);
    await tester.tap(find.text("取消"));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("请求明细"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("请求明细"));
    await tester.pumpAndSettle();
    expect(find.textContaining("1.2 s"), findsOneWidget);
    await tester.runAsync(() async {
      await AiUsageStore(controller.db).record(
        AiUsageCapture(
          actionId: "lookup",
          providerKind: "deepseek",
          endpoint: "https://api.deepseek.com",
          model: "language-model",
          feature: "language_quick_lookup",
          status: "complete",
          occurredAt: DateTime.now(),
          usage: const AiTokenUsage(
            inputTokens: 500,
            outputTokens: 100,
            reasoningTokens: 20,
            reportedTotalTokens: 600,
          ),
        ),
      );
    });
    final source = find.byKey(const Key("ai-usage-scope"));
    await tester.scrollUntilVisible(source, -250);
    Future<void> selectScope(String label) async {
      await Scrollable.ensureVisible(tester.element(source), alignment: .2);
      await tester.pumpAndSettle();
      await tester.tap(source);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await selectScope("语言学习");
    expect(find.textContaining("1.3K"), findsNothing);
    expect(find.text("600"), findsWidgets);
    await selectScope("会话");
    expect(find.textContaining("1.3K"), findsWidgets);
    await selectScope("全部来源");
    expect(find.textContaining("1.9K"), findsWidgets);

    scope.read(routerProvider).go("/chat");
    await tester.pumpAndSettle();
    final messageUsage = find.byKey(
      ValueKey("message-usage-${controller.messages.last.id}"),
    );
    await tester.ensureVisible(messageUsage);
    await tester.tap(messageUsage);
    await tester.pumpAndSettle();
    expect(find.byType(UsageTokenBreakdown), findsOneWidget);
    expect(find.text("思考 Token · 50"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Custom usage starts as one day and supports an optional end", (
    t,
  ) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - 1);
    final controller = await t.runAsync(() async {
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(await Directory.systemTemp.createTemp("tixun-usage")),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await c.initialize(seed: false);
      for (final (day, hour, minute, second) in [
        (9, 23, 59, 59),
        (10, 0, 0, 0),
        (10, 23, 59, 59),
        (11, 23, 59, 59),
        (12, 0, 0, 0),
      ]) {
        await AiUsageStore(c.db).record(
          AiUsageCapture(
            actionId: "usage-$day-$hour",
            providerKind: "compatible",
            endpoint: "https://api.test/v1",
            model: "mock",
            feature: "chat",
            status: "complete",
            occurredAt: DateTime(
              month.year,
              month.month,
              day,
              hour,
              minute,
              second,
            ),
          ),
        );
      }
      return c;
    });
    addTearDown(() async {
      await controller!.db.close();
      await controller.files.root.delete(recursive: true);
    });
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1440, 900);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller!)],
        child: const MaterialApp(home: AiUsageScreen()),
      ),
    );
    await t.pumpAndSettle();
    final start = find.byKey(const Key("ai-usage-custom-range"));
    final end = find.byKey(const Key("ai-usage-end-date"));
    final scope = find.byKey(const Key("ai-usage-scope"));
    final presets = find.byType(SegmentedButton<String>);
    final l10n = t.element(start).l10n;
    final desktopScope = t.getRect(scope);
    final desktopPresets = t.getRect(presets);
    expect(desktopPresets.left, greaterThan(desktopScope.right));
    final desktopCustom = t.getRect(start);
    expect(desktopCustom.left, greaterThan(desktopPresets.right));
    expect(desktopCustom.center.dy, closeTo(desktopPresets.center.dy, 1));

    t.view.physicalSize = const Size(360, 800);
    await t.pumpAndSettle();
    expect(t.getTopLeft(presets).dy, greaterThan(t.getBottomLeft(scope).dy));
    expect(t.getTopLeft(start).dy, greaterThan(t.getBottomLeft(presets).dy));
    expect(end, findsNothing);

    Future<void> tap(Finder target) async {
      await t.tap(target);
      await t.pumpAndSettle();
    }

    final dialog = find.byType(DatePickerDialog);
    Future<void> choose(Finder button, int day) async {
      await tap(button);
      final material = MaterialLocalizations.of(t.element(dialog));
      await tap(find.byTooltip(material.inputDateModeButtonLabel));
      await t.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        material.formatCompactDate(DateTime(month.year, month.month, day)),
      );
      await tap(find.text(material.okButtonLabel));
      expect(dialog, findsNothing);
    }

    void expectRequests(int count) {
      final card = find.ancestor(
        of: find.text(l10n.requestCount),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: card, matching: find.text("$count")),
        findsOneWidget,
      );
    }

    await choose(start, 10);
    expect(find.text(l10n.usageAddEndDate), findsOneWidget);
    expectRequests(2);
    await tap(end);
    await tap(
      find.text(MaterialLocalizations.of(t.element(dialog)).cancelButtonLabel),
    );
    expectRequests(2);
    await choose(end, 11);
    expectRequests(3);
    await tap(find.byTooltip(l10n.usageRemoveEndDate));
    expectRequests(2);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
