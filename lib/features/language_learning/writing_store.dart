import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/database/database.dart';
import 'language_store.dart';
import 'writing_feedback.dart';

const writingTaskId = 'en-application-club-v1';
const writingTaskPrompt =
    'Your school is starting a book club. Write an email to the club organizer '
    'introducing yourself, explaining why you want to join, and suggesting one '
    'activity for the club. Aim for about 100 words. Use an appropriate email tone.';
const writingMaxLength = 3000;

typedef WritingHistory = ({
  LearningWritingVersion version,
  LearningWritingEvaluation? evaluation,
});

extension WritingLearningStore on LanguageLearningStore {
  Future<String> writingDraft() async {
    final row = await (db.select(
      db.learningWritingDrafts,
    )..where((row) => row.taskId.equals(writingTaskId))).getSingleOrNull();
    return row?.content ?? '';
  }

  Future<void> _saveWritingDraft(String text) => db
      .into(db.learningWritingDrafts)
      .insertOnConflictUpdate(
        LearningWritingDraftsCompanion.insert(
          taskId: writingTaskId,
          content: text,
        ),
      );

  Future<void> saveWritingDraft(String text) =>
      runOperation(() => _saveWritingDraft(text));

  Future<String> snapshotWriting(String text) => runOperation(() async {
    if (text.trim().isEmpty || text.length > writingMaxLength) {
      throw const FormatException('Invalid draft length');
    }
    final id = sha256
        .convert(utf8.encode(jsonEncode([writingTaskId, text])))
        .toString();
    await db.transaction(() async {
      await _saveWritingDraft(text);
      await db
          .into(db.learningWritingVersions)
          .insert(
            LearningWritingVersionsCompanion.insert(
              id: id,
              taskId: writingTaskId,
              content: text,
              createdAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
    return id;
  });

  Stream<List<WritingHistory>> writingHistory() {
    final versions = db.learningWritingVersions;
    final evaluations = db.learningWritingEvaluations;
    return (db.select(versions).join([
            leftOuterJoin(
              evaluations,
              evaluations.versionId.equalsExp(versions.id),
            ),
          ])
          ..where(versions.taskId.equals(writingTaskId))
          ..orderBy([
            OrderingTerm.desc(versions.createdAt),
            OrderingTerm.desc(versions.rowId),
          ])
          ..limit(12))
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              (
                version: row.readTable(versions),
                evaluation: row.readTableOrNull(evaluations),
              ),
          ],
        );
  }

  Future<LearningWritingEvaluation?> writingFeedback(String versionId) =>
      (db.select(
        db.learningWritingEvaluations,
      )..where((row) => row.versionId.equals(versionId))).getSingleOrNull();

  Future<List<LearningWritingNote>> writingNotes(String versionId) =>
      (db.select(db.learningWritingNotes)
            ..where((row) => row.versionId.equals(versionId))
            ..orderBy([(row) => OrderingTerm.asc(row.position)]))
          .get();

  Future<void> saveWritingFeedback({
    required String versionId,
    required WritingFeedback feedback,
    required String model,
    required int promptVersion,
    required bool isMock,
  }) => runOperation(
    () => db.transaction(() async {
      final existing = await writingFeedback(versionId);
      if (existing != null) {
        if (!existing.isMock || isMock) return;
        await (db.delete(
          db.learningWritingEvaluations,
        )..where((row) => row.versionId.equals(versionId))).go();
      }
      await db
          .into(db.learningWritingEvaluations)
          .insert(
            LearningWritingEvaluationsCompanion.insert(
              versionId: versionId,
              model: model,
              promptVersion: promptVersion,
              isMock: isMock,
              taskScore: feedback.task,
              organizationScore: feedback.organization,
              languageScore: feedback.language,
              summary: feedback.summary,
              createdAt: DateTime.now(),
            ),
          );
      await db.batch((batch) {
        batch.insertAll(db.learningWritingNotes, [
          for (final (i, note) in feedback.notes.indexed)
            LearningWritingNotesCompanion.insert(
              versionId: versionId,
              position: i,
              startOffset: note.start,
              endOffset: note.end,
              kind: note.kind.name,
              comment: note.comment,
            ),
        ]);
      });
    }),
  );
}
