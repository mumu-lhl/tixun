import "dart:convert";

import "package:dio/dio.dart";
import "package:drift/drift.dart";

import "../../core/l10n/app_error.dart";
import "../../core/visual/math/sampling.dart";
import "../../core/visual/model/visual_scene.dart";
import "../../core/visual/validation/visual_quality.dart";
import "../../core/visual/validation/visual_validator.dart";
import "../../features/visual/visual_store.dart";
import "../database/database.dart";
import "ai_types.dart";
import "study_tools.dart";
import "visual_schema.dart";

part "visual_tool_update.dart";

final visualToolSchema = AiTool(
  name: "create_visual",
  description: "仅当用户要求画图、画函数图像或可视化，或图形能清楚帮助理解时创建一幅教学图形；一次调用只生成一个图形。场景必须符合 Visual DSL v1（v 为 1，元素、表达式与资源上限以内）。kind 可选 plot2d/geometry/physics/vector/chart/circuit/chemistry/geography：电路图用 kind circuit 与 circuit 图元（battery/resistor/switch/wire/meter）；化学与地理用 kind chemistry/geography，以通用图元组合表达。考试模式下提交前不得通过图形透露答案；本工具不在考试模式提供。",
  parameters: {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "scene": visualSceneSchema,
      "title": {"type": "string", "maxLength": 100},
      "alt": {"type": "string", "maxLength": 500},
    },
    "required": ["scene"],
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

final getVisualToolSchema = AiTool(
  name: "get_visual",
  description: "读取一个已创建图形的场景 JSON，用于在修改前确认当前内容或指定版本的内容；只读，不产生新版本，不写入任何记录。",
  parameters: {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "visual_id": {"type": "string", "description": "要读取的图形 id。"},
      "revision": {
        "type": "integer",
        "minimum": 1,
        "description": "版本号；不传则读当前版本。",
      },
    },
    "required": ["visual_id"],
  },
);

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
    if (utf8.encode(call.arguments).length > 65536) {
      throw const AppFormatException(
        AppErrorCode.errorToolCallDataIsTooLong,
        "图形数据过长。",
      );
    }
    final args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
    for (final key in args.keys) {
      if (!{"visual_id", "revision"}.contains(key)) {
        throw AppFormatException(
          AppErrorCode.errorUnknownParameter,
          "未知参数：$key。",
          [key],
        );
      }
    }
    final visualId = args["visual_id"];
    if (visualId == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        "缺少参数：visual_id。",
        ["visual_id"],
      );
    }
    if (visualId is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        "参数 visual_id 必须是文本。",
        ["visual_id"],
      );
    }
    final revisionArg = args["revision"];
    int? revision;
    if (revisionArg != null) {
      if (revisionArg is! int) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          "参数 revision 必须是整数。",
          ["revision"],
        );
      }
      revision = revisionArg;
      if (revision < 1) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          "参数 revision 必须大于等于 1。",
          ["revision"],
        );
      }
    }
    final row = await store.get(visualId);
    if (row == null) {
      throw const AppFormatException(
        AppErrorCode.errorVisualSceneDoesNotExist,
        "图形不存在。",
      );
    }
    final sceneJson = revision == null
        ? row.sceneJson
        : await store.getRevisionSceneJson(visualId, revision);
    if (sceneJson == null) {
      throw const AppFormatException(
        AppErrorCode.errorVisualSceneRevisionDoesNotExist,
        "图形修订不存在。",
      );
    }
    // A snapshot carries its own title and verification: the row holds
    // the CURRENT title/status, which a later edit may have changed.
    final decoded = (jsonDecode(sceneJson) as Map).cast<String, dynamic>();
    final title = revision == null
        ? row.title
        : (decoded["title"] is String && (decoded["title"] as String).isNotEmpty
              ? decoded["title"] as String
              : row.title);
    final verificationStatus = revision == null
        ? row.verificationStatus
        : validateVisualScene(decoded).verificationStatus;
    return <String, dynamic>{
      "ok": true,
      "visual_id": visualId,
      "revision": revision ?? row.revision,
      "scene": decoded,
      "verification_status": verificationStatus,
      "title": title,
    };
  } on DioException {
    rethrow;
  } catch (e) {
    return {
      "ok": false,
      "error": e is FormatException ? e.message : "图形不存在或读取失败。",
    };
  }
}

