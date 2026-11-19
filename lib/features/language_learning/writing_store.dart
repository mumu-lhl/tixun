import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../core/ai/chat_provider.dart' show CancelGuard;

import '../../core/database/database.dart';
import 'language_store.dart';
import 'writing_feedback.dart';

const writingMaxLength = 3000;

class WritingTask {
  const WritingTask(
    this.id,
    this.prompt, {
    this.title,
    this.passage,
    this.rubric,
  });
  final String id, prompt;
  final String? title, passage, rubric;
}

const continuationRubric =
    'Check whether the continuation follows the source events, preserves '
    'the characters and perspective, makes meaningful use of the clue, '
    'and provides a coherent ending. Consider the clarity of transitions.';

typedef WritingHistory = ({
  LearningWritingVersion version,
  LearningWritingEvaluation? evaluation,
});

extension WritingLearningStore on LanguageLearningStore {
  Future<String> writingDraft({required String taskId}) async {
    final row = await (db.select(
      db.learningWritingDrafts,
    )..where((row) => row.taskId.equals(taskId))).getSingleOrNull();
    return row?.content ?? '';
  }

  Future<void> _saveWritingDraft(String text, String taskId) => db
      .into(db.learningWritingDrafts)
      .insertOnConflictUpdate(
        LearningWritingDraftsCompanion.insert(taskId: taskId, content: text),
      );

  Future<void> saveWritingDraft(String text, {required String taskId}) =>
      runOperation(() => _saveWritingDraft(text, taskId));

  Future<String> snapshotWriting(String text, {required String taskId}) =>
      runOperation(() async {
        if (text.trim().isEmpty || text.length > writingMaxLength) {
          throw const FormatException('Invalid draft length');
        }
        final id = sha256
            .convert(utf8.encode(jsonEncode([taskId, text])))
            .toString();
        await db.transaction(() async {
          await _saveWritingDraft(text, taskId);
          await db
              .into(db.learningWritingVersions)
              .insert(
                LearningWritingVersionsCompanion.insert(
                  id: id,
                  taskId: taskId,
                  content: text,
                  createdAt: DateTime.now(),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        });
        return id;
      });

  Stream<List<WritingHistory>> writingHistory({required String taskId}) {
    final versions = db.learningWritingVersions;
    final evaluations = db.learningWritingEvaluations;
    return (db.select(versions).join([
            leftOuterJoin(
              evaluations,
              evaluations.versionId.equalsExp(versions.id),
            ),
          ])
          ..where(versions.taskId.equals(taskId))
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
    CancelToken? cancel,
  }) => runOperation(
    () => db.transaction(() async {
      cancel?.checkCancelled();
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
      cancel?.checkCancelled();
    }),
  );
}
