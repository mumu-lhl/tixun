import 'package:tixun/core/l10n/app_error.dart';

import 'module_store.dart';
import 'subject_scope.dart';

import 'dart:async';
import 'dart:convert';

import 'question_region.dart';

import 'package:drift/drift.dart';

import '../../core/database/database_notifier.dart';

import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/database/attachment_cleanup.dart';
import '../../core/platform/attachment_selection.dart';
import '../../core/platform/attachment_store.dart';

const schoolSubjects = ['数学', '物理', '化学', '语文', '英语', '地理', '生物', '历史', '政治'];
const knowledgeKinds = [
  '通用文章',
  '概念',
  '定义',
  '公式',
  '定理',
  '原理',
  '解题方法',
  '解题技巧',
  '易错点',
  '例题',
  '个人笔记',
];
const mistakeReasons = [
  '知识不理解',
  '公式记忆错误',
  '方法选择错误',
  '推理或计算错误',
  '审题错误',
  '遗漏条件',
  '粗心失误',
  '时间不足',
  '暂未确定',
];

class StudyConflict extends FormatException {
  const StudyConflict() : super('这条资料已在其他操作中更新，请重新打开后编辑，避免覆盖新内容。');
}

class KnowledgeDraft {
  const KnowledgeDraft({
    required this.title,
    required this.content,
    this.subject = '数学',
    this.kind = '个人笔记',
    this.chapter = '',
    this.tags = const [],
  });
  final String title, content, subject, kind, chapter;
  final List<String> tags;
}

class MistakeDraft {
  const MistakeDraft({
    required this.title,
    this.question = '',
    this.subject = '数学',
    this.chapter = '',
    this.correctAnswer = '',
    this.originalAnswer = '',
    this.ownAnalysis = '',
    this.aiAnalysis = '',
    this.errorReason = '暂未确定',
    this.suggestedReason = '',
    this.tags = const [],
  });
  final String title,
      question,
      subject,
      chapter,
      correctAnswer,
      originalAnswer,
      ownAnalysis,
      aiAnalysis,
      errorReason,
      suggestedReason;
  final List<String> tags;
}

class KnowledgeDetail {
  const KnowledgeDetail(
    this.item,
    this.tags,
    this.images,
    this.related,
    this.mistakes,
  );
  final KnowledgeItem item;
  final List<String> tags;
  final List<StudyAttachment> images;
  final List<KnowledgeItem> related;
  final List<Mistake> mistakes;
}

class MistakeDetail {
  const MistakeDetail(this.item, this.tags, this.images, this.knowledge);
  final Mistake item;
  final List<String> tags;
  final List<StudyAttachment> images;
  final List<KnowledgeItem> knowledge;
}

/// One boundary for UI and AI writes: validation, version checks, history and links.
class StudyStore extends DatabaseNotifier {
  StudyStore(this.db, this.files) {
    // Best-effort startup sweep for orphan attachment files left by a
    // crash between the disk write and the row insert. Only files older
    // than 10 minutes are eligible, so in-flight imports and demo seeding
    // are never touched; failures must never block startup.
    unawaited(cleanupOrphanAttachments(db, files).catchError((Object _) => 0));
  }
  final AppDatabase db;
  final AttachmentStore files;
  late final ModuleStore modules = ModuleStore(db, changed);
  int epoch = 0;
  @override
  void dispose() {
    modules.dispose();
    super.dispose();
  }

  @override
  void changed() {
    if (isDisposed) return;
    epoch++;
    super.changed();
  }

  String _checked(
    String value,
    StudyErrorField label,
    int limit, {
    bool required = false,
  }) => checked(value, label.source, limit, required: required, field: label);

  String checked(
    String value,
    String label,
    int limit, {
    bool required = false,
    StudyErrorField? field,
  }) {
    final s = value.trim();
    if ((required && s.isEmpty) || s.length > limit) {
      final message = '$label${s.isEmpty ? '不能为空' : '过长（最多 $limit 字符）'}';
      throw AppFormatException(
        s.isEmpty
            ? AppErrorCode.errorStudyFieldRequired
            : AppErrorCode.errorStudyFieldTooLong,
        message,
        [field?.name ?? label, '$limit', if (field != null) 'builtin'],
      );
    }
    return s;
  }

