import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

// Replay the observed unwanted quiz choice whenever the tool is offered.
// The application must withhold it for an explicit reference-only request.
class _QuizChoice implements ChatProvider {
  _QuizChoice({this.ignoreAvailability = false});
  final bool ignoreAvailability;
  AiRequest? request;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((req, cancel) async* {
        request = req;
        if (ignoreAvailability ||
            req.tools.any((t) => t.name == 'create_quiz')) {
          yield AiChunk(
            calls: [
              ToolCall(
                'unexpected-quiz',
                'create_quiz',
                jsonEncode({
                  'kind': 'single_choice',
                  'stem': '2 + 2 = ?',
                  'subject': '数学',
                  'options': {'A': '4', 'B': '5'},
                  'answers': [
                    ['A'],
                  ],
                  'explanation': '2 + 2 = 4',
                }),
              ),
            ],
            completed: true,
          );
        } else {
          yield const AiChunk(
            text: '数学公式清单：函数、三角函数、数列、立体几何、解析几何与概率。',
            completed: true,
          );
        }
      });
}

void main() {
  for (final mode in ['guided', 'direct', 'exam']) {
    test(
      'Formula reference requests receive content in $mode without creating a quiz',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'tixun-study-intent',
        );
        final provider = _QuizChoice();
        final c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          provider,
        );
        await c.initialize();
        addTearDown(() async {
          await c.shutdown();
          await root.delete(recursive: true);
        });
        await c.newSession();
        await c.mode(mode);
        await c.send('请尽可能梳理高三一模需要复习的所有数学公式，明天就是一模了');
        expect(c.messages.last.status, 'complete');
        expect(c.messages.last.content, contains('公式清单'));
        expect(await c.db.select(c.db.practiceQuestions).get(), isEmpty);
        expect(
          provider.request!.tools.any((t) => t.name == 'create_quiz'),
          false,
        );
        expect(
          c.selected!.mode,
          mode,
          reason: 'The per-turn task must not rewrite the saved teaching mode',
        );
        await c.send('现在给我出一道检测题');
        expect(await c.db.select(c.db.practiceQuestions).get(), hasLength(1));
      },
    );
  }
  test(
    'Coordinated quiz opt-outs remain reference requests in exam mode',
    () async {
      final root = await Directory.systemTemp.createTemp('tixun-quiz-optout');
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        _QuizChoice(),
      );
      await c.initialize();
      addTearDown(() async {
        await c.shutdown();
        await root.delete(recursive: true);
      });
      await c.mode('exam');
      await c.send('不要出题和测验，只要数学公式清单');
      expect(c.messages.last.content, contains('公式清单'));
      expect(await c.db.select(c.db.practiceQuestions).get(), isEmpty);
    },
  );
  test(
    'Unadvertised quiz calls cannot modify data during a material request',
    () async {
      final root = await Directory.systemTemp.createTemp('tixun-intent-tool');
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        _QuizChoice(ignoreAvailability: true),
      );
      await c.initialize();
      addTearDown(() async {
        await c.shutdown();
        await root.delete(recursive: true);
      });
      await c.send('Summarize the formulas as a revision checklist. No quiz.');
      expect(c.messages.last.status, 'error');
      expect(await c.db.select(c.db.practiceQuestions).get(), isEmpty);
    },
  );
}
