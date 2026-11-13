import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/features/scratchpad/scratchpad_screen.dart';

import 'support/gui_capture.dart';

Future<void> ready(WidgetTester t, bool Function() predicate) async {
  for (var i = 0; i < 150 && !predicate(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(predicate(), true);
  await t.pumpAndSettle();
}

Future<void> click(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Streaming reasoning and a persistent multi-page infinite scratchpad on phone and desktop',
    (t) async {
      final c = await AppController.open(demo: true);
      await c.newSession();
      await c.setSessionReasoning('high');
      final key = 'chat:${c.selected!.id}';
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      scope.read(routerProvider).go('/chat');
      await t.pumpAndSettle();
      await resizeGui(t, 390, 844);
      await t.enterText(find.byKey(const Key('chat-input')), '请解释二次函数');
      await t.pump(); // Rebuild the input-driven Send button before tapping.
      await click(t, find.byKey(const Key('send-message')));
      await ready(t, () => !c.busy && c.messages.length == 2);
      expect(c.messages.last.reasoningTrace, contains('Mock'));
      await click(t, find.text('模型思考'));
      expect(find.textContaining('【Mock 思考示例】'), findsWidgets);
      await guiCapture('scratchpad', 'reasoning-phone');
      await click(t, find.byKey(ValueKey('scratchpad-$key')));
      await ready(
        t,
        () => find.byKey(const Key('scratch-canvas')).evaluate().isNotEmpty,
      );
      await resizeGui(t, 320, 844);
      final palette = find.byKey(const Key('scratch-colors'));
      final firstColor = find.byKey(const ValueKey('scratch-color-4280232247'));
      final lastColor = find.byKey(const ValueKey('scratch-color-4287323382'));
      expect(
        (t.getCenter(firstColor).dy - t.getCenter(lastColor).dy).abs(),
        lessThan(1),
        reason: 'Colors stay in one row on a narrow screen',
      );
      final scroll = t.state<ScrollableState>(
        find.descendant(of: palette, matching: find.byType(Scrollable)),
      );
      final needsScrolling = scroll.position.maxScrollExtent > 0;
      await t.drag(palette, const Offset(-160, 0));
      await t.pumpAndSettle();
      if (needsScrolling) {
        expect(scroll.position.pixels, greaterThan(0));
      }
      await click(t, lastColor);
      expect(
        (t.widget<IconButton>(lastColor).icon as Icon).icon,
        Icons.check_circle,
      );
      await guiCapture('scratchpad', 'palette-narrow-phone');
      await t.drag(palette, const Offset(160, 0));
      await t.pumpAndSettle();
      await resizeGui(t, 390, 844);
      Future<void> draw() async {
        final rect = t.getRect(find.byKey(const Key('scratch-canvas')));
        await t.dragFrom(
          rect.center - const Offset(80, 40),
          const Offset(140, 60),
        );
        await t.pumpAndSettle();
        await c.scratch.flush();
      }

      await click(t, find.byKey(const ValueKey('scratch-color-4280640491')));
      final expectedStart =
          t
              .getRect(find.byKey(const Key('scratch-canvas')))
              .size
              .center(Offset.zero) -
          const Offset(80, 40);
      await draw();
      final first = (await c.scratch.load(key)).page.strokes.single;
      expect(first.color, 0xff2563eb);
      expect((first.points.first - expectedStart).distance, lessThan(1));
      await click(t, find.byKey(const Key('scratch-add-page')));
      await draw();
      expect((await c.scratch.load(key)).pages.length, 2);
      await click(t, find.byKey(const Key('scratch-tool-eraser')));
      final before = (await c.scratch.load(key)).page.strokes.single;
      final midpoint = (before.points.first + before.points.last) / 2;
      await t.tapAt(
        t.getRect(find.byKey(const Key('scratch-canvas'))).topLeft + midpoint,
      );
      await t.pumpAndSettle();
      await c.scratch.flush();
      expect((await c.scratch.load(key)).page.strokes.length, 2);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect((await c.scratch.load(key)).page.strokes.length, 1);
      await click(t, find.byKey(const Key('scratch-tool-move')));
      final rect = t.getRect(find.byKey(const Key('scratch-canvas')));
      await t.dragFrom(rect.center, const Offset(80, 40));
      await t.pumpAndSettle();
      await t.sendEventToBinding(
        PointerScrollEvent(
          position: rect.center,
          scrollDelta: const Offset(0, -150),
        ),
      );
      await t.pumpAndSettle();
      await c.scratch.flush();
      expect((await c.scratch.load(key)).page.scale, greaterThan(1));
      await click(t, find.byKey(const Key('scratch-reset')));
      expect((await c.scratch.load(key)).page.scale, 1);
      expect((await c.scratch.load(key)).page.offset, Offset.zero);
      await click(t, find.byKey(const Key('scratch-delete-page')));
      await click(t, find.text('确认'));
      expect((await c.scratch.load(key)).pages.length, 1);
      await click(t, find.byKey(const Key('scratch-undo')));
      expect((await c.scratch.load(key)).pages.length, 2);
      await click(t, find.byKey(const Key('scratch-tool-pen')));
      await guiCapture('scratchpad', 'board-phone');
      await click(t, find.byTooltip('关闭画板'));
      await ready(
        t,
        () => find.byKey(const Key('chat-input')).evaluate().isNotEmpty,
      );
      await click(t, find.byKey(ValueKey('scratchpad-$key')));
      await ready(
        t,
        () => find.byKey(const Key('scratch-canvas')).evaluate().isNotEmpty,
      );
      expect((await c.scratch.load(key)).pages.length, 2);
      expect((await c.scratch.load(key)).page.strokes, isNotEmpty);
      await resizeGui(t, 1280, 900);
      await c.setLanguage('en');
      await t.pumpAndSettle();
      await guiCapture('scratchpad', 'board-desktop-english');
      expect(find.byType(ScratchpadScreen), findsOneWidget);
      expect(t.takeException(), isNull);
      await click(t, find.byTooltip('Close scratchpad'));
      await t.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      await c.shutdown();
    },
  );
}
