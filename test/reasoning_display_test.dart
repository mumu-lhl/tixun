import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/chatgpt/responses.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/core/ui/reasoning_panel.dart';
import 'package:tixun/features/chat/message_reasoning.dart';
import 'package:tixun/features/chat/reasoning_menu.dart';
import 'package:tixun/features/practice/question_spec.dart';

class TraceProvider implements ChatProvider {
  TraceProvider({this.fail = false});
  final bool fail;
  final gate = Completer<void>(), started = Completer<void>();
  int round = 0;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        round++;
        if (round == 1) {
          yield const AiChunk(reasoning: '第一轮：先查询资料。');
          started.complete();
          await gate.future;
          cancel.checkCancelled();
          if (fail) throw const AiFailure('模拟断线');
          yield const AiChunk(
            completed: true,
            calls: [ToolCall('lookup', 'search_knowledge', '{}')],
          );
        } else {
          yield const AiChunk(reasoning: '第二轮：依据资料解释。');
          yield const AiChunk(text: '正文回复', completed: true);
        }
      });
}

void main() {
  test('Thinking streams before body, persists across tool rounds and keeps wire context separate', () async {
    final root = await Directory.systemTemp.createTemp('tixun-thinking');
    final provider = TraceProvider();
    var c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
      chatProvider: provider,
    );
    await c.newSession();
    await c.setTools(true);
    final running = c.send('解释');
    await provider.started.future;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.messages.last.content, isEmpty);
    expect(c.messages.last.reasoningTrace, contains('第一轮'));
    provider.gate.complete();
    await running;
    final row = c.messages.last;
    expect(row.reasoningTrace, contains('第一轮'));
    expect(row.reasoningTrace, contains('第二轮'));
    expect(row.reasoningContent, '第二轮：依据资料解释。');
    expect(row.content, '正文回复');
    await c.shutdown();
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
      chatProvider: MockChatProvider(),
    );
    expect(c.messages.last.reasoningTrace, row.reasoningTrace);
    await c.shutdown();
    await root.delete(recursive: true);
  });

  test('Interrupted thinking remains available for inspection without a successful reply', () async {
    final root = await Directory.systemTemp.createTemp('tixun-thinking-error');
    final provider = TraceProvider(fail: true);
    final c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
      chatProvider: provider,
    );
    await c.newSession();
    final running = c.send('解释');
    await provider.started.future;
    provider.gate.complete();
    await running;
    expect(c.messages.last.status, 'error');
    expect(c.messages.last.reasoningTrace, contains('第一轮'));
    await c.shutdown();
    await root.delete(recursive: true);
  });

  test('Responses exposes public summaries, never encrypted internal reasoning, without duplication', () async {
    final events = [
      {'type': 'response.reasoning_summary_text.delta', 'delta': '公开摘要'},
      {
        'type': 'response.completed',
        'response': {
          'status': 'completed',
          'output': [
            {
              'type': 'reasoning',
              'encrypted_content': 'private-encrypted-state',
              'summary': [
                {'type': 'summary_text', 'text': '公开摘要'},
              ],
            },
          ],
        },
      },
    ];
    final chunks = await decodeResponses(
      Stream.value(
        utf8.encode(events.map((e) => 'data: ${jsonEncode(e)}\n\n').join()),
      ),
      null,
    ).toList();
    expect(chunks.map((e) => e.reasoning).join(), '公开摘要');
    final fallback = await decodeResponses(
      Stream.value(utf8.encode('data: ${jsonEncode(events.last)}\n\n')),
      null,
    ).toList();
    expect(fallback.map((e) => e.reasoning).join(), '公开摘要');
  });

  testWidgets(
    'Reasoning starts collapsed, expands and cannot be exposed while locked',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReasoningPanel(text: 'private-answer-content')),
        ),
      );
      expect(find.text('private-answer-content'), findsNothing);
      await tester.tap(find.byType(ListTile));
      await tester.pump();
      expect(find.text('private-answer-content'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReasoningPanel(text: 'private-answer-content', locked: true),
          ),
        ),
      );
      expect(find.text('private-answer-content'), findsNothing);
    },
  );

  testWidgets(
    'Quiz reasoning unlocks only after the current attempt is submitted',
    (tester) async {
      late Directory root;
      late AppController c;
      late ChatMessage message;
      late PracticeAttempt attempt;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('tixun-quiz-reasoning');
        c = await AppController.openRoot(
          root,
          demo: false,
          keyStore: MemoryKeyStore(),
          chatProvider: MockChatProvider(),
        );
        await c.newSession();
        const id = 'reasoning-message';
        await c.db
            .into(c.db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: id,
                sessionId: c.selected!.id,
                role: 'assistant',
                content: '题目',
                createdAt: DateTime.now(),
                reasoningTrace: const Value('答案为4'),
              ),
            );
        message = (await c.db.messages(c.selected!.id)).last;
        final quiz = await c.practice.create(
          const QuestionSpec(
            kind: 'numeric',
            stem: '2+2',
            answers: [
              ['4'],
            ],
          ),
          sessionId: c.selected!.id,
          messageId: id,
        );
        attempt = await c.practice.begin(quiz);
      });
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(home: Scaffold(body: MessageReasoning(message))),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReasoningPanel>(find.byType(ReasoningPanel)).locked,
        true,
      );
      await tester.runAsync(() => c.practice.submit(attempt.id, ['4']));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReasoningPanel>(find.byType(ReasoningPanel)).locked,
        false,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        scope.dispose();
        await c.shutdown();
        await root.delete(recursive: true);
      });
    },
  );

  testWidgets(
    'Reasoning menu does not highlight when thinking is on with effort none',
    (tester) async {
      late Directory root;
      late AppController c;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('tixun-reasoning-menu');
        c = await AppController.openRoot(
          root,
          demo: false,
          keyStore: MemoryKeyStore(),
          chatProvider: MockChatProvider(),
        );
        await c.newSession();
        c.config = (await c.db.config()).copyWith(
          kind: 'compatible',
          baseUrl: 'https://example.com/v1',
          model: 'gpt-5.6',
          supportsThinking: true,
          thinking: true,
          effort: 'high',
        );
        await c.setSessionReasoning('none');
      });
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(home: Scaffold(body: ReasoningMenu())),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.psychology_outlined)).color,
        isNull,
      );
      await tester.runAsync(() => c.setSessionReasoning('high'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.psychology_outlined)).color,
        Theme.of(tester.element(find.byIcon(Icons.psychology_outlined)))
            .colorScheme
            .primary,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        scope.dispose();
        await c.shutdown();
        await root.delete(recursive: true);
      });
    },
  );

  testWidgets(
    'A failed reasoning-lock query leaves the panel expandable with a retry',
    (tester) async {
      late Directory root;
      late AppController c;
      late ChatMessage message;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('tixun-reasoning-error');
        c = await AppController.openRoot(
          root,
          demo: false,
          keyStore: MemoryKeyStore(),
          chatProvider: MockChatProvider(),
        );
        await c.newSession();
        const id = 'reasoning-error-message';
        await c.db
            .into(c.db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: id,
                sessionId: c.selected!.id,
                role: 'assistant',
                content: '题目',
                createdAt: DateTime.now(),
                reasoningTrace: const Value('答案为4'),
              ),
            );
        message = (await c.db.messages(c.selected!.id)).last;
      });
      final scope = ProviderContainer(
        overrides: [
          appControllerProvider.overrideWith((ref) => c),
          reasoningLockedProvider(message.id)
              .overrideWith((ref) => Stream<bool>.error(StateError('boom'))),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(home: Scaffold(body: MessageReasoning(message))),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReasoningPanel>(find.byType(ReasoningPanel)).locked,
        false,
      );
      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      // The invalidated query errors again; wait for it to land instead
      // of catching the brief loading state.
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReasoningPanel>(find.byType(ReasoningPanel)).locked,
        false,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        scope.dispose();
        await c.shutdown();
        await root.delete(recursive: true);
      });
    },
  );
}
