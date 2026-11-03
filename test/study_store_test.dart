import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/features/library/study_store.dart';

void main() {
  late StudyStore store;
  setUp(() async {
    store = StudyStore(
      AppDatabase.memory(),
      AttachmentStore(
        await Directory.systemTemp.createTemp('tixun-study-test'),
      ),
    );
  });
  tearDown(() async {
    store.dispose();
    await store.db.close();
    await store.files.root.delete(recursive: true);
  });
  test('Knowledge search, normalized tags, revisions, conflict detection and recovery', () async {
    final first = await store.saveKnowledge(
      const KnowledgeDraft(
        title: '二次函数',
        content: '通过配方求顶点，理解对称轴。',
        tags: ['代数', '代数', ' 顶点 '],
      ),
    );
    expect(await store.tags(first.id, isMistake: false), ['代数', '顶点']);
    expect((await store.searchKnowledge(query: '求顶点')).single.id, first.id);
    expect((await store.searchKnowledge(query: '代数')).single.id, first.id);
    expect(await store.searchKnowledge(query: '" OR *'), isEmpty);
    final second = await store.saveKnowledge(
      const KnowledgeDraft(
        title: '配方法',
        content: '新版解释',
        subject: '自定义学科',
        kind: '解题方法',
      ),
      id: first.id,
      expectedRevision: 1,
    );
    await expectLater(
      store.saveKnowledge(
        const KnowledgeDraft(title: '过期', content: '不应覆盖'),
        id: first.id,
        expectedRevision: 1,
      ),
      throwsA(isA<StudyConflict>()),
    );
    expect((await store.knowledge(first.id)).content, '新版解释');
    expect((await store.revisions(first.id)).length, 2);
    final restored = await store.restoreRevision(first.id, 1, second.revision);
    expect(restored.revision, 3);
    expect(restored.content, first.content);
    await store.setDeleted(
      first.id,
      isMistake: false,
      deleted: true,
      expectedRevision: 3,
    );
    expect(await store.searchKnowledge(), isEmpty);
    final trashed = (await store.searchKnowledge(trash: true)).single;
    await store.setDeleted(
      first.id,
      isMistake: false,
      deleted: false,
      expectedRevision: trashed.revision,
    );
    expect((await store.knowledge(first.id)).content, first.content);
    expect((await store.revisions(first.id)).length, 5);
  });
  test('Mistake photos, reason provenance, links and soft-delete restoration persist', () async {
    final k = await store.saveKnowledge(
      const KnowledgeDraft(title: '配方', content: '平方项'),
    );
    final k2 = await store.saveKnowledge(
      const KnowledgeDraft(title: '最小值', content: '顶点纵坐标'),
    );
    final m = await store.importMistake(
      'assets/demo/two_problems.png',
      '真实格式的测试图片',
    );
    final image = (await store.images(m.id, isMistake: true)).single;
    await store.removeImage(image);
    expect(await store.images(m.id, isMistake: true), isEmpty);
    expect(
      (await store.images(m.id, isMistake: true, trash: true)).single.id,
      image.id,
    );
    await store.restoreImage(image);
    expect(await store.files.resolve(image.relativePath).exists(), true);
    final edited = await store.saveMistake(
      MistakeDraft(
        title: m.title,
        question: '二次函数问题',
        aiAnalysis: '待核对的解析',
        suggestedReason: '可能混淆常数项',
      ),
      id: m.id,
      expectedRevision: m.revision,
    );
    expect(edited.errorReason, '暂未确定');
    await store.link(k.id, mistakeId: m.id);
    await store.link(k.id, mistakeId: m.id);
    await store.link(k.id, otherKnowledgeId: k2.id);
    await store.link(k2.id, otherKnowledgeId: k.id);
    expect((await store.mistakeDetail(m.id)).knowledge.single.id, k.id);
    expect((await store.knowledgeDetail(k2.id)).related.single.id, k.id);
    expect((await store.knowledgeDetail(k.id)).mistakes.length, 1);
    await store.setDeleted(
      m.id,
      isMistake: true,
      deleted: true,
      expectedRevision: edited.revision,
    );
    expect((await store.knowledgeDetail(k.id)).mistakes, isEmpty);
    expect(await store.files.resolve(image.relativePath).exists(), true);
    final trash = await store.mistake(m.id, includeDeleted: true);
    await store.setDeleted(
      m.id,
      isMistake: true,
      deleted: false,
      expectedRevision: trash.revision,
    );
    expect((await store.knowledgeDetail(k.id)).mistakes.length, 1);
    await store.link(k.id, mistakeId: m.id, remove: true);
    expect((await store.mistakeDetail(m.id)).knowledge, isEmpty);
    await expectLater(
      store.link(k.id, otherKnowledgeId: k.id),
      throwsFormatException,
    );
  });
  test('Image import failure creates neither empty mistakes nor dangling attachments', () async {
    await expectLater(
      store.importMistake('pubspec.yaml', '无效图片'),
      throwsFormatException,
    );
    expect(await store.searchMistakes(), isEmpty);
    expect(await store.db.select(store.db.studyAttachments).get(), isEmpty);
  });
}
