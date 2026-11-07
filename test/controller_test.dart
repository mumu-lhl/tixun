import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

class FastProvider implements ChatProvider {
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
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
  setUp(() async {
    final root = await Directory.systemTemp.createTemp('tixun-controller-test');
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      FastProvider(),
    );
    await c.initialize();
    await c.newSession();
  });
  tearDown(() async {
    await c.shutdown();
    await c.files.root.delete(recursive: true);
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
    await c.send('原问题');
    final original = c.selected!.id;
    final message = c.messages.first;
    await c.editAndResend(message, '修改后的问题');
    expect(c.selected!.id, isNot(original));
    expect(c.messages.first.content, '修改后的问题');
    expect((await c.db.messages(original)).first.content, '原问题');
    expect(c.sessions.length, 2);
  });
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
}
