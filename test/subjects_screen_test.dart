import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

void main() {
  testWidgets('subject order can be changed and is used by study switcher', (
    tester,
  ) async {
    late Directory root;
    late AppController controller;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('tixun-subject-order');
      controller = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await controller.initialize(seed: false);
      await controller.setLearningSubjects(['英语', '数学', '语文']);
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
    scope.read(routerProvider).go('/settings/subjects');
    await tester.pumpAndSettle();
    expect(find.text('已选 3 / 20 个科目'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 140),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final order = ['英语', '数学', '语文'];
    final savedOrder = order.toList()
      ..sort((a, b) {
        final aY = tester
            .getTopLeft(find.byKey(ValueKey('selected-study-subject-$a')))
            .dy;
        final bY = tester
            .getTopLeft(find.byKey(ValueKey('selected-study-subject-$b')))
            .dy;
        return aY.compareTo(bY);
      });
    expect(savedOrder, isNot(order));

    expect(find.byKey(const Key('save-subjects')), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(controller.learningSubjects, savedOrder);

    scope.read(routerProvider).go('/study');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject-switch')));
    await tester.pumpAndSettle();
    final menuPositions = savedOrder
        .map((subject) => tester.getTopLeft(find.text(subject)).dy)
        .toList();
    expect(menuPositions, orderedEquals([...menuPositions]..sort()));

    scope.read(routerProvider).go('/settings/python');
    tester.view.physicalSize = const Size(1280, 844);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final pythonContent = tester.getRect(
      find.byKey(const Key('python-policy')),
    );
    expect(pythonContent.center.dx, closeTo((203 + 1280) / 2, 1));
    expect(pythonContent.width, lessThanOrEqualTo(760));

    scope.read(routerProvider).go('/settings/ai-usage');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AI 用量'), findsOneWidget);
    expect(find.byKey(const Key('add-ai-model-price')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
