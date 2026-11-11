import 'support/gui_capture.dart';

import 'package:tixun/features/chat/chat_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real Linux GUI: send, stream, persist, navigate and restore draft',
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
      await tester.enterText(find.byKey(const Key('chat-input')), '请解释二次函数的顶点');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.busy, true);
      expect(find.byKey(const Key('stop-generation')), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      // pumpAndSettle observes animations, not pending SQLite I/O.
      for (var i = 0; i < 100 && c.busy; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.busy, false);
      await tester.pumpAndSettle();
      expect(c.messages.length, 2);
      expect(c.messages.last.status, 'complete');
      expect(c.messages.last.content, contains('配方'));
      expect(
        (await c.db.messages(c.selected!.id)).last.content,
        c.messages.last.content,
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('chat-input'))).enabled ??
            true,
        true,
      );
      await tester.tap(find.byKey(const Key('chat-input')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), '明天继续的问题');
      expect(
        c.selected!.draft,
        '明天继续的问题',
        reason: 'draft callback before navigation',
      );
      if (find.byKey(const Key('chat-back')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('chat-back')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('nav-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-1')));
      await tester.pumpAndSettle();
      expect(
        c.selected!.draft,
        '明天继续的问题',
        reason: 'controller draft after navigation',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chat-input')))
            .controller!
            .text,
        '明天继续的问题',
      );
      expect(find.text('明天继续的问题'), findsOneWidget);
      await resizeGui(tester, 390, 844);
      await c.addImage('assets/demo/two_problems.png');
      await tester.pumpAndSettle();
      // The thumbnail's right side contains a separate 48dp remove button.
      await tester.tapAt(
        tester.getRect(find.byType(AttachmentImage)).centerLeft +
            const Offset(12, 0),
      );
      await tester.pumpAndSettle();
      await guiCapture('chat', 'phone-image-preview');
      await tester.tap(find.text('裁剪 / 旋转 / 缩小'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 100 && find.byKey(const Key('crop-canvas')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final canvas = tester.getRect(find.byKey(const Key('crop-canvas')));
      final gesture = await tester.startGesture(
        canvas.topLeft + Offset(canvas.width * .04, canvas.height * .1),
      );
      await gesture.moveTo(
        canvas.topLeft + Offset(canvas.width * .96, canvas.height * .45),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      await guiCapture('chat', 'phone-image-crop');
      await tester.tap(find.text('保存图片编辑'));
      for (
        var i = 0;
        i < 100 && c.attachments.single.originalPath == null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(c.attachments.single.originalPath, isNotNull);
      // The thumbnail's right side contains a separate 48dp remove button.
      await tester.tapAt(
        tester.getRect(find.byType(AttachmentImage)).centerLeft +
            const Offset(12, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看保留的原图'));
      await tester.pumpAndSettle();
      expect(find.text('保留的原图'), findsOneWidget);
      await guiCapture('chat', 'phone-original-retained');
      // Both the retained-original viewer (on top) and the preview viewer
      // below it have a '关闭预览' button; close the topmost one first.
      await tester.tap(find.byTooltip('关闭预览').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭预览'));
      await tester.pumpAndSettle();
      await resizeGui(tester, 1280, 900);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.db.close();
      await c.files.root.delete(recursive: true);
    },
  );
}
