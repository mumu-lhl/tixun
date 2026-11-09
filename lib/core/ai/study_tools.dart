import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../features/library/study_store.dart';
import '../../features/review/review_store.dart';
import '../../features/progress/learning_progress.dart';
import '../database/database.dart';
import 'ai_types.dart';
export 'ai_types.dart' show ToolCall;

const _string = {'type': 'string'};
const _integer = {'type': 'integer', 'minimum': 1};
const _tags = {'type': 'array', 'items': _string, 'maxItems': 20};
const _knowledgeFields = {
  'title': _string,
  'content': _string,
  'subject': _string,
  'kind': {'type': 'string', 'enum': knowledgeKinds},
  'chapter': _string,
  'tags': _tags,
};
const _imageIndicesField = {
  'image_indices': {
    'type': 'array',
    'items': {'type': 'integer', 'minimum': 0, 'maximum': 3},
    'maxItems': 4,
  },
};
const _mistakeFields = {
  'title': _string,
  'question': _string,
  'subject': _string,
  'chapter': _string,
  'correct_answer': _string,
  'ai_analysis': _string,
  'suggested_reason': _string,
  'tags': _tags,
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
    'type': 'object',
    'properties': fields,
    'required': required,
    'additionalProperties': false,
  },
);

final studyToolSchemas = [
  _schema(
    'list_subject_modules',
    '查询科目的模块和子模块目录；可用 query 查找名称。',
    {'subject': _string, 'query': _string},
    ['subject'],
  ),
  _schema(
    'create_subject_module',
    '经用户确认创建科目模块；parent_id 表示同科目的一级模块，最多两级。相同目录重复创建会复用。',
    {'subject': _string, 'name': _string, 'parent_id': _string},
    ['subject', 'name'],
  ),
  _schema(
    'link_study_module',
    '经用户确认，将已有知识或错题关联到同科目的模块或子模块。只新增关联，不覆盖已有分类。',
    {
      'id': _string,
      'kind': {
        'type': 'string',
        'enum': ['knowledge', 'mistake'],
      },
      'module_id': _string,
    },
    ['id', 'kind', 'module_id'],
  ),
  _schema('search_knowledge', '搜索用户授权的本地知识，返回最多5条摘要。', {
    'query': _string,
    'subject': _string,
    'module_id': _string,
  }, []),
  _schema('get_knowledge', '读取一条知识和版本号，正文最多12000字符。', {'id': _string}, ['id']),
  _schema('create_knowledge', '提出新增知识建议；必须由用户在应用内确认后才保存。', _knowledgeFields, [
    'title',
    'content',
    'subject',
  ]),
  _schema(
    'update_knowledge',
    '提出知识修改建议，必须提供读取时的版本号，并由用户确认。',
    {'id': _string, 'expected_revision': _integer, ..._knowledgeFields},
    ['id', 'expected_revision'],
  ),
  _schema(
    'delete_knowledge',
    '将知识移入回收区，可恢复，必须经用户确认。',
    {'id': _string, 'expected_revision': _integer},
    ['id', 'expected_revision'],
  ),
  _schema('search_mistakes', '搜索错题，返回最多5条摘要。', {
    'query': _string,
    'subject': _string,
    'module_id': _string,
  }, []),
  _schema('get_mistake', '读取错题、AI解析、版本及用户明确记录的思路。', {'id': _string}, ['id']),
  _schema(
    'create_mistake',
    '提出错题保存建议；未知原题和答案不要编造。错误原因仅填写为建议，等待用户确认。题目依赖本次请求的图片时，用 image_indices 明确引用图片序号（从 0 开始，最多 4 张，仅前 4 张图片可用）；不填写时错题不附加图片。',
    {..._mistakeFields, ..._imageIndicesField},
    ['title', 'subject'],
  ),
  _schema(
    'update_mistake',
    '提出错题资料修改建议，不能修改用户原答案、用户分析或已确认的错误原因。',
    {'id': _string, 'expected_revision': _integer, ..._mistakeFields},
    ['id', 'expected_revision'],
  ),
  _schema(
    'delete_mistake',
    '将错题移入回收区，可恢复，必须经用户确认。',
    {'id': _string, 'expected_revision': _integer},
    ['id', 'expected_revision'],
  ),
  _schema(
    'link_mistake_to_knowledge',
    '提出知识与错题关联建议，需用户确认。',
    {'knowledge_id': _string, 'mistake_id': _string},
    ['knowledge_id', 'mistake_id'],
  ),
  _schema('get_learning_progress', '读取真实资料、训练与知识点检测证据；样本不足不能给出掌握分数。', {}, []),
  _schema(
    'schedule_review',
    '将一条已存在的练习加入复习。需用户确认；日期由确定性调度代码管理，不能由模型指定。',
    {'question_id': _string},
    ['question_id'],
  ),
];
const _readTools = {
  'list_subject_modules',
  'search_knowledge',
  'get_knowledge',
  'search_mistakes',
  'get_mistake',
  'get_learning_progress',
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
    this.confirm,
    this.reviews,
    this.sourceImages = const [],
  });
  final StudyStore store;
  final ReviewStore? reviews;
  final String sessionId, runId;

  /// Only set by the explicit app UI. Model/user text never sets this capability.
  final bool authorized;
  final ConfirmStudyTool? confirm;
  final List<Attachment> sourceImages;
  AppDatabase get db => store.db;
  Future<Map<String, dynamic>> execute(
    ToolCall call,
    CancelToken cancel,
  ) async {
    if (!authorized) return {'ok': false, 'error': '此会话未获本地资料工具权限。'};
    cancel.checkCancelled();
    Map<String, dynamic> args;
    try {
      if (call.arguments.length > 64000) throw const FormatException('参数过长。');
      args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
      final schema = studyToolSchemas
          .where((t) => t.name == call.name)
          .firstOrNull;
      if (schema == null) throw const FormatException('未知工具。');
      final p = schema.parameters;
      for (final key in args.keys) {
        if (!(p['properties'] as Map).containsKey(key)) {
          throw FormatException('未知参数：$key');
        }
      }
      for (final key in p['required'] as List) {
        if (!args.containsKey(key)) throw FormatException('缺少参数：$key');
      }
      for (final entry in args.entries) {
        final prop = p['properties'][entry.key] as Map;
        final type = prop['type'];
        final v = entry.value;
        if (type == 'string' && v is! String) {
          throw FormatException('参数 ${entry.key} 类型无效。');
        }
        if (type == 'integer' && (v is! int || v < 1)) {
          throw FormatException('参数 ${entry.key} 类型无效。');
        }
        if (type == 'array') {
          if (v is! List) {
            throw FormatException('参数 ${entry.key} 类型无效。');
          }
          // Integer arrays (image_indices) validate elements as ints;
          // every other array parameter is a list of strings.
          final itemType = (prop['items'] as Map?)?['type'];
          if (itemType == 'integer') {
            if (v.any((e) => e is! int)) {
              throw FormatException('参数 ${entry.key} 类型无效。');
            }
          } else if (v.any((e) => e is! String)) {
            throw FormatException('参数 ${entry.key} 类型无效。');
          }
        }
      }
      // Validate sizes before approval, including fields ignored by any individual tool.
      for (final e in args.entries) {
        if (e.value is String) {
          store.checked(
            e.value,
            e.key,
            e.key == 'content' ||
                    e.key == 'question' ||
                    e.key == 'ai_analysis' ||
                    e.key == 'correct_answer'
                ? 60000
                : 500,
          );
        }
      }
      if (args['tags'] != null) {
        store.cleanTags((args['tags'] as List).cast<String>());
      }
    } catch (e) {
      // Keep the specific reason (e.g. which parameter is missing) so the
      // model can fix the call instead of repeating the same bad call.
      return {
        'ok': false,
        'error': e is FormatException ? e.message : '工具名称或参数无效，请检查字段、类型和长度。',
      };
    }
    final encoded = canonicalJson(args);
    final existing = await (db.select(
      db.aiToolOperations,
    )..where((t) => t.id.equals('$runId:${call.id}'))).getSingleOrNull();
    if (existing != null) {
      if (existing.name != call.name || existing.arguments != encoded) {
        return {'ok': false, 'error': '工具调用 ID 已用于其他参数。'};
      }
      return existing.result == null
          ? {'ok': false, 'error': '此操作已在处理中或被中断，请发起新的请求。'}
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
                      'pending',
                      'running',
                      'succeeded',
                      'rejected',
                    ]),
              ))
              .getSingleOrNull();
      if (duplicate != null) {
        return duplicate.result == null
            ? {'ok': false, 'error': '相同操作正在等待确认或执行，已阻止重复调用。'}
            : (jsonDecode(duplicate.result!) as Map).cast<String, dynamic>();
      }
    }
    final operationId = '$runId:${call.id}';
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
              status: 'pending',
              createdAt: DateTime.now(),
            ),
          );
    } catch (_) {
      return {'ok': false, 'error': '无法登记操作，或检测到重复请求；未执行修改。'};
    }

    try {
      if (!_readTools.contains(call.name)) {
        final approved = confirm != null && await confirm!(call.name, args);
        cancel.checkCancelled();
        if (!approved) {
          final result = {'ok': false, 'error': '用户未确认，未修改任何资料。'};
          await _result(operationId, 'rejected', result);
          return result;
        }
      }
      cancel.checkCancelled();
      final result = await db.transaction(() async {
        final value = await _invoke(call.name, args);
        cancel.checkCancelled();
        final result = {'ok': true, ...value};
        await _result(operationId, 'succeeded', result);
        return result;
      });
      store.changed();
      return result;
    } on DioException {
      await _result(operationId, 'cancelled', {
        'ok': false,
        'error': '已取消，未完成的修改已回滚。',
      });
      rethrow;
    } catch (e) {
      final result = {
        'ok': false,
        'error': e is FormatException ? e.message : '操作未完成，数据库修改已回滚。',
      };
      await _result(operationId, 'failed', result);
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

  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> a,
  ) async {
    String text(String key, [String fallback = '']) =>
        a[key] as String? ?? fallback;
    List<String> labels(List<String> fallback) =>
        a['tags'] == null ? fallback : (a['tags'] as List).cast<String>();
    switch (name) {
      case 'list_subject_modules':
        final all = await store.modules.list(text('subject'));
        final matches = all
            .where(
              (m) => m.name.toLowerCase().contains(text('query').toLowerCase()),
            )
            .toList();
        return {
          'modules': matches
              .take(100)
              .map(
                (m) => {
                  'id': m.id,
                  'name': m.name,
                  'subject': m.subject,
                  'parent_id': m.parentId,
                },
              )
              .toList(),
          'truncated': matches.length > 100,
        };
      case 'create_subject_module':
        final id = await store.modules.create(
          text('subject'),
          text('name'),
          parentId: a['parent_id'] as String?,
        );
        return {'id': id, 'subject': text('subject'), 'name': text('name')};
      case 'link_study_module':
        if (!['knowledge', 'mistake'].contains(text('kind'))) {
          throw const FormatException('资料类型无效。');
        }
        await store.modules.link(
          text('id'),
          text('kind') == 'mistake',
          text('module_id'),
        );
        return {'id': text('id'), 'module_id': text('module_id')};
      case 'search_knowledge':
        final rows = await store.searchKnowledge(
          query: text('query'),
          subject: text('subject'),
          moduleId: text('module_id'),
          limit: 5,
        );
        return {
          'items': rows
              .map(
                (k) => {
                  'id': k.id,
                  'title': k.title,
                  'subject': k.subject,
                  'kind': k.kind,
                  'revision': k.revision,
                  'snippet': k.content.substring(
                    0,
                    k.content.length.clamp(0, 160),
                  ),
                },
              )
              .toList(),
        };
      case 'get_knowledge':
        final k = await store.knowledge(text('id'));
        return {
          'id': k.id,
          'title': k.title,
          'content': k.content.substring(0, k.content.length.clamp(0, 12000)),
          'truncated': k.content.length > 12000,
          'subject': k.subject,
          'kind': k.kind,
          'chapter': k.chapter,
          'module_ids': await store.modules.ids(k.id, false),
          'tags': await store.tags(k.id, isMistake: false),
          'revision': k.revision,
        };
      case 'create_knowledge':
      case 'update_knowledge':
        final old = name == 'update_knowledge'
            ? await store.knowledge(text('id'))
            : null;
        if (old != null &&
            a.keys.every((k) => ['id', 'expected_revision'].contains(k))) {
          throw const FormatException('没有提供需要修改的字段。');
        }
        final row = await store.saveKnowledge(
          KnowledgeDraft(
            title: text('title', old?.title ?? ''),
            content: text('content', old?.content ?? ''),
            subject: text('subject', old?.subject ?? ''),
            kind: text('kind', old?.kind ?? '个人笔记'),
            chapter: text('chapter', old?.chapter ?? ''),
            tags: labels(
              old == null ? [] : await store.tags(old.id, isMistake: false),
            ),
          ),
          id: old?.id,
          expectedRevision: a['expected_revision'] as int?,
          sourceSessionId: sessionId,
          sourceMessageId: runId,
        );
        return {'id': row.id, 'revision': row.revision, 'title': row.title};
      case 'delete_knowledge':
        await store.setDeleted(
          text('id'),
          isMistake: false,
          deleted: true,
          expectedRevision: a['expected_revision'] as int,
        );
        return {'id': text('id'), 'recoverable': true};
      case 'search_mistakes':
        final rows = await store.searchMistakes(
          query: text('query'),
          subject: text('subject'),
          moduleId: text('module_id'),
          limit: 5,
        );
        return {
          'items': rows
              .map(
                (m) => {
                  'id': m.id,
                  'title': m.title,
                  'subject': m.subject,
                  'revision': m.revision,
                  'snippet': m.question.substring(
                    0,
                    m.question.length.clamp(0, 160),
                  ),
                },
              )
              .toList(),
        };
      case 'get_mistake':
        final m = await store.mistake(text('id'));
        String bound(String v) => v.substring(0, v.length.clamp(0, 4000));
        return {
          'id': m.id,
          'title': m.title,
          'question': bound(m.question),
          'subject': m.subject,
          'chapter': m.chapter,
          'module_ids': await store.modules.ids(m.id, true),
          'correct_answer': bound(m.correctAnswer),
          'original_answer': bound(m.originalAnswer),
          'own_analysis': bound(m.ownAnalysis),
          'ai_analysis': bound(m.aiAnalysis),
          'error_reason': m.errorReason,
          'suggested_reason': m.suggestedReason,
          'tags': await store.tags(m.id, isMistake: true),
          'revision': m.revision,
          'image_access': '本工具未返回图片内容。需由用户从错题详情发送图片，才能进行视觉分析。',
          'images_available': (await store.images(
            m.id,
            isMistake: true,
          )).length,
        };
      case 'create_mistake':
      case 'update_mistake':
        final old = name == 'update_mistake'
            ? await store.mistake(text('id'))
            : null;
        if (old != null &&
            a.keys.every((k) => ['id', 'expected_revision'].contains(k))) {
          throw const FormatException('没有提供需要修改的字段。');
        }
        final row = await store.saveMistake(
          MistakeDraft(
            title: text('title', old?.title ?? ''),
            question: text('question', old?.question ?? ''),
            subject: text('subject', old?.subject ?? ''),
            chapter: text('chapter', old?.chapter ?? ''),
            correctAnswer: text('correct_answer', old?.correctAnswer ?? ''),
            originalAnswer: old?.originalAnswer ?? '',
            ownAnalysis: old?.ownAnalysis ?? '',
            aiAnalysis: text('ai_analysis', old?.aiAnalysis ?? ''),
            errorReason: old?.errorReason ?? '暂未确定',
            suggestedReason: text(
              'suggested_reason',
              old?.suggestedReason ?? '',
            ),
            tags: labels(
              old == null ? [] : await store.tags(old.id, isMistake: true),
            ),
          ),
          id: old?.id,
          expectedRevision: a['expected_revision'] as int?,
          sourceSessionId: sessionId,
          sourceMessageId: runId,
        );
        if (old == null) {
          // Only copy the images the model referenced. Without
          // image_indices the mistake gets no images: copying the whole
          // session history attached unrelated pictures to every mistake.
          final indices = a['image_indices'];
          if (indices != null) {
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
            for (final i in indices.cast<int>()) {
              await store.copyChatImage(
                row.id,
                sourceImages[i],
                isMistake: true,
              );
            }
          }
        }
        return {'id': row.id, 'title': row.title, 'revision': row.revision};
      case 'delete_mistake':
        await store.setDeleted(
          text('id'),
          isMistake: true,
          deleted: true,
          expectedRevision: a['expected_revision'] as int,
        );
        return {'id': text('id'), 'recoverable': true};
      case 'link_mistake_to_knowledge':
        await store.link(text('knowledge_id'), mistakeId: text('mistake_id'));
        return {'linked': true};
      case 'schedule_review':
        final service = reviews ?? ReviewStore(db);
        try {
          final schedule = await service.enroll(text('question_id'));
          return {
            'schedule_id': schedule.id,
            'question_id': schedule.questionId,
            'due_at': schedule.dueAt.toIso8601String(),
            'scheduler': 'deterministic',
          };
        } finally {
          if (reviews == null) service.dispose();
        }
      case 'get_learning_progress':
        Future<int> count(String table) async =>
            (await db
                    .customSelect(
                      'SELECT count(*) AS n FROM $table WHERE deleted = 0',
                    )
                    .getSingle())
                .read<int>('n');
        return {
          'knowledge_count': await count('knowledge_items'),
          'mistake_count': await count('mistakes'),
          'chat_count': await count('chat_sessions'),
          ...(await LearningProgress.load(db)).toJson(),
        };
      default:
        throw const FormatException('未知工具。');
    }
  }
}
