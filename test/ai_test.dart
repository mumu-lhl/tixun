import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';

void main() {
  Stream<List<int>> bytes(String value) =>
      Stream.fromIterable(utf8.encode(value).map((b) => [b]));
  const end =
      'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n';
  test('SSE handles individual UTF-8 bytes, CRLF, comments, multiline events and usage', () async {
    final chunks = await decodeCompletion(
      bytes(
        ': keepalive\r\ndata: {"choices":[{"delta":{"content":"你好"}}]}\r\n\r\ndata: {"choices":[],\ndata: "usage":{"total_tokens":42}}\n\n$end',
      ),
    ).toList();
    expect(chunks.map((c) => c.text).join(), '你好');
    expect(chunks.any((c) => c.tokens == 42), true);
  });
  test(
    'Malformed JSON, unexpected close and unsupported tools fail explicitly',
    () async {
      for (final data in [
        'data: {broken}\n\n',
        'data: {"choices":[{"delta":{"content":"部分"}}]}\n\n',
        'data: {"choices":[{"delta":{"tool_calls":[]}}]}\n\n',
      ]) {
        await expectLater(
          decodeCompletion(bytes(data)).toList(),
          throwsA(isA<AiFailure>()),
        );
      }
    },
  );
  test('Token limit preserves text then reports incomplete response', () async {
    final output = <String>[];
    try {
      await for (final c in decodeCompletion(
        bytes(
          'data: {"choices":[{"delta":{"content":"partial"},"finish_reason":"length"}]}\n\n',
        ),
      )) {
        output.add(c.text);
      }
    } on AiFailure catch (e) {
      expect(e.message, contains('长度'));
    }
    expect(output.join(), 'partial');
  });
  test(
    'Image request contains actual stable file bytes and Pro rejects images',
    () async {
      final root = await Directory.systemTemp.createTemp('tixun-ai-test');
      addTearDown(() => root.delete(recursive: true));
      final store = AttachmentStore(root);
      await store.resolve('attachments/a.png').parent.create(recursive: true);
      await store.resolve('attachments/a.png').writeAsBytes([137, 80, 78, 71]);
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final config = await db.config();
      final message = ChatMessage(
        id: 'm1',
        sessionId: 's',
        role: 'user',
        content: '解释图片',
        status: 'complete',
        createdAt: DateTime(2026),
      );
      const a = Attachment(
        id: 'a',
        sessionId: 's',
        messageId: 'm1',
        relativePath: 'attachments/a.png',
        mime: 'image/png',
        byteLength: 4,
      );
      final body = await completionBody(
        config,
        [message],
        [a],
        store,
        'guided',
      );
      final messages = body['messages'] as List;
      expect(
        messages.last['content'][1]['image_url']['url'],
        'data:image/png;base64,iVBORw==',
      );
      expect(body['thinking'], {'type': 'disabled'});
      await expectLater(
        completionBody(
          config.copyWith(model: 'deepseek-v4-pro', vision: false),
          [message],
          [a],
          store,
          'guided',
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(
        () =>
            validateConfig(config.copyWith(baseUrl: 'https://key@example.com')),
        throwsFormatException,
      );
    },
  );
  test(
    'Real HTTP transport retries 429 once, sends bearer key, parses SSE',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      final served = server.listen((request) async {
        requests++;
        expect(request.uri.path, '/v1/chat/completions');
        expect(request.headers.value('authorization'), 'Bearer test-only');
        final data = jsonDecode(await utf8.decoder.bind(request).join());
        expect(data['stream'], true);
        if (requests == 1) {
          request.response.statusCode = 429;
        } else {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"OK"}}]}\n\n$end',
          );
        }
        await request.response.close();
      });
      addTearDown(served.cancel);
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final config = (await db.config()).copyWith(
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        kind: 'compatible',
      );
      final result = await OpenAiChatProvider().complete(config, 'test-only', {
        'stream': true,
      }, CancelToken()).toList();
      expect(result.map((e) => e.text).join(), 'OK');
      expect(requests, 2);
    },
  );
  test('Cancellation prevents a Mock response from continuing', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final token = CancelToken();
    final values = <AiChunk>[];
    await expectLater(() async {
      await for (final c in MockChatProvider().complete(
        await db.config(),
        '',
        {},
        token,
      )) {
        values.add(c);
        token.cancel('user');
      }
    }(), throwsA(isA<DioException>()));
    expect(values.length, 1);
  });
}
