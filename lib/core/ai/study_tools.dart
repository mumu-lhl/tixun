import "package:tixun/core/l10n/app_error.dart";

import "dart:convert";

import "package:dio/dio.dart";
import "package:drift/drift.dart";

import "../../features/library/study_store.dart";
import "../../features/library/subject_scope.dart";
import "../../features/review/review_store.dart";
import "../../features/progress/learning_progress.dart";
import "../database/database.dart";
import "ai_types.dart";
export "ai_types.dart" show ToolCall;

part "study_tool_invocation.dart";

const _string = {"type": "string"};

enum StudyToolCategory { knowledge, mistakes, modules, progress, review }

const allStudyToolCategories = {...StudyToolCategory.values};
String studyToolCategoriesKey(String sessionId) => "study_tools:$sessionId";

Set<StudyToolCategory> readStudyToolCategories(String? value) => value == null
    ? allStudyToolCategories
    : StudyToolCategory.values
          .where((category) => value.split(",").contains(category.name))
          .toSet();

bool allowsStudyTool(
  String name,
  Set<StudyToolCategory> categories, {
  String? kind,
}) {
  final knowledge = categories.contains(StudyToolCategory.knowledge);
  final mistakes = categories.contains(StudyToolCategory.mistakes);
  return switch (name) {
    "search_knowledge" ||
    "get_knowledge" ||
    "create_knowledge" ||
    "update_knowledge" ||
    "delete_knowledge" => knowledge,
    "search_mistakes" ||
    "get_mistake" ||
    "create_mistake" ||
    "update_mistake" ||
    "delete_mistake" => mistakes,
    "link_mistake_to_knowledge" => knowledge && mistakes,
    "list_subject_modules" ||
    "create_subject_module" => categories.contains(StudyToolCategory.modules),
    "link_study_module" =>
      categories.contains(StudyToolCategory.modules) &&
          (kind == null
              ? knowledge || mistakes
              : kind == "knowledge"
              ? knowledge
              : kind == "mistake" && mistakes),
    "get_learning_progress" => categories.contains(StudyToolCategory.progress),
    "schedule_review" => categories.contains(StudyToolCategory.review),
    _ => false,
  };
}

List<AiTool> studyToolsFor(Set<StudyToolCategory> categories) => [
  for (final tool in studyToolSchemas)
    if (allowsStudyTool(tool.name, categories))
      if (tool.name == "link_study_module")
        AiTool(
          name: tool.name,
          description: tool.description,
          parameters: {
            ...tool.parameters,
            "properties": {
              ...tool.parameters["properties"] as Map<String, dynamic>,
              "kind": {
                "type": "string",
                "enum": [
                  if (categories.contains(StudyToolCategory.knowledge))
                    "knowledge",
                  if (categories.contains(StudyToolCategory.mistakes))
                    "mistake",
                ],
              },
            },
          },
        )
      else
        tool,
];
const _integer = {"type": "integer", "minimum": 1};
const _tags = {"type": "array", "items": _string, "maxItems": 20};
const _knowledgeFields = {
  "title": _string,
  "content": _string,
  "subject": _string,
  "kind": {"type": "string", "enum": knowledgeKinds},
  "chapter": _string,
  "tags": _tags,
};
const _imageIndicesField = {
  "image_indices": {
    "type": "array",
    "items": {"type": "integer", "minimum": 0, "maximum": 3},
    "maxItems": 4,
  },
};
const _mistakeFields = {
  "title": _string,
  "question": _string,
  "subject": _string,
  "chapter": _string,
  "correct_answer": _string,
  "ai_analysis": _string,
  "suggested_reason": _string,
  "tags": _tags,
};
AiTool _schema(
  String name,
  String description,
  Map<String, dynamic> fields,
  List<String> required,
) => AiTool(
  name: name,
  description: description,
  parameters: {
    "type": "object",
    "properties": fields,
    "required": required,
    "additionalProperties": false,
  },
);

