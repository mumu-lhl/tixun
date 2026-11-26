import "package:dio/dio.dart";
import "package:drift/drift.dart";

import "../../core/ai/chat_provider.dart" show CancelGuard;

import "../../core/database/database.dart";
import "language_store.dart";
import "sentence_content.dart";

extension SentenceLearningStore on LanguageLearningStore {
  Future<void> recordSentence({
    required String batchId,
    required SentenceCard card,
    SentenceRating? rating,
    required Set<SentenceHelp> helpUsed,
    int? selectedIndex,
    Set<SentenceHelp> helpBeforeAnswer = const {},
  }) => runOperation(() async {
    final hasAnswer = selectedIndex != null && card.choices.isNotEmpty;
    if (!hasAnswer && rating == null) return;
    await db
        .into(db.learningSentenceAttempts)
        .insert(
          LearningSentenceAttemptsCompanion.insert(
            id: "$batchId:${card.id}",
            batchId: batchId,
            sentenceId: card.id,
            revision: card.revision,
            language: card.language,
            sentence: card.text,
            skill: card.skill?.name ?? "unscored",
            rating: Value(rating?.name),
            targetSenseId: Value(card.target?.senseId),
            answer: Value(hasAnswer ? card.choices[selectedIndex] : null),
            correct: Value(
              hasAnswer ? selectedIndex == card.correctIndex : null,
            ),
            helpBeforeAnswer: Value(
              hasAnswer ? SentenceHelp.encode(helpBeforeAnswer) : null,
            ),
            helpUsed: SentenceHelp.encode(helpUsed),
            occurredAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    changed();
  });

  Stream<List<LearningSentenceAttempt>> sentenceEvidence(String language) =>
      (db.select(db.learningSentenceAttempts)
            ..where((row) => row.language.equals(language))
            ..orderBy([
              (row) => OrderingTerm.desc(row.occurredAt),
              (row) => OrderingTerm.desc(row.rowId),
            ])
            ..limit(80))
          .watch();

  Future<String?> cachedExplanation(String key) async {
    final row = await (db.select(
      db.learningInlineExplanations,
    )..where((row) => row.cacheKey.equals(key))).getSingleOrNull();
    return row?.explanation;
  }

  Future<void> cacheExplanation({
    required String key,
    required SentenceCard card,
    required String model,
    required int promptVersion,
    required String text,
    CancelToken? cancel,
  }) => runOperation(
    () => db.transaction(() async {
      cancel?.checkCancelled();
      await db
          .into(db.learningInlineExplanations)
          .insertOnConflictUpdate(
            LearningInlineExplanationsCompanion.insert(
              cacheKey: key,
              contentId: card.id,
              revision: card.revision,
              model: model,
              promptVersion: promptVersion,
              explanation: text,
              createdAt: DateTime.now(),
            ),
          );
      cancel?.checkCancelled();
    }),
  );
}
