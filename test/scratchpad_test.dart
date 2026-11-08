import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/backup/backup_service.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/scratchpad/scratch_document.dart';
import 'package:tixun/features/scratchpad/scratch_store.dart';

void main() {
  test(
    'Pages retain their own ink and viewport through encoding and deletion',
    () {
      final stroke = InkStroke(0xff2563eb, 3, [
        const Offset(-100, 50),
        const Offset(250, 500),
      ]);
      var doc = ScratchDocument().replace(
        ScratchPage(
          strokes: [stroke],
          scale: 2,
          offset: const Offset(100, -200),
        ),
      );
      doc = doc.addPage().replace(
        ScratchPage(
          strokes: [
            InkStroke(0xffdc3d43, 8, [Offset.zero]),
          ],
        ),
      );
      final loaded = ScratchDocument.decode(doc.encode());
      expect(loaded.pages.length, 2);
      expect(loaded.index, 1);
      expect(loaded.pages.first.scale, 2);
      expect(
        loaded.pages.first.strokes.single.points.first,
        const Offset(-100, 50),
      );
      expect(loaded.deletePage().page.strokes.single.color, 0xff2563eb);
      expect(loaded.deletePage().deletePage().page.strokes, isEmpty);
      expect(
        () => ScratchDocument.decode('{"version":999}'),
        throwsFormatException,
      );
      expect(
        () => ScratchDocument.decode('{"version":1,"pages":[],"index":0}'),
        throwsFormatException,
      );
    },
  );

  test('Radius erasing splits a stroke and preserves points outside the erased area', () {
    final stroke = InkStroke(0xff000000, 2, [
      const Offset(-50, 0),
      ...interpolate(const Offset(-50, 0), const Offset(50, 0), 1),
    ]);
    final erased = eraseInk([stroke], Offset.zero, 10);
    expect(erased.length, 2);
    expect(erased.first.points.first, const Offset(-50, 0));
    expect(erased.last.points.last, const Offset(50, 0));
    expect(erased.expand((s) => s.points).every((p) => p.distance > 11), true);
    expect(eraseInk([stroke], const Offset(0, 200), 10).single, same(stroke));
    expect(eraseInk([stroke], Offset.zero, 100), isEmpty);
  });

  test('Autosave snapshots are independent by context and hard deletion cleans the board', () async {
    final db = AppDatabase.memory();
    final store = ScratchStore(db);
    final chat = await db.createSession();
    final key = 'chat:${chat.id}';
    store.stage(key, ScratchDocument().addPage());
    store.stage(key, ScratchDocument().addPage().addPage());
    final otherKey = 'chat:${(await db.createSession()).id}';
    store.stage(otherKey, ScratchDocument());
    await store.flush();
    expect((await store.load(key)).pages.length, 3);
    expect((await store.load(otherKey)).pages.length, 1);
    await (db.delete(db.chatSessions)..where((s) => s.id.equals(chat.id))).go();
    expect((await db.select(db.scratchpads).get()).single.contextKey, otherKey);
    store.stage(otherKey, ScratchDocument().addPage());
    await (db.delete(
      db.chatSessions,
    )..where((s) => s.id.equals(otherKey.substring(5)))).go();
    await store.flush();
    expect(await db.select(db.scratchpads).get(), isEmpty);
    store.dispose();
    await db.close();
  });

  test(
    'Continuous short strokes checkpoint without waiting for an idle pause',
    () async {
      final db = AppDatabase.memory();
      final store = ScratchStore(db);
      addTearDown(() async {
        await store.flush();
        store.dispose();
        await db.close();
      });
      final key = 'chat:${(await db.createSession()).id}';
      var doc = ScratchDocument();
      for (var i = 0; i < 6; i++) {
        doc = doc.addPage();
        store.stage(key, doc);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final saved = (await db.select(db.scratchpads).get()).single;
      expect(
        ScratchDocument.decode(saved.document).pages.length,
        greaterThan(1),
      );
      await store.flush();
      expect((await store.load(key)).pages.length, 7);
    },
  );

  test(
    'Shutdown flushes pending drafts and complete backups include all pages',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'tixun-scratch-backup',
      );
      final root = Directory('${temp.path}/app');
      var c = await AppController.openRoot(
        root,
        demo: false,
        keyStore: MemoryKeyStore(),
        chatProvider: MockChatProvider(),
      );
      await c.newSession();
      final key = 'chat:${c.selected!.id}';
      c.scratch.stage(
        key,
        ScratchDocument().addPage().replace(
          ScratchPage(
            strokes: [
              InkStroke(0xff177d56, 4, [const Offset(1, 2)]),
            ],
          ),
        ),
      );
      await c.shutdown();
      c = await AppController.openRoot(
        root,
        demo: false,
        keyStore: MemoryKeyStore(),
        chatProvider: MockChatProvider(),
      );
      expect((await c.scratch.load(key)).pages.length, 2);
      final archive = File('${temp.path}/backup.tixun-backup');
      await BackupService.export(c.db, c.files, archive);
      final prepared = await BackupService.prepare(archive, root);
      final restored = AppDatabase.file(
        File('${prepared.data.path}/tixun.sqlite'),
      );
      final row = (await restored.select(restored.scratchpads).get()).single;
      expect(
        ScratchDocument.decode(row.document).page.strokes.single.points.single,
        const Offset(1, 2),
      );
      await restored.close();
      await prepared.discard();
      await c.shutdown();
      await temp.delete(recursive: true);
    },
  );
}
