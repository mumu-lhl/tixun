import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/backup/backup_service.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/features/exams/exam_ai.dart';
import 'package:tixun/features/exams/exam_store.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late ExamStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('tixun-exams');
    db = AppDatabase.file(File('${root.path}/tixun.sqlite'));
    store = ExamStore(db, AttachmentStore(root));
  });
  tearDown(() async {
    store.dispose();
    await db.close();
    await root.delete(recursive: true);
  });
  test('Calendar scopes dates, main subjects never retain scaled scores, unknown differs from zero', () async {
    final id = await store.saveEvent(
      title: '期中考试',
      date: DateTime(2026, 11, 9, 14),
    );
    await store.saveEvent(title: '另一次考试', date: DateTime(2026, 12, 1));
    expect(
      (await store.watchMonth(DateTime(2026, 11)).first).single.date.toUtc(),
      DateTime.utc(2026, 11, 9),
    );
    await store.saveSubject(
      eventId: id,
      subject: '数学',
      raw: 122.5,
      maximum: 150,
      scaling: true,
      scaled: 140,
    );
    await store.saveSubject(
      eventId: id,
      subject: '化学',
      raw: 0,
      maximum: 100,
      scaling: true,
      scaled: 30,
    );
    await store.saveSubject(eventId: id, subject: '自定义学科');
    final rows = await db.select(db.examSubjects).get();
    final math = rows.firstWhere((r) => r.subject == '数学');
    expect(math.scaledScore, isNull);
    expect(math.usesScaling, false);
    expect(rows.firstWhere((r) => r.subject == '化学').rawScore, 0);
    expect(rows.firstWhere((r) => r.subject == '自定义学科').rawScore, isNull);
    await expectLater(
      store.saveSubject(eventId: id, subject: '数学'),
      throwsA(anything),
    );
  });
  test('Hierarchical totals do not double count; invalid and stale writes preserve scores', () async {
    final exam = await store.saveEvent(title: '考试', date: DateTime.now());
    final id = await store.saveSubject(eventId: exam, subject: '数学');
    final parent = ScoreDraft(label: '17', earned: 10, maximum: 12);
    final rows = [
      parent,
      ScoreDraft(parentId: parent.id, label: '1', earned: 4, maximum: 5),
      ScoreDraft(parentId: parent.id, label: '2', maximum: 7),
      ScoreDraft(label: '18', earned: 8, maximum: 10),
    ];
    expect(scoreTotals(rows), (12.0, 22.0, false));
    final before =
        (await db.select(db.examSubjects).get()).single.scoreRevision;
    await store.saveRows(id, rows, expected: before);
    await expectLater(
      store.saveRows(id, [], expected: before),
      throwsFormatException,
    );
    for (final invalid in [
      [ScoreDraft(label: '1', earned: 6, maximum: 5)],
      [ScoreDraft(label: '1', parentId: 'missing')],
      [ScoreDraft(label: '1'), ScoreDraft(label: '1')],
    ]) {
      await expectLater(store.saveRows(id, invalid), throwsFormatException);
    }
    expect(await db.select(db.examScoreRows).get(), hasLength(4));
    expect((await db.select(db.examSubjects).get()).single.rawScore, isNull);
  });
  test('Original photos survive source deletion and backup, cascade deletion cleans references', () async {
    final exam = await store.saveEvent(title: '照片考试', date: DateTime.now());
    final id = await store.saveSubject(eventId: exam, subject: '物理');
    final source = File('${root.path}/source.png');
    await source.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j/ZkAAAAASUVORK5CYII=',
      ),
    );
    await store.addImage(id, 'sheet', source.path);
    await source.delete();
    final photo = (await db.select(db.examAttachments).get()).single;
    expect(await store.files.resolve(photo.relativePath).exists(), true);
    final archive = File('${root.path}/exam.tixun-backup');
    await BackupService.export(db, store.files, archive);
    final prepared = await BackupService.prepare(archive, root);
    final restored = AppDatabase.file(
      File('${prepared.data.path}/tixun.sqlite'),
    );
    expect(await restored.select(restored.examAttachments).get(), hasLength(1));
    expect(
      await File('${prepared.data.path}/${photo.relativePath}').exists(),
      true,
    );
    await restored.close();
    await prepared.discard();
    await store.saveRows(id, [ScoreDraft(label: '1', earned: 0, maximum: 4)]);
    final other = await store.saveSubject(eventId: exam, subject: '化学');
    await store.saveRows(other, [
      ScoreDraft(label: '1', earned: 4, maximum: 5),
    ]);
    await store.deleteSubject(other);
    expect((await db.select(db.examSubjects).get()).single.id, id);
    expect(await store.files.resolve(photo.relativePath).exists(), true);
    await store.deleteEvent(exam);
    expect(await db.select(db.examSubjects).get(), isEmpty);
    expect(await db.select(db.examScoreRows).get(), isEmpty);
    expect(await db.select(db.examAttachments).get(), isEmpty);
    expect(await store.files.resolve(photo.relativePath).exists(), false);
  });
  test('Exam crop preserves originals across repeat edits, backup and deletion; stale writes fail', () async {
    final event = await store.saveEvent(title: '考试', date: DateTime.now());
    final subject = await store.saveSubject(eventId: event, subject: '数学');
    final image = await store.addImage(
      subject,
      'sheet',
      'assets/demo/two_problems.png',
    );
    final original = await store.files
        .resolve(image.relativePath)
        .readAsBytes();
    final copy = Uint8List.fromList(original);
    await store.replaceImage(image, copy);
    final edited = (await db.select(db.examAttachments).get()).single;
    expect(edited.originalPath, image.relativePath);
    expect(
      await store.files.resolve(image.relativePath).readAsBytes(),
      original,
    );
    await expectLater(store.replaceImage(image, copy), throwsFormatException);
    await store.replaceImage(edited, copy);
    final second = (await db.select(db.examAttachments).get()).single;
    expect(second.originalPath, image.relativePath);
    expect(await store.files.resolve(edited.relativePath).exists(), false);
    final backup = File('${root.path}/crop.tixun-backup');
    await BackupService.export(db, store.files, backup);
    final prepared = await BackupService.prepare(backup, root);
    expect(
      await File('${prepared.data.path}/${image.relativePath}').readAsBytes(),
      original,
    );
    expect(
      await File('${prepared.data.path}/${second.relativePath}').exists(),
      true,
    );
    await prepared.discard();
    await store.files.resolve(image.relativePath).delete();
    await expectLater(
      BackupService.export(db, store.files, backup),
      throwsFormatException,
    );
    await store.files.resolve(image.relativePath).writeAsBytes(original);
    // Deletion receives a stale UI row but must purge the latest edit and original.
    await store.deleteImage(image);
    expect(await store.files.resolve(second.relativePath).exists(), false);
    expect(await store.files.resolve(image.relativePath).exists(), false);
    expect(await db.select(db.examAttachments).get(), isEmpty);
  });
  test('AI accepts explicit unknown scores and rejects malformed or impossible output', () {
    final rows = parseExamScores(
      '{"questions":[{"label":"17","children":[{"label":"1","earned":null,"maximum":5,"note":"缺少评分依据"}]}]}',
    );
    expect(rows.last.parentId, rows.first.id);
    expect(rows.last.earned, isNull);
    for (final json in [
      '{}',
      '{"questions":[]}',
      '{"questions":[{"label":"1","earned":8,"maximum":5}]}',
      '{"questions":[{"label":"1","earned":"5"}]}',
      '{"questions":[{"label":"1"},{"label":"1"}]}',
    ]) {
      expect(() => parseExamScores(json), throwsFormatException);
    }
  });
  test('AI score parsing tolerates fences with trailing prose and keeps the raw reply on failure', () {
    const json = '{"questions":[{"label":"1","earned":4,"maximum":5}]}';
    for (final wrapped in [
      '```json\n$json\n```',
      '```JSON\n$json\n```\n以上是小分表',
      '``` json\n$json\n```',
      '先看小分表：\n```\n$json\n```\n请核对。',
      '小分表如下：$json（完）',
    ]) {
      expect(parseExamScores(wrapped).single.earned, 4);
    }
    const bad =
        '```json\n{"questions":[{"label":"1","earned":"5"}]}\n```\n以上是小分表';
    try {
      parseExamScores(bad);
      fail('expected a parse failure');
    } on ExamScoresParseFailure catch (e) {
      expect(e.rawText, bad);
      expect(e, isA<FormatException>());
    }
  });
  test('AI vision checks, scoped images, completed streaming and cancellation are enforced', () async {
    final image = File('${root.path}/image.png');
    await image.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j/ZkAAAAASUVORK5CYII=',
      ),
    );
    final imported = await store.files.importFile(image.path);
    final photo = ExamAttachment(
      id: 'i',
      subjectId: 's',
      role: 'sheet',
      relativePath: imported.path,
      mime: imported.mime,
      createdAt: DateTime.now(),
    );
    final provider = _Provider();
    const config = ProviderConfig(
      id: 1,
      kind: 'deepseek',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-flash',
      vision: true,
      supportsTools: true,
      thinking: true,
      supportsThinking: true,
      effort: 'high',
    );
    Future<List<ScoreDraft>> generate(
      ProviderConfig config,
      CancelToken cancel,
    ) => generateExamScores(
      provider: provider,
      config: config,
      files: store.files,
      images: [photo],
      prompt: '测试',
      subject: '数学',
      cancel: cancel,
      onReasoning: (_) {},
    );
    await expectLater(
      generate(config.copyWith(vision: false), CancelToken()),
      throwsFormatException,
    );
    expect(provider.request, isNull);
    expect((await generate(config, CancelToken())).single.earned, 4);
    expect(provider.request!.messages.single.images, hasLength(1));
    expect(provider.request!.tools, isEmpty);
    provider.complete = false;
    await expectLater(
      generate(config, CancelToken()),
      throwsA(isA<AiFailure>()),
    );
    final cancelled = CancelToken()..cancel();
    await expectLater(
      generate(config, cancelled),
      throwsA(isA<DioException>()),
    );
  });
}

class _Provider implements ChatProvider {
  AiRequest? request;
  bool complete = true;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((r, c) async* {
        request = r;
        yield const AiChunk(reasoning: '核对图片');
        yield const AiChunk(
          text: '{"questions":[{"label":"1","earned":4,"maximum":5}]}',
        );
        if (complete) yield const AiChunk(completed: true);
      });
}
