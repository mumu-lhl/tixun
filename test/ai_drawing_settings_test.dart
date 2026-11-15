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
  testWidgets('settings drawing switch persists opt-in and follows locale', (
    tester,
  ) async {
    late Directory root;
    late AppController c;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('drawing-settings');
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
    scope.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('settings-ai-drawing'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    expect(find.text('AI 绘图'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(toggle);
      await c.preferences.whenIdle;
      expect(await c.db.preference(aiDrawingEnabledKey), 'true');
      await c.setLanguage('en');
    });
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    expect(find.text('AI drawing'), findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.runAsync(() async {
      await tester.tap(toggle);
      await c.preferences.whenIdle;
      expect(await c.db.preference(aiDrawingEnabledKey), 'false');
    });
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    expect(tester.takeException(), isNull);
  });
}
