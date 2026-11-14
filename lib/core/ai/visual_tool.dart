import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../core/l10n/app_error.dart';
import '../../core/visual/math/sampling.dart';
import '../../core/visual/model/visual_scene.dart';
import '../../core/visual/validation/visual_validator.dart';
import '../../features/visual/visual_store.dart';
import '../database/database.dart';
import 'ai_types.dart';
import 'study_tools.dart';

final visualToolSchema = AiTool(
  name: 'create_visual',
  description: '仅当用户要求画图、画函数图像或可视化，或图形能清楚帮助理解时创建一幅教学图形；一次调用只生成一个图形。场景必须符合 Visual DSL v1（v 为 1，元素、表达式与资源上限以内）。考试模式下提交前不得通过图形透露答案；本工具不在考试模式提供。',
  parameters: {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'scene': {'type': 'object', 'description': 'Visual DSL v1 场景 JSON。'},
      'title': {'type': 'string', 'maxLength': 100},
      'alt': {'type': 'string', 'maxLength': 500},
    },
    'required': ['scene'],
  },
);

final updateVisualToolSchema = AiTool(
  name: 'update_visual',
  description: '仅当用户要求修改已有的图形时更新该图形的场景；一次调用只更新一个图形，场景必须是完整的 Visual DSL v1 JSON（不是增量补丁）。考试模式下提交前不得通过图形透露答案；本工具不在考试模式提供。',
  parameters: {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'visual_id': {'type': 'string', 'description': '要更新的图形 id。'},
      'scene': {
        'type': 'object',
        'description': 'Visual DSL v1 场景 JSON（完整场景）。',
      },
      'title': {'type': 'string', 'maxLength': 100},
    },
    'required': ['visual_id', 'scene'],
  },
);

final getVisualToolSchema = AiTool(
  name: 'get_visual',
  description: '读取一个已创建图形的场景 JSON，用于在修改前确认当前内容或指定版本的内容；只读，不产生新版本，不写入任何记录。',
  parameters: {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'visual_id': {'type': 'string', 'description': '要读取的图形 id。'},
      'revision': {
        'type': 'integer',
        'minimum': 1,
        'description': '版本号；不传则读当前版本。',
      },
    },
    'required': ['visual_id'],
  },
);

