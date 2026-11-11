import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/python/python_runtime.dart';
import 'package:dio/dio.dart';

import 'dart:io';

import 'support/gui_capture.dart';

Future<void> until(WidgetTester t, bool Function() ready) async {
  for (var i = 0; i < 600 && !ready(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), true);
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real bundled CPython: review code, run SymPy, inspect output and full-screen Chat',
    (t) async {
      final c = await AppController.open(demo: true);
      await c.newSession();
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      await resizeGui(t, 390, 844);
      scope.read(routerProvider).go('/chat');
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      final pending = c.send('请用 Python 核对 x² 从0到3的积分');
      await until(t, () => c.pendingTool != null);
      await t.ensureVisible(find.byKey(const Key('approve-tool')));
      await t.pumpAndSettle();
      await guiCapture('python', 'review-code-phone');
      await t.tap(find.byKey(const Key('approve-tool')));
      await until(t, () => !c.busy);
      await pending;
      expect(c.messages.last.status, 'complete', reason: c.error);
      expect(c.messages.last.content, contains('9'));
      final operation = (await c.db.select(c.db.aiToolOperations).get())
          .singleWhere((op) => op.name == 'run_python');
      expect(operation.status, 'succeeded');
      expect(operation.result, contains('9'));
      await until(t, () => find.text('Python · 执行完成').evaluate().isNotEmpty);
      final history = find.byKey(
        PageStorageKey('python-history-${operation.id}'),
      );
      await t.ensureVisible(history);
      await t.pumpAndSettle();
      await t.tap(history);
      await t.pumpAndSettle();
      await guiCapture('python', 'execution-result-phone');
      // Real execution is not constrained to predefined mathematics functions.
      final result = await PythonRuntime.instance.execute(
        code: "from pathlib import Path\nprint(sum(i*i for i in range(10)))\nPath('generated.txt').write_text('Python file output')",
        workspace: Directory('${c.files.root.path}/python-check'),
        timeoutSeconds: 10,
        cancel: CancelToken(),
      );
      expect(result['ok'], true, reason: result.toString());
      expect(result['stdout'], '285\n');
      expect(
        await File('${c.files.root.path}/python-check/generated.txt')
            .readAsString(),
        'Python file output',
      );
      await t.tap(find.byKey(const Key('chat-back')));
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      scope.read(routerProvider).go('/settings/python');
      await t.pumpAndSettle();
      await guiCapture('python', 'execution-settings-phone');
      await t.tap(find.byKey(const Key('python-policy')));
      await t.pumpAndSettle();
      await t.tap(find.text('自动允许任意代码').last);
      await t.pumpAndSettle();
      expect(await c.db.preference('python_execution_policy'), isNull);
      await t.tap(find.text('取消').last);
      await t.pumpAndSettle();
      expect(find.text('每次审查代码'), findsOneWidget);
      expect(await c.db.preference('python_execution_policy'), isNull);
      await t.tap(find.byKey(const Key('python-policy')));
      await t.pumpAndSettle();
      await t.tap(find.text('自动允许任意代码').last);
      await t.pumpAndSettle();
      await guiCapture('python', 'auto-permission-phone');
      await t.tap(find.byKey(const Key('confirm-python-auto')));
      await until(t, () => find.byType(AlertDialog).evaluate().isEmpty);
      expect(await c.db.preference('python_execution_policy'), 'auto');
      scope.read(routerProvider).go('/chat');
      await t.pumpAndSettle();
      var asked = false;
      void observed() {
        if (c.pendingTool != null) asked = true;
      }

      c.addListener(observed);
      final automatic = c.send('再次用 Python 核对积分');
      await until(t, () => !c.busy);
      await automatic;
      c.removeListener(observed);
      expect(asked, false);
      expect(c.messages.last.content, contains('9'));
      expect(c.messages.last.status, 'complete');

      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      scope.dispose();
      await c.shutdown();
    },
  );
}
