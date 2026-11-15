import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/visual_toolset.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('temporary chat drawing menu works at width $width', (
      tester,
    ) async {
      late Directory root;
      late AppController c;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('chat-drawing-menu');
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
      scope.read(routerProvider).go('/chat');
      await tester.pumpAndSettle();
      final menu = find.byKey(const Key('chat-drawing-menu'));
      Future<void> choose(String value) async {
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('chat-drawing-$value')));
        await tester.pumpAndSettle();
      }

      String? tooltip() => tester.widget<PopupMenuButton<String>>(menu).tooltip;
      expect(menu, findsOneWidget);
      expect(tooltip(), contains('绘图已关闭'));
      expect(tooltip(), contains('跟随默认'));
      await choose('on');
      expect(c.sessionDrawingOverride, true);
      expect(c.aiDrawingEnabled, false);
      expect(tooltip(), contains('绘图已开启'));
      expect(tooltip(), isNot(contains('跟随默认')));
      await choose('off');
      expect(c.sessionDrawingEnabled, false);
      await tester.runAsync(() async {
        expect(await c.db.preference(aiDrawingEnabledKey), isNull);
        await c.setAiDrawingEnabled(true);
      });
      await tester.pumpAndSettle();
      expect(c.sessionDrawingEnabled, false);
      await choose('default');
      expect(c.sessionDrawingOverride, isNull);
      expect(c.sessionDrawingEnabled, true);
      await tester.runAsync(() => c.setAiDrawingEnabled(false));
      await tester.pumpAndSettle();
      expect(c.sessionDrawingEnabled, false);

      // The control stays in the input row even when the mode row is hidden.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(menu.hitTestable(), findsOneWidget);
      await choose('on');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.runAsync(() => c.newSession());
      await tester.pumpAndSettle();
      expect(c.sessionDrawingOverride, isNull);
      expect(c.sessionDrawingEnabled, false);
      await tester.runAsync(() async {
        await c.selectSession(first);
        await c.setLanguage('en');
      });
      await tester.pumpAndSettle();
      expect(c.sessionDrawingOverride, true);
      expect(tooltip(), contains('Drawing on'));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('Temporarily enable drawing'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-drawing-default')));
      await tester.pumpAndSettle();
      expect(c.sessionDrawingOverride, isNull);
      c.busy = true;
      c.changed();
      await tester.pump();
      expect(tester.widget<PopupMenuButton<String>>(menu).enabled, false);
      c.setSessionDrawingEnabled(true);
      expect(c.sessionDrawingOverride, isNull);
      c.busy = false;
      c.changed();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
