import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/study_tools.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/backup/backup_service.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/library/module_store.dart';

void main() {
  late StudyStore store;
  setUp(() async {
    store = StudyStore(
      AppDatabase.memory(),
      AttachmentStore(await Directory.systemTemp.createTemp('tixun-modules')),
    );
  });
  tearDown(() async {
    store.dispose();
    await store.db.close();
    await store.files.root.delete(recursive: true);
  });
  test('Shared curriculum is ordered, deduplicated and limited to two levels in the same subject', () async {
    final root = await store.modules.create('数学', '函数');
    final child = await store.modules.create('数学', '单调性', parentId: root);
    expect(await store.modules.create('数学', '函数'), root);
    expect(await store.modules.create('数学', '单调性', parentId: root), child);
    expect(
      modulePath(
        (await store.modules.list('数学')).last,
        await store.modules.list('数学'),
      ),
      '函数 / 单调性',
    );
    await expectLater(
      store.modules.create('物理', '力学', parentId: root),
      throwsFormatException,
    );
    await expectLater(
      store.modules.create('数学', '第三层', parentId: child),
      throwsFormatException,
    );
    final second = await store.modules.create('数学', '几何');
    await store.modules.move(second, -1);
    expect(
      (await store.modules.list('数学'))
          .where((m) => m.parentId == null)
          .first
          .id,
      second,
    );
    await store.modules.rename(root, '函数与导数');
    expect(
      (await store.modules.list('数学')).firstWhere((m) => m.id == root).name,
      '函数与导数',
    );
  });
  test('Knowledge and mistakes filter by parent, child, text, subject and unclassified without duplicate rows', () async {
    final root = await store.modules.create('数学', '函数');
    final child = await store.modules.create('数学', '单调性', parentId: root);
    final note = await store.saveKnowledge(
      const KnowledgeDraft(title: '单调性的定义', content: '在区间上比较函数值'),
    );
    final mistake = await store.saveMistake(
      const MistakeDraft(title: '求参数的范围'),
    );
    final other = await store.saveKnowledge(
      const KnowledgeDraft(title: '旧资料', content: '', chapter: '旧章节'),
    );
    await store.modules.assign(note.id, false, [root, child]);
    await store.modules.assign(mistake.id, true, [child]);
    expect((await store.searchKnowledge(moduleId: root)).single.id, note.id);
    expect(
      (await store.searchKnowledge(moduleId: child, query: '单调性')).single.id,
      note.id,
    );
    expect(
      await store.searchKnowledge(moduleId: child, subject: '物理'),
      isEmpty,
    );
    expect((await store.searchMistakes(moduleId: root)).single.id, mistake.id);
    expect(
      (await store.searchKnowledge(moduleId: 'unclassified')).single.id,
      other.id,
    );
    expect((await store.knowledge(other.id)).chapter, '旧章节');
  });
  test(
    'Cross-subject and stale replacement cannot change existing associations',
    () async {
      final root = await store.modules.create('数学', '函数');
      final physics = await store.modules.create('物理', '力学');
      final note = await store.saveKnowledge(
        const KnowledgeDraft(title: '知识', content: '正文'),
      );
      await store.modules.assign(note.id, false, [root], expected: []);
      await expectLater(
        store.modules.assign(note.id, false, [], expected: []),
        throwsFormatException,
      );
      await expectLater(
        store.modules.assign(note.id, false, [physics]),
        throwsFormatException,
      );
      expect(await store.modules.ids(note.id, false), [root]);
      await store.modules.link(note.id, false, root);
      expect(await store.modules.ids(note.id, false), [root]);
    },
  );
  test('Changing subject removes incompatible links; deleting folders preserves study material', () async {
    final root = await store.modules.create('数学', '函数');
    final child = await store.modules.create('数学', '单调性', parentId: root);
    final note = await store.saveKnowledge(
      const KnowledgeDraft(title: '知识', content: '正文'),
    );
    final mistake = await store.saveMistake(const MistakeDraft(title: '错题'));
    await store.modules.assign(note.id, false, [child]);
    await store.modules.assign(mistake.id, true, [root, child]);
    await store.saveKnowledge(
      const KnowledgeDraft(title: '知识', content: '正文', subject: '物理'),
      id: note.id,
      expectedRevision: note.revision,
    );
    expect(await store.modules.ids(note.id, false), isEmpty);
    await store.modules.delete(root);
    expect(await store.modules.list('数学'), isEmpty);
    expect(await store.modules.ids(mistake.id, true), isEmpty);
    expect((await store.mistake(mistake.id)).title, '错题');
    expect((await store.knowledge(note.id)).subject, '物理');
  });
  test(
    'Complete backup restores shared hierarchy and both types of association',
    () async {
      final parent = await store.modules.create('数学', '函数');
      final child = await store.modules.create('数学', '单调性', parentId: parent);
      final note = await store.saveKnowledge(
        const KnowledgeDraft(title: '知识', content: '正文'),
      );
      final mistake = await store.saveMistake(const MistakeDraft(title: '错题'));
      await store.modules.assign(note.id, false, [child]);
      await store.modules.assign(mistake.id, true, [parent, child]);
      final archive = File('${store.files.root.path}/modules.tixun-backup');
      await BackupService.export(store.db, store.files, archive);
      final prepared = await BackupService.prepare(archive, store.files.root);
      final restored = AppDatabase.file(
        File('${prepared.data.path}/tixun.sqlite'),
      );
      expect(
        await restored.select(restored.subjectModules).get(),
        hasLength(2),
      );
      expect(
        (await restored.select(restored.knowledgeModuleLinks).get())
            .single
            .moduleId,
        child,
      );
      expect(
        await restored.select(restored.mistakeModuleLinks).get(),
        hasLength(2),
      );
      await restored.close();
      await prepared.discard();
    },
  );

  test('AI can inspect, create and link modules only through explicit permissions and approval', () async {
    final session = await store.db.createSession();
    final note = await store.saveKnowledge(
      const KnowledgeDraft(title: '待分类知识', content: '知识正文'),
    );
    var callId = 0;
    Future<Map<String, dynamic>> call(
      String name,
      Map<String, dynamic> args, {
      bool authorized = true,
      bool approve = true,
    }) => StudyToolRunner(
      store,
      sessionId: session.id,
      runId: 'run-${++callId}',
      authorized: authorized,
      confirm: (_, _) async => approve,
    ).execute(ToolCall('$callId', name, jsonEncode(args)), CancelToken());
    final args = {'subject': '数学', 'name': '函数'};
    expect(
      (await call('create_subject_module', args, authorized: false))['ok'],
      false,
    );
    expect(
      (await call('create_subject_module', args, approve: false))['ok'],
      false,
    );
    expect(await store.modules.list('数学'), isEmpty);
    final result = await call('create_subject_module', args);
    expect(result['ok'], true);
    final id = result['id'] as String;
    expect(
      (await call('list_subject_modules', {'subject': '数学'}))['modules'],
      hasLength(1),
    );
    expect(
      (await call('link_study_module', {
        'id': note.id,
        'kind': 'knowledge',
        'module_id': id,
      }, approve: false))['ok'],
      false,
    );
    expect(await store.modules.ids(note.id, false), isEmpty);
    expect(
      (await call('link_study_module', {
        'id': note.id,
        'kind': 'knowledge',
        'module_id': id,
      }))['ok'],
      true,
    );
    expect((await call('get_knowledge', {'id': note.id}))['module_ids'], [id]);
    expect(
      (await call('search_knowledge', {'module_id': id}))['items'],
      hasLength(1),
    );
    expect(
      (await call('link_study_module', {
        'id': note.id,
        'kind': 'sql',
        'module_id': id,
      }))['ok'],
      false,
    );
  });
}
