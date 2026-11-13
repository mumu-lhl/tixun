import 'support/gui_capture.dart';

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app_host.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/backup/backup_actions.dart';
import 'package:tixun/core/backup/backup_service.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/settings/settings_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Backup restore replaces all live providers and can undo without losing images',
    (tester) async {
      final parent = await Directory.systemTemp.createTemp('tixun-host-backup');
      final root = Directory('${parent.path}/app');
      final c = await AppController.openRoot(root, demo: true, seed: true);
      final note = (await c.study.searchKnowledge()).first;
      final backup = File('${parent.path}/ui.tixun-backup');
      await BackupService.export(c.db, c.files, backup);
      await c.study.saveKnowledge(
        const KnowledgeDraft(title: '恢复前的新笔记', content: '新内容将保存在撤销副本里'),
        id: note.id,
        expectedRevision: note.revision,
      );
      await tester.pumpWidget(
        TixunHost(root: root, demo: true, initialController: c),
      );
      await tester.pumpAndSettle();
      if (find.byKey(const Key('chat-back')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('chat-back')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('nav-4')));
      await tester.pumpAndSettle();
      var container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final actions = container.read(backupActionsProvider)!;
      final preparing = actions.prepare(backup);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final prepared = await preparing;
      await tester.pumpAndSettle();
      final restoring = actions.restore(prepared);
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await restoring;
      await prepared.discard();
      await tester.pumpAndSettle();
      // The old provider scope is gone; the new one starts at the learning page.
      if (find.byKey(const Key('chat-back')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('chat-back')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('nav-4')));
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final restored = container.read(appControllerProvider);
      expect(identical(restored, c), false);
      await tester.ensureVisible(find.byKey(const Key('export-backup')));
      await tester.pumpAndSettle();
      await guiCapture('backup', 'settings-desktop');
      await resizeGui(tester, 390, 844);
      await tester.ensureVisible(find.byKey(const Key('export-backup')));
      await tester.pumpAndSettle();
      await guiCapture('backup', 'settings-phone');
      expect((await restored.study.knowledge(note.id)).title, note.title);
      final images = await restored.study.images(
        (await restored.study.searchMistakes()).first.id,
        isMistake: true,
      );
      expect(
        await restored.files.resolve(images.first.relativePath).exists(),
        true,
      );
      final undo = await container.read(backupActionsProvider)!.prepareUndo();
      final reverting = container.read(backupActionsProvider)!.restore(undo);
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await reverting;
      await undo.discard();
      await tester.pumpAndSettle();
      if (find.byKey(const Key('chat-back')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('chat-back')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('nav-4')));
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(
        (await container.read(appControllerProvider).study.knowledge(note.id))
            .title,
        '恢复前的新笔记',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (await parent.exists()) await parent.delete(recursive: true);
    },
  );
}
