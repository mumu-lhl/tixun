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

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets("temporary chat drawing menu works at width $width", (
      tester,
    ) async {
      late Directory root;
      late AppController c;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp("chat-drawing-menu");
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
      final first = c.selected!;
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((_) => c)],
      );
      addTearDown(() async {
        scope.dispose();
        await c.db.close();
        await root.delete(recursive: true);
      });
      tester.view.devicePixelRatio = 1;
      // Give the desktop shell room for its existing navigation rail while
      // simulating a software keyboard; phone coverage stays deliberately small.
      tester.view.physicalSize = Size(width, width >= 1000 ? 1000 : 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      scope.read(routerProvider).go("/chat");
      await tester.pumpAndSettle();
      final menu = find.byKey(const Key("chat-more"));
      expect(find.byKey(const Key("chat-drawing-menu")), findsNothing);
      expect(tester.getCenter(menu).dy, lessThan(100));
      Future<void> choose(String value) async {
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key("chat-drawing-$value")));
        await tester.pumpAndSettle();
      }

      Future<void> expectStatus(
        String status, {
        bool followDefault = false,
      }) async {
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.textContaining(status), findsOneWidget);
        expect(
          find.textContaining("跟随默认"),
          followDefault ? findsOneWidget : findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      expect(menu, findsOneWidget);
      await expectStatus("绘图已关闭", followDefault: true);
      await choose("on");
      expect(c.sessionDrawingOverride, true);
      expect(c.aiDrawingEnabled, false);
      await expectStatus("绘图已开启");
      await choose("off");
      expect(c.sessionDrawingEnabled, false);
      await tester.runAsync(() async {
        expect(await c.db.preference(aiDrawingEnabledKey), isNull);
        await c.setAiDrawingEnabled(true);
      });
      await tester.pumpAndSettle();
      expect(c.sessionDrawingEnabled, false);
      await choose("default");
      expect(c.sessionDrawingOverride, isNull);
      expect(c.sessionDrawingEnabled, true);
      await tester.runAsync(() => c.setAiDrawingEnabled(false));
      await tester.pumpAndSettle();
      expect(c.sessionDrawingEnabled, false);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(menu.hitTestable(), findsOneWidget);
      await choose("on");
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.runAsync(() => c.newSession());
      await tester.pumpAndSettle();
      expect(c.sessionDrawingOverride, isNull);
      expect(c.sessionDrawingEnabled, false);
      await tester.runAsync(() async {
        await c.selectSession(first);
        await c.setLanguage("en");
      });
      await tester.pumpAndSettle();
      expect(c.sessionDrawingOverride, true);
      await expectStatus("Drawing on");
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text("Enable drawing for this chat"), findsOneWidget);
      await tester.tap(find.byKey(const Key("chat-drawing-default")));
      await tester.pumpAndSettle();
      expect(c.sessionDrawingOverride, isNull);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final disable = find.byKey(const Key("chat-a2ui-off"));
      await tester.ensureVisible(disable);
      await tester.runAsync(() async {
        await tester.tap(disable);
        await c.preferences.whenIdle;
      });
      await tester.pumpAndSettle();
      expect(c.sessionA2uiEnabled, false);
      expect(c.aiA2uiEnabled, true);
      c.busy = true;
      c.changed();
      await tester.pump();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      for (final choice in ["default", "on", "off"]) {
        expect(
          tester
              .widget<CheckedPopupMenuItem<String>>(
                find.byKey(Key("chat-drawing-$choice")),
              )
              .enabled,
          false,
        );
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await c.setSessionDrawingEnabled(true);
      expect(c.sessionDrawingOverride, isNull);
      c.busy = false;
      c.changed();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
