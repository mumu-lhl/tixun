part of "study_store.dart";

mixin _StudyQueries on DatabaseNotifier {
  AppDatabase get db;

  String _checked(
    String value,
    StudyErrorField label,
    int limit, {
    required bool required,
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
        "知识记录不存在或已在回收区。",
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
        "错题不存在或已在回收区。",
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

  Future<Map<String, List<String>>> tagsForIds(
    Iterable<String> ids, {
    required bool isMistake,
  }) async {
    final values = ids.toList();
    if (values.isEmpty) return {};
    final result = <String, List<String>>{};
    if (isMistake) {
      final rows = await (db.select(
        db.mistakeTags,
      )..where((t) => t.mistakeId.isIn(values))).get();
      for (final row in rows) {
        result.putIfAbsent(row.mistakeId, () => []).add(row.tag);
      }
    } else {
      final rows = await (db.select(
        db.knowledgeTags,
      )..where((t) => t.knowledgeId.isIn(values))).get();
      for (final row in rows) {
        result.putIfAbsent(row.knowledgeId, () => []).add(row.tag);
      }
    }
    return result;
  }

  Future<String> _listSubject(String subject) async {
    final scope = await readStudySubjectScope(db);
    if (scope != null && subject.isNotEmpty) {
      requireStudySubject(subject, scope);
    }
    return scope ?? subject;
  }

  Future<List<({String tag, int count})>> tagUsage({
    required bool isMistake,
    String subject = "",
    bool trash = false,
  }) async {
    final effectiveSubject = await _listSubject(subject);
    final table = isMistake ? "mistakes" : "knowledge_items";
    final tags = isMistake ? "mistake_tags" : "knowledge_tags";
    final id = isMistake ? "mistake_id" : "knowledge_id";
    final rows = await db
        .customSelect(
          """
      SELECT tags.tag AS tag, count(*) AS n
      FROM $tags tags JOIN $table t ON t.id = tags.$id
      WHERE t.deleted = ? ${effectiveSubject.isEmpty ? "" : "AND t.subject = ?"}
      GROUP BY tags.tag
      ORDER BY n DESC, tags.tag COLLATE NOCASE, tags.tag
      """,
          variables: [
            Variable(trash ? 1 : 0),
            if (effectiveSubject.isNotEmpty) Variable(effectiveSubject),
          ],
        )
        .get();
    return [
      for (final row in rows)
        (tag: row.read<String>("tag"), count: row.read<int>("n")),
    ];
  }

  Future<List<KnowledgeRevision>> revisions(String id) =>
      (db.select(db.knowledgeRevisions)
            ..where((t) => t.knowledgeId.equals(id))
            ..orderBy([(t) => OrderingTerm.desc(t.revision)]))
          .get();

  Future<List<KnowledgeItem>> searchKnowledge({
    String query = "",
    String subject = "",
    String moduleId = "",
    Set<String> tags = const {},
    bool trash = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _search(
      "knowledge_items",
      "knowledge_search",
      "content",
      query,
      subject,
      trash,
      limit,
      offset,
      moduleId,
      tags,
    );
    return Future.wait(rows.map(db.knowledgeItems.mapFromRow));
  }

  Future<List<Mistake>> searchMistakes({
    String query = "",
    String subject = "",
    String moduleId = "",
    Set<String> tags = const {},
    bool trash = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _search(
      "mistakes",
      "mistake_search",
      "question",
      query,
      subject,
      trash,
      limit,
      offset,
      moduleId,
      tags,
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
    Set<String> tags,
  ) async {
    final effectiveSubject = await _listSubject(subject);
    final term = _checked(
      query,
      StudyErrorField.searchTerm,
      300,
      required: false,
    );
    final tagTable = table == "mistakes" ? "mistake_tags" : "knowledge_tags";
    final idColumn = table == "mistakes" ? "mistake_id" : "knowledge_id";
    final vars = <Variable>[Variable(trash ? 1 : 0)];
    var where = "t.deleted = ?";
    if (effectiveSubject.isNotEmpty) {
      where += " AND t.subject = ?";
      vars.add(Variable(effectiveSubject));
    }
    if (moduleId.isNotEmpty) {
      final links = table == "mistakes"
          ? "mistake_module_links"
          : "knowledge_module_links";
      if (moduleId == "unclassified") {
        where +=
            " AND NOT EXISTS (SELECT 1 FROM $links ml WHERE ml.$idColumn=t.id)";
      } else {
        where +=
            " AND EXISTS (SELECT 1 FROM $links ml JOIN subject_modules sm ON sm.id=ml.module_id WHERE ml.$idColumn=t.id AND (sm.id=? OR sm.parent_id=?))";
        vars.addAll([Variable(moduleId), Variable(moduleId)]);
      }
    }
    if (tags.isNotEmpty) {
      // Each (item, tag) is unique. Count exact matches, not keyword hits.
      where +=
          " AND (SELECT count(*) FROM $tagTable tags WHERE tags.$idColumn = t.id AND tags.tag IN (SELECT value FROM json_each(?))) = ?";
      vars.addAll([Variable(jsonEncode(tags.toList())), Variable(tags.length)]);
    }
    if (term.isNotEmpty) {
      final bodyExpression = table == "mistakes"
          ? "t.question || char(10) || t.correct_answer || char(10) || t.original_answer || char(10) || t.own_analysis || char(10) || t.ai_analysis || char(10) || t.error_reason || char(10) || t.suggested_reason"
          : "t.$body";
      for (final keyword in searchTerms(term)) {
        final condition = keyword.runes.length >= 3
            ? "t.rowid IN (SELECT rowid FROM $fts WHERE $fts MATCH ?)"
            : "instr(lower(t.title || char(10) || $bodyExpression || char(10) || t.chapter), lower(?)) > 0";
        where +=
            " AND ($condition OR EXISTS (SELECT 1 FROM $tagTable tags WHERE tags.$idColumn = t.id AND instr(lower(tags.tag), lower(?)) > 0))";
        vars.add(
          Variable(
            keyword.runes.length >= 3
                ? '"${keyword.replaceAll('"', '""')}"'
                : keyword,
          ),
        );
        vars.add(Variable(keyword));
      }
    }
    final order = term.isEmpty
        ? "t.updated_at DESC, t.id"
        : "CASE WHEN instr(lower(t.title), lower(?)) > 0 THEN 0 ELSE 1 END, t.updated_at DESC, t.id";
    if (term.isNotEmpty) vars.add(Variable(searchTerms(term).join(" ")));
    vars.add(Variable(limit.clamp(1, 200)));
    vars.add(Variable(offset.clamp(0, 10000000)));
    return db
        .customSelect(
          "SELECT t.* FROM $table t WHERE $where ORDER BY $order LIMIT ? OFFSET ?",
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
