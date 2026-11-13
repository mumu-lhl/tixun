import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/ai_usage_store.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

void main() {
  testWidgets('usage screen shows summary, trend, and request details', (
    tester,
  ) async {
    late Directory root;
    late AppController controller;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('tixun-ai-usage-screen');
      controller = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await controller.initialize(seed: false);
      await AiUsageStore(controller.db).record(
        AiUsageCapture(
          actionId: 'action-1',
          providerKind: 'deepseek',
          endpoint: 'https://api.deepseek.com',
          model: 'deepseek-flash',
          feature: 'chat',
          status: 'complete',
          occurredAt: DateTime.now(),
          durationMs: 1200,
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
    scope.read(routerProvider).go('/settings/ai-usage');
    await tester.pumpAndSettle();

    expect(find.text('AI 用量'), findsOneWidget);
    expect(find.byKey(const Key('ai-usage-summary')), findsOneWidget);
    expect(find.text('每日 Token'), findsOneWidget);
    expect(find.text('20.0%'), findsOneWidget);
    expect(find.textContaining('1,300'), findsWidgets);
    expect(tester.takeException(), isNull);

    // The breakdown, prices, and details are below the fold on a phone.
    await tester.scrollUntilVisible(find.text('按功能统计'), 250);
    expect(find.text('按功能统计'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('请求明细'), 250);
    expect(find.text('请求明细'), findsOneWidget);
    expect(find.byKey(const Key('add-ai-model-price')), findsOneWidget);
    expect(find.textContaining('离峰 -50%'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('add-ai-model-price')));
    await tester.tap(find.byKey(const Key('add-ai-model-price')));
    await tester.pumpAndSettle();
    expect(find.text('离峰折扣（%）'), findsOneWidget);
    expect(find.textContaining('01:00–04:00'), findsWidgets);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('请求明细'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('请求明细'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.2 s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
