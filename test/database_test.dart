import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';

void main() {
  test('File database persists drafts, attachments, config and recovers interrupted generation', () async {
    final root = await Directory.systemTemp.createTemp('tixun-db-test');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/data.sqlite');
    var db = AppDatabase.file(file);
    final s = await db.createSession(title: '二次函数');
    await db.saveDraft(s.id, '还没发送的草稿');
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: 'm',
            sessionId: s.id,
            role: 'assistant',
            content: '部分回复',
            status: const Value('generating'),
            createdAt: DateTime.now(),
          ),
        );
    await db
        .into(db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'a',
            sessionId: s.id,
            relativePath: 'attachments/a.jpg',
            mime: 'image/jpeg',
            byteLength: 100,
          ),
        );
    await db.saveConfig(
      (await db.config()).copyWith(model: 'deepseek-v4-pro', vision: false),
    );
    await db.close();
    db = AppDatabase.file(file);
    addTearDown(db.close);
    expect((await db.sessions()).single.draft, '还没发送的草稿');
    expect((await db.messages(s.id)).single.status, 'interrupted');
    expect((await db.images(s.id)).single.relativePath, 'attachments/a.jpg');
    expect((await db.config()).model, 'deepseek-v4-pro');
    expect(
      (await db.customSelect('PRAGMA integrity_check').get())
          .single
          .data
          .values
          .single,
      'ok',
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test(
    'Full text index updates, short Chinese search and trash restoration work',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final s = await db.createSession(title: '数学');
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: 'm',
              sessionId: s.id,
              role: 'user',
              content: '配方得到二次函数的顶点',
              createdAt: DateTime.now(),
            ),
          );
      expect((await db.sessions('二次函数')).single.id, s.id);
      expect((await db.sessions('顶点')).single.id, s.id);
      expect(await db.sessions('" OR *'), isEmpty);
      await (db.update(db.chatMessages)..where((m) => m.id.equals('m'))).write(
        const ChatMessagesCompanion(content: Value('动量守恒的条件')),
      );
      expect(await db.sessions('二次函数'), isEmpty);
      expect((await db.sessions('动量守恒')).length, 1);
      await db.setDeleted(s.id, true);
      expect(await db.sessions(), isEmpty);
      expect((await db.trash()).length, 1);
      await db.setDeleted(s.id, false);
      expect((await db.sessions()).single.id, s.id);
    },
  );
  test(
    'Transactions roll back together and foreign keys reject missing sessions',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.config();
      await expectLater(
        db.transaction(() async {
          await db.createSession(title: '应回滚');
          throw StateError('abort');
        }),
        throwsStateError,
      );
      expect(await db.sessions(), isEmpty);
      await expectLater(
        db
            .into(db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: 'bad',
                sessionId: 'missing',
                role: 'user',
                content: 'x',
                createdAt: DateTime.now(),
              ),
            ),
        throwsA(anything),
      );
    },
  );
  test('Stable attachment import survives removal of picker source; traversal is rejected', () async {
    final root = await Directory.systemTemp.createTemp('tixun-images-test');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/source.png');
    await source.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
    final store = AttachmentStore(Directory('${root.path}/managed'));
    final imported = await store.importFile(source.path);
    await source.delete();
    expect(await store.resolve(imported.path).exists(), true);
    expect(imported.mime, 'image/png');
    expect(() => store.resolve('../secret'), throwsFormatException);
    expect(() => store.resolve('/etc/passwd'), throwsFormatException);
  });
}
