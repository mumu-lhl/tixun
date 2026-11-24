import "package:drift/drift.dart";

import "../../core/database/database.dart";
import "exam_material.dart";
import "exam_store.dart";
import "language_skills.dart";
import "language_store.dart";
import "lexical_form.dart";
import "sentence_content.dart";
import "sentence_batch_store.dart";

extension LanguageProfileStore on LanguageLearningStore {
  Stream<LanguageProfile> languageProfile(
    String language, {
    ExamProfile exam = ExamProfile.zhejiang2026,
  }) => db
      .customSelect(
        "SELECT 1",
        readsFrom: {
          db.learningLexicalItems,
          db.learningLexicalSenses,
          db.learningLexicalForms,
          db.learningEvidence,
          db.learningReviewSchedules,
          db.learningSentenceAttempts,
          db.learningSentenceBatches,
          db.learningWritingNotes,
          db.learningExamAttempts,
          db.learningExamMaterials,
          db.learningWritingEvaluations,
          db.learningWritingVersions,
          db.learningWritingTasks,
          db.learningCourseAttempts,
        },
      )
      .watch()
      .asyncMap((_) => readLanguageProfile(language, exam: exam));

  Future<LanguageProfile> readLanguageProfile(
    String language, {
    ExamProfile exam = ExamProfile.zhejiang2026,
  }) => db.transaction(() async {
    return LanguageProfile(
      language: language,
      exam: exam,
      due:
          (await db
                  .customSelect(
                    """
        SELECT COUNT(*) AS due
        FROM learning_review_schedules r
        JOIN learning_lexical_senses s ON s.id = r.sense_id
        JOIN learning_lexical_items i ON i.id = s.item_id
        WHERE i.language = ? AND r.due_at <= unixepoch()
      """,
                    variables: [Variable(language)],
                  )
                  .getSingle())
              .read<int>("due"),
      hasApplications: await _available(db, language, forms: false),
      hasForms: await _available(db, language, forms: true),
      evidence: [
        ...await _words(db, language),
        ...await _sentences(db, language),
        ...await _course(db, language),
        ...await _exams(db, language, exam),
        if (language == "en") ...await _writing(db, exam),
      ],
    );
  });
}

Future<bool> _available(
  AppDatabase db,
  String language, {
  required bool forms,
}) async {
  final content = forms
      ? "JOIN learning_lexical_senses s ON s.item_id = i.id JOIN learning_lexical_forms f ON f.sense_id = s.id"
      : "JOIN learning_lexical_senses s ON s.item_id = i.id";
  return (await db
          .customSelect(
            "SELECT 1 FROM learning_lexical_items i $content WHERE i.language = ? LIMIT 1",
            variables: [Variable(language)],
          )
          .getSingleOrNull()) !=
      null;
}

