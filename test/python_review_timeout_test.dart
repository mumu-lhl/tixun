import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/prompt_settings.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/python/python_tool.dart';
import 'package:tixun/features/chat/learning_run.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/review/review_store.dart';

class _Calculation implements ChatProvider {
  int round = 0;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((req, cancel) async* {
        if (round++ == 0) {
          yield const AiChunk(
            calls: [
              ToolCall(
                'calc',
                'run_python',
                '{"code":"print(9)","purpose":"核对结果"}',
              ),
            ],
            completed: true,
          );
        } else {
          yield const AiChunk(text: '计算结果为9。', completed: true);
        }
      });
}

void main() {
  test(
    'Reviewing code pauses the inference deadline without bypassing approval',
    () async {
      final db = AppDatabase.memory();
      final root = await Directory.systemTemp.createTemp('review-deadline');
      final files = AttachmentStore(root);
      final study = StudyStore(db, files);
      final practice = PracticeStore(db, files: files);
      final review = ReviewStore(db);
      final session = await db.createSession();
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: 'user',
              sessionId: session.id,
              role: 'user',
              content: '用Python核对计算',
              createdAt: DateTime.now(),
            ),
          );
      var executed = false;
      final python = PythonTool(
        db,
        root,
        execute:
            ({
              required code,
              required workspace,
              required timeoutSeconds,
              required cancel,
            }) async {
              executed = true;
              return {'ok': true, 'stdout': '9'};
            },
      );
      final run = LearningRun(
        db,
        files,
        study,
        practice,
        review,
        _Calculation(),
        pythonTool: python,
      );
      final result = await runZoned(
        () async => run.run(
          sessionId: session.id,
          runId: 'answer',
          requestConfig: await db.config(),
          requestPrompts: PromptSettings(),
          history: await db.messages(session.id),
          images: [],
          mode: 'direct',
          authorized: false,
          cancel: CancelToken(),
          confirm: (_, args, count) async {
            expect(executed, false);
            await Future<void>.delayed(const Duration(milliseconds: 700));
            return true;
          },
          onProgress: (_) async {},
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) =>
              parent.createTimer(
                zone,
                duration == const Duration(minutes: 3)
                    ? const Duration(milliseconds: 300)
                    : duration,
                callback,
              ),
        ),
      );
      expect(executed, true);
      expect(result.text, contains('9'));
      study.dispose();
      practice.dispose();
      review.dispose();
      await db.close();
      await root.delete(recursive: true);
    },
  );
}
