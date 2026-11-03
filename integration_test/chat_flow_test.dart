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
        tester.widget<TextField>(find.byKey(const Key('chat-input'))).enabled,
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
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.db.close();
      await c.files.root.delete(recursive: true);
    },
  );
}
