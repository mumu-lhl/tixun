import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/chatgpt/responses.dart';
import 'package:tixun/core/database/database.dart';

import 'support/chatgpt_fixture.dart';

void main() {
  late AppDatabase db;
  late ProviderConfig base;
  setUp(() async {
    db = AppDatabase.memory();
    base = await db.config();
  });
  tearDown(() => db.close());
  ProviderConfig gpt(String model) => base.copyWith(
    kind: 'chatgpt',
    baseUrl: 'https://api.openai.com/v1',
    model: model,
    thinking: true,
  );

  test('Model-specific levels distinguish default, none, minimal, medium, xhigh and max', () {
    expect(AiOptions(gpt('gpt-6.1-sol')).reasoningEfforts, [
      'low',
      'medium',
      'high',
      'xhigh',
      'max',
    ]);
    // gpt-6-pro must hit the -pro rule, not the gpt-6 prefix rule.
    expect(AiOptions(gpt('gpt-6-pro')).reasoningEfforts, isEmpty);
    expect(AiOptions(gpt('gpt-6.1-pro')).reasoningEfforts, isEmpty);
    expect(AiOptions(gpt('gpt-5')).reasoningEfforts, [
      'minimal',
      'low',
      'medium',
      'high',
    ]);
    expect(AiOptions(gpt('gpt-5.2')).reasoningEfforts, [
      'none',
      'low',
      'medium',
      'high',
      'xhigh',
    ]);
    expect(AiOptions(gpt('unknown-account-model')).reasoningEfforts, isEmpty);
    expect(AiOptions(base).reasoningEfforts, ['low', 'high', 'max']);
    expect(
      () => validateConfig(gpt('gpt-6.1-sol').copyWith(effort: 'none')),
      throwsFormatException,
    );
    expect(
      () => validateConfig(gpt('gpt-5').copyWith(effort: 'max')),
      throwsFormatException,
    );
    final none = gpt('gpt-5.2').copyWith(effort: 'none');
    validateConfig(none);
    expect(AiOptions(none).reasoningEnabled, false);
    expect(AiOptions(none).effortParameter, 'none');
    expect(AiOptions.forSession(none, 'off').thinking, false);
  });
  test('Catalog declarations override fallbacks and additional advertised levels pass through verbatim', () {
    final declared = advertisedReasoningLevels({
      'supported_reasoning_levels': [
        {'effort': 'medium'},
        {'effort': 'ultra'},
      ],
    });
    expect(declared, ['medium', 'ultra']);
    final config = gpt(
      'new-account-model',
    ).copyWith(reasoningLevels: Value(jsonEncode(declared)), effort: 'ultra');
    validateConfig(config);
    expect(AiOptions(config).reasoningEfforts, ['medium', 'ultra']);
    expect(AiOptions(config).effortParameter, 'ultra');
    expect(
      advertisedReasoningLevels({
        'supported_reasoning_efforts': ['low', 'medium'],
      }),
      ['low', 'medium'],
    );
    expect(
      advertisedReasoningLevels({'supported_reasoning_levels': []}),
      isEmpty,
    );
    expect(
      advertisedReasoningLevels({
        'supported_reasoning_levels': [42],
      }),
      isNull,
    );
    expect(
      advertisedReasoningLevels({
        'supported_reasoning_levels': ['bad value'],
      }),
      isNull,
    );
    expect(
      AiOptions(config.copyWith(reasoningLevels: const Value('invalid')))
          .reasoningEfforts,
      isEmpty,
    );
  });
  test(
    'Capability metadata and selected effort persist without credentials',
    () async {
      final config = gpt('custom').copyWith(
        reasoningLevels: const Value('["medium","xhigh","max"]'),
        effort: 'max',
      );
      await db.saveConfig(config);
      final saved = await db.config();
      expect(saved.effort, 'max');
      expect(saved.reasoningLevels, config.reasoningLevels);
      expect(AiOptions(saved).reasoningEfforts, ['medium', 'xhigh', 'max']);
    },
  );
  test('Actual Responses requests send xhigh and max separately; default omits effort and none omits summary', () async {
    final fixture = ChatGptFixture();
    await fixture.auth.signIn();
    final bodies = <Map>[];
    final wire = Dio()
      ..httpClientAdapter = FixtureAdapter((r) {
        bodies.add(r.data as Map);
        return fixtureSse([
          {'type': 'response.output_text.delta', 'delta': 'ok'},
          {
            'type': 'response.completed',
            'response': {'status': 'completed', 'output': []},
          },
        ]);
      });
    final provider = ChatGptResponses(fixture.auth, client: wire);
    final request = AiRequest(
      instructions: '',
      messages: [const AiMessage.user('test')],
    );
    for (final effort in ['xhigh', 'max']) {
      await provider
          .start(gpt('gpt-6.1-sol').copyWith(effort: effort))
          .complete(request, CancelToken())
          .toList();
      expect((bodies.last['reasoning'] as Map)['effort'], effort);
    }
    await provider
        .start(gpt('gpt-6.1-sol').copyWith(thinking: false))
        .complete(request, CancelToken())
        .toList();
    expect(bodies.last.containsKey('reasoning'), false);
    await provider
        .start(gpt('gpt-5.2').copyWith(effort: 'none'))
        .complete(request, CancelToken())
        .toList();
    expect(bodies.last['reasoning'], {'effort': 'none'});
  });
}
