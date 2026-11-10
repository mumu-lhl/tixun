import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/chatgpt/auth.dart';
import 'package:tixun/core/ai/chatgpt/responses.dart';
import 'package:tixun/core/database/database.dart';

import 'support/chatgpt_fixture.dart';

const config = ProviderConfig(
  id: 1,
  kind: 'chatgpt',
  baseUrl: chatGptResource,
  model: 'gpt-6.1-sol',
  vision: false,
  thinking: false,
  supportsThinking: true,
  supportsTools: true,
  effort: 'high',
);
final answer = completed(
  output: [
    {
      'type': 'message',
      'content': [
        {'type': 'output_text', 'text': '公式整理'},
      ],
    },
  ],
);

Future<List<AiChunk>> reply(String body, String type) async {
  final f = ChatGptFixture();
  await f.seed();
  final dio = Dio()
    ..httpClientAdapter = FixtureAdapter(
      (_) => ResponseBody.fromString(
        body,
        200,
        headers: {
          'content-type': [type],
        },
      ),
    );
  return ChatGptResponses(f.auth, client: dio)
      .start(config)
      .complete(
        AiRequest(instructions: '', messages: const [AiMessage.user('请整理公式')]),
        CancelToken(),
      )
      .toList();
}

void main() {
  test('Responses accepts a case-insensitive SSE media type and completed-only text', () async {
    final chunks = await reply(
      'data: ${jsonEncode(answer)}\n\n',
      'Text/Event-Stream; charset=UTF-8',
    );
    expect(chunks.map((c) => c.text).join(), '公式整理');
    expect(chunks.last.completed, true);
  });
  test(
    'A valid complete JSON Response is accepted when streaming is not honored',
    () async {
      final chunks = await reply(
        jsonEncode({
          'object': 'response',
          'id': 'resp_fixture',
          ...answer['response'] as Map,
        }),
        'application/json',
      );
      expect(chunks.map((c) => c.text).join(), '公式整理');
      expect(chunks.last.completed, true);
    },
  );
  test(
    'Mislabeled SSE can still be decoded without fabricating a reply',
    () async {
      final chunks = await reply(
        'data: ${jsonEncode(answer)}\n\n',
        'application/octet-stream',
      );
      expect(chunks.map((c) => c.text).join(), '公式整理');
    },
  );
  test('JSON quota failures are classified without exposing server body or credentials', () async {
    await expectLater(
      reply(
        jsonEncode({
          'error': {
            'code': 'subscription_sharing_usage_limit_exceeded',
            'message': 'private-fixture-secret',
          },
        }),
        'application/json',
      ),
      throwsA(
        isA<AiFailure>().having(
          (e) => e.message,
          'message',
          allOf(contains('额度'), isNot(contains('private-fixture-secret'))),
        ),
      ),
    );
  });
  test(
    'HTML interception and malformed JSON never become successful replies',
    () async {
      await expectLater(
        reply('<html>private-fixture-secret</html>', 'text/html'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('网页'), isNot(contains('private-fixture-secret'))),
          ),
        ),
      );
      await expectLater(
        reply('{"status":"completed","output":"invalid"}', 'application/json'),
        throwsA(isA<AiFailure>()),
      );
    },
  );
}
