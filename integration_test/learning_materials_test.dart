import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

Future<void> until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 150 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done(), true, reason: '操作应在15秒内完成');
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Chat tool approval writes a traceable knowledge record and UI opens it',
    (tester) async {
      final c = await AppController.open(demo: true);
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TixunApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-chat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('开启本会话资料工具'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('允许'));
      await until(tester, () => c.selected!.toolsEnabled);
      await tester.enterText(find.byKey(const Key('chat-input')), '请总结并保存知识');
      await tester.tap(find.byKey(const Key('send-message')));
      await until(tester, () => c.pendingTool != null);
      expect((await c.study.searchKnowledge()).length, 1);
      await tester.ensureVisible(find.byKey(const Key('approve-tool')));
      await tester.tap(find.byKey(const Key('approve-tool')));
      await until(tester, () => !c.busy);
      expect(c.messages.last.status, 'complete');
      final note = (await c.study.searchKnowledge()).firstWhere(
        (k) => k.title == '二次函数的顶点与配方',
      );
      expect(note.sourceSessionId, c.selected!.id);
      expect(note.sourceMessageId, c.messages.last.id);
      await tester.tap(find.byKey(const Key('nav-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('二次函数的顶点与配方'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-study')), findsOneWidget);
      expect(find.text('来源对话'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.db.close();
      await c.files.root.delete(recursive: true);
    },
  );
  testWidgets(
    'Manual question splitting keeps both original and crop in a separate mistake',
    (tester) async {
      final c = await AppController.open(demo: true);
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TixunApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('顶点的纵坐标为什么不是常数项？'));
      await tester.pumpAndSettle();
      final editorButton = find.text('裁剪 / 旋转 / 分题');
      await tester.ensureVisible(editorButton);
      await tester.tap(editorButton);
      await tester.pumpAndSettle();
      await until(
        tester,
        () => find.byKey(const Key('crop-canvas')).evaluate().isNotEmpty,
      );
      final rect = tester.getRect(find.byKey(const Key('crop-canvas')));
      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width * .05, rect.top + rect.height * .05),
      );
      await gesture.moveTo(
        Offset(rect.left + rect.width * .95, rect.top + rect.height * .5),
      );
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(const Key('split-mistake')));
      await until(
        tester,
        () => find.byKey(const Key('split-mistake')).evaluate().isEmpty,
      );
      final records = await c.study.searchMistakes();
      expect(records.length, 2);
      final split = records.firstWhere((m) => m.title.endsWith(' · 分题'));
      final images = await c.study.images(split.id, isMistake: true);
      expect(images.length, 2);
      expect(images.map((a) => a.role).toSet(), {'original', 'crop'});
      for (final image in images) {
        expect(await c.files.resolve(image.relativePath).exists(), true);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.db.close();
      await c.files.root.delete(recursive: true);
    },
  );
}
