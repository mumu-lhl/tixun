import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/study_tools.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/library/chat_study_actions.dart";

AiToolOperation operation(
  String id,
  String name,
  Map<String, Object?> args, {
  String status = "succeeded",
  Map<String, Object?>? result,
}) => AiToolOperation(
  id: id,
  runId: "message",
  sessionId: "session",
  name: name,
  arguments: jsonEncode(args),
  status: status,
  result: result == null ? null : jsonEncode(result),
  createdAt: DateTime.utc(2026, 1, 1, 0, 0, int.parse(id)),
);

void main() {
  testWidgets("real tool searches appear in execution order", (tester) async {
    late Directory root;
    late AppController controller;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp("tool-history");
      controller = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
      );
      await controller.initialize(seed: false);
      await controller.newSession();
      final runner = StudyToolRunner(
        controller.study,
        sessionId: controller.selected!.id,
        runId: "message",
        authorized: true,
      );
      expect(
        (await runner.execute(
          const ToolCall("z", "search_knowledge", '{"query":"二次函数"}'),
          CancelToken(),
        ))["ok"],
        isTrue,
      );
      expect(
        (await runner.execute(
          const ToolCall("a", "search_mistakes", '{"query":"配方"}'),
          CancelToken(),
        ))["ok"],
        isTrue,
      );
    });
    final scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((_) => controller)],
    );
    addTearDown(() async {
      scope.dispose();
      await tester.runAsync(() async {
        await controller.shutdown();
        await root.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: const MaterialApp(home: Scaffold(body: ToolHistory("message"))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("2 次工具调用"), findsOneWidget);
    expect(find.text("错题：搜索 配方"), findsOneWidget);
    await tester.tap(find.text("2 次工具调用"));
    await tester.pumpAndSettle();
    expect(find.text("知识：搜索 二次函数"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets("tool descriptions follow the selected language", (tester) async {
    final items = [
      operation("1", "search_mistakes", {"query": "algebra"}),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale("en"),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ToolHistoryPanel(messageId: "message", items: items),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Tool calls · 1"), findsOneWidget);
    expect(find.text("Mistakes: search algebra"), findsOneWidget);
  });
  testWidgets(
    "tool history shows search details and collapses without losing state",
    (tester) async {
      final items = [
        operation("1", "search_knowledge", {"query": "二次函数"}),
        operation("2", "search_mistakes", {"query": "配方"}),
        operation("3", "run_python", {"purpose": "计算", "code": "print(1)"}),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolHistoryPanel(messageId: "message", items: items),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("3 次工具调用"), findsOneWidget);
      expect(find.text("运行 Python 计算"), findsOneWidget);
      expect(find.text("知识：搜索 二次函数"), findsNothing);
      await tester.tap(find.text("3 次工具调用"));
      await tester.pumpAndSettle();
      expect(find.text("知识：搜索 二次函数"), findsOneWidget);
      expect(find.text("错题：搜索 配方"), findsOneWidget);
      expect(find.byType(PythonHistoryCard), findsOneWidget);
      await tester.tap(find.text("3 次工具调用"));
      await tester.pumpAndSettle();
      expect(find.text("知识：搜索 二次函数"), findsNothing);
      expect(find.byType(PythonHistoryCard), findsNothing);
    },
  );

  testWidgets(
    "empty searches and material names are described without opaque IDs",
    (tester) async {
      final items = [
        operation("1", "search_knowledge", {}),
        operation(
          "2",
          "get_mistake",
          {"id": "opaque-id"},
          result: {"id": "opaque-id", "title": "三角函数"},
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolHistoryPanel(messageId: "message", items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("错题：读取 三角函数"), findsOneWidget);
      await tester.tap(find.text("2 次工具调用"));
      await tester.pumpAndSettle();
      expect(find.text("知识：搜索 全部"), findsOneWidget);
      expect(find.textContaining("opaque-id"), findsNothing);
    },
  );
}
