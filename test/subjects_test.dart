import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/preferences.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_store.dart';

void main() {
  late Directory root;
  late AppController c;
  Future<AppController> open() => AppController.openRoot(
    root,
    demo: false,
    seed: false,
    keyStore: MemoryKeyStore(),
    chatProvider: MockChatProvider(),
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('tixun-subjects');
    c = await open();
  });
  tearDown(() async {
    await c.shutdown();
    await root.delete(recursive: true);
  });
  test('Fresh subject choices are compact and existing users retain recorded subjects', () async {
    expect(c.learningSubjects, ['语文', '数学', '英语']);
    await c.study.saveMistake(const MistakeDraft(title: '既有错题', subject: '物理'));
    await c.study.saveKnowledge(
      const KnowledgeDraft(title: '语言学习', content: '正文', subject: '日语'),
    );
    await c.shutdown();
    c = await open();
    expect(c.learningSubjects, containsAll(['语文', '数学', '英语', '物理', '日语']));
    expect(c.learningSubjects, isNot(contains('政治')));
  });
  test('Saved selections and custom filters survive restart; removing a subject keeps material and resets its filter', () async {
    final item = await c.study.saveMistake(
      const MistakeDraft(title: '受力分析', subject: '物理'),
    );
    await c.setLearningSubjects(['语文', '数学', '英语', '物理', '化学', '生物', '日语']);
    await c.setSubjectFilter('物理');
    await c.setLearningSubjects(['语文', '数学', '英语', '日语']);
    expect(c.subjectFilter, '');
    expect(await c.db.preference('subject_filter'), '');
    expect((await c.study.mistake(item.id)).subject, '物理');
    await c.shutdown();
    c = await open();
    expect(c.learningSubjects, ['语文', '数学', '英语', '日语']);
    expect(c.learningSubjects, isNot(contains('物理')));
    await c.setSubjectFilter('日语');
    await c.newSession();
    expect(c.selected!.subject, '日语');
  });
  test('Invalid selections cannot overwrite saved preferences and malformed stored data is recoverable', () async {
    await c.setLearningSubjects(['数学', '日语']);
    final before = await c.db.preference(AppPreferences.subjectsPreference);
    for (final invalid in <List<String>>[
      [],
      [''],
      List.generate(21, (i) => '科目$i'),
      ['a\nb'],
    ]) {
      await expectLater(c.setLearningSubjects(invalid), throwsFormatException);
      expect(await c.db.preference(AppPreferences.subjectsPreference), before);
    }
    await c.db.setPreference(
      AppPreferences.subjectsPreference,
      '{"invalid":true}',
    );
    await c.preferences.loadSubjects();
    expect(c.learningSubjects, contains('数学'));
    expect(c.preferences.loadNotice, isNotNull);
    await c.setLearningSubjects(['数学']);
    expect(c.learningSubjects, ['数学']);
  });
  test('Chat subject switching selects a matching session or empty view, preserves drafts and does not create placeholder records', () async {
    await c.newSession();
    final math = c.selected!;
    await c.setSessionSubject(math, '数学');
    await c.draft('未发送的数学草稿');
    final physics = await c.db.createSession(title: '物理对话', subject: '物理');
    await c.setSubjectFilter('物理', activateChat: true);
    expect(c.selected!.id, physics.id);
    final count = c.allSessions.length;
    await c.setLearningSubjects(['数学', '物理', '日语']);
    await c.setSubjectFilter('日语', activateChat: true);
    expect(c.selected, isNull);
    expect(c.allSessions, hasLength(count));
    expect(
      (await c.db.sessions()).firstWhere((s) => s.id == math.id).draft,
      '未发送的数学草稿',
    );
    await c.setLearningSubjects(['日语']);
    await c.prepareQuickQuiz();
    expect(c.selected!.subject, '日语');
    expect(c.selected!.mode, 'exam');
  });
}
