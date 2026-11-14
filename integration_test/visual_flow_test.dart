import 'support/gui_capture.dart';

import 'package:tixun/features/visual/visual_card.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real Linux GUI: ask for a figure, card renders, fullscreen opens',
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
      await tester.enterText(
        find.byKey(const Key('chat-input')),
        '请画图，画出 y = x^2 的函数图',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 300));
      // No `busy == true` assertion here: the mock tool call can finish
      // inside this first pump (no streaming delay), unlike the text
      // fixtures in chat_flow_test.dart.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      // pumpAndSettle observes animations, not pending SQLite I/O.
      for (var i = 0; i < 100 && c.busy; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.busy, false);
      await tester.pumpAndSettle();
      expect(c.messages.length, 2);
      expect(c.messages.last.status, 'complete');
      // The assistant message carries the closing text and the card below it.
      expect(c.messages.last.content, contains('已生成图形'));
      // The scene is stored and linked to the assistant message.
      final scenes = await c.visual.listByMessage(c.messages.last.id);
      expect(scenes, hasLength(1));
      expect(scenes.single.verificationStatus, 'verified');
      // The card renders under the assistant message.
      expect(find.byType(VisualCard), findsOneWidget);
      expect(find.text('y = x²'), findsWidgets);
      await guiCapture('visual', 'chat-card');
      // Tap the card canvas to open the fullscreen view.
      await tester.ensureVisible(find.byType(VisualCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VisualCard));
      await tester.pumpAndSettle();
      // Fullscreen: app bar title + PNG export action, no slider for the
      // mock scene (it has no controls).
      expect(find.text('y = x²'), findsWidgets);
      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      await guiCapture('visual', 'chat-card-fullscreen');
      // Close the fullscreen view and confirm the card is still there.
      await tester.tap(find.byTooltip('关闭预览'));
      await tester.pumpAndSettle();
      expect(find.byType(VisualCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.db.close();
      await c.files.root.delete(recursive: true);
    },
  );
}
