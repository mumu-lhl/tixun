import 'package:tixun/core/l10n/app_error.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../features/practice/practice_store.dart';
import '../../features/practice/question_spec.dart';
import '../../features/visual/visual_store.dart';
import '../database/database.dart';
import 'chat_provider.dart';
import 'study_tools.dart';
import 'visual_schema.dart';

final quizToolSchema = AiTool(
  name: 'create_quiz',
  description: '仅用户请求出题、测验或训练时创建交互题，不代替资料整理或讲解；本条出题回复不得透露答案与解析。answers 为按位置排列的二维数组：填空每项包含等价答案，多选每个正确选项单独一项。仅校验结构，答案仍待核对。依赖图片时用 image_indices 引用本次请求前4张图片（0起）；纯文字题不填。需要配图时用 visual_id 引用本次对话中已创建的图形：图形只展示题干所需的图，不含答案与解法；不填 visual_revision 时冻结图形当前状态作为题目快照，填了则引用该修订。考试模式使用 question_scene 和可选 solution_scene，一次性独立保存题面图与提交后解析图，不引用探索图。题面图不能含控件、时间线、隐藏图元或答案/解题标记；解析图只在提交后显示。点选题（point_select）必须带 visual_id 或 question_scene，答案是 "x,y" 形式的坐标；区域选择题（region_select）必须带 visual_id 或 question_scene，options 是区域图元 id 到名称的映射，答案是选中的区域 id。拖点题（drag_to_target）必须带 visual_id 或 question_scene 且图形中有点 draggable 为 true，答案是目标点的 "x,y" 坐标，学生把点拖到目标位置附近即算对；读图题（read_value）必须带 visual_id 或 question_scene，答案是学生从图中读出的数值。',
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
          'point_select',
          'region_select',
          'drag_to_target',
          'read_value',
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
      'visual_id': {'type': 'string'},
      'visual_revision': {'type': 'integer', 'minimum': 1},
      'question_scene': visualSceneSchema,
      'solution_scene': visualSceneSchema,
    },
    'required': ['kind', 'stem', 'subject', 'answers', 'explanation'],
  },
);

/// Exam figures are scoped to one atomic quiz write, never chat visuals.
final examQuizToolSchema = AiTool(
  name: quizToolSchema.name,
  description: 'Create an exam question only when requested. Never reveal answers or explanations in chat. Optional question_scene and solution_scene are separate inline Visual DSL objects saved atomically as private frozen snapshots. The question_scene must be static: no timeline, controls, hidden elements, answer markers or solution text. Put all worked solution diagrams in solution_scene, which is shown only after submission of the current attempt. Never reference existing visual IDs in exam mode. Point/drag/region/read_value kinds require question_scene; region options/answers use visible polygon IDs, point/drag answers use x,y coordinates. Use answers as one acceptable-answer list per response position. Content and scientific correctness remain unverified.',
  parameters: {
    ...quizToolSchema.parameters,
    'properties': {...(quizToolSchema.parameters['properties'] as Map)}
      ..remove('visual_id')
      ..remove('visual_revision'),
  },
);

Future<Map<String, dynamic>> executeQuizTool(
  PracticeStore store,
  ToolCall call, {
  required String sessionId,
  required String runId,
  required CancelToken cancel,
  List<Attachment> sourceImages = const [],
  VisualStore? visual,
  bool exam = false,
}) async {
  try {
    cancel.checkCancelled();
    if (call.arguments.length > 160000) {
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
    // Exam figures are inline, private assessment assets. Existing chat
    // figures cannot be imported with teaching controls/hidden solutions.
    if (exam && (spec.visualId != null || spec.solutionVisualId != null)) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '考试题图必须随出题独立保存，不能引用探索图。',
        ['visual_id'],
      );
    }
    if ((spec.visualId != null ||
            spec.questionScene != null ||
            spec.solutionScene != null) &&
        visual == null) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '当前会话未启用图形工具。',
        ['visual_id'],
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
      // PracticeStore owns validation and pinning for AI and manual
      // writes alike. Read the resulting pin for the tool response.
      final saved = (await store.detail(id)).spec;
      cancel.checkCancelled();
      final result = <String, dynamic>{
        'ok': true,
        'question_id': id,
        'verification': 'unverified',
        'visual_id': ?saved.visualId,
        'visual_revision': ?saved.visualRevision,
      };
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
              result: Value(jsonEncode(result)),
              createdAt: DateTime.now(),
            ),
          );
      return {...result, 'note': '题目已在应用显示，用户提交前不要透露答案。'};
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
