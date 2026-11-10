import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/context_compactor.dart';
import 'package:tixun/core/ai/token_estimator.dart';
import 'package:tixun/core/database/database.dart';

void main() {
  group('estimateTokens', () {
    test('empty text costs nothing', () {
      expect(estimateTokens(''), 0);
    });
    test('ASCII costs about four characters per token', () {
      // 10 letters + 1 space: (10 * 0.25 + 0.5) * 1.25 = 3.75 -> 4.
      expect(estimateTokens('hello world'), 4);
    });
    test('CJK characters cost about one token each', () {
      // 4 * 1 * 1.25 = 5.
      expect(estimateTokens('你好世界'), 5);
    });
    test('mixed text sums the script costs', () {
      // (2 * 1 + 5 * 0.25) * 1.25 = 4.0625 -> 5.
      expect(estimateTokens('你好hello'), 5);
    });
    test('emoji costs more than text', () {
      // 2 * 1.25 = 2.5 -> 3.
      expect(estimateTokens('🎉'), 3);
    });
    test('longer text never estimates cheaper', () {
      expect(
        estimateTokens('二次函数顶点公式'),
        lessThanOrEqualTo(estimateTokens('二次函数顶点公式，再说一遍配方法')),
      );
    });
  });

  group('modelContextWindow', () {
    Future<ProviderConfig> configFor(
      String model, {
      String kind = 'deepseek',
    }) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final config = await db.config();
      return config.copyWith(kind: kind, model: model);
    }

    test('DeepSeek V4 models have a 1M window', () async {
      expect(modelContextWindow(await configFor('deepseek-flash')), 1000000);
      expect(modelContextWindow(await configFor('deepseek-v4-pro')), 1000000);
    });
    test(
      'legacy DeepSeek and GPT families have their documented windows',
      () async {
        expect(modelContextWindow(await configFor('deepseek-chat')), 131072);
        expect(
          modelContextWindow(await configFor('gpt-5-mini', kind: 'chatgpt')),
          400000,
        );
        expect(
          modelContextWindow(await configFor('gpt-4o', kind: 'compatible')),
          131072,
        );
      },
    );
    test('unknown models have no window cap', () async {
      expect(modelContextWindow(await configFor('my-model')), isNull);
    });
    test('effective budget reserves room for the reply', () async {
      final config = await configFor('deepseek-flash');
      expect(
        effectiveContextBudget(config: config, maxContextTokens: 128000),
        128000 - kResponseReserveTokens,
      );
      // A 1M window never lifts the setting; the setting governs.
      expect(
        effectiveContextBudget(config: config, maxContextTokens: 2000000),
        1000000 - kResponseReserveTokens,
      );
      // A tiny setting still leaves a usable window.
      expect(
        effectiveContextBudget(config: config, maxContextTokens: 4096),
        2048,
      );
    });
    test('loadMaxContextTokens defaults and clamps', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(await loadMaxContextTokens(db), kDefaultMaxContextTokens);
      await db.setPreference('max_context_tokens', '64000');
      expect(await loadMaxContextTokens(db), 64000);
      await db.setPreference('max_context_tokens', 'not-a-number');
      expect(await loadMaxContextTokens(db), kDefaultMaxContextTokens);
      await db.setPreference('max_context_tokens', '100');
      expect(await loadMaxContextTokens(db), kMinMaxContextTokens);
      await db.setPreference('max_context_tokens', '999999999');
      expect(await loadMaxContextTokens(db), kMaxMaxContextTokens);
    });
  });

  ChatMessage message(
    String id,
    String content, {
    String role = 'user',
    String status = 'complete',
    int? totalTokens,
  }) => ChatMessage(
    id: id,
    sessionId: 's',
    role: role,
    content: content,
    status: status,
    totalTokens: totalTokens,
    createdAt: DateTime(2026),
  );

  group('selectRecentWithinBudget', () {
    // 'a' * 400 and '中' * 100 both estimate to 125 tokens, so a
    // user/assistant pair costs exactly 250.
    final history = [
      message('u1', 'a' * 400),
      message('a1', '中' * 100, role: 'assistant'),
      message('u2', 'a' * 400),
      message('a2', '中' * 100, role: 'assistant'),
      message('u3', 'a' * 400),
    ];

    test('keeps whole turns within the budget', () {
      // 500 fits two pairs; the oldest pair is cut, the leading
      // assistant of the cut turn is trimmed.
      expect(
        selectRecentWithinBudget(history, tokenBudget: 500).map((m) => m.id),
        ['u2', 'a2', 'u3'],
      );
    });
    test('everything fits when the budget is large', () {
      expect(
        selectRecentWithinBudget(history, tokenBudget: 100000).map((m) => m.id),
        ['u1', 'a1', 'u2', 'a2', 'u3'],
      );
    });
    test('the newest user message is always kept whole', () {
      final huge = [
        message('u1', 'a' * 400),
        message('a1', '中' * 100, role: 'assistant'),
        message('u2', '中' * 4000),
      ];
      expect(
        selectRecentWithinBudget(huge, tokenBudget: 300).map((m) => m.id),
        ['u2'],
      );
    });
    test('incomplete assistant messages are never sent', () {
      final withGenerating = [
        message('u1', '第一问'),
        message('a1', '正在生成', role: 'assistant', status: 'generating'),
        message('u2', '继续问'),
      ];
      expect(
        selectRecentWithinBudget(
          withGenerating,
          tokenBudget: 100000,
        ).map((m) => m.id),
        ['u1', 'u2'],
      );
    });
  });

  group('compactContext', () {
    Future<(AppDatabase, ChatSession, ProviderConfig)> setup() async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final session = await db.createSession(title: '压缩测试');
      final config = await db.config();
      return (db, session, config);
    }

    Future<void> insertMessages(
      AppDatabase db,
      String sessionId,
      List<ChatMessage> messages,
    ) async {
      for (final m in messages) {
        await db
            .into(db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: m.id,
                sessionId: sessionId,
                role: m.role,
                content: m.content,
                totalTokens: m.totalTokens == null
                    ? const Value.absent()
                    : Value(m.totalTokens),
                createdAt: m.createdAt,
              ),
            );
      }
    }

    // Six turns of 1250 tokens each ('中' * 1000).
    List<ChatMessage> longHistory() => [
      message('u1', '中' * 1000),
      message('a1', '中' * 1000, role: 'assistant'),
      message('u2', '中' * 1000),
      message('a2', '中' * 1000, role: 'assistant'),
      message('u3', '中' * 1000),
      message('a3', '中' * 1000, role: 'assistant'),
    ];

    test('short history passes through without a summary', () async {
      final (db, session, config) = await setup();
      final history = [
        message('u1', '二次函数顶点怎么求'),
        message('a1', '配方后看平方项为零的位置', role: 'assistant'),
        message('u2', '再举个例子'),
      ];
      await insertMessages(db, session.id, history);
      final compacted = await compactContext(
        db: db,
        sessionId: session.id,
        history: history,
        images: const [],
        config: config,
        provider: MockChatProvider(),
        maxContextTokens: kDefaultMaxContextTokens,
        cancel: CancelToken(),
      );
      expect(compacted.summary, isNull);
      expect(compacted.selected.map((m) => m.id), ['u1', 'a1', 'u2']);
      expect(compacted.droppedUncovered, 0);
    });

    test('long history is summarized and the summary is persisted', () async {
      final (db, session, config) = await setup();
      final history = longHistory();
      await insertMessages(db, session.id, history);
      final compacted = await compactContext(
        db: db,
        sessionId: session.id,
        history: history,
        images: const [],
        config: config,
        provider: MockChatProvider(),
        maxContextTokens: 8192,
        cancel: CancelToken(),
      );
      // The mock provider returns the fixed explanation, so the stored
      // summary is mock text; the test pins the mechanics, not the wording.
      expect(compacted.summary, isNotNull);
      expect(compacted.summary, contains('二次函数'));
      expect(compacted.selected.map((m) => m.id), ['u3', 'a3']);
      expect(compacted.droppedUncovered, 0);
      final stored = (await db.sessions()).single;
      expect(stored.contextSummary, compacted.summary);
      expect(stored.contextSummaryUpToId, 'a2');
      // A second send reuses the stored summary instead of summarizing again.
      final again = await compactContext(
        db: db,
        sessionId: session.id,
        history: history,
        images: const [],
        config: config,
        provider: MockChatProvider(),
        maxContextTokens: 8192,
        cancel: CancelToken(),
      );
      expect(again.summary, compacted.summary);
      expect(again.selected.map((m) => m.id), ['u3', 'a3']);
    });

    test('real usage from the last turn triggers compaction', () async {
      final (db, session, config) = await setup();
      // The text itself (7500 tokens) fits the 20000-token budget, but
      // the last assistant message reports 20000 total tokens for the
      // previous request — the usage path must still trigger compaction.
      final history = longHistory()
          .map(
            (m) => m.id == 'a3'
                ? message(
                    'a3',
                    '中' * 1000,
                    role: 'assistant',
                    totalTokens: 20000,
                  )
                : m,
          )
          .toList();
      await insertMessages(db, session.id, history);
      final compacted = await compactContext(
        db: db,
        sessionId: session.id,
        history: history,
        images: const [],
        config: config,
        provider: MockChatProvider(),
        maxContextTokens: 20000,
        cancel: CancelToken(),
      );
      expect(compacted.summary, isNotNull);
      // Summarized turns are covered by the summary, not sent again.
      expect(compacted.selected.map((m) => m.id), ['u3', 'a3']);
      expect(compacted.droppedUncovered, 0);
    });

    test('a failed summarization degrades to dropping oldest turns', () async {
      final (db, session, config) = await setup();
      final history = longHistory();
      await insertMessages(db, session.id, history);
      final compacted = await compactContext(
        db: db,
        sessionId: session.id,
        history: history,
        images: const [],
        config: config,
        provider: _FailingProvider(),
        maxContextTokens: 8192,
        cancel: CancelToken(),
      );
      expect(compacted.summary, isNull);
      // The newest turn survives; the dropped turns are reported.
      expect(compacted.selected.map((m) => m.id), contains('u3'));
      expect(compacted.droppedUncovered, greaterThan(0));
      expect((await db.sessions()).single.contextSummary, isNull);
    });
  });
}

class _FailingProvider implements ChatProvider {
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((_, _) async* {
        throw const AiFailure('nope');
      });
}
