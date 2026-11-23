import "package:drift/drift.dart";
import "package:uuid/uuid.dart";

import "../../core/database/database.dart";
import "language_store.dart";
import "lexical_form.dart";
import "generation_store.dart";

typedef FormPractice = ({
  LearningLexicalForm form,
  LearningLexicalItem item,
  LearningLexicalSense sense,
});

extension LexicalFormStore on LanguageLearningStore {
  Future<List<LearningLexicalForm>> lexicalForms(String senseId) =>
      (db.select(db.learningLexicalForms)
            ..where((row) => row.senseId.equals(senseId))
            ..orderBy([(row) => OrderingTerm.asc(row.surface)]))
          .get();

  Future<List<FormPractice>> formPractice(String language) async {
    final forms = db.learningLexicalForms;
    final items = db.learningLexicalItems;
    final senses = db.learningLexicalSenses;
    final rows =
        await (db.select(forms).join([
                innerJoin(senses, senses.id.equalsExp(forms.senseId)),
                innerJoin(items, items.id.equalsExp(senses.itemId)),
              ])
              ..where(
                items.language.equals(language) &
                    senses.source.equals("mock").not(),
              )
              ..orderBy([
                OrderingTerm.desc(forms.createdAt),
                OrderingTerm.asc(forms.id),
              ])
              ..limit(80))
            .get();
    final seen = <String>{};
    return [
      for (final row in rows)
        if (seen.add(row.readTable(forms).id))
          (
            form: row.readTable(forms),
            item: row.readTable(items),
            sense: row.readTable(senses),
          ),
    ];
  }

  Future<void> saveLexicalForm(LanguageCard card, LexicalFormDraft form) =>
      runOperation(() async {
        await insertLexicalForm(db, card.sense.id, card.item.form, form);
        changed();
      });

  Future<bool> recordFormPractice({
    required String attemptId,
    required FormPractice exercise,
    required String answer,
    required bool production,
  }) => runOperation(() async {
    final clean = normalizeLanguageText(answer);
    if (clean.isEmpty ||
        clean.length > 80 ||
        exercise.sense.itemId != exercise.item.id ||
        exercise.form.senseId != exercise.sense.id) {
      throw const FormatException("Invalid word form attempt");
    }
    final accepted = production
        ? (await lexicalForms(exercise.sense.id))
              .where((row) => row.inflection == exercise.form.inflection)
              .map((row) => row.normalizedSurface)
        : [normalizeLanguageText(exercise.item.form)];
    final correct = accepted.contains(clean);
    final row = await db
        .into(db.learningEvidence)
        .insertReturningOrNull(
          LearningEvidenceCompanion.insert(
            id: attemptId,
            senseId: exercise.sense.id,
            generationRunId: Value(
              (await LanguageGenerationStore(
                db,
              ).currentContentRun("vocabulary", exercise.sense.id))?.id,
            ),
            formId: Value(exercise.form.id),
            skill: production
                ? LexicalFormDraft.productionSkill
                : LexicalFormDraft.recognitionSkill,
            answer: Value(clean),
            correct: Value(correct),
            occurredAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    changed();
    if (row != null) return row.correct!;
    final current = await (db.select(
      db.learningEvidence,
    )..where((row) => row.id.equals(attemptId))).getSingle();
    return current.correct!;
  });

  Future<bool> recordMeaningRecognition(
    LanguageCard card,
    String answer, {
    String? attemptId,
    bool usedHelp = false,
  }) => runOperation(() async {
    final correct = answer == card.sense.meaning;
    await db
        .into(db.learningEvidence)
        .insert(
          LearningEvidenceCompanion.insert(
            id: attemptId ?? const Uuid().v4(),
            senseId: card.sense.id,
            generationRunId: Value(
              (await LanguageGenerationStore(
                db,
              ).currentContentRun("vocabulary", card.sense.id))?.id,
            ),
            skill: "meaningRecognition",
            answer: Value(answer),
            correct: Value(correct),
            answerRevealed: Value(usedHelp),
            occurredAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    changed();
    return correct;
  });
}
