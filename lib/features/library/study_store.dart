import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
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
class StudyStore extends ChangeNotifier {
  StudyStore(this.db, this.files);
  final AppDatabase db;
  final AttachmentStore files;
  int epoch = 0;
  bool _closed = false;
  void changed() {
    if (_closed) return;
    epoch++;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  String checked(
    String value,
    String label,
    int limit, {
    bool required = false,
  }) {
    final s = value.trim();
    if ((required && s.isEmpty) || s.length > limit) {
      throw FormatException('$label${s.isEmpty ? '不能为空' : '过长（最多 $limit 字符）'}');
    }
    return s;
  }

  List<String> cleanTags(List<String> tags) {
    if (tags.length > 20) throw const FormatException('每条资料最多 20 个标签。');
    return tags
        .map((t) => checked(t, '标签', 40))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<KnowledgeItem> knowledge(
    String id, {
    bool includeDeleted = false,
  }) async {
    final row = await (db.select(
      db.knowledgeItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || (row.deleted && !includeDeleted)) {
      throw const FormatException('知识记录不存在或已在回收区。');
    }
    return row;
  }

  Future<Mistake> mistake(String id, {bool includeDeleted = false}) async {
    final row = await (db.select(
      db.mistakes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || (row.deleted && !includeDeleted)) {
      throw const FormatException('错题不存在或已在回收区。');
    }
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
      throw const FormatException('来源对话和消息不匹配。');
    }
  }

  Future<KnowledgeItem> saveKnowledge(
    KnowledgeDraft draft, {
    String? id,
    int? expectedRevision,
    String? sourceSessionId,
    String? sourceMessageId,
  }) async {
    final title = checked(draft.title, '标题', 160, required: true);
    final content = checked(draft.content, '正文', 60000);
    final subject = checked(draft.subject, '科目', 40, required: true);
    final chapter = checked(draft.chapter, '章节', 160);
    if (!knowledgeKinds.contains(draft.kind)) {
      throw const FormatException('知识类型无效。');
    }
    final labels = cleanTags(draft.tags);
    final result = await db.transaction(() async {
      final old = id == null ? null : await knowledge(id);
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
      await _tags(key, labels, false);
      await _snapshot(row, labels);
      if (sourceSessionId != null) {
        await _chatLink(sourceSessionId, knowledgeId: key);
      }
      return row;
    });
    changed();
    return result;
  }

  Future<Mistake> saveMistake(
    MistakeDraft draft, {
    String? id,
    int? expectedRevision,
    String? sourceSessionId,
    String? sourceMessageId,
  }) async {
    final title = checked(draft.title, '标题', 160, required: true);
    final subject = checked(draft.subject, '科目', 40, required: true);
    for (final text in [
      draft.question,
      draft.correctAnswer,
      draft.originalAnswer,
      draft.ownAnalysis,
      draft.aiAnalysis,
    ]) {
      checked(text, '内容', 60000);
    }
    final chapter = checked(draft.chapter, '章节', 160);
    final reason = checked(draft.errorReason, '错误原因', 100, required: true);
    final suggestion = checked(draft.suggestedReason, '建议原因', 500);
    final labels = cleanTags(draft.tags);
    final result = await db.transaction(() async {
      final old = id == null ? null : await mistake(id);
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
      await _tags(key, labels, true);
      if (sourceSessionId != null) {
        await _chatLink(sourceSessionId, mistakeId: key);
      }
      return row;
    });
    changed();
    return result;
  }

  Future<void> setDeleted(
    String id, {
    required bool isMistake,
    required bool deleted,
    required int expectedRevision,
  }) async {
    await db.transaction(() async {
      if (isMistake) {
        final row = await mistake(id, includeDeleted: true);
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
        if (row.revision != expectedRevision) throw const StudyConflict();
        final next = row.copyWith(
          deleted: deleted,
          revision: row.revision + 1,
          updatedAt: DateTime.now(),
        );
        await db.update(db.knowledgeItems).replace(next);
        await _snapshot(next, await tags(id, isMistake: false));
      }
    });
    changed();
  }

  Future<List<KnowledgeRevision>> revisions(String id) =>
      (db.select(db.knowledgeRevisions)
            ..where((t) => t.knowledgeId.equals(id))
            ..orderBy([(t) => OrderingTerm.desc(t.revision)]))
          .get();
  Future<KnowledgeItem> restoreRevision(
    String id,
    int version,
    int expectedRevision,
  ) async {
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
  }

  Future<List<KnowledgeItem>> searchKnowledge({
    String query = '',
    String subject = '',
    bool trash = false,
    int limit = 100,
  }) async {
    final rows = await _search(
      'knowledge_items',
      'knowledge_search',
      'content',
      query,
      subject,
      trash,
      limit,
    );
    return Future.wait(rows.map(db.knowledgeItems.mapFromRow));
  }

  Future<List<Mistake>> searchMistakes({
    String query = '',
    String subject = '',
    bool trash = false,
    int limit = 100,
  }) async {
    final rows = await _search(
      'mistakes',
      'mistake_search',
      'question',
      query,
      subject,
      trash,
      limit,
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
  ) {
    final term = checked(query, '搜索词', 300);
    final tagTable = table == 'mistakes' ? 'mistake_tags' : 'knowledge_tags';
    final idColumn = table == 'mistakes' ? 'mistake_id' : 'knowledge_id';
    final vars = <Variable>[Variable(trash ? 1 : 0)];
    var where = 't.deleted = ?';
    if (subject.isNotEmpty) {
      where += ' AND t.subject = ?';
      vars.add(Variable(subject));
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
    return db
        .customSelect(
          'SELECT t.* FROM $table t WHERE $where ORDER BY t.updated_at DESC, t.id LIMIT ?',
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
  List<StudyAttachment> preferredImages(List<StudyAttachment> images) {
    final byId = {for (final image in images) image.id: image};
    final selected = <String, StudyAttachment>{};
    for (final image in images) {
      var root = image;
      var key = image.id;
      final seen = <String>{};
      while (root.parentId != null && seen.add(root.id)) {
        key = root.parentId!;
        final parent = byId[key];
        if (parent == null) break;
        root = parent;
      }
      selected[key] = image;
    }
    return selected.values.toList();
  }

  Future<void> restoreImage(StudyAttachment image) async {
    await (db.update(db.studyAttachments)..where((t) => t.id.equals(image.id)))
        .write(const StudyAttachmentsCompanion(deleted: Value(false)));
    changed();
  }

  Future<StudyAttachment> importImage(
    String id,
    String path, {
    required bool isMistake,
  }) async {
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
  }

  Future<StudyAttachment> addImageReference(
    String id,
    String path,
    String mime,
    int bytes, {
    required bool isMistake,
    String? parentId,
    String role = 'original',
  }) async {
    files.resolve(path);
    if (!await files.resolve(path).exists()) {
      throw const FormatException('图片文件缺失。');
    }
    final row = await db.transaction(() async {
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
  }

  Future<Mistake> importMistake(
    String path,
    String title, {
    String subject = '数学',
  }) async {
    final image = await files.importFile(path);
    try {
      final row = await db.transaction(() async {
        final now = DateTime.now();
        final id = const Uuid().v4();
        final row = Mistake(
          id: id,
          title: checked(title, '标题', 160, required: true),
          question: '',
          subject: checked(subject, '科目', 40, required: true),
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
  }

  Future<void> removeImage(StudyAttachment image) async {
    await (db.update(db.studyAttachments)..where((t) => t.id.equals(image.id)))
        .write(const StudyAttachmentsCompanion(deleted: Value(true)));
    changed();
  }

  Future<void> link(
    String knowledgeId, {
    String? otherKnowledgeId,
    String? mistakeId,
    bool remove = false,
  }) async {
    await db.transaction(() async {
      await knowledge(knowledgeId);
      if (mistakeId != null) {
        await mistake(mistakeId);
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
          throw const FormatException('请选择不同的知识记录。');
        }
        await knowledge(otherKnowledgeId);
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
  }

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
  }) async {
    if (knowledgeId != null) await knowledge(knowledgeId);
    if (mistakeId != null) await mistake(mistakeId);
    await _chatLink(session, knowledgeId: knowledgeId, mistakeId: mistakeId);
    changed();
  }

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
