import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/practice/question_spec.dart';

class FastProvider implements ChatProvider {
  final requests = <AiRequest>[];
  bool emitTitle = false;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests.add(request);
        if (request.enableConversationTitle && emitTitle) {
          yield const AiChunk(title: 'DeepSeek 生成标题');
        }
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          cancel.checkCancelled();
          yield const AiChunk(text: '回复');
        }
        yield const AiChunk(completed: true, tokens: 8);
      });
}

void main() {
  late AppController c;
  late FastProvider provider;
  setUp(() async {
    final root = await Directory.systemTemp.createTemp('tixun-controller-test');
    provider = FastProvider();
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      provider,
    );
    await c.initialize();
    await c.newSession();
  });
  tearDown(() async {
    await c.shutdown();
    await c.files.root.delete(recursive: true);
  });
  test('First send preserves explicitly named sessions and names ordinary sessions', () async {
    await c.renameSession(c.selected!, 'AI 整理知识');
    await c.send('请整理学习资料，不要出题。');
    expect(c.selected!.title, 'AI 整理知识');
    await c.newSession();
    await c.send('指数函数的定义');
    expect(c.selected!.title, '指数函数的定义');
  });
  test('DeepSeek titles only the first new untitled conversation', () async {
    c.config = c.config.copyWith(
      kind: 'deepseek',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-flash',
    );
    provider.emitTitle = true;
    await c.renameSession(c.selected!, '我自定义的名称');
    await c.send('自定义标题不应覆盖');
    expect(provider.requests.last.enableConversationTitle, false);
    expect(c.selected!.title, '我自定义的名称');

    await c.newSession();
    await c.send('请解释勾股定理');
    expect(provider.requests.last.enableConversationTitle, true);
    expect(c.selected!.title, 'DeepSeek 生成标题');

    await c.send('再举个例子');
    expect(provider.requests.last.enableConversationTitle, false);
    expect(c.selected!.title, 'DeepSeek 生成标题');
  });

  test(
    'Concurrent send submits once; messages and token usage persist',
    () async {
      await Future.wait([c.send('问题'), c.send('重复点击')]);
      expect(c.messages.length, 2);
      expect(c.messages.first.content, '问题');
      expect(c.messages.last.content, '回复回复回复回复');
      expect(c.messages.last.totalTokens, 8);
      expect(c.busy, false);
    },
  );
  test('Quiz preparation enables reasoning at the configured effort', () async {
    await c.prepareQuickQuiz();
    expect(c.sessionReasoning, 'high');
    expect(c.selected!.mode, 'exam');
    expect(c.selected!.subject, '数学');
  });
  test('Subject filter persists and scopes the session list only', () async {
    final math = await c.db.createSession(title: '数学 · 检测训练', subject: '数学');
    await c.db.createSession(title: '物理 · 受力分析', subject: '物理');
    await c.reload();
    expect(c.sessions.length, 3);
    await c.setSubjectFilter('数学');
    expect(c.subjectFilter, '数学');
    expect(await c.db.preference('subject_filter'), '数学');
    expect(c.sessions.map((s) => s.id), [math.id]);
    expect(c.allSessions.length, 3);
    await c.setSubjectFilter('');
    expect(c.sessions.length, 3);
    expect(() => c.setSubjectFilter('奥数'), throwsA(isA<FormatException>()));
  });
  test('New sessions inherit the global subject filter', () async {
    await c.setSubjectFilter('物理');
    await c.newSession();
    expect(c.selected!.subject, '物理');
    await c.setSubjectFilter('');
    await c.newSession();
    expect(c.selected!.subject, isNull);
  });
  test(
    'Knowledge practice records the note subject; mixed notes take the first',
    () async {
      final physics = await c.study.saveKnowledge(
        const KnowledgeDraft(title: '受力分析', content: '牛顿第二定律', subject: '物理'),
      );
      await c.prepareKnowledgePractice([physics.id]);
      expect(c.selected!.subject, '物理');
      final chemistry = await c.study.saveKnowledge(
        const KnowledgeDraft(title: '摩尔质量', content: 'n=m/M', subject: '化学'),
      );
      await c.prepareKnowledgePractice([chemistry.id, physics.id]);
      expect(c.selected!.subject, '化学');
    },
  );
  test('Variant preparation records the question subject', () async {
    final id = await c.practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '已知 F=ma，求加速度。',
        answers: [
          ['2'],
        ],
        subject: '物理',
      ),
    );
    final attempt = await c.practice.begin(id);
    await c.practice.submit(attempt.id, ['2']);
    final detail = await c.practice.detail(id);
    await c.prepareVariant(detail);
    expect(c.selected!.subject, '物理');
    expect(c.selected!.title, contains('物理'));
  });
  test('Search and subject filter stack', () async {
    await c.db.createSession(title: '数学 · 检测训练', subject: '数学');
    await c.db.createSession(title: '物理 · 受力分析', subject: '物理');
    await c.reload();
    await c.setSubjectFilter('数学');
    await c.searchSessions('检测');
    expect(c.sessions.length, 1);
    expect(c.sessions.single.subject, '数学');
    await c.searchSessions('受力');
    expect(c.sessions, isEmpty);
    await c.setSubjectFilter('');
    await c.searchSessions('受力');
    expect(c.sessions.length, 1);
  });
  test(
    'Stopping generation persists stopped state and allows regeneration',
    () async {
      final pending = c.send('测试取消');
      while (!c.messages.any((m) => m.status == 'generating')) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await c.stop();
      await pending;
      expect(c.messages.last.status, 'stopped');
      await c.regenerate();
      expect(c.messages.length, 2);
      expect(c.messages.last.status, 'complete');
    },
  );
  test('Editing branches history and retains original session', () async {
    await c.setSessionSubject(c.selected!, '数学');
    await c.setSubjectFilter('数学');
    await c.send('原问题');
    final original = c.selected!.id;
    final message = c.messages.first;
    await c.editAndResend(message, '修改后的问题');
    expect(c.selected!.id, isNot(original));
    expect(c.messages.first.content, '修改后的问题');
    expect(c.selected!.subject, '数学');
    expect(c.sessions.map((s) => s.id), contains(c.selected!.id));
    expect((await c.db.messages(original)).first.content, '原问题');
    expect(c.sessions.length, 2);
  });
  test('First send in an empty filtered view inherits its subject', () async {
    await c.deleteSession(c.selected!);
    await c.setSubjectFilter('数学');
    await c.send('二次函数');
    expect(c.selected!.subject, '数学');
    expect(c.sessions.single.id, c.selected!.id);
  });
  test(
    'Restart restores the last conversation even when a filter hides it',
    () async {
      final root = await Directory.systemTemp.createTemp('tixun-chat-restart');
      final first = await AppController.openRoot(
        root,
        demo: false,
        keyStore: MemoryKeyStore(),
        chatProvider: FastProvider(),
      );
      await first.setSubjectFilter('数学');
      await first.newSession();
      await first.send('重启后需要保留的对话');
      final id = first.selected!.id;
      await first.setSubjectFilter('物理');
      expect(first.sessions, isEmpty);
      expect(first.selected!.id, id);
      await first.shutdown();
      final reopened = await AppController.openRoot(
        root,
        demo: false,
        keyStore: MemoryKeyStore(),
        chatProvider: FastProvider(),
      );
      try {
        expect(reopened.subjectFilter, '物理');
        expect(reopened.selected?.id, id);
        expect(reopened.messages.first.content, '重启后需要保留的对话');
        await reopened.setSubjectFilter('');
        expect(reopened.sessions.single.id, id);
      } finally {
        await reopened.shutdown();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'Draft, mode, rename and reversible deletion use database state',
    () async {
      await c.draft('草稿');
      await c.mode('direct');
      await c.renameSession(c.selected!, '新名称');
      final s = c.selected!;
      await c.deleteSession(s);
      expect(c.sessions, isEmpty);
      await c.restoreSession(s);
      await c.selectSession(c.sessions.single);
      expect(c.selected!.draft, '草稿');
      expect(c.selected!.mode, 'direct');
      expect(c.selected!.title, '新名称');
    },
  );
  test('Switching sessions while a send is preparing cancels before loading the next session', () async {
    final original = c.selected!;
    final other = await c.db.createSession(title: '另一个会话');
    final request = c.send('即将发出的消息');
    await c.selectSession(other);
    await request;
    expect(c.selected!.id, other.id);
    expect(c.messages, isEmpty);
    final history = await c.db.messages(original.id);
    expect(history.length, 2);
    expect(history.last.status, 'stopped');
    expect(c.busy, false);
  });
  test(
    'Reselecting an older session object loads its latest saved draft',
    () async {
      final stale = c.selected!;
      await c.draft('最新草稿');
      await c.newSession();
      await c.selectSession(stale);
      expect(c.selected!.draft, '最新草稿');
      await c.searchSessions(stale.title);
      await c.renameSession(c.selected!, '不匹配搜索的新标题');
      expect(c.selected!.title, '不匹配搜索的新标题');
    },
  );
  test('Session search applies subject and literal title matching', () async {
    final math = await c.db.createSession(title: 'A "数学"', subject: '数学');
    await c.db.createSession(title: 'A "数学"', subject: '物理');
    expect((await c.db.sessions('数学', '数学')).map((s) => s.id), [math.id]);
    expect((await c.db.sessions('"数学"', '数学')).map((s) => s.id), [math.id]);
    expect(await c.db.sessions('数学', '英语'), isEmpty);
  });
  test('Message search index follows edits and deletions', () async {
    final session = await c.db.createSession(title: '检索', subject: '数学');
    await c.db.customStatement(
      'INSERT INTO chat_messages (id, session_id, role, content, created_at) VALUES (?, ?, ?, ?, ?)',
      ['search-message', session.id, 'user', 'Quadratic 顶点 x = 1', 1],
    );
    expect((await c.db.sessions('quadratic 顶点', '数学')).map((s) => s.id), [
      session.id,
    ]);
    expect(
      (await c.db.matchingMessage(session.id, 'quadratic 顶点'))?.id,
      'search-message',
    );
    expect((await c.db.sessions('x = 1', '数学')).map((s) => s.id), [session.id]);
    expect(await c.db.sessions('quadratic 不存在', '数学'), isEmpty);
    await c.db.customStatement(
      'UPDATE chat_messages SET content = ? WHERE id = ?',
      ['Updated 公式', 'search-message'],
    );
    expect(await c.db.sessions('quadratic', '数学'), isEmpty);
    expect((await c.db.sessions('updated', '数学')).map((s) => s.id), [
      session.id,
    ]);
    await c.db.customStatement('DELETE FROM chat_messages WHERE id = ?', [
      'search-message',
    ]);
    expect(await c.db.sessions('updated', '数学'), isEmpty);
  });
  test('Rapidly switching sessions keeps the last selected one', () async {
    final first = c.selected!;
    final second = await c.db.createSession(title: '第二个会话');
    await Future.wait([c.selectSession(first), c.selectSession(second)]);
    expect(c.selected!.id, second.id);
    expect(c.messages, isEmpty);
  });
  test('Selecting a session deleted mid-load does not throw', () async {
    final gone = await c.db.createSession(title: '待删会话');
    final current = c.selected!;
    await (c.db.delete(
      c.db.chatSessions,
    )..where((s) => s.id.equals(gone.id))).go();
    await c.selectSession(gone);
    expect(c.selected!.id, current.id);
  });
}
