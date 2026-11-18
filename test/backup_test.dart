import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/backup/backup_service.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/language_learning/exam_bundled.dart';
import 'package:tixun/features/language_learning/exam_material.dart';
import 'package:tixun/features/language_learning/exam_store.dart';
import 'package:tixun/features/language_learning/sentence_content.dart';
import 'package:tixun/features/language_learning/writing_store.dart';
import 'package:tixun/features/language_learning/writing_task_ai.dart';
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
    await c.timeline.save(
      title: '期中考',
      start: DateTime(2027, 4, 5),
      end: DateTime(2027, 4, 6),
      notes: '带准考证',
    );
    await c.savePrompt('guided', '保留我的教学偏好。');
    await c.setLanguage('en');
    await c.setDynamicColors(false);
    await c.setSessionReasoning('off');
    await c.keys.write(providerKeyId(c.config), 'test-key-never-exported-9837');
    return note.id;
  }

  test('Complete backup round-trip and undo preserve relational data, managed images, drafts and external keys', () async {
    final note = await fixture();
    final context = await c.db.select(c.db.chatContextEvents).get();
    expect(context, hasLength(2));
    final sample = bundledExamPapers(ExamKind.grammar).single;
    final material = await c.language.saveExamMaterial(
      target: const ExamTarget(
        kind: ExamKind.grammar,
        level: SentenceLevel.beginner,
        count: 5,
      ),
      paper: sample.paper,
      source: ExamSource.bundled,
      id: sample.id,
    );
    await c.language.submitExam(
      material: material,
      attemptId: 'backup-language-exam',
      responses: sample.paper.items.map((item) => item.answers.first).toList(),
      confidence: ExamConfidence.unsure,
      hintUsed: false,
    );
    final writing =
        await WritingTaskAi(
          store: c.language,
          provider: MockChatProvider(),
          config: c.config,
        ).generate(
          kind: WritingTaskKind.continuation,
          level: SentenceLevel.beginner,
          topic: 'Market',
          cancel: CancelToken(),
        );
    await c.language.snapshotWriting(
      'Maya asked for directions.',
      taskId: writing.id,
    );
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
    final savedExam = ExamMaterial(
      await c.db.select(c.db.learningExamMaterials).getSingle(),
    );
    expect(savedExam.paper.fingerprint, sample.paper.fingerprint);
    final savedAttempt =
        (await c.language.examHistory(savedExam.row.id).first).single;
    expect(savedAttempt.confidence, ExamConfidence.unsure);
    expect(savedAttempt.matched, 5);
    final savedWriting = openWritingTask(
      await c.db.select(c.db.learningWritingTasks).getSingle(),
    );
    expect(savedWriting.passage, writing.passage);
    expect(
      await c.language.writingDraft(taskId: savedWriting.id),
      'Maya asked for directions.',
    );
    final timeline = (await c.db.select(c.db.timelineEvents).get()).single;
    expect(timeline.title, '期中考');
    expect(timeline.notes, '带准考证');
    expect(timeline.endDate!.toUtc(), DateTime.utc(2027, 4, 6));
    expect(c.selected!.draft, '待发送草稿');
    expect(c.languageChoice, 'en');
    expect(c.dynamicColors, false);
    expect(c.sessionReasoning, 'off');
    expect(c.prompts.text('guided'), '保留我的教学偏好。');
    expect(c.prompts.text('global'), startsWith('You are TiXun'));
    expect(c.selected!.toolsEnabled, false);
    expect(c.messages.length, 2);
    expect(
      await c.db.select(c.db.chatContextEvents).get(),
      unorderedEquals(context),
    );
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
  test(
    'backup restores private question/solution pins and the current draft',
    () async {
      final id = await c.practice.create(
        const QuestionSpec(
          kind: 'read_value',
          stem: 'Read figure',
          answers: [
            ['2'],
          ],
          questionScene: {
            'v': 1,
            'kind': 'geometry',
            'title': 'QUESTION',
            'elements': [
              {
                'id': 'p',
                'type': 'point',
                'at': [2, 0],
              },
            ],
          },
          solutionScene: {
            'v': 1,
            'kind': 'geometry',
            'title': 'SOLUTION',
            'elements': [
              {
                'id': 's',
                'type': 'text',
                'at': [0, 0],
                'text': 'Answer 2',
              },
            ],
          },
        ),
      );
      final attempt = await c.practice.begin(id);
      await c.practice.draft(attempt.id, ['1']);
      final original = await c.practice.detail(id);
      final backup = File('${parent.path}/figures.tixun-backup');
      await BackupService.export(c.db, c.files, backup);
      await c.visual.revise(
        original.spec.solutionVisualId!,
        jsonEncode({
          'v': 1,
          'kind': 'geometry',
          'title': 'LATER',
          'elements': [
            {
              'id': 'p',
              'type': 'point',
              'at': [0, 0],
            },
          ],
        }),
      );
      final prepared = await BackupService.prepare(backup, root);
      final keys = c.keys;
      await c.shutdown();
      final activation = await BackupService.activate(prepared, root);
      c = await AppController.openRoot(
        root,
        demo: false,
        keyStore: keys,
        chatProvider: MockChatProvider(),
      );
      await BackupService.finish(activation);
      await prepared.discard();
      final restored = await c.practice.detail(id);
      expect(restored.visualLinks, original.visualLinks);
      expect(restored.solutionVisualLinks, original.solutionVisualLinks);
      expect(restored.latest!.status, 'draft');
      expect(restored.responses[attempt.id], ['1']);
      expect(
        await c.visual.getRevisionSceneJson(
          restored.spec.solutionVisualId!,
          restored.spec.solutionVisualRevision!,
        ),
        contains('SOLUTION'),
      );
      expect(await c.db.select(c.db.visualMessageLinks).get(), isEmpty);
      expect(
        await c.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

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
  test(
    'Activation killed between the two renames resumes from staging',
    () async {
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
      // Simulate a kill after `root -> previous` but before
      // `staging/data -> root`: move the new data back into staging and
      // leave the live directory missing.
      await root.rename(prepared.data.path);
      await BackupService.recoverPending(root);
      c = await AppController.openRoot(
        root,
        demo: false,
        keyStore: MemoryKeyStore(),
        chatProvider: MockChatProvider(),
      );
      expect((await c.study.knowledge(note)).content, '恢复前的内容');
      // The old data is still kept as the undo point.
      expect(await BackupService.previousRoot(root), isNotNull);
      await prepared.discard();
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