final studyToolSchemas = [
  _schema(
    "list_subject_modules",
    "只查询当前学习科目的模块目录；可用 query 查找名称，其他科目由应用拦截。",
    {"subject": _string, "query": _string},
    ["subject"],
  ),
  _schema(
    "create_subject_module",
    "仅在当前学习科目创建模块；需用户确认。parent_id 表示同科目的一级模块，最多两级。",
    {"subject": _string, "name": _string, "parent_id": _string},
    ["subject", "name"],
  ),
  _schema(
    "link_study_module",
    "仅关联当前学习科目的知识/错题与模块；跨科目操作会被应用拦截，并需用户确认。",
    {
      "id": _string,
      "kind": {
        "type": "string",
        "enum": ["knowledge", "mistake"],
      },
      "module_id": _string,
    },
    ["id", "kind", "module_id"],
  ),
  _schema("search_knowledge", "只搜索当前学习科目的本地知识，返回最多5条摘要；科目由应用强制限定。", {
    "query": _string,
    "subject": _string,
    "module_id": _string,
  }, []),
  _schema(
    "get_knowledge",
    "仅读取当前学习科目的知识和版本号；跨科目 ID 会被应用拦截。正文最多12000字符。",
    {"id": _string},
    ["id"],
  ),
  _schema(
    "create_knowledge",
    "提出新增当前学习科目知识的建议；科目由应用强制限定，必须由用户确认后保存。",
    _knowledgeFields,
    ["title", "content", "subject"],
  ),
  _schema(
    "update_knowledge",
    "仅修改当前学习科目的知识；必须提供读取时的版本号并由用户确认，不能改到其他科目。",
    {"id": _string, "expected_revision": _integer, ..._knowledgeFields},
    ["id", "expected_revision"],
  ),
  _schema(
    "delete_knowledge",
    "仅将当前学习科目的知识移入回收区；可恢复，必须经用户确认。",
    {"id": _string, "expected_revision": _integer},
    ["id", "expected_revision"],
  ),
  _schema("search_mistakes", "只搜索当前学习科目的错题，返回最多5条摘要；科目由应用强制限定。", {
    "query": _string,
    "subject": _string,
    "module_id": _string,
  }, []),
  _schema(
    "get_mistake",
    "仅读取当前学习科目的错题、AI解析、版本及用户明确记录的思路。",
    {"id": _string},
    ["id"],
  ),
  _schema(
    "create_mistake",
    "只提出当前学习科目的错题保存建议；未知原题和答案不要编造。错误原因仅建议，等待用户确认。题目依赖本次请求的图片时，用 image_indices 明确引用图片序号（从 0 开始，最多 4 张，仅前 4 张图片可用）；不填写时错题不附加图片。",
    {..._mistakeFields, ..._imageIndicesField},
    ["title", "subject"],
  ),
  _schema(
    "update_mistake",
    "仅修改当前学习科目的错题；不能修改原答案、用户分析或已确认的错误原因，须确认。",
    {"id": _string, "expected_revision": _integer, ..._mistakeFields},
    ["id", "expected_revision"],
  ),
  _schema(
    "delete_mistake",
    "仅将当前学习科目的错题移入回收区；可恢复，必须经用户确认。",
    {"id": _string, "expected_revision": _integer},
    ["id", "expected_revision"],
  ),
  _schema(
    "link_mistake_to_knowledge",
    "仅关联当前学习科目的知识与错题；跨科目关联会被应用拦截，需用户确认。",
    {"knowledge_id": _string, "mistake_id": _string},
    ["knowledge_id", "mistake_id"],
  ),
  _schema(
    "get_learning_progress",
    "读取当前学习科目的资料、训练与知识点检测证据；样本不足不能给出掌握分数。",
    {},
    [],
  ),
  _schema(
    "schedule_review",
    "仅将当前学习科目的练习加入复习。需用户确认；日期由确定性调度代码管理。",
    {"question_id": _string},
    ["question_id"],
  ),
];
const _readTools = {
  "list_subject_modules",
  "search_knowledge",
  "get_knowledge",
  "search_mistakes",
  "get_mistake",
  "get_learning_progress",
};

