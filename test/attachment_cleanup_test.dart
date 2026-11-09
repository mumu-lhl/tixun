import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tixun/core/database/attachment_cleanup.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';

void main() {
  late AppDatabase db;
  late AttachmentStore files;
  late Directory attachmentsDir;
  setUp(() async {
    db = AppDatabase.memory();
    files = AttachmentStore(
      await Directory.systemTemp.createTemp('tixun-cleanup-test'),
    );
    attachmentsDir = Directory(p.join(files.root.path, 'attachments'));
    await attachmentsDir.create(recursive: true);
  });
  tearDown(() async {
    await db.close();
    if (await files.root.exists()) {
      await files.root.delete(recursive: true);
    }
  });

  Future<File> orphan(
    String name, {
    Duration age = const Duration(hours: 1),
  }) async {
    final file = files.resolve('attachments/$name');
    await file.writeAsBytes([1, 2, 3]);
    await file.setLastModified(DateTime.now().subtract(age));
    return file;
  }

  test('Orphan sweep deletes only old unreferenced files', () async {
    final oldOrphan = await orphan('old.png');
    final freshOrphan = await orphan(
      'fresh.png',
      age: const Duration(minutes: 1),
    );
    final kept = await orphan('kept.png');
    // Reference kept.png through a real knowledge row (no StudyStore here:
    // constructing one would fire its startup sweep and race this test).
    final now = DateTime.now();
    await db
        .into(db.knowledgeItems)
        .insert(
          KnowledgeItem(
            id: 'k-1',
            title: '笔记',
            content: '内容',
            subject: '数学',
            kind: '个人笔记',
            chapter: '',
            revision: 1,
            createdAt: now,
            updatedAt: now,
            deleted: false,
          ),
        );
    await db
        .into(db.studyAttachments)
        .insert(
          StudyAttachmentsCompanion.insert(
            id: 'sa-1',
            knowledgeId: const Value('k-1'),
            relativePath: 'attachments/kept.png',
            mime: 'image/png',
            byteLength: 3,
          ),
        );
    expect(await cleanupOrphanAttachments(db, files), 1);
    expect(await oldOrphan.exists(), false);
    expect(await freshOrphan.exists(), true);
    expect(await kept.exists(), true);
  });

  test('Orphan sweep is a no-op without an attachments directory', () async {
    await attachmentsDir.delete(recursive: true);
    expect(await cleanupOrphanAttachments(db, files), 0);
  });

  test(
    'A missing parent directory is not counted as a cleanup failure',
    () async {
      expect(
        await cleanupPurgedAttachments(db, files, [
          'attachments/no-such-dir.png',
        ]),
        0,
      );
    },
  );

  test('Purged cleanup still deletes an existing unreferenced file', () async {
    final file = await orphan('stale.png');
    expect(
      await cleanupPurgedAttachments(db, files, ['attachments/stale.png']),
      0,
    );
    expect(await file.exists(), false);
  });
}
