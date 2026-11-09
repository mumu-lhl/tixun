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
  description: '在聊天中创建真实交互题。不要在正文提前公布答案。答案必须按位置给出二维数组，填空每个位置可有多个等价文字答案，多选每个正确选项单独一项。只检查结构一致性，模型答案仍待用户核对。题目依赖本次请求的图片时，必须用 image_indices 明确引用图片序号；纯文字题不填写。仅本次请求中的前 4 张图片可用 image_indices 引用（序号从 0 开始）。',
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
    if (call.arguments.length > 64000) throw const FormatException('题目数据过长。');
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
      throw const FormatException('题目图片引用无效。');
    }
    final spec = QuestionSpec.fromJson({...args}..remove('image_indices'));
    if (spec.kind == 'short_answer') {
      throw const FormatException('模型当前不能创建自主判分题。');
    }
    final encoded = canonicalJson(args);
    final operation = '$runId:quiz:${sha256.convert(utf8.encode(encoded))}';
    final result = await store.db.transaction(() async {
      cancel.checkCancelled();
      final old = await (store.db.select(
        store.db.aiToolOperations,
      )..where((t) => t.id.equals('$runId:${call.id}'))).getSingleOrNull();
      if (old != null && (old.arguments != encoded || old.name != call.name)) {
        throw const FormatException('工具调用 ID 已被其他参数使用。');
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
