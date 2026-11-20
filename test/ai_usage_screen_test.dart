import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/ai_usage_store.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/core/ui/usage_token_breakdown.dart";

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
      await tester.ensureVisible(source);
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
}
