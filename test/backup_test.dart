import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/backup/backup_service.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/practice/question_spec.dart';

void main() {
  late Directory parent, root;
  late AppController c;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('tixun-backup-test');
    root = Directory('${parent.path}/app');
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
      chatProvider: MockChatProvider(),
    );
    await c.newSession();
  });
  tearDown(() async {
    await c.db.close();
    c.dispose();
    if (await parent.exists()) await parent.delete(recursive: true);
  });
  Future<String> fixture() async {
    await c.addImage('assets/demo/two_problems.png');
    final original = c.attachments.single;
    await c.replaceDraftImage(
      original,
      await c.files.resolve(original.relativePath).readAsBytes(),
    );
    await c.send('请解释题目');
    await c.draft('待发送草稿');
    final note = await c.study.saveKnowledge(
      const KnowledgeDraft(title: '备份知识', content: '恢复前的内容', tags: ['函数']),
    );
    final mistake = await c.study.saveMistake(
      const MistakeDraft(title: '原题', question: '2+2', correctAnswer: '4'),
    );
    final a = c.attachments.first;
    await c.study.addImageReference(
      mistake.id,
      a.relativePath,
      a.mime,
      a.byteLength,
      isMistake: true,
    );
    await c.study.link(note.id, mistakeId: mistake.id);
    final q = await c.practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '2+2',
        answers: [
          ['4'],
        ],
        topics: ['加法'],
      ),
      mistakeId: mistake.id,
      knowledgeIds: [note.id],
    );
    await c.practice.submit((await c.practice.begin(q)).id, ['4']);
    await c.setTools(true);
    await c.keys.write(providerKeyId(c.config), 'test-key-never-exported-9837');
    return note.id;
  }

  test('Complete backup round-trip and undo preserve relational data, managed images, drafts and external keys', () async {
    final note = await fixture();
    final backup = File('${parent.path}/complete.tixun-backup');
    final preview = await BackupService.export(c.db, c.files, backup);
    expect(preview.counts['attempts'], 1);
    expect(preview.counts['reviews'], 1);
    expect(preview.files, 2);
    expect(
      latin1.decode(await backup.readAsBytes()),
      isNot(contains('test-key-never-exported-9837')),
    );
    final old = await c.study.knowledge(note);
    await c.study.saveKnowledge(
      const KnowledgeDraft(title: '备份知识', content: '备份后的改动'),
      id: note,
      expectedRevision: old.revision,
    );
    final prepared = await BackupService.prepare(backup, root);
    expect(
      (await c.study.knowledge(note)).content,
      '备份后的改动',
      reason: 'Preview never modifies live data',
    );
    final keys = c.keys;
    await c.db.close();
    c.dispose();
    final activation = await BackupService.activate(prepared, root);
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: keys,
      chatProvider: MockChatProvider(),
    );
    await BackupService.finish(activation);
    await prepared.discard();
    expect((await c.study.knowledge(note)).content, '恢复前的内容');
    expect(c.selected!.draft, '待发送草稿');
    expect(c.selected!.toolsEnabled, false);
    expect(c.messages.length, 2);
    expect(
      (await c.db.select(c.db.practiceAttempts).get()).single.correct,
      true,
    );
    expect((await c.db.select(c.db.reviewRecords).get()).length, 1);
    expect((await c.db.select(c.db.mistakeKnowledgeLinks).get()).length, 1);
    for (final image in await c.db.select(c.db.attachments).get()) {
      expect(await c.files.resolve(image.relativePath).exists(), true);
      expect(image.originalPath, isNotNull);
      expect(await c.files.resolve(image.originalPath!).exists(), true);
    }
    expect(
      await c.keys.read(providerKeyId(c.config)),
      'test-key-never-exported-9837',
    );
    expect(await c.db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    final undo = await BackupService.preparePrevious(root);
    await c.db.close();
    c.dispose();
    final undoReceipt = await BackupService.activate(undo, root);
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: keys,
      chatProvider: MockChatProvider(),
    );
    await BackupService.finish(undoReceipt);
    await undo.discard();
    expect((await c.study.knowledge(note)).content, '备份后的改动');
    expect(await BackupService.previousRoot(root), isNotNull);
    await BackupService.clearPrevious(root);
    expect(await BackupService.previousRoot(root), isNull);
    await expectLater(
      BackupService.preparePrevious(root),
      throwsFormatException,
    );
    expect((await c.study.knowledge(note)).content, '备份后的改动');
  });
  test('Damaged archives, traversal, duplicate paths and future versions never change live data', () async {
    final note = await fixture();
    final good = File('${parent.path}/good.tixun-backup');
    await BackupService.export(c.db, c.files, good);
    final damaged = File('${parent.path}/broken.tixun-backup');
    final bytes = await good.readAsBytes();
    bytes[100] ^= 0x7f;
    await damaged.writeAsBytes(bytes);
    await expectLater(
      BackupService.prepare(damaged, root),
      throwsFormatException,
    );
    Future<File> zip(String name, List<ArchiveFile> entries) async {
      final file = File('${parent.path}/$name');
      final encoder = ZipFileEncoder()
        ..create(file.path, level: ZipFileEncoder.store);
      for (final e in entries) {
        encoder.addArchiveFile(e);
      }
      await encoder.close();
      return file;
    }

    final traversal = await zip('traversal.zip', [
      ArchiveFile.string('../escape.txt', 'bad'),
    ]);
    await expectLater(
      BackupService.prepare(traversal, root),
      throwsFormatException,
    );
    expect(await File('${parent.path}/escape.txt').exists(), false);
    final duplicate = await zip('duplicate.zip', [
      ArchiveFile.string('database.sqlite', 'a'),
      ArchiveFile.string('database.sqlite', 'b'),
    ]);
    await expectLater(
      BackupService.prepare(duplicate, root),
      throwsFormatException,
    );
    final future = await zip('future.zip', [
      ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'format': 'tixun-backup',
          'version': 1,
          'schema': 999,
          'created_at': '2030-01-01',
          'files': [],
        }),
      ),
    ]);
    await expectLater(
      BackupService.prepare(future, root),
      throwsFormatException,
    );
    expect((await c.study.knowledge(note)).content, '恢复前的内容');
    expect(
      (await parent.list().toList()).where(
        (e) => e.path.contains('.tixun-stage-'),
      ),
      isEmpty,
    );
  });
  test(
    'Missing originals prevent export and leave an existing backup untouched',
    () async {
      await fixture();
      final output = File('${parent.path}/keep.tixun-backup');
      await output.writeAsString('existing backup');
      final image = (await c.db.select(c.db.attachments).get()).first;
      await c.files.resolve(image.relativePath).delete();
      await expectLater(
        BackupService.export(c.db, c.files, output),
        throwsFormatException,
      );
      expect(await output.readAsString(), 'existing backup');
    },
  );
  test('Interrupted directory activation recovers the original when the live name is missing', () async {
    final note = await fixture();
    final output = File('${parent.path}/backup.tixun-backup');
    await BackupService.export(c.db, c.files, output);
    final old = await c.study.knowledge(note);
    await c.study.saveKnowledge(
      const KnowledgeDraft(title: '备份知识', content: '恢复操作之前的新内容'),
      id: note,
      expectedRevision: old.revision,
    );
    final prepared = await BackupService.prepare(output, root);
    await c.db.close();
    c.dispose();
    await BackupService.activate(prepared, root);
    await root.rename('${parent.path}/interrupted-new-data');
    await BackupService.recoverPending(root);
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
      chatProvider: MockChatProvider(),
    );
    expect((await c.study.knowledge(note)).content, '恢复操作之前的新内容');
    expect(await BackupService.previousRoot(root), isNull);
    await prepared.discard();
  });
}