/// Updates one visual scene from an `update_visual` tool call.
///
/// Mirrors [executeVisualTool]: arguments are capped at 64 KiB, the new
/// scene is validated before anything is stored (an invalid scene creates
/// no revision), and idempotency uses the `aiToolOperations` row
/// `'$runId:${call.id}'`. Returns `{'ok': bool, ...}` and never throws
/// (except cancellation).
Future<Map<String, dynamic>> executeUpdateVisualTool(
  VisualStore store,
  ToolCall call, {
  required String sessionId,
  required String runId,
  required CancelToken cancel,
}) async {
  try {
    cancel.checkCancelled();
    if (call.arguments.length > 64000) {
      throw const AppFormatException(
        AppErrorCode.errorToolCallDataIsTooLong,
        '图形数据过长。',
      );
    }
    final args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
    for (final key in args.keys) {
      if (!{'visual_id', 'scene', 'title'}.contains(key)) {
        throw AppFormatException(
          AppErrorCode.errorUnknownParameter,
          '未知参数：$key。',
          [key],
        );
      }
    }
    final visualId = args['visual_id'];
    if (visualId == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        '缺少参数：visual_id。',
        ['visual_id'],
      );
    }
    if (visualId is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        '参数 visual_id 必须是文本。',
        ['visual_id'],
      );
    }
    final sceneArg = args['scene'];
    if (sceneArg == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        '缺少参数：scene。',
        ['scene'],
      );
    }
    if (sceneArg is! Map) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '参数 scene 必须是对象。',
        ['scene'],
      );
    }
    final title = args['title'];
    if (title != null && title is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        '参数 title 必须是文本。',
        ['title'],
      );
    }
    // Same merge rule as create: a tool-level title fills the gap when
    // the scene itself has none; the scene's own title wins.
    final merged = Map<String, dynamic>.of(sceneArg.cast<String, dynamic>());
    if (title is String && title.trim().isNotEmpty && merged['title'] == null) {
      merged['title'] = title;
    }
    // Validate before touching the store: an invalid scene must not
    // create a revision.
    final validation = validateVisualScene(merged);
    if (!validation.ok) {
      return {'ok': false, 'error': validation.errors.first.message};
    }
    final scene = VisualScene.fromJson(merged);
    final encoded = canonicalJson(args);
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
      // Same call replayed: return the cached result like quiz_tool does
      // instead of bumping the revision a second time.
      if (old != null && old.status == 'succeeded' && old.result != null) {
        return (jsonDecode(old.result!) as Map).cast<String, dynamic>();
      }
      final updated = await store.revise(visualId, jsonEncode(scene.toJson()));
      cancel.checkCancelled();
      await store.db
          .into(store.db.aiToolOperations)
          .insertOnConflictUpdate(
            AiToolOperationsCompanion.insert(
              id: '$runId:${call.id}',
              runId: runId,
              sessionId: sessionId,
              name: 'update_visual',
              arguments: encoded,
              status: 'succeeded',
              result: Value(
                jsonEncode({
                  'ok': true,
                  'visual_id': visualId,
                  'revision': updated.revision,
                  'verification': validation.verificationStatus,
                }),
              ),
              createdAt: DateTime.now(),
            ),
          );
      return <String, dynamic>{
        'ok': true,
        'visual_id': visualId,
        'revision': updated.revision,
        'verification': validation.verificationStatus,
      };
    });
    return result;
  } on DioException {
    rethrow;
  } catch (e) {
    // A missing scene surfaces as AppFormatException from the store;
    // report it the same way as any other failure.
    return {
      'ok': false,
      'error': e is FormatException ? e.message : '图形不存在或更新失败，未修改图形。',
    };
  }
}

/// Reads one visual scene from a `get_visual` tool call.
///
/// Read-only: no `aiToolOperations` row, no revision bump, no store
/// writes at all. Without `revision` returns the current scene; with one
/// returns that revision's snapshot. Returns `{'ok': bool, ...}` and never
/// throws (except cancellation).
Future<Map<String, dynamic>> executeGetVisualTool(
  VisualStore store,
  ToolCall call, {
  required String sessionId,
  required String runId,
  required CancelToken cancel,
}) async {
  try {
    cancel.checkCancelled();
    if (call.arguments.length > 64000) {
      throw const AppFormatException(
        AppErrorCode.errorToolCallDataIsTooLong,
        '图形数据过长。',
      );
    }
    final args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
    for (final key in args.keys) {
      if (!{'visual_id', 'revision'}.contains(key)) {
        throw AppFormatException(
          AppErrorCode.errorUnknownParameter,
          '未知参数：$key。',
          [key],
        );
      }
    }
    final visualId = args['visual_id'];
    if (visualId == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        '缺少参数：visual_id。',
        ['visual_id'],
      );
    }
    if (visualId is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        '参数 visual_id 必须是文本。',
        ['visual_id'],
      );
    }
    final revisionArg = args['revision'];
    int? revision;
    if (revisionArg != null) {
      if (revisionArg is! int) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          '参数 revision 必须是整数。',
          ['revision'],
        );
      }
      revision = revisionArg;
      if (revision < 1) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          '参数 revision 必须大于等于 1。',
          ['revision'],
        );
      }
    }
    final row = await store.get(visualId);
    if (row == null) {
      return {'ok': false, 'error': '图形不存在。'};
    }
    final sceneJson = revision == null
        ? row.sceneJson
        : await store.getRevisionSceneJson(visualId, revision);
    if (sceneJson == null) {
      return {'ok': false, 'error': '该版本不存在。'};
    }
    return <String, dynamic>{
      'ok': true,
      'visual_id': visualId,
      'revision': revision ?? row.revision,
      'scene': jsonDecode(sceneJson),
      'verification_status': row.verificationStatus,
      'title': row.title,
    };
  } on DioException {
    rethrow;
  } catch (e) {
    return {
      'ok': false,
      'error': e is FormatException ? e.message : '图形不存在或读取失败。',
    };
  }
}

