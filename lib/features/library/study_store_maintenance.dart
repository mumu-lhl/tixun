part of "study_store.dart";

mixin _StudyMaintenance on DatabaseNotifier, _StudyQueries {
  AttachmentStore get files;

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
        "每次请选择 1–200 条资料。",
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
            "请选择不同的知识记录。",
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
}
