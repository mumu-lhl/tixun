import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../core/l10n/app_error.dart';
import '../../core/visual/math/sampling.dart';
import '../../core/visual/model/visual_scene.dart';
import '../../core/visual/validation/visual_quality.dart';
import '../../core/visual/validation/visual_validator.dart';
import '../../features/visual/visual_store.dart';
import '../database/database.dart';
import 'ai_types.dart';
import 'study_tools.dart';

final visualToolSchema = AiTool(
  name: 'create_visual',
  description: '仅当用户要求画图、画函数图像或可视化，或图形能清楚帮助理解时创建一幅教学图形；一次调用只生成一个图形。场景必须符合 Visual DSL v1（v 为 1，元素、表达式与资源上限以内）。kind 可选 plot2d/geometry/physics/vector/chart/circuit/chemistry/geography：电路图用 kind circuit 与 circuit 图元（battery/resistor/switch/wire/meter）；化学与地理用 kind chemistry/geography，以通用图元组合表达。考试模式下提交前不得通过图形透露答案；本工具不在考试模式提供。',
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
  description: '仅当用户要求修改已有的图形时更新该图形的场景；一次调用只更新一个图形。scene 与 ops 二选一：scene 是完整的 Visual DSL v1 JSON（整体替换）；ops 是按图元 id 的补丁列表，适合小幅修改（换一个点的位置、加一条辅助线、改标题），不用重发整个场景。ops 元素：{"op":"replace_element","id":"...","element":{...}} 替换指定 id 的图元；{"op":"add_element","element":{...}} 追加一个新图元（id 不可重复）；{"op":"remove_element","id":"..."} 删除指定 id 的图元；{"op":"set_title","title":"..."} 改标题。考试模式下提交前不得通过图形透露答案；本工具不在考试模式提供。',
  parameters: {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'visual_id': {'type': 'string', 'description': '要更新的图形 id。'},
      'scene': {
        'type': 'object',
        'description': 'Visual DSL v1 场景 JSON（完整场景，与 ops 二选一）。',
      },
      'ops': {
        'type': 'array',
        'description': '按图元 id 的补丁操作列表（与 scene 二选一）。',
        'items': {
          'type': 'object',
          'properties': {
            'op': {'type': 'string'},
            'id': {'type': 'string'},
            'element': {'type': 'object'},
            'title': {'type': 'string'},
          },
        },
      },
      'title': {'type': 'string', 'maxLength': 100},
    },
    'required': ['visual_id'],
  },
);

/// Quality issues as a JSON list, or null when the scene is clean.
/// Attached to create/update results so the model can fix the figure
/// in the next round instead of shipping a silently bad one.
List<Map<String, dynamic>>? _qualityIssuesJson(VisualScene scene) {
  final issues = checkVisualQuality(scene);
  if (issues.isEmpty) return null;
  return [for (final issue in issues) issue.toJson()];
}