/// Writes are the study tools with a side effect; reads never change data.
/// LearningRun uses this to decide whether an empty final text still means
/// the round succeeded.
bool isWriteStudyTool(String name) => !_readTools.contains(name);

String canonicalJson(Object? value) {
  Object? sort(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: sort(v[k])};
    }
    if (v is List) return v.map(sort).toList();
    return v;
  }

  return jsonEncode(sort(value));
}

typedef ConfirmStudyTool = Future<bool> Function(
  String name,
  Map<String, dynamic> arguments,
);

class StudyToolRunner {
  StudyToolRunner(
    this.store, {
    required this.sessionId,
    required this.runId,
    required this.authorized,
    this.categories = allStudyToolCategories,
    this.confirm,
    this.reviews,
    this.sourceImages = const [],
    this.sourceSessionId,
    this.subjectScope,
  });
  final StudyStore store;
  final ReviewStore? reviews;
  final String sessionId, runId;
  final String? sourceSessionId;
  final String? subjectScope;

  /// Only set by the explicit app UI. Model/user text never sets this capability.
  final bool authorized;
  final Set<StudyToolCategory> categories;
  final ConfirmStudyTool? confirm;
  final List<Attachment> sourceImages;
  AppDatabase get db => store.db;
  Future<Map<String, dynamic>> execute(
    ToolCall call,
    CancelToken cancel,
  ) async {
    if (!authorized) return {"ok": false, "error": "此会话未获本地资料工具权限。"};
    cancel.checkCancelled();
    Map<String, dynamic> args;
    try {
      if (call.arguments.length > 64000) {
        throw const AppFormatException(
          AppErrorCode.errorTheArgumentIsTooLong,
          "参数过长。",
        );
      }
      args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
      if (!allowsStudyTool(
        call.name,
        categories,
        kind: args["kind"] as String?,
      )) {
        return {"ok": false, "error": "此类资料工具未在本会话中启用。"};
      }
      final schema = studyToolSchemas
          .where((t) => t.name == call.name)
          .firstOrNull;
      if (schema == null) {
        throw const AppFormatException(AppErrorCode.errorUnknownTool, "未知工具。");
      }
      final p = schema.parameters;
      for (final key in args.keys) {
        if (!(p["properties"] as Map).containsKey(key)) {
          throw AppFormatException(
            AppErrorCode.errorUnknownParameter,
            "未知参数：$key",
            [key],
          );
        }
      }
      for (final key in p["required"] as List) {
        if (!args.containsKey(key)) {
          throw AppFormatException(
            AppErrorCode.errorMissingParameter,
            "缺少参数：$key",
            [key],
          );
        }
      }
      for (final entry in args.entries) {
        final prop = p["properties"][entry.key] as Map;
        final type = prop["type"];
        final v = entry.value;
        if (type == "string" && v is! String) {
          throw AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "参数 ${entry.key} 类型无效。",
            [entry.key],
          );
        }
        if (type == "integer" && (v is! int || v < 1)) {
          throw AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "参数 ${entry.key} 类型无效。",
            [entry.key],
          );
        }
        if (type == "array") {
          if (v is! List) {
            throw AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "参数 ${entry.key} 类型无效。",
              [entry.key],
            );
          }
          // Integer arrays (image_indices) validate elements as ints;
          // every other array parameter is a list of strings.
          final itemType = (prop["items"] as Map?)?["type"];
          if (itemType == "integer") {
            if (v.any((e) => e is! int)) {
              throw AppFormatException(
                AppErrorCode.errorInvalidParameterType,
                "参数 ${entry.key} 类型无效。",
                [entry.key],
              );
            }
          } else if (v.any((e) => e is! String)) {
            throw AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "参数 ${entry.key} 类型无效。",
              [entry.key],
            );
          }
        }
      }
      // Validate sizes before approval, including fields ignored by any individual tool.
      for (final e in args.entries) {
        if (e.value is String) {
          store.checked(
            e.value,
            e.key,
            e.key == "content" ||
                    e.key == "question" ||
                    e.key == "ai_analysis" ||
                    e.key == "correct_answer"
                ? 60000
                : 500,
          );
        }
      }
      if (args["tags"] != null) {
        store.cleanTags((args["tags"] as List).cast<String>());
      }
      await _validateSubjectScope(call.name, args);
    } catch (e) {
      // Keep the specific reason (e.g. which parameter is missing) so the
      // model can fix the call instead of repeating the same bad call.
      return {
        "ok": false,
        "error": e is FormatException ? e.message : "工具名称或参数无效，请检查字段、类型和长度。",
      };
    }
    final encoded = canonicalJson(args);
    final existing = await (db.select(
      db.aiToolOperations,
    )..where((t) => t.id.equals("$runId:${call.id}"))).getSingleOrNull();
    if (existing != null) {
      if (existing.name != call.name || existing.arguments != encoded) {
        return {"ok": false, "error": "工具调用 ID 已用于其他参数。"};
      }
      return existing.result == null
          ? {"ok": false, "error": "此操作已在处理中或被中断，请发起新的请求。"}
          : (jsonDecode(existing.result!) as Map).cast<String, dynamic>();
    }
    if (!_readTools.contains(call.name)) {
      final duplicate =
          await (db.select(db.aiToolOperations)..where(
                (t) =>
                    t.runId.equals(runId) &
                    t.name.equals(call.name) &
                    t.arguments.equals(encoded) &
                    t.status.isIn([
                      "pending",
                      "running",
                      "succeeded",
                      "rejected",
                    ]),
              ))
              .getSingleOrNull();
      if (duplicate != null) {
        return duplicate.result == null
            ? {"ok": false, "error": "相同操作正在等待确认或执行，已阻止重复调用。"}
            : (jsonDecode(duplicate.result!) as Map).cast<String, dynamic>();
      }
    }
    final operationId = "$runId:${call.id}";
    try {
      await db
          .into(db.aiToolOperations)
          .insert(
            AiToolOperationsCompanion.insert(
              id: operationId,
              runId: runId,
              sessionId: sessionId,
              name: call.name,
              arguments: encoded,
              status: "pending",
              createdAt: DateTime.now(),
            ),
          );
    } catch (_) {
      return {"ok": false, "error": "无法登记操作，或检测到重复请求；未执行修改。"};
    }

    try {
      if (!_readTools.contains(call.name)) {
        final approved = confirm != null && await confirm!(call.name, args);
        cancel.checkCancelled();
        if (!approved) {
          final result = {"ok": false, "error": "用户未确认，未修改任何资料。"};
          await _result(operationId, "rejected", result);
          return result;
        }
      }
      cancel.checkCancelled();
      final result = await db.transaction(() async {
        final value = await _invoke(call.name, args);
        if (sourceSessionId != null &&
            value["id"] is String &&
            [
              "create_knowledge",
              "update_knowledge",
              "create_mistake",
            ].contains(call.name)) {
          final source = await (db.select(
            db.chatSessions,
          )..where((t) => t.id.equals(sourceSessionId!))).getSingleOrNull();
          if (source != null && !source.deleted) {
            await store.linkChat(
              sourceSessionId!,
              knowledgeId: call.name == "create_mistake"
                  ? null
                  : value["id"] as String,
              mistakeId: call.name == "create_mistake"
                  ? value["id"] as String
                  : null,
            );
          }
        }
        cancel.checkCancelled();
        final result = {"ok": true, ...value};
        await _result(operationId, "succeeded", result);
        return result;
      });
      store.changed();
      return result;
    } on DioException {
      await _result(operationId, "cancelled", {
        "ok": false,
        "error": "已取消，未完成的修改已回滚。",
      });
      rethrow;
    } catch (e) {
      final result = {
        "ok": false,
        "error": e is FormatException ? e.message : "操作未完成，数据库修改已回滚。",
      };
      await _result(operationId, "failed", result);
      return result;
    }
  }

  Future<void> _result(
    String id,
    String status,
    Map<String, dynamic> result,
  ) async {
    await (db.update(db.aiToolOperations)..where((t) => t.id.equals(id))).write(
      AiToolOperationsCompanion(
        status: Value(status),
        result: Value(jsonEncode(result)),
      ),
    );
  }
}
