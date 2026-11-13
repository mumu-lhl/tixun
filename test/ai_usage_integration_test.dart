import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/ai_usage_store.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

class UsageProvider implements ChatProvider {
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        yield const AiChunk(text: 'Usage tracked reply.');
        yield const AiChunk(
          completed: true,
          usage: AiTokenUsage(
            inputTokens: 100,
            cachedInputTokens: 50,
            outputTokens: 25,
            reasoningTokens: 5,
            reportedTotalTokens: 125,
          ),
        );
      });
}

void main() {
  test('a chat action records request breakdown and price snapshot', () async {
    final root = await Directory.systemTemp.createTemp('tixun-ai-usage');
    final controller = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      UsageProvider(),
    );
    await controller.initialize();
    await controller.newSession();
    await controller.send('Explain this example.');

    final message = controller.messages.last;
    expect(message.totalTokens, 125);
    final events = await AiUsageStore(controller.db)
        .eventsForAction(message.id);
    expect(events, hasLength(1));
    final event = events.single;
    expect(event.feature, 'chat');
    expect(event.messageId, message.id);
    expect(event.inputTokens, 100);
    expect(event.cachedInputTokens, 50);
    expect(event.outputTokens, 25);
    expect(event.reasoningTokens, 5);
    expect(event.costBasis, 'estimate');
    expect(event.costNanoUsd, 45300);
    await controller.shutdown();
    await root.delete(recursive: true);
  });
}
