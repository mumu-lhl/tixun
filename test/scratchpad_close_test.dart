import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/scratchpad/scratch_document.dart';
import 'package:tixun/features/scratchpad/scratchpad_screen.dart';

void main() {
  testWidgets(
    'A persistently failing save offers discard-and-exit instead of trapping the user',
    (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp(
          'tixun-scratch-close',
        );
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await c.initialize();
      });
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      addTearDown(() async {
        await tester.runAsync(() async {
          container.dispose();
          try {
            await c.db.close();
          } catch (_) {}
          if (await c.files.root.exists()) {
            await c.files.root.delete(recursive: true);
          }
        });
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ScratchpadScreen('mistake:probe')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ScratchpadScreen), findsOneWidget);
      // Queue an unsaved snapshot, then break every later save: closing the
      // database makes flush() throw. (An empty pending set never touches
      // the database, so staging first is what makes the failure real.)
      await tester.runAsync(() async {
        c.scratch.stage('mistake:probe', ScratchDocument().addPage());
        await c.db.close();
      });
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('保存失败，放弃未保存内容退出？'), findsOneWidget);
      // "Keep retrying" dismisses the dialog and stays on the board.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ScratchpadScreen), findsOneWidget);
      // A second failed close, then "Discard and exit" pops the board.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ScratchpadScreen), findsNothing);
    },
  );
}
