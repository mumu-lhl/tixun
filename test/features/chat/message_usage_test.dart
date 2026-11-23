import "dart:io";

import "package:drift/drift.dart" show Value;
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

void main() {
  for (final (count, display) in [
    (999, "999"),
    (1250, "1.25K"),
    (1250000, "1.25M"),
  ]) {
    testWidgets("chat token counts use $display in message and details", (
      tester,
    ) async {
      late Directory root;
      late AppController c;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp("chat-usage");
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
          demo: true,
        );
        await c.initialize(seed: false);
        await c.newSession();
        await c.send("hello");
        c.messages[c.messages.length - 1] = c.messages.last.copyWith(
          totalTokens: Value(count),
        );
        final message = c.messages.last;
        await AiUsageStore(c.db).record(
          AiUsageCapture(
            actionId: message.id,
            sessionId: message.sessionId,
            messageId: message.id,
            providerKind: "deepseek",
            endpoint: "https://api.deepseek.com",
            model: "test-model",
            feature: "chat",
            status: "complete",
            occurredAt: DateTime.now(),
            usage: AiTokenUsage(
              inputTokens: count,
              outputTokens: 0,
              reportedTotalTokens: count,
            ),
          ),
        );
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
      scope.read(routerProvider).go("/chat");
      await tester.pumpAndSettle();
      expect(find.text("AI 学习助手"), findsNothing);
      expect(find.text("Mock · 隔离数据 · 不连接 API"), findsNothing);
      final usage = find.byKey(ValueKey("message-usage-${c.messages.last.id}"));
      await tester.ensureVisible(usage);
      expect(find.text("$display tokens"), findsOneWidget);
      await tester.tap(usage);
      await tester.pumpAndSettle();
      expect(find.text("Token 总量 · $display"), findsOneWidget);
      expect(find.text("输入 Token · $display"), findsOneWidget);
      final request = find.textContaining("输入 Token: $display");
      await tester.scrollUntilVisible(
        request,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(request, findsOneWidget);
      expect(find.textContaining("Token 总量: $display"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
