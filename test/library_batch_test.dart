import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/practice/question_spec.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late StudyStore store;
  late PracticeStore practice;
  setUp(() async {
    db = AppDatabase.memory();
    root = await Directory.systemTemp.createTemp('tixun-batch');
    final files = AttachmentStore(root);
    store = StudyStore(db, files);
    practice = PracticeStore(db, files: files);
  });
  tearDown(() async {
    await store.whenIdle;
    await practice.whenIdle;
    store.dispose();
    practice.dispose();
    await db.close();
    await root.delete(recursive: true);
  });
  test('Batch mutations roll back all versions on conflict; undo and permanent purge preserve shared images', () async {
    final a = await store.saveKnowledge(
      const KnowledgeDraft(title: '分页资料 A', content: '二次函数'),
    );
    final b = await store.saveKnowledge(
      const KnowledgeDraft(title: '分页资料 B', content: '导数'),
    );
    await expectLater(
      store.batchSetDeleted(
        {a.id: a.revision, b.id: b.revision + 1},
        isMistake: false,
        deleted: true,
      ),
      throwsA(isA<StudyConflict>()),
    );
    expect((await store.knowledge(a.id)).revision, 1);
    expect((await store.searchKnowledge()).length, 2);
    final deleted = await store.batchSetDeleted(
      {a.id: 1, b.id: 1},
      isMistake: false,
      deleted: true,
    );
    expect(await store.searchKnowledge(), isEmpty);
    final restored = await store.batchSetDeleted(
      deleted,
      isMistake: false,
      deleted: false,
    );
    expect(restored.values.toSet(), {3});
    final image = await store.importImage(
      a.id,
      'assets/demo/two_problems.png',
      isMistake: false,
    );
    await store.addImageReference(
      b.id,
      image.relativePath,
      image.mime,
      image.byteLength,
      isMistake: false,
    );
    await store.setDeleted(
      a.id,
      isMistake: false,
      deleted: true,
      expectedRevision: 3,
    );
    expect(await store.purge({a.id: 4}, isMistake: false), 0);
    expect(await store.files.resolve(image.relativePath).exists(), true);
    await store.setDeleted(
      b.id,
      isMistake: false,
      deleted: true,
      expectedRevision: 3,
    );
    expect(await store.purge({b.id: 4}, isMistake: false), 0);
    expect(await store.files.resolve(image.relativePath).exists(), false);
    expect(await store.searchKnowledge(query: '分页', trash: true), isEmpty);
    expect(await db.select(db.knowledgeRevisions).get(), isEmpty);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('Stable paged FTS results cover all data and active crop selection respects removed images', () async {
    for (var i = 0; i < 25; i++) {
      await store.saveKnowledge(
        KnowledgeDraft(
          title: '测试分页 $i',
          content: '完整检索资料',
          subject: i.isEven ? '数学' : '物理',
        ),
      );
    }
    final all = <String>{};
    for (var offset = 0; offset < 25; offset += 10) {
      all.addAll(
        (await store.searchKnowledge(
          query: '完整检索',
          limit: 10,
          offset: offset,
        )).map((k) => k.id),
      );
    }
    expect(all.length, 25);
    expect(
      (await store.searchKnowledge(
        subject: '数学',
        offset: 10,
        limit: 10,
      )).length,
      3,
    );
    final m = await store.saveMistake(const MistakeDraft(title: '原图'));
    final original = await store.importImage(
      m.id,
      'assets/demo/two_problems.png',
      isMistake: true,
    );
    final copy = await store.files.importFile(
      store.files.resolve(original.relativePath).path,
    );
    final removed = await store.addImageReference(
      m.id,
      copy.path,
      copy.mime,
      copy.bytes,
      isMistake: true,
      parentId: original.id,
      role: 'crop',
    );
    await store.removeImage(removed);
    final q = await practice.create(
      const QuestionSpec(kind: 'short_answer', stem: '重做原题', answers: []),
      mistakeId: m.id,
    );
    expect(
      (await practice.detail(q)).images.single.relativePath,
      original.relativePath,
    );
    await store.restoreImage(removed);
    final edited = await practice.create(
      const QuestionSpec(kind: 'short_answer', stem: '重做编辑题', answers: []),
      mistakeId: m.id,
    );
    expect(
      (await practice.detail(edited)).images.single.relativePath,
      removed.relativePath,
    );
    await store.setDeleted(
      m.id,
      isMistake: true,
      deleted: true,
      expectedRevision: m.revision,
    );
    await store.purge({m.id: m.revision + 1}, isMistake: true);
    expect(
      await store.files.resolve(original.relativePath).exists(),
      true,
      reason: 'Earlier independent practice still references the original',
    );
    await practice.setDeleted(q, true);
    await practice.purge(q);
    expect(await store.files.resolve(original.relativePath).exists(), false);
    expect(await store.files.resolve(removed.relativePath).exists(), true);
    await practice.setDeleted(edited, true);
    await practice.purge(edited);
    expect(await store.files.resolve(removed.relativePath).exists(), false);
  });
  test('Quiescence waits for queued database writes; drafts flush in order and long histories are bounded', () async {
    final release = Completer<void>(), entered = Completer<void>();
    final lock = db.transaction(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final write = store.saveKnowledge(
      const KnowledgeDraft(title: '尚在写入', content: '已完成后才能关闭数据库'),
    );
    var idle = false;
    final drained = store.whenIdle.then((_) => idle = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(idle, false);
    release.complete();
    await lock;
    await write;
    await drained;
    expect(idle, true);
    final id = await practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '1+1',
        answers: [
          ['2'],
        ],
      ),
    );
    for (var i = 0; i < 55; i++) {
      final a = await practice.begin(id, retry: true);
      final drafts = [
        practice.draft(a.id, ['1']),
        practice.draft(a.id, ['2']),
      ];
      await practice.flushDrafts();
      await Future.wait(drafts);
      await practice.submit(a.id, ['2']);
    }
    final detail = await practice.detail(id);
    expect(detail.attempts.length, 50);
    expect(detail.responses.length, 50);
    expect(detail.latest!.correct, true);
    expect(
      (await db.select(db.practiceAttempts).get()).length,
      55,
      reason: 'Older records stay in the database for diagnosis and backup',
    );
  });
}
