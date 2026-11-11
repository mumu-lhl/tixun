import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jose/jose.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/chatgpt/auth.dart';
import 'package:tixun/core/ai/chatgpt/responses.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/backup/backup_service.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/core/platform/attachment_store.dart';

import 'support/chatgpt_fixture.dart';

const config = ProviderConfig(
  id: 1,
  kind: 'chatgpt',
  baseUrl: chatGptResource,
  model: 'fixture-vision',
  reasoningLevels: '["low","medium","high","xhigh","max"]',
  vision: true,
  thinking: true,
  supportsThinking: true,
  supportsTools: true,
  effort: 'high',
);

void main() {
  test('PKCE loopback sign-in verifies identity, isolates tokens and reuses host/client registration', () async {
    final f = ChatGptFixture();
    final first = await f.auth.signIn();
    expect(first.subject, 'student');
    expect(f.callbackStatuses, [400, 200]);
    final authorization = f.authorization!;
    expect(authorization.host, 'auth.openai.com');
    expect(authorization.queryParameters['client_id'], 'dynamic_agent_client');
    final exchange =
        f.requests.firstWhere((r) => r.path.endsWith('/oauth/token')).data
            as Map;
    expect(exchange['client_id'], 'oaiapp_fixture');
    expect(
      exchange['redirect_uri'],
      authorization.queryParameters['redirect_uri'],
    );
    expect(
      base64UrlEncode(
        sha256.convert(ascii.encode(exchange['code_verifier'] as String)).bytes,
      ).replaceAll('=', ''),
      authorization.queryParameters['code_challenge'],
    );
    expect(await f.auth.accessToken(), 'access-fixture');
    final models = await f.auth.models();
    expect(models.map((m) => m.id), ['fixture-text', 'fixture-vision']);
    expect(models.last.vision, true);
    await f.auth.signIn(accountId: first.id);
    expect(f.authorization!.queryParameters['client_id'], 'oaiapp_fixture');
    expect(
      f.authorization!.queryParameters['ext_agent_host_id'],
      authorization.queryParameters['ext_agent_host_id'],
    );
    expect((await f.auth.snapshot()).accounts.length, 1);
    f.subject = 'other-student';
    await expectLater(
      f.auth.signIn(accountId: first.id),
      throwsA(isA<AiFailure>()),
    );
    expect((await f.auth.snapshot()).accounts.single.subject, 'student');
    await f.auth.signIn();
    expect((await f.auth.snapshot()).accounts.length, 2);
    await f.auth.select(first.id);
    expect((await f.auth.snapshot()).activeId, first.id);
    expect(await f.auth.signOut(first.id), true);
    expect(
      (await f.auth.snapshot()).accounts
          .firstWhere((a) => a.id == first.id)
          .connected,
      false,
    );
    await expectLater(f.auth.accessToken(), throwsA(isA<AiFailure>()));
    expect(f.revocations, 1);
  });

  for (final failure in [
    'nonce',
    'issuer',
    'audience',
    'expiry',
    'signature',
    'scope',
  ]) {
    test('OAuth rejects invalid $failure without saving tokens', () async {
      final f = ChatGptFixture();
      switch (failure) {
        case 'nonce':
          f.overrides['nonce'] = 'wrong';
        case 'issuer':
          f.overrides['iss'] = 'https://attacker.invalid';
        case 'audience':
          f.overrides['aud'] = 'different-client';
        case 'expiry':
          f.overrides['exp'] = 1;
        case 'signature':
          f.alternativeSigningKey = JsonWebKey.generate('RS256');
        case 'scope':
          f.denyScope = true;
      }
      await expectLater(f.auth.signIn(), throwsA(isA<AiFailure>()));
      expect((await f.auth.snapshot()).accounts, isEmpty);
      expect(
        await f.keys.read(ChatGptAuth.storageKey),
        isNot(contains('access-fixture')),
      );
    });
  }

  test('Rotating refresh is serialized and sign-out reports failed remote revocation', () async {
    final f = ChatGptFixture();
    await f.seed(expired: true);
    final values = await Future.wait([
      f.auth.accessToken(),
      f.auth.accessToken(),
      f.auth.accessToken(),
    ]);
    expect(values, everyElement('refreshed-fixture'));
    expect(f.refreshes, 1);
    final stored = await f.keys.read(ChatGptAuth.storageKey);
    expect(stored, contains('rotated-fixture'));
    final refresh = f.requests.first.data as Map;
    expect(refresh['client_id'], 'oaiapp_fixture');
    expect(refresh.containsKey('scope'), false);
    f.failRevocation = true;
    expect(await f.auth.signOut('oaiapp_fixture:student'), false);
    expect((await f.auth.snapshot()).accounts.single.connected, false);
  });

  test('Cancelling browser authorization closes the listener and permits another attempt', () async {
    final f = ChatGptFixture();
    final started = Completer<void>();
    final auth = ChatGptAuth(
      f.keys,
      client: f.dio,
      openBrowser: (_) async {
        started.complete();
        return true;
      },
    );
    final login = auth.signIn();
    final expectation = expectLater(login, throwsA(isA<AiFailure>()));
    await started.future;
    auth.cancelLogin();
    await expectation;
    expect(auth.signingIn, false);
    expect((await f.auth.snapshot()).accounts, isEmpty);
    await f.auth.signIn();
    expect((await f.auth.snapshot()).accounts.single.connected, true);
  });

  test('Responses requests use official fields, namespace tools, vision and encrypted reasoning replay', () async {
    final f = ChatGptFixture();
    await f.seed();
    var request = AiRequest(
      instructions: 'Guide the student.',
      messages: [
        const AiMessage.user(
          'Explain',
          images: [AiImage('data:image/png;base64,fixture')],
        ),
      ],
      tools: [
        const AiTool(
          name: 'create_quiz',
          description: 'Quiz',
          parameters: {'type': 'object'},
        ),
      ],
      maxOutputTokens: 20,
    );
    final output = [
      {
        'type': 'reasoning',
        'id': 'rs_fixture',
        'encrypted_content': 'opaque-fixture',
        'summary': [],
      },
      {
        'type': 'function_call',
        'call_id': 'call_fixture',
        'name': 'create_quiz',
        'namespace': 'tixun',
        'arguments': '{}',
      },
    ];
    final sent = <Map<String, dynamic>>[];
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((r) {
        sent.add(Map<String, dynamic>.from(r.data as Map));
        return fixtureSse([completed(output: sent.length == 1 ? output : [])]);
      });
    final conversation = ChatGptResponses(f.auth, client: client).start(config);
    final chunks = await conversation.complete(request, CancelToken()).toList();
    final encoded = sent.first;
    expect(encoded['store'], false);
    expect(encoded['stream'], true);
    expect(encoded['instructions'], 'Guide the student.');
    // Intentional: the ChatGPT path sends no output cap; the connection
    // test cancels after the first text instead (see _requestBody).
    expect(encoded.containsKey('max_tokens'), false);
    expect(encoded.containsKey('max_output_tokens'), false);
    expect(encoded['input'][0]['content'][1]['type'], 'input_image');
    expect(encoded['tools'][0]['type'], 'namespace');
    expect(chunks.last.completed, true);
    expect(chunks.last.calls.single.id, 'call_fixture');
    request = request.copyWith(
      messages: [
        ...request.messages,
        AiMessage.assistant('', calls: chunks.last.calls),
        const AiMessage.tool('call_fixture', '{"ok":true}'),
      ],
    );
    await conversation.complete(request, CancelToken()).toList();
    final next = sent.last;
    expect(next['input'][1], output.first);
    expect(next['input'][2], output.last);
    expect(next['input'][3]['type'], 'function_call_output');
    expect(next.containsKey('_chatgpt_tool_context'), false);
    expect(
      () =>
          validateConfig(config.copyWith(baseUrl: 'https://attacker.invalid')),
      throwsFormatException,
    );
  });

  test(
    'Optional usage metadata cannot invalidate a complete tool response',
    () async {
      final f = ChatGptFixture();
      await f.seed();
      for (final total in [17.0, '17', null]) {
        var requests = 0;
        final client = Dio()
          ..httpClientAdapter = FixtureAdapter((_) {
            final event = completed(
              output: ++requests == 1
                  ? [
                      {
                        'type': 'message',
                        'content': [
                          {'type': 'output_text', 'text': 'OK'},
                        ],
                      },
                    ]
                  : [
                      {
                        'type': 'function_call',
                        'call_id': 'quiz',
                        'name': 'create_quiz',
                        'namespace': 'tixun',
                        'arguments': '{}',
                      },
                    ],
            );
            (event['response'] as Map)['usage'] = {'total_tokens': total};
            return fixtureSse([event]);
          });
        final provider = ChatGptResponses(f.auth, client: client);
        final model = config.copyWith(model: 'gpt-6.1-terra', effort: 'high');
        final connection = await provider
            .start(model)
            .complete(
              AiRequest(
                instructions: '',
                messages: [const AiMessage.user('只回复 OK')],
              ),
              CancelToken(),
            )
            .toList();
        expect(connection.map((c) => c.text).join(), 'OK');
        final chat = await provider
            .start(model)
            .complete(
              AiRequest(
                instructions: 'Guide the student.',
                messages: [const AiMessage.user('出一道练习题')],
                tools: [
                  const AiTool(
                    name: 'create_quiz',
                    description: 'Quiz',
                    parameters: {'type': 'object'},
                  ),
                ],
              ),
              CancelToken(),
            )
            .toList();
        expect(chat.last.completed, true);
        expect(chat.last.calls.single.name, 'create_quiz');
        expect(chat.last.tokens, isNull);
      }
    },
  );

  test('Empty SSE heartbeats do not invalidate text or reasoning', () async {
    final text =
        'data:\n\ndata:  \n\n: heartbeat\n\n'
        'data: ${jsonEncode({'type': 'response.reasoning_summary_text.delta', 'delta': '核对条件'})}\n\n'
        'data:\n\ndata: ${jsonEncode({'type': 'response.output_text.delta', 'delta': '答案'})}\n\n'
        'data: ${jsonEncode(completed())}\n\n';
    final chunks = await decodeResponses(
      Stream.value(utf8.encode(text)),
      null,
    ).toList();
    expect(chunks.map((c) => c.text).join(), '答案');
    expect(chunks.map((c) => c.reasoning).join(), '核对条件');
    expect(chunks.last.completed, true);
    await expectLater(
      decodeResponses(Stream.value(utf8.encode('data:\n\n')), null).toList(),
      throwsA(isA<AiFailure>()),
    );
  });

  test('Quota failure, invalid JSON and interrupted streams never become successful replies', () async {
    for (final tail in [
      'data: ${jsonEncode({
        'type': 'response.failed',
        'response': {
          'error': {'code': 'subscription_sharing_usage_limit_exceeded'},
        },
      })}\n\n',
      'data: {bad-json}\n\n',
      '',
      'data: ${jsonEncode({'type': 'response.incomplete'})}\n\n',
    ]) {
      final chunks = <AiChunk>[];
      final stream = decodeResponses(
        Stream.value(
          utf8.encode(
            'data: {"type":"response.output_text.delta","delta":"Partial"}\n\n$tail',
          ),
        ),
        null,
      );
      await expectLater(stream.forEach(chunks.add), throwsA(isA<AiFailure>()));
      expect(chunks.single.text, 'Partial');
      expect(chunks.single.completed, false);
    }
  });

  test('History with tool calls but no retained context synthesizes a fallback function_call', () async {
    final f = ChatGptFixture();
    await f.seed();
    final request = AiRequest(
      instructions: '',
      messages: [
        const AiMessage.user('出题'),
        AiMessage.assistant(
          '',
          calls: [
            ToolCall('call_fallback', 'create_quiz', '{"kind":"numeric"}'),
          ],
        ),
        const AiMessage.tool('call_fallback', '{"ok":true}'),
      ],
      tools: [
        const AiTool(
          name: 'create_quiz',
          description: 'Quiz',
          parameters: {'type': 'object'},
        ),
      ],
    );
    final sent = <Map<String, dynamic>>[];
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((r) {
        sent.add(Map<String, dynamic>.from(r.data as Map));
        return fixtureSse([completed()]);
      });
    final chunks = await ChatGptResponses(
      f.auth,
      client: client,
    ).start(config).complete(request, CancelToken()).toList();
    expect(chunks.last.completed, true);
    final input = sent.single['input'] as List;
    expect(input.length, 3);
    final call = input.firstWhere(
      (e) => e is Map && e['type'] == 'function_call',
    ) as Map;
    expect(call['call_id'], 'call_fallback');
    expect(call['name'], 'create_quiz');
    expect(call['namespace'], 'tixun');
    expect(call.containsKey('id'), false);
    expect(input.last, {
      'type': 'function_call_output',
      'call_id': 'call_fallback',
      'output': '{"ok":true}',
    });
  });

  test('Config errors keep their own message on both provider paths', () async {
    final f = ChatGptFixture();
    await f.seed();
    final badChatGpt = config.copyWith(effort: 'ultra');
    expect(
      () => ChatGptResponses(f.auth).start(badChatGpt),
      throwsA(
        isA<AiFailure>().having((e) => e.message, 'message', contains('思考参数')),
      ),
    );
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final badApi = (await db.config()).copyWith(
      baseUrl: 'https://key@example.com',
    );
    await expectLater(
      OpenAiChatProvider()
          .start(badApi, apiKeyOverride: 'test-only')
          .complete(AiRequest(instructions: '', messages: []), CancelToken())
          .toList(),
      throwsA(
        isA<AiFailure>().having(
          (e) => e.message,
          'message',
          contains('API 地址'),
        ),
      ),
    );
  });

  test(
    'Corrupt ChatGPT login records report as unreadable instead of raw errors',
    () async {
      final keys = MemoryKeyStore();
      final auth = ChatGptAuth(keys);
      for (final raw in [
        '{not json',
        '{"version":1,"accounts":["oops"]}',
        '{"version":1,"accounts":[{"sub":"no-client"}]}',
        '{"version":1,"accounts":{}}',
      ]) {
        await keys.write(ChatGptAuth.storageKey, raw);
        await expectLater(
          auth.snapshot(),
          throwsA(
            isA<AiFailure>().having(
              (e) => e.message,
              'message',
              contains('登录记录无法读取'),
            ),
          ),
        );
      }
      await keys.write(
        ChatGptAuth.storageKey,
        jsonEncode({'version': 1, 'accounts': []}),
      );
      expect((await auth.snapshot()).accounts, isEmpty);
    },
  );

  test('Controller creates a real interactive quiz through namespaced tools with reasoning enabled', () async {
    final f = ChatGptFixture();
    await f.seed();
    final responseClient = Dio();
    var count = 0;
    final sent = <Map<String, dynamic>>[];
    responseClient.httpClientAdapter = FixtureAdapter((r) {
      expect(r.path, '$chatGptResource/responses');
      expect(r.headers['Authorization'], 'Bearer access-fixture');
      sent.add(Map<String, dynamic>.from(r.data as Map));
      count++;
      if (count == 1) {
        return fixtureSse([
          completed(
            output: [
              {
                'type': 'reasoning',
                'id': 'rs_search',
                'encrypted_content': 'opaque-search',
                'summary': [],
              },
              {
                'type': 'function_call',
                'namespace': 'tixun',
                'call_id': 'search_fixture',
                'name': 'search_knowledge',
                'arguments': '{}',
              },
            ],
          ),
        ]);
      }
      return count == 2
          ? fixtureSse([
              completed(
                output: [
                  {
                    'type': 'reasoning',
                    'id': 'rs_quiz',
                    'encrypted_content': 'opaque-quiz',
                    'summary': [],
                  },
                  {
                    'type': 'function_call',
                    'namespace': 'tixun',
                    'call_id': 'quiz_fixture',
                    'name': 'create_quiz',
                    'arguments': jsonEncode({
                      'kind': 'single_choice',
                      'stem': '2 + 2 = ?',
                      'subject': '数学',
                      'options': {'A': '4', 'B': '5'},
                      'answers': [
                        ['A'],
                      ],
                      'explanation': '2+2=4',
                    }),
                  },
                ],
              ),
            ])
          : fixtureSse([
              {
                'type': 'response.output_text.delta',
                'delta': 'Try the question.',
              },
              completed(),
            ]);
    });
    final dir = await Directory.systemTemp.createTemp('tixun-chatgpt');
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(dir),
      f.keys,
      RoutedChatProvider(f.auth, client: responseClient),
    );
    await c.initialize();
    final original = c.config;
    await c.saveSettings(config, null);
    await c.prepareQuickQuiz();
    expect(c.sessionConfig.thinking, true);
    await c.setTools(true);
    await c.send(c.selected!.draft);
    expect(c.error, isNull);
    expect(
      (await c.db.select(c.db.practiceQuestions).get()).single.stem,
      '2 + 2 = ?',
    );
    expect(sent.last['input'].any((p) => p['type'] == 'reasoning'), true);
    expect(c.messages.any((m) => m.content.contains('opaque-quiz')), false);
    await c.restoreApiProvider();
    expect(c.config, original);
    await c.shutdown();
    await dir.delete(recursive: true);
  });
  test('Connection tests wait for terminal completion and cannot hide a late quota failure', () async {
    final f = ChatGptFixture();
    await f.seed();
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter(
        (_) => fixtureSse([
          {'type': 'response.output_text.delta', 'delta': 'OK'},
          {
            'type': 'response.failed',
            'response': {
              'error': {'code': 'subscription_sharing_usage_limit_exceeded'},
            },
          },
        ]),
      );
    final root = await Directory.systemTemp.createTemp('tixun-chatgpt-connect');
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      f.keys,
      RoutedChatProvider(f.auth, client: client),
    );
    await c.initialize();
    await expectLater(
      c.testConnection(config, null),
      throwsA(isA<AiFailure>()),
    );
    expect(c.config.kind, 'deepseek');
    await c.shutdown();
    await root.delete(recursive: true);
  });

  test('Cancelled inference cannot start an HTTP request', () async {
    final f = ChatGptFixture();
    await f.seed();
    var calls = 0;
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((_) {
        calls++;
        return fixtureSse([completed()]);
      });
    final cancel = CancelToken()..cancel();
    await expectLater(
      ChatGptResponses(f.auth, client: client)
          .start(config)
          .complete(AiRequest(instructions: '', messages: []), cancel)
          .drain<void>(),
      throwsA(isA<DioException>()),
    );
    expect(calls, 0);
  });

  test('An in-flight refresh cannot restore tokens after sign-out', () async {
    final f = ChatGptFixture();
    await f.seed(expired: true);
    f.refreshGate = Completer<void>();
    final refresh = f.auth.accessToken();
    final expectation = expectLater(refresh, throwsA(isA<AiFailure>()));
    while (f.refreshes == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await f.auth.signOut('oaiapp_fixture:student');
    f.refreshGate!.complete();
    await expectation;
    expect((await f.auth.snapshot()).accounts.single.connected, false);
  });
  test('Backups include provider settings but exclude OAuth tokens and require sign-in on another device', () async {
    final f = ChatGptFixture();
    await f.seed();
    final parent = await Directory.systemTemp.createTemp(
      'tixun-chatgpt-backup',
    );
    final root = Directory('${parent.path}/app');
    var c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: f.keys,
      chatProvider: RoutedChatProvider(f.auth),
    );
    await c.saveSettings(config, null);
    final archive = File('${parent.path}/learning.tixun-backup');
    await BackupService.export(c.db, c.files, archive);
    final contents = ZipDecoder().decodeBytes(await archive.readAsBytes());
    for (final file in contents.files.where((f) => f.isFile)) {
      final bytes = latin1.decode(file.content);
      expect(bytes, isNot(contains('access-fixture')));
      expect(bytes, isNot(contains('refresh-fixture')));
    }
    final prepared = await BackupService.prepare(archive, root);
    await c.shutdown();
    final activation = await BackupService.activate(prepared, root);
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
    );
    await BackupService.finish(activation);
    await prepared.discard();
    expect(c.config.kind, 'chatgpt');
    expect((await c.chatGpt.snapshot()).accounts, isEmpty);
    await expectLater(
      c.testConnection(c.config, null),
      throwsA(isA<AiFailure>()),
    );
    await c.shutdown();
    await parent.delete(recursive: true);
  });
  test(
    'Sign-out invalidates local credentials before remote revocation finishes',
    () async {
      final f = ChatGptFixture();
      await f.seed();
      f.revokeGate = Completer<void>();
      final logout = f.auth.signOut('oaiapp_fixture:student');
      while (f.revocations == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect((await f.auth.snapshot()).accounts.single.connected, false);
      await expectLater(f.auth.accessToken(), throwsA(isA<AiFailure>()));
      await expectLater(f.auth.signIn(), throwsA(isA<AiFailure>()));
      f.revokeGate!.complete();
      expect(await logout, true);
    },
  );
  test('Cancelling one token waiter is immediate and does not duplicate or cancel a shared refresh', () async {
    final f = ChatGptFixture();
    await f.seed(expired: true);
    f.refreshGate = Completer<void>();
    final cancel = CancelToken();
    final first = f.auth.accessToken(cancel: cancel);
    final stopped = expectLater(first, throwsA(isA<DioException>()));
    final second = f.auth.accessToken();
    while (f.refreshes == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    cancel.cancel();
    await stopped.timeout(const Duration(seconds: 1));
    final third = f.auth.accessToken();
    f.refreshGate!.complete();
    expect(
      await Future.wait([second, third]),
      everyElement('refreshed-fixture'),
    );
    expect(f.refreshes, 1);
  });
  test('JWT header keys and key URLs are rejected even when attacker signs with the embedded key', () async {
    for (final field in ['jwk', 'jku', 'x5u']) {
      final f = ChatGptFixture();
      final attacker = JsonWebKey.generate('RS256');
      f.alternativeSigningKey = attacker;
      f.protectedHeaders[field] = field == 'jwk'
          ? JsonWebKey.fromCryptoKeys(
              publicKey: attacker.cryptoKeyPair.publicKey,
            ).toJson()
          : 'https://attacker.invalid/jwks';
      await expectLater(f.auth.signIn(), throwsA(isA<AiFailure>()));
      expect((await f.auth.snapshot()).accounts, isEmpty);
      expect(f.requests.every((r) => r.uri.host == 'auth.openai.com'), true);
    }
  });
}
