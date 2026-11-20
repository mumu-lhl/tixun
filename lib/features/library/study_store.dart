import "package:tixun/core/l10n/app_error.dart";

import "module_store.dart";
import "subject_scope.dart";

import "dart:async";
import "dart:convert";

import "../../core/database/search_terms.dart";

import "question_region.dart";

import "package:drift/drift.dart";

import "../../core/database/database_notifier.dart";

import "package:uuid/uuid.dart";

import "../../core/markdown/visual_references.dart";

import "../../core/database/database.dart";
import "../../core/database/attachment_cleanup.dart";
import "../../core/platform/attachment_selection.dart";
import "../../core/platform/attachment_store.dart";

part "study_store_queries.dart";
part "study_store_images.dart";
part "study_store_maintenance.dart";

part "study_models.dart";

/// One boundary for UI and AI writes: validation, version checks, history and links.
class StudyStore extends DatabaseNotifier
    with _StudyQueries, _StudyImages, _StudyMaintenance {
  StudyStore(this.db, this.files) {
    // Best-effort startup sweep for orphan attachment files left by a
    // crash between the disk write and the row insert. Only files older
    // than 10 minutes are eligible, so in-flight imports and demo seeding
    // are never touched; failures must never block startup.
    unawaited(cleanupOrphanAttachments(db, files).catchError((Object _) => 0));
  }
  @override
  final AppDatabase db;
  @override
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

  @override
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
        [field?.name ?? label, "$limit", if (field != null) "builtin"],
      );
    }
    return s;
  }

  List<String> cleanTags(List<String> tags) {
    if (tags.length > 20) {
      throw const AppFormatException(
        AppErrorCode.errorEachMaterialCanHaveAtMost,
        "每条资料最多 20 个标签。",
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
        "用户裁剪范围无效。",
      );
    }
    if (bytes.isEmpty ||
        bytes.length > 8 * 1024 * 1024 ||
        index < 0 ||
        index > 11) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidQuestionRegionImageOrNumber,
        "分题图片或编号无效。",
      );
    }
    final relative = "attachments/${const Uuid().v4()}.png";
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
                      o.name.equals("suggest_question_regions") &
                      o.status.equals("succeeded"),
                ))
                .getSingle();
        final data = (jsonDecode(op.result!) as Map).cast<String, dynamic>();
        final regions = data["regions"] as List;
        if (index >= regions.length) {
          throw const AppFormatException(
            AppErrorCode.errorTheSuggestedQuestionRegionWasNot,
            "未找到此分题建议。",
          );
        }
        final region = QuestionRegion.fromJson(
          (regions[index] as Map).cast<String, dynamic>(),
        );
        final accepted = (data["accepted"] as Map? ?? {})
            .cast<String, dynamic>();
        final prior = accepted["$index"];
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
                      a.id.equals(data["image_id"] as String) &
                      a.sessionId.equals(op.sessionId),
                ))
                .getSingle();
        final row = await saveMistake(
          MistakeDraft(
            title: region.label,
            subject: region.subject,
            question: region.question,
            aiAnalysis: region.question.isEmpty
                ? ""
                : "题目文字由 AI 从图片转录，尚未核对，请以原图为准。",
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
          "image/png",
          bytes.length,
          isMistake: true,
          parentId: original.id,
          role: "crop",
        );
        await (db.update(
          db.aiToolOperations,
        )..where((o) => o.id.equals(operationId))).write(
          AiToolOperationsCompanion(
            result: Value(
              jsonEncode({
                ...data,
                "accepted": {...accepted, "$index": row.id},
                "user_crops": {
                  ...(data["user_crops"] as Map? ?? {}),
                  "$index": {
                    "left": crop.left,
                    "top": crop.top,
                    "right": crop.right,
                    "bottom": crop.bottom,
                    "clockwise_turns": turns,
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

  Future<void> _source(String? session, String? message) async {
    if (message == null) return;
    final m = await (db.select(
      db.chatMessages,
    )..where((t) => t.id.equals(message))).getSingleOrNull();
    if (m == null || m.sessionId != session) {
      throw const AppFormatException(
        AppErrorCode.errorTheSourceConversationAndMessageDo,
        "来源对话和消息不匹配。",
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
        "知识类型无效。",
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
      await _linkKnowledgeVisuals(key, content, {
        ?sourceSessionId,
        if (old?.sourceSessionId != null) old!.sourceSessionId!,
      });
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

  /// Only public figures from verified source chats can acquire a new owner.
  /// Existing owner links survive edits; arbitrary/private quiz IDs never do.
  Future<void> _linkKnowledgeVisuals(
    String knowledgeId,
    String content,
    Set<String> sourceSessions,
  ) async {
    if (sourceSessions.isEmpty) return;
    for (final visualId in visualReferences(content)) {
      final existing =
          await (db.select(db.visualStudyLinks)..where(
                (l) =>
                    l.visualId.equals(visualId) &
                    l.knowledgeId.equals(knowledgeId),
              ))
              .get();
      if (existing.isNotEmpty) continue;
      final allowed = await db
          .customSelect(
            "SELECT v.id FROM visual_scenes v "
            "JOIN visual_message_links l ON l.visual_id = v.id "
            "JOIN chat_messages m ON m.id = l.message_id "
            "JOIN chat_sessions s ON s.id = m.session_id "
            "WHERE v.id = ? AND v.deleted = 0 AND s.deleted = 0 "
            'AND s.id IN (${List.filled(sourceSessions.length, '?').join(',')}) LIMIT 1',
            variables: [
              Variable(visualId),
              ...sourceSessions.map(Variable.new),
            ],
            readsFrom: {
              db.visualScenes,
              db.visualMessageLinks,
              db.chatMessages,
              db.chatSessions,
            },
          )
          .get();
      if (allowed.isEmpty) continue;
      await db
          .into(db.visualStudyLinks)
          .insert(
            VisualStudyLinksCompanion.insert(
              visualId: visualId,
              knowledgeId: Value(knowledgeId),
            ),
          );
    }
  }

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
    final table = mistake ? "mistake_module_links" : "knowledge_module_links";
    final key = mistake ? "mistake_id" : "knowledge_id";
    await db.customUpdate(
      "DELETE FROM $table WHERE $key=? AND module_id IN (SELECT id FROM subject_modules WHERE subject<>?)",
      variables: [Variable(id), Variable(subject)],
      updates: {db.knowledgeModuleLinks, db.mistakeModuleLinks},
    );
  }

  Future<Mistake> importMistake(
    String path,
    String title, {
    String subject = "数学",
  }) => runOperation(() async {
    final image = await files.importFile(path);
    try {
      final row = await db.transaction(() async {
        final now = DateTime.now();
        final id = const Uuid().v4();
        final row = Mistake(
          id: id,
          title: _checked(title, StudyErrorField.title, 160, required: true),
          question: "",
          subject: _checked(
            subject,
            StudyErrorField.subject,
            40,
            required: true,
          ),
          chapter: "",
          correctAnswer: "",
          originalAnswer: "",
          ownAnalysis: "",
          aiAnalysis: "",
          errorReason: "暂未确定",
          suggestedReason: "",
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
}
