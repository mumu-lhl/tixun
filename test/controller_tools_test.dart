import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

Future<void> waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('condition timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late AppController c;
  setUp(() async {
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(
        await Directory.systemTemp.createTemp('tixun-chat-tools'),
      ),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    await c.initialize();
    await c.newSession();
    await c.setTools(true);
  });
  tearDown(() async {
    await c.shutdown();
    await c.files.root.delete(recursive: true);
  });
  test('Chat completes multi-round tool execution only after approval and preserves provenance', () async {
    final pending = c.send('请保存知识');
    await waitFor(() => c.pendingTool != null);
    expect(await c.study.searchKnowledge(), isEmpty);
    c.decideTool(true);
    await pending;
    expect(c.messages.last.status, 'complete');
    expect(c.messages.last.content, contains('保存成功'));
    final item = (await c.study.searchKnowledge()).single;
    final originalSession = c.selected!.id;
    expect(item.sourceMessageId, c.messages.last.id);
    final retry = c.regenerate();
    await waitFor(() => c.pendingTool != null);
    c.decideTool(false);
    await retry;
    expect(
      (await c.db.messages(originalSession)).last.id,
      item.sourceMessageId,
    );
  });
  test('Rejecting or cancelling a proposal never writes study data', () async {
    var pending = c.send('请保存知识');
    await waitFor(() => c.pendingTool != null);
    c.decideTool(false);
    await pending;
    expect(c.messages.last.content, contains('没有保存'));
    expect(await c.study.searchKnowledge(), isEmpty);
    pending = c.send('再次保存知识');
    await waitFor(() => c.pendingTool != null);
    await c.stop();
    await pending;
    expect(c.messages.last.status, 'stopped');
    expect(c.pendingTool, isNull);
    expect(await c.study.searchKnowledge(), isEmpty);
  });
  test(
    'A tool call naming a missing question reports the missing record',
    () async {
      final toolController = await openWithToolArgs(
        '{"question_id":"no-such-question"}',
      );
      addTearDown(() async {
        await toolController.shutdown();
        await toolController.files.root.delete(recursive: true);
      });
      await toolController.send('安排复习');
      expect(toolController.messages.last.content, '收到');
      final ops = await toolController.db
          .select(toolController.db.aiToolOperations)
          .get();
      expect(ops.single.name, 'schedule_review');
      expect(ops.single.result, contains('题目不存在'));
    },
  );
}

class ScriptedToolProvider implements ChatProvider {
  ScriptedToolProvider(this.args);
  final String args;
  var turns = 0;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        turns++;
        if (turns == 1) {
          yield AiChunk(
            completed: true,
            calls: [ToolCall('bad-1', 'schedule_review', args)],
          );
        } else {
          yield const AiChunk(text: '收到', completed: true);
        }
      });
}

Future<AppController> openWithToolArgs(String args) async {
  final controller = AppController(
    AppDatabase.memory(),
    AttachmentStore(
      await Directory.systemTemp.createTemp('tixun-confirm-tools'),
    ),
    MemoryKeyStore(),
    ScriptedToolProvider(args),
  );
  await controller.initialize();
  await controller.newSession();
  await controller.setTools(true);
  return controller;
}
