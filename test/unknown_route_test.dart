import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

void main() {
  testWidgets('unknown route shows an in-app error page with a way home', (
    tester,
  ) async {
    late AppController c;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('tixun-route-test');
      c = AppController(
        AppDatabase.memory(),
        AttachmentStore(dir),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await c.initialize();
    });
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
    addTearDown(() async {
      container.dispose();
      await c.db.close();
      await c.files.root.delete(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TixunApp()),
    );
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/no-such-page');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('页面不存在'), findsOneWidget);
    expect(find.text('/no-such-page'), findsOneWidget);

    await tester.tap(find.text('回学习页'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Back on the study page: bottom navigation and dashboard content.
    expect(find.text('今天先做什么'), findsOneWidget);
  });
}
