import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_editor.dart';
import 'package:tixun/features/practice/practice_screen.dart';

void main() {
  for (final isMistake in [false, true]) {
    testWidgets(
      'study ${isMistake ? 'mistake' : 'knowledge'} fields use fullscreen Markdown editor',
      (tester) async {
        late Directory root;
        late AppController c;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp('markdown-study');
          c = AppController(
            AppDatabase.memory(),
            AttachmentStore(root),
            MemoryKeyStore(),
            MockChatProvider(),
          );
          await c.initialize(seed: false);
        });
        final scope = ProviderContainer(
          overrides: [appControllerProvider.overrideWith((_) => c)],
        );
        addTearDown(() async {
          scope.dispose();
          await tester.runAsync(() async {
            c.dispose();
            await c.db.close();
            await root.delete(recursive: true);
          });
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: scope,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: ctx,
                      builder: (_) => StudyEditor(isMistake: isMistake),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final name = isMistake ? 'question' : 'content';
        final button = find.byKey(ValueKey('study-markdown-$name'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('markdown-done')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('关闭编辑'));
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsNothing);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('markdown-source')),
          r'推导 \(x^2\)',
        );
        await tester.tap(find.byKey(const Key('markdown-done')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('study-content')))
              .controller!
              .text,
          r'推导 \(x^2\)',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'practice question editor applies the Markdown draft to the stem',
    (tester) async {
      late Directory root;
      late AppController c;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('markdown-practice');
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await c.initialize(seed: false);
      });
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((_) => c)],
      );
      addTearDown(() async {
        scope.dispose();
        await tester.runAsync(() async {
          c.dispose();
          await c.db.close();
          await root.delete(recursive: true);
        });
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => const QuestionEditor(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('practice-markdown-stem'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('markdown-source')), '## 题目');
      await tester.tap(find.byKey(const Key('markdown-done')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('question-stem')))
            .controller!
            .text,
        '## 题目',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