Future<List<LanguageObservation>> _words(
  AppDatabase db,
  String language,
) async {
  final rows = await db
      .customSelect(
        """
    SELECT e.*, i.form AS lemma, s.source, f.surface, f.inflection,
           EXISTS (
             SELECT 1 FROM learning_evidence old
             LEFT JOIN learning_lexical_forms previous_form ON previous_form.id = old.form_id
             WHERE old.sense_id = e.sense_id AND old.skill = e.skill
               AND (old.form_id IS e.form_id OR (
                 e.skill = 'formProduction' AND previous_form.inflection = f.inflection
               )) AND old.correct IS NOT NULL
               AND (old.occurred_at, old.rowid) < (e.occurred_at, e.rowid)
           ) AS repeated
    FROM learning_evidence e
    JOIN learning_lexical_senses s ON s.id = e.sense_id
    JOIN learning_lexical_items i ON i.id = s.item_id
    LEFT JOIN learning_lexical_forms f ON f.id = e.form_id
    WHERE i.language = ? AND s.source <> 'mock'
    ORDER BY e.occurred_at DESC, e.rowid DESC
    LIMIT 150
  """,
        variables: [Variable(language)],
      )
      .get();
  final results = <LanguageObservation>[];
  for (final row in rows) {
    final skill = switch (row.read<String>("skill")) {
      "meaningRecall" => LanguageSkill.wordRecall,
      "meaningRecognition" => LanguageSkill.wordRecognition,
      "contextApplication" => LanguageSkill.wordApplication,
      LexicalFormDraft.recognitionSkill => LanguageSkill.formRecognition,
      LexicalFormDraft.productionSkill => LanguageSkill.formProduction,
      _ => null,
    };
    if (skill == null) continue;
    final correct = row.readNullable<bool>("correct");
    results.add(
      LanguageObservation(
        id: row.read("id"),
        skill: skill,
        at: row.read("occurred_at"),
        basis: row.readNullable<String>("surface") ?? row.read<String>("lemma"),
        response: row.readNullable<String>("answer"),
        expected: skill == LanguageSkill.formRecognition
            ? row.read<String>("lemma")
            : row.readNullable<String>("surface"),
        task:
            row.readNullable<String>("inflection") ?? row.read<String>("skill"),
        correct: correct,
        verified:
            skill != LanguageSkill.wordApplication ||
            row.read<String>("source") == "user",
        kind: correct == null
            ? EvidenceKind.selfReport
            : row.read<bool>("repeated")
            ? EvidenceKind.repeat
            : row.read<bool>("answer_revealed") ||
                  row.read<bool>("group_prompt")
            ? EvidenceKind.assisted
            : EvidenceKind.independent,
      ),
    );
  }
  return results;
}

Future<List<LanguageObservation>> _sentences(
  AppDatabase db,
  String language,
) async {
  final rows = await db
      .customSelect(
        """
    SELECT a.*, EXISTS (
      SELECT 1 FROM learning_sentence_attempts old
      WHERE old.language = a.language AND old.skill = a.skill
        AND (old.sentence_id = a.sentence_id
          OR lower(trim(old.sentence)) = lower(trim(a.sentence)))
        AND old.correct IS NOT NULL
        AND (old.occurred_at, old.rowid) < (a.occurred_at, a.rowid)
    ) AS repeated
    FROM learning_sentence_attempts a
    WHERE a.language = ?
    ORDER BY a.occurred_at DESC, a.rowid DESC
    LIMIT 150
  """,
        variables: [Variable(language)],
      )
      .get();
  final ids = rows.map((r) => r.read<String>("sentence_id")).toSet();
  final batches = ids.isEmpty
      ? <LearningSentenceBatch>[]
      : await db
            .customSelect(
              "SELECT b.* FROM learning_sentence_batches b WHERE b.language = ? AND b.is_mock = 0 AND EXISTS (SELECT 1 FROM json_each(b.cards) c WHERE json_extract(c.value, '\$.id') IN (${List.filled(ids.length, '?').join(',')}))",
              variables: [
                Variable(language),
                for (final id in ids) Variable(id),
              ],
            )
            .map((row) => db.learningSentenceBatches.map(row.data))
            .get();
  // Runs have fresh batch IDs; match immutable content identity instead.
  final cards = <(String, int, String), SentenceCard>{};
  final ambiguous = <(String, int, String)>{};
  for (final batch in batches) {
    for (final card in openSavedSentenceBatch(batch).cards) {
      final key = (card.id, card.revision, card.text);
      final previous = cards[key];
      if (previous != null &&
          (previous.question != card.question ||
              previous.choices.join("\\u0000") !=
                  card.choices.join("\\u0000") ||
              previous.correctIndex != card.correctIndex ||
              previous.level != card.level ||
              previous.skill != card.skill)) {
        ambiguous.add(key);
      }
      cards[key] = card;
    }
  }
  for (final key in ambiguous) {
    cards.remove(key);
  }
  final results = <LanguageObservation>[];
  for (final row in rows) {
    final snapshot =
        cards[(
          row.read<String>("sentence_id"),
          row.read<int>("revision"),
          row.read<String>("sentence"),
        )];
    final skill = SentenceSkill.values.asNameMap()[row.read<String>("skill")];
    if (skill == null) continue;
    final card = snapshot?.skill == skill ? snapshot : null;
    final correct = row.readNullable<bool>("correct");
    results.add(
      LanguageObservation(
        id: row.read("id"),
        skill: sentenceAbility(skill),
        at: row.read("occurred_at"),
        basis: row.read("sentence"),
        response: row.readNullable<String>("answer"),
        task: card == null ? skill.name : "${skill.name}: ${card.question}",
        expected:
            card != null &&
                card.correctIndex >= 0 &&
                card.correctIndex < card.choices.length
            ? card.choices[card.correctIndex]
            : null,
        feedback: card?.checkExplanation,
        level: card?.level,
        correct: correct,
        verified: false,
        kind: correct == null
            ? EvidenceKind.selfReport
            : row.read<bool>("repeated")
            ? EvidenceKind.repeat
            : row.readNullable<int>("help_before_answer") != 0
            ? EvidenceKind.assisted
            : EvidenceKind.independent,
      ),
    );
  }
  return results;
}

