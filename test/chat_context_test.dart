import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/ai_usage_store.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_store.dart';

class RecordingProvider implements ChatProvider {
  final requests = <AiRequest>[];
  String? readKnowledge;
  bool interruptAfterTool = false;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) {
    var round = 0;
    return AiConversation((request, cancel) async* {
      requests.add(request);
      if (request.maxOutputTokens != null) {
        yield const AiChunk(text: '配方法摘要', completed: true);
        return;
      }
      final knowledge = readKnowledge;
      if (knowledge != null && round++ == 0) {
        yield AiChunk(
          text: '先查看笔记。',
          calls: [
            ToolCall('note-lookup', 'get_knowledge', '{"id":"$knowledge"}'),
          ],
          completed: true,
        );
        return;
      }
      yield AiChunk(text: '接着看配方法。', completed: !interruptAfterTool);
    });
  }
}

List<Object?> contextOf(Iterable<AiMessage> messages) => [
  for (final message in messages)
    [
      message.role,
      message.text,
      message.reasoningContent,
      message.callId,
      [
        for (final call in message.calls) [call.id, call.name, call.arguments],
      ],
      [for (final image in message.images) image.dataUrl],
    ],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppController c;
  late RecordingProvider provider;
  late MemoryKeyStore keys;

  Future<AppController> open() => AppController.openRoot(
    root,
    demo: false,
    keyStore: keys,
    chatProvider: provider,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tixun-chat-context');
    provider = RecordingProvider();
    keys = MemoryKeyStore();
    c = await open();
    await c.newSession();
  });

  tearDown(() async {
    await c.shutdown();
    await root.delete(recursive: true);
  });

  Future<String> enableRead() async {
    final note = await c.study.saveKnowledge(
      const KnowledgeDraft(title: '函数笔记', content: '仅来自资料工具的笔记正文'),
    );
    await c.setTools(true);
    provider.readKnowledge = note.id;
    return note.id;
  }

  test(
    'replays complete tool turns after reopening but not after revocation',
    () async {
      await enableRead();
      await c.send('请讲解笔记里的配方法');
      expect(c.messages.last.status, 'complete');
      final first = provider.requests.first;
      final second = provider.requests[1];
      expect(second.messages.last.role, AiRole.tool);
      expect(second.messages.last.text, contains('仅来自资料工具的笔记正文'));
      final usage = await AiUsageStore(c.db)
          .eventsForAction(c.messages.last.id);
      expect(usage, hasLength(2));
      final counts = usage.map((row) {
        final breakdown = jsonDecode(row.tokenBreakdownJson!) as Map;
        return breakdown['counts'] as Map;
      }).toList();
      expect(
        counts.every((row) => (row['toolDefinitions'] as int) > 0),
        isTrue,
      );
      expect(counts.every((row) => (row['toolCalls'] as int) > 0), isTrue);
      expect(
        counts.where((row) => (row['toolResults'] as int) > 0),
        hasLength(1),
      );
      final expected = contextOf([
        ...second.messages,
        AiMessage.assistant('接着看配方法。'),
      ]);

      await c.shutdown();
      provider = RecordingProvider();
      c = await open();
      await c.send('再讲一遍');
      final followup = provider.requests.single;
      expect(followup.instructions, first.instructions);
      expect(contextOf(followup.messages.take(expected.length)), expected);
      expect(c.messages.first.content, '请讲解笔记里的配方法');

      await c.setTools(false);
      provider.requests.clear();
      await c.send('换一种讲法');
      final revoked = provider.requests.single;
      expect(
        revoked.tools.map((tool) => tool.name),
        isNot(contains('get_knowledge')),
      );
      expect(
        revoked.messages.where(
          (m) => m.role == AiRole.tool || m.calls.isNotEmpty,
        ),
        isEmpty,
      );
      expect(
        revoked.messages.map((m) => m.text).join(),
        isNot(contains('仅来自资料工具的笔记正文')),
      );
    },
  );

  test(
    'does not replay an interrupted assistant turn, even after a tool result',
    () async {
      await enableRead();
      provider.interruptAfterTool = true;
      await c.send('请讲解笔记里的配方法');
      expect(provider.requests.last.messages.last.role, AiRole.tool);
      expect(c.messages.last.status, isNot('complete'));

      provider.readKnowledge = null;
      provider.interruptAfterTool = false;
      provider.requests.clear();
      await c.send('重新说说配方法');
      expect(provider.requests.single.messages.map((m) => m.role), [
        AiRole.user,
        AiRole.user,
      ]);
      expect(
        provider.requests.single.messages.first.text,
        contains('请讲解笔记里的配方法'),
      );
    },
  );

  test(
    'forks keep sent images and exclude later turns; edited input is replaced',
    () async {
      await c.addImage('assets/demo/two_problems.png');
      await c.send('解释原图');
      final original = c.selected!;
      final originalAttachment = c.attachments.single;
      final first = provider.requests.single;
      final reply = c.messages.last;
      expect(first.messages.first.images, hasLength(1));
      await c.send('仅原分支的问题');

      await c.forkChat(reply);
      final fork = c.selected!;
      expect(fork.id, isNot(original.id));
      expect(c.attachments.single.id, isNot(originalAttachment.id));
      await c.deleteSession(original);
      await c.purgeSession(original.id);
      final rows = await c.db.select(c.db.chatContextEvents).get();
      expect(
        rows.map((r) => r.messageId),
        unorderedEquals(c.messages.map((m) => m.id)),
      );
      provider.requests.clear();
      await c.send('仅新分支的问题');
      final branchRequest = provider.requests.single;
      expect(
        contextOf(branchRequest.messages.take(1)),
        contextOf(first.messages),
      );
      expect(
        branchRequest.messages.map((m) => m.text).join(),
        isNot(contains('仅原分支的问题')),
      );

      provider.requests.clear();
      await c.editAndResend(c.messages.first, '改成解释第二题');
      final edited = provider.requests.single;
      expect(edited.messages.single.text, startsWith('改成解释第二题'));
      expect(edited.messages.single.text, isNot(contains('解释原图')));
      expect(
        edited.messages.single.images.single.dataUrl,
        first.messages.single.images.single.dataUrl,
      );
    },
  );

  test('tool context counts toward compaction without sending private results to the summarizer', () async {
    final note = await c.study.saveKnowledge(
      KnowledgeDraft(title: '长笔记', content: '函数' * 4300),
    );
    await c.setTools(true);
    provider.readKnowledge = note.id;
    await c.send('讲讲配方法');
    final original = c.selected!;
    final reply = c.messages.last;
    expect(provider.requests.last.messages.last.text, contains('函数' * 100));

    await c.setMaxContextTokens(9000);
    provider.readKnowledge = null;
    provider.requests.clear();
    await c.send('再讲一遍');
    expect(provider.requests, hasLength(2));
    final summaryRequest = provider.requests.first;
    expect(summaryRequest.messages.map((m) => m.role), [
      AiRole.user,
      AiRole.assistant,
    ]);
    expect(
      summaryRequest.messages.map((m) => m.text).join(),
      isNot(contains('函数' * 100)),
    );
    final following = provider.requests.last;
    expect(following.instructions, isNot(contains('配方法摘要')));
    expect(following.messages.first.text, contains('配方法摘要'));
    expect(following.messages.last.text, startsWith('再讲一遍'));
    final rows = await c.db.select(c.db.chatContextEvents).get();
    expect(rows.where((r) => r.messageId == reply.id), hasLength(3));

    await c.forkChat(reply);
    expect(c.selected!.contextSummary, '配方法摘要');
    expect(c.selected!.contextSummaryUpToId, c.messages.last.id);
    await c.selectSession(original);
    await c.forkChat(c.messages.first);
    expect(c.selected!.contextSummary, isNull);
  });
}