/// Told to the model with a fresh figure so it does not repeat the
/// figure's full data in prose. Shared by the live and cached create
/// results so a replay answers identically.
const _visualCreatedNote =
    "图形已保存；可在说明或知识正文的对应位置独立插入 ![图注](visual:返回的visual_id)，不要复述完整场景数据。";

Future<Map<String, dynamic>> executeVisualTool(
  VisualStore store,
  ToolCall call, {
  required String sessionId,
  required String runId,
  required CancelToken cancel,
}) async {
  try {
    cancel.checkCancelled();
    if (utf8.encode(call.arguments).length > 65536) {
      throw const AppFormatException(
        AppErrorCode.errorToolCallDataIsTooLong,
        "图形数据过长。",
      );
    }
    final args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
    for (final key in args.keys) {
      if (!{"scene", "title", "alt"}.contains(key)) {
        throw AppFormatException(
          AppErrorCode.errorUnknownParameter,
          "未知参数：$key。",
          [key],
        );
      }
    }
    final sceneArg = args["scene"];
    if (sceneArg == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        "缺少参数：scene。",
        ["scene"],
      );
    }
    if (sceneArg is! Map) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "参数 scene 必须是对象。",
        ["scene"],
      );
    }
    final title = args["title"];
    if (title != null && title is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        "参数 title 必须是文本。",
        ["title"],
      );
    }
    final alt = args["alt"];
    if (alt != null && alt is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        "参数 alt 必须是文本。",
        ["alt"],
      );
    }
    // Tool-level title/alt fill gaps in the scene itself; the scene's own
    // values win when both are present.
    final merged = Map<String, dynamic>.of(sceneArg.cast<String, dynamic>());
    if (title is String && title.trim().isNotEmpty && merged["title"] == null) {
      merged["title"] = title;
    }
    if (alt is String && alt.trim().isNotEmpty) {
      final meta =
          (merged["meta"] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      meta.putIfAbsent("alt", () => alt);
      merged["meta"] = meta;
    }
    final validation = validateVisualScene(merged);
    if (!validation.ok) {
      return {"ok": false, "error": validation.errors.first.message};
    }
    final scene = VisualScene.fromJson(merged);
    final computed = computeDerivedValues(scene);
    final qualityIssues = _qualityIssuesJson(scene);
    final encoded = canonicalJson(args);
    final result = await store.db.transaction(() async {
      cancel.checkCancelled();
      final old = await (store.db.select(
        store.db.aiToolOperations,
      )..where((t) => t.id.equals("$runId:${call.id}"))).getSingleOrNull();
      if (old != null && (old.arguments != encoded || old.name != call.name)) {
        throw const AppFormatException(
          AppErrorCode.errorThisToolCallIDHasAlready,
          "工具调用 ID 已被其他参数使用。",
        );
      }
      // Same call replayed: return the cached result like quiz_tool does
      // instead of creating the scene a second time.
      if (old != null && old.status == "succeeded" && old.result != null) {
        return (jsonDecode(old.result!) as Map).cast<String, dynamic>();
      }
      final id = await store.create(
        sceneJson: jsonEncode(scene.toJson()),
        messageId: runId,
        // The merged scene is the source of truth: a tool-level title
        // only filled the gap when the scene had none.
        title: scene.title,
        source: "ai",
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
      // studyChatLinks has a surrogate key, so the same owner can appear
      // twice for one session; linkToStudy also guards, but skip the
      // repeat call here.
      final seenOwners = <(String?, String?)>{};
      for (final link in studyLinks) {
        if ((link.knowledgeId == null) == (link.mistakeId == null)) continue;
        if (!seenOwners.add((link.knowledgeId, link.mistakeId))) continue;
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
              id: "$runId:${call.id}",
              runId: runId,
              sessionId: sessionId,
              name: "create_visual",
              arguments: encoded,
              status: "succeeded",
              result: Value(
                jsonEncode({
                  "ok": true,
                  "visual_id": id,
                  "verification": validation.verificationStatus,
                  "computed": computed,
                  "quality_issues": ?qualityIssues,
                  "note": _visualCreatedNote,
                }),
              ),
              createdAt: DateTime.now(),
            ),
          );
      return <String, dynamic>{
        "ok": true,
        "visual_id": id,
        "verification": validation.verificationStatus,
        "computed": computed,
        "quality_issues": ?qualityIssues,
        "note": _visualCreatedNote,
      };
    });
    return result;
  } on DioException {
    rethrow;
  } catch (e) {
    return {
      "ok": false,
      "error": e is FormatException ? e.message : "图形数据无效或保存失败，未创建图形。",
    };
  }
}
