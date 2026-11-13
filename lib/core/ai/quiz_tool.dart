import 'package:tixun/core/l10n/app_error.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../features/practice/practice_store.dart';
import '../../features/practice/question_spec.dart';
import '../database/database.dart';
import 'chat_provider.dart';
import 'study_tools.dart';

final quizToolSchema = AiTool(
  name: 'create_quiz',
  description: '仅用户请求出题、测验或训练时创建交互题，不代替资料整理或讲解；本条出题回复不得透露答案与解析。answers 为按位置排列的二维数组：填空每项包含等价答案，多选每个正确选项单独一项。仅校验结构，答案仍待核对。依赖图片时用 image_indices 引用本次请求前4张图片（0起）；纯文字题不填。',
  parameters: {
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
      'image_indices': {
        'type': 'array',
        'items': {'type': 'integer', 'minimum': 0, 'maximum': 3},
        'maxItems': 4,
      },
      'time_limit_seconds': {'type': 'integer', 'minimum': 10, 'maximum': 7200},
    },
    'required': ['kind', 'stem', 'subject', 'answers', 'explanation'],
  },
);

Future<Map<String, dynamic>> executeQuizTool(
  PracticeStore store,
  ToolCall call, {
  required String sessionId,
  required String runId,
  required CancelToken cancel,
  List<Attachment> sourceImages = const [],
}) async {
  try {
    cancel.checkCancelled();
    if (call.arguments.length > 64000) {
      throw const AppFormatException(
        AppErrorCode.errorQuestionDataIsTooLong,
        '题目数据过长。',
      );
    }
    final args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
    final indices = args.containsKey('image_indices')
        ? args['image_indices']
        : <dynamic>[];
    if (indices is! List ||
        indices.length > 4 ||
        indices.toSet().length != indices.length ||
        indices.any(
          (i) =>
              i is! int ||
              i < 0 ||
              i >= sourceImages.length ||
              sourceImages[i].sessionId != sessionId,
        )) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidQuestionImageReference,
        '题目图片引用无效。',
      );
    }
    final spec = QuestionSpec.fromJson({...args}..remove('image_indices'));
    if (spec.kind == 'short_answer') {
      throw const AppFormatException(
        AppErrorCode.errorThisModelCannotCurrentlyCreateSelf,
        '模型当前不能创建自主判分题。',
      );
    }
    final encoded = canonicalJson(args);
    final operation = '$runId:quiz:${sha256.convert(utf8.encode(encoded))}';
    final result = await store.db.transaction(() async {
      cancel.checkCancelled();
      final old = await (store.db.select(
        store.db.aiToolOperations,
      )..where((t) => t.id.equals('$runId:${call.id}'))).getSingleOrNull();
      if (old != null && (old.arguments != encoded || old.name != call.name)) {
        throw const AppFormatException(
          AppErrorCode.errorThisToolCallIDHasAlready,
          '工具调用 ID 已被其他参数使用。',
        );
      }
      // Same call replayed: return the cached result like region_tool does
      // instead of creating the question a second time.
      if (old != null && old.status == 'succeeded' && old.result != null) {
        return (jsonDecode(old.result!) as Map).cast<String, dynamic>();
      }
      final links =
          await (store.db.select(store.db.studyChatLinks)
                ..where((l) => l.sessionId.equals(sessionId))
                ..limit(5))
              .get();
      final parentId = await store.db.preference('practice_parent:$sessionId');
      final parent = parentId == null
          ? null
          : await (store.db.select(
              store.db.practiceQuestions,
            )..where((q) => q.id.equals(parentId))).getSingleOrNull();
      final id = await store.create(
        spec,
        origin: 'ai',
        verification: 'unverified',
        sessionId: sessionId,
        messageId: runId,
        operation: operation,
        parentId: parent?.id,
        mistakeId:
            parent?.mistakeId ??
            links.map((l) => l.mistakeId).whereType<String>().firstOrNull,
        knowledgeIds: links
            .map((l) => l.knowledgeId)
            .whereType<String>()
            .toList(),
        sourceImages: indices.map((i) => sourceImages[i as int]).toList(),
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
      return <String, dynamic>{
        'ok': true,
        'question_id': id,
        'note': '题目已在应用显示，用户提交前不要透露答案。',
      };
    });
    return result;
  } on DioException {
    rethrow;
  } catch (e) {
    return {
      'ok': false,
      'error': e is FormatException ? e.message : '题目数据无效或保存失败，未创建题目。',
    };
  }
}