Future<List<LanguageObservation>> _exams(
  AppDatabase db,
  String language,
  ExamProfile profile,
) async {
  final material = db.learningExamMaterials;
  final attempt = db.learningExamAttempts;
  final other = db.alias(attempt, "profile_other_exam_attempt");
  final earlier = db.selectOnly(other)
    ..addColumns([other.id])
    ..where(
      other.materialId.equalsExp(attempt.materialId) &
          (other.submittedAt.isSmallerThan(attempt.submittedAt) |
              (other.submittedAt.equalsExp(attempt.submittedAt) &
                  other.rowId.isSmallerThan(attempt.rowId))),
    );
  final disputed = db.selectOnly(other)
    ..addColumns([other.id])
    ..where(
      other.materialId.equalsExp(attempt.materialId) &
          other.disputedPositions.equals("[]").not(),
    );
  final repeatedFlag = existsQuery(earlier);
  final disputedFlag = existsQuery(disputed);
  final query =
      db.select(attempt).join([
          innerJoin(material, material.id.equalsExp(attempt.materialId)),
        ])
        ..addColumns([repeatedFlag, disputedFlag])
        ..where(
          material.language.equals(language) &
              material.profile.equals(profile.id) &
              material.source.equals(ExamSource.bundled.name).not() &
              (material.model.isNull() | material.model.equals("Mock").not()),
        )
        ..orderBy([
          OrderingTerm.desc(attempt.submittedAt),
          OrderingTerm.desc(attempt.rowId),
        ])
        ..limit(40);
  final results = <LanguageObservation>[];
  for (final row in await query.get()) {
    final paper = ExamMaterial(row.readTable(material));
    final record = row.readTable(attempt);
    final answers = ExamResult(record).responses;
    if (answers.length != paper.paper.items.length) continue;
    final disputed = row.read(disputedFlag) ?? true;
    final repeated = row.read(repeatedFlag) ?? true;
    for (final (i, item) in paper.paper.items.indexed) {
      if (answers[i].trim().isEmpty) continue;
      for (final skill in {
        examAbility(paper.target.kind),
        sentenceAbility(item.skill),
      }) {
        results.add(
          LanguageObservation(
            id: record.id,
            skill: skill,
            at: record.submittedAt,
            basis: [paper.paper.title, item.prompt].join(" · "),
            response: answers[i],
            expected: item.answers.join(" / "),
            task: paper.target.kind.name,
            level: paper.target.level,
            profile: profile,
            correct: item.matches(answers[i]),
            verified:
                record.reviewedAtSubmission &&
                paper.verification == ExamVerification.aiReviewed &&
                !disputed,
            kind: disputed
                ? EvidenceKind.disputed
                : repeated
                ? EvidenceKind.repeat
                : record.hintUsed ||
                      record.confidence == ExamConfidence.guess.name
                ? EvidenceKind.assisted
                : EvidenceKind.independent,
          ),
        );
      }
    }
  }
  return results;
}