  List<String> cleanTags(List<String> tags) {
    if (tags.length > 20) {
      throw const AppFormatException(
        AppErrorCode.errorEachMaterialCanHaveAtMost,
        '每条资料最多 20 个标签。',
      );
    }
    return tags
        .map((t) => _checked(t, StudyErrorField.tag, 40))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<String> acceptQuestionRegion(
    String operationId,
    int index,
    Uint8List bytes,
    ({double left, double top, double right, double bottom}) crop,
    int turns,
  ) => runOperation(() async {
    if (![
          crop.left,
          crop.top,
          crop.right,
          crop.bottom,
        ].every((v) => v.isFinite) ||
        crop.left < 0 ||
        crop.top < 0 ||
        crop.right > 1 ||
        crop.bottom > 1 ||
        (crop.right - crop.left) <= 0 ||
        (crop.bottom - crop.top) <= 0 ||
        turns < 0 ||
        turns > 3) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidUserCropArea,
        '用户裁剪范围无效。',
      );
    }
    if (bytes.isEmpty ||
        bytes.length > 8 * 1024 * 1024 ||
        index < 0 ||
        index > 11) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidQuestionRegionImageOrNumber,
        '分题图片或编号无效。',
      );
    }
    final relative = 'attachments/${const Uuid().v4()}.png';
    var used = false;
    var attached = false;
    try {
      final file = files.resolve(relative);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      final id = await db.transaction(() async {
        final op =
            await (db.select(db.aiToolOperations)..where(
                  (o) =>
                      o.id.equals(operationId) &
                      o.name.equals('suggest_question_regions') &
                      o.status.equals('succeeded'),
                ))
                .getSingle();
        final data = (jsonDecode(op.result!) as Map).cast<String, dynamic>();
        final regions = data['regions'] as List;
        if (index >= regions.length) {
          throw const AppFormatException(
            AppErrorCode.errorTheSuggestedQuestionRegionWasNot,
            '未找到此分题建议。',
          );
        }
        final region = QuestionRegion.fromJson(
          (regions[index] as Map).cast<String, dynamic>(),
        );
        final accepted = (data['accepted'] as Map? ?? {})
            .cast<String, dynamic>();
        final prior = accepted['$index'];
        if (prior is String) {
          try {
            await mistake(prior, includeDeleted: true);
            return prior;
          } on FormatException {
            // The previously accepted mistake was permanently purged:
            // treat this as never accepted and create a fresh one below;
            // the stale entry is overwritten when the new row is recorded.
          }
        }
        final image =
            await (db.select(db.attachments)..where(
                  (a) =>
                      a.id.equals(data['image_id'] as String) &
                      a.sessionId.equals(op.sessionId),
                ))
                .getSingle();
        final row = await saveMistake(
          MistakeDraft(
            title: region.label,
            subject: region.subject,
            question: region.question,
            aiAnalysis: region.question.isEmpty
                ? ''
                : '题目文字由 AI 从图片转录，尚未核对，请以原图为准。',
          ),
          sourceSessionId: op.sessionId,
          sourceMessageId: op.runId,
        );
        final original = await addImageReference(
          row.id,
          image.relativePath,
          image.mime,
          image.byteLength,
          isMistake: true,
        );
        await addImageReference(
          row.id,
          relative,
          'image/png',
          bytes.length,
          isMistake: true,
          parentId: original.id,
          role: 'crop',
        );
        await (db.update(
          db.aiToolOperations,
        )..where((o) => o.id.equals(operationId))).write(
          AiToolOperationsCompanion(
            result: Value(
              jsonEncode({
                ...data,
                'accepted': {...accepted, '$index': row.id},
                'user_crops': {
                  ...(data['user_crops'] as Map? ?? {}),
                  '$index': {
                    'left': crop.left,
                    'top': crop.top,
                    'right': crop.right,
                    'bottom': crop.bottom,
                    'clockwise_turns': turns,
                  },
                },
              }),
            ),
          ),
        );
        attached = true;
        return row.id;
      });
      used = attached;
      changed();
      return id;
    } finally {
      if (!used && await files.resolve(relative).exists()) {
        await files.resolve(relative).delete();
      }
    }
  });

  Future<KnowledgeItem> knowledge(
    String id, {
    bool includeDeleted = false,
  }) async {
    final row = await (db.select(
      db.knowledgeItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || (row.deleted && !includeDeleted)) {
      throw const AppFormatException(
        AppErrorCode.errorTheKnowledgeRecordDoesNotExist,
        '知识记录不存在或已在回收区。',
      );
    }
    requireStudySubject(row.subject, await readStudySubjectScope(db));
    return row;
  }

  Future<Mistake> mistake(String id, {bool includeDeleted = false}) async {
    final row = await (db.select(
      db.mistakes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || (row.deleted && !includeDeleted)) {
      throw const AppFormatException(
        AppErrorCode.errorTheMistakeDoesNotExistOr,
        '错题不存在或已在回收区。',
      );
    }
    requireStudySubject(row.subject, await readStudySubjectScope(db));
    return row;
  }

  Future<List<String>> tags(String id, {required bool isMistake}) async =>
      isMistake
      ? (await (db.select(
              db.mistakeTags,
            )..where((t) => t.mistakeId.equals(id))).get())
            .map((t) => t.tag)
            .toList()
      : (await (db.select(
              db.knowledgeTags,
            )..where((t) => t.knowledgeId.equals(id))).get())
            .map((t) => t.tag)
            .toList();
  Future<void> _tags(String id, List<String> tags, bool isMistake) async {
    if (isMistake) {
      await (db.delete(
        db.mistakeTags,
      )..where((t) => t.mistakeId.equals(id))).go();
      for (final tag in tags) {
        await db
            .into(db.mistakeTags)
            .insert(MistakeTagsCompanion.insert(mistakeId: id, tag: tag));
      }
    } else {
      await (db.delete(
        db.knowledgeTags,
      )..where((t) => t.knowledgeId.equals(id))).go();
      for (final tag in tags) {
        await db
            .into(db.knowledgeTags)
            .insert(KnowledgeTagsCompanion.insert(knowledgeId: id, tag: tag));
      }
    }
  }

  Future<void> _snapshot(KnowledgeItem row, List<String> tags) => db
      .into(db.knowledgeRevisions)
      .insert(
        KnowledgeRevisionsCompanion.insert(
          knowledgeId: row.id,
          revision: row.revision,
          title: row.title,
          content: row.content,
          subject: row.subject,
          kind: row.kind,
          chapter: row.chapter,
          tagsSnapshot: jsonEncode(tags),
          createdAt: row.updatedAt,
        ),
      );
  Future<void> _source(String? session, String? message) async {
    if (message == null) return;
    final m = await (db.select(
      db.chatMessages,
    )..where((t) => t.id.equals(message))).getSingleOrNull();
    if (m == null || m.sessionId != session) {
      throw const AppFormatException(
        AppErrorCode.errorTheSourceConversationAndMessageDo,
        '来源对话和消息不匹配。',
      );
    }
  }

  Future<KnowledgeItem> saveKnowledge(
    KnowledgeDraft draft, {
    String? id,
    int? expectedRevision,
    String? sourceSessionId,
    String? sourceMessageId,
  }) => runOperation(() async {
    final title = _checked(
      draft.title,
      StudyErrorField.title,
      160,
      required: true,
    );
    final content = _checked(draft.content, StudyErrorField.body, 60000);
    final subject = _checked(
      draft.subject,
      StudyErrorField.subject,
      40,
      required: true,
    );
    final subjectScope = await readStudySubjectScope(db);
    requireStudySubject(subject, subjectScope);
    final chapter = _checked(draft.chapter, StudyErrorField.chapter, 160);
    if (!knowledgeKinds.contains(draft.kind)) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidKnowledgeType,
        '知识类型无效。',
      );
    }
    final labels = cleanTags(draft.tags);
    final result = await db.transaction(() async {
      final old = id == null ? null : await knowledge(id);
      if (old != null) requireStudySubject(old.subject, subjectScope);
      if (old != null && old.revision != expectedRevision) {
        throw const StudyConflict();
      }
      await _source(sourceSessionId, sourceMessageId);
      final now = DateTime.now();
      final key = id ?? const Uuid().v4();
      final row = KnowledgeItem(
        id: key,
        title: title,
        content: content,
        subject: subject,
        kind: draft.kind,
        chapter: chapter,
        revision: (old?.revision ?? 0) + 1,
        sourceSessionId: old?.sourceSessionId ?? sourceSessionId,
        sourceMessageId: old?.sourceMessageId ?? sourceMessageId,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        deleted: false,
      );
      if (old == null) {
        await db.into(db.knowledgeItems).insert(row);
      } else {
        final count =
            await (db.update(db.knowledgeItems)..where(
                  (t) =>
                      t.id.equals(key) &
                      t.revision.equals(expectedRevision!) &
                      t.deleted.equals(false),
                ))
                .write(row);
        if (count != 1) throw const StudyConflict();
      }
      await _removeMismatchedModules(key, subject, false);
      await _tags(key, labels, false);
      await _snapshot(row, labels);
      if (sourceSessionId != null) {
        await _chatLink(sourceSessionId, knowledgeId: key);
      }
      return row;
    });
    changed();
    return result;
  });

  Future<Mistake> saveMistake(
    MistakeDraft draft, {
    String? id,
    int? expectedRevision,
    String? sourceSessionId,
    String? sourceMessageId,
  }) => runOperation(() async {
    final title = _checked(
      draft.title,
      StudyErrorField.title,
      160,
      required: true,
    );
    final subject = _checked(
      draft.subject,
      StudyErrorField.subject,
      40,
      required: true,
    );
    final subjectScope = await readStudySubjectScope(db);
    requireStudySubject(subject, subjectScope);
    for (final text in [
      draft.question,
      draft.correctAnswer,
      draft.originalAnswer,
      draft.ownAnalysis,
      draft.aiAnalysis,
    ]) {
      _checked(text, StudyErrorField.content, 60000);
    }
    final chapter = _checked(draft.chapter, StudyErrorField.chapter, 160);
    final reason = _checked(
      draft.errorReason,
      StudyErrorField.reason,
      100,
      required: true,
    );
    final suggestion = _checked(
      draft.suggestedReason,
      StudyErrorField.suggestedReason,
      500,
    );
    final labels = cleanTags(draft.tags);
    final result = await db.transaction(() async {
      final old = id == null ? null : await mistake(id);
      if (old != null) requireStudySubject(old.subject, subjectScope);
      if (old != null && old.revision != expectedRevision) {
        throw const StudyConflict();
      }
      await _source(sourceSessionId, sourceMessageId);
      final now = DateTime.now();
      final key = id ?? const Uuid().v4();
      final row = Mistake(
        id: key,
        title: title,
        subject: subject,
        question: draft.question.trim(),
        chapter: chapter,
        correctAnswer: draft.correctAnswer.trim(),
        originalAnswer: draft.originalAnswer.trim(),
        ownAnalysis: draft.ownAnalysis.trim(),
        aiAnalysis: draft.aiAnalysis.trim(),
        errorReason: reason,
        suggestedReason: suggestion,
        revision: (old?.revision ?? 0) + 1,
        sourceSessionId: old?.sourceSessionId ?? sourceSessionId,
        sourceMessageId: old?.sourceMessageId ?? sourceMessageId,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        deleted: false,
      );
      if (old == null) {
        await db.into(db.mistakes).insert(row);
      } else {
        final count =
            await (db.update(db.mistakes)..where(
                  (t) =>
                      t.id.equals(key) &
                      t.revision.equals(expectedRevision!) &
                      t.deleted.equals(false),
                ))
                .write(row);
        if (count != 1) throw const StudyConflict();
      }
      await _removeMismatchedModules(key, subject, true);
      await _tags(key, labels, true);
      if (sourceSessionId != null) {
        await _chatLink(sourceSessionId, mistakeId: key);
      }
      return row;
    });
    changed();
    return result;
  });

  Future<void> setDeleted(
    String id, {
    required bool isMistake,
    required bool deleted,
    required int expectedRevision,
  }) => runOperation(() async {
    await db.transaction(
      () => _setDeleted(
        id,
        isMistake: isMistake,
        deleted: deleted,
        expectedRevision: expectedRevision,
      ),
    );
    changed();
  });

  Future<void> _setDeleted(
    String id, {
    required bool isMistake,
    required bool deleted,
    required int expectedRevision,
  }) async {
    final subjectScope = await readStudySubjectScope(db);
    if (isMistake) {
      final row = await mistake(id, includeDeleted: true);
      requireStudySubject(row.subject, subjectScope);
      if (row.revision != expectedRevision) throw const StudyConflict();
      await db
          .update(db.mistakes)
          .replace(
            row.copyWith(
              deleted: deleted,
              revision: row.revision + 1,
              updatedAt: DateTime.now(),
            ),
          );
    } else {
      final row = await knowledge(id, includeDeleted: true);
      requireStudySubject(row.subject, subjectScope);
      if (row.revision != expectedRevision) throw const StudyConflict();
      final next = row.copyWith(
        deleted: deleted,
        revision: row.revision + 1,
        updatedAt: DateTime.now(),
      );
      await db.update(db.knowledgeItems).replace(next);
      await _snapshot(next, await tags(id, isMistake: false));
    }
  }

  Future<Map<String, int>> batchSetDeleted(
    Map<String, int> revisions, {
    required bool isMistake,
    required bool deleted,
  }) => runOperation(() async {
    _checkBatch(revisions);
    await db.transaction(() async {
      for (final entry in revisions.entries) {
        await _setDeleted(
          entry.key,
          isMistake: isMistake,
          deleted: deleted,
          expectedRevision: entry.value,
        );
      }
    });
    changed();
    return {for (final e in revisions.entries) e.key: e.value + 1};
  });

  void _checkBatch(Map<String, int> revisions) {
    if (revisions.isEmpty ||
        revisions.length > 200 ||
        revisions.values.any((v) => v < 1)) {
      throw const AppFormatException(
        AppErrorCode.errorSelect1200MaterialsAtA,
        '每次请选择 1–200 条资料。',
      );
    }
  }

  Future<int> purge(Map<String, int> revisions, {required bool isMistake}) =>
      runOperation(() async {
        _checkBatch(revisions);
        final subjectScope = await readStudySubjectScope(db);
        final paths = <String>[];
        await db.transaction(() async {
          for (final entry in revisions.entries) {
            final row = isMistake
                ? await mistake(entry.key, includeDeleted: true)
                : await knowledge(entry.key, includeDeleted: true);
            requireStudySubject(
              isMistake
                  ? (row as Mistake).subject
                  : (row as KnowledgeItem).subject,
              subjectScope,
            );
            final deleted = isMistake
                ? (row as Mistake).deleted
                : (row as KnowledgeItem).deleted;
            final revision = isMistake
                ? (row as Mistake).revision
                : (row as KnowledgeItem).revision;
            if (!deleted || revision != entry.value) {
              throw const StudyConflict();
            }
            paths.addAll(
              (await images(
                entry.key,
                isMistake: isMistake,
              )).map((i) => i.relativePath),
            );
            paths.addAll(
              (await images(
                entry.key,
                isMistake: isMistake,
                trash: true,
              )).map((i) => i.relativePath),
            );
            if (isMistake) {
              await (db.delete(
                db.mistakes,
              )..where((m) => m.id.equals(entry.key))).go();
            } else {
              await (db.delete(
                db.knowledgeItems,
              )..where((k) => k.id.equals(entry.key))).go();
            }
          }
        });
        changed();
        return cleanupPurgedAttachments(db, files, paths);
      });

  Future<List<KnowledgeRevision>> revisions(String id) =>
      (db.select(db.knowledgeRevisions)
            ..where((t) => t.knowledgeId.equals(id))
            ..orderBy([(t) => OrderingTerm.desc(t.revision)]))
          .get();
  Future<KnowledgeItem> restoreRevision(
    String id,
    int version,
    int expectedRevision,
  ) => runOperation(() async {
    final r =
        await (db.select(db.knowledgeRevisions)..where(
              (t) => t.knowledgeId.equals(id) & t.revision.equals(version),
            ))
            .getSingle();
    return saveKnowledge(
      KnowledgeDraft(
        title: r.title,
        content: r.content,
        subject: r.subject,
        kind: r.kind,
        chapter: r.chapter,
        tags: (jsonDecode(r.tagsSnapshot) as List).cast<String>(),
      ),
      id: id,
      expectedRevision: expectedRevision,
    );
  });

  Future<void> _removeMismatchedModules(
    String id,
    String subject,
    bool mistake,
  ) async {
    final table = mistake ? 'mistake_module_links' : 'knowledge_module_links';
    final key = mistake ? 'mistake_id' : 'knowledge_id';
    await db.customUpdate(
      'DELETE FROM $table WHERE $key=? AND module_id IN (SELECT id FROM subject_modules WHERE subject<>?)',
      variables: [Variable(id), Variable(subject)],
      updates: {db.knowledgeModuleLinks, db.mistakeModuleLinks},
    );
  }

  Future<List<KnowledgeItem>> searchKnowledge({
    String query = '',
    String subject = '',
    String moduleId = '',
    bool trash = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _search(
      'knowledge_items',
      'knowledge_search',
      'content',
      query,
      subject,
      trash,
      limit,
      offset,
      moduleId,
    );
    return Future.wait(rows.map(db.knowledgeItems.mapFromRow));
  }

  Future<List<Mistake>> searchMistakes({
    String query = '',
    String subject = '',
    String moduleId = '',
    bool trash = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _search(
      'mistakes',
      'mistake_search',
      'question',
      query,
      subject,
      trash,
      limit,
      offset,
      moduleId,
    );
    return Future.wait(rows.map(db.mistakes.mapFromRow));
  }

  Future<List<QueryRow>> _search(
    String table,
    String fts,
    String body,
    String query,
    String subject,
    bool trash,
    int limit,
    int offset,
    String moduleId,
  ) async {
    final scope = await readStudySubjectScope(db);
    if (scope != null && subject.isNotEmpty) {
      requireStudySubject(subject, scope);
    }
    final effectiveSubject = scope ?? subject;
    final term = _checked(query, StudyErrorField.searchTerm, 300);
    final tagTable = table == 'mistakes' ? 'mistake_tags' : 'knowledge_tags';
    final idColumn = table == 'mistakes' ? 'mistake_id' : 'knowledge_id';
    final vars = <Variable>[Variable(trash ? 1 : 0)];
    var where = 't.deleted = ?';
    if (effectiveSubject.isNotEmpty) {
      where += ' AND t.subject = ?';
      vars.add(Variable(effectiveSubject));
    }
    if (moduleId.isNotEmpty) {
      final links = table == 'mistakes'
          ? 'mistake_module_links'
          : 'knowledge_module_links';
      if (moduleId == 'unclassified') {
        where +=
            ' AND NOT EXISTS (SELECT 1 FROM $links ml WHERE ml.$idColumn=t.id)';
      } else {
        where +=
            ' AND EXISTS (SELECT 1 FROM $links ml JOIN subject_modules sm ON sm.id=ml.module_id WHERE ml.$idColumn=t.id AND (sm.id=? OR sm.parent_id=?))';
        vars.addAll([Variable(moduleId), Variable(moduleId)]);
      }
    }
    if (term.isNotEmpty) {
      final bodyExpression = table == 'mistakes'
          ? 't.question || char(10) || t.correct_answer || char(10) || t.original_answer || char(10) || t.own_analysis || char(10) || t.ai_analysis || char(10) || t.error_reason || char(10) || t.suggested_reason'
          : 't.$body';
      final condition = term.runes.length >= 3
          ? 't.rowid IN (SELECT rowid FROM $fts WHERE $fts MATCH ?)'
          : 'instr(lower(t.title || char(10) || $bodyExpression || char(10) || t.chapter), lower(?)) > 0';
      where +=
          ' AND ($condition OR EXISTS (SELECT 1 FROM $tagTable tags WHERE tags.$idColumn = t.id AND instr(lower(tags.tag), lower(?)) > 0))';
      vars.add(
        Variable(
          term.runes.length >= 3 ? '"${term.replaceAll('"', '""')}"' : term,
        ),
      );
      vars.add(Variable(term));
    }
    vars.add(Variable(limit.clamp(1, 200)));
    vars.add(Variable(offset.clamp(0, 10000000)));
    return db
        .customSelect(
          'SELECT t.* FROM $table t WHERE $where ORDER BY t.updated_at DESC, t.id LIMIT ? OFFSET ?',
          variables: vars,
          readsFrom: {db.knowledgeItems, db.mistakes},
        )
        .get();
  }

  Future<List<StudyAttachment>> images(
    String id, {
    required bool isMistake,
    bool trash = false,
  }) =>
      (db.select(db.studyAttachments)
            ..where(
              (t) =>
                  (isMistake
                      ? t.mistakeId.equals(id)
                      : t.knowledgeId.equals(id)) &
                  t.deleted.equals(trash),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.rowId)]))
          .get();
  List<StudyAttachment> preferredImages(List<StudyAttachment> images) =>
      preferredStudyImages(images);

  Future<void> restoreImage(StudyAttachment image) => runOperation(() async {
    await (db.update(db.studyAttachments)..where((t) => t.id.equals(image.id)))
        .write(const StudyAttachmentsCompanion(deleted: Value(false)));
    changed();
  });

  /// Validate an already-imported file under attachments/ without copying
  /// it: it must exist, fit the 8 MB chat limit and still be a supported
  /// image. Returns the format and size to store for the new reference.
  Future<({String mime, int bytes})> checkImageFile(String relativePath) async {
    final file = files.resolve(relativePath);
    if (!await file.exists()) {
      throw const AppFormatException(
        AppErrorCode.errorTheImageFileIsMissing,
        '图片文件缺失。',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw const AppFormatException(
        AppErrorCode.errorEachImageMustBeAtMost,
        '单张图片上限为 8 MB，请先缩小图片。',
      );
    }
    final (mime, _) = AttachmentStore.identify(bytes);
    return (mime: mime, bytes: bytes.length);
  }

  /// Reference an already-imported study image from a chat session without
  /// copying its bytes again. The chat row shares the same relative path;
  /// [cleanupPurgedAttachments] keeps the file while any table still
  /// references it, so purging one side never deletes the other's image.
  Future<void> attachExistingChatImage(String sessionId, String relativePath) =>
      runOperation(() async {
        final info = await checkImageFile(relativePath);
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: const Uuid().v4(),
                sessionId: sessionId,
                relativePath: relativePath,
                mime: info.mime,
                byteLength: info.bytes,
              ),
            );
      });

  Future<StudyAttachment> importImage(
    String id,
    String path, {
    required bool isMistake,
  }) => runOperation(() async {
    if (isMistake) {
      await mistake(id);
    } else {
      await knowledge(id);
    }
    final image = await files.importFile(path);
    try {
      return await addImageReference(
        id,
        image.path,
        image.mime,
        image.bytes,
        isMistake: isMistake,
      );
    } catch (_) {
      await files.resolve(image.path).delete();
      rethrow;
    }
  });

  Future<StudyAttachment> addImageReference(
    String id,
    String path,
    String mime,
    int bytes, {
    required bool isMistake,
    String? parentId,
    String role = 'original',
  }) => runOperation(() async {
    files.resolve(path);
    final row = await db.transaction(() async {
      if (!await files.resolve(path).exists()) {
        throw const AppFormatException(
          AppErrorCode.errorTheImageFileIsMissing,
          '图片文件缺失。',
        );
      }
      if (isMistake) {
        await mistake(id);
      } else {
        await knowledge(id);
      }
      final image = StudyAttachment(
        id: const Uuid().v4(),
        knowledgeId: isMistake ? null : id,
        mistakeId: isMistake ? id : null,
        relativePath: path,
        mime: mime,
        byteLength: bytes,
        parentId: parentId,
        role: role,
        deleted: false,
      );
      await db.into(db.studyAttachments).insert(image);
      return image;
    });
    changed();
    return row;
  });

  Future<void> copyChatImage(
    String id,
    Attachment image, {
    required bool isMistake,
  }) => runOperation(() async {
    final original = await originalChatImage(image, files);
    await db.transaction(() async {
      final root = await addImageReference(
        id,
        original.path,
        original.mime,
        original.bytes,
        isMistake: isMistake,
      );
      if (original.path != image.relativePath) {
        await addImageReference(
          id,
          image.relativePath,
          image.mime,
          image.byteLength,
          isMistake: isMistake,
          parentId: root.id,
          role: 'crop',
        );
      }
    });
  });

  Future<Mistake> importMistake(
    String path,
    String title, {
    String subject = '数学',
  }) => runOperation(() async {
    final image = await files.importFile(path);
    try {
      final row = await db.transaction(() async {
        final now = DateTime.now();
        final id = const Uuid().v4();
        final row = Mistake(
          id: id,
          title: _checked(title, StudyErrorField.title, 160, required: true),
          question: '',
          subject: _checked(
            subject,
            StudyErrorField.subject,
            40,
            required: true,
          ),
          chapter: '',
          correctAnswer: '',
          originalAnswer: '',
          ownAnalysis: '',
          aiAnalysis: '',
          errorReason: '暂未确定',
          suggestedReason: '',
          revision: 1,
          createdAt: now,
          updatedAt: now,
          deleted: false,
        );
        await db.into(db.mistakes).insert(row);
        await db
            .into(db.studyAttachments)
            .insert(
              StudyAttachmentsCompanion.insert(
                id: const Uuid().v4(),
                mistakeId: Value(id),
                relativePath: image.path,
                mime: image.mime,
                byteLength: image.bytes,
              ),
            );
        return row;
      });
      changed();
      return row;
    } catch (_) {
      await files.resolve(image.path).delete();
      rethrow;
    }
  });

  Future<void> removeImage(StudyAttachment image) => runOperation(() async {
    await (db.update(db.studyAttachments)..where((t) => t.id.equals(image.id)))
        .write(const StudyAttachmentsCompanion(deleted: Value(true)));
    changed();
  });

  Future<void> link(
    String knowledgeId, {
    String? otherKnowledgeId,
    String? mistakeId,
    bool remove = false,
  }) => runOperation(() async {
    final subjectScope = await readStudySubjectScope(db);
    await db.transaction(() async {
      final knowledgeRow = await knowledge(knowledgeId);
      requireStudySubject(knowledgeRow.subject, subjectScope);
      if (mistakeId != null) {
        final mistakeRow = await mistake(mistakeId);
        requireStudySubject(mistakeRow.subject, subjectScope);
        if (remove) {
          await (db.delete(db.mistakeKnowledgeLinks)..where(
                (t) =>
                    t.mistakeId.equals(mistakeId) &
                    t.knowledgeId.equals(knowledgeId),
              ))
              .go();
        } else {
          await db
              .into(db.mistakeKnowledgeLinks)
              .insert(
                MistakeKnowledgeLinksCompanion.insert(
                  mistakeId: mistakeId,
                  knowledgeId: knowledgeId,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      } else {
        if (otherKnowledgeId == null || otherKnowledgeId == knowledgeId) {
          throw const AppFormatException(
            AppErrorCode.errorSelectADifferentKnowledgeRecord,
            '请选择不同的知识记录。',
          );
        }
        final other = await knowledge(otherKnowledgeId);
        requireStudySubject(other.subject, subjectScope);
        if (other.subject != knowledgeRow.subject) {
          requireStudySubject(other.subject, knowledgeRow.subject);
        }
        final ids = [knowledgeId, otherKnowledgeId]..sort();
        if (remove) {
          await (db.delete(db.knowledgeRelations)..where(
                (t) => t.sourceId.equals(ids[0]) & t.targetId.equals(ids[1]),
              ))
              .go();
        } else {
          await db
              .into(db.knowledgeRelations)
              .insert(
                KnowledgeRelationsCompanion.insert(
                  sourceId: ids[0],
                  targetId: ids[1],
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
    });
    changed();
  });

  Future<void> _chatLink(
    String session, {
    String? knowledgeId,
    String? mistakeId,
  }) => db
      .into(db.studyChatLinks)
      .insert(
        StudyChatLinksCompanion.insert(
          id: const Uuid().v4(),
          sessionId: session,
          knowledgeId: Value(knowledgeId),
          mistakeId: Value(mistakeId),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  Future<void> linkChat(
    String session, {
    String? knowledgeId,
    String? mistakeId,
  }) => runOperation(() async {
    if (knowledgeId != null) await knowledge(knowledgeId);
    if (mistakeId != null) await mistake(mistakeId);
    await _chatLink(session, knowledgeId: knowledgeId, mistakeId: mistakeId);
    changed();
  });

  Future<KnowledgeDetail> knowledgeDetail(String id) async {
    final row = await knowledge(id, includeDeleted: true);
    final relations = await (db.select(
      db.knowledgeRelations,
    )..where((t) => t.sourceId.equals(id) | t.targetId.equals(id))).get();
    final relatedIds = relations
        .map((r) => r.sourceId == id ? r.targetId : r.sourceId)
        .toList();
    final linked = await (db.select(
      db.mistakeKnowledgeLinks,
    )..where((t) => t.knowledgeId.equals(id))).get();
    return KnowledgeDetail(
      row,
      await tags(id, isMistake: false),
      await images(id, isMistake: false),
      await (db.select(
        db.knowledgeItems,
      )..where((t) => t.id.isIn(relatedIds) & t.deleted.equals(false))).get(),
      await (db.select(db.mistakes)..where(
            (t) =>
                t.id.isIn(linked.map((r) => r.mistakeId)) &
                t.deleted.equals(false),
          ))
          .get(),
    );
  }

  Future<MistakeDetail> mistakeDetail(String id) async {
    final row = await mistake(id, includeDeleted: true);
    final links = await (db.select(
      db.mistakeKnowledgeLinks,
    )..where((t) => t.mistakeId.equals(id))).get();
    return MistakeDetail(
      row,
      await tags(id, isMistake: true),
      await images(id, isMistake: true),
      await (db.select(db.knowledgeItems)..where(
            (t) =>
                t.id.isIn(links.map((r) => r.knowledgeId)) &
                t.deleted.equals(false),
          ))
          .get(),
    );
  }
}
