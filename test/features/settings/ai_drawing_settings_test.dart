import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/visual_toolset.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/a2ui/a2ui_tools.dart";

void main() {
  testWidgets("settings drawing switch persists opt-in and follows locale", (
    tester,
  ) async {
    late Directory root;
    late AppController c;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp("drawing-settings");
      c = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await c.initialize(seed: false);
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
    scope.read(routerProvider).go("/settings");
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key("settings-ai-tools"));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key("settings-ai-drawing"));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    expect(find.text("AI 绘图"), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(toggle);
      await c.preferences.whenIdle;
      expect(await c.db.preference(aiDrawingEnabledKey), "true");
      await c.setLanguage("en");
    });
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    expect(find.text("AI drawing"), findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.runAsync(() async {
      await tester.tap(toggle);
      await c.preferences.whenIdle;
      expect(await c.db.preference(aiDrawingEnabledKey), "false");
    });
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    final a2ui = find.byKey(const Key("settings-ai-a2ui"));
    await tester.ensureVisible(a2ui);
    expect(tester.widget<SwitchListTile>(a2ui).value, true);
    await tester.runAsync(() async {
      await tester.tap(a2ui);
      await c.preferences.whenIdle;
      expect(await c.db.preference(aiA2uiEnabledKey), "false");
    });
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(a2ui).value, false);
    expect(find.byKey(const Key("settings-tool-call-limit")), findsOneWidget);
    final python = find.byKey(const Key("python-policy"));
    await tester.scrollUntilVisible(python, 180);
    expect(python, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