Future<List<LanguageObservation>> _writing(
  AppDatabase db,
  ExamProfile exam,
) async {
  final evaluation = db.learningWritingEvaluations;
  final version = db.learningWritingVersions;
  final task = db.learningWritingTasks;
  final rows =
      await (db.select(evaluation).join([
              innerJoin(version, version.id.equalsExp(evaluation.versionId)),
              leftOuterJoin(task, task.id.equalsExp(version.taskId)),
            ])
            ..where(
              evaluation.isMock.equals(false) &
                  (task.profile.equals(exam.id) | task.profile.isNull()),
            )
            ..orderBy([OrderingTerm.desc(evaluation.createdAt)])
            ..limit(30))
          .get();
  final notes =
      await (db.select(db.learningWritingNotes)
            ..where(
              (n) =>
                  n.versionId.isIn(rows.map((r) => r.readTable(version).id)) &
                  n.kind.equals("issue"),
            )
            ..orderBy([(n) => OrderingTerm.asc(n.position)]))
          .get();
  final issues = <String, List<(String, String)>>{};
  for (final row in rows) {
    final draft = row.readTable(version);
    for (final note in notes.where((n) => n.versionId == draft.id).take(2)) {
      if (note.startOffset < 0 ||
          note.endOffset > draft.content.length ||
          note.startOffset >= note.endOffset) {
        continue;
      }
      (issues[draft.id] ??= []).add((
        draft.content.substring(note.startOffset, note.endOffset),
        note.comment,
      ));
    }
  }
  return [
    for (final row in rows)
      for (final skill in const [
        LanguageSkill.writingTask,
        LanguageSkill.writingOrganization,
        LanguageSkill.writingAccuracy,
      ])
        LanguageObservation(
          id: row.readTable(version).taskId,
          skill: skill,
          at: row.readTable(evaluation).createdAt,
          basis: row.readTable(evaluation).summary,
          task: "writing",
          response: issues[row.readTable(version).id]
              ?.map((n) => n.$1)
              .join("\n"),
          feedback: issues[row.readTable(version).id]
              ?.map((n) => n.$2)
              .join("\n"),
          profile: row.readTableOrNull(task) == null ? null : exam,
          kind: EvidenceKind.unverified,
          verified: false,
          correct: switch (skill) {
            LanguageSkill.writingTask =>
              row.readTable(evaluation).taskScore >= 3,
            LanguageSkill.writingOrganization =>
              row.readTable(evaluation).organizationScore >= 3,
            _ => row.readTable(evaluation).languageScore >= 3,
          },
        ),
  ];
}

Future<List<LanguageObservation>> _course(
  AppDatabase db,
  String language,
) async {
  final table = db.learningCourseAttempts;
  final rows =
      await (db.select(table)
            ..where((row) => row.language.equals(language))
            ..orderBy([
              (row) => OrderingTerm.desc(row.occurredAt),
              (row) => OrderingTerm.desc(row.rowId),
            ])
            ..limit(90))
          .get();
  final distinct = <(String, int)>{};
  return [
    for (final row in rows.reversed)
      if (distinct.add((row.lesson, row.rotation))) ...[
        LanguageObservation(
          id: row.id,
          skill: LanguageSkill.wordRecognition,
          kind: EvidenceKind.independent,
          at: row.occurredAt,
          basis: row.lesson,
          correct: row.recognized == 2,
        ),
        LanguageObservation(
          id: row.id,
          skill: LanguageSkill.wordRecall,
          kind: EvidenceKind.independent,
          at: row.occurredAt,
          basis: row.lesson,
          correct: row.produced == 1,
        ),
      ],
  ];
}
