import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

/// Emits 12 chunks ~80ms apart, so a whole streaming run lasts about a
/// second — long enough to observe progress throttling and to type a draft
/// mid-generation.
class SlowProvider implements ChatProvider {
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        for (var i = 0; i < 12; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          cancel.checkCancelled();
          yield const AiChunk(text: '回复');
        }
        yield const AiChunk(completed: true, tokens: 12);
      });
}

void main() {
  late AppController c;
  setUp(() async {
    final root = await Directory.systemTemp.createTemp('tixun-chat-streaming');
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      SlowProvider(),
    );
    await c.initialize();
    await c.newSession();
  });
  tearDown(() async {
    await c.shutdown();
    await c.files.root.delete(recursive: true);
  });

  test(
    'Streaming progress notifies sparingly: in-memory ticks, no full reload',
    () async {
      var notifications = 0;
      c.addListener(() => notifications++);
      await c.send('问题');
      expect(c.messages.last.content, '回复' * 12);
      expect(c.messages.last.totalTokens, 12);
      // Fixed notifications around one send: start-request, prepare refresh
      // + reload, initial refresh, final refresh + reload + busy-off (7),
      // plus one per throttled progress tick (~3 at the 250ms cadence).
      // Before the fix every ~80ms tick reloaded the whole conversation
      // from the database, which measured ~19 notifications for the same
      // provider.
      expect(notifications, lessThanOrEqualTo(13));
    },
  );

  test(
    'Draft typed during generation survives until the user sends it',
    () async {
      final pending = c.send('问题');
      while (!c.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await c.draft('下一个问题');
      await pending;
      expect(c.messages.last.content, '回复' * 12);
      expect(c.selected!.draft, '下一个问题');
    },
  );

  test('Send clears only a draft that still equals the sent text', () async {
    await c.draft('hello');
    await c.send('hello');
    expect(c.selected!.draft, '');

    await c.draft('hello extra');
    await c.send('hello');
    expect(c.selected!.draft, 'hello extra');
  });
}