/// Applies patch [ops] to a decoded scene JSON, returning a new map.
///
/// Pure JSON surgery — the caller still runs the full scene validation
/// afterwards, so a patch that leaves the scene invalid is rejected
/// without creating a revision. Throws [AppFormatException] on a
/// malformed op (unknown op, missing id, id mismatch, duplicate add,
/// or a replace/remove of an unknown id).
Map<String, dynamic> applyVisualPatchOps(
  Map<String, dynamic> sceneJson,
  List<dynamic> ops,
) {
  Never bad(String message, [String? param]) => throw AppFormatException(
    AppErrorCode.errorInvalidParameterType,
    message,
    param == null ? const <String>[] : <String>[param],
  );
  final patched = (jsonDecode(jsonEncode(sceneJson)) as Map)
      .cast<String, dynamic>();
  var elements = patched['elements'];
  List<dynamic> elementList() {
    if (elements == null) {
      elements = <dynamic>[];
      patched['elements'] = elements;
    }
    if (elements is! List) bad('场景的 elements 必须是列表。', 'elements');
    return elements as List<dynamic>;
  }

  /// Finds the path of the element with [id], recursing into `group`
  /// children; null when absent. The path is a chain of indexes: the
  /// first is the top-level index, the rest descend into nested groups.
  /// Element ids are globally unique (the validator enforces it), so
  /// the first match is the only match.
  List<int>? findPath(List<dynamic> elements, String id) {
    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      if (element is! Map) continue;
      if (element['id'] == id) return [i];
      if (element['type'] == 'group') {
        final children = element['children'];
        if (children is List) {
          final child = findPath(children, id);
          if (child != null) return [i, ...child];
        }
      }
    }
    return null;
  }

  /// The list that holds the element at [path]: the top-level list for
  /// a top-level element, the enclosing group's `children` otherwise.
  List<dynamic> listAt(List<dynamic> elements, List<int> path) {
    var list = elements;
    for (final index in path.sublist(0, path.length - 1)) {
      list = (list[index] as Map)['children'] as List<dynamic>;
    }
    return list;
  }

  String requireId(Map<String, dynamic> op, String field) {
    final id = op[field];
    if (id == null || id is! String || id.isEmpty) {
      bad('补丁操作缺少有效的 $field。', field);
    }
    return id;
  }

  Map<String, dynamic> requireElement(Map<String, dynamic> op) {
    final element = op['element'];
    if (element == null || element is! Map) {
      bad('补丁操作缺少有效的 element。', 'element');
    }
    return element.cast<String, dynamic>();
  }

  for (final rawOp in ops) {
    if (rawOp is! Map) bad('补丁操作必须是对象。', 'ops');
    final op = rawOp.cast<String, dynamic>();
    final name = op['op'];
    if (name is! String) bad('补丁操作缺少有效的 op。', 'op');
    switch (name) {
      case 'replace_element':
        final id = requireId(op, 'id');
        final element = requireElement(op);
        if (element['id'] != id) {
          bad('替换的图元 id 与操作 id 不一致：$id。', 'id');
        }
        final path = findPath(elementList(), id);
        if (path == null) bad('找不到要替换的图元：$id。', 'id');
        listAt(elementList(), path)[path.last] = element;
      case 'add_element':
        final element = requireElement(op);
        final id = requireId(element, 'id');
        if (findPath(elementList(), id) != null) {
          bad('图元 id 已存在：$id。', 'id');
        }
        elementList().add(element);
      case 'remove_element':
        final id = requireId(op, 'id');
        final path = findPath(elementList(), id);
        if (path == null) bad('找不到要删除的图元：$id。', 'id');
        listAt(elementList(), path).removeAt(path.last);
      case 'set_title':
        final title = op['title'];
        if (title == null || title is! String) {
          bad('set_title 缺少有效的 title。', 'title');
        }
        if (title.isEmpty) {
          patched.remove('title');
        } else {
          patched['title'] = title;
        }
      default:
        bad('未知的图形补丁操作：$name。', 'op');
    }
  }
  return patched;
}

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
      if (!{'visual_id', 'scene', 'ops', 'title'}.contains(key)) {
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
    final opsArg = args['ops'];
    if (sceneArg != null && opsArg != null) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '参数 scene 与 ops 只能二选一。',
        ['scene'],
      );
    }
    if (sceneArg == null && opsArg == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        '缺少参数：scene 或 ops。',
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
    // The new scene JSON, from a full replacement or from patch ops
    // applied to the stored scene. Either way the same validation and
    // revise path below runs, so a bad patch creates no revision.
    final Map<String, dynamic> merged;
    if (sceneArg != null) {
      if (sceneArg is! Map) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          '参数 scene 必须是对象。',
          ['scene'],
        );
      }
      merged = Map<String, dynamic>.of(sceneArg.cast<String, dynamic>());
    } else {
      if (opsArg is! List || opsArg.isEmpty) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          '参数 ops 必须是非空列表。',
          ['ops'],
        );
      }
      final stored = await store.get(visualId);
      if (stored == null) {
        throw const AppFormatException(
          AppErrorCode.errorVisualSceneDoesNotExist,
          '图形不存在。',
        );
      }
      final current = (jsonDecode(stored.sceneJson) as Map)
          .cast<String, dynamic>();
      merged = applyVisualPatchOps(current, opsArg);
    }
    // Same merge rule as create: a tool-level title fills the gap when
    // the scene itself has none; the scene's own title wins.
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
    final qualityIssues = _qualityIssuesJson(scene);
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
                  'quality_issues': ?qualityIssues,
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
        'quality_issues': ?qualityIssues,
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
    final qualityIssues = _qualityIssuesJson(scene);
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
      // A visual created in a study-linked session belongs to those
      // study items too: the StudyVisuals section shows it under the
      // matching source group. Mirrors the quiz tool's knowledge links.
      final studyLinks =
          await (store.db.select(store.db.studyChatLinks)
                ..where((l) => l.sessionId.equals(sessionId))
                ..limit(5))
              .get();
      for (final link in studyLinks) {
        if ((link.knowledgeId == null) == (link.mistakeId == null)) continue;
        await store.linkToStudy(
          id,
          knowledgeId: link.knowledgeId,
          mistakeId: link.mistakeId,
        );
      }
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
                  'quality_issues': ?qualityIssues,
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
        'quality_issues': ?qualityIssues,
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
