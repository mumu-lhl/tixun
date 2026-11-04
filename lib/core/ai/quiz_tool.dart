import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../features/practice/practice_store.dart';
import '../../features/practice/question_spec.dart';
import '../database/database.dart';
import 'chat_provider.dart';
import 'study_tools.dart';

final quizToolSchema = {
  'type': 'function',
  'function': {
    'name': 'create_quiz',
    'description': '在聊天中创建真实交互题。不要在正文提前公布答案。答案必须按位置给出二维数组，填空每个位置可有多个等价文字答案，多选每个正确选项单独一项。只检查结构一致性，模型答案仍待用户核对。',
    'parameters': {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'kind': {
          'type': 'string',
          'enum': [
            'single_choice',
            'multiple_choice',
            'true_false',
            'fill_blank',
            'numeric',
          ],
        },
        'stem': {'type': 'string'},
        'subject': {'type': 'string'},
        'options': {
          'type': 'object',
          'additionalProperties': {'type': 'string'},
        },
        'answers': {
          'type': 'array',
          'items': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'explanation': {'type': 'string'},
        'hint': {'type': 'string'},
        'topics': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'absolute_tolerance': {'type': 'number', 'minimum': 0, 'maximum': 100},
        'relative_tolerance': {'type': 'number', 'minimum': 0, 'maximum': 0.1},
        'case_sensitive': {'type': 'boolean'},
        'time_limit_seconds': {
          'type': 'integer',
          'minimum': 10,
          'maximum': 7200,
        },
      },
      'required': ['kind', 'stem', 'subject', 'answers', 'explanation'],
    },
  },
};

Future<Map<String, dynamic>> executeQuizTool(
  PracticeStore store,
  ToolCall call, {
  required String sessionId,
  required String runId,
  required CancelToken cancel,
}) async {
  try {
    cancel.checkCancelled();
    if (call.arguments.length > 64000) throw const FormatException('题目数据过长。');
    final args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
    final spec = QuestionSpec.fromJson(args);
    if (spec.kind == 'short_answer') {
      throw const FormatException('模型当前不能创建自主判分题。');
    }
    final encoded = canonicalJson(args);
    final operation = '$runId:quiz:${sha256.convert(utf8.encode(encoded))}';
    final id = await store.db.transaction(() async {
      cancel.checkCancelled();
      final old = await (store.db.select(
        store.db.aiToolOperations,
      )..where((t) => t.id.equals('$runId:${call.id}'))).getSingleOrNull();
      if (old != null && (old.arguments != encoded || old.name != call.name)) {
        throw const FormatException('工具调用 ID 已被其他参数使用。');
      }
      final id = await store.create(
        spec,
        origin: 'ai',
        verification: 'unverified',
        sessionId: sessionId,
        messageId: runId,
        operation: operation,
      );
      cancel.checkCancelled();
      await store.db
          .into(store.db.aiToolOperations)
          .insertOnConflictUpdate(
            AiToolOperationsCompanion.insert(
              id: '$runId:${call.id}',
              runId: runId,
              sessionId: sessionId,
              name: 'create_quiz',
              arguments: encoded,
              status: 'succeeded',
              result: Value(
                jsonEncode({
                  'ok': true,
                  'question_id': id,
                  'verification': 'unverified',
                }),
              ),
              createdAt: DateTime.now(),
            ),
          );
      return id;
    });
    return {'ok': true, 'question_id': id, 'note': '题目已在应用显示，用户提交前不要透露答案。'};
  } on DioException {
    rethrow;
  } catch (e) {
    return {
      'ok': false,
      'error': e is FormatException ? e.message : '题目数据无效或保存失败，未创建题目。',
    };
  }
}
