import 'support/gui_capture.dart';

import 'dart:io';

import 'package:flutter/services.dart';

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
    'Photo import opens crop; chat and mistake edits preserve originals without extra records',
    (t) async {
      final c = await AppController.open(demo: true);
      await c.newSession();
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      const channel =
          'dev.flutter.pigeon.file_selector_linux.FileSelectorApi.showFileChooser';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(
        channel,
        (_) async => const StandardMessageCodec().encodeMessage([
          [File('assets/demo/two_problems.png').absolute.path],
        ]),
      );
      addTearDown(() => messenger.setMockMessageHandler(channel, null));
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TixunApp(),
        ),
      );
      await t.pumpAndSettle();
      container.read(routerProvider).go('/chat');
      await t.pumpAndSettle();
      await resizeGui(t, 390, 844);
      await t.tap(find.byTooltip('添加图片'));
      await t.pumpAndSettle();
      await t.tap(find.text('选择图片文件'));
      await until(
        t,
        () => find.byKey(const Key('crop-canvas')).evaluate().isNotEmpty,
      );
      final source = c.attachments.single;
      expect(source.originalPath, isNull);
      final canvas = t.getRect(find.byKey(const Key('crop-canvas')));
      final drag = await t.startGesture(
        canvas.topLeft + Offset(canvas.width * .06, canvas.height * .1),
      );
      await drag.moveTo(
        canvas.topLeft + Offset(canvas.width * .94, canvas.height * .46),
      );
      await drag.up();
      await t.pumpAndSettle();
      await guiCapture('split', 'import-crop-phone');
      await t.tap(find.byKey(const Key('apply-image-edit')));
      await until(
        t,
        () => find.byKey(const Key('crop-canvas')).evaluate().isEmpty,
      );
      final edited = c.attachments.single;
      expect(edited.originalPath, source.relativePath);
      expect(edited.relativePath, isNot(source.relativePath));
      expect(await c.files.resolve(source.relativePath).exists(), true);
      expect(await c.files.resolve(edited.relativePath).exists(), true);
      expect(
        (await c.db.images(c.selected!.id)).single.originalPath,
        source.relativePath,
      );
      expect(
        await c.study.searchMistakes(),
        hasLength(1),
        reason: 'Cropping a chat photo must not create a mistake',
      );
      await guiCapture('split', 'import-edited-chat-phone');
      container.read(routerProvider).go('/mistakes');
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('多图录入（每张独立建题）'));
      await until(
        t,
        () => find.byKey(const Key('crop-canvas')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('split-mistake')), findsNothing);
      await t.tap(find.byKey(const Key('apply-image-edit')));
      await until(
        t,
        () => find.byKey(const Key('crop-canvas')).evaluate().isEmpty,
      );
      final mistakes = await c.study.searchMistakes();
      expect(
        mistakes,
        hasLength(2),
        reason: 'Saving an imported photo must edit the same mistake',
      );
      final imported = mistakes.firstWhere(
        (m) => m.title == 'two_problems.png',
      );
      final images = await c.study.images(imported.id, isMistake: true);
      expect(images.map((i) => i.role).toSet(), {'original', 'crop'});
      for (final image in images) {
        expect(await c.files.resolve(image.relativePath).exists(), true);
      }

      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.shutdown();
    },
  );
  testWidgets(
    'AI proposes question regions; user adjusts and confirms a persistent crop',
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
      await until(tester, () => find.text('AI 辅助分题').evaluate().isNotEmpty);
      await tester.ensureVisible(find.text('AI 辅助分题'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI 辅助分题'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-message')));
      await until(tester, () => !c.busy && c.messages.length == 2);
      await until(
        tester,
        () => find.byKey(const Key('check-region-0')).evaluate().isNotEmpty,
      );
      expect(
        (await c.study.searchMistakes()).length,
        1,
        reason: 'Suggestions do not silently save records',
      );
      await tester.ensureVisible(find.byKey(const Key('check-region-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('check-region-0')));
      await tester.pumpAndSettle();
      await until(
        tester,
        () => find.byKey(const Key('crop-canvas')).evaluate().isNotEmpty,
      );
      final canvas = tester.getRect(find.byKey(const Key('crop-canvas')));
      final gesture = await tester.startGesture(
        canvas.topLeft + Offset(canvas.width * .04, canvas.height * .11),
      );
      await gesture.moveTo(
        canvas.topLeft + Offset(canvas.width * .96, canvas.height * .45),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      await guiCapture('split', 'adjusted-ai-region');
      await tester.tap(find.byKey(const Key('split-mistake')));
      await until(
        tester,
        () => find.byKey(const Key('crop-canvas')).evaluate().isEmpty,
      );
      final saved = (await c.study.searchMistakes()).firstWhere(
        (m) => m.title == '第1题 · 二次函数',
      );
      final images = await c.study.images(saved.id, isMistake: true);
      expect(images.length, 2);
      expect(images.any((a) => a.role == 'crop'), true);
      await tester.pumpAndSettle();
      await until(tester, () => find.text('查看错题').evaluate().isNotEmpty);
      await tester.ensureVisible(find.text('查看错题'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看错题'));
      await tester.pumpAndSettle();
      await until(
        tester,
        () => find.byKey(const Key('edit-study')).evaluate().isNotEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.shutdown();
    },
  );
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
      if (find.byKey(const Key('chat-more')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('chat-more')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<String>, '开启本会话资料工具'),
        );
      } else {
        await tester.tap(find.byTooltip('开启本会话资料工具'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('允许'));
      await until(tester, () => c.selected!.toolsEnabled);
      await tester.enterText(find.byKey(const Key('chat-input')), '请总结并保存知识');
      await tester
          .pump(); // Rebuild the input-driven Send button before tapping.
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
      // The subject bar pushed this button below the fold, so the scroll
      // ensureVisible triggers needs a frame before tap() reads its center.
      await tester.pumpAndSettle();
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
