import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/library/chat_study_actions.dart";
import "package:val_highlight_flutter/val_highlight_flutter.dart";

void main() {
  testWidgets(
    "Python approval and full preview preserve selectable highlighted code",
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late Directory root;
      late AppController controller;
      const code = "def calculate(x):\n    # 注释\n    return x * 2\n";
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp("python-highlight");
        controller = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await controller.initialize(seed: false);
        controller.pendingTool = const ToolApproval("run_python", {
          "code": code,
          "purpose": "计算",
        }, "");
      });
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((_) => controller)],
      );
      addTearDown(() async {
        scope.dispose();
        await tester.runAsync(() async {
          controller.dispose();
          await controller.db.close();
          await root.delete(recursive: true);
        });
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ToolApprovalCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<CodeView>(
        find.byKey(const Key("python-highlighted-code")),
      );
      expect(preview.code, code);
      expect(preview.selectable, isTrue);
      expect(preview.language?.name, "python");
      expect(preview.textStyle?.fontFamily, "TixunMono");
      final text = tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byType(CodeView),
              matching: find.byType(RichText),
            ),
          )
          .where((widget) => widget.text.toPlainText() == code)
          .single;
      final spans = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          spans.add(span);
          for (final child in span.children ?? <InlineSpan>[]) {
            collect(child);
          }
        }
      }

      collect(text.text);
      expect(
        spans.where((span) => span.style?.color != null).length,
        greaterThan(1),
      );
      await tester.tap(find.text("查看完整代码"));
      await tester.pumpAndSettle();
      final full = tester.widget<CodeView>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CodeView),
        ),
      );
      expect(full.code, code);
      expect(full.textStyle?.fontFamily, "TixunMono");
      expect(full.selectable, isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text("关闭").last);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