Future<Map<String, dynamic>> executeVisualTool(
  VisualStore store,
  ToolCall call, {
  required String sessionId,
  required String runId,
  required CancelToken cancel,
}) async {
  try {
    cancel.checkCancelled();
    if (call.arguments.length > 64000) {
      throw const AppFormatException(
        AppErrorCode.errorToolCallDataIsTooLong,
        '图形数据过长。',
      );
    }
    final args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
    for (final key in args.keys) {
      if (!{'scene', 'title', 'alt'}.contains(key)) {
        throw AppFormatException(
          AppErrorCode.errorUnknownParameter,
          '未知参数：$key。',
          [key],
        );
      }
    }
    final sceneArg = args['scene'];
    if (sceneArg == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        '缺少参数：scene。',
        ['scene'],
      );
    }
    if (sceneArg is! Map) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '参数 scene 必须是对象。',
        ['scene'],
      );
    }
    final title = args['title'];
    if (title != null && title is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        '参数 title 必须是文本。',
        ['title'],
      );
    }
    final alt = args['alt'];
    if (alt != null && alt is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        '参数 alt 必须是文本。',
        ['alt'],
      );
    }
    // Tool-level title/alt fill gaps in the scene itself; the scene's own
    // values win when both are present.
    final merged = Map<String, dynamic>.of(sceneArg.cast<String, dynamic>());
    if (title is String && title.trim().isNotEmpty && merged['title'] == null) {
      merged['title'] = title;
    }
    if (alt is String && alt.trim().isNotEmpty) {
      final meta =
          (merged['meta'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      meta.putIfAbsent('alt', () => alt);
      merged['meta'] = meta;
    }
    final validation = validateVisualScene(merged);
    if (!validation.ok) {
      return {'ok': false, 'error': validation.errors.first.message};
    }
    final scene = VisualScene.fromJson(merged);
    final computed = computeDerivedValues(scene);
    final encoded = canonicalJson(args);
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
      // Same call replayed: return the cached result like quiz_tool does
      // instead of creating the scene a second time.
      if (old != null && old.status == 'succeeded' && old.result != null) {
        return (jsonDecode(old.result!) as Map).cast<String, dynamic>();
      }
      final id = await store.create(
        sceneJson: jsonEncode(scene.toJson()),
        messageId: runId,
        // The merged scene is the source of truth: a tool-level title
        // only filled the gap when the scene had none.
        title: scene.title,
        source: 'ai',
        verification: validation.verificationStatus,
      );
      cancel.checkCancelled();
      await store.db
          .into(store.db.aiToolOperations)
          .insertOnConflictUpdate(
            AiToolOperationsCompanion.insert(
              id: '$runId:${call.id}',
              runId: runId,
              sessionId: sessionId,
              name: 'create_visual',
              arguments: encoded,
              status: 'succeeded',
              result: Value(
                jsonEncode({
                  'ok': true,
                  'visual_id': id,
                  'verification': validation.verificationStatus,
                }),
              ),
              createdAt: DateTime.now(),
            ),
          );
      return <String, dynamic>{
        'ok': true,
        'visual_id': id,
        'verification': validation.verificationStatus,
        'computed': computed,
        'note': '图形已在应用内显示；不要在正文中复述图形的完整数据。',
      };
    });
    return result;
  } on DioException {
    rethrow;
  } catch (e) {
    return {
      'ok': false,
      'error': e is FormatException ? e.message : '图形数据无效或保存失败，未创建图形。',
    };
  }
}
